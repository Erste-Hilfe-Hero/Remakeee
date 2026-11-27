class_name WeatherFx
extends RefCounted
## Draws the weather (data/weather.json "fx") for EraLightLayer: rain in angled streaks at up to
## three depths, splashes on the ground and rings on water, puddles that grow and dry, snow that
## settles, fog banks in layers, wind with leaves and a wave through the grass, cloud shadows
## and a rainbow after rain. Every place comes from the clock and a hash, so nothing is stored
## per drop and nothing is allocated while painting; textures are built once and kept.
## The colours are the era's own (Era I: the four inks of the region, moving in steps).

const TILE: int = 16
const F_GROUND: int = 1
const F_WATER: int = 2
const F_GRASS: int = 4
const F_TALL: int = 8
const GROUND_KINDS: Array[int] = [TilesetFactory.Kind.GRASS, TilesetFactory.Kind.PATH, TilesetFactory.Kind.FLOWER,
	TilesetFactory.Kind.SCREE, TilesetFactory.Kind.TALL_GRASS, TilesetFactory.Kind.STAIRS, TilesetFactory.Kind.PIER,
	TilesetFactory.Kind.PLANK, TilesetFactory.Kind.REEDS]
const WATER_KINDS: Array[int] = [TilesetFactory.Kind.WATER, TilesetFactory.Kind.WADE, TilesetFactory.Kind.SPRING]
const GRASS_KINDS: Array[int] = [TilesetFactory.Kind.GRASS, TilesetFactory.Kind.TALL_GRASS, TilesetFactory.Kind.REEDS,
	TilesetFactory.Kind.FLOWER]
const FALLING: Array[String] = ["rain", "storm", "snow"]
const PUDDLE_SHAPES: int = 4
const PUDDLE_STAGES: int = 3
const SNOW_STAGES: int = 3
## Side of a rain sheet in px.
const SHEET: int = 128
const RAINBOW: Array[Color] = [Color("e8505a"), Color("f0a040"), Color("f0e060"), Color("60c878"), Color("5890e0"), Color("9068c8")]

## One look of data "fx" "looks", read once.
class Look:
	var n: PackedInt32Array = []
	var length: PackedInt32Array = []
	var vx: PackedFloat32Array = []
	var vy: PackedFloat32Array = []
	var bank_n: PackedInt32Array = []
	var bank_speed: PackedFloat32Array = []
	var bank_alpha: PackedFloat32Array = []
	var splashes: int = 0
	var veil: float = 0.0
	var clouds: float = 0.0
	var sway: float = 0.0
	var streaks: int = 0
	var leaves: int = 0
	var speed: float = 0.0

var map: MapData
var era: int = 0
var region: String = ""
## Share of the drops drawn: the "Weather effects" level (0 = draw nothing).
var density: float = 1.0
var low: bool = false
var depths: int = 3
var soft: bool = true
var step_fps: float = 0.0
var rain: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]
var snow: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]
var leaf: Array[Color] = [Color.WHITE]
var splash: Color = Color.WHITE
var ripple: Color = Color.WHITE
var fog: Color = Color.WHITE
var fog_alpha: float = 0.3
var veil: Color = Color.BLACK
var puddle: Color = Color.BLUE
var puddle_rim: Color = Color.BLUE
var shine: Color = Color.WHITE
var streak: Color = Color.WHITE
var gust: Color = Color.WHITE
var cloud: Color = Color.BLACK
## Cells that can hold a puddle, with the wetness each one needs and its shape.
var puddle_x: PackedInt32Array = []
var puddle_y: PackedInt32Array = []
var puddle_from: PackedFloat32Array = []
var puddle_shape: PackedByteArray = []

var _flags: PackedByteArray = []
var _w: int = 0
var _h: int = 0
var _map_id: String = ""
var _looks: Dictionary[String, Look] = {}
var _tex: Dictionary[String, Texture2D] = {}
var _area: float = 1.0
var _pal_key: String = ""

static func cfg() -> Dictionary:
	return WeatherCycle.data().get("fx", {})

## Seconds one weather takes to glide into the next.
static func fade_seconds() -> float:
	return maxf(float(cfg().get("fade_seconds", 5.0)), 0.01)

## Share of the drops at "Weather effects" [param level].
static func density_of(level: String) -> float:
	return clampf(float((cfg().get("density", {}) as Dictionary).get(level, 1.0)), 0.0, 1.0)

static func _rgba(v: Variant, fallback: Color = Color.WHITE) -> Color:
	return Color(str(v)) if v is String and not (v as String).is_empty() else fallback

