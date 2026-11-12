extends GutTest
## Saves have their own ring limit (save_level_max 96, Spirling.ERA_MAX_LEVEL) so Halcyra
## Spirlings past 60 save to the cloud; level_max (60) still caps echo teams and the open league.
## The same cases as tools/online/sql_test/test_save_level.sql.

var s: LocalBackend

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func test_a_ring_ninety_save_round_trips() -> void:
	var data: Dictionary = {"schema": 1, "party": [{"species": "Kindlop", "level": 90}], "storage": [{"level": Spirling.ERA_MAX_LEVEL}]}
	assert_true(bool(_call("save_put", {"p_slot": 1, "p_data": data, "p_summary": "", "p_base_rev": 0}).ok))
	var back: Dictionary = _call("save_get", {"p_slot": 1})
	assert_eq(int(back.data.party[0].level), 90)
	assert_eq(int(back.data.storage[0].level), Spirling.ERA_MAX_LEVEL)

func test_above_the_era_max_is_refused() -> void:
	var r: Dictionary = _call("save_put", {"p_slot": 2, "p_data": {"schema": 1, "party": [{"level": Spirling.ERA_MAX_LEVEL + 1}]}, "p_summary": "", "p_base_rev": 0})
	assert_eq(r.error, "implausible")
	assert_false(LocalBackend.save_ok({"party": [{"level": Spirling.ERA_MAX_LEVEL + 1}]}))
	assert_true(LocalBackend.save_ok({"party": [{"level": 90}]}))

func test_limits_stay_apart() -> void:
	assert_eq(s.config_int("level_max", 0), Spirling.MAX_LEVEL)
	assert_eq(s.config_int("save_level_max", 0), Spirling.ERA_MAX_LEVEL)

func test_open_league_still_caps_at_sixty() -> void:
	_call("team_set", {"p_team": [{"species": "Kindlop", "level": 90, "moves": ["Kiln Strike"]}]})
	var team: Array = _call("league_join", {"p_league": "open", "p_pick": ["Kindlop"]}).team
	assert_eq(int(team[0].level), Spirling.MAX_LEVEL)
	s.profile_of(s.me())["team"] = [{"species": "Kindlop", "level": 90, "moves": []}]
	var built: Dictionary = LeagueRules.build_team(s.profile_of(s.me()).team, "open", ["Kindlop"], 50, s.config_int("level_max", 60))
	assert_eq(int(built.team[0].level), Spirling.MAX_LEVEL, "a Ring 90 Spirling plays the open league at 60")
