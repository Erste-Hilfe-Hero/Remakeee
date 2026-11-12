extends GutTest
## Online events (Online 100, area 7) on the local stand-in server. The same cases as
## tools/online/sql_test/test_online_events.sql, plus the shared rules in OnlineEvents.gd.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "cid", "dan", "eve"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	OnlineEvents.cached = []

func after_each() -> void:
	OnlineEvents.cached = []

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _save(who: String, data: Dictionary) -> void:
	s.switch_user(who)
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": data}

func _bag(who: String) -> Dictionary:
	s.switch_user(who)
	return s._saves()["1"].data

func _on(keys: Array) -> void:
	for k: String in keys:
		s.db.flags[k] = {"enabled": true, "min_version": 1}

# --- Shared rules ---------------------------------------------------------------------------

func test_the_configs_are_the_data_files() -> void:
	var be: LocalOnlineEvents = LocalOnlineEvents.of(s)
	assert_eq(be.ev_cfg(), OnlineEvents.config())
	assert_eq((OnlineEvents.config().tiers as Array).size(), 5, "4 tiers and an extra tier")

func test_titles_tiers_and_states() -> void:
	var titles: Array = OnlineEvents.config().titles
	assert_eq(OnlineEvents.title_for(1, 3, titles), "first")
	assert_eq(OnlineEvents.title_for(3, 3, titles), "top10")
	assert_eq(OnlineEvents.title_for(50, 1000, titles), "top_tenth")
	assert_eq(OnlineEvents.title_for(500, 1000, titles), "took_part")
	assert_eq(OnlineEvents.title_for(5, 3, []), "")
	assert_true(OnlineEvents.tier_reached(20, 20, 100))
	assert_false(OnlineEvents.tier_reached(20, 20, 150))
	assert_eq(OnlineEvents.tiers_reached(16, 10, [25, 50, 75, 100, 150]), 5)
	assert_eq(OnlineEvents.tiers_reached(6, 10, [25, 50, 75, 100, 150]), 2)
	var ev: Dictionary = {"starts": 100, "ends": 200}
	assert_eq(OnlineEvents.state_of(ev, 50), "upcoming")
	assert_eq(OnlineEvents.state_of(ev, 100), "running")
	assert_eq(OnlineEvents.state_of(ev, 200), "ended")
	assert_eq(OnlineEvents.title_text("first", "Lantern month"), "Champion of Lantern month")
	assert_eq(OnlineEvents.name_of({"name": {"en": "Ember week", "de": "Glut-Woche"}}), "Ember week")
	assert_eq(OnlineEvents.name_of({"kind": "sighting"}), "Sighting day")

func test_weekly_events_start_on_monday_and_rotate_by_week() -> void:
	# Thursday 12 Nov 2026, 15:00 UTC is in ISO week 46, which starts on Monday 9 Nov.
	var thu: int = Time.get_unix_time_from_datetime_string("2026-11-12T15:00:00")
	var mon: int = Time.get_unix_time_from_datetime_string("2026-11-09T00:00:00")
	assert_eq(OnlineEvents.week_start(thu), mon)
	assert_eq(OnlineEvents.week_start(mon), mon)
	assert_eq(OnlineEvents.week_id(mon), "week-2026-w46")
	var rot: Array = OnlineEvents.config().weekly
	assert_eq(OnlineEvents.weekly_template(rot, mon), rot[46 % rot.size()])

func test_rules_pick_the_fitting_species() -> void:
	var ember: Array = OnlineEvents.allowed({"elements": ["EMBER"]})
	assert_true(ember.has("Kindlop"))
	assert_false(ember.has("Puddlet"))
	var first: Array = OnlineEvents.allowed({"max_stage": 1})
	var later: Array = []
	for n: String in Database.spirlings:
		if Database.earlier_form(Database.spirlings[n]) != null:
			later.append(n)
	assert_false(later.is_empty())
	for n: String in later:
		assert_false(first.has(n), "%s is not a first form" % n)
	assert_eq(OnlineEvents.team_error([], {}), "bad_team")
	assert_eq(OnlineEvents.team_error(["Kindlop", "Kindlop"], {}), "bad_team")
	assert_eq(OnlineEvents.team_error(["Nobodyhere"], {}), "bad_team")
	assert_eq(OnlineEvents.team_error(["Kindlop", "Puddlet"], {"elements": ["EMBER"]}), "rules")
	assert_eq(OnlineEvents.team_error(["Kindlop"], {"elements": ["EMBER"]}), "")

