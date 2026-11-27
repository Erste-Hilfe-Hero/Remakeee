class_name PuzzleBoard
extends Control
## The screen of a riddle stone (PuzzleSpots). [method run] plays a whole spot: the riddle text,
## then a pick list, a typed answer or one of the boards below, the reward once solved.
## Boards: order and listen (big colour buttons with their names), lights, slide, push and steps
## (a grid drawn here, tapped directly or steered with the arrow row and the pad keys). Sized from
## the viewport, so it fits the 144 px wide Era I screen and grows with later eras.

signal finished(solved: bool)

const MARGIN: int = 6
const CELL_MAX: int = 30
## Arrow row and bottom row height (touch friendly).
const BUTTON_H: int = 18
## Moves on a lights, slide or push board that count as one more try for the hints.
const MOVES_PER_TRY: int = 15
const NOTE_TIME: float = 0.42
const NOTE_GAP: float = 0.14
const GROUND: Dictionary[String, Color] = {"snow": Color("e8eef0"), "sand": Color("e6d2a0"), "mud": Color("9a8466")}

var spot: Dictionary = {}
var kind: String = ""
var moves: int = 0
var solved: bool = false

var _title: Label
var _status: Label
var _canvas: Control
var _color_buttons: Array[Button] = []
var _cell: int = 16
var _cols: int = 0
var _rows: int = 0
var _menu: MenuHost
# order / listen
var _done: int = 0
var _playing: bool = false
var _lit: int = -1
# lights
var _grid: Array[bool] = []
var _cursor: Vector2i = Vector2i.ZERO
# slide
var _tiles: Array[int] = []
# push
var _map: MapData
var _pc: Vector2i
# steps
var _at: Vector2i
var _trail: Array[Vector2i] = []

## Plays the whole spot on [param parent]. Returns true when it was solved just now.
static func run(parent: Node, s: Dictionary) -> bool:
	var menu := MenuHost.new()
	parent.add_child(menu)
	var id: String = str(s.id)
	var head: String = Loc.t(str(s.get("title", ""))) + "\n\n"
	if PuzzleSpots.solved(id):
		var t: String = head + Loc.t("You solved this one already.")
		if s.has("clue"):
			t += "\n\n" + Loc.t("Its line still reads: %s") % Loc.t(str(s.clue))
		await menu.info(t)
		menu.queue_free()
		return false
	if not PuzzleSpots.open(s):
		await menu.info(head + Loc.t("The stone is still blank. Solve the other stones of its set first: %d of %d done.")
			% [PuzzleSpots.needs_done(s), PuzzleSpots.needs(s).size()])
		menu.queue_free()
		return false
	var intro: String = head + Loc.t(str(s.get("text", "")))
	var clues: Array[String] = PuzzleSpots.clues_for(s)
	if not clues.is_empty():
		intro += "\n\n" + Loc.t("The lines you found:")
		for c: String in clues:
			intro += "\n- " + Loc.t(c)
	await menu.info(intro)
	var ok: bool = false
	match str(s.get("kind", "")):
		"pick":
			ok = await ask_pick(menu, s)
		"type":
			ok = await ask_type(parent, menu, s)
		_:
			var board := PuzzleBoard.new()
			board.setup(s)
			parent.add_child(board)
			ok = await board.finished
			board.queue_free()
	if ok:
		var lines: Array[String] = PuzzleSpots.solve(id)
		var t: String = Loc.t("Solved!")
		if s.has("clue"):
			t += "\n\n" + Loc.t("A line appears on the stone: %s") % Loc.t(str(s.clue))
		for l: String in lines:
			t += "\n" + l
		Sound.sfx("pickup")
		await menu.info(t)
	menu.queue_free()
	return ok

## The answers of a pick riddle in the order they are shown.
static func shown_options(s: Dictionary) -> Array[String]:
	var opts: Array = s.get("options", [])
	var out: Array[String] = []
	for i: int in PuzzleSpots.option_order(s):
		out.append(Loc.t(str(opts[i])))
	return out

