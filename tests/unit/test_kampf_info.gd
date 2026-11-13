extends GutTest
## Battle plan areas "Info und Transparenz" and "Bedienung und Komfort" (docs/KAMPF_PLAN_1000.md):
## log filter, battle facts, art card lines, previews in lists, remembered art and target, the
## 1-4 keys, the end report and the new tips (scripts/battle/BattleInfo.gd).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _duel(mine: Spirling, foe: Spirling) -> BattleModel:
	return BattleFixtures.model([mine] as Array[Spirling], [foe] as Array[Spirling])

# --- Log filter (565) ---

func test_log_filter_sorts_lines_by_kind_and_side() -> void:
	var hit := BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "name": "Mossling", "amount": 7})
	var burn := BattleEvent.new(BattleEvent.Type.STATUS_APPLIED, {"side": 0, "name": "Kindlop", "status": "scorch"})
	var start := BattleEvent.new(BattleEvent.Type.SEND_OUT, {"side": 0, "name": "Kindlop"})
	assert_eq(BattleInfo.kind_of(hit), "hits")
	assert_eq(BattleInfo.kind_of(burn), "status")
	assert_eq(BattleInfo.kind_of(start), "other")
	var entries: Array = [BattleInfo.entry(start), BattleInfo.entry(hit), BattleInfo.entry(burn)]
	assert_eq(BattleInfo.filter_lines(entries, "all", 14).size(), 3)
	assert_eq(BattleInfo.filter_lines(entries, "hits", 14), [hit.describe()] as Array[String])
	assert_eq(BattleInfo.filter_lines(entries, "status", 14), [burn.describe()] as Array[String])
	assert_eq(BattleInfo.filter_lines(entries, "foe", 14), [hit.describe()] as Array[String])
	assert_eq(BattleInfo.filter_lines(entries, "mine", 14).size(), 2)
	assert_eq(BattleInfo.filter_lines(entries, "all", 1), [burn.describe()] as Array[String], "keeps the newest")

func test_log_filter_cycles_back_to_everything() -> void:
	var f: String = "all"
	for i: int in BattleInfo.FILTERS.size():
		assert_true(BattleInfo.FILTER_LABELS.has(f), f)
		f = BattleInfo.next_filter(f)
	assert_eq(f, "all")
	assert_string_contains(BattleInfo.filter_row("hits"), "Hits")

# --- Foe arts and facts (566, 567, 573-575, 579, 600) ---

func test_foe_arts_become_known_once_used() -> void:
	var m: BattleModel = _duel(BattleFixtures.make("Kindlop", 12, ["Bowl Over"]), BattleFixtures.make("Mossling", 12, ["Bowl Over"]))
	var seen: Dictionary = {}
	assert_string_contains(BattleInfo.facts(m, seen), "Arts seen: none yet")
	for e: BattleEvent in m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0)):
		BattleInfo.note(seen, e)
	assert_eq(BattleInfo.seen_arts(seen, 0), ["Bowl Over"])
	var facts: String = BattleInfo.facts(m, seen)
	assert_string_contains(facts, "Arts seen: Bowl Over")
	assert_string_contains(facts, "Mossling R12")
	assert_string_contains(facts, "Seed %d" % m.battle_seed)

func test_player_arts_are_not_noted_as_foe_arts() -> void:
	var seen: Dictionary = {}
	BattleInfo.note(seen, BattleEvent.new(BattleEvent.Type.MOVE_USED, {"side": 0, "index": 0, "move": "Bowl Over"}))
	assert_true(seen.is_empty())

func test_facts_show_trait_only_after_it_showed() -> void:
	var foe: Spirling = BattleFixtures.make("Wickit", 15)
	var m: BattleModel = _duel(BattleFixtures.make("Mossling", 15), foe)
	var label: String = str(BattleRules.trait_info(foe.gift_id()).get("label", "?"))
	assert_false(BattleInfo.facts(m, {}).contains("Trait: "))
	m.apply_status(1, "drowse")
	assert_string_contains(BattleInfo.facts(m, {}), "Trait: " + label)

