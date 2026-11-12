class_name EraSummary
extends PanelContainer
## The tabbed Spirling summary of Era III and later (docs/ERA_FEEL_MENUS.md): a card that
## stays (sprite, name, Ring, coloured element badges, Vigor bar) over the tabs Info, Values,
## Arts and Marks. Left and right or a tap on a tab turn the page, Back closes. Era IV makes
## the card and tabs touch sized, Era V lets the sprite breathe and the pages slide in.
## Era I and II show the same sections as two or three text pages (EraMenus.summary_pages).
## [code]await EraSummary.show_for(host, spirling, leader)[/code]

signal closed

var spirling: Spirling
var leader: bool = false
var lay: Dictionary = {}
var tab: int = 0
var tabs: Array[String] = []
var _tab_row: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _sprite: Control
var _t: float = 0.0

static func show_for(parent: Node, s: Spirling, is_leader: bool = false) -> void:
	var view := EraSummary.new()
	view.name = "era_summary"
	view.spirling = s
	view.leader = is_leader
	view.lay = EraMenus.layout(EraManager.active_era(), "summary")
	parent.add_child(view)
	view.build()
	await view.closed
	view.queue_free()

func build() -> void:
	theme = UITheme.get_theme()
	add_theme_stylebox_override("panel", UITheme.panel_style())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		set("offset_" + side, MenuHost.PANEL_MARGIN * (1 if side in ["left", "top"] else -1))
	mouse_filter = Control.MOUSE_FILTER_STOP
	for page: Variant in lay.get("pages", []):
		tabs.append(str((page as Array)[0]))
	var row_h: int = int(lay.get("row_h", 18))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	# The card that stays while the tabs change.
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 5)
	v.add_child(card)
	var px: int = int(lay.get("sprite", 48))
	_sprite = Control.new()
	_sprite.name = "sprite"
	_sprite.custom_minimum_size = Vector2(px, px)
	_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	_sprite.draw.connect(_draw_sprite)
	_sprite.gui_input.connect(func(ev: InputEvent) -> void:
		if TapInput.is_release(ev):
			Sound.cry(spirling.data))
	card.add_child(_sprite)
	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 2)
	card.add_child(head)
	var name_label := Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = "%s%s\n%s  %s" % [GleamRules.mark(spirling), spirling.display_name(), Loc.t(spirling.data.species_name), Loc.t("Ring %d" % spirling.level)]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(1, 0)
	head.add_child(name_label)
	var badges := Control.new()
	badges.name = "badges"
	badges.custom_minimum_size = Vector2(1, EraMenuArt.BADGE_H + 1)
	badges.draw.connect(_draw_badges.bind(badges))
	head.add_child(badges)
	var bar := Control.new()
	bar.name = "vigor"
	bar.custom_minimum_size = Vector2(1, 12)
	bar.draw.connect(_draw_vigor.bind(bar))
	head.add_child(bar)
	_tab_row = HBoxContainer.new()
	_tab_row.name = "tabs"
	_tab_row.add_theme_constant_override("separation", 1)
	v.add_child(_tab_row)
	for i: int in tabs.size():
		var t := Button.new()
		t.text = EraMenus.SECTION_NAMES.get(tabs[i], tabs[i])
		t.toggle_mode = true
		t.focus_mode = Control.FOCUS_NONE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		t.custom_minimum_size = Vector2(0, row_h)
		t.pressed.connect(show_tab.bind(i))
		_tab_row.add_child(t)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)
	var back := Button.new()
	back.name = "back"
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, row_h)
	back.pressed.connect(func() -> void: closed.emit())
	v.add_child(back)
	back.grab_focus.call_deferred()
	show_tab(0, false)

## The section the open tab shows.
func section() -> String:
	return tabs[tab] if tab < tabs.size() else ""

