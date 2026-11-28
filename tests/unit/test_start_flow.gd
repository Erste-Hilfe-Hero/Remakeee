extends GutTest
## Chimora 100 items 25-36, 45, 52, 54: a new player walks much sooner. At most
## Overworld.START_TEXT_BOXES text boxes before the Wayfarer can walk, difficulty asked at new
## game, one look screen, a short privacy note, Skip clear of the story text, skippable cards,
## partner pictures, free fast text, one tip at battle start, any script in the name.

const LANGS: Array[String] = ["en", "de", "ru", "ja"]

var _flags: Dictionary
var _tips_on: bool

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_tips_on = GameState.tips_enabled
	GameState.flags.clear()
	GameState.tips_enabled = true

func after_each() -> void:
	GameState.flags = _flags
	GameState.tips_enabled = _tips_on
	Loc.set_language("en")

# --- Item 26, 1.3.2: no text box before control ----------------------------------------

## Every line the player taps through from New Game until the first free step: none since the
## opening in the ferns (Opening). The storm night now plays in Brindlewick.
func _start_lines() -> Array[String]:
	return [] as Array[String]

## The storm night, now the first thing in Brindlewick (Overworld.village_story).
func _storm_lines() -> Array[String]:
	var out: Array[String] = []
	for step: Variant in ScenePlayer.load_scene("prologue").get("steps", []):
		if step is Dictionary and (step as Dictionary).has("say"):
			for l: Variant in step.say:
				out.append(str(l))
	return out

func _pages(box: TextBox, line: String) -> int:
	var shown: String = Loc.t(line).replace("{name}", "Liora")
	var parts: PackedStringArray = Dialogue.split_speaker(shown)
	if not parts[0].is_empty():
		shown = parts[1]
	var lab: Label = box._label
	return TextBox.split_lines(shown, box._text_width(), lab.get_theme_font("font"), lab.get_theme_font_size("font_size"), TextBox.MAX_LINES).size()

func test_at_most_ten_text_boxes_before_the_player_walks() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	GameState.set_flag("got_starter")
	add_child_autofree(ow)
	await wait_frames(2)
	for lang: String in LANGS:
		Loc.set_language(lang)
		var n: int = 0
		for line: String in _start_lines():
			n += _pages(ow.text_box(), line)
		assert_lte(n, Overworld.START_TEXT_BOXES, "%s: %d text boxes before the first step" % [lang, n])

func test_the_new_journey_walks_at_once() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "", 0, "")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(3)
	assert_eq(ow.map.id, Opening.MAP)
	assert_false(ow.busy, "nothing to read first")
	assert_false(ow.player.frozen)
	assert_false(ow.text_box().visible)
	assert_true(GameState.has_flag(Overworld.FIRST_WALK_FLAG))
	assert_lte(Funnel.at(GameState.records, "first_control"), 1, "control within the first second of play")
	GameState.flags.clear()

func test_save_and_goal_tips_wait_until_the_player_walks() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_false(src.contains("await _locked_say(Tips.take(\"save\"))"), "the save tip no longer stops the start")
	assert_string_contains(src, "waiting_tips.append(\"save\")")
	assert_string_contains(src, "waiting_tips.append(\"goals\")")

func test_cut_lore_lives_on_the_first_page() -> void:
	var page: String = "\n".join(Dialogue.lines_for(Dialogue.get_entry("story/page_1"), {}))
	for word: String in ["cartographers", "Hush", "grandmother", "never came back"]:
		assert_string_contains(page, word)

# --- Item 25, changed 2026-11-27: no difficulty question (one mode, harder act by act) -----

func test_new_game_asks_no_difficulty() -> void:
	var consts: Dictionary = (TitleScreen as Script).get_script_constant_map()
	for k: String in ["DIFFICULTY_TITLE", "DIFFICULTY_CHOICES", "DIFFICULTY_ROWS", "DIFFICULTY_LINES", "DIFFICULTY_LATER"]:
		assert_false(consts.has(k), k)
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd")
	assert_false(src.contains("ask_difficulty"), "the new game flow asks no difficulty")
	assert_string_contains(src, "GameState.new_game(GameState.Difficulty.TAMER,")
	assert_false(src.contains("How do you want to travel?"), "challenge rules are not the first question")
	GameState.new_game(GameState.Difficulty.VETERAN, "Tess", 0, "")
	assert_eq(GameState.difficulty, GameState.Difficulty.TAMER, "every journey plays the one mode")

# --- Item 27: one look screen -------------------------------------------------------------

