extends GutTest
## Bond minigame "Echo call" rules (pure part).

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_sequence_has_valid_marks_and_no_direct_repeats() -> void:
	for s: int in 50:
		var seq: Array[int] = BondEcho.make_sequence(_rng(s))
		assert_eq(seq.size(), BondEcho.SEQUENCE_LENGTH)
		for i: int in seq.size():
			assert_between(seq[i], 0, BondEcho.MARKS - 1)
			if i > 0:
				assert_ne(seq[i], seq[i - 1])

func test_sequence_is_deterministic_for_a_seed() -> void:
	assert_eq(BondEcho.make_sequence(_rng(7)), BondEcho.make_sequence(_rng(7)))

func test_mark_at_follows_the_call_and_its_gaps() -> void:
	var seq: Array[int] = [2, 0, 1, 0]
	assert_eq(BondEcho.mark_at(seq, 0.0), 2)
	assert_eq(BondEcho.mark_at(seq, BondEcho.SHOW_TIME + BondEcho.GAP_TIME / 2.0), -1)
	assert_eq(BondEcho.mark_at(seq, BondEcho.SHOW_TIME + BondEcho.GAP_TIME + 0.01), 0)
	assert_eq(BondEcho.mark_at(seq, BondEcho.call_duration() + 0.1), -1)
	assert_eq(BondEcho.mark_at(seq, -0.1), -1)

func test_score_counts_the_correct_prefix() -> void:
	var seq: Array[int] = [2, 0, 1, 0]
	assert_eq(BondEcho.score(seq, [2, 0, 1, 0] as Array[int]), 1.0)
	assert_eq(BondEcho.score(seq, [2, 0] as Array[int]), 0.5)
	assert_eq(BondEcho.score(seq, [2, 1, 1, 0] as Array[int]), 0.25)
	assert_eq(BondEcho.score(seq, [] as Array[int]), 0.0)
	assert_eq(BondEcho.score([] as Array[int], [1] as Array[int]), 0.0)

func test_on_track_stops_at_first_mistake() -> void:
	var seq: Array[int] = [2, 0, 1, 0]
	assert_true(BondEcho.is_on_track(seq, [2, 0] as Array[int]))
	assert_false(BondEcho.is_on_track(seq, [2, 1] as Array[int]))
	assert_false(BondEcho.is_on_track(seq, [2, 0, 1, 0, 0] as Array[int]))

func test_legal_pages_split_long_text_without_losing_words() -> void:
	var text: String = LegalInfo.licence_text()
	var pages: PackedStringArray = LegalInfo.pages(text)
	assert_gt(pages.size(), 1)
	for p: String in pages:
		assert_lte(p.length(), LegalInfo.PAGE_CHARS)
	assert_eq(" ".join(pages).split(" ", false).size(), text.split(" ", false).size())
