extends GutTest
## Bund level, donations, week goal, board, search and open join (Online 100, points 33, 34, 36,
## 38, 39, 40). The same cases as tools/online/sql_test/test_bund_more.sql.

var s: LocalBackend
var cfg: Dictionary

func before_all() -> void:
	cfg = BundRules.config()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		s.call_fn("hello", {"p_version": 1})
	s.db.flags["bund"] = {"enabled": true, "min_version": 1}
	s.bund_cfg()["goal_target"] = 5
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {"tonic": 30}, "party": [], "storage": []}}

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func test_rules() -> void:
	assert_eq(BundRules.level(cfg, 499), 1)
	assert_eq(BundRules.level(cfg, 500), 2)
	assert_eq(BundRules.level(cfg, 99999), 20)
	assert_eq(BundRules.donate_xp(cfg, 20), 200)
	assert_true(BundRules.lang_ok(cfg, "de"))
	assert_false(BundRules.lang_ok(cfg, "xx"))
	for l: Variant in cfg.langs:
		assert_true(BundRules.LANG_NAMES.has(l), str(l))

func test_donate_goal_and_board() -> void:
	assert_eq(_as("ann", "bund_stats").error, "no_bund")
	var b: int = int(_as("ann", "bund_create", {"p_a": 3, "p_b": 7}).bund)
	var st: Dictionary = _as("ann", "bund_stats")
	assert_eq(int(st.level), 1)
	assert_eq(_as("ann", "bund_settings", {"p_lang": "xx", "p_open": true}).error, "bad_lang")
	assert_true(bool(_as("ann", "bund_settings", {"p_lang": "de", "p_open": false}).ok))
	assert_eq(_as("ann", "bund_donate", {"p_slot": 1, "p_rev": 1, "p_item": "tonic", "p_count": 21}).error, "limit_today")
	assert_eq(_as("ann", "bund_donate", {"p_slot": 1, "p_rev": 1, "p_item": "remedy", "p_count": 1}).error, "not_enough")
	assert_eq(_as("ann", "bund_goal_claim", {"p_slot": 1, "p_rev": 1}).error, "goal_open")
	var r: Dictionary = _as("ann", "bund_donate", {"p_slot": 1, "p_rev": 1, "p_item": "tonic", "p_count": 20})
	assert_eq(int(r.xp), 200)
	assert_eq(int(r.goal), 20)
	assert_eq(_as("ann", "bund_donate", {"p_slot": 1, "p_rev": int(r.rev), "p_item": "tonic", "p_count": 1}).error, "limit_today")
	var c: Dictionary = _as("ann", "bund_goal_claim", {"p_slot": 1, "p_rev": int(r.rev)})
	assert_eq(c.item, "strong_tonic")
	assert_eq(_as("ann", "bund_goal_claim", {"p_slot": 1, "p_rev": int(c.rev)}).error, "claimed")
	assert_eq(int(s._saves()["1"].data.inventory.tonic), 10)
	assert_true(bool(_as("ann", "bund_board").rows[0].mine))
	assert_false((_as("ann", "bund_board").rows[0] as Dictionary).has("id"))
	assert_eq(int(_as("ben", "bund_search", {"p_lang": "de"}).bunds[0].bund), b)
	assert_true((_as("ben", "bund_search", {"p_lang": "en"}).bunds as Array).is_empty())
	assert_false(bool(_as("ben", "bund_join", {"p_bund": b}).joined), "closed: a request")
	_as("ann", "bund_settings", {"p_lang": "de", "p_open": true})
	assert_true(bool(_as("cid", "bund_join", {"p_bund": b}).joined), "open: joined at once")
	assert_eq(_as("cid", "bund_join", {"p_bund": b}).error, "in_bund")
	s.clock_offset += 8 * 86400
	assert_eq(int(_as("ann", "bund_stats").goal), 0, "a new week starts at 0")

func test_menu_texts() -> void:
	var t: String = BundMenu.stats_text({"level": 3, "xp": 1200, "goal": 250, "goal_target": 200, "donated_today": 5, "donate_daily": 20})
	assert_string_contains(t, "3")
	assert_string_contains(t, "200 / 200")
	assert_string_contains(BundMenu.board_text([{"name": [0, 0], "level": 2, "mine": true}]), "1.")
	assert_eq(BundMenu.ERRORS.limit_today, "You donated all you can today. More tomorrow.")