## Takes over [param m] in the colours of [param e] at "Weather effects" [param level].
func setup(m: MapData, e: int, level: String) -> void:
	density = density_of(level)
	low = level != "full"
	map = m
	if m == null:
		return
	var key: String = "%d|%s" % [e, m.region]
	if key != _pal_key:
		_pal_key = key
		era = e
		region = m.region
		_read_palette()
		_tex.clear()
	if m.id != _map_id or _flags.size() != m.width * m.height:
		_map_id = m.id
		_scan()

func _read_palette() -> void:
	var row: Dictionary = (cfg().get("eras", {}) as Dictionary).get(str(clampi(era, 1, EraLight.ERAS)), {})
	depths = clampi(int(row.get("depths", 3)), 1, 3)
	soft = bool(row.get("soft", true))
	step_fps = float(row.get("step_fps", 0.0))
	if bool(row.get("inks", false)):
		# Era I: nothing but the four inks, darkest first.
		var inks: Array[Color] = EraManager.inks_for(region)
		rain = [inks[1], inks[0], inks[0]]
		snow = [inks[3], inks[3], inks[3]]
		leaf = [inks[1], inks[0]]
		splash = inks[3]
		ripple = inks[3]
		fog = inks[3]
		fog_alpha = 1.0
		veil = inks[0]
		puddle = inks[1]
		puddle_rim = inks[0]
		shine = inks[3]
		streak = inks[3]
		gust = inks[3]
		cloud = inks[0]
		return
	rain = _colors(row.get("rain", []), 3)
	snow = _colors(row.get("snow", []), 3)
	leaf = _colors(row.get("leaf", []), 1)
	splash = _rgba(row.get("splash", ""))
	ripple = _rgba(row.get("ripple", ""))
	fog = _rgba(row.get("fog", ""))
	fog_alpha = float(row.get("fog_alpha", 0.3))
	veil = _rgba(row.get("veil", ""), Color(0.1, 0.15, 0.3))
	puddle = _rgba(row.get("puddle", ""), Color(0.2, 0.3, 0.5, 0.55))
	puddle_rim = _rgba(row.get("puddle_rim", ""), Color(0.1, 0.16, 0.3, 0.55))
	shine = _rgba(row.get("shine", ""))
	streak = _rgba(row.get("streak", ""))
	gust = _rgba(row.get("gust", ""))
	cloud = _rgba(row.get("cloud", ""), Color(0.05, 0.07, 0.2))

static func _colors(v: Variant, at_least: int) -> Array[Color]:
	var out: Array[Color] = []
	if v is Array:
		for c: Variant in v:
			out.append(_rgba(c))
	while out.size() < at_least:
		out.append(Color.WHITE)
	return out

## Reads the map once: which cells are open ground, water or grass, and where puddles can lie.
func _scan() -> void:
	_w = map.width
	_h = map.height
	_flags.resize(_w * _h)
	_flags.fill(0)
	puddle_x.clear()
	puddle_y.clear()
	puddle_from.clear()
	puddle_shape.clear()
	var pc: Dictionary = cfg().get("puddles", {})
	var path_share: float = float(pc.get("path_share", 0.1))
	var grass_share: float = float(pc.get("grass_share", 0.03))
	var salt: int = absi(hash(map.id)) % 9973
	for y: int in _h:
		for x: int in mini(_w, map.rows[y].length()):
			var k: int = TilesetFactory.kind_for(map.rows[y][x])
			var f: int = 0
			if k in GROUND_KINDS:
				f |= F_GROUND
			if k in WATER_KINDS:
				f |= F_WATER
			if k in GRASS_KINDS:
				f |= F_GRASS
			if k in GRASS_KINDS and k != TilesetFactory.Kind.GRASS:
				f |= F_TALL
			_flags[y * _w + x] = f
			var share: float = path_share if k == TilesetFactory.Kind.PATH else (grass_share if k == TilesetFactory.Kind.GRASS else 0.0)
			if share > 0.0 and EraLight.h(x * 131 + y, salt) < share:
				puddle_x.append(x)
				puddle_y.append(y)
				# The first puddles show at once, the last ones only when it has rained a while.
				puddle_from.append(0.55 * EraLight.h(x * 17 + y * 3, salt + 1))
				puddle_shape.append(int(EraLight.h(x + y * 29, salt + 2) * PUDDLE_SHAPES * 2.0) % (PUDDLE_SHAPES * 2))

func flags_at(x: int, y: int) -> int:
	return _flags[y * _w + x] if x >= 0 and y >= 0 and x < _w and y < _h else 0

## Tells the painter how big the screen is: counts are for 144x256 and grow with the area.
func set_view(vs: Vector2) -> void:
	var base: float = maxf(float(cfg().get("base_area", 36864.0)), 1.0)
	_area = clampf(vs.x * vs.y / base, 1.0, float(cfg().get("max_area_scale", 2.6)))

