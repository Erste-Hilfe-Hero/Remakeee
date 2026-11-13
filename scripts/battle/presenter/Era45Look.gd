class_name Era45Look
extends RefCounted
## Look of the Era IV/V battle stage (data/era45_stage.json, docs/ERA_FEEL_BATTLE.md slice 5):
## which painted scene a battle stands in, its colours per era (Era V washed toward golden hour),
## and how big a Spirling is drawn (a whole multiple of its art, so pixels stay crisp).
## Pure helpers, so tests need no scene. Presentation only, never rules.

const PATH: String = "res://data/era45_stage.json"
const SCENES: Array[String] = ["meadow", "cave", "water", "town", "snow", "ember", "voice"]
## Colour keys every scene sets.
const COLOUR_KEYS: Array[String] = ["sky_top", "sky_low", "cloud", "cloud_shade", "sun", "distant", "far", "far_rim",
	"mid", "mid_dark", "mid_rim", "ground_far", "ground_near", "tuft", "tuft_light", "top", "top_light", "top_dark",
	"side", "side_dark", "shadow", "accent", "accent2"]
## Colours the golden-hour grade leaves alone (lamps, embers, crystals keep their own glow).
const UNGRADED: Array[String] = ["accent", "accent2", "sun"]

## Tools and tests: a biome to use instead of the current map's.
static var biome_override: String = ""
static var _cfg: Dictionary = {}
static var _biomes: Dictionary = {}

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"eras": {}, "scenes": {}}
	return _cfg

## Era entry; Era IV below, Era V for anything newer.
static func era_look(era: int) -> Dictionary:
	return (cfg().get("eras", {}) as Dictionary).get(str(clampi(era, 4, 5)), {})

## The scene for a battle on [param terrain] (the map's backdrop) in a map of [param biome].
static func scene_for(terrain: String, biome: String) -> String:
	var r: Dictionary = cfg().get("scene_rules", {})
	var first: Dictionary = r.get("biome_first", {})
	if first.has(biome):
		return str(first[biome])
	var by_terrain: Dictionary = r.get("terrain", {})
	if by_terrain.has(terrain):
		return str(by_terrain[terrain])
	var by_biome: Dictionary = r.get("biome", {})
	if by_biome.has(biome):
		return str(by_biome[biome])
	return str(r.get("default", "meadow"))

static func scene(name: String) -> Dictionary:
	var all: Dictionary = cfg().get("scenes", {})
	return all.get(name, all.get("meadow", {}))

## Biome of the map the battle started on ("" when unknown).
static func current_biome() -> String:
	if not biome_override.is_empty():
		return biome_override
	var id: String = GameState.current_map
	if not _biomes.has(id):
		var path: String = "res://data/maps/%s.json" % id
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_biomes[id] = str((raw as Dictionary).get("biome", "")) if raw is Dictionary else ""
	return str(_biomes[id])

## Colours of [param scene_name] in [param era]: Era V washes them toward its golden-hour colour
## and warms the sky at the horizon of outdoor scenes.
static func palette(scene_name: String, era: int) -> Dictionary:
	var s: Dictionary = scene(scene_name)
	var e: Dictionary = era_look(era)
	var g: Dictionary = e.get("grade", {})
	var gc := Color(str(g.get("colour", "ffffff")))
	var ga: float = float(g.get("amount", 0.0))
	if not bool(s.get("outdoor", true)):
		ga *= float(g.get("indoor", 1.0))
	var out: Dictionary = {}
	for k: String in COLOUR_KEYS:
		var c := Color(str((s.get("colours", {}) as Dictionary).get(k, "ff00ff")))
		out[k] = c if k in UNGRADED else c.lerp(gc, ga)
	if bool(s.get("outdoor", true)):
		var h: Dictionary = e.get("horizon_glow", {})
		out["sky_low"] = (out["sky_low"] as Color).lerp(Color(str(h.get("colour", "ffffff"))), float(h.get("amount", 0.0)))
	return out

## Drawn size for art [param art_px] wide aiming at [param target] px: the nearest whole multiple
## of the art, at least 1x, at most [param max_px] (unless the art itself is bigger).
static func snap_px(target: float, art_px: float, max_px: float) -> float:
	if art_px <= 0.0:
		return roundf(target)
	var k: int = maxi(1, roundi(target / art_px))
	while k > 1 and k * art_px > max_px:
		k -= 1
	return k * art_px

## On-screen size of a Spirling of art [param art_px] on [param side] ("foe"/"player") in [param era].
static func sprite_px(era: int, side: String, art_px: float) -> float:
	var s: Dictionary = era_look(era).get("sprite", {})
	return snap_px(float(s.get(side, 96)), art_px, float(s.get("max", 192)))

## Era V: does the stage move (clouds, grass, water)? Never under reduced motion.
static func animates(era: int, reduced: bool) -> bool:
	return bool(era_look(era).get("animate", false)) and not reduced

## Deterministic 0..1 noise for scene item [param i] (same picture every run).
static func hash01(i: int, salt: int = 0) -> float:
	var v: float = sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floorf(v)
