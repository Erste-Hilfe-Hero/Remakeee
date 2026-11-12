class_name EraPartyDrag
extends Control
## Drag to reorder the team (Era IV and V, docs/ERA_FEEL_MENUS.md): press a team row, drag it
## over another slot and let go. Sits over the team list while it is open; the list's own
## "Move to slot..." stays for keys, gamepads and screen readers.

const SLOP: float = 8.0

var picker: ListPicker
## How many rows at the top of the list are team members.
var count: int = 0
var from: int = -1
var to: int = -1
var _press: Vector2 = Vector2(NAN, NAN)
var _dragging: bool = false

static func attach(host: MenuHost, n: int) -> EraPartyDrag:
	var d := EraPartyDrag.new()
	d.name = "party_drag"
	d.picker = host.picker
	d.count = n
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.z_index = 5
	host.add_child(d)
	return d

## Row whose rectangle holds [param y] (the nearest row above or below when between rows), or
## -1 with no rows.
static func row_at(rects: Array[Rect2], y: float) -> int:
	var best: int = -1
	var dist: float = INF
	for i: int in rects.size():
		var c: float = rects[i].get_center().y
		if absf(c - y) < dist:
			dist = absf(c - y)
			best = i
	return best

func _rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var rows: Array[Button] = picker.buttons()
	for i: int in mini(count, rows.size()):
		out.append(rows[i].get_global_rect())
	return out

func _input(event: InputEvent) -> void:
	if picker == null or not picker.visible or count < 2:
		return
	if TapInput.is_press(event):
		var pos: Vector2 = TapInput.position(event)
		from = -1
		var rects: Array[Rect2] = _rects()
		for i: int in rects.size():
			if rects[i].has_point(pos):
				from = i
		_press = pos
		_dragging = false
	elif from >= 0 and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		var pos2: Vector2 = (event as InputEventMouseMotion).position if event is InputEventMouseMotion else (event as InputEventScreenDrag).position
		if not _dragging and absf(pos2.y - _press.y) > SLOP:
			_dragging = true
		if _dragging:
			to = row_at(_rects(), pos2.y)
			queue_redraw()
	elif TapInput.is_release(event):
		var was: bool = _dragging
		_dragging = false
		queue_redraw()
		if was and from >= 0:
			get_viewport().set_input_as_handled()
			drop(from, row_at(_rects(), TapInput.position(event).y))
		from = -1

## Moves team member [param a] to slot [param b] and tells the list, so it is drawn again.
func drop(a: int, b: int) -> void:
	if a < 0 or b < 0 or a == b or a >= GameState.party.size() or b >= GameState.party.size():
		return
	GameState.move_party(a, b)
	Sound.sfx("select")
	picker.picked.emit(EraMenus.DRAG_PICKED)

func _draw() -> void:
	if not _dragging or from < 0 or to < 0:
		return
	var rects: Array[Rect2] = _rects()
	if from >= rects.size() or to >= rects.size():
		return
	var off: Vector2 = -global_position
	var src := Rect2(rects[from].position + off, rects[from].size)
	var dst := Rect2(rects[to].position + off, rects[to].size)
	draw_rect(src, UITheme.MID, false, 1.0)
	var y: float = dst.position.y if to <= from else dst.end.y
	draw_line(Vector2(dst.position.x, y), Vector2(dst.end.x, y), UITheme.INK, 2.0)
