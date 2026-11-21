extends GutTest
## Owner, 9 Nov: fewer text windows in battle; short lines float over the Spirling instead.

func test_float_sits_above_the_point_and_stacks() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var a: FloatText = FloatText.spawn(root, "A keen hit!", Vector2(80, 60))
	var b: FloatText = FloatText.spawn(root, "A keen hit!", Vector2(80, 60), 1)
	assert_not_null(a)
	assert_true(a.position.y + a.size.y <= 60.0, "above the Spirling")
	assert_true(b.position.y < a.position.y, "a second line sits higher")
	assert_eq(a.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never blocks a tap")

func test_empty_line_spawns_nothing() -> void:
	var root := Control.new()
	add_child_autofree(root)
	assert_null(FloatText.spawn(root, "", Vector2(10, 10)))

func test_minor_battle_events_do_not_open_the_text_box() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/BattleScene.gd")
	for kind: String in ["MOVE_USED", "STAT_CHANGED", "STATUS_APPLIED", "STATUS_CURED", "MISSED", "XP_GAINED", "HEAL"]:
		var at: int = src.find("\n\t\tBattleEvent.Type." + kind + ":")
		assert_true(at >= 0, kind)
		var arm: RegEx = RegEx.create_from_string("\\n\\t\\t[^\\t]")
		var next: RegExMatch = arm.search(src, at + 3)
		var body: String = src.substr(at, (next.get_start() if next else src.length()) - at)
		assert_true(body.contains("_float("), kind + " floats")
		assert_false(body.contains("_text.show_text"), kind + " opens no text box")

func test_tip_lines_get_no_name_tag() -> void:
	assert_eq(Dialogue.split_speaker("Tip: wear it down first.")[0], "", "Tip is not a speaker")
	assert_eq(Dialogue.split_speaker("Aldo: hello")[0], "Aldo")

func test_command_buttons_clip_instead_of_widening_the_screen() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/CommandMenu.gd")
	assert_true(src.contains("b.clip_text = true"))
