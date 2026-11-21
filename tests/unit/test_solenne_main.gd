extends GutTest
## Act IV main storyline (data/dialogue/solenne_main.json, scenes a4_tower_gate, a4_wells,
## a4_drought, a4_north): eight main goals between the Shade Rift and the Wide Rift, three more
## betrayals with a trust choice each, the strangers on the road north, and the finale chain
## left as it was.

const FILE: String = "solenne_main"
const GOALS: Array[String] = ["sol_road", "sol_tower", "sol_council", "sol_oasis", "sol_factor", "sol_sun", "sol_reckoning", "sol_north"]
const SCENES: Array[String] = ["a4_tower_gate", "a4_wells", "a4_drought", "a4_north"]
const STRANGERS: Array[String] = ["Elma", "Aldra", "Amir", "Farida", "Heider", "Kenan", "Leith", "Lejla", "Lipka", "Mirza", "Nail"]
## Flags in play order: each goal's own flags, with the scenes a player passes on the way.
const PLAY: Array = [
	["rift_shade_sealed"], ["scene_a4_ochrewell_seen", "a4_arrived"], ["rift_tower_sealed"],
	["scene_a4_wells_seen", "a4_council_done"], ["scene_a4_oasis_seen", "rift_oasis_sealed"],
	["scene_a4_drought_seen", "a4_drought_done", "veil_factor_beaten"], ["rift_sun_sealed"],
	["c4_reckoning_done"], ["scene_a4_north_seen", "a4_north_done"]]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _main_ids() -> Array:
	return QuestLog.main_goals().map(func(g: Dictionary) -> String: return str(g.id))

func _steps(scene: String, kind: String) -> Array:
	var out: Array = []
	for st: Variant in ScenePlayer.load_scene(scene).get("steps", []):
		if (st as Dictionary).has(kind):
			out.append(str(st[kind]))
	return out

func test_act_four_has_eight_main_goals_in_order() -> void:
	var ids: Array = _main_ids()
	var at: int = ids.find("sol_road")
	assert_eq(ids.slice(at, at + 8), Array(GOALS))
	assert_eq(str(ids[at - 1]), "rift_shade", "Act IV starts after the Shade Rift")
	assert_eq(ids.slice(at + 8), ["far_end", "finale", "epi_guild", "epi_home", "epi_open"], "the finale chain is untouched")
	for g: Dictionary in QuestLog.main_goals().slice(at, at + 8):
		assert_eq(str(g.act), "Act IV: The Sun of Solenne", str(g.id))
		assert_false(str(g.where).is_empty(), str(g.id))
		assert_false((g.done as Array).is_empty(), str(g.id))

func test_goals_advance_one_by_one_as_the_story_is_played() -> void:
	var flags: Dictionary = {}
	var seen: Array = []
	for step: Array in PLAY:
		for f: String in step:
			flags[f] = true
		seen.append(str(QuestLog.current(flags).id))
	assert_eq(seen, Array(GOALS) + ["far_end"])

func test_an_old_save_past_solenne_lands_on_the_wide_rift() -> void:
	# A save from before this storyline: all twelve Rifts mended, none of the new flags.
	var flags: Dictionary = {}
	for f: String in GameState.finale_flags():
		flags[f] = true
	assert_eq(str(QuestLog.current(flags).id), "sol_reckoning")
	flags["undrawn_reached"] = true
	assert_eq(str(QuestLog.current(flags).id), "finale")
	flags["story_complete"] = true
	assert_false(str(QuestLog.current(flags).id).begins_with("sol_"))

func test_finale_still_sets_story_complete() -> void:
	assert_has(_steps("finale_5", "flag"), "story_complete")
	assert_eq(QuestLog.main_goals().filter(func(g: Dictionary) -> bool: return str(g.id) == "finale")[0].done, ["story_complete"])
	# The Undrawn still opens on the twelve seals alone: no new flag gates the finale.
	var need: Array = (Dialogue.get_entry("ashmere/undrawn_gate").get("if", {}) as Dictionary).get("flag", [])
	assert_eq(need, GameState.finale_flags())

func test_scenes_play_on_arrival_in_story_order() -> void:
	var flags: Dictionary = {"rift_shade_sealed": true}
	assert_eq(StoryPlacements.enter_scene("tower_rift", flags), "a4_tower_gate")
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "a4_ochrewell")
	flags["scene_a4_ochrewell_seen"] = true
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "", "nothing until the Tower is mended")
	flags["rift_tower_sealed"] = true
	assert_eq(StoryPlacements.enter_scene("tower_rift", flags), "", "the gate scene is over once Aurelio is beaten")
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "a4_wells")
	flags["scene_a4_wells_seen"] = true
	flags["scene_a4_oasis_seen"] = true
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "")
	flags["rift_oasis_sealed"] = true
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "a4_drought")
	flags["scene_a4_drought_seen"] = true
	flags["rift_sun_sealed"] = true
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "")
	assert_eq(StoryPlacements.enter_scene("saltglass", flags), "", "the road north waits for the reckoning")
	flags["c4_reckoning_done"] = true
	assert_eq(StoryPlacements.enter_scene("saltglass", flags), "a4_north")
	flags["undrawn_reached"] = true
	assert_eq(StoryPlacements.enter_scene("saltglass", flags), "")

