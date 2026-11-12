extends GutTest
## Act I side content: bounty boards, Hush coins, rival Jinks, the Pawn Vault and the side
## side goals (owner rule: 20 h per act, tools/act_hours.py).

var bounties: Dictionary

func before_all() -> void:
	Database.load_all()
	bounties = JSON.parse_string(FileAccess.get_file_as_string("res://data/act1_boards.json"))

func _choice_actions(ref: String) -> Array:
	var out: Array = []
	for page: String in [ref, ref + "_p1", ref + "_p2"]:
		for c: Variant in Dialogue.get_entry(page).get("choices", []):
			out.append(str((c as Dictionary).get("action", "")))
	return out

func test_every_bounty_is_a_story_duel_on_its_board() -> void:
	for id: String in bounties.boards:
		var b: Dictionary = bounties.boards[id]
		var acts: Array = _choice_actions(str(b.npc))
		for sid: Variant in b.bounties:
			assert_true(StoryBattles.has(str(sid)), str(sid))
			assert_has(acts, "battle " + str(sid))
			var def: Dictionary = StoryBattles.get_def(str(sid))
			assert_true(Dialogue.exists(str(def.defeat)), str(def.defeat))
			assert_true(Dialogue.exists(str(def.lose)), str(def.lose))
		var last: Dictionary = StoryBattles.get_def(str(b.bounties[-1]))
		assert_has(last.get("win_flags", []), str(b.done), "the last bounty closes the board")

func test_last_bounty_opens_after_the_others() -> void:
	var b: Dictionary = bounties.boards.brindlewick
	var flags: Dictionary = {}
	var page: Dictionary = Dialogue.get_entry(str(b.npc) + "_p2")
	var ids: Array = Dialogue.choices_for(page, flags).map(func(c: Dictionary) -> String: return str(c.id))
	assert_eq(ids, ["b3", "no"])
	for sid: Variant in b.bounties.slice(0, 3):
		flags[StoryBattles.beaten_flag(str(sid))] = true
	ids = Dialogue.choices_for(page, flags).map(func(c: Dictionary) -> String: return str(c.id))
	assert_eq(ids, ["b4", "no"])

func test_every_hush_coin_is_a_hidden_find() -> void:
	var found: Dictionary = {}
	for id: String in MapData.all_ids():
		for s: Dictionary in MapData.load_map(id).secrets:
			found[str(s.flag)] = id
	for c: Variant in bounties.collections.hush_coins.items:
		assert_true(found.has(str(c)), str(c))
	assert_true(Dialogue.check(Dialogue.get_entry("veydal_side/wicka_paid").get("if"), _all_true(bounties.collections.hush_coins.items)))

func _all_true(list: Array) -> Dictionary:
	var d: Dictionary = {}
	for f: Variant in list:
		d[str(f)] = true
	return d

func test_rival_jinks_turns_up_in_order() -> void:
	var seen: Array = []
	for id: String in ["fernstair", "crowcrest", "brackwater_fen"]:
		for n: Dictionary in MapData.load_map(id).npcs:
			if str(n.id).begins_with("vs_jinks_"):
				seen.append(str(n.hide_flag))
	assert_eq(seen, ["beat_story_rival_jinks_1", "beat_story_rival_jinks_2", "beat_story_rival_jinks_3"])
	assert_has(StoryBattles.get_def("rival_jinks_3").win_flags, "rival_jinks_done")

func test_pawn_vault_has_three_floors_and_a_boss() -> void:
	var m: MapData = MapData.load_map("pawn_vault")
	assert_eq(m.region, "veydal")
	assert_not_null(MapData.load_map("pawn_vault@2"))
	var boss: Array = MapData.load_map("pawn_vault@2").npcs.filter(func(n: Dictionary) -> bool: return n.has("win_flags"))
	assert_eq(boss.size(), 1)
	assert_has(boss[0].win_flags, "vault_done")
	var door: Array = MapData.load_map("thornridge").warps.filter(func(w: Dictionary) -> bool: return str(w.to) == "pawn_vault")
	assert_eq(door.size(), 1)

func test_story_check_is_clean() -> void:
	var mine: Array = Array(StoryValidator.validate()).filter(func(e: String) -> bool: return e.contains("veydal_side") or e.contains("jinks") or e.contains("bounty_"))
	assert_eq(mine, [])

func test_new_npcs_talk() -> void:
	for id: String in MapData.all_ids():
		for n: Dictionary in MapData.load_map(id).npcs:
			if str(n.get("dialogue", "")).begins_with("veydal_side/"):
				assert_true(Dialogue.exists(str(n.dialogue)), "%s: %s" % [id, n.dialogue])

func test_act_one_side_goals_exist() -> void:
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var ids: Array = q.side.map(func(g: Dictionary) -> String: return str(g.id))
	for id: String in ["vault", "rival_jinks", "bounty_brindle", "bounty_thorn", "debts", "parcel", "funeral", "hush_coins"]:
		assert_has(ids, id)
