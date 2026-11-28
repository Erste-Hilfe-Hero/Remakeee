extends GutTest
## Plan area 6, item 2428: a pressed name key lights up one step brighter for 0.08 s.

func _keys() -> NameKeyboard:
	var edit := LineEdit.new()
	add_child_autofree(edit)
	var k := NameKeyboard.new()
	k.target = edit
	add_child_autofree(k)
	return k

func test_pressed_key_flashes_then_returns() -> void:
	var k: NameKeyboard = _keys()
	var b: Button = k.key_button("A")
	assert_not_null(b)
	k.press("A")
	assert_eq(b.self_modulate, NameKeyboard.FLASH_TINT, "lit up at once")
	await wait_seconds(NameKeyboard.FLASH_TIME + 0.15)
	assert_eq(b.self_modulate, Color.WHITE, "back to normal")

func test_typed_key_flashes_too() -> void:
	var k: NameKeyboard = _keys()
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = "m".unicode_at(0)
	assert_true(k.type_key(ev))
	assert_eq(k.key_button("M").self_modulate, NameKeyboard.FLASH_TINT)

func test_page_key_rebuild_is_safe() -> void:
	var k: NameKeyboard = _keys()
	k.press(NameKeyboard.PAGE_EXTRA)
	await wait_seconds(NameKeyboard.FLASH_TIME + 0.15)
	assert_null(k.key_button(NameKeyboard.PAGE_EXTRA), "the old page is gone without errors")
