class_name EraLight
extends RefCounted
## Overworld light, weather look, screen effects and map transitions per era
## (data/era_light.json). Rules only; EraLightLayer draws them. A map takes the era of its own
## region, capped by the active era, so old regions keep the look they were made in.

const PATH: String = "res://data/era_light.json"
const ERAS: int = 5
## Photosensitivity cap: never more flashes than this in any one second, whatever the data says.
const HARD_MAX_FLASHES: int = 3
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
## Switches of an era row. Once on in an era they stay on in every later era.
const BOOL_KEYS: Array[String] = ["lit_windows", "splashes", "puddles", "fog_bands", "lightning", "lamp_glow",
	"light_shafts", "cloud_shadows", "snow_prints", "golden_hour", "long_shadows", "season_tint", "camera_sweep"]
const TINT_STYLES: Array[String] = ["none", "stepped", "smooth"]
const WEATHER_STYLES: Array[String] = ["pattern", "lines", "rich"]
const TRANSITIONS: Array[String] = ["cut", "fade", "base", "door_wipe", "stair_wipe"]
const WARP_KINDS: Array[String] = ["door", "stairs", "edge"]
const CAVE_EDGES: Array[String] = ["hard", "dither", "soft"]
const WET: Array[String] = ["rain", "storm"]
const OPEN_SKY: Array[String] = ["clear", "wind"]

static var _data: Dictionary = {}
## Overrides for the shot tool and tests: era (0 = none), hour (below 0 = clock), weather kind
## (empty = the real sky) and month (0 = calendar).
static var debug_era: int = 0
static var debug_hour: float = -1.0
static var debug_weather: String = ""
static var debug_month: int = 0

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

## The row of [param era] (eras past V use V, below I use I).
static func for_era(era: int) -> Dictionary:
	return (data().get("eras", {}) as Dictionary).get(str(clampi(era, 1, ERAS)), {})

static func on(era: int, key: String) -> bool:
	return bool(for_era(era).get(key, false))

## Era whose light a map of [param region] shows: its own era, never newer than the active one.
static func era_for(region: String) -> int:
	if debug_era > 0:
		return clampi(debug_era, 1, ERAS)
	return mini(EraManager.active_era(), EraManager.region_era(region))

## Game hour as a fraction (bench shifts included).
static func hour_now() -> float:
	if debug_hour >= 0.0:
		return fposmod(debug_hour, 24.0)
	var d: Dictionary = Time.get_time_dict_from_system()
	return fposmod(float(d.hour) + float(d.minute) / 60.0 + float(DayCycle.shift()), 24.0)

static func phase_at(hour: float) -> int:
	return DayCycle.phase_for_hour(int(floor(hour)))

static func month_now() -> int:
	return debug_month if debug_month > 0 else int(Online.date_now().month)

static func _color(v: Variant, fallback: Color = Color(1, 1, 1)) -> Color:
	return Color(str(v)) if v is String and not (v as String).is_empty() else fallback

## Tint of the time of day. [param lit] is false indoors or with the day-night option off.
## Era I has none; Eras II to IV step through their few tints; Era V blends over the hours.
static func day_tint(era: int, hour: float, lit: bool) -> Color:
	var row: Dictionary = for_era(era)
	var style: String = str(row.get("tint_style", "none"))
	if not lit or style == "none":
		return Color(1, 1, 1)
	if style == "smooth":
		var keys: Array = row.get("hours", [])
		for i: int in range(1, keys.size()):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			if hour <= float(b[0]):
				var span: float = maxf(float(b[0]) - float(a[0]), 0.001)
				return _color(a[1]).lerp(_color(b[1]), clampf((hour - float(a[0])) / span, 0.0, 1.0))
	return _color((row.get("tints", {}) as Dictionary).get(DayCycle.phase_name(phase_at(hour)), ""))

## How [param kind] (WeatherCycle) looks on a map: a rule of "weather_looks" may turn it into
## sandstorm, ash or snow when the era knows that look; a look the era lacks stays [param kind].
static func weather_look(era: int, map_id: String, region: String, biome: String, kind: String) -> String:
	if kind == "clear" or kind.is_empty():
		return "clear"
	var known: Array = for_era(era).get("looks", [])
	for r: Variant in data().get("weather_looks", []):
		var rule: Dictionary = r
		if str(rule.get("region", region)) != region or not kind in (rule.get("from", []) as Array):
			continue
		if rule.has("maps") and not map_id in (rule.maps as Array):
			continue
		if rule.has("biome") and str(rule.biome) != biome:
			continue
		if str(rule.to) in known:
			return str(rule.to)
	return kind if kind in known else "clear"