static func wrong_text(s: Dictionary, n: int) -> String:
	var t: String = Loc.t("Not quite. Try again.")
	for h: String in PuzzleSpots.hints(s, n):
		t += "\n" + Loc.t("Hint: %s") % Loc.t(h)
	return t

static func ask_pick(menu: MenuHost, s: Dictionary) -> bool:
	var order: Array[int] = PuzzleSpots.option_order(s)
	while true:
		var i: int = await menu.pick_strings(Loc.t("Your answer:"), shown_options(s))
		if i < 0:
			return false
		if PuzzleSpots.pick_ok(s, order[i]):
			return true
		Sound.sfx("cancel")
		await menu.info(wrong_text(s, PuzzleSpots.add_try(str(s.id))))
	return false

static func ask_type(parent: Node, menu: MenuHost, s: Dictionary) -> bool:
	var offered: bool = false
	while true:
		if not offered and PuzzleSpots.tries(str(s.id)) >= PuzzleSpots.TYPE_CHOICES_AFTER and not (s.get("options", []) as Array).is_empty():
			offered = true
			if await menu.confirm(Loc.t("You have tried a few times. Pick from some answers instead?")):
				return await ask_pick(menu, s)
		var text: String = await TextPrompt.ask(parent, Loc.t("Your answer:"), false, 24)
		if text.is_empty():
			return false
		if PuzzleSpots.answer_ok(s, text):
			return true
		Sound.sfx("cancel")
		await menu.info(wrong_text(s, PuzzleSpots.add_try(str(s.id))))
	return false

# --- Board -------------------------------------------------------------------------------

func setup(s: Dictionary) -> void:
	spot = s
	kind = str(s.get("kind", ""))
	match kind:
		"lights":
			_grid = PuzzleSpots.lights_start(s)
			_cols = PuzzleSpots.lights_size(s)
			_rows = _cols
		"slide":
			_tiles = PuzzleSpots.slide_start(s)
			_cols = 3
			_rows = 3
		"push":
			_map = PuzzleSpots.push_map(s)
			_pc = PuzzleSpots.push_start(s)
			_cols = _map.width
			_rows = _map.height
		"steps":
			_at = PuzzleSpots.step_find(s, "S")
			_trail = [_at]
			var g: Array = s.get("grid", [])
			_rows = g.size()
			_cols = str(g[0]).length() if not g.is_empty() else 0

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN
	panel.offset_top = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_bottom = -MARGIN
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_title = Label.new()
	_title.text = Loc.t(str(spot.get("title", "")))
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(1, 0)
	box.add_child(_title)
	_status = Label.new()
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)
	_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	box.add_child(_status)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)
	var inner_w: float = get_viewport_rect().size.x - MARGIN * 2 - 12
	if kind in ["order", "listen"]:
		center.add_child(_build_color_buttons(inner_w))
	else:
		_cell = clampi(int(inner_w / maxi(_cols, 1)), 8, CELL_MAX)
		_canvas = Control.new()
		_canvas.custom_minimum_size = Vector2(_cols * _cell, _rows * _cell)
		_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
		_canvas.draw.connect(_draw_board)
		_canvas.gui_input.connect(_on_canvas_input)
		center.add_child(_canvas)
	if kind in ["push", "steps"]:
		var arrows := HBoxContainer.new()
		arrows.alignment = BoxContainer.ALIGNMENT_CENTER
		for d: Array in [["<", Vector2i.LEFT], ["^", Vector2i.UP], ["v", Vector2i.DOWN], [">", Vector2i.RIGHT]]:
			var b: Button = _button(str(d[0]), move.bind(d[1]))
			b.custom_minimum_size = Vector2(26, BUTTON_H)
			arrows.add_child(b)
		box.add_child(arrows)
	# Again / Reset gets a full row: "Zurücksetzen" and friends do not fit a third of 144 px.
	if kind == "listen":
		box.add_child(_button(Loc.t("Again"), play_tune))
	elif kind != "order":
		box.add_child(_button(Loc.t("Reset"), reset))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_button(Loc.t("Read"), _read))
	row.add_child(_button(Loc.t("Back"), func() -> void: finished.emit(false)))
	box.add_child(row)
	_say(_prompt())
	if kind == "listen":
		play_tune.call_deferred()
	elif not _color_buttons.is_empty():
		_color_buttons[0].grab_focus.call_deferred()

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.pressed.connect(on_press)
	return b

