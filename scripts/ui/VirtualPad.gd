extends CanvasLayer
## Autoload "VirtualPad": on-screen D-pad plus A/B on its own CanvasLayer.
## Buttons press the same input actions as a keyboard or gamepad (ui_up..., ui_accept, ui_cancel),
## so gameplay never knows where input came from. Respects the display safe area and hides
## itself when a gamepad is connected or the device has no touchscreen.

const LAYER: int = 50
## Button sizes in viewport pixels per size setting (Medium is about 9-10 mm at integer scale 7).
const DPAD_SIZES: Array[int] = [16, 20, 24, 28]
const AB_SIZES: Array[int] = [18, 22, 26, 30]
## The menu button is a little larger than before and further from B, so it is not taken for
## B (item 1811).
const MENU_BUTTON: int = 16
const MENU_GAP: int = 10
const EDGE: int = 4
const DIRS: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]

## Force the pad on (desktop testing) regardless of touchscreen detection.
var force_visible: bool = false
var _wanted: bool = false
var _root: Node2D
var _buttons: Array[TouchScreenButton] = []

## The D-pad is one 3x3 field: the angle from its middle presses exactly one direction, so
## the middle and the corners always do something (item 1809). The four arrow buttons only
## draw; this script reads the touches.
var _dir_touch: int = -1
var _dir: String = ""
var _dpad_origin: Vector2 = Vector2.ZERO
var _dpad: int = DPAD_SIZES[1]
var _ab: int = AB_SIZES[1]

func _ready() -> void:
	layer = LAYER
	_root = Node2D.new()
	add_child(_root)
	apply_settings()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _refresh())
	get_viewport().size_changed.connect(_layout)

## Rebuilds the buttons from the size / opacity / handedness settings in GameState.
func apply_settings() -> void:
	_set_dir("")
	_dir_touch = -1
	for b: TouchScreenButton in _buttons:
		if b.action != &"" and Input.is_action_pressed(b.action):
			Input.action_release(b.action)
		b.queue_free()
	_buttons.clear()
	_dpad = DPAD_SIZES[clampi(GameState.pad_size, 0, DPAD_SIZES.size() - 1)]
	_ab = AB_SIZES[clampi(GameState.pad_size, 0, AB_SIZES.size() - 1)]
	_root.modulate.a = GameState.PAD_ALPHAS[clampi(GameState.pad_opacity, 0, GameState.PAD_ALPHAS.size() - 1)]
	_add_button("ui_up", Vector2(_dpad, 0), _dpad, false, "^")
	_add_button("ui_down", Vector2(_dpad, _dpad * 2), _dpad, false, "v")
	_add_button("ui_left", Vector2(0, _dpad), _dpad, false, "<")
	_add_button("ui_right", Vector2(_dpad * 2, _dpad), _dpad, false, ">")
	_add_button("ui_accept", Vector2.ZERO, _ab, true, "A")
	_add_button("ui_cancel", Vector2.ZERO, _ab, true, "B")
	_add_button("menu", Vector2.ZERO, MENU_BUTTON, false, "=")
	_layout()
	_refresh()

## True if [param pos] (viewport pixels) is on a visible pad button, so taps there don't also walk.
func covers(pos: Vector2) -> bool:
	if not visible:
		return false
	if dpad_rect().grow(2).has_point(pos):
		return true
	for b: TouchScreenButton in _buttons:
		var s: Vector2 = (b.shape as RectangleShape2D).size
		if Rect2(b.position, s).grow(2).has_point(pos):
			return true
	return false

## Top edge of the highest pad button in viewport pixels, or -1 while the pad is hidden.
func top_y() -> float:
	if not visible or _buttons.is_empty():
		return -1.0
	var top: float = INF
	for b: TouchScreenButton in _buttons:
		top = minf(top, b.position.y)
	return top

## Show the pad in gameplay screens; hide it in menus and battles (they have their own buttons).
func set_wanted(on: bool) -> void:
	_wanted = on
	_refresh()

func _refresh() -> void:
	var touch: bool = DisplayServer.is_touchscreen_available() or force_visible
	visible = _wanted and touch and Input.get_connected_joypads().is_empty()
	if not visible:
		_set_dir("")
		_dir_touch = -1
		for b: TouchScreenButton in _buttons:
			if b.action != &"" and Input.is_action_pressed(b.action):
				Input.action_release(b.action)

