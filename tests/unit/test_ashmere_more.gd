extends GutTest
## Ashmere side content, part two (Act III toward 20 h of real content,
## tools/art/world/ashmere_more.py): Clinker Heath, the Ash Assize with its five jurors, the
## Bellows Deep, the tally tags, the portraits, and the Act III betrayals of the court and the Deep.

const DEEP: Array[String] = ["bellows_deep", "bellows_deep@1", "bellows_deep@2"]
const GOALS: Array[String] = ["ah_assize", "ah_briony", "ah_mourner", "ah_tags", "ah_last_shift",
	"ah_portraits", "ah_deeds", "ah_deep", "ah_juno"]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _goal(id: String) -> Dictionary:
	for g: Variant in QuestLog.data().get("side", []):
		if str((g as Dictionary).id) == id:
			return g
	return {}

func _npc(map_id: String, id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == id:
			return n
	return {}

func test_heath_opens_south_of_cinderfold_once_halvard_is_met() -> void:
	var heath: MapData = MapData.load_map("clinker_heath")
	assert_not_null(heath)
	assert_eq(heath.region, "ashmere")
	assert_true(heath.outdoor)
	assert_eq(heath.encounter_table, "clinker_heath")
	var town: MapData = MapData.load_map("cinderfold")
	var cut: Array = town.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == "clinker_heath")
	assert_eq(cut.size(), 2)
	for w: Dictionary in cut:
		var lock: Array = town.blocks.filter(func(b: Dictionary) -> bool: return int(b.x) == int(w.x) and int(b.y) == int(w.y))
		assert_eq(lock.size(), 1)
		assert_eq(str(lock[0].open_flag), "halvard_met")
	var ways: Dictionary = {}
	for w: Dictionary in heath.warps:
		ways[str(MapData.split_id(str(w.to))[0])] = true
	assert_eq(ways.keys().size(), 3, "Cinderfold, the Assize and the Deep")
	assert_eq(WorldValidator.validate(), PackedStringArray())

func test_deep_is_three_floors_of_ashmere_kinds() -> void:
	for mid: String in DEEP:
		var m: MapData = MapData.load_map(mid)
		assert_not_null(m, mid)
		assert_eq(m.encounter_table, "bellows_deep", mid)
	for t: String in ["clinker_heath", "bellows_deep"]:
		for sp: Variant in EncounterTable.table(t).spawns:
			var sd: SpirlingData = Database.species(str((sp as Dictionary).species))
			assert_eq(sd.region, "ashmere", "%s: %s" % [t, sp.species])
	assert_eq(WorldValidator.check_rarity_weights(), PackedStringArray())

func test_evolved_kinds_are_not_met_below_their_ring() -> void:
	var ring_of: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		for u: Dictionary in sd.unfold:
			if str(u.get("rule", "")) == "ring":
				ring_of[(u.to as SpirlingData).species_name] = int(u.value)
	for t: String in ["clinker_heath", "bellows_deep"]:
		for sp: Variant in EncounterTable.table(t).spawns:
			var name: String = str((sp as Dictionary).species)
			assert_gte(int(sp.min), int(ring_of.get(name, 0)), "%s: %s" % [t, name])

func test_bellows_rows_open_the_stairs() -> void:
	var steps: Dictionary = {}
	for mid: String in DEEP:
		for s: Dictionary in MapData.load_map(mid).signs:
			var action: String = str(Dialogue.get_entry(str(s.dialogue)).get("action", ""))
			if action.begins_with("bell "):
				var p: PackedStringArray = action.split(" ")
				assert_eq(p[4], "bellows")
				steps[p[1]] = int(p[3])
	assert_eq(steps, {"ah_bellows_1": 3, "ah_bellows_2": 4})
	assert_eq(Overworld.SWITCH_LINES["bellows"].size(), 4)
	assert_eq(GameState.press_switch("ah_bellows_1", 2, 3), GameState.SwitchResult.WRONG, "out of order starts over")
	for n: int in [1, 2, 3]:
		assert_eq(GameState.press_switch("ah_bellows_1", n, 3), GameState.SwitchResult.SOLVED if n == 3 else GameState.SwitchResult.STEP)

func test_five_jurors_then_the_verdict() -> void:
	var jurors: Dictionary = {}
	for n: Dictionary in MapData.load_map("clinker_heath").npcs:
		var f: String = str(n.get("beaten_flag", ""))
		if f.begins_with("ah_juror_"):
			assert_true(TrainerData.is_trainer(n), f)
			jurors[f] = true
	assert_eq(jurors.size(), 5)
	assert_eq((_goal("ah_assize").progress as Array).size(), 5)
	var votes: Dictionary = Dialogue.get_entry("ashmere_more/greaves_votes")
	var flags: Dictionary = {"ah_assize_asked": true}
	for f: String in jurors:
		assert_false(Dialogue.check(votes.get("if"), flags), "the verdict waits for all five votes")
		flags[f] = true
	assert_true(Dialogue.check(votes.get("if"), flags))
	assert_eq(str(votes.action), "betrayal greaves_verdict")

