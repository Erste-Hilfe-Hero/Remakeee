extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 823, 825, 826): rest share band,
## status hits and length, and reactions in the team report.

func before_all() -> void:
	Database.load_all()

func test_team_result_carries_rest_status_and_reaction_tallies() -> void:
	var r: Dictionary = BalanceSim.run_team(36, 40, 11)
	assert_between(float(r.rest_share), 0.0, 1.0)
	assert_false((r.status_hits as Dictionary).is_empty())
	for n: String in r.status_hits:
		var row: Dictionary = r.status_hits[n]
		assert_lte(int(row.landed), int(row.tries), n)
		assert_false(Database.move(n).status_effect.is_empty(), "%s carries a status" % n)
	for st: String in r.status_turns:
		assert_gte(int(r.status_turns[st].turns), int(r.status_turns[st].count), "every status holds at least a turn")
	assert_true(r.has("reactions"))

func test_status_and_reaction_events_are_booked() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 20)] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], false, 1, 1)
	var fx: Dictionary = BalanceSim.new_effects()
	BalanceSim.watch_effects(m, fx)
	m.emit_event(BattleEvent.Type.MOVE_USED, {"side": 0, "index": 0, "move": "Drench"})
	m.emit_event(BattleEvent.Type.STATUS_APPLIED, {"side": 1, "index": 0, "status": "soak"})
	m.emit_event(BattleEvent.Type.REACTION, {"side": 1, "index": 0, "element": Elements.E.VOLT, "status": "soak"})
	m.turn = 3
	m.emit_event(BattleEvent.Type.STATUS_CURED, {"side": 1, "index": 0, "status": "soak"})
	m.emit_event(BattleEvent.Type.MOVE_USED, {"side": 0, "index": 0, "move": "Drench"})
	BalanceSim.close_effects(m, fx)
	assert_eq(fx.hits.Drench, {"tries": 2, "landed": 1})
	assert_eq(fx.lasts.soak, {"count": 1, "turns": 3})
	assert_eq(fx.reactions, {"Volt on soak": 1})

func test_report_shows_the_new_sections_and_flags_the_rest_band() -> void:
	var r: Dictionary = BalanceSim.run_team(20, 10, 4)
	var text: String = BalanceSim.report(r)
	assert_string_contains(text, "## Reactions")
	r.rest_share = 0.4
	assert_string_contains(BalanceSim.report(r), "outside the target band 10% to 25%")
	r.rest_share = 0.18
	assert_false(BalanceSim.report(r).contains("outside the target band 10%"))
