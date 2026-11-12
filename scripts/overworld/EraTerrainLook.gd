class_name EraTerrainLook
extends Node2D
## Overworld terrain look per era (data/era_overworld_look.json, docs/ERA_FEEL_TILES.md): each
## era's maps look one handheld generation newer. Sits right above the ground tiles and draws
## the tile animation (2 frames in Era I, 8 with a travelling wave in Era V), ragged ground
## edges, bank lines, reflections of the terrain in water and the contact shade (Era III on);
## its children draw the drop shadows and the raised tiles over them, and a layer above the
## people draws tree crowns, roof ridges and cliff lips (Era IV on), pennants and the lean of
## tall things away from the view centre (Era V). The shadows turn with the time of day.
## A map takes the tier of its region's era, capped by the era on screen, so the story acts
## stay flat Ink maps. Reduced motion freezes every frame, the lean and the zoom.

const PATH: String = "res://data/era_overworld_look.json"
const TILE: int = TilesetFactory.TILE
const BOOL_KEYS: Array[String] = ["edges", "contact_shade", "reflections", "drop_shadows", "banners"]
const NUM_KEYS: Array[String] = ["canopy_lift", "parallax_px", "town_zoom"]
const STYLES: Array[String] = ["flip", "sway", "scroll"]
## Kinds cut out of their grass in the raised atlas (tools/art/gen_era_raised.py CUT).
const CUT_KINDS: Array[int] = [TilesetFactory.Kind.TREE, TilesetFactory.Kind.FENCE, TilesetFactory.Kind.SIGN, TilesetFactory.Kind.TOWER, TilesetFactory.Kind.LAMP, TilesetFactory.Kind.ROCK]
## Casters with a slim foot; the others shade the full tile width.
const SLIM: Array[int] = [TilesetFactory.Kind.TREE, TilesetFactory.Kind.LAMP, TilesetFactory.Kind.SIGN, TilesetFactory.Kind.ROCK, TilesetFactory.Kind.TOWER]
const INTERIOR_ROW: int = 15
const MARGIN: int = 3
const SHADE: Color = Color(0.05, 0.04, 0.1)
const POLE: Color = Color("2a1e2c")

## Off for the "before" screenshots (tools/era_tiles_shots.gd).
static var enabled: bool = true
static var _data: Dictionary = {}

var map: MapData
var ground: TileMapLayer
var camera: Camera2D
var tier: int = 1
var cfg: Dictionary = {}
var frame: int = 0
## Seconds since the map was shown; < 0 when the view does not zoom.
var zoom_t: float = -1.0
var canopy: Painter
## Clips the canopy to the map, so nothing hangs over the edge of a map smaller than the screen.
var canopy_root: Control
var _shadow_clip: Control
var _shadow_group: CanvasGroup
var _shadows: Painter
var _raised: Painter
var _tex: Texture2D
var _raised_tex: Texture2D
var _clock: float = 0.0
var _last_cam: Vector2 = Vector2.INF
var _anim: Dictionary[int, String] = {}
var _sway_rows: Dictionary[int, int] = {}
var _casters: Dictionary[int, int] = {}
var _canopy_rows: Dictionary[int, int] = {}
var _colors: Dictionary[int, Color] = {}
var _banners: Array[Dictionary] = []
var _zoomed: bool = false

## Draws through a callable, so one script owns every layer.
class Painter extends Node2D:
	var paint: Callable
	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)

# --- Data --------------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data

static func era_cfg(era: int) -> Dictionary:
	return data().get("eras", {}).get(str(era), {})

static func shared(key: String, fallback: Variant = null) -> Variant:
	return data().get("shared", {}).get(key, fallback)

## Tier of a map in [param region] while era [param active] is on screen: the region's own era,
## never newer than the screen (Retro filter), so old regions keep their origin look.
static func tier_for(region: String, active: int) -> int:
	return clampi(mini(EraManager.region_era(region), active), EraManager.Era.INK, EraManager.NEWEST)

