extends GutTest
## Wayfarer Pass track: data/pass_track.json, step math, seasons, claims on the local stand-in server
## (same rules as supabase/migrations/20261127140040_pass_track.sql) and the premium lock.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_inventory: Dictionary
var _old_money: int
var _old_in_game: bool
var s: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_inventory = GameState.inventory.duplicate()
	_old_money = GameState.money
	_old_in_game = GameState.in_game

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Billing.state = {}
	PassTrack.state = {}
	GameState.inventory = _old_inventory
	GameState.money = _old_money
	GameState.in_game = _old_in_game

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.ONLINE
	Billing.state = {}
	PassTrack.state = {}
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	GameState.inventory = {}
	GameState.money = 0
	GameState.in_game = false

func _call(fn: String, args: Dictionary = {}) -> Dictionary:
	return s.call_fn(fn, args).data

func _give_pass() -> void:
	LocalShop.of(s).sub_set(s.me(), "local", "pass-1", "de.chimora.game.pass", s.now() + 30 * 86400, "active", true)

# --- Data ------------------------------------------------------------------------------------

func test_thirty_steps_with_fixed_rewards_in_both_rows() -> void:
	assert_eq(PassTrack.tier_count(), 30)
	var looks: Array[String] = []
	for o: Dictionary in ShopCatalog.offers():
		for g: Dictionary in o.get("grants", []):
			if str(g.t) == "unlock":
				looks.append(str(g.id))
	for t: int in range(1, 31):
		for lane: String in PassTrack.LANES:
			var grants: Array = PassTrack.reward(t, lane)
			assert_false(grants.is_empty(), "step %d %s has a reward" % [t, lane])
			for g: Dictionary in grants:
				assert_true(str(g.t) in ["rg", "coins", "item", "unlock", "spirling"], "known grant kind")
				for k: String in ShopCatalog.RANDOM_FIELDS:
					assert_false(g.has(k), "nothing random")
				match str(g.t):
					"item":
						assert_false(Database.item(str(g.id)).is_empty(), "item %s exists" % g.id)
						assert_gt(int(g.n), 0)
					"unlock":
						assert_true(str(g.id) in looks, "look %s is a shop look" % g.id)
					"spirling":
						assert_not_null(Database.species(str(g.species)), "species exists")
					"rg", "coins":
						assert_gt(int(g.n), 0)
			assert_false(PassTrack.reward_text(grants).is_empty())

func test_looks_at_15_and_30_and_a_spirling_on_premium_30() -> void:
	for t: int in [15, 30]:
		for lane: String in PassTrack.LANES:
			assert_true(PassTrack.reward(t, lane).any(func(g: Dictionary) -> bool: return str(g.t) == "unlock"), "look at %d %s" % [t, lane])
	var sp: Array = PassTrack.reward(30, "premium").filter(func(g: Dictionary) -> bool: return str(g.t) == "spirling")
	assert_eq(sp.size(), 1)
	assert_eq(int(sp[0].level), 40)

func test_server_copy_matches_the_data_file() -> void:
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261127140040_pass_track.sql")
	var m: RegExMatch = RegEx.create_from_string("values \\('pass_track', '(.*?)'\\)").search(sql)
	assert_not_null(m)
	var server: Variant = JSON.parse_string(m.get_string(1))
	var local: Dictionary = PassTrack.data().duplicate(true)
	local.erase("_comment")
	assert_eq(JSON.stringify(server, "", true), JSON.stringify(local, "", true), "rebuild the server copy from data/pass_track.json")

# --- Math ------------------------------------------------------------------------------------

func test_step_math() -> void:
	assert_eq(PassTrack.per_tier(), 100)
	assert_eq(PassTrack.tier_for(0), 0)
	assert_eq(PassTrack.tier_for(99), 0)
	assert_eq(PassTrack.tier_for(100), 1)
	assert_eq(PassTrack.tier_for(2999), 29)
	assert_eq(PassTrack.tier_for(99999), 30, "never past the last step")
	assert_eq(PassTrack.progress(250), [50, 100] as Array[int])
	assert_eq(PassTrack.progress(3000), [100, 100] as Array[int], "full bar at the end")
	assert_eq(PassTrack.points_for("win"), 10)
	assert_eq(PassTrack.points_for("bond"), 25)
	assert_eq(PassTrack.points_for("daily_task"), 40)
	assert_eq(PassTrack.points_for("step"), 0)

func test_seasons_last_thirty_days_from_the_epoch() -> void:
	var jan1: int = int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 1}))
	assert_eq(PassTrack.season_of(jan1), 0)
	assert_eq(PassTrack.season_of(jan1 + 29 * 86400 + 3600), 0)
	assert_eq(PassTrack.season_of(jan1 + 30 * 86400), 1)
	assert_eq(PassTrack.season_start(1), jan1 + 30 * 86400)
	assert_eq(PassTrack.season_end(1) - PassTrack.season_start(1), 30 * 86400)

func test_block_reasons_and_open_claims() -> void:
	var st: Dictionary = {"points": 250, "claimed_free": 1, "claimed_premium": 0, "premium": false}
	assert_eq(PassTrack.block_reason(st, 1, "free"), "claimed")
	assert_eq(PassTrack.block_reason(st, 2, "free"), "")
	assert_eq(PassTrack.block_reason(st, 3, "free"), "not_reached")
	assert_eq(PassTrack.block_reason(st, 1, "premium"), "no_pass", "premium locked without the pass")
	assert_eq(PassTrack.open_claims(st), [[2, "free"]] as Array[Array])
	assert_eq(PassTrack.locked_premium(st), 2)
	st.premium = true
	assert_eq(PassTrack.open_claims(st), [[1, "premium"], [2, "free"], [2, "premium"]] as Array[Array])
	assert_eq(PassTrack.locked_premium(st), 0)

