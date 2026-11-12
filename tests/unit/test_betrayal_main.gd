extends GutTest
## Main-story betrayals of Acts I to IV (docs/STORY.md "Main-story betrayals", data/clans.json
## betrayals with "main", "trust_choices", data/dialogue/betrayal.json): at least three betrayals
## and two trust choices on the critical path per act, and every trust choice changes the outcome.

const ON_ENTER: Dictionary = {
	"brindlewick": ["a1_square", {"aldo_dock_told": true}, "ferry_crossed"],
	"cinderfold": ["a3_cinderfold", {"rift_glass_sealed": true}, "rift_shade_sealed"],
	"saltglass": ["a3_saltglass", {"veit_plate_done": true}, "rift_sun_sealed"],
	"ochrewell": ["a4_ochrewell", {"rift_shade_sealed": true}, "rift_oasis_sealed"],
	"oasis_rift": ["a4_oasis", {"rift_tower_sealed": true}, "rift_oasis_sealed"],
	"sun_rift": ["a4_sun", {"rift_oasis_sealed": true}, "rift_sun_sealed"],
}

func before_each() -> void:
	Database.load_all()
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 0, Database.STARTERS[0], 1)

func _main_betrayals() -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in Trust.data().betrayals:
		if Trust.betrayal(str(id)).has("main"):
			out[str(id)] = Trust.betrayal(str(id))
	return out

## Flags and story vars after picking [param c] (its "flag", "set_flag" and "trust" actions).
func _pick(c: Dictionary) -> Array[Dictionary]:
	var flags: Dictionary = {}
	var vars: Dictionary = {}
	if c.has("flag"):
		flags[str(c.flag)] = true
	for one: String in str(c.get("action", "")).split(";", false):
		var p: PackedStringArray = one.strip_edges().split(" ", false)
		if p.size() >= 3 and p[0] == "trust":
			var eff: Dictionary = {"trust": {p[1]: int(p[2])}}
			if p.size() > 3:
				eff["use"] = {p[1]: int(p[3])}
			Trust.apply_values(eff, vars)
		elif p.size() >= 2 and p[0] == "set_flag":
			flags[p[1]] = true
	var out: Array[Dictionary] = [flags, vars]
	return out

## Applies the effects of [param result] of betrayal [param id] to flags and vars.
func _cash(id: String, result: String, flags: Dictionary, vars: Dictionary) -> void:
	var eff: Dictionary = Trust.effects(Trust.betrayal(id), result)
	Trust.apply_values(eff, vars)
	for f: Variant in eff.get("flags", []):
		flags[str(f)] = true

func _scene_has_action(scene: String, action: String) -> bool:
	for st: Variant in ScenePlayer.load_scene(scene).get("steps", []):
		if str((st as Dictionary).get("action", "")).split(";").has(action):
			return true
	return false

func _scene_has_dialogue(scene: String, ref: String) -> bool:
	for st: Variant in ScenePlayer.load_scene(scene).get("steps", []):
		if str((st as Dictionary).get("dialogue", "")) == ref:
			return true
	return false

func test_three_main_betrayals_per_act() -> void:
	var per_act: Dictionary = {}
	for id: String in _main_betrayals():
		var a: int = int(_main_betrayals()[id].act)
		per_act[a] = int(per_act.get(a, 0)) + 1
	for act: int in range(1, 5):
		assert_gte(int(per_act.get(act, 0)), 3, "act %d main-story betrayals" % act)

func test_main_betrayals_fire_in_their_scene() -> void:
	for id: String in _main_betrayals():
		var scene: String = str(_main_betrayals()[id].main)
		assert_true(ScenePlayer.exists(scene), "%s: scene %s" % [id, scene])
		assert_true(_scene_has_action(scene, "betrayal " + id), "%s fires in %s" % [id, scene])

func test_main_scenes_are_on_the_critical_path() -> void:
	for map_id: String in ON_ENTER:
		var row: Array = ON_ENTER[map_id]
		var flags: Dictionary = row[1]
		assert_eq(StoryPlacements.enter_scene(map_id, flags), str(row[0]), map_id)
		var later: Dictionary = flags.duplicate()
		later[str(row[2])] = true
		assert_eq(StoryPlacements.enter_scene(map_id, later), "", "%s: old saves past it skip the scene" % map_id)
		later = flags.duplicate()
		later[ScenePlayer.seen_flag(str(row[0]))] = true
		assert_eq(StoryPlacements.enter_scene(map_id, later), "", "%s plays once" % map_id)

