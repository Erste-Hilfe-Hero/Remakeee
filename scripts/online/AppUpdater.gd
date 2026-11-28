class_name AppUpdater
extends Node
## Runs the in-game update (docs/LIVE_CONTENT.md, "In-game updates"). Lives under Online as
## Online.updater. AppUpdate.choose() picks the path; this node talks to the Play plugin
## (ChimoraAppUpdate, plugins/chimora_appupdate), downloads the itch.io APK and drives UpdatePanel.

const SINGLETON: String = "ChimoraAppUpdate"
const INFO_TIMEOUT: float = 8.0
## Google's update screen hands back its result when the game is in front again.
const FLOW_TIMEOUT: float = 1800.0

const TEXT_STORE: String = "A new version of Chimora is out."
const TEXT_STORE_REQUIRED: String = "A new version of Chimora is out. Please update it in the store to keep playing."
const TEXT_PLAY: String = "Google Play is updating Chimora."
const TEXT_FLEX: String = "Downloading the update. You can keep playing."
const TEXT_FLEX_REQUIRED: String = "Downloading the update. Chimora restarts when it is ready."
const TEXT_READY: String = "The update is ready. Restart Chimora to finish it."
const TEXT_PLAY_FAILED: String = "The update did not finish. Please try again."
const TEXT_APK: String = "Downloading the new version of Chimora."
const TEXT_APK_DONE: String = "Download complete. Tap Install and confirm it. If Android asks, allow Chimora to install apps."
const TEXT_APK_FAILED: String = "The download failed. Check your connection and try again."

var panel: UpdatePanel
## Opens a link; tests replace it.
var open_url: Callable = func(url: String) -> void: MenuHost.open_url.call(url)
## Hands a downloaded APK to the system installer; tests replace it.
var install_apk: Callable = func(path: String) -> int: return OS.shell_open(ProjectSettings.globalize_path(path))
var busy: bool = false
var _p: Object
var _answers: Dictionary = {}
var _apk: HTTPRequest
var _ready_shown: bool = false

## [param plugin] is the Android singleton, or a stand-in in tests.
func _init(plugin: Object = null) -> void:
	_p = plugin

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _p == null and Engine.has_singleton(SINGLETON):
		_p = Engine.get_singleton(SINGLETON)
	if _p != null and _p.has_signal("update_event"):
		_p.connect("update_event", _on_event)
	panel = UpdatePanel.new()
	add_child(panel)

func has_play_api() -> bool:
	return _p != null

func installer() -> String:
	return str(_p.call("installer")) if _p != null else ""

func _on_event(text: String) -> void:
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return
	var kind: String = str(d.get("kind", ""))
	_answers[kind] = d
	if kind == "progress":
		_on_progress(d)

func _wait(kind: String, seconds: float) -> Dictionary:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not _answers.has(kind) and Time.get_ticks_msec() < until and is_inside_tree():
		await get_tree().process_frame
	return _answers.get(kind, {})

## Play's answer for this copy, {} without the Play API or when Play does not answer.
func play_info() -> Dictionary:
	if _p == null:
		return {}
	_answers.erase("info")
	_p.call("check")
	return await _wait("info", INFO_TIMEOUT)

## Everything AppUpdate.choose() needs, for [param state] ("required", "optional" or "none").
func context(state: String) -> Dictionary:
	var plat: String = LiveContent.platform()
	var ctx: Dictionary = {"platform": plat, "state": state, "itch": OS.has_feature("itch"),
		"installer": installer(), "apk": AppUpdate.apk_url(LiveContent.data), "play": {}}
	if plat == "android" and not AppUpdate.can_sideload(ctx.itch, ctx.installer):
		ctx.play = await play_info()
	return ctx

## Checks for an update and shows the panel when there is one. Returns the path it took
## (AppUpdate.NONE when nothing was shown). A required update keeps the panel to the caller,
## which tries again (TitleScreen).
func offer(state: String) -> String:
	if busy:
		return AppUpdate.NONE
	busy = true
	var path: String = AppUpdate.choose(await context(state))
	await run(path, state == "required")
	busy = false
	return path

func run(path: String, required: bool) -> void:
	match path:
		AppUpdate.APP_STORE:
			await _store(AppUpdate.app_store_url(Online.APP_STORE_ID), required)
		AppUpdate.STORE_LINK:
			await _store(Online.store_url(), required)
		AppUpdate.PLAY_IMMEDIATE:
			await _play(true, required)
		AppUpdate.PLAY_FLEXIBLE:
			await _play(false, required)
		AppUpdate.PLAY_RESTART:
			await _restart_prompt(required)
		AppUpdate.APK_DOWNLOAD:
			await _download(AppUpdate.apk_url(LiveContent.data), required)

func _ask(body: String, buttons: Array[String]) -> int:
	panel.show_view(body, buttons)
	return await panel.chosen