func _add_button(action: String, offset: Vector2, size_px: int, round_shape: bool, glyph: String) -> void:
	var b := TouchScreenButton.new()
	var is_dir: bool = action in DIRS
	# Arrow buttons press nothing themselves; the 3x3 field does (see _input).
	b.action = "" if is_dir else action
	b.set_meta("dir", action if is_dir else "")
	b.passby_press = true
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	b.texture_normal = _make_texture(size_px, round_shape, glyph, false)
	b.texture_pressed = _make_texture(size_px, round_shape, glyph, true)
	if is_dir:
		b.set_meta("up_tex", b.texture_normal)
		b.set_meta("down_tex", b.texture_pressed)
		b.texture_pressed = b.texture_normal
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size_px, size_px)
	b.shape = shape
	b.shape_centered = true
	b.set_meta("offset", offset)
	_root.add_child(b)
	_buttons.append(b)

func _make_texture(size_px: int, round_shape: bool, glyph: String, pressed: bool, framed: bool = false) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var fill: Color = UITheme.MID if pressed else UITheme.BG
	var c: float = (size_px - 1) / 2.0
	for y: int in size_px:
		for x: int in size_px:
			var inside: bool = true
			var edge: bool = x == 0 or y == 0 or x == size_px - 1 or y == size_px - 1
			if framed:
				edge = edge or x == 1 or y == 1 or x == size_px - 2 or y == size_px - 2
			if round_shape:
				var d: float = Vector2(x - c, y - c).length()
				inside = d <= c + 0.5
				edge = d > c - 1.0 and inside
			if inside:
				img.set_pixel(x, y, UITheme.INK if edge else fill)
	_draw_glyph(img, glyph, UITheme.INK)
	return ImageTexture.create_from_image(img)

## Tiny built-in 3x5 glyphs for the button labels.
func _draw_glyph(img: Image, glyph: String, col: Color) -> void:
	var glyphs: Dictionary[String, Array] = {
		"^": ["010", "111", "000", "000", "000"], "v": ["000", "000", "000", "111", "010"],
		"<": ["001", "011", "001", "000", "000"], ">": ["100", "110", "100", "000", "000"],
		"A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
		"=": ["000", "111", "000", "111", "000"],
	}
	var rows: Array = glyphs.get(glyph, [])
	var scale: int = 2
	var ox: int = img.get_width() / 2 - 3
	var oy: int = img.get_height() / 2 - 5
	if glyph in ["^", "v", "<", ">"]:
		oy = img.get_height() / 2 - 3
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "1":
				img.fill_rect(Rect2i(ox + x * scale, oy + y * scale, scale, scale), col)

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = _safe_rect_in_viewport(vp)
	var left: bool = GameState.left_handed
	var dpad_x: float = safe.end.x - EDGE - _dpad * 3 if left else safe.position.x + EDGE
	var dpad_origin := Vector2(dpad_x, safe.end.y - EDGE - _dpad * 3)
	_dpad_origin = dpad_origin
	if GameState.one_hand:
		_layout_one_hand(safe, left)
	else:
		_layout_two_hands(safe, left, dpad_origin)
	if GameState.swap_ab_touch:
		_swap_ab()

## A and B change places (item 2111); each keeps its letter, the menu button stays put.
func _swap_ab() -> void:
	var a: TouchScreenButton = null
	var b: TouchScreenButton = null
	for t: TouchScreenButton in _buttons:
		if t.action == &"ui_accept":
			a = t
		elif t.action == &"ui_cancel":
			b = t
	if a != null and b != null:
		var p: Vector2 = a.position
		a.position = b.position
		b.position = p

func _layout_two_hands(safe: Rect2, left: bool, dpad_origin: Vector2) -> void:
	for b: TouchScreenButton in _buttons:
		var off: Vector2 = b.get_meta("offset")
		match b.action:
			"ui_accept":
				var ax: float = safe.position.x + EDGE + _ab + 4 if left else safe.end.x - EDGE - _ab
				b.position = Vector2(ax, safe.end.y - EDGE - _ab * 2 - 4)
			"ui_cancel":
				var bx: float = safe.position.x + EDGE if left else safe.end.x - EDGE - _ab * 2 - 4
				b.position = Vector2(bx, safe.end.y - EDGE - _ab)
			"menu":
				# Sits above B, clear of the D-pad at every size and handedness.
				var bx2: float = safe.position.x + EDGE if left else safe.end.x - EDGE - _ab * 2 - 4
				b.position = Vector2(bx2 + (_ab - MENU_BUTTON) / 2.0, safe.end.y - EDGE - _ab - MENU_BUTTON - MENU_GAP)
			_:
				b.position = dpad_origin + off