func _build_color_buttons(width: float) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var buttons: Array = spot.get("buttons", [])
	for i: int in buttons.size():
		var key: String = str(buttons[i])
		var b: Button = _button(Loc.t(PuzzleSpots.COLOR_NAMES.get(key, key)), tap_button.bind(i))
		b.custom_minimum_size = Vector2(floorf((width - 4) / 2.0), BUTTON_H + 8)
		b.icon = _swatch(PuzzleSpots.COLORS.get(key, Color.GRAY))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(b)
		_color_buttons.append(b)
	return grid

static func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(UITheme.INK)
	img.fill_rect(Rect2i(1, 1, 8, 8), c)
	return ImageTexture.create_from_image(img)

func _prompt() -> String:
	match kind:
		"order":
			return Loc.t("Use them in the right order.")
		"listen":
			return Loc.t("Listen, then play the notes back.")
		"lights":
			return Loc.t("Light them all. A tap flips its neighbours too.")
		"slide":
			return Loc.t("Slide the tiles until they run from 1 to 8.")
		"push":
			return Loc.t("Push the stones onto every plate.")
		"steps":
			return Loc.t("Follow the right tracks to the end.")
	return ""

func _say(text: String) -> void:
	if _status != null:
		_status.text = text

func _hint_line() -> String:
	var t: String = ""
	for h: String in PuzzleSpots.hints(spot, PuzzleSpots.tries(str(spot.id))):
		t = Loc.t("Hint: %s") % Loc.t(h)
	return t

func _wrong(text: String) -> void:
	PuzzleSpots.add_try(str(spot.id))
	Sound.sfx("cancel")
	var h: String = _hint_line()
	_say(Loc.t(text) + ("\n" + h if not h.is_empty() else ""))

func _moved() -> void:
	moves += 1
	if moves % MOVES_PER_TRY == 0:
		PuzzleSpots.add_try(str(spot.id))
	var h: String = _hint_line()
	_say(Loc.t("Moves: %d") % moves + ("\n" + h if not h.is_empty() else ""))
	if _canvas != null:
		_canvas.queue_redraw()
	if is_solved():
		_win()

func is_solved() -> bool:
	match kind:
		"lights":
			return PuzzleSpots.lights_done(_grid)
		"slide":
			return _tiles == PuzzleSpots.slide_solved()
		"push":
			return PuzzleSpots.push_done(_map)
		"steps":
			return PuzzleSpots.step_kind(spot, _at) == "end"
		"order", "listen":
			return _done >= PuzzleSpots.sequence(spot).size()
	return false

func _win() -> void:
	if solved:
		return
	solved = true
	Sound.sfx("warp")
	_say(Loc.t("Solved!"))
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	finished.emit(true)

func _read() -> void:
	if _menu != null:
		return
	_menu = MenuHost.new()
	add_child(_menu)
	var t: String = Loc.t(str(spot.get("title", ""))) + "\n\n" + Loc.t(str(spot.get("text", "")))
	for h: String in PuzzleSpots.hints(spot, PuzzleSpots.tries(str(spot.id))):
		t += "\n\n" + Loc.t("Hint: %s") % Loc.t(h)
	await _menu.info(t)
	_menu.queue_free()
	_menu = null

func reset() -> void:
	if solved:
		return
	PuzzleSpots.add_try(str(spot.id))
	moves = 0
	_done = 0
	setup(spot)
	_say(_prompt())
	if _canvas != null:
		_canvas.queue_redraw()

# --- Order and listen --------------------------------------------------------------------

func tap_button(i: int) -> void:
	if solved or _playing:
		return
	_flash(i)
	if kind == "listen":
		Sound.sfx("confirm", 0.0, PuzzleSpots.PITCHES[mini(i, PuzzleSpots.PITCHES.size() - 1)])
	else:
		Sound.sfx("tick")
	var r: int = PuzzleSpots.press(spot, _done, i)
	if r < 0:
		_done = 0
		_wrong("Wrong order. Start again.")
		return
	_done = r
	_say(Loc.t("%d of %d") % [_done, PuzzleSpots.sequence(spot).size()])
	if is_solved():
		_win()

