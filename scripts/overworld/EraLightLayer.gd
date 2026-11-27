class_name EraLightLayer
extends Node2D
## Draws what EraLight decides for the map on screen (data/era_light.json): weather in the era's
## style, puddles, snow with prints, long shadows (this node, on the ground under the people),
## cloud shadows, light shafts, lamp glow and embers (a layer that follows the camera and that
## the day tint does not reach), and rain, fog, cave dark, lightning and wipes on the screen.
## Motion comes from the clock alone, so with reduced motion everything stands still and
## lightning, wipes and the camera sweep are off.
## Rain, snow, fog and wind themselves are drawn by WeatherFx (data/weather.json "fx"); this
## layer fades one weather into the next, lets puddles and snow build up and dry, and sends
## the thunder after a flash.

class Painter extends Node2D:
	var paint: Callable
	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)

const TILE: int = 16
const SKY_LAYER: int = 2
const SCREEN_LAYER: int = 3
const FADE_TIME: float = 0.11
const WIPE_TIME: float = 0.16
const WIPE_STRIPS: int = 8
const PRINT_LIFE: float = 24.0
const MAX_PRINTS: int = 40
const TEXT_TIME: float = 2.5
const SWEEP_TIME: float = 1.4
const SWEEP_DIST: float = 56.0
const PATTERN_FPS: float = 4.0
const SHADOW: Color = Color(0.05, 0.05, 0.16, 0.26)
const WARM: Color = Color(1.0, 0.86, 0.55)
const LEAVES: Array[Color] = [Color("d0782c"), Color("8a5a2a"), Color("b8a03c")]
const GROUND_KINDS: Array[int] = [TilesetFactory.Kind.GRASS, TilesetFactory.Kind.PATH, TilesetFactory.Kind.FLOWER, TilesetFactory.Kind.SCREE, TilesetFactory.Kind.TALL_GRASS, TilesetFactory.Kind.STAIRS]

var player: GridWalker
var camera: Camera2D
var map: MapData
var era: int = 1
var cfg: Dictionary = {}
## Weather as it looks here (EraLight.weather_look).
var look: String = "clear"
var hour: float = 12.0
## Names of what is drawn now (EraLight.effects).
var fx: Array[String] = []
## Footprints in snow: {cell, facing, age}.
var prints: Array[Dictionary] = []
## Start times of the flashes so far (the cap looks at the last second).
var flash_times: Array[float] = []
var wipe_style: String = ""
var wipe_k: float = 0.0
var wipe_up: bool = false
var sweeping: bool = false
## Draws rain, snow, fog and wind (data/weather.json "fx").
var wx: WeatherFx = WeatherFx.new()
## The look that is fading out, and how far the new one is in (1 = all the way).
var from_look: String = "clear"
var mix: float = 1.0
## Grade of the look and of the one fading out (WeatherCycle.grade "amount").
var power: float = 1.0
var from_power: float = 1.0
## How wet the ground is now, 0 to 1 (puddles, lying snow), and where it is heading.
var wet: float = 0.0
var wet_to: float = 0.0
## True when the screen shows land around the map (EraDepthLayer fill): weather covers it too.
var full_screen: bool = false
## Seconds on the layer's clock when the next thunder sounds; below 0 for none.
var thunder_at: float = -1.0

var _t: float = 0.0
var _ground: Painter
var _sky_clip: Painter
var _sky: Painter
var _weather_clip: Painter
var _weather: Painter
var _screen: Painter
var _label: Label
var _label_left: float = 0.0
var _map_id: String = ""
var _last_cell: Vector2i = Vector2i(-99, -99)
var _lamps: Array[Vector2i] = []
var _trees: Array[Vector2i] = []
var _shafts: Array[Vector2i] = []
var _flash_left: float = 0.0
var _next_strike: float = 0.0
var _closed: bool = false
var _closed_for: float = 0.0
var _fade: ColorRect
var _seen_big: Dictionary = {}
var _sweep_left: float = 0.0
var _sweep_from: Vector2 = Vector2.ZERO
var _pattern_frame: int = -1
var _tex: Dictionary = {}
var _dim: float = 1.0
var _rainbow: float = 0.0
var _level: String = "full"

func setup(p: GridWalker, cam: Camera2D) -> void:
	player = p
	camera = cam

