extends GutTest
## Raid tiers, weekly guardian, top bonus, fastest Rifts, legendary guardians (Online 100, points
## 23, 24, 28, 29, 30). The same cases as tools/online/sql_test/test_raid_more.sql.

var s: LocalBackend
var codes: Dictionary = {}
var cfg: Dictionary

func before_all() -> void:
	Database.load_all()
	cfg = RaidRules.config()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	s.db.flags["raid"] = {"enabled": true, "min_version": 1}
	s.db.config["raid_guardians"] = ["Cairnhold", "Leviarch"]

func _open(tier: Variant) -> Dictionary:
	s.switch_user("ann")
	return s.call_fn("raid_open", {"p_codes": [codes.ben], "p_tier": tier}).data

func test_rules_from_the_data() -> void:
	assert_eq((cfg.tiers as Array).size(), 3)
	for g: Variant in cfg.legendaries:
		assert_not_null(Database.species(str(g)), str(g))
	assert_eq(RaidRules.guardian(cfg, ["A", "B"], 7, 99), {"guardian": "B", "legendary": false}, "by week")
	assert_eq(RaidRules.guardian(cfg, ["A", "B"], 8, 99).guardian, "A")
	assert_true(bool(RaidRules.guardian(cfg, ["A", "B"], 8, 0).legendary))
	assert_eq(RaidRules.hp(cfg, 1200, 0, false), 840)
	assert_eq(RaidRules.hp(cfg, 1200, 2, true), 2700)
	assert_eq(RaidRules.reward_count(cfg, 2, true), 3)

func test_tiers_and_the_weekly_guardian() -> void:
	s.raid_cfg()["legendary_chance"] = 0
	assert_eq(_open(5).error, "bad_tier")
	var r: Dictionary = _open(0)
	assert_eq(int(r.hp), 840)
	assert_false(bool(r.legendary))
	assert_eq(r.guardian, ["Cairnhold", "Leviarch"][RaidRules.week_index(s.now()) % 2])
	assert_eq(int(s.db.raids[str(r.raid)].level), 50)
	assert_eq(int(_open(2).hp), 1800)

func test_legendary_guardians_are_stronger() -> void:
	s.raid_cfg()["legendary_chance"] = 100
	var r: Dictionary = _open(1)
	assert_true(bool(r.legendary))
	assert_true((cfg.legendaries as Array).has(r.guardian))
	assert_eq(int(r.hp), 1800)

func test_top_bonus_and_board() -> void:
	s.raid_cfg()["legendary_chance"] = 0
	var id: int = int(_open(1).raid)
	var rd: Dictionary = s.db.raids[str(id)]
	s.db.raid_members["%d|%s" % [id, s.uid_for_code(codes.ann)]].damage = 900
	s.db.raid_members["%d|%s" % [id, s.uid_for_code(codes.ben)]].damage = 300
	rd.hp_left = 0
	rd.won_at = rd.created_at + 600
	rd.reward = {"item": "tonic", "count": 2}
	s.switch_user("ann")
	var a: Dictionary = s.call_fn("raid_claim", {"p_raid": id}).data
	assert_eq(int(a.count), 3)
	assert_true(bool(a.top))
	s.switch_user("ben")
	assert_eq(int(s.call_fn("raid_claim", {"p_raid": id}).data.count), 2)
	var b: Dictionary = s.call_fn("raid_board").data
	assert_eq(int(b.rows[0].seconds), 600)
	assert_false((b.rows[0] as Dictionary).has("name"), "no names")
	assert_string_contains(RaidMenu.board_text(b.rows), "10 min")
