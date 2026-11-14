class_name WeatherCycle
extends RefCounted
## Weather (area 3 items 1142 to 1145): one roll per region and 6-hour block of the server date,
## so every player in a region sees the same sky. The biome of the map picks the shares from
## data/weather.json (a marsh sees more fog than a scree slope). Indoors, in caves and with the
## "Weather" switch off it is always clear. From Era III on (EraFeatures "sky_battles") rain, fog
## and storms lay a Rift field on outdoor battles (battle_field()).

const KINDS: Array[String] = ["clear", "rain", "fog", "wind", "storm"]
const BLOCK_SECONDS: int = 6 * 3600
const PATH: String = "res://data/weather.json"
## Plain tints in UITheme spirit; the real look comes from area 6.
const TINTS: Dictionary = {
	"clear": Color(1, 1, 1), "rain": Color(0.86, 0.9, 0.96), "fog": Color(0.93, 0.93, 0.95),
	"wind": Color(1.0, 0.98, 0.94), "storm": Color(0.74, 0.76, 0.86),
}

static var _data: Dictionary = {}

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
