extends GutTest
## More Act I side content (data/dialogue/veydal_more.json, owner rule: 20 h of real content per
## act, tools/act_hours.py): the Shatterfloor strike, the widow's tonic, Jinks' last bet, the
## Copperfold bounty board, the wanted posters and the burnt ledger. Every goal can be picked up
## from a figure standing in Veydal, and every flag a goal reads is set somewhere.

const FILE: String = "veydal_more"
const GOALS: Array[String] = ["strike", "widow", "jinks_bet", "bounty_copper", "wanted_posters", "burnt_ledger"]

var boards: Dictionary

func before_all() -> void:
	Database.load_all()
	boards = JSON.parse_string(FileAccess.get_file_as_string("res://data/act1_boards.json"))

func before_each() -> void:
	GameState.reset()

func _goals() -> Dictionary:
	var out: Dictionary = {}
	for g: Dictionary in QuestLog.data().get("side", []):
		out[str(g.id)] = g
	return out

## Every flag the new content can set: dialogue flags (entries and answers), story duel wins,
## favor and betrayal effects, and hidden finds.
func _set_flags() -> Dictionary:
	var out: Dictionary = {}
	var d: Dictionary = Dialogue.file_data(FILE)
	for k: Variant in d:
		var e: Dictionary = Dialogue.normalize(d[k])
		if e.has("flag"):
			out[str(e.flag)] = true
		for c: Variant in e.get("choices", []):
			if (c as Dictionary).has("flag"):
				out[str(c.flag)] = true
	for id: Variant in StoryBattles.data():
		out[StoryBattles.beaten_flag(str(id))] = true
		for f: Variant in StoryBattles.get_def(str(id)).get("win_flags", []):
			out[str(f)] = true
	for kind: String in ["favors", "betrayals"]:
		for id: Variant in Trust.data().get(kind, {}):
			var def: Dictionary = Trust.data()[kind][id]
			for r: String in ["betray", "reward", "kept", "caught", "struck"]:
				for f: Variant in (def.get(r, {}) as Dictionary).get("flags", []):
					out[str(f)] = true
	for mid: String in MapData.all_ids():
		for s: Dictionary in MapData.load_map(mid).secrets:
			out[str(s.flag)] = true
	return out

## Map id -> npcs whose talk starts in veydal_more.
func _figures() -> Dictionary:
	var out: Dictionary = {}
	for mid: String in MapData.all_ids():
		for n: Dictionary in MapData.load_map(mid).npcs:
			if str(n.get("dialogue", "")).begins_with(FILE + "/"):
				out[str(n.dialogue).get_file()] = {"map": mid, "npc": n}
	return out

func test_goals_exist_in_act_one_places() -> void:
	var goals: Dictionary = _goals()
	for id: String in GOALS:
		assert_true(goals.has(id), id)
	assert_eq((goals.wanted_posters.progress as Array).size(), 8)
	assert_eq((goals.strike.stages as Array).size(), 3)
	assert_eq((goals.widow.stages as Array).size(), 2)

func test_every_goal_flag_is_set_somewhere() -> void:
	var set: Dictionary = _set_flags()
	var goals: Dictionary = _goals()
	for id: String in GOALS:
		var g: Dictionary = goals[id]
		assert_true(set.has(str(g.show)), "%s show %s" % [id, g.show])
		assert_true(set.has(str(g.done)), "%s done %s" % [id, g.done])
		for f: Variant in g.get("progress", []):
			assert_true(set.has(str(f)), "%s progress %s" % [id, f])

func test_every_goal_can_be_picked_up_in_veydal() -> void:
	var figs: Dictionary = _figures()
	var set: Dictionary = _set_flags()
	var givers: Dictionary = {"strike": "haskett", "widow": "odette", "jinks_bet": "jinks_4", "bounty_copper": "sprocket",
		"wanted_posters": "gorrie", "burnt_ledger": "crane"}
	var goals: Dictionary = _goals()
	for id: String in givers:
		var ref: String = givers[id]
		assert_true(figs.has(ref), "%s: %s stands on a map" % [id, ref])
		if not figs.has(ref):
			continue
		var m: MapData = MapData.load_map(str(figs[ref].map))
		assert_eq(m.region, "veydal", ref)
		var n: Dictionary = figs[ref].npc
		if n.has("show_flag"):
			assert_true(set.has(str(n.show_flag)), "%s appears once %s is set" % [ref, n.show_flag])
		assert_eq(str(Dialogue.get_entry(FILE + "/" + ref).get("flag", "")), str(goals[id].show), "%s opens %s" % [ref, id])

func test_new_figures_talk_and_story_check_is_clean() -> void:
	for ref: String in _figures():
		assert_true(Dialogue.exists(FILE + "/" + ref), ref)
	var mine: Array = Array(StoryValidator.validate()).filter(func(e: String) -> bool: return e.contains(FILE))
	assert_eq(mine, [])
	assert_eq(Trust.validate(), PackedStringArray())

