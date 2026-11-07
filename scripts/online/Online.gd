extends Node
## Autoload "Online": Chimora is online only (items 1-20).
## - Signs in on start (a fresh account without email, or the stored session).
## - Keeps the saves on the server; the files in user:// are only a cache of them.
## - While playing it sends a heartbeat. If the server cannot be reached, the game pauses
##   behind a "Reconnecting" screen and carries on by itself once the connection is back.
## - Gives the server's clock to everything that depends on the date (daily find, weekly
##   challenge, festivals), so changing the phone's clock does nothing.

enum State { OFFLINE, CONNECTING, ONLINE, UPDATE_REQUIRED }

## Must match version/code in export_presets.cfg (tests check it). The server sends builds
## older than its "min_version" to the store.
const CLIENT_VERSION: int = 1
## Format number of the online save (plan item 2673). The server refuses saves without it or
## newer than its server_config.save_schema_max. Raise both together.
const SAVE_SCHEMA: int = 1
const CONFIG_PATH: String = "res://data/online.json"
const SESSION_PATH: String = "user://online_session.json"
const LOCAL_STORE_PATH: String = "user://local_server.json"
const HEARTBEAT_SECONDS: float = 45.0
const RETRY_SECONDS: float = 5.0
## Waits between reconnect tries after the first quick one (plan item 3657), each with up to
## 20 % chance either way, so after a server restart the players do not all come back at once.
const RETRY_STEPS: Array[float] = [4.0, 8.0, 16.0, 30.0]
const RETRY_JITTER: float = 0.2
## Small actions kept while the connection is weak (plan item 3011); the oldest go first.
const ACTIONS_MAX: int = 50
## A failed call is tried once more after this pause before anything is shown (item 2151).
var net_retry_seconds: float = 2.0

signal state_changed(state: State)
## Another device saved this slot after this one last synced it.
signal save_conflict(slot: int)

var backend: OnlineBackend
var state: State = State.OFFLINE
var last_error: String = ""
## Our public profile as the server returned it ({"code", "name", ...}).
var profile: Dictionary = {}
var motd: String = ""
var online_now: int = 0
## Server clock minus phone clock, in seconds.
var clock_offset: int = 0
## Revision of each slot the last time this device read or wrote it (slot -> rev).
var revs: Dictionary = {}
## Slots saved on this device that the server has not confirmed yet.
var dirty: Dictionary = {}
## Seen the short privacy note (item 20).
var privacy_seen: bool = false
## Slots the player must decide about (both this phone and another device have changes).
var conflicts: Array[int] = []
## The account was opened on another device since this one claimed it (plan item 3010). The
## title asks before this device takes it back.
var kicked: bool = false
## Small actions waiting to go out (plan item 3011): [{"id", "fn", "args"}], oldest first.
var actions: Array = []
var _sending_actions: bool = false

var _beat: float = 0.0
var _beats: int = 0
var _retry: float = 0.0
## Failed reconnects in a row (picks the wait from RETRY_STEPS) and the current wait.
var _retry_count: int = 0
var _retry_wait: float = 4.0
var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _overlay: ReconnectOverlay
## Hopping dots while a server call is slow (plan item 2290).
var wait_dots: WaitDots
## Slots with an upload on its way, slots saved again meanwhile (value: force), and a counter
## of local saves per slot (see push()).
var _pushing: Dictionary = {}
var _push_again: Dictionary = {}
var _save_gen: Dictionary = {}
## Seconds without connection while playing, and reconnect tries so far (reconnect screen).
var _store_url: String = ""
var _offline_for: float = 0.0
var _tries: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Action ids (plan item 3011) must differ after every start of the app.
	_rng.randomize()
	backend = make_backend()
	_load_session()
	_overlay = ReconnectOverlay.new()
	add_child(_overlay)
	_overlay.try_now.connect(retry_now)
	_overlay.to_title.connect(_to_title)
	wait_dots = WaitDots.new()
	add_child(wait_dots)