func test_look_rows_step_and_random() -> void:
	var look: Array[int] = [0, 0, 0, 0]
	assert_eq(TitleScreen.look_rows(look).size(), 6, "four parts, Random, Done")
	TitleScreen.step_look(look, TitleScreen.LOOK_SKIN, -1)
	assert_eq(look[TitleScreen.LOOK_SKIN], GameState.SKIN_NAMES.size() - 1, "left wraps around")
	TitleScreen.step_look(look, TitleScreen.LOOK_BODY, 1)
	assert_eq(look[TitleScreen.LOOK_BODY], 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 20:
		TitleScreen.random_look(look, rng)
		for part: int in 4:
			assert_between(look[part], 0, TitleScreen.look_choices(part).size() - 1)

func test_look_preview_shows_the_picked_colours() -> void:
	var a: Texture2D = TitleScreen.look_texture([0, 0, 0, 0] as Array[int], 0)
	var b: Texture2D = TitleScreen.look_texture([0, 4, 1, 2] as Array[int], 0)
	assert_not_null(a)
	assert_eq(a.get_size(), Vector2(TitleScreen.LOOK_FRAME * TitleScreen.LOOK_SCALE, TitleScreen.LOOK_FRAME * TitleScreen.LOOK_SCALE))
	assert_ne(a.get_image().get_data(), b.get_image().get_data(), "skin, hair and coat change the picture")

func test_look_screen_done_and_back() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	var stage := Control.new()
	add_child_autofree(stage)
	await wait_frames(1)
	var look: Array[int] = [0, 0, 0, 0]
	var res: Array = []
	var run := func() -> void: res.append(await TitleScreen.look_screen(host, look, stage))
	run.call()
	await wait_frames(2)
	assert_true(stage.visible and stage.get_child_count() > 0, "the picture shows")
	host.picker.last_dir = 1
	host.picker.picked.emit(TitleScreen.LOOK_HAIR)
	await wait_frames(2)
	assert_eq(look[TitleScreen.LOOK_HAIR], 1)
	host.picker.picked.emit(TitleScreen.LOOK_DONE)
	await wait_frames(2)
	assert_eq(res, [true])

# --- Items 28, 52: privacy note -----------------------------------------------------------

func test_privacy_note_is_short_with_more() -> void:
	assert_eq(TitleScreen.PRIVACY_SHORT.count(". "), 1, "short")
	assert_lt(TitleScreen.PRIVACY_SHORT.length(), AccountMenu.PRIVACY_NOTE.length() / 3)
	var rows: Array[Dictionary] = TitleScreen.privacy_rows()
	assert_eq(rows.size(), 2)
	assert_eq(str(rows[1].text), "More")

func test_long_info_text_shows_a_more_arrow() -> void:
	var stage := Control.new()
	stage.size = Vector2(144, 256)
	add_child_autofree(stage)
	var host := MenuHost.new()
	stage.add_child(host)
	await wait_frames(1)
	host.info(AccountMenu.PRIVACY_NOTE + "\n\n" + AccountMenu.ONLINE_RULES)
	await wait_frames(3)
	assert_gt(host.info_more_cue_rect().size.x, 0.0, "an arrow says the text goes on")
	host._close_info()
	await wait_frames(1)
	host.info("Short.")
	await wait_frames(3)
	assert_eq(host.info_more_cue_rect().size.x, 0.0, "no arrow when it all fits")
	host._close_info()

# --- Item 45: Skip clear of the text ------------------------------------------------------

func test_skip_never_covers_the_story_text_and_fits_its_word() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	sp.play("t", {"steps": [{"say": ["A valley of lakes and terraces, drawn and redrawn by its cartographers."]}]})
	await wait_frames(3)
	var b: Button = sp.skip_button()
	assert_not_null(b)
	for lang: String in ["en", "de", "fr", "nl", "ru", "ja", "ko"]:
		Loc.set_language(lang)
		await wait_frames(2)
		sp.place_skip_button()
		await wait_frames(1)
		var text_w: float = b.get_theme_font("font").get_string_size(Loc.t("Skip"), HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		assert_gte(b.size.x, text_w, "%s: Skip is as wide as its word" % lang)
		assert_false(b.get_global_rect().intersects(ow.text_box().get_global_rect()), "%s: Skip is off the text box" % lang)
		assert_true(Rect2(Vector2.ZERO, b.get_viewport_rect().size).encloses(b.get_global_rect()), "%s: Skip is on screen" % lang)
	sp.skip()
	for i: int in 240:
		if not ow.scene_running:
			break
		await wait_frames(1)
	sp.queue_free()

# --- Item 30: chapter cards can be skipped ------------------------------------------------

func test_chapter_card_ends_on_skip() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	var done: Array = []
	var run := func() -> void:
		await sp.play("chapter_card", {"skippable": true, "steps": [{"card": "Chapter 1: The Map House"}]})
		done.append(true)
	var start: int = Time.get_ticks_msec()
	run.call()
	await wait_frames(4)
	assert_not_null(sp.skip_button(), "the card has Skip")
	sp.skip()
	for i: int in 120:
		if not done.is_empty():
			break
		await wait_frames(1)
	assert_eq(done, [true])
	assert_lt(Time.get_ticks_msec() - start, int(ScenePlayer.CARD_TIME * 1000.0), "ended before the card time")
	assert_string_contains(FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd"), "sp.play(\"chapter_card\", {\"skippable\": true")
	sp.queue_free()

# --- Items 31, 32, 34, 35, 36 -------------------------------------------------------------

func test_first_battle_starts_with_the_energy_tip_only() -> void:
	assert_eq(Tips.battle_start_tip(true, false), "battle")
	Tips.take("battle")
	assert_eq(Tips.battle_start_tip(true, false), "bond", "bonding waits for the next wild battle")
	assert_eq(Tips.battle_start_tip(false, true), "multi")
	Tips.take("bond")
	Tips.take("multi")
	assert_eq(Tips.battle_start_tip(true, true), "")

func test_partner_pick_shows_the_three_partners() -> void:
	var head: Control = Overworld.starter_header()
	autofree(head)
	assert_eq(head.get_child_count(), Database.STARTERS.size())
	for c: Node in head.get_children():
		assert_not_null((c as TextureRect).texture)
	for r: Dictionary in Overworld.starter_rows():
		assert_true(r.get("icon") is Texture2D, str(r.text))
	# Since 1.3.2 the pick is bonded with Mine! (the bonding tutorial) instead of Yes or No.
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_string_contains(src, "await partner_bond(sd)")

func test_fast_text_is_free() -> void:
	Billing.state = {"unlocks": {}}
	assert_true(ShopEffects.owns_setting("fast_text"))
	assert_eq(MenuHost.next_text_speed(GameState.TextSpeed.NORMAL), GameState.TextSpeed.FAST)

func test_bond_call_says_what_to_tap() -> void:
	assert_string_contains(BondMinigame.first_call_hint(true), "tap")
	assert_string_contains(BondMinigame.first_call_hint(false), "press")

func test_name_takes_letters_of_every_script() -> void:
	for ch: String in ["A", "ä", "Ж", "я", "あ", "カ", "한", "名", "ğ"]:
		assert_true(NameKeyboard.name_letter(ch), ch)
	for ch: String in ["_", "1", "-", " ", "!", "@"]:
		assert_false(NameKeyboard.name_letter(ch), ch)
	var edit := LineEdit.new()
	edit.max_length = NameBox.MAX
	add_child_autofree(edit)
	var keys := NameKeyboard.new()
	keys.target = edit
	add_child_autofree(keys)
	for ch: String in ["М", "и", "ш", "а"]:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		assert_true(keys.type_key(ev), ch)
	assert_eq(edit.text, "Миша")
	assert_not_null(keys.make_extra_row().get_child(0), "a key opens the phone's own keyboard")

func test_new_texts_are_translated() -> void:
	var texts: Array[String] = [TitleScreen.HAVE_CODE, TitleScreen.PRIVACY_SHORT,
		Overworld.STARTER_STAY_LINE, Opening.MEET_LINE, Opening.ALDO_LINE, NameBox.TITLE, NameKeyboard.SYSTEM_KEYS, "Random"]
	texts.append_array(TitleScreen.LOOK_ROWS)
	texts.append_array(BondMinigame.FIRST_CALL_HINT.values())
	texts.append_array(_storm_lines())
	for lang: String in Loc.LANGUAGES:
		if lang == "en":
			continue
		Loc.set_language(lang)
		for t: String in texts:
			assert_ne(Loc.t(t), t, "%s: %s" % [lang, t])

# --- Item 54 / 1.3.1: an "ellipsis" row still ends in "...", every other long row wraps ------

func test_continue_row_wraps_and_ellipsis_rows_stay_one_line() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_frames(1)
	var run := func() -> void: await host.pick("", [{"text": "Continue  Brindlewick Lighthouse", "ellipsis": true}, {"text": "Continue  Brindlewick Lighthouse"}] as Array[Dictionary], false)
	run.call()
	await wait_frames(2)
	var cut: Button = host.picker._buttons[0]
	var wrapped: Button = host.picker._buttons[1]
	assert_eq(cut.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_true(cut.clip_text)
	assert_eq(wrapped.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	assert_false(wrapped.clip_text, "a long row is never cut")
	assert_eq(wrapped.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_false(FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd").contains("entries[0][\"ellipsis\"] = true"),
		"the Continue row shows the whole place name")
	host.picker.picked.emit(-1)
	await wait_frames(1)

func test_version_label_sits_under_the_list() -> void:
	var v: Label = TitleScreen.version_label()
	autofree(v)
	assert_eq(v.vertical_alignment, VERTICAL_ALIGNMENT_BOTTOM)
	assert_gt(TitleScreen.VERSION_ROOM, 0)
	assert_string_contains(FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd"), "_menu.offset_bottom = -VERSION_ROOM")