static func kind_of(kind_name: String) -> int:
	return int(TilesetFactory.Kind.get(kind_name, -1))

static func kinds_of(names: Variant) -> Array[int]:
	var out: Array[int] = []
	if names is Array:
		for n: Variant in names:
			out.append(kind_of(str(n)))
	return out

## Every flaw of the data file: a missing era or key, an unknown kind or style, or a later era
## that loses something an earlier one had. Empty when the file is sound.
static func problems() -> Array[String]:
	var out: Array[String] = []
	var before: Dictionary = {}
	for era: int in range(EraManager.Era.INK, EraManager.NEWEST + 1):
		var c: Dictionary = era_cfg(era)
		if c.is_empty():
			out.append("era %d is not configured" % era)
			continue
		var wanted: Array[String] = ["anim"]
		wanted.append_array(BOOL_KEYS)
		wanted.append_array(NUM_KEYS)
		for key: String in wanted:
			if not c.has(key):
				out.append("era %d: missing %s" % [era, key])
		var anim: Dictionary = c.get("anim", {})
		for key: String in ["frames", "period", "wave", "kinds"]:
			if not anim.has(key):
				out.append("era %d: anim misses %s" % [era, key])
		for kind_name: String in anim.get("kinds", {}):
			if kind_of(kind_name) < 0:
				out.append("era %d: unknown kind %s" % [era, kind_name])
			if not str(anim.kinds[kind_name]) in STYLES:
				out.append("era %d: unknown style %s" % [era, anim.kinds[kind_name]])
		if not before.is_empty():
			for key: String in BOOL_KEYS:
				if bool(before.get(key, false)) and not bool(c.get(key, false)):
					out.append("era %d loses %s" % [era, key])
			for key: String in NUM_KEYS:
				if float(c.get(key, 0)) < float(before.get(key, 0)):
					out.append("era %d: %s goes down" % [era, key])
			var old: Dictionary = before.get("anim", {})
			if int(anim.get("frames", 0)) < int(old.get("frames", 0)):
				out.append("era %d has fewer frames" % era)
			if float(anim.get("period", 0)) > float(old.get("period", 0)):
				out.append("era %d animates slower" % era)
			if bool(old.get("wave", false)) and not bool(anim.get("wave", false)):
				out.append("era %d loses the wave" % era)
			for kind_name: String in old.get("kinds", {}):
				if not (anim.get("kinds", {}) as Dictionary).has(kind_name):
					out.append("era %d stops animating %s" % [era, kind_name])
		before = c
	var first: Dictionary = era_cfg(EraManager.Era.INK).get("anim", {})
	if int(first.get("frames", 0)) > 2:
		out.append("era 1 has more than 2 frames")
	for kind_name: String in first.get("kinds", {}):
		if not kind_name in ["WATER", "FLOWER"]:
			out.append("era 1 animates %s" % kind_name)
	for key: String in ["sway_rows", "casters", "canopy"]:
		for kind_name: String in shared(key, {}):
			if kind_of(kind_name) < 0:
				out.append("shared %s: unknown kind %s" % [key, kind_name])
	for key: String in ["edge_onto", "edge_from", "shore_kinds", "shore_joins", "reflect_from", "flat", "bridge_kinds"]:
		if -1 in kinds_of(shared(key, [])) or kinds_of(shared(key, [])).is_empty():
			out.append("shared %s: empty or unknown kind" % key)
	for phase: String in DayCycle.PHASE_NAMES:
		var l: Dictionary = shared("sun", {}).get(phase, {})
		for key: String in ["dir", "alpha"]:
			if not l.has(key):
				out.append("sun %s misses %s" % [phase, key])
	return out

# --- Pure rules (tested in tests/unit/test_era_overworld_look.gd) --------------------

