class_name BattleWeather
extends Control
## The sky over a battle (era function "sky_battles", docs/ERA_FUNCTIONS.md): when the region's
## weather laid the battle's field, rain, fog or a storm shows over the field in the era's look
## (data/era_battle_feel.json "weather_*"): a few ink dots in Era I, more and longer coloured
## streaks each era, splashes on the ground and a distant flash in a storm from Era IV.
## Under reduced motion the drops stand still and nothing flashes. Presentation only.

const KINDS: Array[String] = ["rain", "fog", "storm"]

var kind: String = ""
var era: int = 1
var _time: float = 0.0
var _flash: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The weather that laid [param m]'s field: "rain", "fog", "storm" or "" (none, or a Rift field).
static func weather_of(m: BattleModel) -> String:
	if m == null or m.field_intro.is_empty():
		return ""
	var b: Dictionary = WeatherCycle.data().get("battle", {})
	for k: Variant in b:
		var f: Dictionary = b[k]
		if str(f.get("field", "")) == m.field and str(f.get("intro", "")) == m.field_intro:
			return str(k)
	return ""

func setup(p_kind: String, p_era: int) -> void:
	kind = p_kind if p_kind in KINDS else ""
	era = clampi(p_era, 1, EraBattleFeel.ERAS)
	visible = not kind.is_empty()
	set_process(visible)
	queue_redraw()

## Number of drops drawn for [param k] in [param e] (a storm pours half again as much).
static func drop_count(k: String, e: int) -> int:
	if k == "fog" or k.is_empty():
		return 0
	var n: int = int(EraBattleFeel.num(e, "weather_drops", 20))
	return n * 3 / 2 if k == "storm" else n

## Seconds between distant flashes in a storm, or 0 when the era shows none.
static func flash_every(k: String, e: int) -> float:
	if k != "storm" or not EraBattleFeel.flag(e, "weather_lightning"):
		return 0.0
	return float(EraBattleFeel.cfg().get("weather_storm_every", 4.0))

func _process(delta: float) -> void:
	if Juice.reduced():
		return
	_time += delta
	var every: float = flash_every(kind, era)
	_flash = 0.0
	if every > 0.0 and fmod(_time, every) < 0.08:
		_flash = float(EraBattleFeel.cfg().get("weather_flash_alpha", 0.22))
	queue_redraw()

func _drop_colour() -> Color:
	if not EraBattleFeel.flag(era, "weather_colour"):
		return Color(UITheme.MID, 0.9)
	return Color(0.78, 0.88, 1.0, 0.75)

func _draw() -> void:
	if kind.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	if kind == "storm":
		draw_rect(Rect2(Vector2.ZERO, size), Color(UITheme.INK, 0.14))
	if kind == "fog":
		var bands: int = int(EraBattleFeel.num(era, "weather_fog_bands", 3))
		for i: int in bands:
			var y: float = roundf(h * (0.2 + 0.6 * i / maxf(bands - 1, 1)))
			var x: float = fposmod(_time * (6.0 + i * 3.0) + i * 41.0, w + 60.0) - 60.0
			var c := Color(UITheme.BG, 0.28 if EraBattleFeel.flag(era, "weather_colour") else 0.45)
			draw_rect(Rect2(0, y - 3, w, 6), Color(c, c.a * 0.5))
			draw_rect(Rect2(roundf(x), y - 5, 60, 10), c)
		return
	var n: int = drop_count(kind, era)
	var length: int = int(EraBattleFeel.num(era, "weather_len", 2))
	var speed: float = EraBattleFeel.num(era, "weather_speed", 100.0) * (1.3 if kind == "storm" else 1.0)
	var slant: float = 0.25 if era >= 3 else 0.0
	var col: Color = _drop_colour()
	var splash: bool = EraBattleFeel.flag(era, "weather_splash")
	for i: int in n:
		var x0: float = fmod(i * 53.7 + (i % 7) * 11.0, w)
		var y0: float = fmod(i * 37.3, h)
		var y: float = fposmod(y0 + _time * speed, h)
		var x: float = fposmod(x0 - y * slant, w)
		if length <= 1:
			draw_rect(Rect2(Vector2(x, y).round(), Vector2.ONE), col)
		else:
			draw_line(Vector2(x, y).round(), Vector2(x + slant * length, y - length).round(), col, 1.0)
		if splash and y > h * 0.75 and i % 3 == 0:
			var k: float = (y - h * 0.75) / (h * 0.25)
			draw_rect(Rect2(Vector2(x - 1.0 - k * 2.0, y).round(), Vector2(1, 1)), Color(col, 0.6 * (1.0 - k)))
			draw_rect(Rect2(Vector2(x + 1.0 + k * 2.0, y).round(), Vector2(1, 1)), Color(col, 0.6 * (1.0 - k)))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.95, _flash))