func test_field_status_cap_and_bench_lines() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 12)
	var m: BattleModel = _duel(me, BattleFixtures.make("Mossling", 12))
	var fid: String = BattleRules.FIELDS.keys()[0]
	var label: String = str(BattleRules.FIELDS[fid].get("label", fid))
	m.field = fid
	m.field_turns = 3
	assert_eq(BattleInfo.field_line(m), "Field: %s, 3 turns left" % label)
	m.field_turns = 0
	assert_eq(BattleInfo.field_line(m), "Field: %s" % label)
	me.status = "scorch"
	me.status_turns = 2
	assert_string_contains(BattleInfo.status_line(me), "2 turns left")
	m.level_cap = 20
	m.bench_share = 0.5
	var facts: String = BattleInfo.facts(m, {})
	assert_string_contains(facts, "Ring limit 20")
	assert_string_contains(facts, "learns 50% as much")
	assert_string_contains(facts, "Field: ")

# --- Art card (571, 572) ---

func test_order_hint_follows_priority_and_pace() -> void:
	var fast: Spirling = BattleFixtures.from_species(BattleFixtures.balanced_species(90, [Elements.E.EMBER]), 20)
	var slow: Spirling = BattleFixtures.from_species(BattleFixtures.balanced_species(40, [Elements.E.TIDE]), 20)
	var plain: MoveData = BattleFixtures.move(Elements.E.EMBER, 50)
	var m: BattleModel = _duel(fast, slow)
	assert_eq(BattleInfo.order_hint(m, fast, slow, plain), "first")
	assert_eq(BattleInfo.order_hint(m, slow, fast, plain), "after")
	assert_eq(BattleInfo.order_hint(m, slow, slow, plain), "even")
	var quick: MoveData = BattleFixtures.move(Elements.E.EMBER, 40)
	quick.priority = 1
	assert_eq(BattleInfo.order_hint(m, slow, fast, quick), "first", "an art that acts first beats Pace")
	assert_eq(BattleInfo.order_hint(m, slow, null, plain), "hidden")

func test_card_lines_name_order_and_energy_left() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 12, ["Bowl Over"])
	var m: BattleModel = _duel(me, BattleFixtures.make("Mossling", 12))
	var mv: MoveData = me.moves[0]
	assert_eq(BattleInfo.energy_after(me, mv), maxi(me.energy - me.move_cost(mv), 0))
	var lines: Array[String] = BattleInfo.card_lines(m, 0, mv)
	assert_eq(lines.size(), 2)
	assert_true(BattleInfo.ORDER_TEXT.values().has(lines[0]))
	assert_eq(lines[1], "Energy after: %d" % BattleInfo.energy_after(me, mv))
	me.energy = 0
	assert_eq(BattleInfo.card_lines(m, 0, mv).size(), 1, "no Energy line when it can't be paid")

# --- Previews in lists (563, 625) ---

func test_target_preview_needs_a_known_matchup() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 12, ["Bowl Over"])
	var foe: Spirling = BattleFixtures.make("Mossling", 12)
	var m: BattleModel = _duel(me, foe)
	var mv: MoveData = me.moves[0]
	var keep: Dictionary = Billing.state
	Billing.state = {"unlocks": {"damage_preview": 1}}
	assert_eq(BattleInfo.target_preview(m, me, foe, mv), "", "unknown matchup")
	GameState.learn_matchup(mv.element, "Mossling", 1.0)
	assert_eq(BattleInfo.target_preview(m, me, foe, mv), " ~%d%%" % CommandMenu.damage_pct(m, me, foe, mv))
	GameState.damage_preview = false
	assert_eq(BattleInfo.target_preview(m, me, foe, mv), "", "setting off")
	GameState.damage_preview = true
	Billing.state = {"unlocks": {}}
	assert_eq(BattleInfo.target_preview(m, me, foe, mv), "", "a shop setting: not bought, no preview")
	Billing.state = keep

func test_switch_tag_shows_best_known_matchup() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 12)
	me.moves = [BattleFixtures.move(Elements.E.EMBER, 50), BattleFixtures.move(Elements.E.TIDE, 50)] as Array[MoveData]
	var foe: Spirling = BattleFixtures.make("Mossling", 12)
	assert_eq(BattleInfo.switch_tag(me, foe), "")
	GameState.learn_matchup(Elements.E.TIDE, "Mossling", 0.5)
	GameState.learn_matchup(Elements.E.EMBER, "Mossling", 2.0)
	assert_eq(BattleInfo.switch_tag(me, foe), " x2")
	assert_eq(BattleInfo.switch_tag(me, null), "")

