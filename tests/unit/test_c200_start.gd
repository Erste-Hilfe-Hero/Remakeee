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