## The clock the drops follow: the real one, in steps in Era I.
func clock(t: float) -> float:
	return floorf(t * step_fps) / step_fps if step_fps > 0.0 else t

func look_of(name: String) -> Look:
	if _looks.has(name):
		return _looks[name]
	var raw: Dictionary = (cfg().get("looks", {}) as Dictionary).get(name, {})
	var l := Look.new()
	for row: Variant in raw.get("layers", []):
		var a: Array = row
		l.n.append(int(a[0]))
		l.length.append(int(a[1]))
		l.vx.append(float(a[2]))
		l.vy.append(float(a[3]))
	for row: Variant in raw.get("banks", []):
		var a: Array = row
		l.bank_n.append(int(a[0]))
		l.bank_speed.append(float(a[1]))
		l.bank_alpha.append(float(a[2]))
	l.splashes = int(raw.get("splashes", 0))
	l.veil = float(raw.get("veil", 0.0))
	l.clouds = float(raw.get("clouds", 0.0))
	l.sway = float(raw.get("sway", 0.0))
	l.streaks = int(raw.get("streaks", 0))
	l.leaves = int(raw.get("leaves", 0))
	l.speed = float(raw.get("speed", 0.0))
	_looks[name] = l
	return l

## The layers of [param l] this era draws: the nearest ones when it has fewer depths.
func first_layer(l: Look) -> int:
	return maxi(0, l.n.size() - depths)

## Drops of layer [param layer] on screen: the data count by screen area, the level, how far
## the weather has faded in ([param amount], 0 to 1) and its grade ([param power]).
func count(l: Look, layer: int, amount: float, power: float) -> int:
	if layer < 0 or layer >= l.n.size() or density <= 0.0:
		return 0
	# A drizzle loses its big near drops first, a downpour gains them.
	var near: float = power if layer == l.n.size() - 1 and l.n.size() > 1 else 1.0
	return int(roundf(l.n[layer] * _area * density * clampf(amount, 0.0, 1.0) * power * near))

func _scaled(n: int, amount: float, power: float = 1.0) -> int:
	return int(roundf(n * _area * density * clampf(amount, 0.0, 1.0) * power))

# --- On the screen --------------------------------------------------------------------------

## Rain, snow, fog or wind over the [param vs] screen. [param amount] fades the look in and out,
## [param power] is its grade, [param dim] the light left under the day tint (1 at noon).
func paint_screen(c: CanvasItem, vs: Vector2, look: String, amount: float, power: float, t: float, dim: float) -> void:
	if density <= 0.0 or amount <= 0.0:
		return
	var l: Look = look_of(look)
	t = clock(t)
	if l.veil > 0.0 and soft:
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(veil, l.veil * amount * minf(power, 1.2)))
	match look:
		"rain", "storm":
			_paint_rain(c, vs, l, amount, power, t, dim)
		"snow":
			_paint_snow(c, vs, l, amount, power, t, dim)
		"fog":
			_paint_fog(c, vs, l, amount, power, t, dim)
		"wind":
			_paint_wind(c, vs, l, amount, power, t, dim)

func _lit(col: Color, dim: float) -> Color:
	return Color(col.r * dim, col.g * dim, col.b * dim, col.a)

## Rain: every depth is one sheet of streaks that tiles over the screen and slides along its
## fall line, so a downpour costs as few draw calls as a drizzle.
func _paint_rain(c: CanvasItem, vs: Vector2, l: Look, amount: float, power: float, t: float, dim: float) -> void:
	var last: int = l.n.size() - 1
	for layer: int in range(first_layer(l), l.n.size()):
		var per_tile: int = sheet_count(l, layer, power)
		if per_tile <= 0:
			continue
		var tex: Texture2D = rain_tex(l, layer, per_tile, layer == last and soft)
		var col: Color = _lit(rain[mini(layer, rain.size() - 1)], dim)
		col.a *= clampf(amount, 0.0, 1.0)
		var shift := Vector2(floorf(fposmod(l.vx[layer] * t, SHEET)), floorf(fposmod(l.vy[layer] * t, SHEET)))
		c.draw_texture_rect(tex, Rect2(shift - Vector2(SHEET, SHEET), vs + Vector2(SHEET, SHEET) * 2.0), true, col)

## Streaks on one sheet of layer [param layer]: the data count is for a 144x256 screen.
func sheet_count(l: Look, layer: int, power: float) -> int:
	if layer < 0 or layer >= l.n.size() or density <= 0.0:
		return 0
	var near: float = power if layer == l.n.size() - 1 and l.n.size() > 1 else 1.0
	var base: float = maxf(float(cfg().get("base_area", 36864.0)), 1.0)
	return int(roundf(l.n[layer] * SHEET * SHEET / base * density * power * near))

