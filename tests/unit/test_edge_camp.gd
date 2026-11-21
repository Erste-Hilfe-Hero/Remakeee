extends GutTest
## Plan 2: the strangers from the map's edge in their camp at the Wide Rift. Placement that grows
## with each act, own sprites, one side goal per figure with no dead end, the betrayal branches,
## six duels, the gift from the other map and a closing talk for everyone.

const FIGURES: Array[String] = ["elma", "aldra", "amir", "farida", "heider", "kenan", "leith", "lejla",
	"lipka", "mirza", "nail"]
const SPRITES: Array[String] = ["stranger", "stranger_hat", "stranger_runner", "stranger_kid"]

func before_all() -> void:
	Database.load_all()

func _camp() -> Dictionary:
	var out: Dictionary = {}
	for n: Dictionary in MapData.load_map("wide_rift_edge").npcs:
		if str(n.id).begins_with("edge_"):
			out[str(n.id).trim_prefix("edge_")] = n
	return out

func test_all_eleven_stand_in_the_camp_in_their_own_clothes() -> void:
	var camp: Dictionary = _camp()
	for f: String in FIGURES:
		assert_true(camp.has(f), f)
		assert_has(SPRITES, str(camp[f].sprite), f)
		assert_eq(str(camp[f].dialogue), "edge_camp/" + f)
	for s: String in SPRITES:
		for era: int in [1, 2]:
			assert_true(FileAccess.file_exists("res://art/era%d/chars/%s.png" % [era, s]), "%s era %d" % [s, era])

func test_the_camp_grows_with_each_act() -> void:
	var by_flag: Dictionary = {}
	for n: Dictionary in _camp().values():
		by_flag[str(n.show_flag)] = int(by_flag.get(str(n.show_flag), 0)) + 1
	assert_eq(int(by_flag.get("edge_camp_met", 0)), 5, "Act II")
	assert_eq(int(by_flag.get("act2_end", 0)), 3, "Act III")
	assert_eq(int(by_flag.get("rift_shade_sealed", 0)), 3, "Act IV")

func test_first_meeting_plays_on_arrival_in_act_two() -> void:
	var on: Dictionary = StoryPlacements.for_map("wide_rift_edge").get("on_enter", {})
	assert_eq(str(on.scene), "edge_camp")
	assert_true(ScenePlayer.exists("edge_camp"))
	var lines: Array[String] = Dialogue.lines_for(Dialogue.get_entry("edge_camp/arrive_elma"), {})
	assert_true(lines.any(func(l: String) -> bool: return l.contains("Our map is going blank too")))

func test_town_figures_use_the_new_sheets() -> void:
	for mid: Variant in StoryPlacements.data():
		for n: Variant in StoryPlacements.for_map(str(mid)).get("npcs", []):
			var id: String = str((n as Dictionary).get("id", ""))
			if id.begins_with("clan_") and id.trim_prefix("clan_") in FIGURES:
				assert_has(SPRITES, str(n.sprite), id)

func test_act_four_clan_figures_reach_ochrewell() -> void:
	var ids: Array[String] = []
	for n: Dictionary in MapData.load_map("ochrewell").npcs:
		ids.append(str(n.id))
	for id: String in ["clan_ottilie_4", "clan_fenrick_4", "clan_sable_4", "clan_kerr"]:
		assert_has(ids, id)

func test_one_side_goal_per_figure_and_the_gift() -> void:
	var goals: Dictionary = {}
	for g: Variant in QuestLog.data().get("side", []):
		goals[str((g as Dictionary).id)] = g
	for f: String in FIGURES:
		assert_true(goals.has("edge_" + f), f)
		assert_eq(str(goals["edge_" + f].done), "edge_%s_done" % f)
	assert_eq((goals["edge_gift"].progress as Array).size(), 11)

