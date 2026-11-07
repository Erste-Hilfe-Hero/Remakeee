class_name SurveyGlass
extends RefCounted
## Survey Glass (area 3 items 1052, 1053): face open ground and press A (or tap yourself) to
## look ahead. Hidden finds up to 6 steps away in that direction (a band three cells wide)
## show as dots on the minimap. The glass needs 20 seconds between looks, so it never turns
## into a constant radar.

const ITEM: String = "survey_glass"
const RANGE: int = 6
const COOLDOWN_MS: int = 20000

static var _last_look_ms: int = -COOLDOWN_MS

## True when the glass is ready again at [param now_ms] (defaults to the engine clock).
static func ready(now_ms: int = -1) -> bool:
	var t: int = now_ms if now_ms >= 0 else Time.get_ticks_msec()
	return t - _last_look_ms >= COOLDOWN_MS

## Seconds left until the next look (0 when ready).
static func wait_left(now_ms: int = -1) -> int:
	var t: int = now_ms if now_ms >= 0 else Time.get_ticks_msec()
	return maxi(0, ceili(float(COOLDOWN_MS - (t - _last_look_ms)) / 1000.0))

static func mark_used(now_ms: int = -1) -> void:
	_last_look_ms = now_ms if now_ms >= 0 else Time.get_ticks_msec()

## Cells of hidden finds not yet taken that lie 1..6 steps from [param from] in [param dir],
## at most one cell to either side.
static func scan(m: MapData, from: Vector2i, dir: Vector2i, flags: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	var side := Vector2i(dir.y, dir.x)
	for sc: Dictionary in m.secrets:
		if bool(flags.get(str(sc.get("flag", "")), false)):
			continue
		var d: Vector2i = Vector2i(int(sc.x), int(sc.y)) - from
		var ahead: int = d.x * dir.x + d.y * dir.y
		var lateral: int = absi(d.x * side.x + d.y * side.y)
		if ahead >= 1 and ahead <= RANGE and lateral <= 1:
			out.append(Vector2i(int(sc.x), int(sc.y)))
	return out