func _ready() -> void:
	name = "era_light"
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = SKY_LAYER
	sky_layer.follow_viewport_enabled = true
	add_child(sky_layer)
	# Maps can be smaller than the screen: nothing spills past the map's edge.
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_ground = Painter.new()
	_ground.paint = _paint_ground
	add_child(_ground)
	_sky_clip = Painter.new()
	_sky_clip.paint = _paint_map_rect
	_sky_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	sky_layer.add_child(_sky_clip)
	_sky = Painter.new()
	_sky.paint = _paint_sky
	_sky_clip.add_child(_sky)
	var screen_layer := CanvasLayer.new()
	screen_layer.layer = SCREEN_LAYER
	add_child(screen_layer)
	_weather_clip = Painter.new()
	_weather_clip.paint = _paint_map_on_screen
	_weather_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	screen_layer.add_child(_weather_clip)
	_weather = Painter.new()
	_weather.paint = _paint_weather
	_weather.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_weather.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weather_clip.add_child(_weather)
	_screen = Painter.new()
	_screen.paint = _paint_screen
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen_layer.add_child(_screen)
	_label = Label.new()
	_label.theme = UITheme.get_theme()
	_label.add_theme_stylebox_override("normal", UITheme.panel_style())
	_label.position = Vector2(4, 24)
	_label.visible = false
	screen_layer.add_child(_label)
	_under_people.call_deferred()

## Puddles, prints and shadows lie on the ground: right above the tiles, under the people.
func _under_people() -> void:
	var ground: Node = get_parent().get_node_or_null("Ground") if get_parent() != null else null
	if ground != null:
		get_parent().move_child(self, ground.get_index() + 1)

## Called by the overworld whenever the light is refreshed (map load, phase change, once a
## minute). Sets the world tint of the era, hides what the era does not have (lit windows,
## the plain weather dots) and picks what to draw.
func refresh(m: MapData, kind: String, daylight: CanvasModulate = null, glow: WindowGlow = null, plain_weather: CanvasItem = null) -> void:
	if m == null:
		return
	map = m
	era = EraLight.era_for(m.region)
	cfg = EraLight.for_era(era)
	hour = EraLight.hour_now()
	if not EraLight.debug_weather.is_empty() and m.outdoor:
		kind = EraLight.debug_weather
	var new_look: String = EraLight.weather_look(era, m.id, m.region, m.biome, kind)
	var new_power: float = float(WeatherCycle.grade(kind, WeatherCycle.strength(m.region, Online.unix_now())).get("amount", 1.0))
	var entered: bool = m.id != _map_id
	_level = WeatherCycle.fx_level()
	wx.setup(m, era, _level)
	# The ground is as wet as the sky made it; a sky set by a tool is wet when it rains.
	var loose: bool = m.outdoor and not EraLight.is_cave(m) and GameState.weather
	if not EraLight.debug_weather.is_empty() and WeatherCycle.debug_wet < 0.0:
		wet_to = 1.0 if new_look in EraLight.WET or new_look == "snow" else 0.0
	else:
		wet_to = WeatherCycle.wetness(m) if loose or WeatherCycle.debug_wet >= 0.0 else 0.0
	if not m.outdoor or EraLight.is_cave(m):
		wet_to = 0.0
	if entered:
		_map_id = m.id
		_scan()
		prints.clear()
		_last_cell = player.cell if player != null else Vector2i(-99, -99)
	fx = EraLight.effects(era, {"look": new_look, "outdoor": m.outdoor, "lit": m.outdoor and GameState.day_night,
		"hour": hour, "wooded": EraLight.wooded(m), "lamps": not _lamps.is_empty(), "cave": EraLight.is_cave(m),
		"month": EraLight.month_now(), "reduced": Juice.reduced(), "weather_fx": _level,
		"after_rain": wet_to > 0.0 and (WeatherCycle.after_rain(m) if loose and EraLight.debug_weather.is_empty() else WeatherCycle.debug_wet >= 0.0)})
	var tint: Color = EraLight.world_tint(era, m, new_look, hour, EraLight.month_now(), GameState.day_night)
	# Drops and fog sit above the day tint: they take their share of the dark themselves.
	_dim = clampf(0.35 + 0.65 * tint.get_luminance(), 0.4, 1.0)
	if daylight != null:
		daylight.color = tint
	if glow != null:
		glow.show_for(m, "lit_windows" in fx)
	if plain_weather != null:
		plain_weather.visible = false
	if (entered or new_look != look) and "weather_text" in fx:
		_say(Loc.t(EraLight.weather_line(new_look)))
	if entered or Juice.reduced():
		# A new map shows its sky at once; so does a calm screen.
		from_look = "clear"
		mix = 1.0
		wet = wet_to
		thunder_at = -1.0
		_rainbow = 1.0 if "rainbow" in fx else 0.0
	elif new_look != look:
		# The old sky thins out while the new one comes in (WeatherFx.fade_seconds).
		from_look = look
		from_power = power
		mix = 0.0
	if new_look != look:
		_next_strike = _t + 1.0
	look = new_look
	power = new_power
	if entered:
		_start_sweep()
		_open_wipe()
	_pattern_frame = -1
	_redraw()

