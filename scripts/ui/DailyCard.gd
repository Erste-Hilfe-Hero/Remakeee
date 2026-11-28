class_name DailyCard
extends CanvasLayer
## The daily card (DailyBoard): once a day in the world, never in battle. A small panel with the
## welcome gift (seven beads on a thread, the taken ones filled, no clock), the Spirling of the
## day and where it lives, today's tasks and, on Friday and the weekend, the weekend weather.
## One button takes the gift and closes it. Reduced motion: it appears without sliding.

signal closed

const LAYER: int = 80
const BEAD_R: float = 3.0
const BEAD_GAP: float = 14.0
const MIN_BUTTON_H: float = 22.0
## Px kept free above and below the card.
const MARGIN: float = 8.0

var info: Dictionary = {}
var panel: PanelContainer
var button: Button
var scroll: ScrollContainer
var body: VBoxContainer
var _thread: Control
var _done: bool = false

## Shows the card of today over [param parent] and returns the lines of what was taken.
static func play(parent: Node) -> Array[String]:
	var c := DailyCard.new()
	c.info = DailyBoard.card()
	DailyBoard.mark_shown()
	parent.add_child(c)
	await c.closed
	var lines: Array[String] = DailyBoard.take_gift()
	c.queue_free()
	return lines

func _ready() -> void:
	layer = LAYER
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	panel = PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_label(box, Loc.t("Today"), UITheme.MID)
	var step: int = int(info.get("gift_step", 0))
	_label(box, Loc.t("Welcome gift, day %d of 7: %s") % [step + 1, str(info.get("gift", ""))])
	_thread = Control.new()
	_thread.custom_minimum_size = Vector2(BEAD_GAP * 6 + BEAD_R * 4, BEAD_R * 2 + 4)
	_thread.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_thread.draw.connect(_draw_thread)
	box.add_child(_thread)
	# The rest scrolls when the screen is short; the gift above and the button below stay.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 3)
	scroll.add_child(body)
	if str(info.get("featured", "")) != "":
		_label(body, str(info.featured))
	var tasks: Array = info.get("tasks", [])
	if not tasks.is_empty():
		_label(body, Loc.t("Daily tasks"), UITheme.MID)
		for t: Variant in tasks:
			_label(body, str(t))
	for w: Variant in info.get("weekend", []):
		_label(body, str(w))
	button = Button.new()
	button.text = Loc.t("Take the gift") if bool(info.get("gift_open", false)) else Loc.t("OK")
	button.custom_minimum_size.y = maxf(MIN_BUTTON_H, float(ScreenFit.touch_px(get_window())))
	button.pressed.connect(_close)
	Juice.press_feedback(button)
	box.add_child(button)
	_fit.call_deferred()
	get_viewport().size_changed.connect(_fit)
	button.grab_focus.call_deferred()
	_slide_in()

func _label(box: VBoxContainer, text: String, color: Color = UITheme.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	l.add_theme_color_override("font_color", color)
	box.add_child(l)
	return l

## Keeps the card in the UI column, near the top, as wide as the column allows.
func _fit() -> void:
	if not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var col: Rect2 = SafeArea.column(vp)
	var w: float = col.size.x - 12.0
	panel.custom_minimum_size.x = w
	# The scrolling part takes what the screen leaves after the gift, the button and the margins.
	scroll.custom_minimum_size.y = 0.0
	panel.size = Vector2(w, 0)
	var fixed: float = panel.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = clampf(col.size.y - 2.0 * MARGIN - fixed, 0.0, body.get_combined_minimum_size().y)
	panel.size = Vector2(w, 0)
	panel.position = Vector2(col.position.x + 6.0, col.position.y + maxf(MARGIN, (col.size.y - panel.size.y) / 2.0)).round()

func _slide_in() -> void:
	await get_tree().process_frame
	if Juice.reduced() or not is_inside_tree():
		return
	var to: Vector2 = panel.position
	panel.position = to - Vector2(0, 12)
	panel.modulate.a = 0.0
	Juice.tween(panel, "position", to, "open")
	Juice.tween(panel, "modulate:a", 1.0, "fade")

## Seven beads on a thread: taken ones filled, today's ringed. The thread runs as far as the gifts.
func _draw_thread() -> void:
	var step: int = int(info.get("gift_step", 0))
	var y: float = _thread.size.y / 2.0
	var x0: float = BEAD_R * 2
	_thread.draw_line(Vector2(x0, y), Vector2(x0 + BEAD_GAP * 6, y), UITheme.DISABLED, 1.0)
	_thread.draw_line(Vector2(x0, y), Vector2(x0 + BEAD_GAP * step, y), UITheme.INK, 1.0)
	for i: int in 7:
		var c := Vector2(x0 + BEAD_GAP * i, y)
		var r: float = BEAD_R + (1.0 if i == 6 else 0.0)
		if i < step or (i == step and not bool(info.get("gift_open", false))):
			_thread.draw_circle(c, r, UITheme.INK)
		else:
			_thread.draw_circle(c, r, UITheme.BG)
			_thread.draw_arc(c, r, 0, TAU, 12, UITheme.INK, 1.0)
		if i == step:
			_thread.draw_arc(c, r + 1.5, 0, TAU, 14, UITheme.MID, 1.0)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _done:
		return
	_done = true
	Sound.sfx("toast")
	closed.emit()
