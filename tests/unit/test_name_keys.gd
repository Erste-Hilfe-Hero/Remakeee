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
	assert_eq(k.get_child_count(), 28)