func _flash(i: int) -> void:
	_lit = i
	for k: int in _color_buttons.size():
		_color_buttons[k].modulate = Color(1.35, 1.35, 1.1) if k == i else Color.WHITE
	if is_inside_tree():
		await get_tree().create_timer(NOTE_TIME).timeout
	if _lit == i:
		_lit = -1
		for b: Button in _color_buttons:
			b.modulate = Color.WHITE

## Plays the tune of a listen board, lighting each button with its note.
func play_tune() -> void:
	if _playing or solved:
		return
	_playing = true
	_done = 0
	_say(Loc.t("Listen..."))
	for i: int in PuzzleSpots.sequence(spot):
		if not is_inside_tree():
			break
		_flash(i)
		Sound.sfx("confirm", 0.0, PuzzleSpots.PITCHES[mini(i, PuzzleSpots.PITCHES.size() - 1)])
		await get_tree().create_timer(NOTE_TIME + NOTE_GAP).timeout
	_playing = false
	_say(Loc.t("Your turn."))
	if not _color_buttons.is_empty():
		_color_buttons[0].grab_focus()

# --- Grid boards -------------------------------------------------------------------------

## A tap (or accept) on grid [param c]: lights flip, slide tiles move, push and steps walk one
## cell toward it.
func tap_cell(c: Vector2i) -> void:
	if solved:
		return
	match kind:
		"lights":
			if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
				return
			_cursor = c
			PuzzleSpots.lights_tap(_grid, _cols, c)
			Sound.sfx("tick")
			_moved()
		"slide":
			if PuzzleSpots.slide_tap(_tiles, c):
				Sound.sfx("tick")
				_moved()
		"push", "steps":
			var from: Vector2i = _pc if kind == "push" else _at
			var d: Vector2i = c - from
			if d == Vector2i.ZERO:
				return
			move(Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y)))

## One arrow: push walks (and pushes), steps walks, slide moves the tile into the gap from the
## other side, lights moves the cursor.
func move(dir: Vector2i) -> void:
	if solved:
		return
	match kind:
		"push":
			var to: Vector2i = PuzzleRoom.step(_map, _pc, dir, [])
			if to == _pc:
				Sound.sfx("bump")
				return
			_pc = to
			Sound.sfx("tick")
			_moved()
		"steps":
			var to: Vector2i = _at + dir
			match PuzzleSpots.step_kind(spot, to):
				"edge":
					Sound.sfx("bump")
				"decoy":
					_lost("Those are other tracks. Back to the start.")
				"lost":
					_lost("No tracks there. Back to the start.")
				_:
					_at = to
					if not to in _trail:
						_trail.append(to)
					Sound.sfx("tick")
					_moved()
		"slide":
			if PuzzleSpots.slide_gap(_tiles, -dir):
				Sound.sfx("tick")
				_moved()
		"lights":
			_cursor = Vector2i(clampi(_cursor.x + dir.x, 0, _cols - 1), clampi(_cursor.y + dir.y, 0, _rows - 1))
			_canvas.queue_redraw()

func _lost(text: String) -> void:
	_at = PuzzleSpots.step_find(spot, "S")
	_trail = [_at]
	_wrong(text)
	_canvas.queue_redraw()

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		tap_cell(Vector2i(int(p.x / _cell), int(p.y / _cell)))
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _menu != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finished.emit(false)
		return
	if _canvas == null:
		return
	for a: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if event.is_action_pressed(a):
			get_viewport().set_input_as_handled()
			move(GridWalker.DIRS[a.trim_prefix("ui_")])
			return
	if kind == "lights" and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		tap_cell(_cursor)

