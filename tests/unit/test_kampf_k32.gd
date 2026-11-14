extends GutTest
## KAMPF_PLAN_1000, area "Bosse und Wardens": 419 raid guardian phases, 423 the boss moves bigger,
## 424 a short boss entrance at 4x, 435 weekly boss boards by rounds (the same cases as
## tools/online/sql_test/test_kampf_k32.sql), 434 and 436 the prism heart and the weekly giant.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
		s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []}]})
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

# --- 419: raid guardian phases ------------------------------------------------------------------

func test_raid_phase_from_the_strength_left() -> void:
	var cfg: Dictionary = RaidRules.config()
	assert_eq(RaidRules.phases(cfg).size(), 2, "two phases in data/raid_rules.json")
	assert_eq(RaidRules.phase_of(cfg, 1200, 1200), 0)
	assert_eq(RaidRules.phase_of(cfg, 601, 1200), 0)
	assert_eq(RaidRules.phase_of(cfg, 600, 1200), 1, "half gone")
	assert_eq(RaidRules.phase_of(cfg, 301, 1200), 1)
	assert_eq(RaidRules.phase_of(cfg, 300, 1200), 2, "a quarter left")
	assert_eq(RaidRules.phase_of(cfg, 0, 1200), 2)
	assert_eq(RaidRules.phase_of(cfg, 0, 0), 0)
	for p: Dictionary in RaidRules.phases(cfg):
		assert_true(str(p.text).contains("%s"), "the text names the guardian")
		assert_false((p.stage as Dictionary).is_empty())

func test_raid_attempt_meets_the_guardian_in_its_phase() -> void:
	s.db.flags["raid"] = {"enabled": true, "min_version": 1}
	s.db.config["raid_guardians"] = ["Cairnhold"]
	s.raid_cfg()["legendary_chance"] = 0
	var id: int = int(_as("ann", "raid_open", {"p_codes": [codes.ben]}).raid)
	var at: Dictionary = _as("ann", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]})
	assert_eq(int(at.raid_phase), 0, "fresh guardian")
	var fresh: BattleModel = BattleReplay.build_model(BattleReferee.from_expect(at))
	fresh.start()
	assert_eq(fresh.parties[1][0].stage("atk"), 0)
	var raid: Dictionary = s._table("raids", {})[str(id)]
	raid.hp_left = int(raid.hp_total) / 5
	at = _as("ann", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]})
	assert_eq(int(at.raid_phase), 2, "a fifth left: both phases")
	var m: BattleModel = BattleReplay.build_model(BattleReferee.from_expect(at))
	assert_eq(m.raid_phase, 2)
	var events: Array[BattleEvent] = m.start()
	var phases: Array = events.filter(func(e: BattleEvent) -> bool: return e.type == BattleEvent.Type.BOSS_PHASE and bool(e.data.get("raid", false)))
	assert_eq(phases.size(), 2, "each phase is announced")
	assert_true(phases[0].describe().begins_with(m.parties[1][0].display_name()))
	var g: Spirling = m.parties[1][0]
	assert_eq(g.stage("atk"), 1)
	assert_eq(g.stage("spd"), 1)
	assert_eq(g.stage("foc"), 1)
	# The phase stays on the attempt, so the referee rebuilds the same battle later.
	raid.hp_left = int(raid.hp_total)
	var att: Dictionary = s._table("raid_attempts", {})[str(at.attempt_id)]
	assert_eq(int(s._raid_expect(att).raid_phase), 2)
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	assert_eq(int(snap.raid_phase), 2, "the replay keeps the phase")
	assert_eq(BattleReplay.build_model(snap).raid_phase, 2)

# --- 423, 424: the boss on screen ---------------------------------------------------------------

func test_boss_moves_bigger() -> void:
	assert_gt(BattleShow.boss_motion(), 1.0)
	assert_eq(SpirlingSprite.reach(Vector2(8, 4), 1.75), Vector2(14, 7))
	assert_eq(SpirlingSprite.reach(Vector2(8, 4), 1.0), Vector2(8, 4), "everyone else as before")
	assert_eq(SpirlingSprite.reach(Vector2(8, 4), 0.5), Vector2(8, 4), "never smaller")
	var sp := SpirlingSprite.new()
	assert_eq(sp.motion_scale, 1.0)
	sp.free()