func test_old_saves_skip_scenes_whose_choice_they_never_saw() -> void:
	# Mid-act saves from before this storyline: the oasis mended without the council scene.
	var flags: Dictionary = {"rift_shade_sealed": true, "scene_a4_ochrewell_seen": true, "rift_tower_sealed": true,
		"scene_a4_oasis_seen": true, "rift_oasis_sealed": true}
	assert_eq(StoryPlacements.enter_scene("ochrewell", flags), "", "no vote is cashed in that was never asked for")

func test_every_goal_flag_is_set_by_a_scene_or_a_duel() -> void:
	var settable: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://data/scenes"):
		for fl: String in _steps(f.get_basename(), "flag"):
			settable[fl] = true
	for w: String in ["tower", "oasis", "sun"]:
		settable["rift_%s_sealed" % w] = true
	for id: Variant in StoryBattles.data():
		for wf: Variant in StoryBattles.get_def(str(id)).get("win_flags", []):
			settable[str(wf)] = true
	for g: Dictionary in QuestLog.main_goals():
		if str(g.id) in GOALS:
			for f: Variant in g.done:
				assert_true(settable.has(str(f)), "%s: %s" % [g.id, f])

func test_three_new_betrayals_each_decided_by_a_trust_choice() -> void:
	var pairs: Dictionary = {"a4_water": ["leith_water", "a4_tower_gate", "a4_wells"],
		"a4_vote": ["ottilie_vote", "a4_wells", "a4_drought"], "a4_oath": ["emrys_oath", "a4_drought", "a4_north"]}
	for id: String in pairs:
		var tc: Dictionary = Trust.data().trust_choices[id]
		var b: Dictionary = Trust.betrayal(str(pairs[id][0]))
		assert_eq(tc.decides, [pairs[id][0]], id)
		assert_eq(int(b.act), 4, id)
		assert_has(_steps(str(pairs[id][1]), "dialogue"), str(tc.at), "%s is asked in %s" % [id, pairs[id][1]])
		assert_eq(str(b.main), str(pairs[id][2]), id)
		assert_has(_steps(str(b.main), "action"), "betrayal " + str(pairs[id][0]), "%s is cashed in later" % id)
		var choices: Array = Dialogue.get_entry(str(tc.at)).choices
		assert_eq(choices.size(), 2, id)
		assert_true(str(choices[0].action).begins_with("trust "), "%s: the first answer trusts" % id)
		assert_eq(Trust.betrayal_result(b, {}, {}), "struck", "%s: trusting is punished" % id)
		assert_eq(Trust.betrayal_result(b, {str(choices[1].flag): true}, {}), "caught", "%s: caution pays" % id)
		assert_lt(int(Trust.effects(b, "struck").coins), 0, id)
		assert_true(int(Trust.effects(b, "caught").get("coins", 0)) > 0 or Trust.effects(b, "caught").has("item"), id)
	assert_eq(Trust.validate(), PackedStringArray())

func test_scene_duels_sit_in_the_act_four_band() -> void:
	# The band is the one the three Solenne Wardens and the Veil's story duels already use.
	var duels: Array = []
	for s: String in SCENES:
		duels.append_array(_steps(s, "battle"))
	assert_eq(duels, ["well_bailiff", "veil_pump_guards", "guild_proctor"])
	var last: int = 0
	for id: String in duels:
		var def: Dictionary = StoryBattles.get_def(id)
		assert_true(Dialogue.exists(str(def.defeat)) and Dialogue.exists(str(def.lose)), id)
		var top: int = 0
		for e: Variant in def.team:
			assert_not_null(Database.species(str(e.species)), "%s: %s" % [id, e.species])
			assert_between(int(e.level), 35, 41, id)
			top = maxi(top, int(e.level))
		assert_gte(top, last, "%s does not drop below the duel before it" % id)
		last = top

func test_three_wardens_and_eleven_strangers_are_on_the_road_north() -> void:
	var text: String = ""
	for ref: String in _steps("a4_north", "dialogue"):
		text += " ".join(PackedStringArray(Dialogue.lines_for(Dialogue.get_entry(ref), {}))) + " "
	for w: String in ["Aurelio:", "Kaia:", "Emrys:"]:
		assert_string_contains(text, w)
	for s: String in STRANGERS:
		assert_string_contains(text, s)
	# The reckoning's three endings each change one line at the border stone.
	var clans: Dictionary = Dialogue.get_entry(FILE + "/north_clans")
	var plain: Array[String] = Dialogue.lines_for(clans, {})
	for f: String in ["c4_end_burn", "c4_end_guild", "c4_end_keep"]:
		assert_ne(Dialogue.lines_for(clans, {f: true}), plain, f)

func test_story_check_is_clean() -> void:
	var mine: Array = Array(StoryValidator.validate()).filter(func(e: String) -> bool: return e.contains(FILE) or e.contains("a4_"))
	assert_eq(mine, [])
	for s: String in SCENES:
		assert_true(ScenePlayer.exists(s), s)

func test_older_act_one_side_goals_name_their_place() -> void:
	var where: Dictionary = {}
	for g: Dictionary in QuestLog.data().get("side", []):
		where[str(g.id)] = str(g.get("where", ""))
	for id: String in ["pages", "spar", "fern", "hollow", "lamps", "fisher", "hiker", "reedcutter", "marsh_tag", "swarm",
			"cinder_heart", "tide_heart", "mist_heart"]:
		assert_false(str(where.get(id, "")).is_empty(), id)