# --- Remembered art, target, keys (603, 613, 615) ---

func test_focus_row_prefers_the_last_art_while_usable() -> void:
	assert_eq(BattleInfo.focus_row([true, true, true] as Array[bool], 2), 2)
	assert_eq(BattleInfo.focus_row([true, true, false] as Array[bool], 2), 0)
	assert_eq(BattleInfo.focus_row([false, true] as Array[bool], -1), 1)
	assert_eq(BattleInfo.focus_row([false, false] as Array[bool], 0), -1)

func test_aim_start_keeps_the_last_target() -> void:
	assert_eq(BattleInfo.aim_start([0, 1, 2] as Array[int], 2), 2)
	assert_eq(BattleInfo.aim_start([0, 2] as Array[int], 2), 1)
	assert_eq(BattleInfo.aim_start([0, 1] as Array[int], 2), 0, "fallen target: the first")

func test_number_keys_pick_arts() -> void:
	assert_eq(BattleInfo.art_key(KEY_1), 0)
	assert_eq(BattleInfo.art_key(KEY_4), 3)
	assert_eq(BattleInfo.art_key(KEY_KP_2), 1)
	assert_eq(BattleInfo.art_key(KEY_5), -1)
	assert_eq(BattleInfo.art_key(KEY_A), -1)

# --- End report (581) ---

func test_report_counts_hits_and_downs() -> void:
	var r: Dictionary = BattleInfo.new_report()
	BattleInfo.count(r, BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "amount": 12}), "Bowl Over")
	BattleInfo.count(r, BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "amount": 20, "crit": true}), "Cinder Breath")
	BattleInfo.count(r, BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 0, "amount": 9}), "Cinder Breath")
	BattleInfo.count(r, BattleEvent.new(BattleEvent.Type.FAINTED, {"side": 1}), "")
	assert_eq(int(r.dealt), 32)
	assert_eq(int(r.taken), 9)
	assert_eq(int(r.downed), 1)
	assert_eq(int(r.keen), 1)
	assert_eq(int(r.best), 20)
	var text: String = "\n".join(BattleInfo.report_lines(r, 4))
	assert_string_contains(text, "Turns: 4")
	assert_string_contains(text, "Damage dealt: 32, taken: 9")
	assert_string_contains(text, "Best hit: 20 (Cinder Breath)")

func test_report_over_a_real_battle() -> void:
	var m: BattleModel = _duel(BattleFixtures.make("Kindlop", 30, ["Bowl Over"]), BattleFixtures.make("Mossling", 3, ["Bowl Over"]))
	var r: Dictionary = BattleInfo.new_report()
	for i: int in 10:
		if m.is_finished():
			break
		for e: BattleEvent in m.submit_turn(BattleAction.make_move(0, 0)):
			BattleInfo.count(r, e, "Bowl Over")
	assert_true(m.is_finished())
	assert_gt(int(r.dealt), 0)
	assert_eq(int(r.downed), 1)

# --- Tips (585, 631) ---

func test_new_battle_tips_are_short_and_in_the_guide() -> void:
	for id: String in ["resonance", "boss_phase", "battle_comfort"]:
		assert_true(Tips.LINES.has(id), id)
		assert_true(Tips.TOPICS.has(id), id)
		assert_between(Tips.lines_of(id, true).size(), 1, Tips.MAX_LINES, id)
	assert_eq(BattleInfo.tip_for(BattleEvent.new(BattleEvent.Type.FIELD, {})), "resonance")
	assert_eq(BattleInfo.tip_for(BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {})), "boss_phase")
	assert_eq(BattleInfo.tip_for(BattleEvent.new(BattleEvent.Type.DAMAGE, {})), "")

func test_new_texts_have_german() -> void:
	Loc.set_language("de")
	assert_eq(Loc.t("Battle facts"), "Kampfwissen")
	assert_eq(Loc.t("Energy after: %d") % 3, "Energie danach: 3")
	Loc.set_language("en")