## The real server if data/online.json names one, otherwise the local stand-in.
func make_backend() -> OnlineBackend:
	var cfg: Dictionary = read_config()
	if not str(cfg.get("url", "")).is_empty() and not str(cfg.get("anon_key", "")).is_empty():
		return SupabaseBackend.new(str(cfg.url), str(cfg.anon_key), self)
	return LocalBackend.new(LOCAL_STORE_PATH)

static func read_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return raw if raw is Dictionary else {}

func is_online() -> bool:
	return state == State.ONLINE

func is_local() -> bool:
	return backend != null and backend.is_local()

func friend_code() -> String:
	return str(profile.get("code", ""))

## Shown with a dash in the middle so it is easy to read out: "ABCD-EFGH".
static func pretty_code(code: String) -> String:
	return code.left(4) + "-" + code.substr(4) if code.length() == 8 else code

func _set_state(s: State) -> void:
	if state != s:
		state = s
		state_changed.emit(s)

# --- Clock -----------------------------------------------------------------------------

## Unix time by the server's clock (falls back to the phone before the first contact).
func unix_now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_offset

## Local calendar date by the server's clock: {"year", "month", "day", "weekday"}.
func date_now() -> Dictionary:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_dict_from_unix_time(unix_now() + bias)

func _take_server_time(t: Variant) -> void:
	if t is int or t is float:
		clock_offset = int(t) - int(Time.get_unix_time_from_system())

# --- Connecting ------------------------------------------------------------------------

## Signs in (creating an account the first time) and says hello. Returns the new state.
func connect_now() -> State:
	if _busy:
		while _busy:
			await get_tree().process_frame
		return state
	_busy = true
	_set_state(State.CONNECTING)
	var r: Dictionary
	if backend.signed_in():
		r = await backend.refresh()
		if not r.ok and not r.net:
			r = await backend.sign_in_anonymous()
	else:
		r = await backend.sign_in_anonymous()
	if r.ok:
		r = await backend.call_fn("hello", {"p_version": CLIENT_VERSION})
	if r.ok:
		r = await _claim(r)
	_busy = false
	if not r.ok:
		last_error = r.error
		_set_state(State.OFFLINE)
		if r.error == "other_device":
			_other_device()
		return state
	_take_hello(r.data)
	_save_session()
	if state == State.ONLINE and str(profile.get("platform", "")) != platform_name():
		# The browser test build's accounts are deleted after 30 days unused (plan item 3765).
		var p: Dictionary = await backend.call_fn("platform_set", {"p_platform": platform_name()})
		if p.ok and p.data is Dictionary and bool(p.data.get("ok", false)):
			profile["platform"] = platform_name()
	return state

## Claims the account for this device (plan item 3010): keeps the token it had, or gets a new
## one on a fresh start. Fails with "other_device" when another device took over meanwhile.
## Returns [param hello] (the hello answer) when all is well.
func _claim(hello: Dictionary) -> Dictionary:
	var c: Dictionary = await backend.call_fn("session_claim", {"p_token": backend.device_token})
	if not c.ok:
		# A server without the function yet lets every device save, as before.
		return c if c.net else hello
	if c.data is Dictionary and bool(c.data.get("ok", false)):
		backend.device_token = str(c.data.get("token", ""))
	elif c.data is Dictionary and str(c.data.get("error", "")) == "other_device":
		return OnlineBackend.fail("other_device")
	return hello

## Another device has the account now: stop here and go to the title, which says so.
func _other_device() -> void:
	kicked = true
	backend.device_token = ""
	last_error = "other_device"
	_set_state(State.OFFLINE)
	if GameState.in_game:
		_to_title()

## "web" for the browser test build, "app" for the phone apps (and desktop test runs).
static func platform_name() -> String:
	return "web" if OS.has_feature("web") else "app"

func _take_hello(d: Variant) -> void:
	if not d is Dictionary:
		return
	profile = d.get("profile", {}) if d.get("profile") is Dictionary else {}
	motd = str(d.get("motd", ""))
	_store_url = str(d.get("store_url", ""))
	online_now = int(d.get("online_now", 0))
	flags.assign(d.get("flags", []) if d.get("flags") is Array else [])
	_take_server_time(d.get("server_time"))
	_set_state(State.UPDATE_REQUIRED if bool(d.get("update_required", false)) else State.ONLINE)

