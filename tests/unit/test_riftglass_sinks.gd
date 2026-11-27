extends GutTest
## Riftglass in play (RiftglassSinks, Ali 27 Nov 2026): fixed prices and limits, the same table
## as the server (20261127120000_rg_sinks.sql, SQL cases in tools/online/sql_test/test_rg_sinks.sql),
## the local server, the client flow against it, the Continue in the battle model and its replay.

const MIGRATION: String = "res://supabase/migrations/20261127120000_rg_sinks.sql"

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_boosts: Dictionary
var _old_records: Dictionary
var s: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_boosts = GameState.shop_boosts.duplicate(true)
	_old_records = GameState.records.duplicate(true)

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Billing.state = {}
	GameState.shop_boosts = _old_boosts
	GameState.records = _old_records

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.ONLINE
	Billing.state = {}
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})

func _give(n: int) -> void:
	LocalShop.of(s)._ledger_add(s.me(), n, "support", "test")

func _spend(reason: String, ref: String, cost: int) -> Dictionary:
	return s.call_fn("rg_spend", {"p_reason": reason, "p_ref": ref, "p_expected": cost}).data

# --- Prices -------------------------------------------------------------------------------------

func test_same_price_table_as_the_server() -> void:
	var sql: String = FileAccess.get_file_as_string(MIGRATION)
	var re := RegEx.new()
	re.compile("\\('rg_sinks', '(\\{.*\\})'\\)")
	var m: RegExMatch = re.search(sql)
	assert_not_null(m, "server_config row in the migration")
	var server: Variant = JSON.parse_string(m.get_string(1))
	var mine: Dictionary = RiftglassSinks.data().duplicate(true)
	mine.erase("_comment")
	assert_eq(JSON.stringify(server, "", true), JSON.stringify(mine, "", true), "data/riftglass_sinks.json = server prices")

func test_prices_escalate_and_stop() -> void:
	assert_eq(RiftglassSinks.continue_max(), 3)
	assert_eq(RiftglassSinks.price("continue", 0), 200)
	assert_eq(RiftglassSinks.price("continue", 1), 400)
	assert_eq(RiftglassSinks.price("continue", 2), 800)
	assert_eq(RiftglassSinks.price("continue", 3), 0, "no fourth continue")
	assert_eq(RiftglassSinks.price("heal"), 100)
	assert_eq(RiftglassSinks.price("bond_boost"), 200)
	assert_almost_eq(RiftglassSinks.bond_boost(), 0.3, 0.0001)
	assert_eq(RiftglassSinks.price("trip_skip", 0, 1), 100)
	assert_eq(RiftglassSinks.price("trip_skip", 0, 12), 1200)
	assert_eq(RiftglassSinks.price("trip_skip", 0, 0), 0)
	assert_eq(RiftglassSinks.price("trip_skip", 0, 13), 0)
	assert_eq(RiftglassSinks.price("warden_retry"), 100)
	assert_eq(RiftglassSinks.price("lamp_relight"), 200)
	assert_eq(RiftglassSinks.price("growth_x2"), 100)
	assert_eq(RiftglassSinks.price("nothing"), 0)
	assert_eq(RiftglassSinks.hours_left(1), 1, "a minute left is a started hour")
	assert_eq(RiftglassSinks.hours_left(3600), 1)
	assert_eq(RiftglassSinks.hours_left(3601), 2)
	assert_eq(RiftglassSinks.daily_rg(), 20)
	for reason: String in RiftglassSinks.REASONS:
		var p: int = RiftglassSinks.price(reason, 0, 1)
		assert_true(p > 0 and p % 100 == 0, "%s: whole hundreds (MONETIZATION rule 9)" % reason)

