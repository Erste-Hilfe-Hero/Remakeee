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

# --- Plan area 1: Echo bonding (items 278-286, 437) ---------------------------------------

func _kind(rarity: String, element: int = Elements.E.EMBER, motif: Array[int] = [2, 0]) -> SpirlingData:
	var sd := SpirlingData.new()
	sd.species_name = "Testkind"
	sd.rarity = rarity
	sd.elements.assign([element])
	sd.cry_motif = motif
	return sd

func test_every_kind_has_a_cry_motif_and_the_call_opens_with_it() -> void:
	Database.load_all()
	for sname: String in Database.spirlings:
		var sd: SpirlingData = Database.spirlings[sname]
		assert_eq(sd.cry_motif.size(), 2, sname)
		assert_ne(sd.cry_motif[0], sd.cry_motif[1], sname)
		for s: int in 5:
			var plan: Dictionary = BondEcho.make_plan(_rng(s), sd)
			var first: Array = plan.phases[0]
			assert_eq([first[0], first[1]], [sd.cry_motif[0], sd.cry_motif[1]], sname)

func test_call_length_grows_with_rarity() -> void:
	assert_eq(BondEcho.call_length("common"), 4)
	assert_eq(BondEcho.call_length("uncommon"), 4)
	assert_eq(BondEcho.call_length("shy"), 5)
	assert_eq(BondEcho.call_length("ancient"), 5)
	assert_eq((BondEcho.make_plan(_rng(1), _kind("shy")).phases as Array).size(), 1)
	var ancient: Dictionary = BondEcho.make_plan(_rng(1), _kind("ancient"))
	assert_eq((ancient.phases as Array).size(), 2, "ancient kinds call a second phase")
	assert_eq((ancient.phases[1] as Array).size(), 5)

func test_open_rift_mutes_the_call_and_a_mended_one_makes_it_full() -> void:
	assert_eq(BondEcho.rift_state("brindlewick", []), "none")
	assert_eq(BondEcho.rift_state("crowcrest", []), "muted")
	assert_eq(BondEcho.rift_state("cinder_rift", []), "muted")
	assert_eq(BondEcho.rift_state("crowcrest", ["cinder"]), "mended")
	assert_eq(BondEcho.rift_state("saltmarsh", ["cinder"]), "muted")
	assert_eq(BondEcho.call_length("shy", "muted"), 3)
	assert_eq(BondEcho.call_length("common", "mended"), 4)
	var muted: Dictionary = BondEcho.make_plan(_rng(3), _kind("common"), "muted")
	assert_eq((muted.phases[0] as Array).size(), 3)
	assert_eq(muted.state, "muted")

func test_result_is_words_never_a_number() -> void:
	for v: float in [0.0, 0.25, 0.5, 0.75, 0.9, 1.0]:
		var w: String = BondEcho.result_words(v)
		assert_true(w in [BondEcho.WORD_LISTENS, BondEcho.WORD_HESITATES, BondEcho.WORD_TURNS_AWAY])
		assert_false(RegEx.create_from_string("[0-9%]").search(w) != null, "no number or chance in '%s'" % w)
	assert_eq(BondEcho.result_words(1.0), BondEcho.WORD_LISTENS)
	assert_eq(BondEcho.result_words(0.5), BondEcho.WORD_HESITATES)
	assert_eq(BondEcho.result_words(0.25), BondEcho.WORD_TURNS_AWAY)

func test_afterglow_keeps_a_flawless_echo_at_one() -> void:
	var plan: Dictionary = {"phases": [[2, 0, 1, 0]], "afterglow": 2}
	var right: Array = [[2, 0, 1, 0]]
	assert_eq(BondEcho.plan_score(plan, right, 2), 1.0)
	assert_eq(BondEcho.plan_score(plan, right, 1), BondEcho.AFTERGLOW_MISS)
	assert_eq(BondEcho.plan_score(plan, right, -1), BondEcho.AFTERGLOW_MISS)
	assert_eq(BondEcho.result_words(BondEcho.AFTERGLOW_MISS), BondEcho.WORD_LISTENS, "missing the extra mark is no failure")
	assert_eq(BondEcho.plan_score(plan, [[2, 0]], -1), 0.5, "no afterglow without a flawless echo")
	assert_eq(BondEcho.plan_score({"phases": [[2, 0, 1, 0]], "afterglow": -1}, right), 1.0)
	var two: Dictionary = {"phases": [[0, 1, 2, 1, 0], [1, 2, 0, 2, 1]], "afterglow": -1}
	assert_eq(BondEcho.plan_score(two, [[0, 1, 2, 1, 0]]), 0.5, "second phase counts half")