## The frame on screen after [param ticks] periods; always 0 with reduced motion.
static func anim_frame(ticks: int, frames: int, reduced: bool) -> int:
	return 0 if reduced or frames <= 1 else posmod(ticks, frames)

## Sideways lean in px of a swaying tile: 2 frames nod (0, 1), more frames swing both ways;
## with [param wave] the swing starts later the further right and down the cell is.
static func sway_offset(frames: int, at: int, cell: Vector2i, wave: bool) -> int:
	if frames <= 1:
		return 0
	if frames == 2:
		return at % 2
	var f: int = posmod(at + (cell.x + cell.y * 2 if wave else 0), frames)
	return roundi(sin(TAU * f / frames))

## Drift in px of scrolling water: out and back, one px a frame.
static func scroll_offset(frames: int, at: int) -> int:
	var f: int = posmod(at, maxi(frames, 1))
	return mini(f, frames - f)

## Where the top of a [param height] px tall thing throws its shadow under [param sun].
static func shadow_shift(sun: Vector2, height: float) -> Vector2:
	return (sun * height).round()

## Outline of the ground a foot [param foot] shades when its shadow ends [param shift] away.
static func shadow_hull(foot: Rect2, shift: Vector2) -> PackedVector2Array:
	var a: Vector2 = foot.position
	var b: Vector2 = foot.end
	if shift.x >= 0.0:
		return PackedVector2Array([a, Vector2(b.x, a.y), Vector2(b.x, a.y) + shift, b + shift, Vector2(a.x, b.y) + shift, Vector2(a.x, b.y)])
	return PackedVector2Array([a, Vector2(b.x, a.y), b, b + shift, Vector2(a.x, b.y) + shift, a + shift])

## Lean in whole px of a tall thing at [param pos] away from the view centre: [param ref] px
## of distance per px, at most [param px_max]. Zero with reduced motion.
static func lean(pos: Vector2, center: Vector2, px_max: float, ref: float, reduced: bool) -> Vector2:
	if reduced or px_max <= 0.0 or ref <= 0.0:
		return Vector2.ZERO
	var d: Vector2 = (pos - center) / ref
	return Vector2(clampf(d.x, -px_max, px_max), clampf(d.y, -px_max, px_max)).round()

## Camera zoom [param t] seconds after walking into a town: from a little wider than usual
## back to 1 (crisp pixels). 1 with reduced motion or when the era has no zoom.
static func zoom_at(t: float, amount: float, time: float, reduced: bool) -> float:
	if reduced or amount <= 0.0 or time <= 0.0 or t < 0.0:
		return 1.0
	return lerpf(1.0 - amount, 1.0, smoothstep(0.0, 1.0, clampf(t / time, 0.0, 1.0)))

## The sun of [param phase] (data "sun": shadow direction and strength); the plain day on
## indoor maps or when the player switched the day cycle off.
static func sun_of(phase: int, outdoor: bool, day_night: bool) -> Dictionary:
	var name_now: String = DayCycle.phase_name(phase) if outdoor and day_night else "day"
	return shared("sun", {}).get(name_now, {})

static func is_town(biome: String) -> bool:
	return biome in (shared("town_biomes", []) as Array)

# --- Node --------------------------------------------------------------------------

func _ready() -> void:
	name = "era_terrain"
	_shadow_clip = _clip_box()
	add_child(_shadow_clip)
	_shadow_group = CanvasGroup.new()
	_shadow_clip.add_child(_shadow_group)
	_shadows = Painter.new()
	_shadows.paint = _paint_shadows
	_shadow_group.add_child(_shadows)
	_raised = Painter.new()
	_raised.paint = _paint_raised
	add_child(_raised)
	canopy_root = _clip_box()
	canopy_root.name = "era_canopy"
	canopy = Painter.new()
	canopy.paint = _paint_canopy
	canopy_root.add_child(canopy)
	EraManager.era_changed.connect(_on_era_changed)

