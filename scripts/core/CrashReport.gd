class_name CrashReport
extends RefCounted
## Anonymous crash report (200 list item 184). A small mark file says "the game is running"; it is
## removed whenever the app goes to the background or closes and written again when it is back.
## A mark still there on the next start means the last run ended unexpectedly, and one short
## report is kept: game version, platform and the last scene. No account id, no name, no save.
## The server needs the sign-in only to stop one phone from flooding it (rate limit) and stores the
## report without the account. It is sent only when the server switches it on with the feature flag
## FLAG; until then nothing leaves the phone and the kept report is replaced by the next one.

const MARK_PATH: String = "user://session_mark.json"
const PENDING_PATH: String = "user://crash_report.json"
## Feature flag from hello that switches sending on (supabase feature_flags).
const FLAG: String = "crash_report"
## Server function (/rest/v1/rpc/crash_report) that takes p_version, p_platform, p_scene.
const FN: String = "crash_report"
const MAX_LEN: int = 40
## Shown with the privacy note in Settings, Account.
const PRIVACY_LINE: String = "If the game ended unexpectedly, it sends one short anonymous crash report next time: only the game version, the device system and the last scene, never your account."

static var mark_path: String = MARK_PATH
static var pending_path: String = PENDING_PATH
static var version: String = ""
static var scene: String = "start"
static var in_battle: bool = false
static var _running: bool = false

## Called once at app start: keeps a report when the last run left its mark, then marks this run.
static func begin(p_version: String) -> void:
	version = p_version
	var old: Dictionary = _read(mark_path)
	if not old.is_empty():
		_write(pending_path, report_for(old))
	_running = true
	_mark()

## The app goes to the background or closes: a kill from here on is not a crash.
static func app_left() -> void:
	_running = false
	if FileAccess.file_exists(mark_path):
		DirAccess.remove_absolute(mark_path)

## The app is back in front.
static func app_back() -> void:
	if version.is_empty():
		return
	_running = true
	_mark()

## The current scene changed (file name without folder and extension).
static func enter_scene(p_scene: String) -> void:
	scene = p_scene
	_mark()

## A battle screen opened or closed.
static func set_battle(on: bool) -> void:
	in_battle = on
	_mark()

## "battle" while a battle screen is open, else the scene name.
static func place() -> String:
	return "battle" if in_battle else scene

## The report kept from [param mark]: only version, platform and scene, each cut to MAX_LEN.
static func report_for(mark: Dictionary) -> Dictionary:
	return {
		"version": str(mark.get("version", "")).left(MAX_LEN),
		"platform": str(mark.get("platform", "")).left(MAX_LEN),
		"scene": str(mark.get("scene", "")).left(MAX_LEN),
	}

## The kept report, or {} when the last run ended normally.
static func pending() -> Dictionary:
	return _read(pending_path)

static func clear_pending() -> void:
	if FileAccess.file_exists(pending_path):
		DirAccess.remove_absolute(pending_path)

## Arguments for FN.
static func args_for(report: Dictionary) -> Dictionary:
	return {"p_version": str(report.get("version", "")), "p_platform": str(report.get("platform", "")),
		"p_scene": str(report.get("scene", ""))}

## Sends the kept report once through [param backend] when [param flag_on] (the server supports
## it). Clears it after any answer from the server; keeps it when the connection dropped.
static func send(backend: OnlineBackend, flag_on: bool) -> void:
	var p: Dictionary = pending()
	if p.is_empty() or not flag_on:
		return
	var r: Dictionary = await backend.call_fn(FN, args_for(p))
	if r.ok or not r.net:
		clear_pending()

## Forgets the state (tests).
static func reset() -> void:
	mark_path = MARK_PATH
	pending_path = PENDING_PATH
	version = ""
	scene = "start"
	in_battle = false
	_running = false

static func _mark() -> void:
	if _running:
		_write(mark_path, {"version": version, "platform": OS.get_name(), "scene": place()})

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}

static func _write(path: String, d: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