static func weather_tint(era: int, look: String) -> Color:
	return _color((for_era(era).get("weather_tints", {}) as Dictionary).get(look, ""))

## Season name of [param month] (1 to 12).
static func season(month: int) -> String:
	var months: Dictionary = (data().get("seasons", {}) as Dictionary).get("months", {})
	for s: String in SEASONS:
		for m: Variant in months.get(s, []):
			if int(m) == month:
				return s
	return SEASONS[0]

## Season tint of [param region] in [param month]: the region's own row or the shared one.
## White in eras without season tint.
static func season_tint(era: int, region: String, month: int) -> Color:
	if not on(era, "season_tint"):
		return Color(1, 1, 1)
	var cfg: Dictionary = data().get("seasons", {})
	var own: Dictionary = (cfg.get("regions", {}) as Dictionary).get(region, {})
	var s: String = season(month)
	return _color(own.get(s, (cfg.get("tints", {}) as Dictionary).get(s, "")))

static func is_cave(m: MapData) -> bool:
	return m != null and m.biome == "cave"

static func cave(era: int) -> Dictionary:
	return for_era(era).get("cave", {})

## The whole world tint of a map: time of day, weather and season outdoors, the cave tint in caves.
static func world_tint(era: int, m: MapData, look: String, hour: float, month: int, day_night: bool) -> Color:
	if is_cave(m):
		return _color(cave(era).get("tint", ""))
	if not m.outdoor:
		return Color(1, 1, 1)
	return day_tint(era, hour, day_night) * weather_tint(era, look) * season_tint(era, m.region, month)

## door, stairs or edge for a warp from a tile of [param tile_kind].
static func warp_kind(tile_kind: int, edge: bool) -> String:
	if tile_kind == TilesetFactory.Kind.STAIRS:
		return "stairs"
	return "edge" if edge else "door"

## Transition style of [param era] for a warp kind; base keeps the overworld's own.
static func transition(era: int, kind: String) -> String:
	return str((for_era(era).get("transition", {}) as Dictionary).get(kind, "base"))

static func is_big_place(m: MapData) -> bool:
	var cfg: Dictionary = data().get("big_place", {})
	return m != null and m.outdoor and m.biome in (cfg.get("biomes", []) as Array) and m.width * m.height >= int(cfg.get("min_cells", 0))

## True when enough of an outdoor map is trees for light shafts and falling leaves.
static func wooded(m: MapData) -> bool:
	if m == null or not m.outdoor or m.width * m.height <= 0:
		return false
	var trees: int = 0
	for row: String in m.rows:
		trees += row.count("T")
	return m.biome == "forest" or float(trees) / float(m.width * m.height) >= float(data().get("wooded_tree_share", 1.0))

## Shadow of a one-tile-high thing in tiles: long and westward after sunrise, short at noon,
## long and eastward before sunset, none at night.
static func shadow(hour: float) -> Vector2:
	var k: float = (hour - 5.5) / 14.5
	if k <= 0.0 or k >= 1.0:
		return Vector2.ZERO
	var c: float = cos(PI * k)
	return Vector2(-c * (0.4 + 1.6 * c * c), 0.3)

## 0 to 1: how deep the golden hour is (peaks shortly after sunrise and before sunset).
static func golden(hour: float) -> float:
	return maxf(0.0, 1.0 - minf(absf(hour - 6.25), absf(hour - 18.25)) / 1.5)

# --- Lightning ---------------------------------------------------------------------------

static func flash_cfg() -> Dictionary:
	return data().get("flash", {})

## Flashes allowed per second: the data value, never above HARD_MAX_FLASHES.
static func max_flashes() -> int:
	return clampi(int(flash_cfg().get("max_per_second", HARD_MAX_FLASHES)), 0, HARD_MAX_FLASHES)

## True when a flash may start at [param now] after the flashes at [param history] (seconds):
## never under reduced motion, never past the cap in the last second, never inside the gap.
static func flash_allowed(history: Array[float], now: float, reduced: bool) -> bool:
	if reduced or max_flashes() <= 0:
		return false
	var recent: int = 0
	for t: float in history:
		if now - t < 1.0:
			recent += 1
		if now - t < float(flash_cfg().get("min_gap", 0.35)):
			return false
	return recent < max_flashes()

