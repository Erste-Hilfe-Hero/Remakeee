class_name SpirlogPage
extends PanelContainer
## One Spirlog page in Mirela's map book (plan area 1, items 243-247): the sprite (tap it to
## hear the kind's call), its unfold line as small sprites (tap one to turn to its page), and
## the page text from SpirlogBook. Prev / next turn the pages of the current list.
## [code]await SpirlogPage.show_pages(parent, kinds, index)[/code]

signal _closed

var kinds: Array[SpirlingData] = []
var index: int = 0
var _sprite: TextureRect
var _line: HBoxContainer
var _text: Label
var _scroll: ScrollContainer

static func show_pages(parent: Node, p_kinds: Array[SpirlingData], p_index: int) -> void:
	var page := SpirlogPage.new()
	page.kinds = p_kinds
	page.index = clampi(p_index, 0, maxi(p_kinds.size() - 1, 0))
	parent.add_child(page)
	page._build()
	page._show()
	await page._closed
	page.queue_free()

static func sprite_path(sd: SpirlingData) -> String:
	return "res://art/era1/spirlings/%s_front.png" % sd.species_name.to_lower()

func _build() -> void:
	theme = UITheme.get_theme()
	add_theme_stylebox_override("panel", UITheme.panel_style())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		set("offset_" + side, MenuHost.PANEL_MARGIN * (1 if side in ["left", "top"] else -1))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(56, 56)
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	_sprite.gui_input.connect(_on_sprite_input)
	top.add_child(_sprite)
	_line = HBoxContainer.new()
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_line)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(1, 0)
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_scroll.add_child(_text)
	var row := HBoxContainer.new()
	v.add_child(row)
	for b: Array in [["<", _turn.bind(-1)], ["Back", func() -> void: _closed.emit()], [">", _turn.bind(1)]]:
		var btn := Button.new()
		btn.text = str(b[0])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(b[1])
		row.add_child(btn)

## The kind on the page now.
func current() -> SpirlingData:
	return kinds[index] if index < kinds.size() else null

func _show() -> void:
	var sd: SpirlingData = current()
	if sd == null:
		return
	_sprite.texture = load(sprite_path(sd)) if ResourceLoader.exists(sprite_path(sd)) else null
	for c: Node in _line.get_children():
		c.queue_free()
	for member: SpirlingData in SpirlogBook.line_of(sd):
		if SpirlogBook.line_of(sd).size() < 2:
			break
		var t := TextureRect.new()
		t.texture = load(sprite_path(member)) if ResourceLoader.exists(sprite_path(member)) else null
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(20, 20)
		# Unseen forms show only as an outline (item 245).
		var seen: bool = SpirlogBook.is_seen(GameState.spirlog, member.species_name)
		t.modulate = Color(1, 1, 1) if seen else Color(0, 0, 0, 0.6)
		if member == sd:
			t.custom_minimum_size = Vector2(24, 24)
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		t.gui_input.connect(_on_line_input.bind(member))
		_line.add_child(t)
	_text.text = Loc.t(SpirlogBook.page_text(sd, GameState.spirlog))
	_scroll.scroll_vertical = 0

func _turn(step: int) -> void:
	if kinds.is_empty():
		return
	# Turn past unseen kinds: they have no page yet.
	for i: int in kinds.size():
		index = posmod(index + step, kinds.size())
		if SpirlogBook.is_seen(GameState.spirlog, kinds[index].species_name):
			break
	Sound.sfx("select")
	_show()

func _on_sprite_input(event: InputEvent) -> void:
	if TapInput.is_release(event) and current() != null:
		Sound.cry(current())

## Tapping a form in the line turns to its page, if it has been seen.
func _on_line_input(event: InputEvent, member: SpirlingData) -> void:
	if not TapInput.is_release(event) or not SpirlogBook.is_seen(GameState.spirlog, member.species_name):
		return
	var i: int = kinds.find(member)
	if i < 0:
		kinds.append(member)
		i = kinds.size() - 1
	index = i
	_show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_closed.emit()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_turn(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_turn(1)
	elif event.is_action_pressed("ui_accept") and current() != null:
		get_viewport().set_input_as_handled()
		Sound.cry(current())
