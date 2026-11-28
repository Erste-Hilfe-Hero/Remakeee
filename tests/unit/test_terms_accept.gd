extends GutTest
## The terms step (docs/legal/NUTZUNGSBEDINGUNGEN.md 2.1): before the first connection and the
## first journey, offline ones too, the player ticks "I have read and accept the Terms of Use and
## the Privacy Policy"; only then "Continue" works. The accepted version stays in the settings
## file, players with a save see it once, a new LegalInfo.TERMS_VERSION asks again.

const SETTINGS: String = "user://test_terms_settings.json"
## A 390 x 844 pt phone shows the 144 px wide screen at 390 / 144 pt per pixel.
const PT_PER_PX: float = 390.0 / 144.0

var _settings_path: String
var _terms: String
var _privacy: bool
var _lang: String
var _open_url: Callable
var _opened: Array[String] = []
var _old_backend: OnlineBackend
var _old_state: Online.State

func before_each() -> void:
	_settings_path = SaveManager.settings_path
	SaveManager.settings_path = SETTINGS
	_terms = GameState.terms_version
	_privacy = Online.privacy_seen
	_lang = GameState.language
	_open_url = MenuHost.open_url
	_opened.clear()
	MenuHost.open_url = func(url: String) -> void: _opened.append(url)
	_old_backend = Online.backend
	_old_state = Online.state
	GameState.terms_version = ""
	Online.privacy_seen = false

func after_each() -> void:
	SaveManager.settings_path = _settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameState.terms_version = _terms
	Online.privacy_seen = _privacy
	GameState.language = _lang
	MenuHost.open_url = _open_url
	Online.backend = _old_backend
	Online.state = _old_state
	Loc.set_language("en")

func _host() -> MenuHost:
	var stage := Control.new()
	stage.size = Vector2(144, 256)
	add_child_autofree(stage)
	var host := MenuHost.new()
	stage.add_child(host)
	await wait_frames(1)
	return host

func _open(host: MenuHost) -> void:
	for i: int in 60:
		if host.picker.visible and host.last_title == TitleScreen.TERMS_TITLE and host.picker._buttons.size() == 4:
			break
		await wait_frames(1)
	await wait_frames(2)

func test_needed_until_this_version_is_accepted() -> void:
	assert_true(TitleScreen.terms_needed(), "a new device, or an old one with a save, is asked")
	TitleScreen.accept_terms()
	assert_false(TitleScreen.terms_needed())
	assert_true(Online.privacy_seen, "the short privacy note stood on the same screen")
	GameState.terms_version = "2020-01"
	assert_true(TitleScreen.terms_needed(), "a newer version of the terms asks once more")

func test_accepted_version_is_kept_in_the_settings_file() -> void:
	TitleScreen.accept_terms()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	assert_eq(str((raw as Dictionary).get("terms_version")), LegalInfo.TERMS_VERSION)
	GameState.terms_version = ""
	SaveManager.load_settings()
	assert_eq(GameState.terms_version, LegalInfo.TERMS_VERSION, "read back after a restart")
	var old_file: Dictionary = GameState.settings_to_dict()
	old_file.erase("terms_version")
	GameState.settings_from_dict(old_file)
	assert_eq(GameState.terms_version, "", "a settings file from before the step means not accepted")

func test_continue_works_only_once_ticked() -> void:
	var rows: Array[Dictionary] = TitleScreen.terms_rows(false)
	assert_eq(rows.size(), 4)
	assert_eq(str(rows[TitleScreen.TermsRow.ACCEPT].text), TitleScreen.TERMS_ACCEPT)
	assert_true(bool(rows[TitleScreen.TermsRow.GO].disabled))
	assert_eq(str(rows[TitleScreen.TermsRow.GO].why), TitleScreen.TERMS_WHY, "a tap on the grey row says what to do")
	assert_false(bool(TitleScreen.terms_rows(true)[TitleScreen.TermsRow.GO].disabled))
	assert_ne(TitleScreen.check_box(true).get_image().get_data(), TitleScreen.check_box(false).get_image().get_data(), "the tick shows")

func test_step_ends_only_after_ticking_and_continue() -> void:
	var host: MenuHost = await _host()
	var done: Array = []
	var run := func() -> void:
		await TitleScreen.terms_step(host)
		done.append(true)
	run.call()
	await _open(host)
	assert_true(host.picker._buttons[TitleScreen.TermsRow.GO].disabled, "Continue waits for the tick")
	assert_true(host.picker.show_why(TitleScreen.TermsRow.GO))
	assert_eq(host.picker._hint.text, Loc.t(TitleScreen.TERMS_WHY))
	host.picker.picked.emit(TitleScreen.TermsRow.GO)
	await _open(host)
	assert_eq(done, [], "not without the tick")
	host.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _open(host)
	assert_false(host.picker._buttons[TitleScreen.TermsRow.GO].disabled)
	host.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _open(host)
	assert_true(host.picker._buttons[TitleScreen.TermsRow.GO].disabled, "a second tap takes the tick away")
	assert_true(TitleScreen.terms_needed())
	host.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _open(host)
	host.picker.picked.emit(TitleScreen.TermsRow.GO)
	await wait_frames(3)
	assert_eq(done, [true])
	assert_false(TitleScreen.terms_needed())