func _scan() -> void:
	_lamps.clear()
	_trees.clear()
	_shafts.clear()
	var salt: int = absi(hash(map.id)) % 9973
	for y: int in map.height:
		for x: int in map.rows[y].length():
			var c := Vector2i(x, y)
			var k: int = map.kind_at(c)
			var r: float = EraLight.h(x * 131 + y, salt)
			if k == TilesetFactory.Kind.LAMP:
				_lamps.append(c)
			elif k == TilesetFactory.Kind.TREE:
				_trees.append(c)
				if r < 0.22:
					_shafts.append(c)

func _say(text: String) -> void:
	if _label == null or text.is_empty():
		return
	_label.text = " %s " % text
	_label.visible = true
	_label_left = TEXT_TIME

func _redraw() -> void:
	queue_redraw()
	if _weather != null:
		# Weather keeps the pixel size of the world when the camera zooms in whole steps.
		var zoom: float = maxf(1.0, roundf(camera.zoom.x)) if camera != null else 1.0
		_weather.scale = Vector2(zoom, zoom)
	for p: Painter in [_ground, _sky_clip, _sky, _weather_clip, _weather, _screen]:
		if p != null:
			p.queue_redraw()

func _process(delta: float) -> void:
	if map == null:
		return
	var still: bool = Juice.reduced()
	if not still:
		_t += delta
	if _label_left > 0.0:
		_label_left -= delta
		if _label_left <= 0.0:
			_label.visible = false
	if player != null and player.cell != _last_cell:
		note_step(_last_cell, player.facing)
		_last_cell = player.cell
	for p: Dictionary in prints:
		p.age = float(p.age) + delta
	while not prints.is_empty() and float(prints[0].age) >= PRINT_LIFE:
		prints.pop_front()
	var moving: bool = mix < 1.0 or wet != wet_to or _rainbow > 0.0 or "rainbow" in fx
	if mix < 1.0:
		mix = minf(1.0, mix + delta / WeatherFx.fade_seconds())
		if mix >= 1.0:
			from_look = "clear"
	if wet != wet_to:
		var pc: Dictionary = WeatherFx.cfg().get("puddles", {})
		var secs: float = float(pc.get("form_seconds", 45.0)) if wet_to > wet else float(pc.get("dry_seconds", 600.0))
		wet = move_toward(wet, wet_to, delta / maxf(secs, 0.01))
	_rainbow = move_toward(_rainbow, 1.0 if "rainbow" in fx else 0.0, delta / WeatherFx.fade_seconds())
	if "lightning" in fx and not still and _t >= _next_strike:
		_next_strike = _t + float(EraLight.flash_cfg().get("strike_every", 7.0)) * randf_range(0.6, 1.4)
		if try_flash() and randf() < float(EraLight.flash_cfg().get("double_share", 0.0)):
			_next_strike = _t + float(EraLight.flash_cfg().get("min_gap", 0.35)) + 0.05
	if thunder_at >= 0.0 and _t >= thunder_at:
		thunder_at = -1.0
		_thunder()
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
	if _closed:
		# A warp that never loaded its map: let go of the covered screen.
		_closed_for += delta
		if _closed_for > 1.0:
			_closed = false
			wipe_k = 0.0
			wipe_style = ""
	_sweep(delta)
	if fx.is_empty() and wipe_style.is_empty() and _flash_left <= 0.0 and not moving and wet <= 0.0:
		return
	# The weather line is a Label of its own: alone it needs no repaint (weather effects "off" in Era I).
	if fx.size() == 1 and fx[0] == "weather_text" and wipe_style.is_empty() and _flash_left <= 0.0 and not moving and (wet <= 0.0 or not _draws_weather()):
		return
	if _weather_clip != null:
		_weather_clip.queue_redraw()
	if str(cfg.get("weather_style", "")) == "pattern" and wipe_style.is_empty() and not "cave_light" in fx:
		# Era I moves in steps, a few frames a second, like a tile animation.
		var f: int = int(_t * PATTERN_FPS)
		if f == _pattern_frame:
			return
		_pattern_frame = f
	_redraw()