func test_continue_only_in_fair_story_battles() -> void:
	var story: int = GameState.Difficulty.STORY
	assert_true(RiftglassSinks.continue_allowed({}, true, story, true), "plain wild battle")
	assert_true(RiftglassSinks.continue_allowed({"ambush": true}, true, story, true))
	assert_true(RiftglassSinks.continue_allowed({"story": true, "name": "Hauler"}, false, story, true), "story Wayfarer")
	assert_false(RiftglassSinks.continue_allowed({"story": true}, false, GameState.Difficulty.RIFT_BORN, true), "not on Rift-Born")
	assert_false(RiftglassSinks.continue_allowed({"story": true}, false, story, false), "not where items are banned")
	assert_false(RiftglassSinks.continue_allowed({"name": "League rival", "model": null, "friendly": true}, false, story, true), "league")
	assert_false(RiftglassSinks.continue_allowed({"name": "x", "player_team": [], "friendly": true}, false, story, true), "echo duel")
	assert_false(RiftglassSinks.continue_allowed({"name": "Hall, round 1", "ai": 3}, false, story, true), "halls and towers")
	assert_false(RiftglassSinks.continue_allowed({"model": null}, true, story, true), "a ready model from the server")
	assert_true(RiftglassSinks.continue_allowed({"model": null, "resume": []}, true, story, true), "a wild battle picked up again")

# --- Local server -------------------------------------------------------------------------------

func test_local_server_spends_and_limits() -> void:
	assert_eq(_spend("heal", "", 100).error, "not_enough")
	_give(3000)
	assert_eq(_spend("heal", "", 50).error, "price_changed")
	assert_eq(int(_spend("heal", "", 50).price), 100)
	assert_eq(int(_spend("heal", "", 100).balance), 2900)
	assert_true(_spend("continue", "b1", 200).ok)
	assert_eq(_spend("continue", "b1", 200).error, "price_changed", "second continue costs more")
	assert_true(_spend("continue", "b1", 400).ok)
	assert_true(_spend("continue", "b1", 800).ok)
	assert_eq(_spend("continue", "b1", 800).error, "used_up")
	assert_true(_spend("continue", "b2", 200).ok, "a new battle starts at the first price")
	assert_eq(_spend("continue", "", 200).error, "bad_ref")
	assert_eq(int(_spend("trip_skip", "3", 300).price), 300)
	assert_eq(_spend("trip_skip", "13", 1300).error, "bad_ref")
	for i: int in 3:
		assert_true(_spend("lamp_relight", "", 200).ok)
	assert_eq(_spend("lamp_relight", "", 200).error, "used_up", "3 a day")
	assert_eq(_spend("free_stuff", "", 0).error, "unknown_reason")
	assert_eq(LocalShop.of(s).balance_of(s.me()), 3000 - 100 - 200 - 400 - 800 - 200 - 300 - 600)

func test_local_daily_claim_once_a_day_and_never_for_children() -> void:
	var r: Dictionary = s.call_fn("rg_daily_claim").data
	assert_eq(int(r.added), 20)
	assert_eq(int(s.call_fn("rg_daily_claim").data.added), 0, "once a day")
	s.clock_offset += 86400
	assert_eq(int(s.call_fn("rg_daily_claim").data.added), 20, "the next day again")
	s.switch_user("kid")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("shop_set_age", {"p_year": int(Time.get_date_dict_from_unix_time(s.now()).year) - 9, "p_month": 1})
	assert_eq(s.call_fn("rg_daily_claim").data.error, "age")
	assert_eq(_spend("heal", "", 100).error, "age")

func test_local_rate_limit() -> void:
	_give(100000)
	for i: int in 60:
		assert_true(_spend("heal", "", 100).ok)
	assert_eq(_spend("heal", "", 100).error, "slow_down")

# --- Client flow --------------------------------------------------------------------------------

func test_client_spend_and_daily_claim() -> void:
	await Billing.refresh_state()
	assert_true(RiftglassSinks.visible())
	assert_eq(RiftglassSinks.why_not(100), "not_enough")
	assert_eq((await RiftglassSinks.spend("heal", "", 100)).error, "not_enough", "refused before asking the server")
	assert_eq(await RiftglassSinks.claim_daily(), 20)
	assert_eq(Billing.balance(), 20, "balance follows the server")
	assert_eq(await RiftglassSinks.claim_daily(), 0)
	_give(980)
	await Billing.refresh_state()
	var d: Dictionary = await RiftglassSinks.spend("heal", "", 100)
	assert_true(d.ok)
	assert_eq(Billing.balance(), 900)
	assert_true(RiftglassSinks.error_text("not_enough", 200).contains("200"))