func test_boss_intro_is_short_at_4x() -> void:
	assert_true(BattleShow.short_boss_intro(true, 4.0))
	assert_false(BattleShow.short_boss_intro(true, 2.0))
	assert_false(BattleShow.short_boss_intro(false, 4.0), "only bosses")
	var e := BattleEvent.new(BattleEvent.Type.BOSS, {"label": "Ashen Heart", "text": "long", "actions": 2})
	assert_eq(BattleShow.boss_short_line(e), "It acts 2 times each turn.")
	e = BattleEvent.new(BattleEvent.Type.BOSS, {"label": "Ashen Heart", "text": str(BattleRules.BOSSES.ashen_heart.text), "actions": 1})
	assert_eq(BattleShow.boss_short_line(e), "It acts once each turn.")
	assert_lt(BattleShow.boss_short_line(e).length(), e.describe().length())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var m := BattleModel.new([Spirling.new(Database.species("Kindlop"), 20, rng)], [Spirling.new(Database.species("Smoldrake"), 20, rng)], false, 3, 1)
	m.trainer_name = "k32 test heart"
	m.foe_boss = "ashen_heart"
	var keep: int = GameState.battle_speed
	GameState.battle_speed = GameState.BATTLE_SPEEDS.find(4.0)
	assert_lt(BattleShow.intro_share_for(m), 1.0, "short opening at 4x")
	GameState.battle_speed = GameState.BATTLE_SPEEDS.find(1.0)
	assert_eq(BattleShow.intro_share_for(m), 1.0, "the whole opening at 1x")
	GameState.battle_speed = keep

# --- 435: boss boards ---------------------------------------------------------------------------

func test_boss_board_is_off_at_first() -> void:
	assert_eq(_as("ann", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 5}).error, "feature_off")
	assert_eq(_as("ann", "boss_board", {"p_kind": "prism_boss", "p_friends": true}).error, "feature_off")

func test_boss_board_keeps_the_fewest_rounds() -> void:
	s.db.flags["boss_board"] = {"enabled": true, "min_version": 1}
	assert_true(bool(_as("ann", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 12}).ok))
	assert_true(bool(_as("ann", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 15}).ok))
	assert_eq(_as("ann", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 31}).error, "implausible")
	assert_eq(_as("ann", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 0}).error, "implausible")
	assert_eq(_as("ann", "boss_submit", {"p_kind": "roof", "p_rounds": 3}).error, "bad_kind")
	assert_true(bool(_as("ann", "boss_submit", {"p_kind": "boss_tower", "p_rounds": 40}).ok))
	assert_eq(_as("ann", "boss_submit", {"p_kind": "boss_tower", "p_rounds": 91}).error, "implausible")
	_as("ben", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 9})
	_as("cid", "boss_submit", {"p_kind": "prism_boss", "p_rounds": 4})
	var r: Dictionary = _as("ann", "boss_board", {"p_kind": "prism_boss", "p_friends": true})
	assert_true(bool(r.ok))
	assert_eq(r.rows.size(), 2)
	assert_ne(str(r.rows[0].name), "", "a friend shows with name")
	assert_eq(int(r.rows[0].score), 9, "fewest rounds first")
	assert_eq(int(r.rows[1].score), 12, "the best clear counts")
	assert_true(bool(r.rows[1].me))
	r = _as("ann", "boss_board", {"p_kind": "prism_boss", "p_friends": false})
	assert_eq(r.rows.size(), 3)
	assert_eq(int(r.rows[0].score), 4)
	assert_eq(str(r.rows[0].name), "", "strangers stay nameless")
	r = _as("ann", "boss_board", {"p_kind": "boss_tower", "p_friends": false})
	assert_eq(r.rows.size(), 1)
	assert_eq(int(r.rows[0].score), 40)
	assert_eq(_as("ann", "boss_board", {"p_kind": "roof", "p_friends": true}).error, "bad_kind")

func test_boss_board_kinds_are_the_boss_halls() -> void:
	for kind: String in LocalBossBoard.MAX_ROUNDS:
		var h: Dictionary = BattleHalls.by_id(kind)
		assert_false(h.is_empty(), kind)
		assert_true(str(h.kind) in ["boss", "prism"], kind)
		assert_eq(int(LocalBossBoard.MAX_ROUNDS[kind]), BattleHalls.rounds(h) * BattleModel.BOSS_ROUND_LIMIT, kind)

# --- 434, 436: prism heart and weekly giant (existing) -------------------------------------------

func test_prism_heart_and_weekly_giant_are_bosses() -> void:
	var prism: Dictionary = BattleHalls.by_id("prism_boss")
	assert_true(BattleRules.BOSSES.has(str(BattleHalls.battle_info(prism, 4, 0, "2026-W46", [] as Array[Spirling]).boss)))
	assert_true(BattleHalls.foe_team(prism, 4, 0)[0].prism, "the endgame prism heart")
	for g: Variant in WeeklyGiant.data().get("giants", []):
		assert_true(BattleRules.BOSSES.has(str((g as Dictionary).boss)), str(g))
	assert_eq(WeeklyGiant.giant("2026-W46"), WeeklyGiant.giant("2026-W46"), "one giant per week for everyone")