func _paint_snow(c: CanvasItem, vs: Vector2, l: Look, amount: float, power: float, t: float, dim: float) -> void:
	var w: float = vs.x + 16.0
	var h: float = vs.y + 8.0
	for layer: int in range(first_layer(l), l.n.size()):
		var n: int = count(l, layer, amount, power)
		var size: float = float(l.length[layer])
		var col: Color = _lit(snow[mini(layer, snow.size() - 1)], dim)
		var salt: int = 200 + layer * 10
		for i: int in n:
			var k: float = 0.8 + 0.4 * EraLight.h(i, salt + 2)
			var x: float = fposmod(EraLight.h(i, salt) * w + l.vx[layer] * k * t + sin(t * (0.9 + k) + i) * l.sway, w) - 8.0
			var y: float = fposmod(EraLight.h(i, salt + 1) * h + l.vy[layer] * k * t, h) - 4.0
			c.draw_rect(Rect2(floorf(x), floorf(y), size, size), col)

func _paint_fog(c: CanvasItem, vs: Vector2, l: Look, amount: float, power: float, t: float, dim: float) -> void:
	var col: Color = _lit(fog, dim)
	var a: float = fog_alpha * amount * minf(power, 1.4)
	if fog_alpha < 1.0:
		# Every era with see-through colours lays a thin veil under its banks (Era I has inks only).
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(col, l.veil * amount * power))
	var row: int = 0
	var rows: int = 0
	for layer: int in l.bank_n.size():
		rows += l.bank_n[layer]
	rows = maxi(1, int(roundf(rows * _area / 1.6)))
	var idx: int = 0
	for layer: int in l.bank_n.size():
		if low and layer == 0:
			continue
		var tex: Texture2D = bank_tex(layer)
		var size: Vector2 = tex.get_size()
		var n: int = maxi(1, int(roundf(l.bank_n[layer] * _area / 1.6)))
		var span: float = vs.x + size.x
		for i: int in n:
			var salt: int = 300 + layer * 10
			var x: float = fposmod(EraLight.h(i, salt) * span + l.bank_speed[layer] * (0.8 + 0.4 * EraLight.h(i, salt + 1)) * t, span) - size.x
			# Banks of the layers interleave down the screen, so no stripe stays empty.
			row = (idx * 5) % rows
			var y: float = vs.y * (float(row) + 0.5 * EraLight.h(i, salt + 2)) / rows - size.y * 0.3 + sin(t * 0.25 + idx) * 2.0
			c.draw_texture(tex, Vector2(floorf(x), floorf(y)), Color(col, a * l.bank_alpha[layer]))
			idx += 1

func _paint_wind(c: CanvasItem, vs: Vector2, l: Look, amount: float, power: float, t: float, dim: float) -> void:
	var w: float = vs.x + 60.0
	var col: Color = _lit(streak, dim)
	for i: int in _scaled(l.streaks, amount, power):
		var k: float = 0.75 + 0.5 * EraLight.h(i, 402)
		var x: float = floorf(fposmod(EraLight.h(i, 400) * w + l.speed * power * k * t, w)) - 30.0
		# A gust line lives for one crossing: it swells, curls up at its head and thins out.
		var life: float = (x + 30.0) / w
		var a: float = col.a * sin(life * PI) * amount
		var y: float = floorf(EraLight.h(i, 401) * vs.y + sin(life * TAU + i) * 4.0)
		var length: float = 10.0 + float(i % 4) * 4.0
		c.draw_rect(Rect2(x, y, length * 0.5, 1), Color(col, a * 0.45))
		c.draw_rect(Rect2(x + length * 0.5, y, length * 0.5, 1), Color(col, a))
		c.draw_rect(Rect2(x + length, y - 1.0, 3, 1), Color(col, a))
		c.draw_rect(Rect2(x + length + 3.0, y - 2.0, 1, 1), Color(col, a * 0.7))
	for i: int in _scaled(l.leaves, amount, power):
		var k: float = 0.7 + 0.6 * EraLight.h(i, 412)
		var x: float = floorf(fposmod(EraLight.h(i, 410) * w + l.speed * 0.7 * power * k * t, w)) - 30.0
		var y: float = floorf(fposmod(EraLight.h(i, 411) * vs.y + 26.0 * k * t, vs.y) + sin(t * 3.0 + i * 1.7) * 6.0)
		var lc: Color = _lit(leaf[i % leaf.size()], dim)
		# A leaf tumbles through three shapes and drags a short blur behind it.
		match int(fposmod(t * 7.0 + i * 1.3, 3.0)):
			0:
				c.draw_rect(Rect2(x, y, 3, 1), lc)
				c.draw_rect(Rect2(x + 1.0, y - 1.0, 1, 1), lc)
			1:
				c.draw_rect(Rect2(x, y, 2, 1), lc)
				c.draw_rect(Rect2(x + 1.0, y - 1.0, 2, 1), lc)
			_:
				c.draw_rect(Rect2(x + 1.0, y - 1.0, 1, 3), lc)
				c.draw_rect(Rect2(x, y, 1, 1), lc)
		c.draw_rect(Rect2(x - 3.0, y, 2, 1), Color(lc, 0.35))

