extends GutTest
## Raid search with a random group (Online 100 point 25), Echo teams (26), role signs (27), bund
## rank perks (34), the bund house (35) and bund against bund (37) on the local stand-in of the
## server. The same cases as tools/online/sql_test/test_raid_bund_more.sql.

var s: LocalBackend
var codes: Dictionary = {}
const TEAM: Array = [{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []}]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid", "dan", "a1", "a2", "b1", "b2"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
		s.call_fn("team_set", {"p_team": TEAM})
	s.db.flags["raid"] = {"enabled": true, "min_version": 1}
	s.db.flags["bund"] = {"enabled": true, "min_version": 1}
	s.db.config["raid_guardians"] = ["Cairnhold", "Leviarch"]
	s.raid_cfg()["legendary_chance"] = 0

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _wait(who: String, seconds: int) -> void:
	s.db.raid_queue[who].at = int(s.db.raid_queue[who].at) - seconds

func test_rules() -> void:
	var rc: Dictionary = RaidRules.config()
	assert_eq(RaidRules.group_echoes(rc, 0, 0), -1)
	assert_eq(RaidRules.group_echoes(rc, 1, 10), -1, "two players wait a little for more")
	assert_eq(RaidRules.group_echoes(rc, 1, 30), 0)
	assert_eq(RaidRules.group_echoes(rc, 3, 0), 0, "four players start at once")
	assert_eq(RaidRules.group_echoes(rc, 0, 60), 3, "alone: three Echo teams")
	assert_eq(RaidRules.group_echoes(rc, 1, 60), 2)
	assert_true(RaidRules.role_ok(rc, "guard"))
	assert_true(RaidRules.role_ok(rc, ""))
	assert_false(RaidRules.role_ok(rc, "boss"))
	for r: Variant in rc.roles:
		assert_true(RaidRules.ROLE_NAMES.has(r), str(r))
	var bc: Dictionary = BundRules.config()
	assert_eq(BundRules.perk(bc, 4, "donate_more"), 0)
	assert_eq(BundRules.perk(bc, 5, "donate_more"), 10)
	assert_eq(BundRules.perk(bc, 20, "goal_more"), 2)
	assert_eq(BundRules.house_slots(bc, 1), 3)
	assert_eq(BundRules.house_slots(bc, 15), 6)
	for d: Dictionary in bc.decor:
		assert_true(BundRules.DECOR_NAMES.has(d.id), str(d.id))
	for p: Dictionary in bc.perks:
		assert_true(BundRules.PERK_TEXT.has(p.key), str(p.key))
	assert_true(BundRules.house_ok(bc, 1, ["lantern", "banner"]))
	assert_false(BundRules.house_ok(bc, 1, ["fountain"]), "fountain opens at rank 8")
	assert_false(BundRules.house_ok(bc, 1, ["lantern", "lantern"]))
	assert_false(BundRules.house_ok(bc, 1, ["lantern", "banner", "bench", "lantern"]))
	assert_true(BundRules.war_day({"war_days": [6, 7]}, 1798848000), "2027-01-02 is a Saturday")
	assert_false(BundRules.war_day({"war_days": [6, 7]}, 1798934400 + 86400), "Monday")

func test_random_group_of_two_with_roles() -> void:
	assert_eq(_as("ann", "raid_find", {"p_tier": 9, "p_role": ""}).error, "bad_tier")
	assert_eq(_as("ann", "raid_find", {"p_tier": 1, "p_role": "boss"}).error, "bad_role")
	var f: Dictionary = _as("ann", "raid_find", {"p_tier": 1, "p_role": "attack"})
	assert_false(bool(f.found))
	assert_eq(int(f.waiting), 0)
	assert_false(bool(_as("ben", "raid_find", {"p_tier": 1, "p_role": "guard"}).found), "ben just came")
	_wait("ann", 31)
	f = _as("ann", "raid_find", {"p_tier": 1, "p_role": "attack"})
	assert_true(bool(f.found), str(f))
	assert_eq(int(f.echoes), 0)
	var g: Dictionary = _as("ben", "raid_find", {"p_tier": 1, "p_role": "guard"})
	assert_true(bool(g.found))
	assert_eq(int(g.raid), int(f.raid), "ben is told which Rift")
	var r: Dictionary = _as("ben", "raid_list").raids[0]
	assert_eq(int(r.players), 2)
	assert_eq(r.role, "guard")
	var roles: Array = (r.members as Array).map(func(m: Dictionary) -> String: return str(m.role))
	roles.sort()
	assert_eq(roles, ["attack", "guard"])
	assert_true(bool(_as("ann", "raid_role", {"p_raid": int(f.raid), "p_role": "help"}).ok))
	assert_eq(_as("ann", "raid_list").raids[0].role, "help")
	assert_eq(_as("ann", "raid_role", {"p_raid": int(f.raid), "p_role": "boss"}).error, "bad_role")
	assert_eq(_as("cid", "raid_role", {"p_raid": int(f.raid), "p_role": "help"}).error, "no_such_raid")