func test_scenes_with_tests_that_skip_them_stay_free_of_choices() -> void:
	# The prologue, the lamp and the Act I finale are played skipped in test_story_engine; a
	# choice there would wait for a tap.
	for id: String in ["prologue", "mirela_lamp", "act1_finale"]:
		for st: Variant in ScenePlayer.load_scene(id).steps:
			assert_false(str((st as Dictionary).get("dialogue", "")).begins_with("betrayal/"), id)

func test_two_trust_choices_per_act_on_the_critical_path() -> void:
	var where: Dictionary = {
		"betrayal/a1_report": "lighthouse/aldo_dock", "betrayal/a1_hour": "a1_square",
		"betrayal/a2_porter": "corvane_arrival", "betrayal/a2_chalk": "wide_rift_reveal",
		"betrayal/a3_seal": "ashmere_arrival", "betrayal/a3_copper": "a3_cinderfold",
		"betrayal/a4_letter": "a4_ochrewell", "betrayal/a4_tunnel": "a4_oasis"}
	var per_act: Dictionary = {}
	for id: Variant in Trust.data().trust_choices:
		var tc: Dictionary = Trust.data().trust_choices[id]
		per_act[int(tc.act)] = int(per_act.get(int(tc.act), 0)) + 1
		var at: String = str(tc.at)
		assert_eq(Dialogue.get_entry(at).get("choices", []).size(), 2, at)
		assert_true(where.has(at), "%s has a known place" % at)
		var host: String = str(where.get(at, ""))
		if host.contains("/"):
			assert_eq(str(Dialogue.get_entry(host).get("next", "")), at, host)
		else:
			assert_true(_scene_has_dialogue(host, at), "%s plays in %s" % [at, host])
	for act: int in range(1, 5):
		assert_gte(int(per_act.get(act, 0)), 2, "act %d trust choices" % act)

func test_every_trust_choice_changes_its_betrayal() -> void:
	for id: Variant in Trust.data().trust_choices:
		var tc: Dictionary = Trust.data().trust_choices[id]
		var choices: Array = Dialogue.get_entry(str(tc.at)).choices
		var b: String = str(tc.decides[0])
		var results: Array[String] = []
		for c: Variant in choices:
			var st: Array[Dictionary] = _pick(c)
			results.append(Trust.betrayal_result(Trust.betrayal(b), st[0], st[1]))
		assert_true(results.has("caught") and results.has("struck"), "%s decides %s: %s" % [id, b, results])
		# Trusting is the answer that changes a hidden value; it never protects you here.
		for i: int in choices.size():
			if str((choices[i] as Dictionary).get("action", "")).begins_with("trust "):
				assert_eq(results[i], "struck", "%s: trusting is punished" % id)

func test_struck_costs_and_caught_pays() -> void:
	for id: String in _main_betrayals():
		var b: Dictionary = _main_betrayals()[id]
		var struck: Dictionary = Trust.effects(b, "struck")
		var caught: Dictionary = Trust.effects(b, "caught")
		assert_true(int(struck.get("coins", 0)) < 0 or bool(struck.get("take_keepsake", false)), "%s struck costs something" % id)
		assert_true(int(caught.get("coins", 0)) > 0 or caught.has("item"), "%s caught pays something" % id)
		for r: Dictionary in [struck, caught]:
			assert_true(Dialogue.exists(str(r.get("say", ""))), "%s says something" % id)
			assert_true(r.has("ledger"), "%s goes into the Ledger" % id)

func test_free_betrayal_flags_14_to_25() -> void:
	var set_by: Dictionary = {}
	for id: String in _main_betrayals():
		for r: String in ["caught", "struck"]:
			for f: Variant in Trust.effects(_main_betrayals()[id], r).get("flags", []):
				if str(f).begins_with("clan_b"):
					set_by[str(f)] = set_by.get(str(f), []) + [id]
	for n: int in range(14, 26):
		var by: Array = set_by.get("clan_b%d" % n, [])
		assert_false(by.is_empty(), "clan_b%d is set" % n)
		assert_eq(Array(by).filter(func(x: String) -> bool: return x != by[0]).size(), 0, "clan_b%d belongs to one betrayal" % n)