## A rainbow over the top of the screen after rain; [param alpha] fades it.
func paint_rainbow(c: CanvasItem, vs: Vector2, alpha: float) -> void:
	if density <= 0.0 or alpha <= 0.0:
		return
	var tex: Texture2D = rainbow_tex()
	c.draw_texture(tex, Vector2(floorf(vs.x - tex.get_width() * 0.82), floorf(vs.y * 0.1)), Color(1, 1, 1, alpha))

# --- Above the map: cloud shadows -----------------------------------------------------------

## Dark cloud shadows that drift over a [param size] map under rain and storm.
func paint_clouds(c: CanvasItem, size: Vector2, look: String, amount: float, t: float) -> void:
	var l: Look = look_of(look)
	if density <= 0.0 or l.clouds <= 0.0 or not soft or amount <= 0.0:
		return
	var tex: Texture2D = cloud_tex()
	var ts: Vector2 = tex.get_size()
	var span: float = size.x + ts.x * 2.0
	var n: int = clampi(int(ceilf(size.y / 120.0)) + 1, 2, 7)
	for i: int in n:
		var x: float = fposmod(EraLight.h(i, 500) * span + clock(t) * (9.0 + 4.0 * EraLight.h(i, 501)), span) - ts.x
		var y: float = size.y * (float(i) + 0.3) / n - ts.y * 0.4
		c.draw_texture(tex, Vector2(floorf(x), floorf(y)), Color(cloud, l.clouds * amount))

# --- On the ground --------------------------------------------------------------------------

## Puddles that have formed at wetness [param wet], within [param view] (map px).
func paint_puddles(g: CanvasItem, view: Rect2, wet: float, t: float, raining: float) -> void:
	if density <= 0.0 or wet <= 0.0:
		return
	t = clock(t)
	for i: int in puddle_x.size():
		var grown: float = (wet - puddle_from[i]) / 0.45
		if grown <= 0.0:
			continue
		var o := Vector2(puddle_x[i] * TILE, puddle_y[i] * TILE)
		if o.x > view.end.x or o.y > view.end.y or o.x + TILE < view.position.x or o.y + TILE < view.position.y:
			continue
		var stage: int = clampi(int(grown * PUDDLE_STAGES), 0, PUDDLE_STAGES - 1)
		var shape: int = puddle_shape[i]
		g.draw_texture(puddle_tex(shape % PUDDLE_SHAPES, stage, shape >= PUDDLE_SHAPES), o)
		if stage == 0 or low:
			continue
		# The sky in the puddle: a pale streak that wanders, and a ring where a drop lands.
		g.draw_rect(Rect2(o.x + 6.0 + roundf(sin(t * 1.1 + i) * 1.5), o.y + 8.0, 3, 1), shine)
		if raining > 0.0:
			var ring: float = fposmod(t * 1.4 + EraLight.h(i, 5), 1.6)
			if ring < 0.45:
				_ring(g, o.x + 8.0 + float(i % 3) - 1.0, o.y + 9.0, int(ring / 0.15), Color(ripple, ripple.a * raining))

## Drops that land within [param view]: a small crown on open ground, a ring on water.
func paint_splashes(g: CanvasItem, view: Rect2, look: String, amount: float, power: float, t: float) -> void:
	var l: Look = look_of(look)
	if density <= 0.0 or low or l.splashes <= 0:
		return
	t = clock(t)
	var origin: Vector2 = (view.position / TILE).floor() * TILE
	for i: int in _scaled(l.splashes, amount, power):
		var period: float = 0.4 + 0.3 * EraLight.h(i, 21)
		var at: float = t / period + EraLight.h(i, 22)
		var turn: float = floorf(at)
		var ph: float = at - turn
		if ph > 0.8:
			continue
		var spot: int = i * 31 + int(turn) % 4096
		var x: float = floorf(origin.x + EraLight.h(spot, 23) * (view.size.x + TILE))
		var y: float = floorf(origin.y + EraLight.h(spot, 24) * (view.size.y + TILE))
		var f: int = flags_at(int(x) >> 4, int(y) >> 4)
		var frame: int = int(ph * 5.0)
		if f & F_WATER != 0:
			_ring(g, x, y, frame, ripple)
		elif f & F_GROUND != 0 and frame < 3:
			_crown(g, x, y, frame)

