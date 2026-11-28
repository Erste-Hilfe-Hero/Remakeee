extends GutTest
## KAMPF_PLAN_1000 item 876: the rival echo's AI tier in a league battle follows the searching
## player's rank (data/league_ranks.json echo_ai). The same cases as
## tools/online/sql_test/test_league_echo_ai.sql.

var s: LocalBackend
var cfg: Dictionary

func before_all() -> void:
	Database.load_all()
	cfg = LeagueRules.ranks_config()

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 12, "moves": ["Bowl Over"]}]})
	s.call_fn("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]})

func test_every_rank_names_a_tier_that_never_falls() -> void:
	var last: int = 1
	for i: int in (cfg.ranks as Array).size():
		var t: int = LeagueRules.echo_ai(cfg, i, 2)
		assert_between(t, 1, 3, str(cfg.ranks[i].id))
		assert_gte(t, last, "%s is not gentler than the rank below" % cfg.ranks[i].id)
		last = t
	assert_eq(LeagueRules.echo_ai(cfg, 0, 2), 1, "the first rank meets the gentlest echo")
	assert_eq(LeagueRules.echo_ai(cfg, (cfg.ranks as Array).size() - 1, 2), 3, "the top meets the master tier")

func test_placement_counts_as_the_first_rank_and_missing_data_falls_back() -> void:
	assert_eq(LeagueRules.echo_ai(cfg, -1, 2), LeagueRules.echo_ai(cfg, 0, 2))
	assert_eq(LeagueRules.echo_ai(cfg, 99, 2), 3)
	assert_eq(LeagueRules.echo_ai({}, 3, 2), 2)
	assert_eq(LeagueRules.echo_ai({"ranks": [{"id": "x"}]}, 0, 2), 2)

func _find() -> Dictionary:
	return s.call_fn("league_find", {"p_league": "fair", "p_waited": 45}).data

func _open_match() -> Dictionary:
	for m: Dictionary in (s._table("league_matches", {}) as Dictionary).values():
		if m.user == s.me() and m.state == "open":
			return m
	return {}

func test_the_server_sets_the_tier_and_the_referee_replays_it() -> void:
	var f: Dictionary = _find()
	assert_true(bool(f.found))
	assert_eq(int(f.ai), 1, "placement: the gentlest echo")
	assert_eq(int(s._league_expect(_open_match()).ai), 1)
	var sn: Dictionary = s.league_season()
	var e: Dictionary = s.league_entry("fair", int(sn.id), s.me())
	e.rating = 1720.0
	e.games = 9
	f = _find()
	assert_eq(int(f.ai), 3, "a Captain meets the master tier")
	assert_eq(int(s._league_expect(_open_match()).ai), 3)
