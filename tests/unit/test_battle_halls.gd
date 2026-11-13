extends GutTest
## KAMPF_PLAN_1000, area "Endgame-Kampfmodi": battle halls (BattleHalls.gd, HallRunner.gd).

const WEEK: String = "2026-W46"

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r

func _play(mine: Array[Spirling], foes: Array[Spirling], info: Dictionary, seed_value: int) -> BattleModel:
	var m := BattleModel.new(mine, foes, false, seed_value, int(info.ai))
	m.field = str(info.get("field", ""))
	var vids: Array[String] = []
	vids.assign(info.get("variants", []))
	m.variants.assign(vids)
	var front: Array = info.get("front", [1, 1])
	m.front_size = [int(front[0]), int(front[1])]
	m.foe_boss = str(info.get("boss", ""))
	var brain := BattleAI.new(2)
	m.start()
	var turns: int = 0
	while not m.is_finished() and turns < 300:
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			acts.append(brain.choose(m, BattleModel.Side.PLAYER, slot))
		m.submit_actions(acts)
		turns += 1
	return m

func test_data_is_sound() -> void:
	var ids: Dictionary = {}
	for h: Dictionary in BattleHalls.all():
		assert_false(ids.has(h.id), "hall id twice: %s" % h.id)
		ids[h.id] = true
		assert_true(str(h.kind) in ["random", "draft", "survival", "tower", "boss", "prism"], str(h.id))
		for k: String in ["label", "intro", "title", "lore"]:
			assert_false(str(h.get(k, "")).is_empty(), "%s needs %s" % [h.id, k])
		assert_gt(int(h.get("waymarks", 0)), 0, str(h.id))
		if h.has("front"):
			for f: Variant in h.front:
				assert_between(int(f), 1, BattleRules.MAX_FRONT, str(h.id))
	for f: Variant in BattleHalls.data().fields:
		assert_true(str(f).is_empty() or BattleRules.FIELDS.has(str(f)), str(f))
	assert_lte(BattleHalls.all().size(), 36, "a run code keeps the hall in one letter")

func test_every_text_has_german() -> void:
	var t: PatternTranslation = Loc.load_translation("de")
	var texts: Array[String] = []
	for h: Dictionary in BattleHalls.all():
		for k: String in ["label", "intro", "title", "lore"]:
			texts.append(str(h[k]))
	for s: String in texts:
		var de: String = t.lookup(s)
		assert_false(de.is_empty() or de == s, "German for: " + s)

func test_same_week_same_run() -> void:
	var h: Dictionary = BattleHalls.by_id("lottery")
	var s1: int = BattleHalls.week_seed("lottery", WEEK)
	assert_eq(s1, BattleHalls.week_seed("lottery", WEEK))
	assert_ne(s1, BattleHalls.week_seed("lottery", "2026-W47"))
	var a: Array[Spirling] = BattleHalls.foe_team(h, s1, 2)
	var b: Array[Spirling] = BattleHalls.foe_team(h, s1, 2)
	assert_eq(a.size(), 3)
	for i: int in a.size():
		assert_eq(a[i].data.species_name, b[i].data.species_name)
		assert_eq(a[i].level, BattleHalls.ring(), "level scaling: every foe on the hall ring")
	var lot: Array[Spirling] = BattleHalls.lottery_team(s1)
	assert_eq(lot.size(), 3)
	assert_eq(lot[0].data.species_name, BattleHalls.lottery_team(s1)[0].data.species_name)

func test_fields_and_rules_rotate() -> void:
	var seen: Dictionary = {}
	for r: int in 7:
		seen[BattleHalls.field_for(5, r)] = true
	assert_eq(seen.size(), (BattleHalls.data().fields as Array).size(), "every field comes round in a run")
	var v: Array[String] = BattleHalls.variants_for(WEEK)
	assert_eq(v.size(), 1)
	assert_true(BattleRules.variants().has(v[0]))
	assert_eq(BattleHalls.variants_for(WEEK), v, "the rule is the same all week")

