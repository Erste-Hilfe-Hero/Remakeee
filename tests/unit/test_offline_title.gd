extends GutTest
## docs/OFFLINE.md, the title: without internet the first start goes from the privacy note
## straight to the title list (New Game), with no "No connection / Try again" question and no
## option to pick; a server that does not answer cannot hold the title longer than
## TitleScreen.CONNECT_WAIT.

const SETTINGS: String = "user://test_offline_title_settings.json"

## A server that never answers the sign-in in time (a captive or very slow network).
class SlowBackend:
	extends LocalBackend
	func sign_in_anonymous() -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).create_timer(30.0).timeout
		return OnlineBackend.fail("timeout", true)

var _settings_path: String
var _terms: String
var _privacy: bool
var _lang: String
var _old_backend: OnlineBackend
var _old_state: Online.State
var _kept: Dictionary = {}

func before_all() -> void:
	for n: int in range(1, SaveManager.SLOTS + 1):
		var p: String = SaveManager.path_for_slot(n)
		if FileAccess.file_exists(p):
			_kept[p] = FileAccess.get_file_as_string(p)

func after_all() -> void:
	for p: String in _kept:
		SaveManager.write_atomic(p, _kept[p])

func before_each() -> void:
	_settings_path = SaveManager.settings_path
	SaveManager.settings_path = SETTINGS
	_terms = GameState.terms_version
	_privacy = Online.privacy_seen
	_lang = GameState.language
	_old_backend = Online.backend
	_old_state = Online.state
	GameState.terms_version = LegalInfo.TERMS_VERSION
	GameState.language = "en"
	Online.privacy_seen = false
	Online.kicked = false
	EraBoot.shown = true
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)

func after_each() -> void:
	SaveManager.settings_path = _settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameState.terms_version = _terms
	Online.privacy_seen = _privacy
	GameState.language = _lang
	Online.backend = _old_backend
	Online.state = _old_state
	Loc.set_language("en")

## Waits for the title's root list and returns its row texts (privacy note answered on the way).
func _root_rows(title: TitleScreen, frames: int) -> Array[String]:
	var host: MenuHost = title._menu
	for i: int in frames:
		await wait_frames(1)
		if host.picker.visible and host.last_title == TitleScreen.PRIVACY_TITLE:
			host.picker.picked.emit(0)
			continue
		if host.picker.visible and title._at_root:
			var out: Array[String] = []
			for b: Button in host.picker._buttons:
				out.append(b.text)
			return out
	return []

func test_first_start_offline_goes_straight_to_new_game() -> void:
	var server := LocalBackend.new()
	server.offline = true
	Online.backend = server
	Online.state = Online.State.OFFLINE
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	add_child_autofree(title)
	var rows: Array[String] = await _root_rows(title, 600)
	assert_has(rows, Loc.t("New Game"), "the journey can start offline")
	assert_does_not_have(rows, Loc.t("Try again"), "no connection question")
	assert_does_not_have(rows, Loc.t("Start offline"), "offline is no option to pick")
	assert_true(Online.privacy_seen, "the privacy note came before the first journey")
	assert_eq(title._status.text, TitleScreen.OFFLINE_STATUS)
	assert_false(get_tree().paused)

func test_a_server_that_does_not_answer_cannot_hold_the_title() -> void:
	Online.privacy_seen = true
	Online.backend = SlowBackend.new()
	Online.state = Online.State.OFFLINE
	var started: int = Time.get_ticks_msec()
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	add_child_autofree(title)
	var rows: Array[String] = await _root_rows(title, 2000)
	assert_has(rows, Loc.t("New Game"))
	assert_lt(Time.get_ticks_msec() - started, int((TitleScreen.CONNECT_WAIT + 3.0) * 1000.0), "at most CONNECT_WAIT")
	assert_eq(title._status.text, TitleScreen.OFFLINE_STATUS)