func test_two_betrayals_and_an_alibi() -> void:
	var warn: Dictionary = {"greaves_verdict": "ah_docket_read", "juno_split": "ah_juno_note"}
	for id: String in warn:
		var def: Dictionary = Trust.betrayal(id)
		assert_eq(int(def.get("act", 0)), 3, id)
		assert_eq(Trust.betrayal_result(def, {}, {}), "struck", id)
		assert_eq(Trust.betrayal_result(def, {warn[id]: true}, {}), "caught", id)
		assert_true(StoryBattles.has(str(Trust.effects(def, "struck").get("battle", ""))), id + " struck ends in a duel")
	assert_eq(str(Trust.figure("greaves").get("clan", "")), "ruskweber")
	assert_true(Trust.betrays(Trust.trust("briony"), Trust.use("briony")), "Briony turns the oath on you unless trusted")
	assert_false(Trust.betrays(Trust.trust("orla"), Trust.use("orla")))
	assert_true(StoryBattles.has(str(Trust.effects(Trust.favor("briony_alibi"), "betray").get("battle", ""))))
	assert_eq(Trust.validate(), PackedStringArray())

func test_the_warnings_can_be_found_before_the_trap() -> void:
	# The docket is read in the Assize, Juno's note lies on the floor above her offer.
	var docket: Dictionary = Dialogue.get_entry("ash_assize/docket")
	assert_eq(str(docket.get("flag", "")), "ah_docket_read")
	assert_false(Dialogue.check(docket.get("if"), {}), "the docket means nothing before the case")
	assert_eq(str(Dialogue.get_entry("bellows_deep/note").get("flag", "")), "ah_juno_note")
	var offer: Dictionary = _npc("bellows_deep@1", "juno_offer")
	assert_eq(str(offer.get("show_flag", "")), "beat_juno_3", "Juno comes after her third race")
	var juno: Dictionary = _npc("bellows_deep@1", "juno_4")
	assert_eq(str(juno.get("show_flag", "")), "betrayal_juno_split")
	assert_eq(str(juno.get("beaten_flag", "")), "beat_juno_4")

func test_collect_eight_tags_and_eight_kinds() -> void:
	var tags: int = 0
	for mid: String in ["clinker_heath"] + DEEP:
		for s: Dictionary in MapData.load_map(mid).signs:
			if str(s.dialogue).get_file().begins_with("tag_") and str(s.dialogue).get_file() != "tag_empty":
				tags += 1
	assert_eq(tags, 8)
	assert_eq((_goal("ah_tags").progress as Array).size(), 8)
	var kinds: Array = _goal("ah_portraits").progress
	assert_eq(kinds.size(), 8)
	var end: Dictionary = Dialogue.get_entry("ashmere_more/corwin_end")
	var flags: Dictionary = {}
	for f: Variant in kinds:
		assert_false(Dialogue.check(end.get("if"), flags))
		flags[str(f)] = true
	assert_true(Dialogue.check(end.get("if"), flags))

func test_mourner_and_last_shift_move_in_stages() -> void:
	for id: String in GOALS:
		assert_false(_goal(id).is_empty(), id)
	assert_eq((_goal("ah_mourner").stages as Array).size(), 4)
	assert_eq((_goal("ah_last_shift").stages as Array).size(), 3)
	assert_eq((_goal("ah_deeds").stages as Array).size(), 3)
	# The auction book only moves the mourner goal on at its third step.
	var book: Dictionary = Dialogue.get_entry("bellows_deep/auction")
	assert_false(Dialogue.check(book.get("if"), {}))
	GameState.set_story_var("q_ah_mourner_stage", 2)
	assert_true(Dialogue.check(book.get("if"), {}))
	GameState.set_story_var("q_ah_mourner_stage", 3)
	assert_false(Dialogue.check(book.get("if"), {}))
	# Hamm only counts as found once Orla has her tags.
	var hamm: Dictionary = Dialogue.get_entry("ashmere_more/hamm")
	GameState.set_story_var("q_ah_last_shift_stage", 0)
	assert_false(Dialogue.check(hamm.get("if"), {}))
	assert_true(Dialogue.check(hamm.get("if"), {"ah_tags_done": true}))

func test_deeds_choice_has_a_consequence() -> void:
	var e: Dictionary = Dialogue.get_entry("ashmere_more/corwin_deeds")
	var picks: Array = e.get("choices", [])
	assert_eq(picks.size(), 2)
	assert_false(str(picks[0].action).contains("battle"), "burning the deeds costs nothing but the reward")
	assert_true(str(picks[1].action).contains("battle deed_hunters"), "selling them brings the catch tax collectors")
	assert_true(StoryBattles.has("deed_hunters"))

func test_story_duels_climb_toward_slagg() -> void:
	var last: int = 0
	for id: String in ["assize_bailiffs", "briony_fence", "mercer_wake", "deed_hunters", "juno_split_trap", "deep_slagg"]:
		var top: int = 0
		for e: Variant in StoryBattles.get_def(id).team:
			assert_not_null(Database.species(str(e.species)), "%s: %s" % [id, e.species])
			top = maxi(top, int(e.level))
		assert_gte(top, last, id)
		last = top
	assert_has(StoryBattles.get_def("deep_slagg").get("win_flags", []), "ah_slagg_beaten")
	assert_has(StoryBattles.get_def("mercer_wake").get("win_flags", []), "ah_mourner_done")
