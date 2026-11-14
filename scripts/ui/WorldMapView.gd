class_name WorldMapView
extends Control
## The world map picture (area 3 items 1242-1244, 1248, 1169, 1273): every place of
## data/world_layout.json as a cell, roads between neighbours, boat and coach lines dotted.
## Unknown places stay empty parchment, sighted ones are an outline, visited ones are filled.
## Fixed symbols: the player (ink square), rest points (cross), stops (small square), Rifts (x)
## and the player's own marks (mid dot). A tap on a place emits place_tapped; dragging pans
## at 2x zoom. The time-of-day symbol sits in the corner. UITheme colours only.

signal place_tapped(place: String)

const CELL_1X: int = 11
const DRAG_SLOP: float = 4.0

var zoom: int = 1
var pan: Vector2 = Vector2.ZERO
var current: String = ""
var known: Dictionary = {}
var _press: Vector2 = Vector2(NAN, NAN)
var _dragged: bool = false
var _phase_icon: PhaseIcon
## Era V: the "you are here" square pulses with a ring (still under reduced motion).
var pulse: bool = false
var _pulse_t: float = 0.0

func _process(delta: float) -> void:
	if pulse and not Juice.reduced():
		_pulse_t += delta
		queue_redraw()

func _ready() -> void:
	name = "world_map"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_phase_icon = PhaseIcon.new()
	add_child(_phase_icon)
	refresh()

func refresh(here: String = current) -> void:
	current = here
	known = WorldAtlas.known(current)
	if _phase_icon != null:
		_phase_icon.phase = DayCycle.current()
		_phase_icon.queue_redraw()
	queue_redraw()

func cell_px() -> int:
	return CELL_1X * zoom

## Toggles 1x / 2x and keeps the player's place in view.
func toggle_zoom() -> void:
	zoom = 2 if zoom == 1 else 1
	center_on_here()

## "Here": pans so the player's place sits in the middle.
func center_on_here() -> void:
	var place: String = WorldAtlas.place_of(current)
	if place.is_empty():
		pan = Vector2.ZERO
	else:
		var c: Vector2 = (Vector2(WorldAtlas.grid_cell(place)) + Vector2(0.5, 0.5)) * cell_px()
		pan = c - size / 2.0
	_clamp_pan()
	queue_redraw()

func _clamp_pan() -> void:
	var full: Vector2 = Vector2(WorldAtlas.grid_size()) * cell_px()
	pan.x = clampf(pan.x, minf(0.0, full.x - size.x), maxf(0.0, full.x - size.x))
	pan.y = clampf(pan.y, minf(0.0, full.y - size.y), maxf(0.0, full.y - size.y))
	if full.x <= size.x:
		pan.x = (full.x - size.x) / 2.0
	if full.y <= size.y:
		pan.y = (full.y - size.y) / 2.0

## Screen rectangle of a place's cell.
func cell_rect(place: String) -> Rect2:
	var p: int = cell_px()
	return Rect2(Vector2(WorldAtlas.grid_cell(place)) * p - pan, Vector2(p, p))

## Place under a point in this control, or "" (only places the player knows).
func place_at_point(at: Vector2) -> String:
	var c: Vector2i = Vector2i(((at + pan) / cell_px()).floor())
	var id: String = WorldAtlas.place_at(c)
	return id if int(known.get(id, WorldAtlas.Known.UNKNOWN)) != WorldAtlas.Known.UNKNOWN else ""

func _gui_input(event: InputEvent) -> void:
	if TapInput.is_press(event):
		_press = TapInput.position(event)
		_dragged = false
		accept_event()
	elif TapInput.is_release(event) and not is_nan(_press.x):
		if not _dragged:
			var id: String = place_at_point(TapInput.position(event))
			if not id.is_empty():
				place_tapped.emit(id)
		_press = Vector2(NAN, NAN)
		accept_event()
	elif event is InputEventMouseMotion and not is_nan(_press.x):
		# Touch drags arrive as emulated mouse motion too (see TapInput).
		var motion: InputEventMouseMotion = event
		if motion.position.distance_to(_press) > DRAG_SLOP:
			_dragged = true
		if _dragged:
			pan -= motion.relative
			_clamp_pan()
			queue_redraw()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.ACCENT)
	var p: int = cell_px()
	var places: Dictionary = WorldAtlas.places()
	# Roads between places the player knows, then the boat and coach lines dotted.
	for id: String in places:
		if int(known.get(id, 0)) == WorldAtlas.Known.UNKNOWN:
			continue
		for n: Variant in (places[id] as Dictionary).get("neighbours", []):
			if str(n) > id and int(known.get(str(n), 0)) != WorldAtlas.Known.UNKNOWN:
				draw_line(cell_rect(id).get_center(), cell_rect(str(n)).get_center(), UITheme.MID, 1.0)
	for l: String in Transit.lines():
		var st: Array[String] = Transit.stops(l)
		for i: int in st.size() - 1:
			var a: String = WorldAtlas.place_of(st[i])
			var b: String = WorldAtlas.place_of(st[i + 1])
			if int(known.get(a, 0)) == WorldAtlas.Known.VISITED and int(known.get(b, 0)) != WorldAtlas.Known.UNKNOWN:
				draw_dashed_line(cell_rect(a).get_center(), cell_rect(b).get_center(), UITheme.INK, 1.0, 2.0)
	for id: String in places:
		var r: Rect2 = cell_rect(id).grow(-1.0)
		match int(known.get(id, 0)):
			WorldAtlas.Known.VISITED:
				draw_rect(r, UITheme.BG)
				draw_rect(r, UITheme.INK, false, 1.0)
				_draw_symbols(id, r)
			WorldAtlas.Known.SIGHTED:
				draw_rect(r, UITheme.MID, false, 1.0)
	var here: String = WorldAtlas.place_of(current)
	if not here.is_empty():
		var hr: Rect2 = cell_rect(here)
		var s: float = maxf(3.0, p / 3.0)
		draw_rect(Rect2(hr.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)), UITheme.INK)
		if pulse:
			var grow: float = 1.0 + roundf(2.0 * (0.5 + 0.5 * sin(_pulse_t * 4.0)))
			draw_rect(Rect2(hr.get_center() - Vector2(s, s) / 2.0, Vector2(s, s)).grow(grow), UITheme.INK, false, 1.0)

## Small symbols in the corners of a visited place.
func _draw_symbols(id: String, r: Rect2) -> void:
	var syms: Array[String] = WorldAtlas.symbols(id)
	if "heal" in syms:
		var c: Vector2 = r.position + Vector2(2.5, 2.5)
		draw_line(c - Vector2(1.5, 0), c + Vector2(1.5, 0), UITheme.INK, 1.0)
		draw_line(c - Vector2(0, 1.5), c + Vector2(0, 1.5), UITheme.INK, 1.0)
	if "stop" in syms:
		draw_rect(Rect2(r.end - Vector2(4, 4), Vector2(2, 2)), UITheme.INK)
	if "rift" in syms:
		var c2: Vector2 = r.get_center()
		draw_line(c2 - Vector2(2, 2), c2 + Vector2(2, 2), UITheme.MID, 1.0)
		draw_line(c2 + Vector2(-2, 2), c2 + Vector2(2, -2), UITheme.MID, 1.0)
	var marked: bool = false
	for mid: String in WorldAtlas.maps_of(id):
		marked = marked or not Survey.marks_on(mid).is_empty()
	if marked:
		draw_rect(Rect2(Vector2(r.end.x - 4, r.position.y + 2), Vector2(2, 2)), UITheme.MID)
