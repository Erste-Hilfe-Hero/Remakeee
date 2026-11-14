class_name BadgeBook
extends PanelContainer
## Badge book (plan area 8): every achievement as a 16x16 badge in a grid, locked ones grey.
## Tapping or pressing a badge emits [signal chosen] with its index in Achievements.list();
## Back emits -1. The menu then shows the card with text, progress and reward.

signal chosen(index: int)

const COLUMNS: int = 7
var _grid: GridContainer
var _title: Label
var _first: Control
var _filter: Button
## Category shown ("" = every badge, plan 3333).
var category: String = ""

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = MenuHost.PANEL_MARGIN
	offset_top = MenuHost.PANEL_MARGIN
	offset_right = -MenuHost.PANEL_MARGIN
	offset_bottom = -MenuHost.PANEL_MARGIN
	SafeArea.apply(self, MenuHost.PANEL_MARGIN)
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(1, 0)
	box.add_child(_title)
	_filter = Button.new()
	_filter.pressed.connect(next_category)
	box.add_child(_filter)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)
	var back := Button.new()
	back.text = Loc.t("Back")
	back.pressed.connect(func() -> void: chosen.emit(-1))
	box.add_child(back)
	fill()

## Builds the grid from the current save.
func fill() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	var have: Dictionary = Achievements.unlocked()
	var list: Array[Dictionary] = Achievements.list()
	_title.text = Loc.t("Badge book %d/%d (%d%%)") % [have.size(), list.size(), Achievements.percent()]
	_filter.text = Loc.t("Show: %s") % Loc.t(str(Achievements.CATEGORY_NAMES.get(category, "All badges")))
	_first = null
	for i: int in Achievements.indices_for(category):
		var a: Dictionary = list[i]
		var b := TextureButton.new()
		b.texture_normal = Badges.texture(a, have.has(a.id))
		b.custom_minimum_size = Vector2(Badges.SIZE, Badges.SIZE)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = Loc.t(Achievements.shown_title(a))
		b.pressed.connect(func() -> void: chosen.emit(i))
		b.focus_entered.connect(func() -> void: _title.text = "%s\n%s" % [Loc.t("Badge book %d/%d") % [have.size(), list.size()], Loc.t(str(a.title)) if have.has(a.id) else Loc.t("Locked: %s") % Loc.t(Achievements.shown_text(a))])
		_grid.add_child(b)
		if _first == null:
			_first = b
	if _first != null:
		_first.grab_focus.call_deferred()

## Steps the filter to the next category, after the last one back to every badge.
func next_category() -> void:
	var order: Array[String] = [""]
	order.append_array(Achievements.CATEGORIES)
	category = order[(order.find(category) + 1) % order.size()]
	fill()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit(-1)