func _store(url: String, required: bool) -> void:
	var second: String = "Try again" if required else "Later"
	var pick: int = await _ask(TEXT_STORE_REQUIRED if required else TEXT_STORE, ["Update", second] as Array[String])
	panel.close()
	if pick == 0:
		open_url.call(url)

## Google's update screen. Immediate: full screen, Play restarts the game when done. Flexible:
## the player agrees, Play downloads in the background, then "Restart now".
func _play(immediate: bool, required: bool) -> void:
	panel.show_view(TEXT_PLAY, [])
	_answers.erase("flow")
	if not bool(_p.call("start", immediate)):
		await _store(Online.store_url(), required)
		return
	var flow: Dictionary = await _wait("flow", FLOW_TIMEOUT)
	var result: int = int(flow.get("result", AppUpdate.RESULT_CANCELED))
	if result != AppUpdate.RESULT_OK:
		if required:
			await _ask(TEXT_PLAY_FAILED, ["Try again"] as Array[String])
		panel.close()
		return
	if immediate:
		return
	_ready_shown = false
	if not required:
		panel.show_view(TEXT_FLEX, ["Keep playing"] as Array[String])
		await panel.chosen
		panel.close()
		return
	panel.show_view(TEXT_FLEX_REQUIRED, [])
	while is_inside_tree() and panel.visible:
		await get_tree().process_frame

func _on_progress(d: Dictionary) -> void:
	var status: int = int(d.get("status", 0))
	var bytes: int = int(d.get("bytes", 0))
	var total: int = int(d.get("total", 0))
	if status == AppUpdate.STATUS_DOWNLOADING and panel.visible:
		panel.set_progress(AppUpdate.progress(bytes, total), AppUpdate.size_text(bytes, total))
	elif status == AppUpdate.STATUS_DOWNLOADED and not _ready_shown:
		_ready_shown = true
		_restart_prompt(false)
	elif status == AppUpdate.STATUS_FAILED or status == AppUpdate.STATUS_CANCELED:
		panel.close()

func _restart_prompt(required: bool) -> void:
	panel.hide_progress()
	var buttons: Array[String] = ["Restart now"]
	if not required:
		buttons.append("Later")
	if await _ask(TEXT_READY, buttons) == 0:
		panel.show_view(TEXT_PLAY, [])
		if GameState.in_game:
			await Online.push_dirty()
		_p.call("complete")
	else:
		panel.close()

## itch.io build: downloads the APK into user:// with a progress bar, then the system installer.
func _download(url: String, required: bool) -> void:
	var path: String = "user://update/" + AppUpdate.apk_file_name(url)
	DirAccess.make_dir_recursive_absolute("user://update")
	while true:
		var cancel: Array[String] = []
		if not required:
			cancel.append("Cancel")
		panel.show_view(TEXT_APK, cancel)
		panel.set_progress(-1.0, "")
		_apk = HTTPRequest.new()
		_apk.download_file = path
		_apk.timeout = 0.0
		add_child(_apk)
		var cancelled: Array[bool] = [false]
		var on_cancel: Callable = func(_i: int) -> void:
			cancelled[0] = true
			_apk.cancel_request()
			_apk.request_completed.emit(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
		panel.chosen.connect(on_cancel, CONNECT_ONE_SHOT)
		var res: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0]
		if _apk.request(url) == OK:
			res = await _apk.request_completed
		if panel.chosen.is_connected(on_cancel):
			panel.chosen.disconnect(on_cancel)
		_apk.queue_free()
		_apk = null
		if cancelled[0]:
			panel.close()
			return
		if int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) == 200:
			break
		var again: Array[String] = ["Try again"]
		if not required:
			again.append("Later")
		panel.hide_progress()
		if await _ask(TEXT_APK_FAILED, again) != 0:
			panel.close()
			return
	panel.set_progress(1.0, "")
	install_apk.call(path)
	var buttons: Array[String] = ["Install"]
	if not required:
		buttons.append("Later")
	while await _ask(TEXT_APK_DONE, buttons) == 0:
		install_apk.call(path)
		if not required:
			break
	panel.close()

func _process(_delta: float) -> void:
	if _apk != null and panel.visible:
		var bytes: int = _apk.get_downloaded_bytes()
		var total: int = _apk.get_body_size()
		panel.set_progress(AppUpdate.progress(bytes, total), AppUpdate.size_text(bytes, total))

## Back from the background: Google's update screen that was started goes on, and a finished
## flexible download asks for the restart (Play's guidance). A full check only on the title.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _p != null and not busy and AppUpdate.from_play(installer()):
		_on_resumed()

func _on_resumed() -> void:
	busy = true
	var info: Dictionary = await play_info()
	var path: String = AppUpdate.play_path(info) if bool(info.get("ok", false)) else AppUpdate.NONE
	if path == AppUpdate.PLAY_RESTART or (path == AppUpdate.PLAY_IMMEDIATE and bool(info.get("in_progress", false))):
		await run(path, false)
	elif path != AppUpdate.NONE and not GameState.in_game:
		await run(path, Online.update_state() == "required")
	busy = false
