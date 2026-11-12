class_name EraBattleFeel
extends RefCounted
## How a battle looks and moves in each era (data/era_battle_feel.json, docs/ERA_FEEL_BATTLE.md):
## intro wipe, entrance, idle level, hit reaction, faint, backdrop, HP drain, art animation tier,
## shake and camera. Pure helpers so tests need no scene. Presentation only, never rules.

const PATH: String = "res://data/era_battle_feel.json"
const ERAS: int = 5

static var _cfg: Dictionary = {}

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"eras": {}}
	return _cfg

## The whole entry for [param era]; eras past the table use the newest one.
static func for_era(era: int) -> Dictionary:
	return (cfg().get("eras", {}) as Dictionary).get(str(clampi(era, 1, ERAS)), {})

static func value(era: int, key: String, fallback: Variant = null) -> Variant:
	return for_era(era).get(key, fallback)

static func num(era: int, key: String, fallback: float = 0.0) -> float:
	return float(for_era(era).get(key, fallback))

static func flag(era: int, key: String) -> bool:
	return bool(for_era(era).get(key, false))

static func text(era: int, key: String, fallback: String = "") -> String:
	return str(for_era(era).get(key, fallback))

## Position of [param style] in the ordered list [param list_key] (later = richer), -1 if unknown.
static func rank(list_key: String, style: String) -> int:
	return (cfg().get(list_key, []) as Array).find(style)

## Idle level 0 (still) .. 4 (constant loop) of [param era].
static func idle_level(era: int) -> int:
	return maxi(rank("idle_levels", text(era, "idle", "none")), 0)

## Does the Spirling bob or breathe while waiting? Only from the breathing era on.
static func idles(era: int) -> bool:
	return idle_level(era) >= rank("idle_levels", "breath")

## Hit flash as a white silhouette (III, IV) instead of a blink (I, II).
static func silhouette_hit(era: int) -> bool:
	return text(era, "hit") == "flash"

## How a Spirling lunges into a physical art: "step" (I, II: there and back in two hard steps),
## "tween" (III) or "stretch" (IV, V: it stretches into the lunge).
static func lunge_style(era: int) -> String:
	return text(era, "lunge", "tween")

## Drawn scale during the forward half of a lunge: wider and flatter in the stretch eras.
static func lunge_scale(era: int) -> Vector2:
	var k: float = num(era, "lunge_stretch", 0.0) if lunge_style(era) == "stretch" else 0.0
	return Vector2(1.0 + k, 1.0 - k * 0.5)

## Screen-shake factor for [param era] (I chunky and small, V strongest).
static func shake(era: int) -> float:
	return num(era, "shake", 1.0)

## Camera settings of [param era]: {} when fixed. "dynamic" takes data/era5_anim.json "camera".
static func camera(era: int) -> Dictionary:
	var c: Dictionary = (cfg().get("cameras", {}) as Dictionary).get(text(era, "camera", "fixed"), {})
	if str(c.get("from", "")) == "era5_anim":
		return (BattleAnim.config().get("camera", {}) as Dictionary).duplicate()
	return c.duplicate()

static func camera_on(era: int) -> bool:
	return float(camera(era).get("zoom", 1.0)) > 1.0

## Seconds the HP bar takes to move from [param from_frac] to [param to_frac] of the bar. Step
## eras (I, II) drain at a fixed pace across the bar, like an old screen counting down; later
## eras ease in [param smooth_time] whatever the amount.
static func hp_drain_time(era: int, from_frac: float, to_frac: float, smooth_time: float) -> float:
	if text(era, "hp_drain", "smooth") != "step":
		return smooth_time
	return maxf(absf(from_frac - to_frac) * num(era, "hp_step_time", 1.0), 0.05)

## Whole-pixel steps for step-drain eras: the bar ticks one pixel at a time.
static func hp_steps(era: int) -> bool:
	return text(era, "hp_drain", "smooth") == "step"

# --- Art animations ---------------------------------------------------------------

## Animation style of an art: by a word in its name (data "move_style_words"), an explicit
## override, else by kind. Every art gets one in every era.
static func move_style(mv: MoveData) -> String:
	if mv == null:
		return "strike"
	var over: Dictionary = cfg().get("move_style_overrides", {})
	if over.has(mv.move_name):
		return str(over[mv.move_name])
	var words: PackedStringArray = mv.move_name.to_lower().replace("-", " ").split(" ", false)
	var table: Dictionary = cfg().get("move_style_words", {})
	# Last word first: "Glowglass Slash" is a slash, "Bloom Burst" a burst. Whole words win
	# over endings ("Spray" is a wave, not a "ray"); endings catch "Boltglass", "Biter".
	for whole: bool in [true, false]:
		for i: int in range(words.size() - 1, -1, -1):
			for style: String in table:
				for w: Variant in table[style]:
					if (words[i] == str(w)) if whole else words[i].ends_with(str(w)):
						return style
	var kinds: Dictionary = cfg().get("kind_default_style", {})
	return str(kinds.get(MoveData.Kind.keys()[mv.kind], "strike"))

## Everything an art needs to draw itself in [param era]: element, kind, style and the era's
## effect tier with its extras (colour, field tint, trail, dust, camera).
static func move_anim(mv: MoveData, era: int) -> Dictionary:
	var e: Dictionary = for_era(era)
	return {
		"element": mv.element if mv != null else -1,
		"kind": mv.kind if mv != null else MoveData.Kind.PHYSICAL,
		"style": move_style(mv),
		"tier": int(e.get("fx_tier", 1)),
		"colour": bool(e.get("fx_colour", false)),
		"tint": float(e.get("fx_tint", 0.0)),
		"trail": bool(e.get("fx_trail", false)),
		"dust": bool(e.get("fx_dust", false)),
		"camera": camera_on(era),
	}

## Number of features switched on in [param era], for the "later eras never have fewer" rule.
static func feature_score(era: int) -> int:
	var e: Dictionary = for_era(era)
	var n: int = int(e.get("fx_tier", 0)) + idle_level(era)
	for k: String in ["shadow", "parallax", "fx_colour", "fx_trail", "fx_dust"]:
		n += 1 if bool(e.get(k, false)) else 0
	n += 1 if float(e.get("fx_tint", 0.0)) > 0.0 else 0
	n += 1 if camera_on(era) else 0
	n += int(e.get("level_glints", 0)) / 2
	return n

## Colour roles for the flat backdrop of [param era] at [param terrain]: {} for Era I (the
## screen inks come from the palette filter) and for the stage eras.
static func backdrop_colours(era: int, terrain: String) -> Dictionary:
	var byera: Dictionary = (cfg().get("backdrop_colours", {}) as Dictionary).get(str(clampi(era, 1, ERAS)), {})
	return byera.get(terrain, byera.get("field", {}))

## Era IV/V stage colours for [param terrain] (lake water floor, ember dusk ...).
static func stage_terrain(terrain: String) -> Dictionary:
	return (cfg().get("stage_terrain", {}) as Dictionary).get(terrain, {})

## Status tag look in [param era]: Era I plain ink letters, from Era II a coloured badge with
## light letters. Returns the badge colour, or transparent for plain letters.
static func status_badge(era: int, status: String) -> Color:
	if status.is_empty() or era < int(cfg().get("status_badge_from_era", 2)):
		return Color.TRANSPARENT
	return Color(str((cfg().get("status_colours", {}) as Dictionary).get(status, "6a4256")))