## One frame of a ring that widens and fades (water, puddles).
func _ring(g: CanvasItem, x: float, y: float, frame: int, col: Color) -> void:
	match frame:
		0:
			g.draw_rect(Rect2(x, y, 1, 1), col)
		1:
			g.draw_rect(Rect2(x - 1.0, y - 1.0, 3, 1), col)
			g.draw_rect(Rect2(x - 1.0, y + 1.0, 3, 1), col)
			g.draw_rect(Rect2(x - 2.0, y, 1, 1), col)
			g.draw_rect(Rect2(x + 2.0, y, 1, 1), col)
		2:
			var c2 := Color(col, col.a * 0.7)
			g.draw_rect(Rect2(x - 2.0, y - 1.0, 5, 1), c2)
			g.draw_rect(Rect2(x - 2.0, y + 1.0, 5, 1), c2)
			g.draw_rect(Rect2(x - 3.0, y, 1, 1), c2)
			g.draw_rect(Rect2(x + 3.0, y, 1, 1), c2)
		3:
			var c3 := Color(col, col.a * 0.4)
			g.draw_rect(Rect2(x - 3.0, y - 2.0, 2, 1), c3)
			g.draw_rect(Rect2(x + 2.0, y - 2.0, 2, 1), c3)
			g.draw_rect(Rect2(x - 2.0, y + 2.0, 5, 1), c3)
			g.draw_rect(Rect2(x - 4.0, y, 1, 1), c3)
			g.draw_rect(Rect2(x + 4.0, y, 1, 1), c3)

## One frame of a drop that bursts on the ground.
func _crown(g: CanvasItem, x: float, y: float, frame: int) -> void:
	match frame:
		0:
			g.draw_rect(Rect2(x, y - 1.0, 1, 2), splash)
		1:
			g.draw_rect(Rect2(x - 1.0, y - 1.0, 1, 1), splash)
			g.draw_rect(Rect2(x + 1.0, y - 1.0, 1, 1), splash)
			g.draw_rect(Rect2(x, y, 1, 1), Color(splash, splash.a * 0.6))
		2:
			var c2 := Color(splash, splash.a * 0.55)
			g.draw_rect(Rect2(x - 2.0, y - 2.0, 1, 1), c2)
			g.draw_rect(Rect2(x + 2.0, y - 2.0, 1, 1), c2)
			g.draw_rect(Rect2(x - 1.0, y, 3, 1), Color(splash, splash.a * 0.3))

## Snow lying on the open ground within [param view]; [param settled] 0 to 1 is how much.
func paint_snow_cover(g: CanvasItem, view: Rect2, settled: float) -> void:
	if settled <= 0.0:
		return
	var from := Vector2i((view.position / TILE).floor())
	var to := Vector2i((view.end / TILE).ceil())
	var col: Color = snow[snow.size() - 1]
	for y: int in range(maxi(from.y, 0), mini(to.y, _h)):
		for x: int in range(maxi(from.x, 0), mini(to.x, _w)):
			if _flags[y * _w + x] & F_GROUND == 0:
				continue
			# Snow gathers cell by cell: some are white early, the last ones late.
			var grown: float = settled * 1.5 - 0.5 * EraLight.h(x * 57 + y, 3)
			if grown <= 0.0:
				continue
			g.draw_texture(snow_tex(clampi(int(grown * SNOW_STAGES), 0, SNOW_STAGES - 1), (x * 7 + y * 3) % 2 == 1), Vector2(x * TILE, y * TILE), Color(col, 0.8))