## Leaves a footprint at [param cell] while snow lies (Era IV on). True when one was left.
func note_step(cell: Vector2i, facing: String) -> bool:
	if not "snow_prints" in fx or map == null or not map.kind_at(cell) in GROUND_KINDS:
		return false
	prints.append({"cell": cell, "facing": facing, "age": 0.0})
	if prints.size() > MAX_PRINTS:
		prints.pop_front()
	return true

## Starts a lightning flash when the cap allows one (EraLight.flash_allowed). True when it did.
func try_flash() -> bool:
	if not EraLight.flash_allowed(flash_times, _t, Juice.reduced()):
		return false
	flash_times.append(_t)
	while flash_times.size() > 8:
		flash_times.pop_front()
	_flash_left = float(EraLight.flash_cfg().get("length", 0.07)) * 3.0
	if thunder_at < 0.0:
		# The thunder follows the flash after a moment; a double flash has one thunder.
		var th: Dictionary = WeatherFx.cfg().get("thunder", {})
		thunder_at = _t + randf_range(float(th.get("delay_min", 0.35)), float(th.get("delay_max", 1.4)))
	return true

func _thunder() -> void:
	var th: Dictionary = WeatherFx.cfg().get("thunder", {})
	Sound.sfx(str(th.get("sfx", "rumble")), float(th.get("db", -5.0)), randf_range(float(th.get("pitch_min", 0.85)), float(th.get("pitch_max", 1.1))))

## True when this era draws weather over the map at all (style "none" or weather effects "off" leave the line of text only).
func _draws_weather() -> bool:
	return str(cfg.get("weather_style", "pattern")) != "none" and _level != "off"

## The part of the map on screen, in map px.
func _view(c: CanvasItem) -> Rect2:
	return c.get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, c.get_viewport_rect().size)

# --- Map transitions ----------------------------------------------------------------------

## Darkens the screen for a warp the era's own way. False when the era keeps the overworld's
## own transition (and for wipes under reduced motion); then the caller goes on as before.
func warp_out(tile_kind: int, edge: bool, facing: String, fade: ColorRect) -> bool:
	var style: String = EraLight.transition(era, EraLight.warp_kind(tile_kind, edge))
	match style:
		"cut":
			fade.color.a = 1.0
			_cover(fade)
			return true
		"fade":
			await Juice.tween(fade, "color:a", 1.0, "close", FADE_TIME).finished
			return true
		"door_wipe", "stair_wipe":
			if Juice.reduced():
				return false
			wipe_style = style
			wipe_up = facing == "up"
			wipe_k = 0.0
			var tw: Tween = create_tween()
			tw.tween_property(self, "wipe_k", 1.0, WIPE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw.finished
			fade.color.a = 1.0
			_cover(fade)
			return true
	return false

func _cover(fade: ColorRect) -> void:
	_closed = true
	_closed_for = 0.0
	_fade = fade

## The new map is in: a cut shows it at once, a wipe opens the way it closed.
func _open_wipe() -> void:
	if not _closed:
		return
	_closed = false
	if _fade != null:
		_fade.color.a = 0.0
	if wipe_style.is_empty():
		return
	wipe_k = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "wipe_k", 0.0, WIPE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: wipe_style = "")

## Era V: the first time a big place is entered the camera starts toward its middle and
## glides back to the Wayfarer.
func _start_sweep() -> void:
	sweeping = false
	if not bool(cfg.get("camera_sweep", false)) or Juice.reduced() or camera == null or player == null:
		return
	if not EraLight.is_big_place(map) or _seen_big.has(map.id):
		return
	_seen_big[map.id] = true
	var middle: Vector2 = Vector2(map.width, map.height) * TILE / 2.0
	_sweep_from = (middle - (player.position + Vector2(TILE, TILE) / 2.0)).limit_length(SWEEP_DIST)
	_sweep_left = SWEEP_TIME
	sweeping = true

func _sweep(delta: float) -> void:
	if not sweeping:
		return
	_sweep_left -= delta
	if _sweep_left <= 0.0 or Juice.reduced():
		sweeping = false
		camera.offset = Vector2.ZERO
		return
	var k: float = _sweep_left / SWEEP_TIME
	camera.offset = (_sweep_from * k * k * (3.0 - 2.0 * k)).round()