func _draw_board() -> void:
	var font: Font = UITheme.font()
	var ink: Color = UITheme.INK
	var s: int = _cell
	for y: int in _rows:
		for x: int in _cols:
			var r := Rect2(x * s, y * s, s, s)
			match kind:
				"lights":
					var on: bool = _grid[y * _cols + x]
					_canvas.draw_rect(r.grow(-1), Color("f2c14e") if on else Color("4a4250"))
					_canvas.draw_circle(r.get_center(), s * 0.22, Color("fff4c0") if on else Color("2c2630"))
					_canvas.draw_rect(r.grow(-1), ink, false, 1.0)
				"slide":
					var t: int = _tiles[y * 3 + x]
					if t == 0:
						_canvas.draw_rect(r.grow(-1), Color("4a4250"))
						continue
					var row_tint: Array[Color] = [Color("e6c9a0"), Color("cfe0b0"), Color("b8d0e8")]
					_canvas.draw_rect(r.grow(-1), row_tint[(t - 1) / 3])
					_canvas.draw_rect(r.grow(-1), ink, false, 1.0)
					_canvas.draw_string(font, Vector2(r.position.x, r.get_center().y + 3), str(t), HORIZONTAL_ALIGNMENT_CENTER, s, UITheme.FONT_SIZE, ink)
				"push":
					var ch: String = _map.char_at(Vector2i(x, y))
					var under: String = PuzzleRoom.under(_map, Vector2i(x, y))
					_canvas.draw_rect(r, Color("5a4a3c") if ch == "W" else Color("d8cbb0"))
					if under == "P":
						_canvas.draw_rect(r.grow(-s * 0.2), Color("b0503a"), false, 1.0)
					if ch == "B":
						_canvas.draw_circle(r.get_center(), s * 0.4, Color("8a8070"))
						_canvas.draw_arc(r.get_center(), s * 0.4, 0, TAU, 12, ink, 1.0)
				"steps":
					_draw_step_cell(r, str((spot.grid as Array)[y])[x], Vector2i(x, y) in _trail)
	if kind == "push":
		_draw_walker(Rect2(_pc.x * s, _pc.y * s, s, s))
	elif kind == "steps":
		_draw_walker(Rect2(_at.x * s, _at.y * s, s, s))
	elif kind == "lights" and has_focus_cursor():
		_canvas.draw_rect(Rect2(_cursor.x * s, _cursor.y * s, s, s), Color("e0563a"), false, 1.0)
	_canvas.draw_rect(Rect2(0, 0, _cols * s, _rows * s), ink, false, 1.0)

## The lights cursor shows once a pad or keys are used (a tap needs none).
func has_focus_cursor() -> bool:
	return not DisplayServer.is_touchscreen_available()

func _draw_step_cell(r: Rect2, ch: String, walked: bool) -> void:
	var ground: Color = GROUND.get(str(spot.get("ground", "snow")), GROUND.snow)
	_canvas.draw_rect(r, ground.darkened(0.12) if walked else ground)
	var c: Vector2 = r.get_center()
	var u: float = r.size.x / 8.0
	match ch:
		"o", "S":
			_canvas.draw_rect(Rect2(c + Vector2(-2.5 * u, -2 * u), Vector2(2 * u, 3 * u)), Color("4a3a30"))
			_canvas.draw_rect(Rect2(c + Vector2(0.5 * u, -0.5 * u), Vector2(2 * u, 3 * u)), Color("4a3a30"))
		"x":
			for k: int in 3:
				_canvas.draw_line(c + Vector2((k - 1) * 1.6 * u, -2 * u), c + Vector2((k - 1) * 2.2 * u, 2 * u), Color("7d5f5f"), 1.0)
		"E":
			_canvas.draw_circle(c, 2.5 * u, Color("3a2a55"))
			_canvas.draw_circle(c, 1.2 * u, Color("f2c14e"))

func _draw_walker(r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	_canvas.draw_circle(c + Vector2(0, -r.size.y * 0.18), r.size.x * 0.16, Color("e0563a"))
	_canvas.draw_rect(Rect2(c + Vector2(-r.size.x * 0.15, -r.size.y * 0.04), Vector2(r.size.x * 0.3, r.size.y * 0.32)), Color("3a5a9a"))