func test_level_scaling_copies_never_touch_the_team() -> void:
	var real: Spirling = GameState.party[0]
	var lvl: int = real.level
	var copies: Array[Spirling] = BattleHalls.scaled(GameState.party, 3)
	assert_eq(copies.size(), mini(3, GameState.party.size()))
	assert_eq(copies[0].level, BattleHalls.ring())
	copies[0].hp = 0
	assert_eq(real.level, lvl)
	assert_gt(real.hp, 0)

func test_draft_alternates_and_echo_takes_the_strongest() -> void:
	var h: Dictionary = BattleHalls.by_id("draft")
	var table: Array[String] = BattleHalls.draft_pool(h, 77)
	assert_eq(table.size(), int(h.pool))
	var strongest: String = BattleHalls.echo_pick(table)
	var mine: Array[String] = [table[0], table[1], table[2], table[3]]
	if strongest == table[0]:
		mine = [table[1], table[2], table[3], table[4]]
	var d: Dictionary = BattleHalls.draft(table, mine, 3)
	assert_eq(d.mine.size(), 3)
	assert_eq(d.theirs.size(), 3)
	assert_eq(d.theirs[0], strongest, "the echo picks the strongest left")
	for n: String in d.mine:
		assert_false(n in d.theirs, "no Spirling on both sides")
	var again: Dictionary = BattleHalls.draft(table, ["Nobody", table[0]] as Array[String], 3)
	assert_eq(again.mine, [table[0]], "a pick not on the table is skipped")

func test_codes_round_trip() -> void:
	var seed_value: int = BattleHalls.week_seed("survival", WEEK)
	var code: String = BattleHalls.run_code("survival", seed_value)
	assert_eq(code.length(), BattleHalls.CODE_LEN)
	assert_eq(BattleHalls.parse_run_code(NameKeyboard.pretty(code)), {"hall": "survival", "seed": seed_value})
	var broken: String = code.left(7) + ("A" if code[7] != "A" else "B")
	assert_eq(BattleHalls.parse_run_code(broken), {})
	assert_eq(BattleHalls.run_code("nope", 1), "")
	var names: Array[String] = ["Kindlop", "Puddlet", "Zephlet"]
	var tc: String = BattleHalls.team_code(names)
	assert_eq(tc.length(), BattleHalls.CODE_LEN)
	assert_eq(BattleHalls.parse_team_code(tc), names)
	assert_eq(BattleHalls.parse_team_code(tc.left(7) + ("A" if tc[7] != "A" else "B")), [] as Array[String])
	var team: Array[Spirling] = BattleHalls.code_team(names, 3)
	assert_eq(team.size(), 3)
	assert_eq(team[2].level, BattleHalls.ring())

func test_festival_cup_only_in_festivals_and_only_their_elements() -> void:
	var cup: Dictionary = BattleHalls.by_id("festival_cup")
	assert_false(BattleHalls.is_open(cup, {}))
	var fest: Dictionary = Season.festivals()[0]
	assert_true(BattleHalls.is_open(cup, fest))
	assert_true(BattleHalls.open_halls({}).all(func(h: Dictionary) -> bool: return not bool(h.get("festival", false))))
	for s: Spirling in BattleHalls.foe_team(cup, 9, 1, fest.elements):
		assert_true(s.data.elements.any(func(e: int) -> bool: return e in fest.elements), s.data.species_name)