func test_bills_never_take_the_purse_below_zero() -> void:
	assert_eq(Trust.money_after(500, -200), 300)
	assert_eq(Trust.money_after(100, -300), 0)
	assert_eq(Trust.money_after(10, 150), 160)

func test_trusting_juna_in_act1_costs_you_in_act4() -> void:
	var tc: Dictionary = Trust.data().trust_choices.a1_report
	var outcomes: Dictionary = {}
	for c: Variant in Dialogue.get_entry(str(tc.at)).choices:
		var st: Array[Dictionary] = _pick(c)
		var flags: Dictionary = st[0]
		var vars: Dictionary = st[1]
		var post: String = Trust.betrayal_result(Trust.betrayal("juna_post"), flags, vars)
		_cash("juna_post", post, flags, vars)
		outcomes[str((c as Dictionary).get("flag", "trust"))] = [post, Trust.betrayal_result(Trust.betrayal("juna_letter"), flags, vars)]
	assert_eq(outcomes.get("a1_cipher"), ["caught", "caught"], "the code protects you twice")
	assert_eq(outcomes.get("trust"), ["struck", "struck"], "Juna sells you twice")

func test_pips_secret_carries_from_act1_to_act3() -> void:
	# Covering up Pip's duel (trust_pip +15) makes him warn you about the guild clerk; that
	# warning keeps Ottilie's copy of your route worthless in Act III.
	for pair: Array in [[15, "caught"], [-20, "struck"], [0, "struck"]]:
		var flags: Dictionary = {}
		var vars: Dictionary = {"trust_pip": pair[0]}
		var charter: String = Trust.betrayal_result(Trust.betrayal("ysolde_charter"), flags, vars)
		assert_eq(charter, pair[1], "pip %d" % pair[0])
		_cash("ysolde_charter", charter, flags, vars)
		assert_eq(Trust.betrayal_result(Trust.betrayal("ottilie_route"), flags, vars), pair[1], "route, pip %d" % pair[0])

func test_reading_fenricks_letter_saves_the_lantern() -> void:
	var b: Dictionary = Trust.betrayal("fenrick_lantern")
	assert_eq(Trust.betrayal_result(b, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(b, {"c1_read_letter": true}, {}), "caught")
	assert_eq(Trust.betrayal_result(b, {"c1_aldra_warned": true}, {}), "caught")

func test_sables_porters_make_her_tip_a_trap() -> void:
	var porters: Dictionary = Dialogue.get_entry("betrayal/a2_porter").choices[0]
	var st: Array[Dictionary] = _pick(porters)
	var sable: Dictionary = Trust.favor("sable_tip")
	assert_ne(Trust.resolve(sable, Trust.trust_in("sable", {}), Trust.use_in("sable", {}), 0.9), "betray")
	assert_eq(Trust.resolve(sable, Trust.trust_in("sable", st[1]), Trust.use_in("sable", st[1]), 0.9), "betray")

func test_aldo_asks_about_the_report_only_once() -> void:
	var e: Dictionary = Dialogue.get_entry("betrayal/a1_report")
	assert_true(Dialogue.check(e.get("if"), {}))
	assert_false(Dialogue.check(e.get("if"), {"a1_report_done": true}))
	assert_false(Dialogue.check(e.get("if"), {"scene_ferry_crossing_seen": true}), "old saves past the ferry")

func test_main_betrayal_data_and_scenes_are_valid() -> void:
	assert_eq(Trust.validate(), PackedStringArray())
	var bad: PackedStringArray = []
	for e: String in StoryValidator.validate():
		if e.contains("betrayal") or e.contains("a1_") or e.contains("a3_") or e.contains("a4_"):
			bad.append(e)
	assert_eq(bad, PackedStringArray())
	for e: Variant in Trust.data().ledger:
		if str(e.ref).begins_with("betrayal/"):
			assert_gte(Trust.ledger_text(str(e.ref)).size(), 2, str(e.id))
