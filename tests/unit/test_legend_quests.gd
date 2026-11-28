extends GutTest
## Lore quest chains of the six legendary Spirlings (LegendQuests, data/legend_quests.json):
## guide -> inscription + witness -> back to the guide -> betrayal -> the legend waits. Bond
## rules for a wild legend, and the shop copies (pay-to-win step 2) next to the journey ones.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _npc(map_id: String, id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == id:
			return n
	return {}

func _entry(sp: String, part: String) -> Dictionary:
	return Dialogue.get_entry("legend_quests/%s_%s" % [sp.to_lower(), part])

func test_one_chain_per_legend_and_data_is_valid() -> void:
	assert_eq(LegendQuests.species_list().size(), 6)
	for sp: String in FirstVoices.LEGENDS:
		assert_false(LegendQuests.chain(sp).is_empty(), sp)
	assert_eq(LegendQuests.validate(), PackedStringArray())
	var story: PackedStringArray = []
	for e: String in StoryValidator.validate():
		if e.contains("legend_quests") or e.contains("lq_"):
			story.append(e)
	assert_eq(story, PackedStringArray())

func test_guide_witness_and_inscription_are_placed_and_gated() -> void:
	for sp: String in LegendQuests.species_list():
		var c: Dictionary = LegendQuests.chain(sp)
		var guide: Dictionary = _npc(str(c.guide.map), str(c.guide.npc))
		assert_eq(guide.get("show_flag"), str(FirstVoices.LEGENDS[sp].opens), sp)
		assert_eq(guide.get("hide_flag"), LegendQuests.flag(sp, "ready"), sp)
		var witness: Dictionary = _npc(str(c.witness.map), str(c.witness.npc))
		assert_eq(witness.get("show_flag"), LegendQuests.flag(sp, "met"), sp)
		assert_eq(witness.get("hide_flag"), LegendQuests.flag(sp, "ready"), sp)
		var lore: MapData = MapData.load_map(str(c.lore.map))
		var ins: Dictionary = lore.sign_at(Vector2i(int(c.lore.x), int(c.lore.y)), {LegendQuests.flag(sp, "met"): true})
		assert_eq(str(ins.get("dialogue", "")), "legend_quests/%s_lore" % sp.to_lower(), sp)
		assert_true(lore.sign_at(Vector2i(int(c.lore.x), int(c.lore.y)), {}).is_empty(), "%s: inscription only during the quest" % sp)
		# The legend itself only waits once the chain is over.
		var meet: Dictionary = _npc(str(FirstVoices.LEGENDS[sp].map), sp.to_lower())
		assert_eq(meet.get("show_flag"), LegendQuests.flag(sp, "ready"), sp)

func test_dialogue_runs_guide_lore_witness_guide() -> void:
	for sp: String in LegendQuests.species_list():
		var f: Callable = func(step: String) -> String: return LegendQuests.flag(sp, step)
		var intro: Dictionary = _entry(sp, "guide_intro")
		assert_eq(str(intro.flag), f.call("met"), sp)
		assert_eq(str(intro.action), "quest_stage %s 1" % LegendQuests.quest_id(sp), sp)
		var wait: Dictionary = _entry(sp, "guide_wait")
		assert_false(Dialogue.check(wait.get("if"), {}), sp)
		assert_true(Dialogue.check(wait.get("if"), {f.call("met"): true}), sp)
		assert_eq(str(_entry(sp, "lore").flag), f.call("lore1"), sp)
		assert_eq(str(_entry(sp, "witness").flag), f.call("lore2"), sp)
		var both: Dictionary = _entry(sp, "both")
		assert_false(Dialogue.check(both.get("if"), {f.call("lore1"): true}), "%s: one piece is not enough" % sp)
		assert_true(Dialogue.check(both.get("if"), {f.call("lore1"): true, f.call("lore2"): true}), sp)
		assert_eq(str(both.action), "quest_stage %s 2" % LegendQuests.quest_id(sp), sp)
		var guide: Dictionary = _entry(sp, "guide")
		assert_false(Dialogue.check(guide.get("if"), {f.call("met"): true, f.call("lore1"): true}), sp)
		assert_true(Dialogue.check(guide.get("if"), {f.call("lore1"): true, f.call("lore2"): true}), sp)
		var picks: Array = guide.get("choices", []).map(func(ch: Dictionary) -> String: return str(ch.flag))
		assert_eq(picks, [f.call("handed"), f.call("kept")], sp)
		var twist: Dictionary = _entry(sp, "twist")
		assert_eq(str(twist.action), "betrayal " + LegendQuests.betrayal_id(sp), sp)
		assert_eq(str(twist.flag), f.call("ready"), sp)

func test_handing_over_the_relic_is_the_betrayal() -> void:
	for sp: String in LegendQuests.species_list():
		var b: Dictionary = Trust.betrayal(LegendQuests.betrayal_id(sp))
		assert_eq(Trust.betrayal_result(b, {LegendQuests.flag(sp, "handed"): true}, {}), "struck", sp)
		assert_eq(Trust.betrayal_result(b, {LegendQuests.flag(sp, "kept"): true}, {}), "caught", sp)
		var struck: Dictionary = Trust.effects(b, "struck")
		assert_eq(str(struck.battle), str(LegendQuests.chain(sp).battle), sp)
		assert_has(struck.flags, LegendQuests.flag(sp, "struck"))
		var caught: Dictionary = Trust.effects(b, "caught")
		assert_has(caught.flags, LegendQuests.flag(sp, "caught"))
		assert_false(Database.item(str(caught.item)).is_empty(), sp)
		for r: Dictionary in [struck, caught]:
			assert_gte(Trust.ledger_text("legend_quests/%s_ledger" % sp.to_lower()).size(), 2, sp)
			assert_eq(str(r.ledger), LegendQuests.betrayal_id(sp))
		var team: Array = StoryBattles.get_def(str(struck.battle)).team
		var ring: int = int(FirstVoices.LEGENDS[sp].ring)
		for e: Dictionary in team:
			assert_between(int(e.level), ring - 6, ring, "%s: the guide's team fits the legend's Ring" % sp)