# --- Ground: snow, prints, puddles, long shadows ----------------------------------------------

func _draw() -> void:
	if map != null:
		draw_rect(Rect2(Vector2.ZERO, Vector2(map.width, map.height) * TILE), Color.WHITE)

func _paint_map_rect(c: Painter) -> void:
	if map != null:
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(map.width, map.height) * TILE), Color.WHITE)

## The map's rectangle on the screen (weather is drawn in screen pixels).
func _paint_map_on_screen(c: Painter) -> void:
	if map != null and full_screen and map.outdoor:
		c.draw_rect(Rect2(Vector2.ZERO, c.get_viewport_rect().size), Color.WHITE)
	elif map != null:
		c.draw_rect(c.get_viewport().get_canvas_transform() * Rect2(Vector2.ZERO, Vector2(map.width, map.height) * TILE), Color.WHITE)

func _paint_ground(g: Painter) -> void:
	if map == null:
		return
	var view: Rect2 = _view(g)
	var live: bool = _draws_weather()
	var snowy: float = (mix if look == "snow" else 0.0) + ((1.0 - mix) if from_look == "snow" else 0.0)
	if live and snowy > 0.0:
		wx.paint_snow_cover(g, view, wet * snowy)
	if "snow_prints" in fx:
		for p: Dictionary in prints:
			var a: float = 0.6 * (1.0 - float(p.age) / PRINT_LIFE)
			var o: Vector2 = Vector2(p.cell as Vector2i) * TILE
			var side: bool = str(p.facing) == "left" or str(p.facing) == "right"
			var col := Color(0.25, 0.3, 0.45, a)
			g.draw_rect(Rect2(o + (Vector2(4, 5) if side else Vector2(5, 4)), Vector2(3, 2) if side else Vector2(2, 3)), col)
			g.draw_rect(Rect2(o + (Vector2(9, 9) if side else Vector2(9, 9)), Vector2(3, 2) if side else Vector2(2, 3)), col)
	if live and bool(cfg.get("puddles", false)) and snowy < 1.0:
		var raining: float = (mix if look in EraLight.WET else 0.0) + ((1.0 - mix) if from_look in EraLight.WET else 0.0)
		wx.paint_puddles(g, view, wet * (1.0 - snowy), _t, raining)
		if player != null and wet > 0.5:
			# Whoever stands right above a puddle shows in it.
			for i: int in wx.puddle_x.size():
				if player.cell.x == wx.puddle_x[i] and player.cell.y == wx.puddle_y[i] - 1 and wet - wx.puddle_from[i] > 0.3:
					g.draw_rect(Rect2(wx.puddle_x[i] * TILE + 5, wx.puddle_y[i] * TILE + 9, 6, 2), Color(player.body_color, 0.35))
	if live and bool(cfg.get("splashes", false)):
		if look in EraLight.WET:
			wx.paint_splashes(g, view, look, mix, power, _t)
		if from_look in EraLight.WET and mix < 1.0:
			wx.paint_splashes(g, view, from_look, 1.0 - mix, from_power, _t)
	if live:
		if look == "wind" or look == "storm":
			wx.paint_gusts(g, view, mix, power, _t)
		if (from_look == "wind" or from_look == "storm") and mix < 1.0:
			wx.paint_gusts(g, view, 1.0 - mix, from_power, _t)
	if "long_shadows" in fx:
		var sv: Vector2 = EraLight.shadow(hour)
		for c: Vector2i in _trees:
			var base: Vector2 = Vector2(c) * TILE + Vector2(8, 14)
			g.draw_line(base, base + sv * 22.0, SHADOW, 6.0)
			g.draw_circle(base + sv * 22.0, 5.0, SHADOW)
		for w: Node in _walkers():
			var feet: Vector2 = (w as Node2D).position + Vector2(8, 14)
			g.draw_line(feet, feet + sv * 15.0, SHADOW, 5.0)

func _walkers() -> Array[Node]:
	var out: Array[Node] = []
	if player != null and player.get_parent() != null:
		for n: Node in player.get_parent().get_children():
			if n is GridWalker and (n as Node2D).visible:
				out.append(n)
	return out

# --- Above the map, tied to it: cloud shadows, light shafts, lamp glow, embers ----------------