## Calls a server function. A dropped connection switches to OFFLINE (the reconnect screen
## takes over while playing).
func call_fn(name: String, args: Dictionary = {}) -> Dictionary:
	if state != State.ONLINE:
		return OnlineBackend.fail("offline", true)
	if wait_dots != null:
		wait_dots.begin()
	var r: Dictionary = await backend.call_fn(name, args)
	if not r.ok and r.net and r.error != "server_429" and is_inside_tree():
		if net_retry_seconds > 0.0:
			await get_tree().create_timer(net_retry_seconds, true).timeout
		r = await backend.call_fn(name, args)
	if wait_dots != null:
		wait_dots.end()
	if not r.ok and r.net:
		last_error = r.error
		_set_state(State.OFFLINE)
	elif not r.ok and r.error == "not_signed_in":
		_set_state(State.OFFLINE)
	elif not r.ok and r.error == "other_device":
		_other_device()
	return r

## A sentence and the next step for an online problem (item 2146). Empty: the last error.
func error_text(code: String = "") -> String:
	return OnlineErrors.text(code if not code.is_empty() else last_error)

## Where "Open the store" goes when an update is needed (item 2148): the address the server
## sends, otherwise the store page for this platform.
func store_url() -> String:
	if not _store_url.is_empty():
		return _store_url
	if OS.get_name() == "iOS":
		return "itms-apps://apps.apple.com"
	return "https://play.google.com/store/apps/details?id=de.chimora.game"

## Waits up to [param max_seconds] for an upload of [param slot] on its way; true when the
## server has the newest save (honest "Saved." in the pause menu, item 1868).
func wait_synced(slot: int, max_seconds: float = 4.0) -> bool:
	var until: int = Time.get_ticks_msec() + int(max_seconds * 1000.0)
	while _pushing.has(slot) and Time.get_ticks_msec() < until and is_inside_tree():
		await get_tree().process_frame
	return state == State.ONLINE and not dirty.has(slot)

# --- Account (items 2, 4, 11) -------------------------------------------------------------

## A one-time code (valid 7 days) that moves this account to another phone. No email needed.
func transfer_create() -> Dictionary:
	return await call_fn("transfer_create")

## On a new phone: takes over the account the code belongs to and loads its journeys.
## The journeys cached on this phone are replaced.
func transfer_claim(code: String) -> Dictionary:
	var r: Dictionary = await call_fn("transfer_claim", {"p_code": code})
	if not r.ok:
		return r
	if not r.data is Dictionary or not bool(r.data.get("ok", false)):
		return OnlineBackend.fail(str(r.data.get("error", "bad_code")) if r.data is Dictionary else "bad_code")
	revs = {}
	dirty = {}
	_clear_cache()
	# This phone takes the account over from the old one.
	backend.device_token = ""
	r = await call_fn("hello", {"p_version": CLIENT_VERSION})
	if r.ok:
		r = await _claim(r)
	if r.ok:
		_take_hello(r.data)
	_save_session()
	await sync_down()
	return OnlineBackend.ok()

## Deletes the account on the server and every local copy (item 11).
func delete_account() -> Dictionary:
	var r: Dictionary = await call_fn("delete_account")
	if not r.ok:
		return r
	backend.session = {}
	profile = {}
	revs = {}
	dirty = {}
	actions = []
	_clear_cache()
	_save_session()
	_set_state(State.OFFLINE)
	return r

func _clear_cache() -> void:
	var keep: int = SaveManager.slot
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(keep)

# --- Saves (items 5, 6, 8) ----------------------------------------------------------------

