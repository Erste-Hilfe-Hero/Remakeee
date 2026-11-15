extends GutTest
## Promo codes on the local stand-in of the server. The same cases as
## tools/online/sql_test/test_promo_codes.sql.

var s: LocalBackend

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	var t: int = s.now()
	s._table("promo_codes", {}).merge({
		"DISCORD1": {"reward": {"tonic": 3, "revival_leaf": 1}, "max_uses": null, "uses": 0, "starts_at": 0, "ends_at": null, "active": true},
		"ONLYONE1": {"reward": {"tonic": 1}, "max_uses": 1, "uses": 0, "starts_at": 0, "ends_at": null, "active": true},
		"OLDCODE1": {"reward": {"tonic": 1}, "max_uses": null, "uses": 0, "starts_at": 0, "ends_at": t - 86400, "active": true},
		"LATER001": {"reward": {"tonic": 1}, "max_uses": null, "uses": 0, "starts_at": t + 86400, "ends_at": null, "active": true},
	})
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		s.call_fn("hello", {"p_version": 1})
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 4, "summary": "", "saved_at": 0, "data": {"inventory": {"tonic": 1}}}
	s.switch_user("ben")
	s._saves()["1"] = {"rev": 2, "summary": "", "saved_at": 0, "data": {"inventory": {}}}
	s.switch_user("cid")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {}}}

func _as(who: String, code: String, slot: int, rev: int) -> Dictionary:
	s.switch_user(who)
	return s.call_fn("promo_redeem", {"p_code": code, "p_slot": slot, "p_rev": rev}).data

func test_redeem_once_per_account() -> void:
	assert_eq(_as("ann", "DISCORD1", 1, 3).error, "sync_first", "old save rev")
	var r: Dictionary = _as("ann", "disc-ord1", 1, 4)
	assert_true(r.ok)
	assert_eq(int(r.rev), 5)
	assert_eq(r.bag, {"tonic": 3, "revival_leaf": 1})
	assert_eq(s._saves()["1"].data.inventory, {"tonic": 4, "revival_leaf": 1}, "items in the bag")
	assert_eq(_as("ann", "DISCORD1", 1, 5).error, "code_used")
	assert_true(_as("ben", "DISCORD1", 1, 2).ok, "others can still redeem")
	assert_eq(int(s.db.promo_codes.DISCORD1.uses), 2)

func test_unknown_expired_not_started_and_limit() -> void:
	assert_eq(_as("ann", "NOSUCH99", 1, 4).error, "no_such_code")
	assert_eq(_as("ann", "OLDCODE1", 1, 4).error, "code_expired")
	assert_eq(_as("ann", "LATER001", 1, 4).error, "no_such_code", "not started yet")
	assert_true(_as("ann", "ONLYONE1", 1, 4).ok)
	assert_eq(_as("ben", "ONLYONE1", 1, 2).error, "code_used_up", "use limit")
	assert_eq(_as("cid", "DISCORD1", 2, 0).error, "no_save")

func test_ten_tries_an_hour() -> void:
	var last: Dictionary = {}
	for i: int in 11:
		last = _as("cid", "GUESS%03d" % i, 1, 1)
	assert_eq(last.error, "slow_down")

func test_redeem_writes_the_save() -> void:
	assert_true("promo_redeem" in LocalBackend.SAVE_WRITERS)
	assert_true(s.flag_on("promo", 1), "promo codes are on")

func test_norm() -> void:
	assert_eq(LocalPromo.norm(" ab-cd 12 34 "), "ABCD1234")

func test_error_texts() -> void:
	for e: String in ["no_such_code", "code_used", "code_used_up", "code_expired", "slow_down"]:
		assert_eq(PromoMenu.error_text({"ok": true, "data": {"ok": false, "error": e}}), PromoMenu.ERRORS[e])
