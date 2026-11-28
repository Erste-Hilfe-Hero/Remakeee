extends GutTest
## Spirlog book rewards (SpirlogRewards, Chimora 1.3.2): percent of the book, steps at 25/50/100 %
## bonded and 10/25/50 Gleam, taken once in the book, offline too; items and a title only, never
## Riftglass (security review 1.3.2). Also the invite code that waits offline.

const INVITE_MIGRATION: String = "res://supabase/migrations/20261128061100_invite_on.sql"

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_records: Dictionary
var _old_inventory: Dictionary
var _old_flags: Array[String]
var s: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_records = GameState.records.duplicate(true)
	_old_inventory = GameState.inventory.duplicate(true)
	_old_flags = Online.flags.duplicate()

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online.flags = _old_flags
	Billing.state = {}
	GameState.records = _old_records
	GameState.inventory = _old_inventory

func before_each() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.OFFLINE
	Billing.state = {}
	GameState.records = {}
	GameState.inventory = {}
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})

## A Spirlog with the first [param n] kinds (by Spirlog number) bonded, [param g] of them with a Gleam.
func _book(n: int, g: int = 0) -> Dictionary:
	var kinds: Array = Database.spirlings.values()
	kinds.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	var out: Dictionary = {}
	for i: int in mini(n, kinds.size()):
		out[(kinds[i] as SpirlingData).species_name] = {"seen": true, "bonded": true, "gleam_bonded": i < g}
	return out

func _need(pct: int) -> int:
	return ceili(float(pct * SpirlogRewards.total()) / 100.0)

# --- Data ---------------------------------------------------------------------------------------

func test_steps_as_asked() -> void:
	var pcts: Array = []
	var gleams: Array = []
	for st: Dictionary in SpirlogRewards.steps():
		if str(st.kind) == "gleam":
			gleams.append(int(st.n))
		else:
			pcts.append(int(st.pct))
		assert_false(st.has("riftglass"), "%s: no currency from a client-written book" % st.id)
		assert_false(Database.item(str(st.item)).is_empty(), "%s: item %s exists" % [st.id, st.item])
	assert_eq(pcts, [25, 50, 100])
	assert_eq(gleams, [10, 25, 50])
	var top: Dictionary = SpirlogRewards.step("bonded_100")
	assert_true(str(top.title) in BattleHalls.card_titles(), "the 100% title can be worn on the card")

# --- Percent and steps ----------------------------------------------------------------------------

func test_percent_lines_and_row() -> void:
	var t: int = SpirlogRewards.total()
	var book: Dictionary = _book(_need(25), 3)
	var c: Dictionary = SpirlogRewards.counts(book)
	assert_eq(int(c.bonded), _need(25))
	assert_eq(int(c.gleam), 3)
	assert_eq(int(c.total), t)
	var lines: Array[String] = SpirlogRewards.percent_lines(book)
	assert_eq(lines.size(), 3)
	assert_string_contains(lines[1], "%d%%" % SpirlogBook.percent(_need(25), t))
	assert_string_contains(SpirlogRewards.book_row_text(book, {}), "(1 ready)")
	assert_eq(SpirlogRewards.ready(_book(_need(25) - 1, 9), {}).size(), 0, "one kind and one Gleam short")

func test_claim_once_offline_with_items_and_title() -> void:
	var book: Dictionary = _book(SpirlogRewards.total(), 10)
	var lines: Array[String] = SpirlogRewards.claim("bonded_100", book, GameState.records)
	assert_false(lines.is_empty())
	assert_eq(GameState.item_count("echo_lumen"), 1)
	assert_true((GameState.records.titles as Array).has("Keeper of Every Page"))
	assert_false("\n".join(lines).contains("Riftglass"))
	assert_eq(SpirlogRewards.claim("bonded_100", book, GameState.records), [] as Array[String], "taken once")
	assert_eq(GameState.item_count("echo_lumen"), 1)
	assert_eq(SpirlogRewards.claim("gleam_25", book, GameState.records), [] as Array[String], "not reached")
	SpirlogRewards.claim("gleam_10", book, GameState.records)
	assert_eq(GameState.item_count("kin_charm"), 2)