func _on_era_changed(_era: int) -> void:
	if map != null:
		show_map(map, ground, camera)

static func _clip_box() -> Control:
	var box := Control.new()
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func _exit_tree() -> void:
	if canopy_root != null and canopy_root.get_parent() == null:
		canopy_root.free()

## Takes over [param m] as painted on [param ground_layer]. The canopy goes right above
## [param over] (the people), so crowns and ridges cover whoever walks behind them.
func show_map(m: MapData, ground_layer: TileMapLayer, cam: Camera2D = null, over: Node = null) -> void:
	map = m
	ground = ground_layer
	camera = cam
	if canopy_root.get_parent() == null and over != null and over.get_parent() != null:
		over.add_sibling(canopy_root)
	canopy_root.size = Vector2(m.width, m.height) * TILE
	_shadow_clip.size = canopy_root.size
	tier = tier_for(m.region, EraManager.active_era())
	cfg = era_cfg(tier) if enabled else {}
	_tex = null
	_raised_tex = null
	if ground != null and ground.tile_set != null and ground.tile_set.get_source_count() > 0:
		_tex = (ground.tile_set.get_source(0) as TileSetAtlasSource).texture
	var raised_path: String = str(shared("raised_atlas", "")) % [EraManager.region_era(m.region), m.region]
	if tier >= EraManager.Era.ETCHED and ResourceLoader.exists(raised_path):
		_raised_tex = load(raised_path)
	_anim.clear()
	var anim_kinds: Dictionary = cfg.get("anim", {}).get("kinds", {})
	for kind_name: String in anim_kinds:
		_anim[kind_of(kind_name)] = str(anim_kinds[kind_name])
	_sway_rows = _kind_ints("sway_rows")
	_casters = _kind_ints("casters")
	_canopy_rows = _kind_ints("canopy")
	_colors.clear()
	_find_banners()
	zoom_t = 0.0 if float(cfg.get("town_zoom", 0.0)) > 0.0 and m.outdoor and is_town(m.biome) and not Juice.reduced() else -1.0
	_apply_zoom()
	_last_cam = Vector2.INF
	redraw()

func _kind_ints(key: String) -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	var src: Dictionary = shared(key, {})
	for kind_name: String in src:
		out[kind_of(kind_name)] = int(src[kind_name])
	return out

func redraw() -> void:
	queue_redraw()
	_shadows.queue_redraw()
	_raised.queue_redraw()
	canopy.queue_redraw()

func _process(delta: float) -> void:
	if map == null:
		return
	_clock += delta
	var anim: Dictionary = cfg.get("anim", {})
	var period: float = float(anim.get("period", 0.5))
	var dirty: bool = false
	if _clock >= period:
		_clock = 0.0
		frame = anim_frame(frame + 1, int(anim.get("frames", 1)), Juice.reduced())
		dirty = true
	if zoom_t >= 0.0:
		zoom_t += delta
		_apply_zoom()
		if zoom_t >= float(shared("town_zoom_time", 1.0)):
			zoom_t = -1.0
	var cam: Vector2 = _view_center()
	var leaning: bool = float(cfg.get("parallax_px", 0)) > 0.0 and not Juice.reduced()
	if (cam / (1.0 if leaning else float(TILE))).floor() != (_last_cam / (1.0 if leaning else float(TILE))).floor():
		_last_cam = cam
		dirty = true
	if dirty:
		redraw()

func _apply_zoom() -> void:
	if camera == null:
		return
	var z: float = zoom_at(zoom_t, float(cfg.get("town_zoom", 0.0)), float(shared("town_zoom_time", 1.0)), Juice.reduced())
	if z != 1.0 or _zoomed:
		camera.zoom = Vector2(z, z)
		_zoomed = z != 1.0

func _view_center() -> Vector2:
	return camera.get_screen_center_position() if camera != null and camera.is_inside_tree() else Vector2.ZERO