func show_tab(i: int, sound: bool = true) -> void:
	if tabs.is_empty():
		return
	tab = posmod(i, tabs.size())
	for k: int in _tab_row.get_child_count():
		(_tab_row.get_child(k) as Button).button_pressed = k == tab
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if sound:
		Sound.sfx("select")
	match section():
		"arts":
			_add_line(Loc.t("Arts of %s" % spirling.display_name()))
			for mv: MoveData in spirling.moves:
				var power: String = "-" if mv.power <= 0 else str(mv.power)
				_add_row(_badge(mv.element), "%s\n%s  %s" % [Loc.t(mv.move_name), Loc.t("Power %s" % power), Loc.t("Energy %d" % mv.energy_cost)])
		"marks":
			var ms: Array[Dictionary] = EraMenus.marks(spirling, leader)
			_add_line(Loc.t("Honours (%d)") % ms.size())
			if ms.is_empty():
				_add_line(Loc.t("No honours yet. They come with the road."))
			for m: Dictionary in ms:
				var pic := TextureRect.new()
				pic.texture = EraMenuArt.mark_icon(str(m.id), int(lay.get("era", 3)), maxi(9, int(lay.get("icon_size", 9))))
				pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				pic.custom_minimum_size = pic.texture.get_size()
				_add_row(pic, "%s\n%s" % [Loc.t(str(m.name)), Loc.t(str(m.text))])
		var sec:
			# The card already carries name, Ring and elements; the text starts under them.
			var text: String = EraMenus.summary_section(spirling, sec, leader)
			_add_line(text.substr(text.find("\n", text.find("\n") + 1 if sec == "info" else 0) + 1))
	_scroll.scroll_vertical = 0
	# Era V: the page slides in from the side it was turned to.
	if str(lay.get("anim", "none")) == "slide" and sound and not Juice.reduced():
		_body.modulate.a = 0.0
		var tw: Tween = _body.create_tween()
		Juice.shaped(tw.tween_property(_body, "modulate:a", 1.0, 0.12), "fade")

func _add_line(text: String) -> void:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text = text
	_body.add_child(l)

func _add_row(left: Control, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left)
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text = text
	row.add_child(l)
	_body.add_child(row)

func _badge(element: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(ElementIcons.SIZE + 5, EraMenuArt.BADGE_H + 1)
	c.draw.connect(func() -> void: EraMenuArt.draw_badge(c, element, Vector2.ZERO, str(lay.get("badges", "colour")), UITheme.INK))
	return c

## Scale of the breathing sprite at [param t] seconds (Era V): 1.0 to 1.04, a slow sine.
static func breathe_at(t: float, reduced: bool) -> float:
	return 1.0 if reduced else 1.0 + 0.02 * (1.0 + sin(t * 2.4))

func _draw_sprite() -> void:
	var px: float = _sprite.size.x
	var tex: Texture2D = MiniSprite.of(spirling.data.species_name, int(_sprite.custom_minimum_size.x))
	if tex == null:
		return
	var k: float = breathe_at(_t, Juice.reduced() or not bool(lay.get("sprite_anim", false)))
	var h: float = roundf(px * k)
	# It breathes from the feet: taller and a little narrower, the ground line stays.
	var w: float = roundf(px * (2.0 - k))
	_sprite.draw_texture_rect(tex, Rect2((px - w) / 2.0, px - h, w, h), false)

func _draw_badges(c: Control) -> void:
	var at := Vector2.ZERO
	var font: Font = UITheme.font()
	var style: String = str(lay.get("badges", "colour"))
	for e: int in spirling.elements():
		at.x += EraMenuArt.draw_badge(c, e, at, style, UITheme.INK)
		var name_text: String = Loc.t(Elements.element_name(e))
		c.draw_string(font, at + Vector2(1, font.get_ascent(UITheme.FONT_SIZE)), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE, UITheme.INK)
		at.x += font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x + 5

func _draw_vigor(c: Control) -> void:
	var ratio: float = clampf(float(spirling.hp) / maxf(1.0, float(spirling.max_hp())), 0.0, 1.0)
	var font: Font = UITheme.font()
	var nums: String = "%d/%d" % [spirling.hp, spirling.max_hp()]
	var nw: float = font.get_string_size(nums, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
	var w: float = maxf(16.0, minf(c.size.x - nw - 6.0, 80.0))
	EraFeel.draw_bar(c, Rect2(1, 4, w, 3), ratio, UITheme.INK, str(EraManager.feel("bar")))
	c.draw_string(font, Vector2(w + 5, font.get_ascent(UITheme.FONT_SIZE) + 1), nums, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE, UITheme.INK)

func _process(delta: float) -> void:
	if bool(lay.get("sprite_anim", false)) and not Juice.reduced() and _sprite != null:
		_t += delta
		_sprite.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		show_tab(tab - 1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		show_tab(tab + 1)
