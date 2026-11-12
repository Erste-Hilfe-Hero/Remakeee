class_name HpBarStyle
extends RefCounted
## Per-era HP bar look from data/battle_ui.json. Pure helpers, so tests need no scene.

const PATH: String = "res://data/battle_ui.json"
enum State { HIGH, MID, LOW }

static var _cfg: Dictionary = {}

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_cfg = JSON.parse_string(f.get_as_text()) if f != null else {}
	return _cfg

## Style for [param era]; eras past the table use the newest entry.
static func for_era(era: int) -> Dictionary:
	var eras: Dictionary = cfg().get("eras", {})
	var e: int = clampi(era, 1, eras.size())
	return eras.get(str(e), {})

static func state(frac: float) -> int:
	if frac <= float(cfg().get("low_at", 0.25)):
		return State.LOW
	if frac <= float(cfg().get("mid_at", 0.5)):
		return State.MID
	return State.HIGH

static func color(era: int, frac: float) -> Color:
	var cols: Array = for_era(era).get("colors", ["2f7f7a", "2f7f7a", "2f7f7a"])
	return Color(String(cols[state(frac)]))

## Era I and the colour-blind option: does pixel ([param x], [param y]) of the fill get ink?
## High = solid, mid = checker, low = sparse dots. Shape tells the state, not colour.
static func pattern_ink(st: int, x: int, y: int) -> bool:
	match st:
		State.HIGH:
			return true
		State.MID:
			return (x + y) % 2 == 0
		_:
			return x % 3 == 0 and y % 2 == 0

## Low HP blinks: is the fill hidden at time [param t] seconds?
static func blink_hidden(era: int, frac: float, t: float) -> bool:
	if not bool(for_era(era).get("blink_low", false)) or state(frac) != State.LOW or frac <= 0.0:
		return false
	return fmod(t * float(cfg().get("blink_hz", 2.0)), 1.0) >= 0.5
