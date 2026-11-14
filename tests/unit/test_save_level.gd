extends GutTest
## Spirlings have no top ring (owner decision 2026-11-12): save_level_max is only a sanity bound
## (9999, Spirling.LEVEL_SANITY) so Ring 150 and Ring 500 Spirlings save to the cloud; level_max
## (60) still caps echo teams and the open league. The same cases as
## tools/online/sql_test/test_save_level.sql.

var s: LocalBackend

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func test_ring_150_and_500_saves_round_trip() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 150)
	var b: Spirling = BattleFixtures.make("Kindlop", 500)
	var data: Dictionary = {"schema": 1, "party": [a.to_dict(), {"species": "Kindlop", "level": 90}], "storage": [b.to_dict()]}
	assert_true(bool(_call("save_put", {"p_slot": 1, "p_data": data, "p_summary": "", "p_base_rev": 0}).ok))
	var back: Dictionary = _call("save_get", {"p_slot": 1})
	assert_eq(int(back.data.party[0].level), 150)
	assert_eq(int(back.data.party[1].level), 90)
	assert_eq(int(back.data.storage[0].level), 500)
	var a2: Spirling = Spirling.from_dict(back.data.party[0])
	var b2: Spirling = Spirling.from_dict(back.data.storage[0])
	assert_eq(a2.level, 150)
	assert_eq(a2.xp, a.xp)
	assert_eq(a2.max_hp(), a.max_hp())
	assert_eq(b2.level, 500)
	assert_eq(b2.xp, Spirling.xp_for_level(500))
	assert_eq(b2.atk(), b.atk())

func test_only_garbage_above_the_sanity_bound_is_refused() -> void:
	var r: Dictionary = _call("save_put", {"p_slot": 2, "p_data": {"schema": 1, "party": [{"level": Spirling.LEVEL_SANITY + 1}]}, "p_summary": "", "p_base_rev": 0})
	assert_eq(r.error, "implausible")
	assert_false(LocalBackend.save_ok({"party": [{"level": Spirling.LEVEL_SANITY + 1}]}))
	assert_true(LocalBackend.save_ok({"party": [{"level": Spirling.LEVEL_SANITY}]}))
	assert_true(LocalBackend.save_ok({"party": [{"level": 150}], "storage": [{"level": 500}]}))

func test_limits_stay_apart() -> void:
	assert_eq(s.config_int("level_max", 0), Spirling.STORY_RING)
	assert_eq(s.config_int("save_level_max", 0), Spirling.LEVEL_SANITY)

func test_open_league_still_plays_at_sixty() -> void:
	_call("team_set", {"p_team": [{"species": "Kindlop", "level": 500, "moves": ["Kiln Strike"]}]})
	var team: Array = _call("league_join", {"p_league": "open", "p_pick": ["Kindlop"]}).team
	assert_eq(int(team[0].level), Spirling.STORY_RING)
	s.profile_of(s.me())["team"] = [{"species": "Kindlop", "level": 500, "moves": []}]
	var built: Dictionary = LeagueRules.build_team(s.profile_of(s.me()).team, "open", ["Kindlop"], 50, s.config_int("level_max", 60))
	assert_eq(int(built.team[0].level), Spirling.STORY_RING, "a Ring 500 Spirling plays the open league at 60")