## Brings the local cache in line with the server. Slots changed on both sides go to
## [member conflicts] for the player to decide. Returns false if the server could not be read.
func sync_down() -> bool:
	conflicts.clear()
	var r: Dictionary = await call_fn("save_list")
	if not r.ok:
		return false
	var on_server: Dictionary = {}
	for row: Variant in (r.data if r.data is Array else []):
		on_server[int(row.slot)] = int(row.rev)
	for n: int in range(1, SaveManager.SLOTS + 1):
		var local: bool = FileAccess.file_exists(SaveManager.path_for_slot(n))
		var known: int = int(revs.get(n, 0))
		if on_server.has(n):
			var server_rev: int = on_server[n]
			if server_rev == known and local:
				if dirty.has(n):
					await push(n)
				continue
			if dirty.has(n) and local:
				conflicts.append(n)
				continue
			if not await pull(n):
				return false
		elif local:
			# A save from before the server existed, or one the server never got: send it up.
			revs.erase(n)
			dirty[n] = true
			await push(n)
	_save_session()
	return true

## Writes the server's copy of [param slot] into the local cache.
func pull(slot: int) -> bool:
	var r: Dictionary = await call_fn("save_get", {"p_slot": slot})
	if not r.ok:
		return false
	if not r.data is Dictionary or not r.data.get("data") is Dictionary:
		return true
	var path: String = SaveManager.path_for_slot(slot)
	if not SaveManager.write_save(path, r.data.data):
		return false
	revs[slot] = int(r.data.rev)
	dirty.erase(slot)
	_save_session()
	return true

## Called by SaveManager after every local save of the active slot.
func note_saved(slot: int) -> void:
	dirty[slot] = true
	_save_gen[slot] = int(_save_gen.get(slot, 0)) + 1
	_save_session()
	if state == State.ONLINE:
		push(slot)

## Sends the local copy of [param slot] up. [param force] keeps this device's journey after a conflict.
## One upload per slot at a time: two saves close together (leaving the app saves twice on
## Android, a door warp right after a battle) used to send both with the same base revision,
## so the second, newer one was refused as a conflict and never reached the server.
func push(slot: int, force: bool = false) -> bool:
	if _pushing.has(slot):
		_push_again[slot] = bool(_push_again.get(slot, false)) or force
		while _pushing.has(slot):
			await get_tree().process_frame
		return not dirty.has(slot)
	_pushing[slot] = true
	var ok: bool = await _push_once(slot, force)
	while _push_again.has(slot):
		var again_force: bool = bool(_push_again[slot])
		_push_again.erase(slot)
		ok = await _push_once(slot, again_force)
	_pushing.erase(slot)
	return ok

func _push_once(slot: int, force: bool) -> bool:
	var gen: int = int(_save_gen.get(slot, 0))
	var path: String = SaveManager.path_for_slot(slot)
	var d: Variant = SaveManager.read_save(path)
	if not d is Dictionary:
		return false
	d["schema"] = SAVE_SCHEMA
	var base_rev: int = int(revs.get(slot, 0))
	var r: Dictionary = await call_fn("save_put", {"p_slot": slot, "p_data": d,
		"p_summary": SaveManager.summary_line(d), "p_base_rev": base_rev, "p_force": force,
		"p_request_id": request_id(d, slot, base_rev)})
	if not r.ok or not r.data is Dictionary:
		return false
	if bool(r.data.get("ok", false)):
		revs[slot] = int(r.data.rev)
		# A save made while this upload was on its way is still waiting to go up.
		if int(_save_gen.get(slot, 0)) == gen:
			dirty.erase(slot)
		conflicts.erase(slot)
		_save_session()
		return true
	if bool(r.data.get("conflict", false)):
		if not conflicts.has(slot):
			conflicts.append(slot)
		save_conflict.emit(slot)
	else:
		push_error("Server refused save: %s" % str(r.data.get("error", "")))
	return false

## Same save on the same base revision = same id, even after a restart of the app, so the
## server stores an upload that was resent after a timeout only once (plan item 3658).
static func request_id(d: Dictionary, slot: int, base_rev: int) -> String:
	return ("%d|%d|" % [slot, base_rev] + JSON.stringify(d, "", true)).sha256_text().left(32)

## The player kept the other device's journey: drop this phone's changes.
func resolve_conflict_take_server(slot: int) -> bool:
	dirty.erase(slot)
	conflicts.erase(slot)
	return await pull(slot)

func resolve_conflict_keep_local(slot: int) -> bool:
	return await push(slot, true)