func test_blocked_players_never_meet_and_echoes_fill() -> void:
	_as("cid", "block", {"p_code": codes.dan})
	_as("cid", "raid_find", {"p_tier": 0, "p_role": ""})
	_as("dan", "raid_find", {"p_tier": 0, "p_role": ""})
	_wait("dan", 31)
	assert_false(bool(_as("dan", "raid_find", {"p_tier": 0, "p_role": ""}).found), "blocked: no group")
	_wait("cid", 61)
	var f: Dictionary = _as("cid", "raid_find", {"p_tier": 0, "p_role": "attack"})
	assert_true(bool(f.found))
	assert_eq(int(f.echoes), 3)
	var rd: Dictionary = s.db.raids[str(f.raid)]
	assert_eq(int(rd.players), 4)
	assert_eq(int(rd.hp_total), RaidRules.hp(s.raid_cfg(), s.raid_hp(4), 0, false))
	assert_eq(int(rd.hp_left), int(rd.hp_total) - 3 * RaidRules.echo_damage(s.raid_cfg(), int(rd.hp_total)))
	var members: Array = _as("cid", "raid_list").raids[0].members
	assert_eq(members.size(), 4)
	assert_eq(members.filter(func(m: Dictionary) -> bool: return bool(m.get("echo", false))).size(), 3)
	assert_false(bool(_as("dan", "raid_find", {"p_tier": 0, "p_role": ""}).found), "dan still waits")
	assert_true(bool(_as("dan", "raid_find_cancel").ok))
	assert_false(s.db.raid_queue.has("dan"))

func _bund(leader: String, others: Array) -> String:
	var b: String = str(int(_as(leader, "bund_create", {"p_a": 1, "p_b": 2}).bund))
	for x: String in others:
		s._bund_join(b, x, "member")
	return b

func test_perks_and_house() -> void:
	var b: String = _bund("ann", ["ben"])
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {"tonic": 50}, "party": [], "storage": []}}
	assert_eq(int(_as("ann", "bund_stats").donate_daily), 20)
	s.db.bunds[b]["xp"] = 2000
	var st: Dictionary = _as("ann", "bund_stats")
	assert_eq(int(st.level), 5)
	assert_eq(int(st.donate_daily), 30, "rank 5: ten more donations")
	var d: Dictionary = _as("ann", "bund_donate", {"p_slot": 1, "p_rev": 1, "p_item": "tonic", "p_count": 25})
	assert_true(bool(d.ok), str(d))
	s.db.bunds[b]["xp"] = 4500
	s.db.bunds[b]["goal_progress"] = 999
	s.db.bunds[b]["goal_week"] = s._week()
	var c: Dictionary = _as("ann", "bund_goal_claim", {"p_slot": 1, "p_rev": int(d.rev)})
	assert_eq(int(c.count), 4, "rank 10: one more from the week goal")
	s.db.bunds[b]["xp"] = 0
	var h: Dictionary = _as("ben", "bund_house")
	assert_eq(int(h.slots), 3)
	assert_false(bool(h.can_edit))
	assert_eq(_as("ben", "bund_house_set", {"p_house": ["lantern"]}).error, "not_allowed")
	assert_eq(_as("ann", "bund_house_set", {"p_house": ["fountain"]}).error, "bad_decor")
	assert_eq(_as("ann", "bund_house_set", {"p_house": ["lantern", "banner", "bench", "map_table"]}).error, "bad_decor")
	assert_true(bool(_as("ann", "bund_house_set", {"p_house": ["lantern", "banner"]}).ok))
	h = _as("ben", "bund_house")
	assert_eq(h.house, ["lantern", "banner"], "every member sees the house")
	assert_eq(h.members.size(), 2)
	s.db.bunds[b]["xp"] = 1500
	assert_eq(int(_as("ann", "bund_house").slots), 4, "rank 4: one more place")
	assert_true(bool(_as("ann", "bund_house_set", {"p_house": ["lantern", "banner", "bench", "map_table"]}).ok))
	assert_eq(_as("cid", "bund_house").error, "no_bund")

## Plays the war battle with the AI and sends it in.
func _war_battle(who: String) -> void:
	var at: Dictionary = _as(who, "bund_war_fight")
	assert_true(bool(at.ok), str(at))
	var snap: Dictionary = BattleReferee.from_expect(at)
	var model: BattleModel = BattleReplay.build_model(snap)
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 300:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			snap.inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var act: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(act))
		model.submit_turn(act)
	var r: Dictionary = _as(who, "battle_submit", {"p_kind": "bund_war", "p_ref": str(at.fight_id), "p_replay": snap,
		"p_claim": BattleReferee.claim_of(model)})
	assert_true(bool(r.ok), str(r))
	assert_eq(_as(who, "bund_war_fight").error, "fought")

