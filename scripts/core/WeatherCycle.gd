class_name WeatherCycle
extends RefCounted
## Weather (area 3 items 1142 to 1145): one roll per region and 6-hour block of the server date,
## so every player in a region sees the same sky. The biome of the map picks the shares from
## data/weather.json (a marsh sees more fog than a scree slope). Indoors, in caves and with the
## "Weather" switch off it is always clear. From Era III on (EraFeatures "sky_battles") rain, fog
## and storms lay a Rift field on outdoor battles (battle_field()).
## Around the kind (which stays what the rules read): a strength per block names a grade
## (drizzle, rain, downpour), forecast() tells the next blocks, wetness() says how far puddles
## have formed or dried, and fx_level() is the "Weather effects" setting. WeatherFx draws it.

const KINDS: Array[String] = ["clear", "rain", "fog", "wind", "storm"]
const BLOCK_SECONDS: int = 6 * 3600
const PATH: String = "res://data/weather.json"
## Plain tints in UITheme spirit; the real look comes from area 6.
const TINTS: Dictionary = {
	"clear": Color(1, 1, 1), "rain": Color(0.86, 0.9, 0.96), "fog": Color(0.93, 0.93, 0.95),
	"wind": Color(1.0, 0.98, 0.94), "storm": Color(0.74, 0.76, 0.86),
}

const FX_LEVELS: Array[String] = ["full", "low", "off"]
const FX_LEVEL_NAMES: Dictionary = {"full": "Full", "low": "Low", "off": "Off"}
## Kinds that leave the ground wet.
const WET: Array[String] = ["rain", "storm"]

static var _data: Dictionary = {}
## Overrides for the shot tool and tests: strength and wetness (below 0 = the real ones).
static var debug_strength: float = -1.0
static var debug_wet: float = -1.0

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

## Weather shares for [param biome] (falls back to "default").
static func shares(biome: String) -> Dictionary:
	var b: Dictionary = data().get("biomes", {})
	return b.get(biome, b.get("default", {"clear": 100}))

## The 6-hour block of [param unix] (same block for everyone).
static func block_of(unix: int) -> int:
	return floori(float(unix) / BLOCK_SECONDS)

## The weather in [param region] on a map of [param biome] at [param unix].
static func roll(region: String, biome: String, unix: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [region, block_of(unix)])
	var r: float = rng.randf()
	var table: Dictionary = shares(biome)
	var total: float = 0.0
	for k: String in KINDS:
		total += float(table.get(k, 0))
	if total <= 0.0:
		return "clear"
	var acc: float = 0.0
	for k: String in KINDS:
		acc += float(table.get(k, 0)) / total
		if r < acc:
			return k
	return "clear"

## Weather on [param m] now: clear indoors, in caves and dungeons, or with the switch off.
static func current(m: MapData, unix: int = -1, enabled: bool = GameState.weather) -> String:
	if m == null or not enabled or not m.outdoor or m.biome in ["cave", "dungeon"]:
		return "clear"
	if unix < 0:
		unix = Online.unix_now()
	return roll(m.region, m.biome if m.biome != "" else "default", unix)

## Strength of the weather in [param region] at [param unix], 0 to 1: one more roll per block.
static func strength(region: String, unix: int) -> float:
	if debug_strength >= 0.0:
		return clampf(debug_strength, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|1" % [region, block_of(unix)])
	return rng.randf()

## The grade row of [param kind] at [param power] (data "grades"): {"id", "amount"}. A kind
## without grades is its own grade at amount 1.
static func grade(kind: String, power: float) -> Dictionary:
	for g: Variant in (data().get("grades", {}) as Dictionary).get(kind, []):
		if power <= float((g as Dictionary).get("upto", 1.0)):
			return g
	return {"id": kind, "amount": 1.0}

## Everything about the sky over [param m]: {"kind", "grade", "amount", "strength"}.
static func state(m: MapData, unix: int = -1, enabled: bool = GameState.weather) -> Dictionary:
	if unix < 0:
		unix = Online.unix_now()
	var kind: String = current(m, unix, enabled)
	var power: float = strength(m.region, unix) if m != null and kind != "clear" else 0.0
	var g: Dictionary = grade(kind, power)
	return {"kind": kind, "grade": str(g.get("id", kind)), "amount": float(g.get("amount", 1.0)), "strength": power}

## English name of a kind, grade or look for Loc.t ("Drizzle", "Thick fog").
static func name_of(id: String) -> String:
	return str((data().get("names", {}) as Dictionary).get(id, id.capitalize()))

## The kinds of the next [param blocks] 6-hour blocks over [param m], soonest first.
static func forecast(m: MapData, blocks: int = 2, unix: int = -1, enabled: bool = GameState.weather) -> Array[String]:
	if unix < 0:
		unix = Online.unix_now()
	var out: Array[String] = []
	for i: int in range(1, blocks + 1):
		out.append(current(m, unix + i * BLOCK_SECONDS, enabled))
	return out

## Seconds until the sky is rolled again.
static func seconds_left(unix: int) -> int:
	return (block_of(unix) + 1) * BLOCK_SECONDS - unix

## How wet the ground of [param m] is, 0 to 1: it fills while rain or a storm is up (data "fx"
## "puddles" form_seconds, at once when the block before was wet too) and dries over
## dry_seconds once the sky has cleared.
static func wetness(m: MapData, unix: int = -1, enabled: bool = GameState.weather) -> float:
	if debug_wet >= 0.0:
		return clampf(debug_wet, 0.0, 1.0)
	if unix < 0:
		unix = Online.unix_now()
	var cfg: Dictionary = (data().get("fx", {}) as Dictionary).get("puddles", {})
	var since: float = float(unix - block_of(unix) * BLOCK_SECONDS)
	var before: bool = current(m, unix - BLOCK_SECONDS, enabled) in WET
	if current(m, unix, enabled) in WET:
		return 1.0 if before else clampf(since / maxf(float(cfg.get("form_seconds", 45.0)), 1.0), 0.0, 1.0)
	return clampf(1.0 - since / maxf(float(cfg.get("dry_seconds", 600.0)), 1.0), 0.0, 1.0) if before else 0.0

## True in the first minutes of a clear sky after rain (data "fx" "rainbow_seconds").
static func after_rain(m: MapData, unix: int = -1, enabled: bool = GameState.weather) -> bool:
	if unix < 0:
		unix = Online.unix_now()
	if current(m, unix, enabled) != "clear" or not current(m, unix - BLOCK_SECONDS, enabled) in WET:
		return false
	return float(unix - block_of(unix) * BLOCK_SECONDS) < float((data().get("fx", {}) as Dictionary).get("rainbow_seconds", 600.0))

## The "Weather effects" level in force: the setting, and never more than "low" while the
## battery saver is on. "off" keeps the weather and its rules but draws no drops.
static func fx_level() -> String:
	var level: String = GameState.weather_fx if GameState.weather_fx in FX_LEVELS else "full"
	return "low" if level == "full" and GameState.battery_saver else level

static func tint(kind: String) -> Color:
	return TINTS.get(kind, Color(1, 1, 1))

## Weather in battle (era function "sky_battles", opens in Era III): {"field", "intro"} that
## [param kind] lays on a battle (data/weather.json "battle"), or {} for a calm sky.
static func battle_field(kind: String) -> Dictionary:
	var b: Dictionary = data().get("battle", {})
	var f: Variant = b.get(kind, {})
	if not f is Dictionary or not BattleRules.FIELDS.has(str((f as Dictionary).get("field", ""))):
		return {}
	return f
