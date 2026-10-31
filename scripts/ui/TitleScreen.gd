class_name TitleScreen
extends Control
## Title and new-game flow: difficulty -> Tamer customisation (placeholder) -> starter.

const OVERWORLD: String = "res://scenes/overworld/Overworld.tscn"
const STARTERS: Array[String] = Database.STARTERS
const DIFFICULTY_TEXT: Array[String] = [
	"Story (relaxed)",
	"Tamer (normal)",
	"Veteran (caps, smart AI)",
	"Rift-Born (no battle items)",
]
const NAME_MAX: int = 10
const TITLE_SIZE: int = 24

var _menu: MenuHost
var _name_box: PanelContainer
var _name_edit: LineEdit
signal _name_done(text: String)

func _ready() -> void:
	Database.load_all()
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "CHIMORA"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 36
	add_child(title)
	var sub := Label.new()
	sub.text = "A Spirling bonding tale"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 66
	add_child(sub)
	_menu = MenuHost.new()
	add_child(_menu)
	_menu.offset_top = 96
	_build_name_box()
	VirtualPad.set_wanted(false)
	GameState.in_game = false
	_run.call_deferred()

func _build_name_box() -> void:
	_name_box = PanelContainer.new()
	_name_box.add_theme_stylebox_override("panel", UITheme.panel_style())
	_name_box.set_anchors_preset(Control.PRESET_CENTER)
	_name_box.custom_minimum_size = Vector2(120, 50)
	_name_box.offset_left = -60
	_name_box.offset_right = 60
	_name_box.offset_top = -25
	_name_box.offset_bottom = 25
	_name_box.visible = false
	add_child(_name_box)
	var v := VBoxContainer.new()
	_name_box.add_child(v)
	var l := Label.new()
	l.text = "Your name?"
	v.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	_name_edit.add_theme_stylebox_override("normal", UITheme.panel_style(UITheme.ACCENT))
	_name_edit.add_theme_color_override("font_color", UITheme.INK)
	_name_edit.text_submitted.connect(func(t: String) -> void: _name_done.emit(t))
	# Gamepad / virtual pad confirm also submits the name.
	_name_edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_accept") and not (ev is InputEventKey):
			_name_done.emit(_name_edit.text))
	v.add_child(_name_edit)
	var ok := Button.new()
	ok.text = "OK"
	ok.pressed.connect(func() -> void: _name_done.emit(_name_edit.text))
	v.add_child(ok)

func _run() -> void:
	while true:
		var items: Array[String] = []
		var has_save: bool = SaveManager.has_save()
		if has_save:
			items.append("Continue")
		items.append_array(["New Game", "Settings"] as Array[String])
		var idx: int = await _menu.pick_strings("", items, false)
		match items[idx]:
			"Continue":
				if SaveManager.load_game():
					get_tree().change_scene_to_file(OVERWORLD)
					return
				await _menu.info("The save could not be read.")
			"New Game":
				if has_save and not await _menu.confirm("Start over? Your save will be replaced when you save."):
					continue
				if await _new_game():
					get_tree().change_scene_to_file(OVERWORLD)
					return
			"Settings":
				await _menu.run_settings()

func _new_game() -> bool:
	var diff: int = await _menu.pick_strings("Difficulty", DIFFICULTY_TEXT)
	if diff < 0:
		return false
	_name_edit.text = GameState.tamer_name
	_name_box.visible = true
	_name_edit.grab_focus()
	var name: String = await _name_done
	_name_box.visible = false
	var colors: Array[String] = ["Blue jacket", "Red jacket", "Green jacket", "Gold jacket"]
	var color: int = await _menu.pick_strings("Your look", colors)
	if color < 0:
		color = 0
	while true:
		var entries: Array[String] = []
		for sp: String in STARTERS:
			entries.append("%s (%s)" % [sp, Elements.element_name(Database.species(sp).elements[0])])
		var pick: int = await _menu.pick_strings("Choose your partner", entries)
		if pick < 0:
			return false
		var sd: SpirlingData = Database.species(STARTERS[pick])
		if await _menu.confirm("%s, the %s Spirling. Bond with it?" % [sd.species_name, Elements.element_name(sd.elements[0])]):
			GameState.new_game(diff as GameState.Difficulty, name, color, sd.species_name)
			EraManager.from_dict({})
			return true
	return false
