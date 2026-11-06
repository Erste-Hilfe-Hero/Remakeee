extends GutTest
## On-screen name keys at new game (the phone keyboard does not always open).

func _keys() -> NameKeyboard:
	var edit := LineEdit.new()
	edit.max_length = 10
	add_child_autofree(edit)
	var k := NameKeyboard.new()
	k.target = edit
	add_child_autofree(k)
	return k

func test_typing_capitalises_first_letter_only() -> void:
	var k: NameKeyboard = _keys()
	for c: String in ["M", "A", "R", "A"]:
		k.press(c)
	assert_eq(k.target.text, "Mara")

func test_first_key_replaces_suggested_name() -> void:
	var k: NameKeyboard = _keys()
	k.target.text = "Corin"
	k.fresh = true
	k.press("L")
	assert_eq(k.target.text, "L")

func test_delete_and_max_length() -> void:
	var k: NameKeyboard = _keys()
	for i: int in 12:
		k.press("A")
	assert_eq(k.target.text.length(), 10)
	k.press(NameKeyboard.DELETE)
	assert_eq(k.target.text.length(), 9)

func test_ok_confirms_and_keeps_suggestion() -> void:
	var k: NameKeyboard = _keys()
	k.target.text = "Corin"
	k.fresh = true
	watch_signals(k)
	k.press(NameKeyboard.OK)
	assert_signal_emitted(k, "confirmed")
	assert_eq(k.target.text, "Corin")

func test_has_all_letters_and_keys() -> void:
	var k: NameKeyboard = _keys()
	assert_eq(k.get_child_count(), 29, "26 letters, the second page, delete and OK")

# --- Plan area 5: umlauts, codes, empty names -----------------------------------------

func test_second_page_has_umlauts_hyphen_and_space() -> void:
	var k: NameKeyboard = _keys()
	k.press("J")
	k.press(NameKeyboard.PAGE_EXTRA)
	await wait_process_frames(1)
	var labels: Array[String] = []
	for b: Node in k.get_children():
		labels.append((b as Button).text)
	for c: String in ["Ä", "Ö", "Ü", "ß", "-", NameKeyboard.SPACE]:
		assert_true(c in labels, "key " + c)
	k.press("Ö")
	k.press("-")
	k.press(NameKeyboard.PAGE_LETTERS)
	k.press("A")
	assert_eq(k.target.text, "Jö-A", "capital again after a hyphen")
	k.press(NameKeyboard.PAGE_EXTRA)
	k.press(NameKeyboard.SPACE)
	k.press(NameKeyboard.SPACE)
	assert_eq(k.target.text, "Jö-A ", "no double spaces")

func test_pixel_font_has_every_key() -> void:
	var font: Font = PixelFont.get_font()
	for c: String in NameKeyboard.LETTERS + NameKeyboard.DIGITS + "äöüÄÖÜß-":
		assert_true(font.has_char(c.unicode_at(0)), "glyph " + c)

func test_empty_or_blank_names_are_refused() -> void:
	assert_false(NameKeyboard.valid_name(""))
	assert_false(NameKeyboard.valid_name("   "))
	assert_true(NameKeyboard.valid_name("Mara"))

func test_code_keys_group_by_four_and_paste() -> void:
	var k: NameKeyboard = _keys()
	k.target.max_length = 0
	k.code_length = 12
	k.set_mode(NameKeyboard.Mode.CODE)
	for c: String in ["A", "B", "C", "D", "1"]:
		k.press(c)
	assert_eq(k.target.text, "ABCD-1")
	k.press(NameKeyboard.DELETE)
	assert_eq(k.target.text, "ABCD", "the dash goes with the last character")
	k.paste(" abcd-efgh 1234 5678 ")
	assert_eq(k.target.text, "ABCD-EFGH-1234", "pasted codes are cleaned and cut to length")
	assert_eq(NameKeyboard.raw_code(k.target.text), "ABCDEFGH1234")

func test_back_key_cancels() -> void:
	var k: NameKeyboard = _keys()
	watch_signals(k)
	k.press(NameKeyboard.BACK)
	assert_signal_emitted(k, "cancelled")

func test_code_prompt_returns_letters_and_digits_only() -> void:
	var res: Array = []
	var run := func() -> void:
		res.append(await CodePrompt.ask(self, "Friend code", 8))
	run.call()
	await wait_process_frames(1)
	var p: CodePrompt = null
	for c: Node in get_children():
		if c is CodePrompt:
			p = c
	assert_not_null(p)
	p.keys.paste("wxyz-1234")
	p.keys.press(NameKeyboard.OK)
	await wait_process_frames(1)
	assert_eq(res, ["WXYZ1234"])