func test_client_offline_and_children() -> void:
	await Billing.refresh_state()
	_give(1000)
	Online.state = Online.State.OFFLINE
	assert_false(RiftglassSinks.visible())
	assert_eq(RiftglassSinks.why_not(100), "offline")
	assert_eq((await RiftglassSinks.spend("heal", "", 100)).error, "offline")
	assert_eq(await RiftglassSinks.claim_daily(), 0)
	Online.state = Online.State.ONLINE
	s.call_fn("shop_set_age", {"p_year": int(Time.get_date_dict_from_unix_time(s.now()).year) - 9, "p_month": 1})
	await Billing.refresh_state()
	assert_true(Billing.kids_locked())
	assert_false(RiftglassSinks.visible(), "nothing about Riftglass for children")
	assert_eq(RiftglassSinks.why_not(100), "age")
	assert_eq(LocalShop.of(s).balance_of(s.me()), 1000, "nothing spent")

# --- Effects ------------------------------------------------------------------------------------

func test_growth_x2_adds_battles_and_never_replaces_a_stronger_boost() -> void:
	GameState.shop_boosts = {}
	assert_false(RiftglassSinks.growth_blocked())
	RiftglassSinks.apply_growth()
	assert_eq(GameState.shop_boosts.growth, {"mult": 2.0, "left": 5})
	RiftglassSinks.apply_growth()
	assert_eq(int(GameState.shop_boosts.growth.left), 10, "the same boost adds its battles")
	GameState.shop_boosts = {"growth": {"mult": 3.0, "left": 4}}
	assert_true(RiftglassSinks.growth_blocked(), "x3 still runs")
	GameState.shop_boosts = {}

func test_trip_skip_and_lamp_relight() -> void:
	var now: int = Online.unix_now()
	GameState.records["expeditions"] = [{"uid": "u1", "hours": 8, "start": now, "dest": ""}]
	var t: Dictionary = GameState.records.expeditions[0]
	assert_eq(RiftglassSinks.hours_left(Expeditions.seconds_left(t)), 8)
	RiftglassSinks.apply_trip_skip(t)
	assert_eq(Expeditions.seconds_left(GameState.records.expeditions[0]), 0, "home now")
	var rec: Dictionary = {LampWatch.RECORD: {"nights": 2, "last_day": "2026-11-27", "answered": "2026-11-27"}}
	assert_false(LampWatch.can_light(rec, "2026-11-27"))
	RiftglassSinks.apply_lamp_relight(rec)
	assert_true(LampWatch.can_light(rec, "2026-11-27"), "lit again today")
	assert_eq(LampWatch.nights_lit(rec), 2, "nights only grow when it is lit")

# --- Battle model -------------------------------------------------------------------------------

func _losing_model(offer: int) -> BattleModel:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 3), BattleFixtures.make("Mossling", 3)]
	var m := BattleModel.new(mine, [BattleFixtures.make("Zephlet", 40)] as Array[Spirling], true, 11, 1)
	m.continue_offer = offer
	return m

## Rests until the battle waits for the Continue answer or ends. Returns the inputs.
func _play_until_choice(m: BattleModel, inputs: Array) -> void:
	for i: int in 60:
		if m.is_finished() or m.needs_continue_choice():
			return
		if m.needs_player_switch():
			var idx: int = m.swap_candidates(0, m.switch_slot())[0]
			inputs.append(BattleReplay.switch_to_dict(idx))
			m.submit_switch(idx)
			continue
		var a: BattleAction = BattleAction.make_rest(BattleModel.Side.PLAYER)
		inputs.append(BattleReplay.action_to_dict(a))
		m.submit_turn(a)

func test_no_offer_means_a_plain_loss() -> void:
	var m: BattleModel = _losing_model(0)
	m.start()
	_play_until_choice(m, [])
	assert_true(m.is_finished())
	assert_eq(m.outcome, BattleModel.Outcome.LOSS)

