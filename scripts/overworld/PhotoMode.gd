class_name PhotoMode
extends CanvasLayer
## Photo mode (item 94), opened from the menu. The world stays still; the D-pad pans the view a
## few tiles around the player, the menu button cycles a frame, A saves a picture and B leaves.
## Pictures are PNGs in user://photos/, scaled up 4x with sharp pixels. Nothing is uploaded.

signal finished
## Photos saved in this session (a daily task counts them).
var taken: int = 0

const DIR: String = "user://photos/"
const SCALE: int = 4
const PAN_SPEED: float = 48.0
const PAN_LIMIT: float = 4.0 * 16.0
const FRAMES: Array[String] = ["No frame", "Film", "Postcard"]

## Pan offset in world pixels; the overworld adds it to the camera.
var pan: Vector2 = Vector2.ZERO
var frame: int = 0
## Shown on the postcard frame.
var place: String = ""

var _overlay: Control
var _hint: Label
var _busy: bool = false

func _init() -> void:
	layer = 60

func _ready() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_frame)
	add_child(_overlay)
	_hint = Label.new()
	_hint.theme = UITheme.get_theme()
	_hint.position = Vector2(2, 2)
	_hint.text = Loc.t("A: photo  B: done  Menu: frame")
	add_child(_hint)

func _process(delta: float) -> void:
	if _busy:
		return
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	pan = clamp_offset(pan + v * PAN_SPEED * delta)

static func clamp_offset(o: Vector2) -> Vector2:
	return o.clamp(Vector2(-PAN_LIMIT, -PAN_LIMIT), Vector2(PAN_LIMIT, PAN_LIMIT)).round()

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		snap()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finished.emit()
	elif event.is_action_pressed(GameState.MENU_ACTION):
		get_viewport().set_input_as_handled()
		frame = (frame + 1) % FRAMES.size()
		_hint.text = Loc.t(FRAMES[frame])
		_overlay.queue_redraw()
	elif TapInput.is_press(event) and not VirtualPad.covers(TapInput.position(event)):
		get_viewport().set_input_as_handled()
		snap()

## Hides the hint and the touch pad for one frame, grabs the screen and saves it.
func snap() -> void:
	_busy = true
	_hint.visible = false
	var pad_was: bool = VirtualPad.visible
	VirtualPad.visible = false
	# Photos never carry a shake offset (item 2269).
	Juice.calm()
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		cam.offset = Vector2.ZERO
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	VirtualPad.visible = pad_was
	var path: String = save_photo(img)
	if path != "":
		taken += 1
	Sound.sfx("save" if path != "" else "cancel")
	_hint.text = Loc.t("Photo saved.") if path != "" else Loc.t("Could not save the photo.")
	_hint.visible = true
	_busy = false

## Saves [param img] scaled up as the next free photo file. Returns its path, or "" on failure.
static func save_photo(img: Image) -> String:
	if img == null or img.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(DIR)
	var big: Image = img.duplicate()
	big.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path: String = DIR + "photo_%s.png" % stamp
	var n: int = 2
	while FileAccess.file_exists(path):
		path = DIR + "photo_%s_%d.png" % [stamp, n]
		n += 1
	if big.save_png(path) != OK:
		return ""
	GameState.records["photos"] = int(GameState.records.get("photos", 0)) + 1
	return path

func _draw_frame() -> void:
	var r: Rect2 = _overlay.get_rect()
	match frame:
		1:
			var bar: float = r.size.y * 0.1
			_overlay.draw_rect(Rect2(0, 0, r.size.x, bar), Color.BLACK)
			_overlay.draw_rect(Rect2(0, r.size.y - bar, r.size.x, bar), Color.BLACK)
		2:
			var b: float = 6.0
			var col: Color = UITheme.BG
			_overlay.draw_rect(Rect2(0, 0, r.size.x, b), col)
			_overlay.draw_rect(Rect2(0, r.size.y - b * 3, r.size.x, b * 3), col)
			_overlay.draw_rect(Rect2(0, 0, b, r.size.y), col)
			_overlay.draw_rect(Rect2(r.size.x - b, 0, b, r.size.y), col)
			_overlay.draw_rect(Rect2(b, b, r.size.x - b * 2, r.size.y - b * 4), UITheme.INK, false, 1.0)
			_overlay.draw_string(PixelFont.get_font(), Vector2(b + 2, r.size.y - b), place, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE, UITheme.INK)
