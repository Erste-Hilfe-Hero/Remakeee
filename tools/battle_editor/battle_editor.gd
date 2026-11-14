extends Control
## Developer battle editor (KAMPF_PLAN_1000 item 993). Open tools/battle_editor/battle_editor.tscn
## in the Godot editor and press F6: set both teams, field, Warden rule, boss, seed, AI and front
## sizes, then Run plays the battle with the AI on both sides and shows the full log. Battle data
## packs (BattlePacks, signed by a trusted key) add their fields and bosses to the lists and their
## ready battles to "Pack battle". "Copy setup" puts the setup as JSON on the clipboard for a
## pack's "battles" list; "Save setup" writes it to user://battle_setups/. English only, dev tool.

const BattleSetup := preload("res://tools/battle_editor/BattleSetup.gd")
const SETUP_DIR: String = "user://battle_setups"

var player_edit := LineEdit.new()
var foe_edit := LineEdit.new()
var field_pick := OptionButton.new()
var rule_pick := OptionButton.new()
var boss_pick := OptionButton.new()
var pack_pick := OptionButton.new()
var seed_box := SpinBox.new()
var ai_box := SpinBox.new()
var front_player := SpinBox.new()
var front_foe := SpinBox.new()
var wild_box := CheckBox.new()
var name_edit := LineEdit.new()
var pack_path := LineEdit.new()
var output := TextEdit.new()
var pack_battles: Array = []

func _ready() -> void:
	Database.load_all()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	add_child(root)
	var grid := GridContainer.new()
	grid.columns = 4
	root.add_child(grid)
	name_edit.text = "editor battle"
	player_edit.text = "Kindlop 12, Zippit 12"
	foe_edit.text = "Mossling 12, Wickit 12"
	seed_box.max_value = 2147483647
	seed_box.value = 1
	ai_box.max_value = 3
	ai_box.value = 1
	for box: SpinBox in [front_player, front_foe]:
		box.min_value = 1
		box.max_value = BattleRules.MAX_FRONT
		box.value = 1
	wild_box.text = "wild"
	pack_path.placeholder_text = "user://battle_packs"
	pack_path.text = "user://battle_packs"
	for row: Array in [["Name", name_edit], ["Seed", seed_box], ["Player team", player_edit], ["Foe team", foe_edit],
			["Field", field_pick], ["Rule", rule_pick], ["Boss", boss_pick], ["AI 0-3", ai_box],
			["Front player", front_player], ["Front foe", front_foe], ["Wild", wild_box], ["Pack battle", pack_pick],
			["Pack folder", pack_path]]:
		var l := Label.new()
		l.text = str(row[0])
		grid.add_child(l)
		(row[1] as Control).custom_minimum_size.x = 220
		grid.add_child(row[1])
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	for b: Array in [["Run", run], ["Load packs", load_packs], ["Copy setup", copy_setup], ["Save setup", save_setup]]:
		var btn := Button.new()
		btn.text = str(b[0])
		btn.pressed.connect(b[1])
		buttons.add_child(btn)
	output.editable = false
	output.add_theme_color_override("font_readonly_color", Color(0.92, 0.92, 0.92))
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(output)
	pack_pick.item_selected.connect(_pack_battle)
	refresh_lists()

## Fills the field, rule, boss and pack battle lists from the tables in play.
func refresh_lists() -> void:
	for pair: Array in [[field_pick, BattleRules.FIELDS], [rule_pick, BattleRules.RULES], [boss_pick, BattleRules.BOSSES]]:
		var pick: OptionButton = pair[0]
		pick.clear()
		pick.add_item("(none)")
		for id: String in pair[1]:
			pick.add_item(id)
	pack_pick.clear()
	pack_pick.add_item("(none)")
	for b: Dictionary in pack_battles:
		pack_pick.add_item(str(b.get("name", "?")))

func _picked(pick: OptionButton) -> String:
	return "" if pick.selected <= 0 else pick.get_item_text(pick.selected)

func _select(pick: OptionButton, id: String) -> void:
	pick.select(0)
	for i: int in pick.item_count:
		if pick.get_item_text(i) == id:
			pick.select(i)

## The setup the form shows.
func setup() -> Dictionary:
	return {"name": name_edit.text, "player": BattleSetup.parse_team(player_edit.text), "foe": BattleSetup.parse_team(foe_edit.text),
		"field": _picked(field_pick), "rule": _picked(rule_pick), "boss": _picked(boss_pick), "seed": int(seed_box.value),
		"ai": int(ai_box.value), "front": [int(front_player.value), int(front_foe.value)], "wild": wild_box.button_pressed}

## Puts [param s] into the form.
func show_setup(s: Dictionary) -> void:
	name_edit.text = str(s.get("name", ""))
	player_edit.text = BattleSetup.team_text(s.get("player", []))
	foe_edit.text = BattleSetup.team_text(s.get("foe", []))
	_select(field_pick, str(s.get("field", "")))
	_select(rule_pick, str(s.get("rule", "")))
	_select(boss_pick, str(s.get("boss", "")))
	seed_box.value = int(s.get("seed", 1))
	ai_box.value = int(s.get("ai", 1))
	var front: Array = s.get("front", [1, 1])
	front_player.value = int(front[0])
	front_foe.value = int(front[1])
	wild_box.button_pressed = bool(s.get("wild", false))

func run() -> Dictionary:
	var r: Dictionary = BattleSetup.play(setup())
	if not (r.errors as PackedStringArray).is_empty():
		output.text = "\n".join(r.errors)
	else:
		output.text = "%s after %d turns\n\n%s" % [r.outcome, r.turns, "\n".join(r.log)]
	return r

## Reads every signed pack in the pack folder; returns the errors of the packs that were refused.
func load_packs(keys: Dictionary = {}) -> PackedStringArray:
	BattleRules.reload_tables()
	pack_battles.clear()
	var errs: PackedStringArray = []
	var dir: String = pack_path.text.strip_edges()
	var names: PackedStringArray = DirAccess.get_files_at(dir)
	names.sort()
	for f: String in names:
		if not f.ends_with(".kpack.json"):
			continue
		var r: Dictionary = BattlePacks.read(dir.path_join(f), keys)
		if (r.pack as Dictionary).is_empty():
			errs.append_array(r.errors)
			continue
		BattlePacks.apply(r.pack)
		pack_battles.append_array(r.pack.get("battles", []))
	refresh_lists()
	output.text = "Packs loaded: %d battles. %s" % [pack_battles.size(), "\n".join(errs)]
	return errs

func _pack_battle(index: int) -> void:
	if index > 0 and index <= pack_battles.size():
		show_setup(pack_battles[index - 1])

func copy_setup() -> void:
	DisplayServer.clipboard_set(JSON.stringify(setup(), "\t", false))
	output.text = "Setup copied."

func save_setup() -> String:
	DirAccess.make_dir_recursive_absolute(SETUP_DIR)
	var path: String = SETUP_DIR.path_join(name_edit.text.to_snake_case().validate_filename() + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		output.text = "Could not write %s" % path
		return ""
	f.store_string(JSON.stringify(setup(), "\t", false))
	f.close()
	output.text = "Saved %s" % path
	return path