func _paint_sky(c: Painter) -> void:
	if map == null:
		return
	var size: Vector2 = Vector2(map.width, map.height) * TILE
	if _draws_weather() and hour > 5.5 and hour < 20.5:
		if look != "clear":
			wx.paint_clouds(c, size, look, mix, _t)
		if from_look != "clear" and mix < 1.0:
			wx.paint_clouds(c, size, from_look, 1.0 - mix, _t)
	if "cloud_shadows" in fx:
		var tex: Texture2D = _cloud_tex()
		for i: int in 3:
			var x: float = fposmod(EraLight.h(i, 11) * (size.x + 200.0) + _t * (7.0 + i * 2.0), size.x + 200.0) - 110.0
			var y: float = size.y * (0.08 + 0.3 * i) + sin(_t * 0.1 + i) * 6.0
			c.draw_texture_rect(tex, Rect2(Vector2(x, y).round(), Vector2(112, 56)), false, Color(0.06, 0.06, 0.2, 0.17))
	if "light_shafts" in fx:
		var lean: Vector2 = Vector2(0.45 if hour < 13.0 else -0.45, 1.0)
		for i: int in _shafts.size():
			var top: Vector2 = Vector2(_shafts[i]) * TILE + Vector2(8, 2)
			var a: float = 0.08 + 0.03 * sin(_t * 0.8 + i * 1.7)
			c.draw_line(top, top + lean * 34.0, Color(1.0, 0.94, 0.66, a), 9.0)
			c.draw_line(top, top + lean * 34.0, Color(1.0, 0.97, 0.8, a), 4.0)
	if "lamp_glow" in fx:
		for i: int in _lamps.size():
			var mid: Vector2 = Vector2(_lamps[i]) * TILE + Vector2(8, 6)
			var flick: float = roundf(sin(_t * 5.0 + i * 2.3))
			c.draw_circle(mid, 24.0 + flick, Color(WARM, 0.09))
			c.draw_circle(mid, 16.0 + flick, Color(WARM, 0.13))
			c.draw_circle(mid, 9.0, Color(WARM, 0.2))
	if "embers" in fx:
		for i: int in _lamps.size():
			var mid: Vector2 = Vector2(_lamps[i]) * TILE + Vector2(8, 4)
			for j: int in 4:
				var p: float = fposmod(_t * 0.45 + EraLight.h(i * 4 + j, 7), 1.0)
				var at: Vector2 = mid + Vector2(sin(p * 6.0 + j * 2.0) * 5.0, -p * 26.0)
				c.draw_rect(Rect2(at.round(), Vector2(1, 1)), Color(1.0, 0.62 - 0.3 * p, 0.2, 1.0 - p))

# --- On the screen: weather, motes, golden light, cave dark, lightning, wipes -----------------

func _paint_weather(c: Painter) -> void:
	if map == null:
		return
	var vs: Vector2 = (c.get_viewport_rect().size / c.scale.x).ceil()
	wx.set_view(vs)
	if _draws_weather():
		if str(cfg.get("weather_style", "pattern")) == "pattern":
			if look != "clear":
				_paint_pattern(c, vs)
		else:
			if from_look != "clear" and mix < 1.0:
				_paint_look(c, vs, from_look, 1.0 - mix, from_power)
			if look != "clear":
				_paint_look(c, vs, look, mix, power)
		if _rainbow > 0.0 and wx.soft:
			wx.paint_rainbow(c, vs, 0.42 * _rainbow * _dim)
	_paint_motes(c, vs)
	if "golden_hour" in fx:
		var g: float = EraLight.golden(hour)
		for i: int in 6:
			c.draw_rect(Rect2(0, i * vs.y * 0.1, vs.x, vs.y * 0.1 + 1.0), Color(1.0, 0.7, 0.38, 0.17 * g * (1.0 - i / 6.0)))

func _paint_screen(c: Painter) -> void:
	if map == null:
		return
	var vs: Vector2 = c.get_viewport_rect().size
	if "cave_light" in fx:
		_paint_cave(c, vs)
	if _flash_left > 0.0:
		var length: float = float(EraLight.flash_cfg().get("length", 0.07))
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(1.0, 1.0, 0.94, float(EraLight.flash_cfg().get("alpha", 0.5)) * minf(1.0, _flash_left / (length * 2.0))))
	_paint_wipe(c, vs)

## Era I: weather is a flat pattern in the region's inks that steps along.
func _paint_pattern(c: Painter, vs: Vector2) -> void:
	var f: int = int(_t * PATTERN_FPS)
	var shift: Vector2 = Vector2.ZERO
	match look:
		"fog":
			shift = Vector2(f % 2, 0)
		"wind":
			shift = Vector2((f * 2) % 8, 0)
		_:
			shift = Vector2(0, (f * 2) % 8)
	c.draw_texture_rect(_pattern_tex(look), Rect2(shift - Vector2(8, 8), vs + Vector2(16, 16)), true)