func push_dirty() -> void:
	for slot: Variant in dirty.keys():
		if not conflicts.has(int(slot)):
			await push(int(slot))

# --- Profile and presence ------------------------------------------------------------------

## Sends name, look, favourite and card numbers (item 24).
func push_profile() -> void:
	if state != State.ONLINE:
		return
	var r: Dictionary = await call_fn("profile_set", {"p_name": GameState.tamer_name, "p_color": GameState.tamer_color,
		"p_favorite": favorite_species(), "p_card": card_numbers()})
	if r.ok and r.data is Dictionary:
		profile = r.data
	await push_team()

## Sends the team as this player's echo for friends (species, level and moves only).
func push_team() -> void:
	if state == State.ONLINE and not GameState.party.is_empty():
		await call_fn("team_set", {"p_team": EchoTeam.snapshot(GameState.party)})

## Adds to the world goal of the week (items 81-85). The server only counts this week's kind.
func contribute(kind: String, amount: int = 1) -> void:
	await send_small("community_add", {"p_kind": kind, "p_amount": amount})

# --- Small actions (plan item 3011) -------------------------------------------------------

## Sends a set phrase, wave, thanks or world goal step. With a weak connection it waits in
## [member actions] (up to ACTIONS_MAX) and goes out after the reconnect; its own id lets the
## server count it once even if it is sent twice. Returns the server's answer, or
## {"ok": true, "queued": true} while it waits.
func send_small(fn: String, args: Dictionary) -> Dictionary:
	var item: Dictionary = {"id": action_id(), "fn": fn, "args": args}
	actions.append(item)
	while actions.size() > ACTIONS_MAX:
		actions.pop_front()
	_save_session()
	var sent: Dictionary = await send_actions()
	return sent.get(item.id, OnlineBackend.ok({"ok": true, "queued": true}))

## Sends the waiting actions in order until the queue is empty or the connection drops.
## Returns the answers by action id.
func send_actions() -> Dictionary:
	var out: Dictionary = {}
	if _sending_actions:
		return out
	_sending_actions = true
	while state == State.ONLINE and not actions.is_empty():
		var it: Dictionary = actions[0]
		var r: Dictionary = await call_fn("action_once", {"p_id": it.id, "p_fn": it.fn, "p_args": it.args})
		if not r.ok and not r.net and r.error.contains("action_once"):
			# A server without the function yet takes the action directly.
			r = await call_fn(str(it.fn), it.args)
		if not r.ok and r.net:
			break
		if not actions.is_empty() and actions[0] == it:
			actions.pop_front()
		_save_session()
		out[it.id] = r
	_sending_actions = false
	return out

func action_id() -> String:
	return "%08x%08x%08x" % [_rng.randi(), _rng.randi(), Time.get_ticks_usec() & 0xffffffff]

## Features the server switched on for this version (hello, item 2675). Menus hide the rest.
var flags: Array[String] = []

func flag_on(key: String) -> bool:
	return flags.has(key)

## The Leagues menu shows when at least one league is on.
func league_on() -> bool:
	return flag_on("league_" + LeagueRules.FAIR) or flag_on("league_" + LeagueRules.OPEN)

## Friends, mail and greetings are on (parents can switch them off, item 147).
func social_on() -> bool:
	return bool(profile.get("social", true))

func set_social(on: bool) -> bool:
	var r: Dictionary = await call_fn("set_social", {"p_on": on})
	if r.ok:
		profile["social"] = on
	return r.ok

func favorite_species() -> String:
	var fav: String = str(GameState.records.get("favorite", ""))
	if fav.is_empty() and not GameState.party.is_empty():
		fav = GameState.party[0].data.species_name
	return fav

static func card_numbers() -> Dictionary:
	var seen: int = 0
	var bonded: int = 0
	for k: Variant in GameState.spirlog:
		var e: Variant = GameState.spirlog[k]
		if e is Dictionary:
			seen += 1 if bool(e.get("seen", true)) else 0
			bonded += 1 if bool(e.get("bonded", false)) else 0
		else:
			seen += 1
	var out: Dictionary = {"seals": GameState.rifts_sealed.size(), "seen": seen, "bonded": bonded,
		"hours": int(GameState.play_time / 3600.0)}
	# The worn profile frame (item 4284); the server keeps it only with the unlock.
	if not GameState.profile_frame().is_empty():
		out["frame"] = GameState.profile_frame()
	return out

