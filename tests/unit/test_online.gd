extends GutTest
## Online only (items 1-20): accounts, server saves with revisions and conflicts, server clock,
## the reconnect screen, and that the local stand-in follows the same rules as the SQL.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_revs: Dictionary
var _old_dirty: Dictionary
var _old_offset: int
var _server: LocalBackend
var _kept: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_revs = Online.revs.duplicate()
	_old_dirty = Online.dirty.duplicate()
	_old_offset = Online.clock_offset
	# Keep any real saves of this machine out of the way.
	for n: int in range(1, SaveManager.SLOTS + 1):
		var p: String = SaveManager.path_for_slot(n)
		if FileAccess.file_exists(p):
			_kept[p] = FileAccess.get_file_as_string(p)

func after_all() -> void:
	_wipe_slots()
	for p: String in _kept:
		SaveManager.write_atomic(p, _kept[p])
	Online.backend = _old_backend
	Online.state = _old_state
	Online.revs = _old_revs
	Online.dirty = _old_dirty
	Online.clock_offset = _old_offset
	Online.conflicts.clear()
	GameState.in_game = false
	SaveManager.set_slot(1)

func before_each() -> void:
	_wipe_slots()
	_server = LocalBackend.new()
	Online.backend = _server
	Online.state = Online.State.OFFLINE
	Online.revs = {}
	Online.dirty = {}
	Online.conflicts.clear()
	Online._retry_count = 0
	Online._retry_wait = Online.RETRY_SECONDS
	GameState.in_game = false
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, "Puddlet")

func _wipe_slots() -> void:
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)

func test_client_version_matches_export_presets() -> void:
	var text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var re := RegEx.create_from_string("version/code=(\\d+)")
	for m: RegExMatch in re.search_all(text):
		assert_eq(int(m.get_string(1)), Online.CLIENT_VERSION, "Online.CLIENT_VERSION must follow version/code")

func test_builds_without_a_server_address_use_the_local_stand_in() -> void:
	var cfg: Dictionary = Online.read_config()
	if str(cfg.get("url", "")).is_empty():
		assert_true(Online.make_backend() is LocalBackend)
	else:
		assert_true(Online.make_backend() is SupabaseBackend)

func test_first_start_makes_an_account_and_a_friend_code() -> void:
	assert_eq(await Online.connect_now(), Online.State.ONLINE)
	var code: String = Online.friend_code()
	assert_eq(code.length(), 8)
	for ch: String in code:
		assert_true(LocalBackend.CODE_ALPHABET.contains(ch), "no look-alike characters")
	assert_eq(Online.pretty_code("ABCDEFGH"), "ABCD-EFGH")
	# The same account comes back after a restart.
	var uid: String = _server.me()
	assert_eq(await Online.connect_now(), Online.State.ONLINE)
	assert_eq(_server.me(), uid)

func test_old_builds_are_sent_to_update() -> void:
	_server.db.config.min_version = Online.CLIENT_VERSION + 1
	assert_eq(await Online.connect_now(), Online.State.UPDATE_REQUIRED)

func test_no_connection_means_offline() -> void:
	_server.offline = true
	assert_eq(await Online.connect_now(), Online.State.OFFLINE)
	_server.offline = false
	assert_eq(await Online.connect_now(), Online.State.ONLINE)
	_server.offline = true
	var r: Dictionary = await Online.call_fn("save_list")
	assert_false(r.ok)
	assert_true(r.net)
	assert_eq(Online.state, Online.State.OFFLINE, "a dropped call switches to offline")

func test_saving_sends_the_journey_to_the_server() -> void:
	await Online.connect_now()
	SaveManager.set_slot(2)
	GameState.money = 777
	assert_true(SaveManager.save_game())
	await wait_process_frames(2)
	var row: Variant = _server.call_fn("save_get", {"p_slot": 2})
	var got: Dictionary = (await row).data
	assert_eq(int(got.data.money), 777)
	assert_eq(int(Online.revs[2]), 1)
	assert_false(Online.dirty.has(2))

