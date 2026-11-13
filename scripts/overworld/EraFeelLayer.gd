class_name EraFeelLayer
extends Node2D
## Overworld extras of the era on screen (data/era_feel.json, docs/ERA_FEEL_UI.md), drawn
## between the ground and the people: shimmering water and swaying flowers (Era II on), leaves
## from the grass, the Wayfarer's reflection in water and footprints on paths (Era III on), the
## tilted 2.5D view (Era IV on), and the season tint and a camera that looks ahead (Era V).

const TICK: float = 0.35
const FOOTPRINT_LIFE: float = 2.0
const MAX_FOOTPRINTS: int = 12
const FOOTPRINT_KINDS: Array[int] = [TilesetFactory.Kind.PATH, TilesetFactory.Kind.SCREE]
const TILT_LAYER: int = 5
const TILT_SHADER: Shader = preload("res://shaders/era_tilt.gdshader")
const IRIS_SHADER: Shader = preload("res://shaders/era_iris.gdshader")
const LEAF: Color = Color("4e8a3a")
## Camera look-ahead eases toward its target at this share per second.
const LEAD_EASE: float = 6.0

var map: MapData
var player: Player
var lead: Vector2 = Vector2.ZERO
## {pos: Vector2, dir: Vector2i, life: float}
var footprints: Array[Dictionary] = []
var _phase: int = 0
var _clock: float = 0.0
var _leaves: PixelParticles
var _tilt_layer: CanvasLayer
var _tilt_rect: ColorRect

func _ready() -> void:
	name = "era_feel"
	_leaves = PixelParticles.new()
	add_child(_leaves)
	_tilt_layer = CanvasLayer.new()
	_tilt_layer.layer = TILT_LAYER
	_tilt_rect = ColorRect.new()
	_tilt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tilt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = TILT_SHADER
	_tilt_rect.material = mat
	_tilt_layer.add_child(_tilt_rect)
	add_child(_tilt_layer)
	EraManager.era_changed.connect(func(_e: int) -> void: refresh())
	refresh()

static func on(key: String) -> bool:
	return bool(EraManager.feel(key))

## Applies the era: tilt strength (off under reduced motion) and a redraw.
func refresh() -> void:
	var tilt: float = float(EraManager.feel("tilt"))
	_tilt_layer.visible = tilt > 0.0 and not Juice.reduced()
	(_tilt_rect.material as ShaderMaterial).set_shader_parameter("tilt", tilt)
	if not on("footprints"):
		footprints.clear()
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= TICK:
		_clock = 0.0
		_phase = (_phase + 1) % 4
		queue_redraw()
	for i: int in range(footprints.size() - 1, -1, -1):
		footprints[i].life = float(footprints[i].life) - delta
		if float(footprints[i].life) <= 0.0:
			footprints.remove_at(i)
	if on("reflections") or not footprints.is_empty():
		queue_redraw()
	var target: Vector2 = lead_target(player.moving if player != null else false, player.facing if player != null else "down", float(EraManager.feel("camera_lead")))
	lead = lead.lerp(target, clampf(LEAD_EASE * delta, 0.0, 1.0))

## Where the camera looks ahead to: [param px] pixels in the walking direction while moving.
static func lead_target(moving: bool, facing: String, px: float) -> Vector2:
	if not moving or px <= 0.0 or Juice.reduced():
		return Vector2.ZERO
	return Vector2(GridWalker.DIRS.get(facing, Vector2i.ZERO)) * px

## The camera offset to add this frame, in whole pixels.
func camera_offset() -> Vector2:
	return lead.round()

## Called for every finished player step on [param cell].
func stepped(cell: Vector2i, from_cell: Vector2i) -> void:
	if map == null:
		return
	var kind: int = map.kind_at(cell)
	if on("grass_fx") and kind == TilesetFactory.Kind.TALL_GRASS and not Juice.reduced():
		var feet: Vector2 = GridWalker.cell_to_pos(cell) + Vector2(8, 13)
		_leaves.emit(feet, 3, {"vel": Vector2(0, -16), "spread": 9.0, "life": 0.35, "gravity": 60.0, "color": LEAF})
	if on("footprints") and map.outdoor and map.kind_at(from_cell) in FOOTPRINT_KINDS:
		footprints.append({"pos": GridWalker.cell_to_pos(from_cell), "dir": cell - from_cell, "life": FOOTPRINT_LIFE})
		while footprints.size() > MAX_FOOTPRINTS:
			footprints.pop_front()
	queue_redraw()