## A light wave that runs through grass, reeds and flowers within [param view] under wind.
func paint_gusts(g: CanvasItem, view: Rect2, amount: float, power: float, t: float) -> void:
	if density <= 0.0 or low or amount <= 0.0:
		return
	t = clock(t)
	var from := Vector2i((view.position / TILE).floor())
	var to := Vector2i((view.end / TILE).ceil())
	var col := Color(gust, gust.a * amount)
	for y: int in range(maxi(from.y, 0), mini(to.y, _h)):
		for x: int in range(maxi(from.x, 0), mini(to.x, _w)):
			var f: int = _flags[y * _w + x]
			if f & F_GRASS == 0:
				continue
			var wave: float = sin(x * 0.7 - y * 0.25 - t * 3.2 * power)
			# The gust front lifts the pale undersides of the blades and leans them over. A plain
			# lawn shows it at the crest only; tall grass, reeds and flowers bend in the whole front.
			var tall: bool = f & F_TALL != 0
			if wave < (0.4 if tall else 0.82):
				continue
			var lean: float = 1.0 if wave > 0.8 else 0.0
			var ox: float = x * TILE
			var oy: float = y * TILE
			var r: float = floorf(EraLight.h(x * 13 + y, 7) * 3.0)
			g.draw_rect(Rect2(ox + 2.0 + r, oy + 4.0, 1, 3), col)
			g.draw_rect(Rect2(ox + 3.0 + r + lean, oy + 3.0, 2, 1), col)
			if not tall:
				continue
			g.draw_rect(Rect2(ox + 9.0 - r, oy + 10.0, 1, 3), col)
			g.draw_rect(Rect2(ox + 10.0 - r + lean, oy + 9.0, 2, 1), col)
			g.draw_rect(Rect2(ox + 13.0, oy + 6.0 + r, 1, 2), col)
			g.draw_rect(Rect2(ox + 14.0 + lean, oy + 5.0 + r, 1, 1), col)

# --- Textures, built once -------------------------------------------------------------------

func _keep(key: String, img: Image) -> Texture2D:
	_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]

## One sheet of [param n] rain streaks of [param layer], white (the colour comes with the draw
## call), wrapping at its edges. A streak is a stair of 1 px wide pieces: the steeper the fall,
## the longer each piece. With [param bright_tip] the lowest pixel is full white, the rest thinner.
func rain_tex(l: Look, layer: int, n: int, bright_tip: bool) -> Texture2D:
	var key: String = "rain|%d|%d|%d|%d|%s" % [l.length[layer], int(l.vx[layer]), int(l.vy[layer]), n, bright_tip]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(SHEET, SHEET, false, Image.FORMAT_RGBA8)
	var vx: float = l.vx[layer]
	var length: int = l.length[layer]
	var piece: int = clampi(roundi(absf(l.vy[layer] / vx)), 1, 4) if absf(vx) > 0.01 else length
	var dir: int = int(signf(vx))
	var salt: int = 100 + layer * 10
	var body := Color(1, 1, 1, 0.82 if bright_tip else 1.0)
	for i: int in n:
		var x: int = int(EraLight.h(i, salt) * SHEET)
		var y: int = int(EraLight.h(i, salt + 1) * SHEET)
		# Streaks of one depth differ a little in length, so the sheet does not look stamped.
		var own: int = maxi(2, length - int(EraLight.h(i, salt + 2) * 3.0))
		for j: int in own:
			img.set_pixel(posmod(x + dir * (j / piece), SHEET), posmod(y + j, SHEET), Color.WHITE if bright_tip and j == own - 1 else body)
	return _keep(key, img)

## A puddle of [param shape] at growth [param stage] (0 small to 2 full), in the era's colours:
## a dark rim at the far edge, the water, and the pale sky along the near edge.
func puddle_tex(shape: int, stage: int, flip: bool) -> Texture2D:
	var key: String = "puddle|%d|%d|%s" % [shape, stage, flip]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var grow: float = [0.5, 0.78, 1.0][stage]
	# Two or three flat blobs per shape: [mid x, mid y, radius x, radius y].
	var blobs: Array = [
		[[7.5, 9.0, 6.0, 3.2], [10.5, 10.5, 4.0, 2.4]],
		[[8.0, 9.5, 5.0, 3.6], [5.0, 8.0, 3.4, 2.2], [11.0, 11.0, 3.0, 1.8]],
		[[8.0, 10.0, 6.6, 2.6], [6.0, 8.5, 3.0, 2.0]],
		[[9.0, 9.0, 4.4, 3.4], [5.5, 10.5, 3.6, 2.0]],
	][shape]
	var inside: Array[bool] = []
	inside.resize(TILE * TILE)
	for y: int in TILE:
		for x: int in TILE:
			var sx: float = (TILE - 1 - x) if flip else x
			var hit: bool = false
			for b: Array in blobs:
				if Vector2((sx - float(b[0])) / (float(b[2]) * grow), (y - float(b[1])) / (float(b[3]) * grow)).length() < 1.0:
					hit = true
			inside[y * TILE + x] = hit
	for y: int in TILE:
		for x: int in TILE:
			if not inside[y * TILE + x]:
				continue
			var top: bool = y == 0 or not inside[(y - 1) * TILE + x]
			var bottom: bool = y == TILE - 1 or not inside[(y + 1) * TILE + x]
			var col: Color = puddle
			if top:
				col = puddle_rim
			elif bottom and soft and stage > 0:
				col = puddle.lerp(Color(shine, puddle.a), 0.35)
			img.set_pixel(x, y, col)
	return _keep(key, img)