func test_a_new_phone_gets_the_journeys_with_a_transfer_code() -> void:
	await Online.connect_now()
	SaveManager.set_slot(1)
	GameState.money = 4321
	SaveManager.save_game()
	await wait_process_frames(2)
	var old_code: String = Online.friend_code()
	var t: Dictionary = await Online.transfer_create()
	assert_true(t.ok)
	var code: String = str(t.data.code)
	assert_eq(code.length(), 12)
	# "Another phone": empty cache, fresh account.
	_wipe_slots()
	Online.revs = {}
	Online.backend.session = {}
	await Online.connect_now()
	assert_ne(Online.friend_code(), old_code)
	assert_false((await Online.transfer_claim("WRONG-CODE-12")).ok)
	var r: Dictionary = await Online.transfer_claim(code.to_lower().insert(4, "-"))
	assert_true(r.ok, "code works with a dash and lower case")
	assert_eq(Online.friend_code(), old_code, "same account, same friend code")
	var d: Dictionary = SaveManager.read_save(SaveManager.path_for_slot(1))
	assert_eq(int(d.money), 4321, "server save was pulled into the cache")
	assert_false((await Online.transfer_claim(code)).ok, "codes work once")

func test_transfer_codes_limit_guessing() -> void:
	await Online.connect_now()
	for i: int in 10:
		await Online.transfer_claim("AAAAAAAAAAAA")
	assert_eq((await Online.transfer_claim("AAAAAAAAAAAA")).error, "too_many_tries")

func test_two_devices_raise_a_conflict_instead_of_overwriting() -> void:
	await Online.connect_now()
	SaveManager.set_slot(1)
	GameState.money = 100
	SaveManager.save_game()
	await wait_process_frames(2)
	# The other device writes rev 2 behind our back.
	var other: Dictionary = (await _server.call_fn("save_get", {"p_slot": 1})).data
	other.data.money = 999
	await _server.call_fn("save_put", {"p_slot": 1, "p_data": other.data, "p_summary": "", "p_base_rev": 1})
	GameState.money = 200
	SaveManager.save_game()
	await wait_process_frames(2)
	assert_true(Online.conflicts.has(1), "conflict noticed")
	assert_eq(int((await _server.call_fn("save_get", {"p_slot": 1})).data.data.money), 999, "server copy kept")
	# Title screen: still dirty and changed on both sides -> the player decides.
	assert_true(await Online.sync_down())
	assert_eq(Online.conflicts, [1] as Array[int])
	assert_true(await Online.resolve_conflict_keep_local(1))
	assert_eq(int((await _server.call_fn("save_get", {"p_slot": 1})).data.data.money), 200)
	assert_true(Online.conflicts.is_empty())

func test_taking_the_other_devices_journey() -> void:
	await Online.connect_now()
	SaveManager.set_slot(1)
	GameState.money = 100
	SaveManager.save_game()
	await wait_process_frames(2)
	var other: Dictionary = (await _server.call_fn("save_get", {"p_slot": 1})).data
	other.data.money = 999
	await _server.call_fn("save_put", {"p_slot": 1, "p_data": other.data, "p_summary": "", "p_base_rev": 1})
	Online.dirty[1] = true
	assert_true(await Online.sync_down())
	assert_true(await Online.resolve_conflict_take_server(1))
	assert_eq(int(SaveManager.read_save(SaveManager.path_for_slot(1)).money), 999)

func test_saves_from_before_the_server_are_uploaded() -> void:
	SaveManager.set_slot(3)
	GameState.money = 55
	SaveManager.save_game()
	await Online.connect_now()
	assert_true(await Online.sync_down())
	assert_eq(int((await _server.call_fn("save_get", {"p_slot": 3})).data.data.money), 55)

func test_server_refuses_impossible_saves() -> void:
	await Online.connect_now()
	var bad: Dictionary = {"schema": 1, "party": [{"level": 250}], "money": 1}
	var r: Dictionary = (await _server.call_fn("save_put", {"p_slot": 1, "p_data": bad, "p_summary": "", "p_base_rev": 0})).data
	assert_eq(r.error, "implausible")
	assert_false(LocalBackend.save_ok({"money": -1}))
	assert_false(LocalBackend.save_ok({"party": [{}, {}, {}, {}, {}, {}, {}]}))
	assert_true(LocalBackend.save_ok(SaveManager.build_save()))

func test_server_clock_drives_the_date() -> void:
	_server.clock_offset = 3 * 86400
	await Online.connect_now()
	assert_almost_eq(float(Online.unix_now() - int(Time.get_unix_time_from_system())), 3.0 * 86400.0, 5.0)
	assert_eq(WeeklyChallenge.this_week(), WeeklyChallenge.week_key(Online.unix_now()))