func _pattern_tex(kind: String) -> Texture2D:
	var inks: Array[Color] = EraManager.inks_for(map.region)
	var key: String = "%s|%s" % [kind, inks[1].to_html()]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var dots: Array = []
	var ink: Color = inks[1]
	match kind:
		"fog":
			ink = inks[2]
			dots = [[0, 0], [4, 0], [2, 2], [6, 2], [0, 4], [4, 4], [2, 6], [6, 6]]
		"wind":
			ink = inks[3]
			dots = [[0, 1], [1, 1], [2, 1], [4, 5], [5, 5], [6, 5]]
		"storm":
			ink = inks[0]
			dots = [[1, 0], [1, 1], [5, 4], [5, 5], [3, 2], [3, 3], [7, 6], [7, 7]]
		_:
			dots = [[1, 0], [1, 1], [5, 4], [5, 5]]
	for d: Array in dots:
		img.set_pixel(int(d[0]), int(d[1]), ink)
	_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]

## One look at [param amount] (0 to 1, the fade): sandstorm and ash are painted here, rain,
## snow, fog and wind by WeatherFx in the era's colours.
func _paint_look(c: Painter, vs: Vector2, kind: String, amount: float, grade: float) -> void:
	if kind == "sandstorm" or kind == "ash":
		if _level != "off":
			_paint_rich(c, vs, kind, amount * wx.density)
		return
	wx.paint_screen(c, vs, kind, amount, grade, _t, _dim)

## Screen spot of mote [param i] moving at [param vel] px/s, wrapped; whole pixels.
func _drift(i: int, vs: Vector2, vel: Vector2, salt: int = 1) -> Vector2:
	var k: float = 0.75 + 0.5 * EraLight.h(i, salt + 2)
	return Vector2(fposmod(EraLight.h(i, salt) * vs.x + vel.x * k * _t, vs.x), fposmod(EraLight.h(i, salt + 1) * vs.y + vel.y * k * _t, vs.y)).round()

## Era III on: sandstorm and ash fall.
func _paint_rich(c: Painter, vs: Vector2, kind: String, amount: float) -> void:
	match kind:
		"sandstorm":
			c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.86, 0.72, 0.44, 0.24 * amount))
			for i: int in 3:
				var y: float = fposmod(EraLight.h(i, 41) * vs.y + _t * 9.0, vs.y)
				c.draw_rect(Rect2(0, roundf(y), vs.x, 22), Color(0.9, 0.78, 0.5, 0.12 * amount))
			for i: int in int(54 * amount):
				var p: Vector2 = _drift(i, vs, Vector2(230, 24), 42)
				if i % 3 == 0:
					c.draw_rect(Rect2(p, Vector2(1, 1)), Color("7a5a30"))
				else:
					c.draw_rect(Rect2(p, Vector2(5 + i % 4, 1)), Color(0.98, 0.9, 0.68, 0.75))
		"ash":
			c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.42, 0.4, 0.42, 0.16 * amount))
			for i: int in int(46 * amount):
				var p: Vector2 = _drift(i, vs, Vector2(4, 22), 51)
				p.x = roundf(p.x + sin(_t * 1.1 + i) * 3.0)
				var col: Color = Color("ff9040") if i % 9 == 0 else (Color("e4e0dc") if i % 2 == 0 else Color("6e686a"))
				c.draw_rect(Rect2(p, Vector2(2, 1) if i % 4 == 0 else Vector2(1, 1)), col)

## Era V: leaves in autumn or wind, pollen on fair spring and summer days.
func _paint_motes(c: Painter, vs: Vector2) -> void:
	if "leaves" in fx:
		for i: int in 14:
			var p: Vector2 = _drift(i, vs, Vector2(26, 20), 81)
			p.x = roundf(p.x + sin(_t * 2.0 + i) * 5.0)
			var flat: bool = sin(_t * 4.0 + i * 1.3) > 0.0
			c.draw_rect(Rect2(p, Vector2(3, 1) if flat else Vector2(2, 2)), LEAVES[i % LEAVES.size()])
	if "pollen" in fx:
		for i: int in 20:
			var p: Vector2 = _drift(i, vs, Vector2(5, -7), 91)
			p.x = roundf(p.x + sin(_t * 0.9 + i) * 4.0)
			c.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.96, 0.6, 0.5 + 0.4 * sin(_t * 1.5 + i)))