func test_state_is_kept_in_the_save() -> void:
	SpirlogRewards.claim("bonded_25", _book(_need(25)), GameState.records)
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.records = {}
	GameState.from_dict(d)
	assert_true(SpirlogRewards.is_claimed(GameState.records, "bonded_25"))
	GameState.records[SpirlogRewards.RECORD] = {"claimed": ["bonded_25", "made_up", 3]}
	assert_eq(SpirlogRewards.state(GameState.records), {"claimed": ["bonded_25"]}, "a damaged save is repaired")

# --- Invite code that waits offline ---------------------------------------------------------------

func test_no_server_payout_for_the_book() -> void:
	assert_false(s._fns.has("spirlog_reward_claim"), "the local server has no book payout")
	for f: String in DirAccess.get_files_at("res://supabase/migrations"):
		assert_false(FileAccess.get_file_as_string("res://supabase/migrations/" + f).contains("spirlog_reward"), f)

func test_invite_goes_live_on_the_server() -> void:
	var sql: String = FileAccess.get_file_as_string(INVITE_MIGRATION)
	assert_string_contains(sql, "update public.feature_flags set enabled = true where key = 'invite';")
	assert_true(bool(LocalBackend.new().db.flags.invite.enabled), "the local stand-in has it on too")

func test_invite_code_waits_offline_and_goes_out_online() -> void:
	s.switch_user("ben")
	var ben_code: String = str(s.call_fn("hello", {"p_version": 1}).data.profile.code)
	s.switch_user("ann")
	FriendsMoreMenu.keep_for_later(ben_code)
	assert_eq(await FriendsMoreMenu.redeem_pending(), "", "offline: nothing goes out")
	assert_eq(FriendsMoreMenu.pending(), ben_code, "kept in the save")
	Online.state = Online.State.ONLINE
	Online.flags.assign(["invite"])
	var line: String = await FriendsMoreMenu.redeem_pending()
	assert_string_contains(line, Online.pretty_code(ben_code))
	assert_eq(FriendsMoreMenu.pending(), "", "sent once")
	assert_eq(str(s.db.friendships[LocalBackend.pair_key("ann", "ben")].status), "pending", "a friend request, the friend decides")
	FriendsMoreMenu.keep_for_later(ben_code)
	assert_string_contains(await FriendsMoreMenu.redeem_pending(), Loc.t("You already used an invite link."))
	assert_eq(FriendsMoreMenu.pending(), "", "one redeem per account, the code is dropped")

func test_invite_follows_the_friend_safety_rules() -> void:
	s.switch_user("ben")
	var ben_code: String = str(s.call_fn("hello", {"p_version": 1}).data.profile.code)
	s.switch_user("ann")
	s.call_fn("set_social", {"p_on": false})
	Online.state = Online.State.ONLINE
	Online.flags.assign(["invite"])
	FriendsMoreMenu.keep_for_later(ben_code)
	await FriendsMoreMenu.redeem_pending()
	assert_false((s.db.get("friendships", {}) as Dictionary).has(LocalBackend.pair_key("ann", "ben")), "no request with friends switched off")
	assert_false((s._table("invites", {}) as Dictionary).has("ann"), "and no invite stored")
	assert_eq(FriendsMoreMenu.pending(), "")

func test_book_screen_rows() -> void:
	var book: Dictionary = _book(_need(25), 10)
	SpirlogRewards.claim("bonded_25", book, GameState.records)
	var rows: Array[Dictionary] = SpirlogRewardsMenu.rows(book, GameState.records)
	assert_eq(rows.size(), SpirlogRewardsMenu.SHARE_ROWS + SpirlogRewards.steps().size())
	assert_string_contains(str(rows[1].text), "%d%%" % SpirlogBook.percent(_need(25), SpirlogRewards.total()))
	assert_string_contains(str(rows[3].text), "taken")
	assert_string_contains(str(rows[6].text), "ready!")
	assert_string_contains(str(rows[4].hint), "x2")
	assert_false(s.db.config.has("spirlog_rewards"), "nothing about the book on the server")