## Cells on screen plus a margin (the whole map without a camera).
func _cells() -> Rect2i:
	var all := Rect2i(0, 0, map.width, map.height)
	if camera == null or not camera.is_inside_tree():
		return all
	var half: Vector2 = get_viewport_rect().size / camera.zoom / 2.0
	var c: Vector2 = _view_center()
	var from := Vector2i(((c - half) / TILE).floor()) - Vector2i(MARGIN, MARGIN)
	var to := Vector2i(((c + half) / TILE).ceil()) + Vector2i(MARGIN, MARGIN)
	return Rect2i(from, to - from).intersection(all)

func _on(key: String) -> bool:
	return bool(cfg.get(key, false))

func _kind(c: Vector2i) -> int:
	return map.kind_at(c) if map.in_bounds(c) else -1

func _coords(c: Vector2i) -> Vector2i:
	return ground.get_cell_atlas_coords(c)

## Mean colour of a kind's first tile in the atlas on screen (the fallback colour without one).
func _color(kind: int) -> Color:
	if not _colors.has(kind):
		var col: Color = TilesetFactory.COLORS.get(kind, Color.GRAY)
		var img: Image = _tex.get_image() if _tex != null else null
		if img != null and not img.is_empty() and img.get_width() >= (kind + 1) * TILE and not img.is_compressed():
			var sum := Vector3.ZERO
			var n: int = 0
			for y: int in range(0, TILE, 3):
				for x: int in range(0, TILE, 3):
					var p: Color = img.get_pixel(kind * TILE + x, y)
					if p.a > 0.5:
						sum += Vector3(p.r, p.g, p.b)
						n += 1
			if n > 0:
				col = Color(sum.x / n, sum.y / n, sum.z / n)
		_colors[kind] = col
	return _colors[kind]

