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
const RETRY_SECONDS: float = 4.0

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

var _beat: float = 0.0
var _beats: int = 0
var _retry: float = 0.0
var _busy: bool = false
var _overlay: ReconnectOverlay
## Slots with an upload on its way, slots saved again meanwhile (value: force), and a counter
## of local saves per slot (see push()).
var _pushing: Dictionary = {}
var _push_again: Dictionary = {}
var _save_gen: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backend = make_backend()
	_load_session()
	_overlay = ReconnectOverlay.new()
	add_child(_overlay)

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
	_busy = false
	if not r.ok:
		last_error = r.error
		_set_state(State.OFFLINE)
		return state
	_take_hello(r.data)
	_save_session()
	return state

func _take_hello(d: Variant) -> void:
	if not d is Dictionary:
		return
	profile = d.get("profile", {}) if d.get("profile") is Dictionary else {}
	motd = str(d.get("motd", ""))
	online_now = int(d.get("online_now", 0))
	_take_server_time(d.get("server_time"))
	_set_state(State.UPDATE_REQUIRED if bool(d.get("update_required", false)) else State.ONLINE)

## Calls a server function. A dropped connection switches to OFFLINE (the reconnect screen
## takes over while playing).
func call_fn(name: String, args: Dictionary = {}) -> Dictionary:
	if state != State.ONLINE:
		return OnlineBackend.fail("offline", true)
	var r: Dictionary = await backend.call_fn(name, args)
	if not r.ok and r.net:
		last_error = r.error
		_set_state(State.OFFLINE)
	elif not r.ok and r.error == "not_signed_in":
		_set_state(State.OFFLINE)
	return r

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
	r = await call_fn("hello", {"p_version": CLIENT_VERSION})
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
	if not SaveManager.write_atomic(path, JSON.stringify(r.data.data, "\t")):
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
	var r: Dictionary = await call_fn("save_put", {"p_slot": slot, "p_data": d,
		"p_summary": SaveManager.summary_line(d), "p_base_rev": int(revs.get(slot, 0)), "p_force": force})
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
	if state == State.ONLINE:
		await call_fn("community_add", {"p_kind": kind, "p_amount": amount})

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
	return {"seals": GameState.rifts_sealed.size(), "seen": seen, "bonded": bonded,
		"hours": int(GameState.play_time / 3600.0)}

func _process(delta: float) -> void:
	if state == State.ONLINE:
		_overlay.hide_overlay()
		if GameState.in_game:
			_beat += delta
			if _beat >= HEARTBEAT_SECONDS:
				_beat = 0.0
				_heartbeat()
		return
	if not GameState.in_game or state == State.UPDATE_REQUIRED:
		return
	# Playing without a connection is not possible: pause and keep trying (item 7).
	_overlay.show_overlay()
	if state == State.OFFLINE and not _busy:
		_retry += delta
		if _retry >= RETRY_SECONDS:
			_retry = 0.0
			_reconnect()

func _reconnect() -> void:
	if await connect_now() == State.ONLINE:
		await push_dirty()

func _heartbeat() -> void:
	_beats += 1
	if _beats % 4 == 0:
		push_team()
	var r: Dictionary = await call_fn("presence", {"p_place": current_place()})
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
	privacy_seen = bool(raw.get("privacy_seen", false))

func mark_privacy_seen() -> void:
	privacy_seen = true
	_save_session()
