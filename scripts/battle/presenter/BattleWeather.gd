class_name BattleWeather
extends Control
## The sky over a battle (era function "sky_battles", docs/ERA_FUNCTIONS.md): when the region's
## weather laid the battle's field, rain, fog or a storm shows over the field in the era's look
## (data/era_battle_feel.json "weather_*"): a few ink dots in Era I, more and longer coloured
## streaks each era, splashes on the ground and a distant flash in a storm from Era IV.
## Under reduced motion the drops stand still and nothing flashes. Presentation only.
## Wind lays no field: a windy sky only marks the battle (SKY_META) and shows drifting lines,
## leaves from Era II, rolling dust from Era IV and gusts in Era V ("wind_*" keys).

const KINDS: Array[String] = ["rain", "fog", "storm", "wind"]
## Meta on the BattleModel for a sky that changes the look only (set by the overworld).
const SKY_META: StringName = &"sky_look"

var kind: String = ""
var era: int = 1
var _time: float = 0.0
var _flash: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The weather that laid [param m]'s field: "rain", "fog", "storm" or "" (none, or a Rift field).
## "wind" when the sky is windy and no field lies on the battle.
static func weather_of(m: BattleModel) -> String:
	if m == null:
		return ""
	if m.field.is_empty() and str(m.get_meta(SKY_META, "")) == "wind":
		return "wind"
	if m.field_intro.is_empty():
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
	if k == "fog" or k == "wind" or k.is_empty():
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
	if kind == "wind":
		_draw_wind()
		return
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

# --- Wind ---------------------------------------------------------------------------

## Wind lines and leaves drawn in [param e].
static func wind_lines(e: int) -> int:
	return int(EraBattleFeel.num(e, "wind_lines", 0))

static func wind_leaves(e: int) -> int:
	return int(EraBattleFeel.num(e, "wind_leaves", 0))

## Pixels the wind has carried things after [param t] seconds in [param e]. Era V blows in
## gusts: the pace swells and eases but never turns back.
static func wind_travel(e: int, t: float) -> float:
	var speed: float = EraBattleFeel.num(e, "wind_speed", 40.0)
	if not EraBattleFeel.flag(e, "wind_gust"):
		return speed * t
	var wind: Dictionary = EraBattleFeel.cfg().get("wind", {})
	var depth: float = clampf(float(wind.get("gust_depth", 0.4)), 0.0, 0.9)
	var om: float = TAU / maxf(float(wind.get("gust_period", 3.5)), 0.1)
	return speed * (t + depth * (1.0 - cos(om * t)) / om)

## Where part [param i] of the wind ("line", "leaf" or "dust") is at time [param t] on a field
## of [param field] pixels. Lines stay in the wind band, leaves sink slowly and wrap, dust rolls
## along the ground. Whole pixels; Era I moves in 2 px steps.
static func wind_pos(part: String, i: int, e: int, t: float, field: Vector2) -> Vector2:
	var wind: Dictionary = EraBattleFeel.cfg().get("wind", {})
	var band: Array = wind.get("band", [0.1, 0.9])
	var top: float = field.y * float(band[0])
	var span: float = maxf(field.y * (float(band[1]) - float(band[0])), 1.0)
	var step: float = maxf(EraBattleFeel.num(e, "wind_step", 1.0), 1.0)
	var go: float = wind_travel(e, t)
	var x: float = 0.0
	var y: float = 0.0
	match part:
		"leaf":
			x = fposmod(i * 61.3 + 17.0 + go * (0.7 + 0.1 * (i % 3)), field.x)
			y = top + fposmod(i * 43.9 + go * float(wind.get("leaf_fall", 0.18)), span)
			y += sin(go * 0.08 + i) * 2.0
		"dust":
			x = fposmod(i * 29.7 + go * 1.2, field.x)
			y = field.y * float(band[1]) - (i % 3) * 2.0
		_:
			x = fposmod(i * 47.1 + (i % 5) * 13.0 + go * (1.0 + 0.15 * (i % 4)), field.x)
			y = top + fposmod(i * 37.3, span)
	return Vector2(floorf(x / step) * step, clampf(roundf(y), 0.0, field.y - 1.0))

func _wind_colour(key: String, alpha: float = 1.0) -> Color:
	if not EraBattleFeel.flag(era, "weather_colour"):
		return Color(UITheme.MID if key == "wind" else UITheme.INK, 0.9)
	var cols: Dictionary = (EraBattleFeel.cfg().get("move_fx", {}) as Dictionary).get("colours", {})
	return Color(Color(str(cols.get(key, "eef2f4"))), alpha)

func _draw_wind() -> void:
	var wind: Dictionary = EraBattleFeel.cfg().get("wind", {})
	var length: float = EraBattleFeel.num(era, "wind_len", 4.0)
	var wave: bool = EraBattleFeel.flag(era, "wind_wave")
	var col: Color = _wind_colour("wind", float(wind.get("line_alpha", 0.55)))
	# From Era II a faint shade under each white line keeps it readable on a pale sky or meadow.
	var shade: Color = Color(UITheme.INK, float(wind.get("shade_alpha", 0.0)))
	for i: int in wind_lines(era):
		var p: Vector2 = wind_pos("line", i, era, _time, size)
		# Every third line is a short one, so the wind does not look ruled.
		var len_i: float = roundf(length * (0.5 if i % 3 == 2 else 1.0))
		if EraBattleFeel.flag(era, "weather_colour"):
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(len_i, 1)), shade)
		if not wave:
			draw_rect(Rect2(p, Vector2(len_i, 1)), col)
			continue
		var third: float = roundf(len_i / 3.0)
		draw_rect(Rect2(p, Vector2(third, 1)), Color(col, col.a * 0.6))
		draw_rect(Rect2(p + Vector2(third, -1), Vector2(third, 1)), col)
		draw_rect(Rect2(p + Vector2(third * 2.0, 0), Vector2(third, 1)), col)
	var big: bool = era >= 4
	for i: int in wind_leaves(era):
		var p: Vector2 = wind_pos("leaf", i, era, _time, size)
		var lc: Color = _wind_colour("leaf" if i % 2 == 0 else "leaf_dry")
		# Leaves tumble: the shape flips between lying and standing.
		var flip: bool = int(_time * 5.0 + i) % 2 == 0
		var sz: Vector2 = Vector2(3, 2) if big else Vector2(2, 1)
		draw_rect(Rect2(p, sz if flip else Vector2(sz.y, sz.x)), lc)
		if era >= 3:
			draw_rect(Rect2(p + (Vector2(sz.x, 0) if flip else Vector2(0, sz.x)), Vector2.ONE), Color(lc.darkened(0.3), lc.a))
	if EraBattleFeel.flag(era, "wind_dust"):
		var dc: Color = _wind_colour("dust", 0.7)
		for i: int in wind_lines(era) / 2:
			var p: Vector2 = wind_pos("dust", i, era, _time, size)
			draw_rect(Rect2(p, Vector2(2, 1)), dc)
			draw_rect(Rect2(p + Vector2(3, -1), Vector2.ONE), Color(dc, dc.a * 0.6))
