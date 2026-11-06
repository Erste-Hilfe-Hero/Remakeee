extends CanvasLayer
## Autoload "VirtualPad": on-screen D-pad plus A/B on its own CanvasLayer.
## Buttons press the same input actions as a keyboard or gamepad (ui_up..., ui_accept, ui_cancel),
## so gameplay never knows where input came from. Respects the display safe area and hides
## itself when a gamepad is connected or the device has no touchscreen.

const LAYER: int = 50
## Button sizes in viewport pixels per size setting (Medium is about 9-10 mm at integer scale 7).
const DPAD_SIZES: Array[int] = [16, 20, 24]
const AB_SIZES: Array[int] = [18, 22, 26]
const MENU_BUTTON: int = 14
const EDGE: int = 4

## Force the pad on (desktop testing) regardless of touchscreen detection.
var force_visible: bool = false
var _wanted: bool = false
var _root: Node2D
var _buttons: Array[TouchScreenButton] = []

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
	for b: TouchScreenButton in _buttons:
		if Input.is_action_pressed(b.action):
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
		for b: TouchScreenButton in _buttons:
			if Input.is_action_pressed(b.action):
				Input.action_release(b.action)

func _add_button(action: String, offset: Vector2, size_px: int, round_shape: bool, glyph: String) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.passby_press = true
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	b.texture_normal = _make_texture(size_px, round_shape, glyph, false)
	b.texture_pressed = _make_texture(size_px, round_shape, glyph, true)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size_px, size_px)
	b.shape = shape
	b.shape_centered = true
	b.set_meta("offset", offset)
	_root.add_child(b)
	_buttons.append(b)

func _make_texture(size_px: int, round_shape: bool, glyph: String, pressed: bool) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var fill: Color = UITheme.MID if pressed else UITheme.BG
	var c: float = (size_px - 1) / 2.0
	for y: int in size_px:
		for x: int in size_px:
			var inside: bool = true
			var edge: bool = x == 0 or y == 0 or x == size_px - 1 or y == size_px - 1
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
	if GameState.one_hand:
		_layout_one_hand(safe, left)
		return
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
				b.position = Vector2(bx2 + (_ab - MENU_BUTTON) / 2.0, safe.end.y - EDGE - _ab - MENU_BUTTON - 6)
			_:
				b.position = dpad_origin + off

## One-hand layout (item 79): the D-pad sits in the bottom corner on the thumb's side, with
## A and B in a row just above it and the menu button above B. Left-handed mirrors it.
func _layout_one_hand(safe: Rect2, left: bool) -> void:
	var dpad_x: float = safe.position.x + EDGE if left else safe.end.x - EDGE - _dpad * 3
	var dpad_origin := Vector2(dpad_x, safe.end.y - EDGE - _dpad * 3)
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
				b.position = Vector2(b_x + (_ab - MENU_BUTTON) / 2.0, row_y - MENU_BUTTON - 4)
			_:
				b.position = dpad_origin + (b.get_meta("offset") as Vector2)

## Converts DisplayServer's safe area (screen pixels) into viewport units.
func _safe_rect_in_viewport(vp: Vector2) -> Rect2:
	return SafeArea.rect(vp)
