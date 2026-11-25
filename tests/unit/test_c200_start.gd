extends GutTest
## Chimora 200 list, start package: name dice key (item 6).

func test_dice_key_puts_a_new_name_idea_in_the_field() -> void:
	var edit := LineEdit.new()
	add_child_autofree(edit)
	var keys := NameKeyboard.new()
	keys.target = edit
	add_child_autofree(keys)
	edit.text = "Corin"
	keys.press(NameKeyboard.DICE)
	assert_true(edit.text in NameKeyboard.NAME_IDEAS, edit.text)
	assert_true(keys.fresh, "the first typed key replaces the idea")
	keys.press("B")
	assert_eq(edit.text, "B")

func test_name_idea_never_repeats_the_current_name() -> void:
	for roll: int in NameKeyboard.NAME_IDEAS.size():
		var cur: String = NameKeyboard.NAME_IDEAS[roll]
		assert_ne(NameKeyboard.name_idea(cur, roll), cur)

func test_name_ideas_are_valid_names() -> void:
	for n: String in NameKeyboard.NAME_IDEAS:
		assert_true(NameKeyboard.valid_name(n), n)

func test_name_row_has_keyboard_dice_and_back() -> void:
	var keys := NameKeyboard.new()
	var row: HBoxContainer = keys.make_extra_row()
	assert_eq(row.get_child_count(), 3)
	assert_eq((row.get_child(1) as Button).text, NameKeyboard.DICE)
	row.free()
	keys.free()

# --- item 15: a save mark shows after each quiet save ------------------------------------------

func test_save_pip_shows_on_save_and_fades() -> void:
	var pip := SavePip.new()
	add_child_autofree(pip)
	assert_false(pip.is_showing())
	SaveManager.saved.emit()
	assert_true(pip.is_showing())
	await wait_seconds(SavePip.SHOW_S + SavePip.FADE_S + 0.2)
	assert_false(pip.is_showing())

# --- items 14, 115: the talk log keeps the last 20 overworld lines --------------------------------

func test_talk_log_keeps_the_last_twenty_lines_newest_first_in_the_menu() -> void:
	TextBox.talk_log.clear()
	for i: int in 25:
		TextBox.log_line("Kestra: line %d" % i)
	assert_eq(TextBox.talk_log.size(), TextBox.TALK_LOG_MAX)
	var rows: Array[Dictionary] = PauseMenu.talk_log_rows()
	assert_eq(str(rows[0].text), "Kestra: line 24")
	assert_eq(str(rows[rows.size() - 1].text), "Kestra: line 5")
	TextBox.talk_log.clear()
	assert_true(bool(PauseMenu.talk_log_rows()[0].get("disabled", false)), "an empty log says so")

func test_only_a_logging_box_writes_the_talk_log() -> void:
	TextBox.talk_log.clear()
	var box := TextBox.new()
	add_child_autofree(box)
	box.show_text("A battle line.")
	assert_true(TextBox.talk_log.is_empty(), "battle boxes do not log")
	box.keep_log = true
	box.show_text("Hello there.", "Kestra")
	assert_eq(TextBox.talk_log, ["Kestra: Hello there."] as Array[String])
	TextBox.talk_log.clear()

func test_talk_log_has_a_symbol_and_hint() -> void:
	assert_true(EraMenuArt.has(PauseMenu.TALK_LOG))
	assert_true(EraMenuKit.PAUSE_HINTS.has(PauseMenu.TALK_LOG))

# --- item 19: the Account menu says when the journey last reached the server ----------------------

func test_backup_line_says_how_long_ago() -> void:
	var keep_at: Dictionary = Online.backup_at.duplicate()
	var keep_dirty: Dictionary = Online.dirty.duplicate()
	Online.dirty.erase(7)
	Online.backup_at.erase(7)
	assert_eq(Online.backup_line(7), "", "never backed up: no line")
	Online.backup_at[7] = 1000
	assert_eq(Online.backup_line(7, 1030), "Backed up just now.")
	assert_eq(Online.backup_line(7, 1000 + 5 * 60), "Backed up 5 min ago.")
	assert_eq(Online.backup_line(7, 1000 + 3 * 3600), "Backed up 3 h ago.")
	Online.dirty[7] = true
	assert_eq(Online.backup_line(7, 1030), "Backup waits for the connection.")
	Online.backup_at = keep_at
	Online.dirty = keep_dirty