func test_continue_revives_the_whole_team_and_is_replayed() -> void:
	var m: BattleModel = _losing_model(3)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "field")
	assert_eq(int(snap.continue_offer), 3, "kept in the replay")
	m.start()
	var inputs: Array = []
	_play_until_choice(m, inputs)
	assert_true(m.needs_continue_choice(), "waits for the answer")
	assert_false(m.is_finished())
	inputs.append(BattleReplay.continue_to_dict(true))
	var ev: Array[BattleEvent] = m.submit_continue(true)
	assert_eq(m.continues_used, 1)
	for sp: Spirling in m.party(BattleModel.Side.PLAYER):
		assert_eq(sp.hp, sp.max_hp(), "full Vigor")
		assert_eq(sp.status, "")
	assert_true(BattleEvent.Type.SWAP_IN in BattleFixtures.types_of(ev), "the team steps back out")
	assert_false(m.is_finished())
	# Three continues at most, then the loss stands.
	for k: int in 2:
		_play_until_choice(m, inputs)
		assert_true(m.needs_continue_choice())
		inputs.append(BattleReplay.continue_to_dict(true))
		m.submit_continue(true)
	_play_until_choice(m, inputs)
	assert_true(m.is_finished(), "no fourth continue")
	assert_eq(m.outcome, BattleModel.Outcome.LOSS)
	assert_eq(m.continues_used, 3)
	snap["inputs"] = inputs
	var again: BattleModel = BattleReplay.run(snap)
	assert_eq(again.outcome, m.outcome, "the replay plays the same battle")
	assert_eq(again.turn, m.turn)
	assert_eq(again.continues_used, 3)

func test_declined_continue_is_a_loss() -> void:
	var m: BattleModel = _losing_model(3)
	m.start()
	_play_until_choice(m, [])
	m.submit_continue(false)
	assert_true(m.is_finished())
	assert_eq(m.outcome, BattleModel.Outcome.LOSS)
	assert_eq(m.continues_used, 0)

func test_referee_never_counts_a_continue() -> void:
	var m: BattleModel = _losing_model(1)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "field")
	m.start()
	var inputs: Array = []
	_play_until_choice(m, inputs)
	inputs.append(BattleReplay.continue_to_dict(true))
	m.submit_continue(true)
	_play_until_choice(m, inputs)
	snap["inputs"] = inputs
	var r: Dictionary = BattleReferee.check(snap, BattleReferee.claim_of(m))
	assert_eq(r.verdict, BattleReferee.ERROR)
	assert_eq(r.detail.reason, "continue")
	# A continue input where the battle could not take one does not fit the replay.
	var plain: BattleModel = _losing_model(0)
	var psnap: Dictionary = BattleReplay.snapshot(plain, "battle", "field")
	psnap["inputs"] = [BattleReplay.continue_to_dict(false)]
	assert_eq(BattleReferee.check(psnap, BattleReferee.claim_of(plain)).verdict, BattleReferee.MISMATCH)

func test_bond_boost_is_kept_in_the_replay_and_capped() -> void:
	var a: BattleAction = BattleAction.make_bond(BattleModel.Side.PLAYER, 0.5)
	assert_false(BattleReplay.action_to_dict(a).has("rb"), "old replays stay the same")
	a.rg_boost = RiftglassSinks.bond_boost()
	var d: Dictionary = BattleReplay.action_to_dict(a)
	assert_almost_eq(BattleReplay.action_from_dict(d).rg_boost, 0.3, 0.0001)
	d["rb"] = 9.0
	assert_almost_eq(BattleReplay.action_from_dict(d).rg_boost, RiftglassSinks.BOND_BOOST_MAX, 0.0001, "capped")

func test_bond_boost_makes_bonds_likelier() -> void:
	var tries: int = 40
	var plain: int = 0
	var boosted: int = 0
	for i: int in tries:
		for boost: float in [0.0, 0.3]:
			var foe: Spirling = BattleFixtures.make("Zephlet", 5)
			var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 5)] as Array[Spirling], [foe] as Array[Spirling], true, 100 + i)
			var b: BattleAction = BattleAction.make_bond(BattleModel.Side.PLAYER, 0.5)
			b.rg_boost = boost
			m.submit_turn(b)
			if m.outcome == BattleModel.Outcome.BONDED:
				if boost > 0.0:
					boosted += 1
				else:
					plain += 1
	assert_true(boosted > plain, "boosted %d > plain %d with the same seeds" % [boosted, plain])