## Marks the fight of [param who] as sent and decided.
func _decided(who: String, won: bool) -> void:
	var id: int = int(_as(who, "bund_war_fight").fight_id)
	var f: Dictionary = s.db.bund_war_fights[str(id)]
	f.state = "submitted"
	f.battle_id = 900000 + id
	(s.get_meta("raid_bund") as LocalRaidBund).war_apply(900000 + id, true, {"winner": "player" if won else "foe"})

func test_bund_war_five_against_five() -> void:
	s.bund_cfg()["war_size"] = 2
	s.bund_cfg()["war_days"] = []
	var ba: String = _bund("a1", ["a2"])
	var bb: String = _bund("b1", ["b2"])
	assert_eq(_as("a1", "bund_war_join", {"p_pick": ["Kindlop", "Puddlet"]}).error, "war_closed", "weekends only")
	s.bund_cfg()["war_days"] = [1, 2, 3, 4, 5, 6, 7]
	var j: Dictionary = _as("a1", "bund_war_join", {"p_pick": ["Kindlop", "Puddlet"]})
	assert_true(bool(j.joined))
	assert_null(j.war)
	assert_eq(_as("a1", "bund_war_join", {"p_pick": ["Kindlop"]}).error, "joined")
	assert_eq(_as("a1", "bund_war_fight").error, "no_war")
	_as("a2", "bund_war_join", {"p_pick": ["Kindlop", "Puddlet"]})
	_as("b1", "bund_war_join", {"p_pick": ["Kindlop", "Puddlet"]})
	var w: Dictionary = _as("b2", "bund_war_join", {"p_pick": ["Kindlop", "Puddlet"]})
	assert_not_null(w.war, "both bunds full: paired")
	assert_eq(_as("ann", "bund_war_join", {"p_pick": ["Kindlop"]}).error, "no_bund")
	_war_battle("a1")
	_decided("a2", true)
	_decided("b1", false)
	assert_false(bool(_as("a1", "bund_war_info").war.settled), "one fight still open")
	_decided("b2", false)
	var info: Dictionary = _as("a1", "bund_war_info")
	assert_true(bool(info.war.settled))
	assert_eq(info.war.result, "won")
	assert_eq(_as("b1", "bund_war_info").war.result, "lost")
	assert_eq(int(s.db.bunds[ba].xp), 300)
	assert_eq(int(s.db.bunds[bb].xp), 100, "taking part counts too")
	assert_eq(int(_as("a2", "bund_house").war_wins), 1)
	assert_eq(info.war.places.size(), 2)
	assert_eq(info.war.places[1].mine_result, "won")

func test_menu_texts() -> void:
	assert_eq(RaidMenu.member_line({"name": "Mira", "role": "guard", "damage": 320}), "Mira  [Guard]  320")
	assert_eq(RaidMenu.member_line({"name": "Mira", "role": "", "damage": 5}), "Mira  5")
	assert_eq(RaidMenu.member_line({"name": "", "echo": true, "damage": 180}), "Echo team  180")
	var h: String = BundMenu.house_text({"name": [1, 2], "level": 3, "house": ["lantern"], "slots": 4, "war_wins": 2,
		"members": [{"name": "Ann", "me": true}, {"name": "Ben", "online": false}]})
	assert_string_contains(h, "Lantern")
	assert_string_contains(h, "1 of 4")
	assert_string_contains(h, "Wars won: 2")
	assert_false(h.contains("Ben"), "only who is here now")
	var w: String = BundMenu.war_text({"size": 2, "war": {"settled": true, "result": "won", "wins": 1, "foe_wins": 0,
		"foe": {"name": [3, 4], "level": 2}, "places": [{"slot": 1, "mine": "Ann", "foe": "Cid", "mine_result": "lost",
		"foe_result": null}]}})
	assert_string_contains(w, "Score: 1 to 0")
	assert_string_contains(w, "1. Ann (lost) against Cid (open)")
	assert_string_contains(w, "Your bund won the war!")
	assert_string_contains(BundMenu.stats_text({"level": 5, "xp": 2000, "goal": 0, "goal_target": 200, "donated_today": 0,
		"donate_daily": 30, "perks": [{"level": 5, "key": "donate_more", "value": 10}]}), "* Rank 5: +10 donations a day")
	assert_true(load("res://scripts/overworld/Overworld.gd").can_instantiate())
	assert_true(load("res://scripts/ui/FriendsMenu.gd").can_instantiate())
