extends GutTest
## Chimora 200 list items 2 (team lead on the Continue row), 5 (which partner suits you),
## 11 (the first battle's arrow at the first art) and 17 (place pictures in Earlier saves).

const ROW_TEXT_WIDTH: int = 115

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	Loc.set_language("en")

func _width(text: String) -> float:
	return PixelFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x

# --- Item 2 -------------------------------------------------------------------------------

func test_lead_species_is_the_first_team_member() -> void:
	assert_eq(EraSaveCard.lead_species({"party": [{"species": "Zippit"}, {"species": "Kindlop"}]}), "Zippit")
	assert_eq(EraSaveCard.lead_species({"party": []}), "")
	assert_eq(EraSaveCard.lead_species({}), "")

func test_continue_icon_shows_badge_and_lead() -> void:
	var with_lead: Texture2D = EraSaveCard.continue_icon(1, "Kindlop")
	assert_eq(with_lead.get_width(), EraSaveCard.badge(1).get_width() + 2 + EraSaveCard.LEAD_SIZE)
	assert_eq(with_lead.get_height(), EraSaveCard.LEAD_SIZE)
	assert_eq(EraSaveCard.continue_icon(1, ""), EraSaveCard.badge(1), "no team: only the badge")
	assert_eq(EraSaveCard.continue_icon(1, "NoSuchKind"), EraSaveCard.badge(1))

func test_title_uses_the_continue_icon() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd")
	assert_string_contains(src, "EraSaveCard.continue_icon(")

# --- Item 5 -------------------------------------------------------------------------------

func test_each_partner_can_be_suggested() -> void:
	assert_eq(Overworld.SUIT_QUESTIONS.size(), 2)
	var hits: Dictionary = {}
	for a: int in 3:
		for b: int in 3:
			var s: int = Overworld.suit_pick([a, b] as Array[int])
			assert_between(s, 0, Database.STARTERS.size() - 1)
			hits[s] = true
	assert_eq(hits.size(), Database.STARTERS.size())

func test_matching_answers_suggest_that_partner() -> void:
	for i: int in Database.STARTERS.size():
		assert_eq(Overworld.suit_pick([i, i] as Array[int]), i, Database.STARTERS[i])

func test_the_second_answer_counts_too() -> void:
	# Warm fire (Kindlop first, Wickit second) and calm and bright: Wickit.
	assert_eq(Overworld.suit_pick([0, 2] as Array[int]), 2)
	# Warm fire and quick: a tie, the first question decides.
	assert_eq(Overworld.suit_pick([0, 1] as Array[int]), 0)

func test_the_list_is_unchanged_and_the_pick_stays_free() -> void:
	assert_eq(Overworld.starter_rows().size(), Database.STARTERS.size())
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_string_contains(src, "rows.append({\"text\": SUIT_ROW")
	assert_string_contains(src, "focus = hint")

func test_suit_texts_are_german_and_fit() -> void:
	var texts: Array[String] = [Overworld.SUIT_ROW, Overworld.SUIT_HINT, Overworld.SUIT_RESULT]
	var answers: Array[String] = []
	for q: Dictionary in Overworld.SUIT_QUESTIONS:
		texts.append(str(q.q))
		for a: Array in q.a:
			answers.append(str(a[0]))
	texts.append_array(answers)
	Loc.set_language("de")
	for t: String in texts:
		assert_ne(Loc.t(t), t, t)
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		for t: String in answers + [Overworld.SUIT_ROW]:
			assert_lte(_width(Loc.t(t)), float(ROW_TEXT_WIDTH), "%s row too wide: %s" % [lang, Loc.t(t)])

# --- Item 11 ------------------------------------------------------------------------------

func test_only_the_very_first_battle() -> void:
	assert_true(FirstArtArrow.is_first_battle({}))
	assert_true(FirstArtArrow.is_first_battle({"Kindlop": {"battles": 0}}))
	assert_false(FirstArtArrow.is_first_battle({"Kindlop": {"battles": 1}}))

func test_arrow_after_five_idle_seconds() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var b := Button.new()
	b.size = Vector2(80, 13)
	host.add_child(b)
	var arrow := FirstArtArrow.new()
	arrow.set_process(false)
	host.add_child(arrow)
	arrow.wait_for(b)
	arrow.tick(FirstArtArrow.IDLE_SECONDS - 0.1)
	assert_false(arrow.visible)
	arrow.tick(0.2)
	assert_true(arrow.visible)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	arrow._input(tap)
	assert_false(arrow.visible, "a tap hides it")
	assert_eq(arrow.idle_time(), 0.0, "and starts the wait again")
	arrow.tick(FirstArtArrow.IDLE_SECONDS)
	assert_true(arrow.visible)
	arrow.stop()
	arrow.tick(10.0)
	assert_false(arrow.visible, "no arrow once the orders are given")

func test_battle_wires_the_arrow() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/BattleScene.gd")
	assert_string_contains(src, "FirstArtArrow.is_first_battle(GameState.spirlog)")
	assert_string_contains(src, "_first_arrow.wait_for(_menu.first_art_button())")

# --- Item 17 ------------------------------------------------------------------------------

func test_place_id_from_a_summary() -> void:
	assert_eq(SaveHistoryMenu.place_id("Brindlewick  1:05"), "brindlewick")
	assert_eq(SaveHistoryMenu.place_id(SaveManager.OATH_GLYPH + " Brindlewick  1:05  40%"), "brindlewick")
	assert_eq(SaveHistoryMenu.place_id("Nowhere Land  1:05"), "")

func test_place_picture() -> void:
	var pic: Texture2D = SaveHistoryMenu.place_picture("brindlewick")
	assert_not_null(pic)
	assert_eq(Vector2i(pic.get_size()), SaveHistoryMenu.PICTURE)
	assert_null(SaveHistoryMenu.place_picture(""))

func test_rows_carry_the_picture() -> void:
	var rows: Array[Dictionary] = SaveHistoryMenu.entry_rows([{"saved_at": 0, "summary": "Brindlewick  0:05"},
		{"saved_at": 0, "summary": "Ashdown  0:01"}])
	assert_eq(rows.size(), 2)
	assert_true(rows[0].get("icon") is Texture2D)
	assert_string_contains(str(rows[0].text), "Brindlewick  0:05")