## One-hand layout (item 79): the D-pad sits in the bottom corner on the thumb's side, with
## A and B in a row just above it and the menu button above B. Left-handed mirrors it.
func _layout_one_hand(safe: Rect2, left: bool) -> void:
	var dpad_x: float = safe.position.x + EDGE if left else safe.end.x - EDGE - _dpad * 3
	var dpad_origin := Vector2(dpad_x, safe.end.y - EDGE - _dpad * 3)
	_dpad_origin = dpad_origin
	var row_y: float = dpad_origin.y - 4 - _ab
	# A is the button nearest the screen edge, B sits next to it toward the middle.
	var a_x: float = safe.position.x + EDGE if left else safe.end.x - EDGE - _ab
	var b_x: float = a_x + _ab + 4 if left else a_x - _ab - 4
	for b: TouchScreenButton in _buttons:
		match b.action:
			"ui_accept":
				b.position = Vector2(a_x, row_y)
			"ui_cancel":
				b.position = Vector2(b_x, row_y)
			"menu":
				b.position = Vector2(b_x + (_ab - MENU_BUTTON) / 2.0, row_y - MENU_BUTTON - MENU_GAP)
			_:
				b.position = dpad_origin + (b.get_meta("offset") as Vector2)

## Converts DisplayServer's safe area (screen pixels) into viewport units.
func _safe_rect_in_viewport(vp: Vector2) -> Rect2:
	return SafeArea.rect(vp)

## The 3x3 D-pad field in viewport pixels.
func dpad_rect() -> Rect2:
	return Rect2(_dpad_origin, Vector2(_dpad * 3, _dpad * 3))

## The direction for a touch at [param local] inside a field of [param side] pixels: the
## larger of the two distances from the middle wins. Right in the middle it returns "" (keep
## the direction already held).
static func dir_for(local: Vector2, side: float) -> String:
	var d: Vector2 = local - Vector2(side, side) / 2.0
	if d.length() < 1.5:
		return ""
	if absf(d.x) > absf(d.y):
		return "ui_right" if d.x > 0.0 else "ui_left"
	return "ui_down" if d.y > 0.0 else "ui_up"

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var f: Dictionary = TapInput.finger(event)
	if f.is_empty():
		return
	var pos: Vector2 = f.pos
	match str(f.kind):
		"down":
			if _dir_touch < 0 and dpad_rect().grow(2).has_point(pos):
				_dir_touch = int(f.finger)
				_touch_dir(pos)
		"move":
			if int(f.finger) == _dir_touch:
				_touch_dir(pos)
		"up":
			if int(f.finger) == _dir_touch:
				_dir_touch = -1
				_set_dir("")

## Presses the direction for a touch at [param pos] (viewport pixels).
func _touch_dir(pos: Vector2) -> void:
	var d: String = dir_for(pos - _dpad_origin, _dpad * 3)
	if not d.is_empty():
		_set_dir(d)

func _set_dir(d: String) -> void:
	if d == _dir:
		return
	if not _dir.is_empty():
		Input.action_release(_dir)
	_dir = d
	if not d.is_empty():
		Input.action_press(d)
	for b: TouchScreenButton in _buttons:
		var own: String = str(b.get_meta("dir", ""))
		if not own.is_empty():
			b.texture_normal = b.get_meta("down_tex" if own == d else "up_tex")

## Until the menu was opened once, the menu button pulses gently; with Reduce motion it gets
## a firm frame instead (item 1983). The overworld sets this flag when the menu opens.
const MENU_SEEN_FLAG: String = "menu_opened"
const PULSE_SECONDS: float = 1.6

func menu_hinted() -> bool:
	return not GameState.has_flag(MENU_SEEN_FLAG)

func _process(_delta: float) -> void:
	if not visible:
		return
	var hint: bool = menu_hinted()
	for b: TouchScreenButton in _buttons:
		if b.action != &"menu":
			continue
		var framed: bool = hint and GameState.reduce_motion
		if bool(b.get_meta("framed", false)) != framed:
			b.set_meta("framed", framed)
			b.texture_normal = _make_texture(MENU_BUTTON, false, "=", false, framed)
		if hint and not GameState.reduce_motion:
			var t: float = fmod(Time.get_ticks_msec() / 1000.0, PULSE_SECONDS) / PULSE_SECONDS
			b.modulate = Color(1, 1, 1, 0.55 + 0.45 * (0.5 + 0.5 * cos(t * TAU)))
		else:
			b.modulate = Color.WHITE

## The direction the D-pad holds now ("" for none; tests).
func held_dir() -> String:
	return _dir