func test_side_goal_follows_the_stages() -> void:
	for sp: String in LegendQuests.species_list():
		var goal: Dictionary = {}
		for g: Variant in QuestLog.data().side:
			if str((g as Dictionary).id) == LegendQuests.quest_id(sp):
				goal = g
		assert_eq(str(goal.show), str(FirstVoices.LEGENDS[sp].opens), sp)
		assert_eq(str(goal.done), LegendQuests.flag(sp, "ready"), sp)
		assert_eq((goal.stages as Array).size(), 3, sp)
		var flags: Dictionary = {str(goal.show): true}
		var ids: Array = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return str(g.id))
		assert_has(ids, goal.id)
		flags[LegendQuests.flag(sp, "ready")] = true
		ids = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return str(g.id))
		assert_does_not_have(ids, goal.id)
	GameState.set_story_var(QuestLog.stage_var({"id": "legend_monolurk"}), 2)
	var step: Dictionary = QuestLog.side_step({"id": "legend_monolurk", "stages": [{"text": "a"}, {"text": "b"}, {"text": "c"}]})
	assert_eq(str(step.text), "c")

func test_a_legend_listens_only_below_half_hp() -> void:
	var b: Dictionary = LegendQuests.data().bond
	for sp: String in LegendQuests.species_list():
		var wild := Spirling.new(Database.species(sp), int(FirstVoices.LEGENDS[sp].ring))
		assert_eq(LegendQuests.bond_factor(wild, {}), 0.0, "%s at full HP" % sp)
		assert_eq(BondCalc.chance(wild, 1.0, 0.5), 0.0, "%s: no charm helps at full HP" % sp)
		wild.hp = 1
		assert_eq(LegendQuests.bond_factor(wild, {}), 1.0, sp)
		assert_eq(LegendQuests.bond_factor(wild, {LegendQuests.flag(sp, "caught"): true}), float(b.caught_factor), sp)
		assert_eq(LegendQuests.bond_factor(wild, {LegendQuests.flag(sp, "struck"): true}), float(b.struck_factor), sp)
	assert_gt(float(b.caught_factor), 1.0, "keeping the relic earns the legend's trust")
	assert_lt(float(b.struck_factor), 1.0, "a betrayed legend is wary")
	var plain := Spirling.new(Database.species("Zippit"), 10)
	assert_eq(LegendQuests.bond_factor(plain, {}), 1.0, "other kinds are untouched")

func test_chain_outcome_changes_the_bond_chance() -> void:
	var wild := Spirling.new(Database.species("Vorlucent"), 48)
	wild.hp = 1
	var neutral: float = BondCalc.chance(wild, 1.0)
	GameState.set_flag(LegendQuests.flag("Vorlucent", "caught"))
	assert_gt(BondCalc.chance(wild, 1.0), neutral)
	GameState.set_flag(LegendQuests.flag("Vorlucent", "caught"), false)
	GameState.set_flag(LegendQuests.flag("Vorlucent", "struck"))
	assert_lt(BondCalc.chance(wild, 1.0), neutral)

func test_bond_seal_stays_certain_on_a_legend() -> void:
	var foe: Array[Spirling] = [Spirling.new(Database.species("Hallowmur"), 55)]
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 50)]
	var m: BattleModel = BattleFixtures.model(mine, foe, true, 3)
	m.inventory = {"rg_bond_seal": 1}
	m.submit_turn(BattleAction.make_bond(BattleModel.Side.PLAYER, 1.0, "rg_bond_seal"), BattleAction.make_rest(BattleModel.Side.FOE))
	assert_eq(m.outcome, BattleModel.Outcome.BONDED, "the shop's Bond Seal works at full HP too")

func test_shop_copy_is_not_the_one_met_on_the_journey() -> void:
	for sp: String in LegendQuests.species_list():
		var offer: Dictionary = ShopCatalog.offer("rg_spirling_" + sp.to_lower())
		assert_false(offer.is_empty(), "%s is still for sale" % sp)
		assert_eq(str(offer.get("store_type", "")), "non_consumable", sp)
		var bought: Spirling = ShopEffects.bought_spirling(offer.grants[0])
		assert_not_null(bought, sp)
		GameState.receive_spirling(bought)
		assert_false(FirstVoices.is_bonded(sp), "%s: a shop copy does not end the meeting" % sp)
	GameState.receive_spirling(Spirling.new(Database.species("Monolurk"), 45))
	assert_true(FirstVoices.is_bonded("Monolurk"), "the one bonded on the journey counts")

func test_quest_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	var data: Dictionary = Dialogue.file_data("legend_quests")
	var n: int = 0
	for key: Variant in data:
		if str(key).begins_with("_"):
			continue
		var e: Dictionary = data[key]
		var texts: Array = e.get("lines", []).duplicate()
		for ch: Variant in e.get("choices", []):
			texts.append(str((ch as Dictionary).text))
		for t: Variant in texts:
			n += 1
			assert_true(de.has(str(t)), str(t))
	assert_gt(n, 100, "six chains of real dialogue")
	for g: Variant in QuestLog.data().side:
		if str((g as Dictionary).id).begins_with("legend_"):
			for st: Variant in (g as Dictionary).stages:
				assert_true(de.has(str((st as Dictionary).text)), str(st.text))
