extends CanvasLayer
## Autoload "VirtualPad": on-screen D-pad plus A/B on its own CanvasLayer.
## Buttons press the same input actions as a keyboard or gamepad (ui_up..., ui_accept, ui_cancel),
## so gameplay never knows where input came from. Respects the display safe area and hides
## itself when a gamepad is connected or the device has no touchscreen.

const LAYER: int = 50
## Button sizes in viewport pixels (about 9-10 mm on a typical phone at integer scale 7).
const DPAD_BUTTON: int = 20
const AB_BUTTON: int = 22
const EDGE: int = 4
const ALPHA: float = 0.55

## Force the pad on (desktop testing) regardless of touchscreen detection.
var force_visible: bool = false
var _wanted: bool = false
var _root: Node2D
var _buttons: Array[TouchScreenButton] = []

func _ready() -> void:
	layer = LAYER
	_root = Node2D.new()
	_root.modulate.a = ALPHA
	add_child(_root)
	_add_button("ui_up", Vector2(DPAD_BUTTON, 0), DPAD_BUTTON, false, "^")
	_add_button("ui_down", Vector2(DPAD_BUTTON, DPAD_BUTTON * 2), DPAD_BUTTON, false, "v")
	_add_button("ui_left", Vector2(0, DPAD_BUTTON), DPAD_BUTTON, false, "<")
	_add_button("ui_right", Vector2(DPAD_BUTTON * 2, DPAD_BUTTON), DPAD_BUTTON, false, ">")
	_add_button("ui_accept", Vector2.ZERO, AB_BUTTON, true, "A")
	_add_button("ui_cancel", Vector2.ZERO, AB_BUTTON, true, "B")
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

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
	var dpad_origin := Vector2(safe.position.x + EDGE, safe.end.y - EDGE - DPAD_BUTTON * 3)
	for b: TouchScreenButton in _buttons:
		var off: Vector2 = b.get_meta("offset")
		match b.action:
			"ui_accept":
				b.position = Vector2(safe.end.x - EDGE - AB_BUTTON, safe.end.y - EDGE - AB_BUTTON * 2 - 4)
			"ui_cancel":
				b.position = Vector2(safe.end.x - EDGE - AB_BUTTON * 2 - 4, safe.end.y - EDGE - AB_BUTTON)
			_:
				b.position = dpad_origin + off

## Converts DisplayServer's safe area (screen pixels) into viewport units.
func _safe_rect_in_viewport(vp: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, vp)
	var screen_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe_px: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 0.0 or safe_px.size.x <= 0.0:
		return full
	var scale: Vector2 = vp / screen_size
	var r := Rect2(safe_px.position * scale, safe_px.size * scale)
	return full.intersection(r) if full.intersects(r) else full
