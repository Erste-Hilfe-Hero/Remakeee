extends GutTest
## Owner wish 23.11.2026 (plan Chimora 100): the map's talk box above the on-screen buttons,
## never under them. The centred, larger talk text of that day is off again since 25.11.2026
## on the map (owner: "Texte im Chat gleich machen wie davor"): left-aligned, the screen's own
## font. The battle box (big_text) keeps the centred, larger lines.

var _lang: String
var _large: bool

func before_each() -> void:
	_lang = Loc.language()
	_large = UITheme.large_text
	Loc.set_language("en")
	UITheme.set_large_text(false)

func after_each() -> void:
	UITheme.set_large_text(_large)
	Loc.set_language(_lang)

func test_lift_clears_the_buttons() -> void:
	assert_eq(Overworld.text_lift(-1.0, 256.0), 0, "no pad, the box stays at the bottom")
	assert_eq(Overworld.text_lift(256.0, 256.0), 0)
	assert_eq(Overworld.text_lift(200.0, 256.0), 56 + Overworld.PAD_GAP)
	assert_eq(Overworld.text_lift(199.5, 256.0), 57 + Overworld.PAD_GAP)

func test_small_text_takes_the_large_glyphs() -> void:
	var big: Array = TextBox.big_font(PixelFont.get_font(), UITheme.FONT_SIZE, true)
	assert_same(big[0], PixelFont.get_large_font())
	assert_eq(big[1], UITheme.FONT_SIZE)

func test_large_text_doubles_on_the_map_and_stays_in_battle() -> void:
	var map: Array = TextBox.big_font(PixelFont.get_large_font(), UITheme.FONT_SIZE, true)
	assert_eq(int((map[0] as Font).get_height(map[1])), PixelFont.CELL_H * TextBox.BIG_SCALE)
	var battle: Array = TextBox.big_font(PixelFont.get_bold_font(), UITheme.FONT_SIZE, false)
	assert_same(battle[0], PixelFont.get_bold_font())

func test_box_text_is_left_aligned_in_the_screen_font_as_before() -> void:
	var box := TextBox.new()
	add_child_autofree(box)
	box.size = Vector2(144, 44)
	box.show_prompt("Orders for Kindlop?")
	assert_eq(box._label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_false(box._label.has_theme_font_override("font"), "no larger talk font")
	assert_false(box._label.has_theme_font_size_override("font_size"))

func test_map_talk_box_sits_above_the_pad() -> void:
	Database.load_all()
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	VirtualPad.force_visible = true
	VirtualPad.apply_settings()
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	VirtualPad.set_talk(true)
	ow.player.global_position = Vector2(ow.player.global_position.x, ow._camera.global_position.y - 32)
	ow._place_text_box()
	await wait_process_frames(2)
	var r: Rect2 = ow.text_box().get_global_rect()
	assert_false(ow.text_box_on_top())
	assert_lte(r.end.y, VirtualPad.top_y(), "the box ends above the A button")
	VirtualPad.set_talk(false)
	VirtualPad.set_wanted(false)
	VirtualPad.force_visible = false

func test_battle_box_is_centred_and_larger() -> void:
	var box := TextBox.new()
	box.big_text = true
	box.allow_double = false
	add_child_autofree(box)
	box.size = Vector2(144, 44)
	box.show_prompt("Orders for Kindlop?")
	assert_eq(box._label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	var f: Font = box._label.get_theme_font("font")
	assert_gte(int(f.get_height(box._label.get_theme_font_size("font_size"))), PixelFont.LARGE_H)
	assert_eq(box._label_pad.content_margin_left, box._label_pad.content_margin_right, "centring stays true")

func test_long_prompt_keeps_the_screen_font() -> void:
	var box := TextBox.new()
	box.big_text = true
	add_child_autofree(box)
	box.size = Vector2(144, 44)
	box.fit_prompt = true
	box.show_prompt("Orders for Kindlop? (10 Energy)\nActing order: foe Zippit > Kindlop > Puddlet > foe Shalebat")
	assert_false(box._label.has_theme_font_override("font"), "too long for three large lines: the screen's own font")
	box.show_prompt("Orders for Kindlop?")
	assert_true(box._label.has_theme_font_override("font"), "a short prompt is larger again")

func test_continue_marker_keeps_clear_of_the_text() -> void:
	var box := TextBox.new()
	add_child_autofree(box)
	box.size = Vector2(144, 52)
	box.show_prompt("Orders for Kindlop?")
	var f: Font = box._arrow.get_theme_font("font")
	var aw: float = f.get_string_size("v", HORIZONTAL_ALIGNMENT_LEFT, -1, box._arrow.get_theme_font_size("font_size")).x
	assert_gte(float(box._arrow_space), aw + TextBox.ARROW_GAP, "room for the marker and a gap")
	assert_lte(box._label_pad.content_margin_left, 0.0, "left-aligned text starts at the frame (no left margin)")