func test_every_done_flag_is_set_by_its_figure_line() -> void:
	# No dead end (plan item 189): each done flag is set by an entry or answer in edge_camp.
	var data: Dictionary = Dialogue.file_data("edge_camp")
	var set_flags: Dictionary = {}
	for k: Variant in data:
		if data[k] is Dictionary:
			set_flags[str(data[k].get("flag", ""))] = true
			for c: Variant in data[k].get("choices", []):
				set_flags[str((c as Dictionary).get("flag", ""))] = true
	for f: String in FIGURES:
		assert_true(set_flags.has("edge_%s_done" % f), f)

func test_every_figure_has_a_closing_talk() -> void:
	for f: String in FIGURES:
		# Kenan's closing talk is his rematch offer after the finale.
		var e: Dictionary = Dialogue.get_entry("edge_camp/" + ("kenan_r" if f == "kenan" else f))
		assert_string_contains(JSON.stringify(e.get("if", {})), "story_complete", f)

func test_the_gift_needs_all_eleven() -> void:
	var e: Dictionary = Dialogue.get_entry("edge_camp/elma_gift")
	var flags: Dictionary = {}
	for f: String in FIGURES:
		assert_false(Dialogue.check(e.get("if"), flags))
		flags["edge_%s_done" % f] = true
	assert_true(Dialogue.check(e.get("if"), flags))
	assert_eq(str(e.action), "gift_spirling Scrivane 40")
	assert_has(StoryValidator.known_actions(), "gift_spirling")
	assert_has(StoryValidator.known_actions(), "take_item")

func test_kenan_fights_once_per_act() -> void:
	var two: Dictionary = Dialogue.get_entry("edge_camp/kenan_2")
	assert_false(Dialogue.check(two.get("if"), {"beat_story_kenan_duel_1": true}))
	assert_true(Dialogue.check(two.get("if"), {"beat_story_kenan_duel_1": true, "act2_end": true}))
	var three: Dictionary = Dialogue.get_entry("edge_camp/kenan_3")
	assert_true(Dialogue.check(three.get("if"), {"rift_shade_sealed": true}))
	assert_false(Dialogue.check(three.get("if"), {"rift_shade_sealed": true, "beat_story_kenan_duel_3": true}))

func test_six_duels_against_the_strangers() -> void:
	for id: String in ["kenan_duel_1", "kenan_duel_2", "kenan_duel_3", "kenan_rematch", "nail_duel", "leith_trap"]:
		assert_true(StoryBattles.has(id), id)
	var lv: Array[int] = []
	for id: String in ["kenan_duel_1", "kenan_duel_2", "kenan_duel_3", "kenan_rematch"]:
		lv.append(int(StoryBattles.get_def(id).team[0].level))
	for i: int in range(1, lv.size()):
		assert_gt(lv[i], lv[i - 1], "Kenan grows stronger")
	assert_has(StoryBattles.get_def("nail_duel").get("win_flags", []), "edge_nail_1")
	assert_has(StoryBattles.get_def("silent_warden").get("win_flags", []), "edge_lejla_woke")

func test_betrayal_turns_on_hidden_trust() -> void:
	var arrow: Dictionary = Dialogue.get_entry("edge_camp/leith_arrow")
	assert_eq(int(arrow.get("if").trust_min.leith), 40)
	assert_eq(str(Dialogue.get_entry("edge_camp/leith_arrow_trap").action), "battle leith_trap")
	assert_eq(str(Dialogue.get_entry("edge_camp/aldra_pay").get("else")), "aldra_pay_low")
	assert_eq(str(Dialogue.get_entry("edge_camp/lipka_after").get("else")), "lipka_sold")
	assert_eq(str(Dialogue.get_entry("edge_camp/mirza_forge").get("else")), "mirza_lost")
	assert_string_contains(str(Dialogue.get_entry("edge_camp/amir_wait").action), "trust heider -10")
	assert_gte(Trust.ledger_text("edge_camp/ledger_farida_book").size(), 2)

func test_texts_have_german() -> void:
	for ref: String in ["edge_camp/arrive_elma", "edge_camp/kenan", "edge_camp/lipka_sold", "edge_camp/farida_guestbook"]:
		for line: String in Dialogue.lines_for(Dialogue.get_entry(ref), {}):
			assert_true(Loc.load_table("de").strings.has(line), line)