func test_afterglow_mark_differs_from_the_last_mark() -> void:
	var found: int = 0
	for s: int in 80:
		var plan: Dictionary = BondEcho.make_plan(_rng(s), _kind("common"))
		if int(plan.afterglow) >= 0:
			found += 1
			assert_ne(int(plan.afterglow), int((plan.phases[-1] as Array)[-1]))
	assert_between(found, 10, 50, "the afterglow comes sometimes, not always")

func test_same_plan_gives_the_same_call_on_a_second_try() -> void:
	var bm := BondMinigame.new()
	add_child_autofree(bm)
	var plan: Dictionary = BondEcho.make_plan(_rng(9), _kind("common"))
	bm._plan = plan
	bm._start_phase(0)
	var first: Array[int] = bm._sequence.duplicate()
	bm._start_phase(0)
	assert_eq(bm._sequence, first)

func test_minigame_plays_a_plan_and_shows_only_words() -> void:
	var bm := BondMinigame.new()
	add_child_autofree(bm)
	bm.size = Vector2(144, 256)
	bm._plan = {"phases": [[0, 1, 2, 1]], "afterglow": 0, "state": "mended", "sky": true, "element": Elements.E.LUMEN}
	bm._start_phase(0)
	bm._phase = BondMinigame.Phase.ECHO
	for m: int in [0, 1, 2, 1]:
		bm._tap(m)
	assert_eq(bm._phase, BondMinigame.Phase.AFTER_CALL, "a flawless echo can get an afterglow")
	bm._phase = BondMinigame.Phase.AFTER_ECHO
	bm._tap(0)
	assert_eq(bm._phase, BondMinigame.Phase.RESULT)
	assert_eq(bm._score, 1.0)
	assert_eq(bm._hint.text, BondEcho.WORD_LISTENS)

func test_lumen_and_umbra_use_moon_star_spark_with_the_same_rules() -> void:
	assert_true(BondEcho.uses_sky_marks([Elements.E.LUMEN]))
	assert_true(BondEcho.uses_sky_marks([Elements.E.UMBRA, Elements.E.EMBER]))
	assert_false(BondEcho.uses_sky_marks([Elements.E.TIDE]))
	for i: int in BondEcho.MARKS:
		var pts: PackedVector2Array = BondMinigame.mark_points(i, Vector2(50, 50), 13.0, true)
		assert_gt(Geometry2D.triangulate_polygon(pts).size(), 0, "mark %d is a drawable shape" % i)
		assert_ne(pts, BondMinigame.mark_points(i, Vector2(50, 50), 13.0, false))
	var sky: Dictionary = BondEcho.make_plan(_rng(4), _kind("common", Elements.E.UMBRA))
	assert_true(sky.sky)
	assert_eq(BondEcho.MARKS, 3, "still three marks")

func test_each_element_has_its_own_scale() -> void:
	assert_eq(Sound.ELEMENT_SCALES.size(), Elements.E.size())
	var seen: Dictionary = {}
	for e: int in Elements.E.size():
		var notes: Array = [Sound.mark_note(e, 0), Sound.mark_note(e, 1), Sound.mark_note(e, 2)]
		assert_false(seen.has(str(notes)), "element %d sounds different" % e)
		seen[str(notes)] = true
	assert_gt(Cry.tone(60).data.size(), 0)

func test_legal_bonding_stays_free_of_throws_aims_circles_and_odds() -> void:
	var legal: String = FileAccess.get_file_as_string("res://LEGAL.md")
	assert_true(legal.contains("Echo bonding (plan area 1)"), "LEGAL.md keeps the Echo bonding note")
	var code: String = FileAccess.get_file_as_string("res://scripts/battle/BondEcho.gd") \
		+ FileAccess.get_file_as_string("res://scripts/battle/presenter/BondMinigame.gd")
	for banned: String in ["throw", "aim", "shrink", "chance %", "odds:"]:
		assert_false(code.to_lower().contains(banned + "("), "no '%s' mechanic" % banned)
	for w: String in [BondEcho.WORD_LISTENS, BondEcho.WORD_HESITATES, BondEcho.WORD_TURNS_AWAY]:
		assert_false(w.contains("%"))