## The flashes of a storm of [param seconds] for [param seed_value]: strikes every few seconds,
## some as a double flash, each one passed through flash_allowed().
static func strike_times(seed_value: int, seconds: float, reduced: bool = false) -> Array[float]:
	var out: Array[float] = []
	var cfg: Dictionary = flash_cfg()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t: float = 0.0
	while true:
		t += float(cfg.get("strike_every", 7.0)) * rng.randf_range(0.6, 1.4)
		if t >= seconds:
			break
		if flash_allowed(out, t, reduced):
			out.append(t)
		var second: float = t + float(cfg.get("min_gap", 0.35)) + 0.05
		if rng.randf() < float(cfg.get("double_share", 0.0)) and second < seconds and flash_allowed(out, second, reduced):
			out.append(second)
	return out

## The most flashes [param times] puts into any one-second window.
static func worst_second(times: Array[float]) -> int:
	var worst: int = 0
	for a: float in times:
		var n: int = 0
		for b: float in times:
			if b >= a and b - a < 1.0:
				n += 1
		worst = maxi(worst, n)
	return worst

# --- What a map shows -----------------------------------------------------------------------

## English line Era I shows for a weather look (for Loc.t), or empty.
static func weather_line(look: String) -> String:
	return str((data().get("weather_text", {}) as Dictionary).get(look, ""))

## Names of everything the layer draws for [param ctx]: {look, outdoor, lit (outdoor with the
## day-night option on), hour, wooded, lamps, cave, month, reduced}.
static func effects(era: int, ctx: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var row: Dictionary = for_era(era)
	var look: String = str(ctx.get("look", "clear"))
	var outdoor: bool = bool(ctx.get("outdoor", false))
	var lit: bool = bool(ctx.get("lit", false))
	var hour: float = float(ctx.get("hour", 12.0))
	var phase: int = phase_at(hour)
	var dark: bool = phase == DayCycle.Phase.DUSK or phase == DayCycle.Phase.NIGHT
	var is_wooded: bool = bool(ctx.get("wooded", false))
	var lamps: bool = bool(ctx.get("lamps", false))
	var s: String = season(int(ctx.get("month", 1)))
	var parts: Array = row.get("particles", [])
	if look != "clear":
		out.append("weather_" + str(row.get("weather_style", "pattern")))
		if bool(row.get("weather_text", false)):
			out.append("weather_text")
	if look in WET:
		for k: String in ["splashes", "puddles"]:
			if bool(row.get(k, false)):
				out.append(k)
	if look == "fog" and bool(row.get("fog_bands", false)):
		out.append("fog_bands")
	if look == "storm" and bool(row.get("lightning", false)) and not bool(ctx.get("reduced", false)):
		out.append("lightning")
	if look == "snow" and bool(row.get("snow_prints", false)):
		out.append("snow_prints")
	if lit and dark and bool(row.get("lit_windows", false)):
		out.append("lit_windows")
	if lit and dark and lamps and bool(row.get("lamp_glow", false)):
		out.append("lamp_glow")
	if lit and is_wooded and phase != DayCycle.Phase.NIGHT and look == "clear" and bool(row.get("light_shafts", false)):
		out.append("light_shafts")
	if outdoor and phase != DayCycle.Phase.NIGHT and look in OPEN_SKY and bool(row.get("cloud_shadows", false)):
		out.append("cloud_shadows")
	if lit and shadow(hour) != Vector2.ZERO and (look in OPEN_SKY or look == "snow") and bool(row.get("long_shadows", false)):
		out.append("long_shadows")
	if lit and golden(hour) > 0.0 and bool(row.get("golden_hour", false)):
		out.append("golden_hour")
	if outdoor and is_wooded and (s == "autumn" or look == "wind") and "leaves" in parts:
		out.append("leaves")
	if outdoor and look == "clear" and not dark and (s == "spring" or s == "summer") and "pollen" in parts:
		out.append("pollen")
	if lit and dark and lamps and "embers" in parts:
		out.append("embers")
	if bool(ctx.get("cave", false)):
		out.append("cave_light")
	return out

## 0 to 1 from two whole numbers; the same every run (drops, puddles and motes need no state).
static func h(i: int, salt: int) -> float:
	var n: int = (i * 374761393 + salt * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0
