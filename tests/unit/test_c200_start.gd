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

# --- items 22, 45: bonded kinds per place, a star when all are bonded --------------------------------

func test_bond_count_and_star_per_place() -> void:
	var kinds: Array[String] = WorldAtlas.spawn_kinds("brindlewick")
	if kinds.is_empty():
		kinds = WorldAtlas.spawn_kinds("fernstair")
	assert_false(kinds.is_empty(), "a starting place has wild Spirlings")
	var place: String = "brindlewick" if not WorldAtlas.spawn_kinds("brindlewick").is_empty() else "fernstair"
	assert_eq(WorldAtlas.bond_count(place, {}), [0, kinds.size()] as Array[int])
	assert_eq(WorldAtlas.complete_mark(place, {}), "")
	var all: Dictionary = {}
	for k: String in kinds:
		all[k] = {"seen": true, "bonded": true}
	assert_eq(WorldAtlas.bond_count(place, all), [kinds.size(), kinds.size()] as Array[int])
	assert_eq(WorldAtlas.complete_mark(place, all), " *")

# --- item 129: version and build for support ---------------------------------------------------

func test_about_text_names_version_build_and_contact() -> void:
	var t: String = LegalInfo.about_text()
	assert_string_contains(t, Online.CLIENT_VERSION_NAME)
	assert_string_contains(t, "build %d" % Online.CLIENT_VERSION)
	assert_string_contains(t, LegalInfo.CONTACT)

# --- item 36: the last travel target heads the list ------------------------------------------------

func test_last_travel_target_comes_first() -> void:
	var ids: Array[String] = ["a", "b", "c"]
	assert_eq(PauseMenu.last_first(ids, "c"), ["c", "a", "b"] as Array[String])
	assert_eq(PauseMenu.last_first(ids, "x"), ids, "unknown last target: order stays")
	assert_eq(ids, ["a", "b", "c"] as Array[String], "the input is not changed")

# --- item 7: the name box asks for another name while typing a refused one ------------------------

func test_refused_names_are_flagged_while_typing() -> void:
	assert_false(CharCounter.name_refused(""))
	assert_false(CharCounter.name_refused("Liora"))
	assert_true(CharCounter.name_refused("www"))
	assert_true(CharCounter.name_refused("Nazi"))
	var edit := LineEdit.new()
	add_child_autofree(edit)
	var ask := Label.new()
	ask.text = "Your name?"
	add_child_autofree(ask)
	var c: CharCounter = CharCounter.make(edit, 10)
	c.ask_label = ask
	c.ask_text = ask.text
	add_child_autofree(c)
	edit.text = "Hitler"
	await wait_frames(2)
	assert_eq(ask.text, CharCounter.ASK_AGAIN)
	edit.text = "Mira"
	await wait_frames(2)
	assert_eq(ask.text, "Your name?")