## Snow on a ground tile at [param stage]: a few flecks, drifts, then a cover with gaps.
func snow_tex(stage: int, flip: bool) -> Texture2D:
	var key: String = "snow|%d|%s" % [stage, flip]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y: int in TILE:
		for x: int in TILE:
			var sx: int = (TILE - 1 - x) if flip else x
			var r: float = EraLight.h(sx * 31 + y * 7, 17)
			# Drifts: two soft mounds per tile that widen with the stage.
			var d: float = minf(Vector2((sx - 4.5) / 5.0, (y - 5.0) / 3.0).length(), Vector2((sx - 11.0) / 5.5, (y - 11.5) / 3.2).length())
			var a: float = 0.0
			match stage:
				0:
					a = 1.0 if d < 0.55 and r < 0.6 else 0.0
				1:
					a = 1.0 if d < 0.8 or (d < 1.1 and (sx + y) % 2 == 0) else 0.0
				_:
					a = 1.0 if d < 1.15 or (sx + y) % 2 == 0 or r < 0.3 else 0.0
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return _keep(key, img)

## A fog bank of depth [param layer] (0 far and small, 2 near and wide): white, its edge
## thinned out by a fixed dither so it stays pixel art; the colour comes with the draw call.
func bank_tex(layer: int) -> Texture2D:
	var key: String = "bank|%d" % layer
	if _tex.has(key):
		return _tex[key]
	var w: int = [72, 104, 136][clampi(layer, 0, 2)]
	var hgt: int = [18, 26, 34][clampi(layer, 0, 2)]
	var img := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
	for y: int in hgt:
		for x: int in w:
			# A long flat body with a few lumps along its back.
			var u: float = (x + 0.5) / w * 2.0 - 1.0
			var v: float = (y + 0.5) / hgt * 2.0 - 1.0
			var lump: float = 0.16 * sin(x * 0.19 + layer * 2.0) + 0.1 * sin(x * 0.07 + 1.3 + layer)
			var f: float = 1.0 - sqrt(u * u * u * u + (v + lump) * (v + lump) * 1.25)
			var a: float = 0.0
			if not soft:
				# Flat eras: no see-through steps, only dither, and a rounder bank.
				f = 1.0 - sqrt(u * u + (v + lump) * (v + lump))
				if f > 0.45:
					a = 1.0 if (x + y) % 2 == 0 else 0.0
				elif f > 0.12:
					a = 1.0 if x % 2 == 0 and y % 2 == 0 else 0.0
			elif f > 0.5:
				a = 1.0
			elif f > 0.3:
				a = 1.0 if (x + y) % 2 == 0 else 0.55
			elif f > 0.14:
				a = 0.55 if (x + y) % 2 == 0 else 0.2
			elif f > 0.0:
				a = 0.3 if x % 2 == 0 and y % 2 == 0 else 0.0
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return _keep(key, img)

## A cloud shadow: a broad soft shape in two steps of dark, no dither (it is scaled by nothing).
func cloud_tex() -> Texture2D:
	if _tex.has("cloud"):
		return _tex["cloud"]
	var img := Image.create(160, 84, false, Image.FORMAT_RGBA8)
	var blobs: Array = [[42, 46, 36, 24], [80, 36, 44, 30], [120, 48, 34, 22], [68, 54, 52, 20]]
	for y: int in 84:
		for x: int in 160:
			var best: float = 9.0
			for b: Array in blobs:
				best = minf(best, Vector2((x - float(b[0])) / float(b[2]), (y - float(b[1])) / float(b[3])).length())
			if best < 0.8:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif best < 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.5))
	return _keep("cloud", img)

## Six bands of a wide arc, the ends thinned out by dither.
func rainbow_tex() -> Texture2D:
	if _tex.has("rainbow"):
		return _tex["rainbow"]
	var w: int = 150
	var hgt: int = 84
	var img := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
	var mid := Vector2(w * 0.5, hgt + 26.0)
	var outer: float = 104.0
	for y: int in hgt:
		for x: int in w:
			var d: float = outer - Vector2(x + 0.5, y + 0.5).distance_to(mid)
			if d < 0.0 or d >= RAINBOW.size() * 2.0:
				continue
			# It fades toward the ground on both sides.
			var low_part: float = float(y) / hgt
			if low_part > 0.55 and (x + y) % 2 == 0:
				continue
			if low_part > 0.8 and x % 2 == 0:
				continue
			img.set_pixel(x, y, RAINBOW[int(d / 2.0)])
	return _keep("rainbow", img)
