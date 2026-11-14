extends GutTest
## Online 100, points 12-13 and 16-20: ranks, placement, demotion shield, echo fallback, quit wait
## and the season reward. The same cases as tools/online/sql_test/test_league_ranks.sql.

var s: LocalBackend
var cfg: Dictionary

func before_all() -> void:
	Database.load_all()
	cfg = LeagueRules.ranks_config()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 12, "moves": ["Bowl Over"]}]})
	s.call_fn("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]})

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func test_the_data_has_seven_ranks_with_rising_floors_and_real_items() -> void:
	var ranks: Array = cfg.ranks
	assert_eq(ranks.size(), 7)
	for i: int in ranks.size():
		assert_true(LeagueRules.RANK_NAMES.has(ranks[i].id), str(ranks[i].id))
		assert_true(Database.items.has(str(ranks[i].reward.item)), str(ranks[i].reward.item))
		if i > 0:
			assert_gt(float(ranks[i].floor), float(ranks[i - 1].floor))
	assert_eq(s.ranks_cfg(), cfg, "the stand-in server reads the same file")

func test_ranks_start_after_placement() -> void:
	assert_eq(LeagueRules.rank(cfg, 1500, 4), -1)
	assert_eq(LeagueRules.rank(cfg, 1500, 5), 2)
	assert_eq(LeagueRules.rank(cfg, 1399, 5), 0)
	assert_eq(LeagueRules.rank(cfg, 1400, 5), 1)
	assert_eq(LeagueRules.rank(cfg, 2400, 9), 6)
	assert_eq(LeagueRules.rank_name(cfg, 6), "Map Master")
	assert_eq(LeagueRules.rank_name(cfg, -1), "Placement")

func test_the_shield_holds_the_floor_after_a_promotion() -> void:
	assert_eq(LeagueRules.after_battle(cfg, 1590, 1610, 10, 0), {"rating": 1610.0, "shield": 3})
	assert_eq(LeagueRules.after_battle(cfg, 1610, 1580, 11, 3), {"rating": 1600.0, "shield": 2})
	assert_eq(LeagueRules.after_battle(cfg, 1610, 1580, 11, 0), {"rating": 1580.0, "shield": 0})
	assert_eq(int(LeagueRules.after_battle(cfg, 1500, 1700, 5, 0).shield), 0, "leaving placement is no promotion")

func test_quit_wait_doubles_and_stops_at_the_cap() -> void:
	assert_eq(LeagueRules.quit_wait(cfg, 1, 0), 0)
	assert_eq(LeagueRules.quit_wait(cfg, 2, 0), 60)
	assert_eq(LeagueRules.quit_wait(cfg, 3, 10), 110)
	assert_eq(LeagueRules.quit_wait(cfg, 30, 0), 900)

func test_alone_after_45_seconds_an_unrated_echo_battle() -> void:
	assert_false(bool(_call("league_find", {"p_league": "fair", "p_waited": 40}).found))
	var f: Dictionary = _call("league_find", {"p_league": "fair", "p_waited": 45})
	assert_true(bool(f.found))
	assert_true(bool(f.echo))
	assert_false(bool(f.rated))
	var info: Dictionary = _call("league_info", {"p_league": "fair"})
	assert_eq(int(info.rank), -1)
	assert_eq(int(info.placement_left), 5)

func test_leaving_found_battles_brings_a_wait() -> void:
	_call("league_find", {"p_league": "fair", "p_waited": 45})
	s.clock_offset += 120
	_call("league_find", {"p_league": "fair", "p_waited": 45})
	assert_true(bool(_call("league_find", {"p_league": "fair", "p_waited": 0}).has("found")), "quick repeats do not count")
	s.clock_offset += 120
	_call("league_find", {"p_league": "fair", "p_waited": 45})
	var f: Dictionary = _call("league_find", {"p_league": "fair", "p_waited": 45})
	assert_eq(f.error, "quit_wait")
	assert_eq(int(f.wait), 60)
	assert_string_contains(LeagueMenu.error_text({"ok": true, "data": f}), "60")

func test_the_season_reward_once_with_title() -> void:
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {}, "party": [], "storage": []}}
	var sn: Dictionary = s.league_season()
	var e: Dictionary = s.league_entry("fair", int(sn.id), "ann")
	e.rating = 1720.0
	e.games = 9
	assert_false(bool(_call("league_info", {"p_league": "fair"}).reward_ready))
	sn.ends_at = s.now() - 60
	assert_true(bool(_call("league_info", {"p_league": "fair"}).reward_ready))
	var r: Dictionary = _call("league_reward", {"p_league": "fair", "p_slot": 1, "p_rev": 1})
	assert_true(bool(r.ok))
	assert_eq(r.title, "captain")
	assert_eq(r.item, "revival_leaf")
	assert_eq(int(r.count), 3)
	assert_eq(r.frame, "season_%d_captain" % int(sn.id))
	assert_eq(int(s._saves()["1"].data.inventory.revival_leaf), 3)
	assert_eq(_call("league_reward", {"p_league": "fair", "p_slot": 1, "p_rev": int(r.rev)}).error, "no_reward")
	assert_eq(_call("league_reward", {"p_league": "open", "p_slot": 1, "p_rev": int(r.rev)}).error, "no_reward")
	assert_eq(_call("league_info", {"p_league": "fair"}).titles[0].title, "captain")

func test_the_menu_shows_placement_rank_and_shield() -> void:
	assert_string_contains(LeagueMenu.rank_text({"rank": -1, "placement_left": 3}), "3")
	var t: String = LeagueMenu.rank_text({"rank": 4, "shield": 2})
	assert_string_contains(t, "Captain")
	assert_string_contains(t, "2")