# --- Server ----------------------------------------------------------------------------------

func test_points_are_counted_and_capped_by_the_server() -> void:
	assert_eq(int(_call("pass_points_add", {"p_kind": "win", "p_amount": 1}).added), 10)
	assert_eq(int(_call("pass_points_add", {"p_kind": "bond", "p_amount": 9}).added), 75, "at most 3 events a report")
	assert_eq(int(_call("pass_points_add", {"p_kind": "cheat", "p_amount": 1}).added), 0)
	for i: int in 20:
		_call("pass_points_add", {"p_kind": "daily_task", "p_amount": 1})
	var st: Dictionary = _call("pass_state")
	assert_eq(int(st.points), PassTrack.day_cap(), "day cap")
	assert_eq(int(st.tier), 4)

func test_action_queue_carries_pass_points_once() -> void:
	var a: Dictionary = {"p_id": "pass-act-1", "p_fn": "pass_points_add", "p_args": {"p_kind": "win", "p_amount": 1}}
	assert_eq(int(_call("action_once", a).added), 10)
	assert_true(bool(_call("action_once", a).get("repeat", false)))
	assert_eq(int(_call("pass_state").points), 10)

func test_free_claim_once_and_delivered() -> void:
	assert_eq(str((await PassTrack.claim(1, "free")).error), "not_reached")
	_call("pass_points_add", {"p_kind": "daily_task", "p_amount": 3})
	await PassTrack.refresh()
	var d: Dictionary = await PassTrack.claim(1, "free")
	assert_true(bool(d.ok))
	assert_eq(GameState.money, 500, "500 coins picked up from the deliveries")
	assert_eq(str((await PassTrack.claim(1, "free")).error), "claimed")
	assert_eq(str(_call("pass_claim", {"p_tier": 1, "p_lane": "free"}).error), "claimed", "the server says so too")

func test_premium_needs_the_pass() -> void:
	_call("pass_points_add", {"p_kind": "daily_task", "p_amount": 3})
	assert_eq(str(_call("pass_claim", {"p_tier": 1, "p_lane": "premium"}).error), "no_pass")
	await PassTrack.refresh()
	assert_false(bool(PassTrack.state.premium))
	_give_pass()
	await PassTrack.refresh()
	assert_true(bool(PassTrack.state.premium))
	var d: Dictionary = await PassTrack.claim(1, "premium")
	assert_true(bool(d.ok))
	assert_eq(int(d.balance), 50, "50 Riftglass on the server")
	assert_eq(str(_call("pass_claim", {"p_tier": 1, "p_lane": "gold"}).error), "bad_lane")
	assert_eq(str(_call("pass_claim", {"p_tier": 31, "p_lane": "free"}).error), "bad_tier")

func test_premium_thirty_gives_the_spirling_and_look() -> void:
	_give_pass()
	LocalPassTrack.of(s).row(s.me()).points = 3000
	var d: Dictionary = _call("pass_claim", {"p_tier": 30, "p_lane": "premium"})
	assert_true(bool(d.ok))
	var shop: Dictionary = LocalShop.of(s)._shop(s.me())
	assert_eq(int(shop.unlocks.get("hat_tricorn", 0)), 1)
	var bag: Array = (shop.deliveries as Array).back().grants
	assert_eq(str(bag[0].species), "Vorlucent")

# --- Screen ----------------------------------------------------------------------------------

func test_screen_rows_show_the_premium_row_and_locks() -> void:
	Billing.state = {"band": 18}
	var st: Dictionary = {"points": 120, "claimed_free": 0, "claimed_premium": 0, "premium": false, "ends": 0}
	var list: Array[Dictionary] = PassScreen.rows(st)
	assert_eq(str(list[0].act), "all")
	assert_eq(str(list[1].act), "premium", "the pass offer row while the premium row is locked")
	assert_eq(list.size(), 32)
	assert_string_contains(PassScreen.step_text(st, 1), Loc.t("Locked: needs the Wayfarer Pass."))
	assert_string_contains(PassScreen.step_text(st, 1), PassTrack.reward_text(PassTrack.reward(1, "premium")))
	assert_eq(int(list[PassScreen.focus_row(list, st)].tier), 1, "focus on the first waiting reward")
	st.premium = true
	assert_false(PassScreen.rows(st).any(func(r: Dictionary) -> bool: return str(r.act) == "premium"))
	Billing.state = {"band": 0}
	st.premium = false
	assert_false(PassScreen.rows(st).any(func(r: Dictionary) -> bool: return str(r.act) == "premium"), "never for children")

func test_header_draws_without_errors() -> void:
	var v := PassScreen.PassTrackView.new()
	v.st = {"points": 1250, "claimed_free": 3, "claimed_premium": 0, "premium": false}
	v.size = Vector2(132, PassScreen.PassTrackView.HEIGHT)
	add_child_autofree(v)
	await get_tree().process_frame
	assert_eq(PassScreen.PassTrackView.first_column(12), 12)
	assert_eq(PassScreen.PassTrackView.first_column(30), 26)
	assert_eq(PassScreen.PassTrackView.first_column(0), 1)
