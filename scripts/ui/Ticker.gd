extends CanvasLayer
## Autoload "Ticker": short notices such as "Game saved." (item 2418). A 12 px bar slides in from
## the top edge (below any notch), stays 1.6 s and slides out. Notices queue up, never overlap.
##   Ticker.show_text("Game saved.")
##   Ticker.coins(120, 340)       counts the coin total up (item 2419)

const HEIGHT: int = 12
const STAY_TIME: float = 1.6
const LAYER: int = 60

var _bar: PanelContainer
var _label: Label
var _queue: Array[Dictionary] = []
var _busy: bool = false
## Texts shown so far, newest last (for tests; keeps the last few).
var shown: Array[String] = []

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bar = PanelContainer.new()
	_bar.theme = UITheme.get_theme()
	_bar.add_theme_stylebox_override("panel", UITheme.flat_style(UITheme.BG, UITheme.INK))
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	add_child(_bar)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bar.add_child(_label)

func show_text(text: String) -> void:
	_queue.append({"text": text})
	if not _busy:
		_run()

## Shows the coin total counting from [param from] to [param to].
func coins(from: int, to: int) -> void:
	_queue.append({"text": "Coins: %d", "from": from, "to": to})
	if not _busy:
		_run()

func busy() -> bool:
	return _busy

func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var t: Dictionary = _queue.pop_front()
		await _show(t)
	_busy = false

func _show(t: Dictionary) -> void:
	var vp: Vector2 = _bar.get_viewport().get_visible_rect().size
	var top: float = SafeArea.rect(vp).position.y
	_bar.size = Vector2(vp.x - 16.0, HEIGHT)
	var home := Vector2(8.0, top + 2.0)
	_bar.position = home - Vector2(0, HEIGHT + 2 + top)
	var fmt: String = Loc.t(str(t.text))
	if t.has("from"):
		_label.text = fmt % int(t.from)
	else:
		_label.text = fmt
	shown.append(_label.text if not t.has("to") else fmt % int(t.to))
	if shown.size() > 8:
		shown.pop_front()
	_bar.visible = true
	await Juice.tween(_bar, "position", home, "open").finished
	if t.has("from"):
		await Juice.count_to(_label, int(t.from), int(t.to), 0.6, fmt)
	await get_tree().create_timer(STAY_TIME, true, false, true).timeout
	await Juice.tween(_bar, "position", home - Vector2(0, HEIGHT + 2 + top), "close").finished
	_bar.visible = false