func test_sighting_days_raise_the_weight_of_their_species() -> void:
	var now: int = 1000000
	OnlineEvents.cached = [{"kind": "sighting", "starts": now - 10, "ends": now + 10, "species": ["Kindlop"], "boost": 3},
		{"kind": "sighting", "starts": now + 100, "ends": now + 200, "species": ["Zippit"], "boost": 3}]
	assert_eq(OnlineEvents.sighting_boost("Kindlop", now), 3)
	assert_eq(OnlineEvents.sighting_boost("Zippit", now), 1, "not before it starts")
	assert_eq(OnlineEvents.sighting_boost("Puddlet", now), 1)
	OnlineEvents.cached = []
	assert_eq(EncounterTable.weight_of({"species": "Kindlop", "weight": 30}, []), 30, "no events, no change")

func test_switched_off_until_the_flags_are_on() -> void:
	assert_eq(_as("ann", "event_list").error, "feature_off")

# --- Online events --------------------------------------------------------------------------

func _put_events() -> void:
	var be: LocalOnlineEvents = LocalOnlineEvents.of(s)
	var now: int = s.now()
	be.put_event({"id": "t-fest", "kind": "festival", "starts": now - 86400, "ends": now + 86400,
		"data": {"name": {"en": "Test fest"}, "goal_kind": "battles", "target": 20,
			"rewards": ["tonic", "remedy", "strong_tonic", "max_tonic", "spark_charm"]}})
	be.put_event({"id": "t-board", "kind": "board", "starts": now - 86400, "ends": now + 86400,
		"data": {"name": {"en": "Test board"}, "rules": {"max_stage": 1}, "allowed": ["Kindlop", "Zippit"]}})
	be.put_event({"id": "t-old", "kind": "festival", "starts": now - 10 * 86400, "ends": now - 3600,
		"data": {"goal_kind": "bonds", "target": 10, "rewards": ["tonic", "tonic", "tonic", "tonic", "tonic"]}, "total": 16})
	be.put_event({"id": "t-later", "kind": "sighting", "starts": now + 3 * 86400, "ends": now + 4 * 86400,
		"data": {"species": ["Kindlop"], "boost": 3}})
	be.put_event({"id": "t-gone", "kind": "festival", "starts": now - 40 * 86400, "ends": now - 30 * 86400,
		"data": {"goal_kind": "bonds", "target": 10}})
	var scores: Dictionary = s._table("event_scores", {})
	scores["t-old|ann"] = {"score": 8, "claimed": 0, "team": null, "at": now - 2 * 86400}
	scores["t-old|ben"] = {"score": 5, "claimed": 0, "team": null, "at": now - 3 * 86400}
	scores["t-old|cid"] = {"score": 3, "claimed": 0, "team": null, "at": now - 4 * 86400}