## Rows [param y0] .. y0 + h of the tile at [param coords], drawn at cell origin [param at].
static func _blit(ci: CanvasItem, tex: Texture2D, coords: Vector2i, at: Vector2, y0: int = 0, h: int = TILE, tint: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(tex, Rect2(at + Vector2(0, y0), Vector2(TILE, h)), Rect2(Vector2(coords * TILE) + Vector2(0, y0), Vector2(TILE, h)), tint)

## Like _blit, moved [param dx] px sideways and wrapped inside the tile.
static func _blit_shift(ci: CanvasItem, tex: Texture2D, coords: Vector2i, at: Vector2, y0: int, h: int, dx: int) -> void:
	var d: int = posmod(dx, TILE)
	if d == 0:
		_blit(ci, tex, coords, at, y0, h)
		return
	var src: Vector2 = Vector2(coords * TILE) + Vector2(0, y0)
	ci.draw_texture_rect_region(tex, Rect2(at + Vector2(d, y0), Vector2(TILE - d, h)), Rect2(src, Vector2(TILE - d, h)))
	ci.draw_texture_rect_region(tex, Rect2(at + Vector2(0, y0), Vector2(d, h)), Rect2(src + Vector2(TILE - d, 0), Vector2(d, h)))

static func _hash(c: Vector2i, salt: int) -> int:
	return absi(c.x * 73 + c.y * 151 + salt * 31 + (c.x * c.y) % 7)

# --- Ground layer --------------------------------------------------------------------

func _draw() -> void:
	if map == null or ground == null or _tex == null or cfg.is_empty():
		return
	var anim: Dictionary = cfg.get("anim", {})
	var frames: int = int(anim.get("frames", 1))
	var wave: bool = bool(anim.get("wave", false))
	var shore: Array[int] = kinds_of(shared("shore_kinds", []))
	var shore_joins: Array[int] = kinds_of(shared("shore_joins", []))
	var onto: Array[int] = kinds_of(shared("edge_onto", []))
	var from: Array[int] = kinds_of(shared("edge_from", []))
	var mirrored: Array[int] = kinds_of(shared("reflect_from", []))
	var flat: Array[int] = kinds_of(shared("flat", []))
	var bridges: Array[int] = kinds_of(shared("bridge_kinds", []))
	var contact: bool = _on("contact_shade") and not (_on("drop_shadows") and map.outdoor)
	var area: Rect2i = _cells()
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			var k: int = _kind(c)
			var at := Vector2(c * TILE)
			var coords: Vector2i = _coords(c)
			var style: String = _anim.get(k, "")
			var masked: bool = k in TilesetFactory.MASKED
			if style == "flip" and frame % 2 == 1 and (not masked or coords.y == INTERIOR_ROW):
				draw_set_transform(at + Vector2(TILE, 0), 0.0, Vector2(-1, 1))
				_blit(self, _tex, coords, Vector2.ZERO)
				draw_set_transform(Vector2.ZERO)
			elif style == "scroll" and coords.y == INTERIOR_ROW:
				_blit_shift(self, _tex, coords, at, 0, TILE, scroll_offset(frames, frame + (x + y if wave else 0)))
			elif style == "sway" and k != TilesetFactory.Kind.TREE and not (k == TilesetFactory.Kind.GRASS and coords.y >= TilesetFactory.SHADOW_ROW):
				var off: int = sway_offset(frames, frame, c, wave)
				if off != 0:
					_blit_shift(self, _tex, coords, at, 0, int(_sway_rows.get(k, TILE / 2)), off)
			if k in shore:
				var up: int = _kind(c + Vector2i.UP)
				if _on("reflections") and up in mirrored:
					_reflect(c + Vector2i.UP, up, at)
				if float(cfg.get("parallax_px", 0)) > 0.0 and up in bridges:
					var p: Vector2 = _lean(at + Vector2(TILE, TILE) / 2.0)
					draw_rect(Rect2(at.x + maxf(p.x, 0.0), at.y, TILE - absf(p.x), 4.0 + p.y), Color(SHADE, float(shared("bridge_shadow_alpha", 0.3))))
				if _on("edges"):
					_shore(c, k, at, shore_joins)
			if _on("edges") and k in onto:
				for i: int in TilesetFactory.MASK_DIRS.size():
					var nk: int = _kind(c + TilesetFactory.MASK_DIRS[i])
					if nk in from:
						_fringe(c, i, at, _color(nk))
			if contact and k in flat:
				var a: float = float(shared("contact_alpha", 0.2))
				if _tall(_kind(c + Vector2i.UP), flat):
					draw_rect(Rect2(at, Vector2(TILE, 2)), Color(SHADE, a))
					draw_rect(Rect2(at + Vector2(0, 2), Vector2(TILE, 2)), Color(SHADE, a / 2.0))
				if _tall(_kind(c + Vector2i.LEFT), flat):
					draw_rect(Rect2(at, Vector2(2, TILE)), Color(SHADE, a / 2.0))

func _tall(kind: int, flat: Array[int]) -> bool:
	return _casters.has(kind) and not kind in flat

func _lean(pos: Vector2) -> Vector2:
	return lean(pos, _view_center(), float(cfg.get("parallax_px", 0)), float(shared("parallax_ref", 40.0)), Juice.reduced())

## The tile above a water cell, upside down in the water.
func _reflect(src_cell: Vector2i, kind: int, at: Vector2) -> void:
	var tex: Texture2D = _raised_tex if kind in CUT_KINDS else _tex
	if tex == null:
		return
	var coords: Vector2i = _coords(src_cell)
	var alpha: float = float(shared("reflect_alpha", 0.3))
	draw_set_transform(at, 0.0, Vector2(1, -1))
	# Four bands, fainter the deeper the picture reaches into the water.
	for band: int in 4:
		var y0: int = TILE - (band + 1) * 4
		draw_texture_rect_region(tex, Rect2(0, y0 - TILE, TILE, 4), Rect2(Vector2(coords * TILE) + Vector2(0, y0), Vector2(TILE, 4)), Color(1, 1, 1, alpha * (1.0 - band * 0.25)))
	draw_set_transform(Vector2.ZERO)

## Bank line and moving foam where water meets land.
func _shore(c: Vector2i, kind: int, at: Vector2, joins: Array[int]) -> void:
	var water: Color = _color(kind)
	for i: int in TilesetFactory.MASK_DIRS.size():
		var n: Vector2i = c + TilesetFactory.MASK_DIRS[i]
		if not map.in_bounds(n) or _kind(n) in joins:
			continue
		for s: int in range(0, TILE, 2):
			var foam: bool = (s / 2 + frame + _hash(c, i)) % 4 == 0
			var col: Color = Color(water.lightened(0.55), 0.85) if foam else Color(water.darkened(0.35), 0.6)
			draw_rect(_edge_rect(at, i, s, 2, 1, 1 if foam else 0), col)

## Ragged tufts of the neighbour's green reaching onto bare ground, side [param side].
func _fringe(c: Vector2i, side: int, at: Vector2, green: Color) -> void:
	for s: int in range(0, TILE, 2):
		var depth: int = _hash(c + Vector2i(s, side), side) % 4
		if depth == 0:
			continue
		draw_rect(_edge_rect(at, side, s, 2, depth, 0), green if depth < 3 else green.darkened(0.18))

## A rect [param along] px wide and [param depth] px deep on side [param side] (MASK_DIRS
## order) of the tile at [param at], [param s] px along the edge and [param inset] px in.
static func _edge_rect(at: Vector2, side: int, s: int, along: int, depth: int, inset: int) -> Rect2:
	match side:
		0:
			return Rect2(at.x + s, at.y + inset, along, depth)
		1:
			return Rect2(at.x + TILE - inset - depth, at.y + s, depth, along)
		2:
			return Rect2(at.x + s, at.y + TILE - inset - depth, along, depth)
	return Rect2(at.x + inset, at.y + s, depth, along)

# --- Shadows and raised tiles ---------------------------------------------------------

func _shadows_on() -> bool:
	return map != null and ground != null and _tex != null and _on("drop_shadows") and map.outdoor

func _paint_shadows(ci: CanvasItem) -> void:
	if not _shadows_on():
		return
	var l: Dictionary = sun_of(DayCycle.current(), map.outdoor, GameState.day_night)
	var sun_raw: Array = l.get("dir", [0.3, 0.3])
	var sun := Vector2(float(sun_raw[0]), float(sun_raw[1]))
	_shadow_group.self_modulate = Color(1, 1, 1, float(l.get("alpha", 0.3)))
	var area: Rect2i = _cells()
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			var k: int = _kind(c)
			if not _casters.has(k):
				continue
			var at := Vector2(c * TILE)
			var foot: Rect2 = Rect2(at + Vector2(3, 9), Vector2(10, 7)) if k in SLIM else Rect2(at, Vector2(TILE, TILE))
			ci.draw_colored_polygon(shadow_hull(foot, shadow_shift(sun, float(_casters[k]))), SHADE)

## The casters again, over the shadows that fell on them.
func _paint_raised(ci: CanvasItem) -> void:
	if not _shadows_on():
		return
	var area: Rect2i = _cells()
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			var k: int = _kind(c)
			if not _casters.has(k):
				continue
			var tex: Texture2D = _raised_tex if k in CUT_KINDS else _tex
			if tex != null:
				_blit(ci, tex, _coords(c), Vector2(c * TILE))

# --- Canopy (over the people) ---------------------------------------------------------

## True when the top of the tile at [param c] stands free and may be lifted over the cell above.
func _has_top(c: Vector2i, kind: int) -> bool:
	var up: int = _kind(c + Vector2i.UP)
	match kind:
		TilesetFactory.Kind.TREE, TilesetFactory.Kind.LAMP:
			return true
		TilesetFactory.Kind.ROOF:
			return up != TilesetFactory.Kind.ROOF
		TilesetFactory.Kind.TOWER:
			return up != TilesetFactory.Kind.TOWER and up != TilesetFactory.Kind.LAMP
		TilesetFactory.Kind.CLIFF:
			return up >= 0 and not TilesetFactory.is_solid(up) and up != TilesetFactory.Kind.STAIRS
	return false

## Pennant poles: on free tower tops and on the ridge over every house door (the healer's and
## the shop's in their own colours).
func _find_banners() -> void:
	_banners.clear()
	if not _on("banners") or not map.outdoor:
		return
	var roles: Dictionary = map.door_roles()
	for y: int in map.height:
		for x: int in map.width:
			var door := Vector2i(x, y)
			if _kind(door) != TilesetFactory.Kind.DOOR:
				continue
			var role: int = int(roles.get(door, TilesetFactory.DoorRole.HOUSE))
			if role == TilesetFactory.DoorRole.HEAL or role == TilesetFactory.DoorRole.SHOP:
				_roof_banner(door, role - 1)
			else:
				_roof_banner(door, 2 + (x + y) % 2)
	for y: int in map.height:
		for x: int in map.width:
			var c := Vector2i(x, y)
			if _kind(c) == TilesetFactory.Kind.TOWER and _has_top(c, TilesetFactory.Kind.TOWER):
				_banners.append({"cell": c, "color": 2})

func _roof_banner(door: Vector2i, color: int) -> void:
	var top: Vector2i = door
	while _kind(top + Vector2i.UP) in [TilesetFactory.Kind.WALL, TilesetFactory.Kind.ROOF]:
		top += Vector2i.UP
	if top != door:
		_banners.append({"cell": top, "color": color})

func banner_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for b: Dictionary in _banners:
		out.append(b.cell)
	return out

func _paint_canopy(ci: CanvasItem) -> void:
	if map == null or ground == null or _tex == null or cfg.is_empty():
		return
	var anim: Dictionary = cfg.get("anim", {})
	var frames: int = int(anim.get("frames", 1))
	var lift: int = int(cfg.get("canopy_lift", 0))
	var area: Rect2i = _cells()
	if lift > 0:
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				var c := Vector2i(x, y)
				var k: int = _kind(c)
				if not _canopy_rows.has(k) or not _has_top(c, k):
					continue
				var tex: Texture2D = _raised_tex if k in CUT_KINDS else _tex
				if tex == null:
					continue
				var up_px: int = lift if k == TilesetFactory.Kind.TREE else maxi(lift - 2, 1)
				var at: Vector2 = Vector2(c * TILE) + Vector2(0, -up_px) + _lean(Vector2(c * TILE) + Vector2(TILE, TILE) / 2.0)
				var off: int = sway_offset(frames, frame, c, bool(anim.get("wave", false))) if _anim.get(k, "") == "sway" else 0
				_blit_shift(ci, tex, _coords(c), at, 0, _canopy_rows[k], off)
	var colors: Array = shared("banners", [])
	for b: Dictionary in _banners:
		if colors.is_empty() or not area.has_point(b.cell):
			continue
		var base: Vector2 = Vector2(b.cell * TILE) + Vector2(7, -lift) + _lean(Vector2(b.cell * TILE))
		ci.draw_rect(Rect2(base + Vector2(0, -7), Vector2(1, 9)), POLE)
		var col := Color(str(colors[int(b.color) % colors.size()]))
		for i: int in 3:
			var dy: int = roundi(sin(TAU * frame / maxf(frames, 1.0) + i * 1.3)) if i > 0 else 0
			ci.draw_rect(Rect2(base + Vector2(1 + i * 2, -7 + dy), Vector2(2, 4 - i)), col if i < 2 else col.darkened(0.2))