func test_strike_choices_follow_the_proof() -> void:
	var dory: Dictionary = Dialogue.get_entry(FILE + "/dory")
	var ids: Callable = func(flags: Dictionary) -> Array:
		return Dialogue.choices_for(dory, flags).map(func(c: Dictionary) -> String: return str(c.id))
	assert_eq(ids.call({"q_strike_asked": true}), ["proof", "haskett", "miners"])
	assert_eq(ids.call({"q_strike_asked": true, "strike_proof": true}), ["haskett", "miners"])
	assert_has(StoryBattles.get_def("strike_dory").win_flags, "strike_broke")
	assert_false(Dialogue.check(dory.get("if"), {"q_strike_asked": true, "strike_miners": true}), "one side only")

func test_trust_choices_change_the_betrayals() -> void:
	# Reading Haskett's ledger first gets real coin instead of scrip.
	var scrip: Dictionary = Trust.betrayal("haskett_scrip")
	assert_eq(Trust.betrayal_result(scrip, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(scrip, {"strike_proof": true}, {}), "caught")
	# Giving the miners' hat back keeps Dory from selling the mine.
	var sale: Dictionary = Trust.betrayal("dory_sale")
	var vars: Dictionary = {}
	assert_eq(Trust.betrayal_result(sale, {}, vars), "struck")
	Trust.apply_values({"trust": {"dory": 20}}, vars)
	assert_eq(Trust.betrayal_result(sale, {}, vars), "caught")
	# Pocketing the widow's label is the only defence against her delivery slip.
	var slip: Dictionary = Trust.betrayal("odette_slip")
	assert_eq(Trust.betrayal_result(slip, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(slip, {"widow_read_label": true}, {}), "caught")
	for id: String in ["haskett_scrip", "dory_sale"]:
		assert_eq(int(Trust.betrayal(id).act), 1, id)

func test_jinks_sells_you_unless_you_bought_him_a_drink() -> void:
	var def: Dictionary = Trust.favor("jinks_stake")
	assert_eq(str(def.kind), "lend_coins")
	var vars: Dictionary = {}
	assert_eq(Trust.resolve(def, Trust.trust_in("jinks", vars), Trust.use_in("jinks", vars), 0.0), "betray")
	Trust.apply_values({"trust": {"jinks": 20}}, vars)
	assert_ne(Trust.resolve(def, Trust.trust_in("jinks", vars), Trust.use_in("jinks", vars), 0.0), "betray")
	var drink: Array = (Dialogue.get_entry(FILE + "/jinks_5").choices as Array).filter(func(c: Dictionary) -> bool: return str(c.get("action", "")) == "trust jinks 20")
	assert_eq(drink.size(), 1)
	for r: String in ["betray", "reward", "kept"]:
		assert_has(Trust.effects(def, r).get("flags", []), "jinks_bet_done", r)

func test_copperfold_board_opens_its_last_bounty_last() -> void:
	var b: Dictionary = boards.boards.copperfold
	var page: Dictionary = Dialogue.get_entry(str(b.npc) + "_p2")
	var flags: Dictionary = {}
	var ids: Array = Dialogue.choices_for(page, flags).map(func(c: Dictionary) -> String: return str(c.id))
	assert_eq(ids, ["b11", "no"])
	for sid: Variant in b.bounties.slice(0, 3):
		flags[StoryBattles.beaten_flag(str(sid))] = true
	ids = Dialogue.choices_for(page, flags).map(func(c: Dictionary) -> String: return str(c.id))
	assert_eq(ids, ["b12", "no"])

func test_every_wanted_poster_is_a_hidden_find_in_veydal() -> void:
	var found: Dictionary = {}
	for id: String in MapData.all_ids():
		for s: Dictionary in MapData.load_map(id).secrets:
			found[str(s.flag)] = MapData.load_map(id).region
	var items: Array = boards.collections.wanted_posters.items
	assert_eq(items.size(), 8)
	var all: Dictionary = {}
	for f: Variant in items:
		assert_true(found.has(str(f)), str(f))
		all[str(f)] = true
	var paid: Dictionary = Dialogue.get_entry(FILE + "/gorrie_paid")
	assert_true(Dialogue.check(paid.get("if"), all))
	all.erase(items[0])
	assert_false(Dialogue.check(paid.get("if"), all), "seven posters are not enough")

func test_ledger_accusation_needs_all_three_clues() -> void:
	var e: Dictionary = Dialogue.get_entry(FILE + "/crane_2")
	assert_false(Dialogue.check(e.get("if"), {"ledger_clue_tibbs": true, "ledger_clue_fay": true}))
	assert_true(Dialogue.check(e.get("if"), {"ledger_clue_tibbs": true, "ledger_clue_fay": true, "ledger_clue_page": true}))
	assert_eq((e.choices as Array).size(), 3)
	assert_has(StoryBattles.get_def("ledger_crane").win_flags, "ledger_done")

func test_new_duels_use_known_spirlings_inside_act_one() -> void:
	for id: String in ["strike_dory", "strike_prawle", "widow_odette", "widow_lemuel", "rival_jinks_4", "jinks_ambush",
			"bounty_b9", "bounty_b10", "bounty_b11", "bounty_b12", "ledger_crane"]:
		assert_true(StoryBattles.has(id), id)
		for e: Variant in StoryBattles.get_def(id).team:
			assert_not_null(Database.species(str(e.species)), "%s: %s" % [id, e.species])
			assert_lte(int(e.level), GameState.LEVEL_CAPS[2], id)