func test_boss_and_prism_halls() -> void:
	var stair: Dictionary = BattleHalls.by_id("boss_tower")
	assert_eq(BattleHalls.rounds(stair), BattleRules.BOSSES.size())
	var bosses: Dictionary = {}
	for r: int in BattleHalls.rounds(stair):
		bosses[BattleHalls.boss_for(stair, 4, r)] = true
	assert_eq(bosses.size(), BattleRules.BOSSES.size(), "every heart once")
	assert_false(BattleHalls.heals_between(stair))
	var prism: Dictionary = BattleHalls.by_id("prism_boss")
	var foe: Array[Spirling] = BattleHalls.foe_team(prism, 4, 0)
	assert_eq(foe.size(), 1)
	assert_true(foe[0].prism)
	var info: Dictionary = BattleHalls.battle_info(prism, 4, 0, WEEK, BattleHalls.scaled(GameState.party, 3))
	assert_true(BattleRules.BOSSES.has(str(info.boss)))
	assert_true(bool(info.friendly), "an echo battle: nothing bought counts, nothing is lost")
	assert_eq(int(info.money), 0)

func test_every_kind_plays_to_an_end() -> void:
	var mine_src: Array[Spirling] = BattleHalls.lottery_team(11)
	for h: Dictionary in BattleHalls.all():
		var seed_value: int = BattleHalls.week_seed(str(h.id), WEEK)
		var mine: Array[Spirling] = BattleHalls.scaled(mine_src, BattleHalls.team_size(h))
		while mine.size() < BattleHalls.team_size(h):
			mine.append_array(BattleHalls.scaled(mine_src, 1))
		var info: Dictionary = BattleHalls.battle_info(h, seed_value, 0, WEEK, mine)
		var m: BattleModel = _play(mine, BattleHalls.foe_team(h, seed_value, 0, Season.festivals()[0].elements), info, seed_value)
		assert_true(m.is_finished(), "%s ends" % h.id)

func test_survival_keeps_damage() -> void:
	assert_false(BattleHalls.heals_between(BattleHalls.by_id("survival")))
	assert_true(BattleHalls.heals_between(BattleHalls.by_id("lottery")))

func test_finish_pays_once_a_week_and_first_clear_extras() -> void:
	var h: Dictionary = BattleHalls.by_id("lottery")
	var team: Array[String] = ["Kindlop", "Puddlet", "Zephlet"]
	var w0: int = GameState.waymarks
	var lines: Array[String] = BattleHalls.finish(h, BattleHalls.rounds(h), team, WEEK, "2026-11-13")
	assert_eq(GameState.waymarks - w0, int(h.waymarks))
	assert_true(Collection.titles().has(str(h.title)), "the title goes on the card list")
	assert_eq(BattleHalls.lore_lines().size(), 1)
	assert_eq(BattleHalls.fame_lines().size(), 1)
	assert_string_contains(BattleHalls.fame_lines()[0], "Zephlet")
	assert_gt(lines.size(), 2)
	BattleHalls.finish(h, BattleHalls.rounds(h), team, WEEK, "2026-11-13")
	assert_eq(GameState.waymarks - w0, int(h.waymarks), "the second clear of the week pays nothing")
	assert_eq(BattleHalls.fame_lines().size(), 1, "the Hall of Fame keeps first clears")
	BattleHalls.finish(h, BattleHalls.rounds(h), team, "2026-W47", "2026-11-20")
	assert_eq(GameState.waymarks - w0, 2 * int(h.waymarks))
	BattleHalls.finish(h, 2, team, "2026-W47", "2026-11-20")
	var s: Dictionary = BattleHalls.stats("lottery")
	assert_eq(int(s.runs), 4)
	assert_eq(int(s.clears), 3)
	assert_eq(int(s.best), BattleHalls.rounds(h))
	assert_eq(int(s.wins), 3 * BattleHalls.rounds(h) + 2)
	assert_eq(BattleHalls.total_clears(), 3)
	assert_eq(Achievements.stat("record:hall_clears"), 3)
	assert_eq(BattleHalls.stats_lines().size(), 1)

func test_weekly_goal() -> void:
	var g: Dictionary = BattleHalls.data().week_goal
	var w0: int = GameState.waymarks
	for i: int in int(g.wins) - 1:
		assert_eq(BattleHalls.note_win(WEEK), [] as Array[String])
	assert_false(BattleHalls.note_win(WEEK).is_empty())
	assert_eq(GameState.waymarks - w0, int(g.waymarks))
	assert_eq(BattleHalls.note_win(WEEK), [] as Array[String], "paid once a week")
	assert_string_contains(BattleHalls.week_goal_line(WEEK), "done")
	assert_eq(int(BattleHalls.week_state("2026-W47").wins), 0, "a new week starts at zero")