func _visible_cells() -> Rect2i:
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	var vp: Vector2 = get_viewport_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * vp
	var t: float = float(GridWalker.TILE)
	return Rect2i(Vector2i(floori(a.x / t) - 1, floori(a.y / t) - 1), Vector2i(ceili((b.x - a.x) / t) + 3, ceili((b.y - a.y) / t) + 3))

func _draw() -> void:
	if map == null:
		return
	var shimmer: bool = on("water_shimmer")
	var sway: bool = on("flower_sway")
	if shimmer or sway:
		var r: Rect2i = _visible_cells()
		for y: int in range(maxi(r.position.y, 0), mini(r.end.y, map.height)):
			for x: int in range(maxi(r.position.x, 0), r.end.x):
				var c := Vector2i(x, y)
				var k: int = map.kind_at(c)
				var o: Vector2 = GridWalker.cell_to_pos(c)
				if shimmer and k == TilesetFactory.Kind.WATER:
					_draw_shimmer(o, x, y)
				elif sway and k == TilesetFactory.Kind.FLOWER:
					var dx: float = 1.0 if (_phase + x + y) % 2 == 0 else -1.0
					draw_rect(Rect2(o + Vector2(7 + dx, 5), Vector2(1, 1)), Color(1, 1, 1, 0.55))
	for f: Dictionary in footprints:
		var a: float = clampf(float(f.life) / FOOTPRINT_LIFE, 0.0, 1.0) * 0.45
		var d: Vector2i = f.dir
		var side := Vector2(absf(d.y), absf(d.x)) * 2.0
		var mid: Vector2 = (f.pos as Vector2) + Vector2(7, 7)
		draw_rect(Rect2(mid - side, Vector2(2, 2)), Color(UITheme.INK, a))
		draw_rect(Rect2(mid + side + Vector2(d) * 3.0, Vector2(2, 2)), Color(UITheme.INK, a))
	if on("reflections"):
		_draw_reflection()

## Two short light strokes per water cell that move along with the tick.
func _draw_shimmer(o: Vector2, x: int, y: int) -> void:
	var off: int = (x * 7 + y * 13) % 4
	var p: int = (_phase + off) % 4
	var c := Color(1, 1, 1, 0.35)
	draw_rect(Rect2(o + Vector2(2 + p * 3, 4 + off * 2), Vector2(3, 1)), c)
	draw_rect(Rect2(o + Vector2(12 - p * 2, 11 - off), Vector2(2, 1)), c)

## The Wayfarer upside down in the water cell below, faint (Era III on).
func _draw_reflection() -> void:
	if player == null or map.kind_at(player.cell + Vector2i.DOWN) != TilesetFactory.Kind.WATER:
		return
	var sheet: Texture2D = GridWalker.sheet_for(player.sprite_style)
	if sheet == null:
		return
	var src := Rect2(GridWalker.SHEET_COLUMNS[player.shown_facing()] * GridWalker.TILE, player.step_frame() * GridWalker.TILE, GridWalker.TILE, GridWalker.TILE)
	var base: Vector2 = player.position + Vector2(0, GridWalker.TILE * 2)
	draw_set_transform(base, 0.0, Vector2(1, -1))
	draw_texture_rect_region(sheet, Rect2(0, 0, GridWalker.TILE, GridWalker.TILE), src, Color(0.75, 0.85, 1.0, 0.4))
	draw_set_transform(Vector2.ZERO)

## Iris close for warps of Eras IV and V: a circle around [param center] shrinks to black on
## [param layer]. Awaitable; the caller covers the screen with its fade afterwards.
static func iris_close(layer: CanvasLayer, center: Vector2, color: Color, time: float) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = IRIS_SHADER
	var vp: Vector2 = layer.get_viewport().get_visible_rect().size
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("size_px", vp)
	mat.set_shader_parameter("ink", color)
	mat.set_shader_parameter("radius", vp.length())
	rect.material = mat
	layer.add_child(rect)
	var tw: Tween = rect.create_tween()
	tw.tween_method(func(r: float) -> void: mat.set_shader_parameter("radius", r), vp.length(), 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	rect.queue_free()