func _process(delta: float) -> void:
	if state == State.ONLINE:
		_overlay.hide_overlay()
		_offline_for = 0.0
		_tries = 0
		if GameState.in_game:
			_beat += delta
			if _beat >= HEARTBEAT_SECONDS:
				_beat = 0.0
				_heartbeat()
		return
	if not GameState.in_game or state == State.UPDATE_REQUIRED:
		_overlay.hide_overlay()
		_offline_for = 0.0
		return
	# Playing without a connection is not possible: pause and keep trying (item 7).
	_overlay.show_overlay()
	_offline_for += delta
	# The first try comes quickly, so a short drop is over before the big screen shows.
	var wait: float = 1.0 if _tries == 0 else _retry_wait
	if state == State.OFFLINE and not _busy:
		_retry += delta
		if _retry >= wait:
			_retry = 0.0
			_reconnect()
	var next_in: float = 0.0 if _busy else maxf(0.0, wait - _retry)
	_overlay.update_view(_tries + 1, next_in, _offline_for)

## "Try now" on the reconnect screen.
func retry_now() -> void:
	if state == State.OFFLINE and not _busy:
		_retry = 0.0
		_reconnect()

## "To title" on the reconnect screen after a minute without connection.
func _to_title() -> void:
	GameState.in_game = false
	_overlay.hide_overlay()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/Title.tscn")

func _reconnect() -> void:
	_tries += 1
	if await connect_now() == State.ONLINE:
		_retry_count = 0
		_retry_wait = retry_wait(0, 0.0)
		await push_dirty()
		await send_actions()
	else:
		_retry_count += 1
		_retry_wait = retry_wait(_retry_count, _rng.randf_range(-1.0, 1.0))

## Seconds before reconnect try number [param failed] + 1; [param spread] from -1 to 1 is the
## random part (scaled to RETRY_JITTER).
static func retry_wait(failed: int, spread: float) -> float:
	var base: float = RETRY_STEPS[clampi(failed, 0, RETRY_STEPS.size() - 1)]
	return base * (1.0 + RETRY_JITTER * clampf(spread, -1.0, 1.0))

func _heartbeat() -> void:
	_beats += 1
	if _beats % 4 == 0:
		push_team()
	var r: Dictionary = await call_fn("presence", {"p_place": current_place()})
	if r.ok and r.data is Dictionary and bool(r.data.get("other_device", false)):
		_other_device()
		return
	if r.ok and r.data is Dictionary:
		online_now = int(r.data.get("online_now", online_now))
		_take_server_time(r.data.get("server_time"))

static func current_place() -> String:
	var id: String = GameState.current_map
	if MapData.exists(id):
		var m: MapData = MapData.load_map(id)
		if m != null and not m.display_name.is_empty():
			return m.display_name
	return id.replace("_", " ").capitalize()

# --- Session file ----------------------------------------------------------------------------

func _save_session() -> void:
	var d: Dictionary = {"session": backend.session, "revs": revs, "dirty": dirty.keys(), "privacy_seen": privacy_seen,
		"actions": actions,
		"local": backend.is_local()}
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if not raw is Dictionary:
		return
	# A session from the local stand-in is useless against the real server and the other way round.
	if bool(raw.get("local", false)) == backend.is_local() and raw.get("session") is Dictionary:
		backend.session = raw.session
		for k: Variant in (raw.get("revs", {}) as Dictionary):
			revs[int(k)] = int(raw.revs[k])
		for k: Variant in (raw.get("dirty", []) as Array):
			dirty[int(k)] = true
		if raw.get("actions") is Array:
			actions = (raw.actions as Array).filter(func(a: Variant) -> bool: return a is Dictionary and a.has("id"))
	privacy_seen = bool(raw.get("privacy_seen", false))

func mark_privacy_seen() -> void:
	privacy_seen = true
	_save_session()