func test_rewards_are_never_bought() -> void:
	# No hall reward is an item or anything from the shop: Waymarks, titles, lore, fame only.
	for h: Dictionary in BattleHalls.all():
		for k: String in h.keys():
			assert_false(k in ["item", "items", "price", "riftglass", "coins"], "%s has %s" % [h.id, k])

func test_card_title_list_is_complete() -> void:
	var known: Array[String] = BattleHalls.card_titles()
	var earnable: Array[String] = []
	for h: Dictionary in BattleHalls.all():
		earnable.append(str(h.title))
	for list: Array in [Collection.GOALS, Collection.SEEN_GOALS, Collection.SET_GOALS]:
		for g: Variant in list:
			if (g as Dictionary).has("title"):
				earnable.append(str(g.title))
	for g: Variant in BattleGoals.all().values():
		var r: Variant = (g as Dictionary).get("reward", {})
		if r is Dictionary and not str(r.get("title", "")).is_empty():
			earnable.append(str(r.title))
	for t: String in earnable:
		assert_true(t in known, "card_titles misses: " + t)
	var tr: PatternTranslation = Loc.load_translation("de")
	for t: String in known:
		var de: String = tr.lookup(t)
		assert_false(de.is_empty() or de == t, "German for: " + t)

func test_wear_only_earned_titles() -> void:
	BattleHalls.wear("First Pick")
	assert_eq(BattleHalls.worn_title(), "", "not earned yet")
	BattleHalls.finish(BattleHalls.by_id("draft"), 3, ["Kindlop"] as Array[String], WEEK, "2026-11-13")
	BattleHalls.wear("First Pick")
	assert_eq(BattleHalls.worn_title(), "First Pick")
	assert_eq(Online.card_numbers().get("title"), "First Pick")
	BattleHalls.wear("")
	assert_false(Online.card_numbers().has("title"))

func test_server_keeps_only_known_titles() -> void:
	var s := LocalBackend.new()
	s.rng.seed = 1
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	var p: Dictionary = s.call_fn("profile_set", {"p_name": "Ann", "p_color": 0, "p_favorite": "", "p_card": {"title": "First Pick"}}).data
	assert_eq(p.card.get("title"), "First Pick")
	p = s.call_fn("profile_set", {"p_name": "Ann", "p_color": 0, "p_favorite": "", "p_card": {"title": "Queen of Everything"}}).data
	assert_false(p.card.has("title"), "no free text on the card")
	assert_string_contains(FriendsMenu.card_text({"name": "Ann", "code": "ABCDEFGH", "card": {"title": "First Pick"}}), "Title: First Pick")
	assert_string_contains(FriendsMenu.card_text({"name": "Ann", "code": "ABCDEFGH", "card": {}}), "Title: -")

func test_last_hall_battle_as_replay_code() -> void:
	assert_eq(BattleHalls.replay_code(), "")
	var h: Dictionary = BattleHalls.by_id("lottery")
	var mine: Array[Spirling] = BattleHalls.lottery_team(3)
	var info: Dictionary = BattleHalls.battle_info(h, 3, 0, WEEK, mine)
	var m := BattleModel.new(mine, BattleHalls.foe_team(h, 3, 0), false, 3, 3)
	m.variants.assign(info.variants)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "")
	snap["inputs"] = []
	BattleHalls.keep_replay(snap)
	var code: String = BattleHalls.replay_code()
	assert_ne(code, "")
	var back: Dictionary = ReplayLibrary.from_code(code)
	assert_false(back.is_empty())
	assert_eq(BattleReplay.problem(back), "", "the code plays back in this version")