func test_calendar_festival_tiers_rule_week_board_rewards_and_recap() -> void:
	_on(["events", "rift_board"])
	s.referee_waits = true
	_save("ann", {"money": 1000, "inventory": {}, "party": []})
	s._saves()["1"].rev = 3
	_save("cid", {"money": 0, "inventory": {}, "party": []})
	_put_events()
	var r: Dictionary = _as("ann", "event_list")
	var ids: Array = r.events.map(func(e: Dictionary) -> String: return str(e.id))
	for id: String in ["t-fest", "t-board", "t-old", "t-later"]:
		assert_true(ids.has(id), id)
	assert_false(ids.has("t-gone"))
	assert_eq(ids.filter(func(i: String) -> bool: return i.begins_with("week-")).size(), 2, "this week and the next")
	assert_false(r.events.any(func(e: Dictionary) -> bool: return e.has("allowed")), "the species list stays on the server")
	var by_id: Dictionary = {}
	for e: Dictionary in r.events:
		by_id[e.id] = e
	assert_eq(by_id["t-later"].state, "upcoming")
	assert_eq(by_id["t-old"].state, "ended")
	assert_eq(int(by_id["t-old"].mine), 8)
	assert_eq((r.tiers as Array).size(), 5)
	for i: int in 3:
		_as("ann", "community_add", {"p_kind": "battles", "p_amount": 5})
	assert_eq(_as("ann", "event_claim", {"p_event": "t-fest", "p_tier": 4, "p_slot": 1, "p_rev": 3}).error, "not_reached")
	_as("ben", "community_add", {"p_kind": "battles", "p_amount": 9})
	assert_eq(int(s.db.online_events["t-fest"].total), 20)
	assert_eq(_as("ann", "event_claim", {"p_event": "t-fest", "p_tier": 6, "p_slot": 1, "p_rev": 3}).error, "bad_tier")
	assert_eq(_as("ann", "event_claim", {"p_event": "t-fest", "p_tier": 5, "p_slot": 1, "p_rev": 3}).error, "not_reached",
		"the extra tier needs 150 %")
	assert_eq(_as("ann", "event_claim", {"p_event": "t-later", "p_tier": 1, "p_slot": 1, "p_rev": 3}).error, "no_such_event")
	r = _as("ann", "event_claim", {"p_event": "t-fest", "p_tier": 4, "p_slot": 1, "p_rev": 3})
	assert_eq(r.item, "max_tonic")
	assert_eq(int(r.rev), 4)
	assert_eq(_as("ann", "event_claim", {"p_event": "t-fest", "p_tier": 4, "p_slot": 1, "p_rev": 4}).error, "claimed")
	assert_eq(_as("ann", "event_enter", {"p_event": "t-fest", "p_team": ["Kindlop"]}).error, "no_such_event")
	assert_eq(_as("ann", "event_enter", {"p_event": "t-board", "p_team": ["Kindlop", "Puddlet"]}).error, "rules")
	assert_eq(_as("ann", "event_enter", {"p_event": "t-board", "p_team": ["Kindlop", "Kindlop"]}).error, "bad_team")
	assert_eq(_as("ann", "event_enter", {"p_event": "t-board", "p_team": ["Nobodyhere"]}).error, "bad_team")
	assert_eq(_as("ann", "event_enter", {"p_event": "t-board", "p_team": []}).error, "bad_team")
	assert_true(bool(_as("ann", "event_enter", {"p_event": "t-board", "p_team": ["Kindlop", "Zippit"]}).ok))
	var claim: Dictionary = {"winner": "player", "rounds": 7}
	var w1: int = int(_as("ann", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []}, "p_claim": claim}).battle_id)
	var w2: int = int(_as("ann", "battle_submit", {"p_kind": "rift", "p_ref": "cinder", "p_replay": {"teams": []}, "p_claim": claim}).battle_id)
	assert_eq(_as("cid", "event_claim", {"p_event": "t-fest", "p_tier": 1, "p_slot": 1, "p_rev": 1}).error, "not_helped")
	var rows: Array = _as("cid", "event_board", {"p_event": "t-fest", "p_friends": false}).rows
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0].score), 15)
	assert_eq(str(rows[0].name), "", "strangers have no name")
	assert_eq(_as("cid", "event_board", {"p_event": "t-fest", "p_friends": true}).rows, [], "friends only")
	assert_eq(_as("cid", "event_board", {"p_event": "t-later", "p_friends": false}).error, "no_such_event")
	s.db.battles[str(w1)].status = "ok"
	s.db.battles[str(w2)].status = "mismatch"
	rows = _as("ann", "event_board", {"p_event": "t-board", "p_friends": true}).rows
	assert_eq(rows.size(), 1)
	assert_eq(int(rows[0].score), 1)
	assert_true(bool(rows[0].me))
	assert_eq(_as("ann", "event_reward", {"p_event": "t-fest", "p_slot": 1, "p_rev": 4}).error, "still_running")
	r = _as("ann", "event_reward", {"p_event": "t-old", "p_slot": 1, "p_rev": 4})
	assert_eq(int(r.rank), 1)
	assert_eq(int(r.players), 3)
	assert_eq(r.title, "first")
	assert_eq(r.item, "spark_charm")
	assert_eq(int(r.rev), 5)
	assert_eq(_as("ann", "event_reward", {"p_event": "t-old", "p_slot": 1, "p_rev": 5}).error, "claimed")
	r = _as("ann", "event_recap", {"p_event": "t-old"})
	assert_eq(int(r.score), 8)
	assert_eq(int(r.rank), 1)
	assert_eq(int(r.players), 3)
	assert_eq(int(r.best), 8)
	assert_eq(int(r.reached), 5)
	assert_eq(r.award.title, "first")
	assert_eq(_as("ann", "event_recap", {"p_event": "t-later"}).error, "no_such_event")
	var titles: Array = _as("ann", "event_list").titles
	assert_true(titles.any(func(t: Dictionary) -> bool: return t.event == "t-old" and t.title == "first"))
	assert_eq(_as("cid", "event_reward", {"p_event": "t-old", "p_slot": 1, "p_rev": 1}).title, "top10")
	assert_eq(_as("dan", "event_reward", {"p_event": "t-old", "p_slot": 1, "p_rev": 1}).error, "not_helped")
	assert_eq(int(_bag("ann").inventory.max_tonic), 1)
	assert_eq(int(_bag("ann").inventory.spark_charm), 1)

func test_menu_texts() -> void:
	assert_eq(EventsMenu.span_text(3 * 86400 + 5), "3 d")
	assert_eq(EventsMenu.span_text(7200), "2 h")
	assert_eq(EventsMenu.span_text(30), "1 min")
	assert_eq(EventsMenu.rules_text({"max_stage": 1}), "Only first forms")
	assert_eq(EventsMenu.rules_text({}), "No special rules")
	var ev: Dictionary = {"total": 20, "target": 20, "mine": 5, "claimed": 1 << 3}
	assert_eq(EventsMenu.open_tiers(ev, [25, 50, 75, 100, 150]), [1, 2, 3] as Array[int])
	ev.mine = 0
	assert_eq(EventsMenu.open_tiers(ev, [25, 50, 75, 100, 150]), [] as Array[int])