func test_links_open_the_page_in_the_game_language() -> void:
	var host: MenuHost = await _host()
	TitleScreen.terms_step(host)
	for lang: String in ["de", "en", "fr"]:
		Loc.set_language(lang)
		await _open(host)
		host.picker.picked.emit(TitleScreen.TermsRow.TERMS)
		await _open(host)
		host.picker.picked.emit(TitleScreen.TermsRow.PRIVACY)
		await _open(host)
	assert_eq(_opened, [LegalInfo.TERMS_URL, LegalInfo.PRIVACY_URL, LegalInfo.TERMS_URL_EN, LegalInfo.PRIVACY_URL_EN,
		LegalInfo.TERMS_URL_EN, LegalInfo.PRIVACY_URL_EN])
	assert_true(LegalInfo.TERMS_URL.ends_with("/nutzungsbedingungen") and LegalInfo.PRIVACY_URL.ends_with("/datenschutz"))
	assert_true(LegalInfo.TERMS_URL_EN.ends_with("/terms") and LegalInfo.PRIVACY_URL_EN.ends_with("/privacy"))
	assert_eq(host.toast_text(), LegalInfo.PRIVACY_URL_EN, "the link also shows, in case no browser opens")
	host.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _open(host)
	host.picker.picked.emit(TitleScreen.TermsRow.GO)
	await wait_frames(3)

## Text at least 13 pt and rows at least 44 pt high on a 390 pt phone, the whole sentence in view,
## in every language.
func test_text_and_rows_are_big_enough_in_every_language() -> void:
	var host: MenuHost = await _host()
	TitleScreen.terms_step(host)
	await _open(host)
	assert_gte(UITheme.FONT_SIZE * PT_PER_PX, 13.0)
	var screen := Rect2(Vector2.ZERO, Vector2(144, 256))
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		await wait_frames(3)
		for b: Button in host.picker._buttons:
			assert_gte(b.size.y * PT_PER_PX, 44.0, "%s: %s is finger sized" % [lang, b.text])
			assert_true(screen.encloses(b.get_global_rect()), "%s: %s on screen" % [lang, b.text])
		var accept: Button = host.picker._buttons[TitleScreen.TermsRow.ACCEPT]
		var f: Font = accept.get_theme_font("font")
		var fs: int = accept.get_theme_font_size("font_size")
		# The box stands above the sentence, so the words get the row's whole width.
		assert_eq(accept.vertical_icon_alignment, VERTICAL_ALIGNMENT_TOP)
		assert_eq(accept.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER)
		var sb: StyleBox = accept.get_theme_stylebox("normal")
		var text_w: float = accept.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
		var need: float = f.get_multiline_string_size(Loc.t(TitleScreen.TERMS_ACCEPT), HORIZONTAL_ALIGNMENT_LEFT, text_w, fs).y
		assert_gte(accept.size.y + 0.5, need + accept.icon.get_height(), "%s: the box and the whole sentence show" % lang)
		# Japanese and Chinese break between any two characters; the others only between words.
		for word: String in ([] as Array[String] if lang in ["ja", "zh_CN", "zh_TW"] else Array(Loc.t(TitleScreen.TERMS_ACCEPT).split(" "))):
			assert_lte(f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, text_w, "%s: %s fits on a line, never cut" % [lang, word])
	host.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _open(host)
	host.picker.picked.emit(TitleScreen.TermsRow.GO)
	await wait_frames(3)

func test_title_asks_before_the_server_is_contacted() -> void:
	var server := LocalBackend.new("user://test_terms_server.json")
	Online.backend = server
	Online.state = Online.State.OFFLINE
	GameState.language = "en"
	EraBoot.shown = true
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	add_child_autofree(title)
	var host: MenuHost = title._menu
	await _open(host)
	assert_eq(host.last_title, TitleScreen.TERMS_TITLE, "the first thing after the language")
	assert_true(server.session.is_empty(), "no account before the terms are accepted")
	assert_eq(host.picker._hint.text, Loc.t(TitleScreen.PRIVACY_SHORT), "the short privacy note stands under the rows")
	var screen := Rect2(Vector2.ZERO, title.get_viewport_rect().size)
	for b: Button in host.picker._buttons:
		assert_true(screen.encloses(b.get_global_rect()), "%s in view without scrolling" % b.text)
		assert_lte(b.get_global_rect().end.y, host.picker._hint.get_global_rect().position.y + 0.5, "%s above the note" % b.text)
	host.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _open(host)
	host.picker.picked.emit(TitleScreen.TermsRow.GO)
	for i: int in 300:
		if host.picker.visible and host.last_title != TitleScreen.TERMS_TITLE:
			break
		await wait_frames(1)
	assert_ne(host.last_title, TitleScreen.TERMS_TITLE)
	assert_ne(host.last_title, TitleScreen.PRIVACY_TITLE, "no second privacy note after connecting")
	assert_false(TitleScreen.terms_needed())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_terms_server.json"))