## Cave dark with a light circle on the Wayfarer: a hard ink edge in Era I, dithered in Era II,
## soft later.
func _paint_cave(c: Painter, vs: Vector2) -> void:
	var cave: Dictionary = EraLight.cave(era)
	var r: int = int(cave.get("radius", 40))
	var edge: String = str(cave.get("edge", "hard"))
	var dark: Color = EraManager.inks_for(map.region)[0] if edge != "soft" else Color(0.05, 0.04, 0.1)
	dark.a = float(cave.get("dark", 1.0))
	var mid: Vector2 = vs / 2.0
	if player != null and player.is_inside_tree():
		mid = (player.get_global_transform_with_canvas().origin + Vector2(TILE, TILE) / 2.0).round()
	var tex: Texture2D = _hole_tex(r, edge)
	var half: float = tex.get_width() / 2.0
	var box := Rect2(mid - Vector2(half, half), Vector2(half, half) * 2.0)
	c.draw_texture_rect(tex, box, false, dark)
	c.draw_rect(Rect2(-8, -8, vs.x + 16, box.position.y + 8), dark)
	c.draw_rect(Rect2(-8, box.end.y, vs.x + 16, vs.y - box.end.y + 8), dark)
	c.draw_rect(Rect2(-8, box.position.y, box.position.x + 8, box.size.y), dark)
	c.draw_rect(Rect2(box.end.x, box.position.y, vs.x - box.end.x + 8, box.size.y), dark)
	# The lantern's flame colour (KAMPF_PLAN_1000 item 837) tints the circle once the edge is soft.
	if edge == "soft":
		var flame: Color = LanternColors.color()
		c.draw_circle(mid, r * 0.8, Color(flame, 0.07))
		c.draw_circle(mid, r * 0.45, Color(flame, 0.09))

func _hole_tex(r: int, edge: String) -> Texture2D:
	var key: String = "hole|%d|%s" % [r, edge]
	if _tex.has(key):
		return _tex[key]
	var n: int = (r + 12) * 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var d: float = Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length()
			var a: float = 1.0
			match edge:
				"soft":
					a = smoothstep(r * 0.45, r + 10.0, d)
				"dither":
					if d < r:
						a = 0.0
					elif d < r + 5.0:
						a = 1.0 if x % 2 == 0 and y % 2 == 0 else 0.0
					elif d < r + 10.0:
						a = 1.0 if (x + y) % 2 == 0 else 0.0
				_:
					if d < r:
						a = 0.0
					elif d < r + 4.0:
						a = 1.0 if (x + y) % 2 == 0 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]

func _cloud_tex() -> Texture2D:
	if _tex.has("cloud"):
		return _tex["cloud"]
	var img := Image.create(56, 28, false, Image.FORMAT_RGBA8)
	var blobs: Array = [[16, 16, 14, 9], [30, 12, 15, 11], [42, 17, 12, 8], [24, 19, 18, 7]]
	for y: int in 28:
		for x: int in 56:
			for b: Array in blobs:
				if Vector2((x - float(b[0])) / float(b[2]), (y - float(b[1])) / float(b[3])).length() < 1.0:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
					break
	_tex["cloud"] = ImageTexture.create_from_image(img)
	return _tex["cloud"]

## Era III on: a door shuts from both sides; stairs fill step by step, upward when climbing.
func _paint_wipe(c: Painter, vs: Vector2) -> void:
	if wipe_style.is_empty() or wipe_k <= 0.0:
		return
	if wipe_style == "door_wipe":
		var w: float = ceilf(vs.x / 2.0 * wipe_k)
		c.draw_rect(Rect2(0, 0, w, vs.y), UITheme.INK)
		c.draw_rect(Rect2(vs.x - w, 0, w, vs.y), UITheme.INK)
		return
	var hgt: float = ceilf(vs.y / WIPE_STRIPS)
	for j: int in WIPE_STRIPS:
		var p: float = clampf((wipe_k - 0.6 * j / (WIPE_STRIPS - 1.0)) / 0.4, 0.0, 1.0)
		if p <= 0.0:
			continue
		var row: int = WIPE_STRIPS - 1 - j if wipe_up else j
		var w: float = ceilf(vs.x * p)
		c.draw_rect(Rect2(0.0 if j % 2 == 0 else vs.x - w, row * hgt, w, hgt), UITheme.INK)