func test_names_are_cleaned_like_on_the_server() -> void:
	assert_eq(LocalBackend.clean_name("  Mara  ", "ABCDEFGH"), "Mara")
	assert_eq(LocalBackend.clean_name("B1tch", "ABCDEFGH"), "Wanderer EFGH")
	assert_eq(LocalBackend.clean_name("<script>", "ABCDEFGH"), "Wanderer EFGH")
	assert_eq(LocalBackend.clean_name("Averyveryverylongname", "ABCDEFGH"), "Wanderer EFGH")
	assert_eq(LocalBackend.clean_name("Jörg", "ABCDEFGH"), "Jörg")
	# The banned word list is the same as in the migration.
	var sql: String = FileAccess.get_file_as_string("res://supabase/migrations/20261101000001_online_core.sql")
	for w: String in LocalBackend.BANNED:
		assert_true(sql.contains("('%s')" % w), "%s is in the SQL list too" % w)

func test_profile_card_carries_only_numbers() -> void:
	await Online.connect_now()
	GameState.mark_seen("Puddlet", true)
	GameState.mark_seen("Zippit")
	var card: Dictionary = Online.card_numbers()
	assert_eq(int(card.seen), 2)
	assert_eq(int(card.bonded), 1)
	await Online.push_profile()
	assert_eq(Online.profile.name, "Mara")
	assert_eq(int(Online.profile.card.seen), 2)

func test_deleting_the_account_removes_everything() -> void:
	await Online.connect_now()
	SaveManager.set_slot(1)
	SaveManager.save_game()
	await wait_process_frames(2)
	var uid: String = _server.me()
	assert_true((await Online.delete_account()).ok)
	assert_false(_server.db.users.has(uid))
	assert_false(FileAccess.file_exists(SaveManager.path_for_slot(1)), "local copy gone too")
	assert_eq(Online.state, Online.State.OFFLINE)

func test_losing_the_connection_while_playing_pauses_and_recovers() -> void:
	await Online.connect_now()
	GameState.in_game = true
	_server.offline = true
	await Online.call_fn("presence", {"p_place": "x"})
	# Drops shorter than 3 s only show a small mark (plan item 2150).
	Online._offline_for = ReconnectOverlay.SHORT_DROP
	await wait_process_frames(2)
	assert_true(Online._overlay.visible, "reconnect screen shows")
	assert_true(get_tree().paused)
	_server.offline = false
	await wait_seconds(Online.RETRY_SECONDS + 0.5)
	await wait_process_frames(3)
	assert_eq(Online.state, Online.State.ONLINE)
	assert_false(Online._overlay.visible)
	assert_false(get_tree().paused)
	GameState.in_game = false

## Item 438 (plan area 1): no Spirling, Echo Core or Hallkind can ever be traded, gifted or
## bought. Gifts, goal rewards and the exchange hand out bag items only, the server has no
## function that moves a Spirling between players, and Echo Cores are no bag item.
func test_spirlings_and_echo_cores_never_change_hands() -> void:
	var cfg: Dictionary = LocalBackend.DEFAULT_CONFIG
	var handed: Array[String] = []
	for e: Dictionary in cfg.gift_table:
		handed.append(str(e.item))
	for it: Variant in cfg.goal_rewards:
		handed.append(str(it))
	for o: Dictionary in Exchange.all_offers():
		handed.append(str(o.item))
	for id: String in handed:
		assert_true(Database.items.has(id), "%s is a bag item" % id)
		assert_null(Database.species(id), "%s is no Spirling" % id)
	for id: Variant in Database.items:
		assert_false(str(id).contains("core") or str(id).contains("hall"), "Echo Cores are no item: %s" % id)
		assert_null(Database.species(str(id)), "no item shares a Spirling's name: %s" % id)
	for id: Variant in _server.trade_items():
		assert_true(Database.items.has(str(id)), "%s is a bag item" % id)
		assert_null(Database.species(str(id)), "trading never moves Spirlings: %s" % id)
	for fn: String in _server._fns:
		# The shop (plan area 10) sells items for Riftglass; shop_buy never hands out Spirlings
		# (ShopValidator bans species grants, test_shop_catalog checks it), so only "buy" is allowed there.
		var banned: Array = ["spirling", "trade", "core", "sell", "release"]
		if not fn.begins_with("shop_"):
			banned.append("buy")
		# Item trading between friends (plan area 7, item 2792) moves only bag items, checked below.
		if fn.begins_with("trade_"):
			banned.erase("trade")
		for bad: String in banned:
			assert_false(fn.contains(bad), "server function %s must not move Spirlings" % fn)
	# Mail carries only phrases, waves and thanks; gifts are rolled by the server.
	assert_eq(_server._fn_mail_send({"p_kind": "spirling", "p_code": "X", "p_phrase": 0}).get("error", ""), "bad_kind")
