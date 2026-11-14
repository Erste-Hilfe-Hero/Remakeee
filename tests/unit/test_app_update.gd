extends GutTest
## In-game updates (docs/LIVE_CONTENT.md, "In-game updates"): which path each platform and
## installer takes, the itch.io APK link, the presets and the plugin, and the update panel.

const PLAY_INFO: Dictionary = {"ok": true, "available": true, "in_progress": false, "downloaded": false,
	"immediate": true, "flexible": true, "version_code": 1005}
const APK: String = "https://example.org/releases/Chimora-1.3.0.apk"

## Stand-in for the Android singleton ChimoraAppUpdate.
class FakePlay extends RefCounted:
	signal update_event(text: String)
	var who: String = AppUpdate.PLAY_STORE
	var flow_result: int = AppUpdate.RESULT_CANCELED
	var starts: Array[bool] = []
	var completed: int = 0

	func installer() -> String:
		return who

	func check() -> void:
		update_event.emit(JSON.stringify({"kind": "info", "ok": true, "available": true, "immediate": true}))

	func start(immediate: bool) -> bool:
		starts.append(immediate)
		update_event.emit(JSON.stringify({"kind": "flow", "result": flow_result}))
		return true

	func complete() -> void:
		completed += 1

func _ctx(over: Dictionary) -> Dictionary:
	var c: Dictionary = {"platform": "android", "state": "none", "installer": AppUpdate.PLAY_STORE,
		"itch": false, "play": {}, "apk": ""}
	c.merge(over, true)
	return c

func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate()
	d.merge(over, true)
	return d

# --- Version compare -----------------------------------------------------------------------

func test_versions_compare_part_by_part() -> void:
	assert_eq(LiveContent.compare_versions("1.2.0", "1.10.0"), -1)
	assert_eq(LiveContent.compare_versions("1.10.0", "1.9.9"), 1)
	assert_eq(LiveContent.compare_versions("1.2", "1.2.0"), 0)

func test_live_content_state_feeds_the_panel() -> void:
	var c: Dictionary = {"min_client": {"android": "1.1.0"}, "latest": {"android": "1.3.0", "ios": "1.2.0"}}
	assert_eq(LiveContent.update_state(c, "android", "1.2.0"), "optional")
	assert_eq(LiveContent.update_state(c, "android", "1.0.0"), "required")
	assert_eq(LiveContent.update_state(c, "ios", "1.2.0"), "none")
	assert_eq(LiveContent.update_state(c, "ios", "1.2.0", "1.2.1"), "optional", "App Store lookup is newer")

# --- Android from Google Play --------------------------------------------------------------

func test_play_newer_version_starts_immediate_even_without_live_content() -> void:
	assert_eq(AppUpdate.choose(_ctx({"play": PLAY_INFO})), AppUpdate.PLAY_IMMEDIATE)
	assert_eq(AppUpdate.choose(_ctx({"play": PLAY_INFO, "state": "required"})), AppUpdate.PLAY_IMMEDIATE)

func test_play_flexible_when_immediate_is_not_allowed() -> void:
	assert_eq(AppUpdate.choose(_ctx({"play": _with(PLAY_INFO, {"immediate": false})})), AppUpdate.PLAY_FLEXIBLE)

func test_play_neither_type_allowed_falls_back() -> void:
	var play: Dictionary = _with(PLAY_INFO, {"immediate": false, "flexible": false})
	assert_eq(AppUpdate.choose(_ctx({"play": play})), AppUpdate.NONE)
	assert_eq(AppUpdate.choose(_ctx({"play": play, "state": "required"})), AppUpdate.STORE_LINK)

func test_play_update_in_progress_resumes_and_downloaded_asks_restart() -> void:
	assert_eq(AppUpdate.choose(_ctx({"play": _with(PLAY_INFO, {"available": false, "in_progress": true})})), AppUpdate.PLAY_IMMEDIATE)
	assert_eq(AppUpdate.choose(_ctx({"play": _with(PLAY_INFO, {"available": false, "downloaded": true})})), AppUpdate.PLAY_RESTART)

func test_play_has_nothing_newer_yet() -> void:
	var play: Dictionary = _with(PLAY_INFO, {"available": false})
	assert_eq(AppUpdate.choose(_ctx({"play": play, "state": "optional"})), AppUpdate.NONE, "staged rollout: Play knows best")
	assert_eq(AppUpdate.choose(_ctx({"play": play, "state": "required"})), AppUpdate.STORE_LINK)

func test_no_play_api_uses_the_store_link_dialog() -> void:
	assert_eq(AppUpdate.choose(_ctx({"state": "optional"})), AppUpdate.STORE_LINK)
	assert_eq(AppUpdate.choose(_ctx({"state": "required", "play": {"ok": false, "error": "ERROR_APP_NOT_OWNED"}})), AppUpdate.STORE_LINK)
	assert_eq(AppUpdate.choose(_ctx({"state": "none"})), AppUpdate.NONE)

# --- Android itch.io build -----------------------------------------------------------------

func test_itch_build_downloads_the_apk() -> void:
	var c: Dictionary = _ctx({"itch": true, "installer": "com.android.chrome", "state": "optional", "apk": APK})
	assert_eq(AppUpdate.choose(c), AppUpdate.APK_DOWNLOAD)
	assert_eq(AppUpdate.choose(_with(c, {"installer": ""})), AppUpdate.APK_DOWNLOAD, "unknown installer")
	assert_eq(AppUpdate.choose(_with(c, {"state": "none"})), AppUpdate.NONE)
	assert_eq(AppUpdate.choose(_with(c, {"apk": ""})), AppUpdate.STORE_LINK, "no APK link: store-link dialog")

func test_itch_build_ignores_play_answers() -> void:
	var c: Dictionary = _ctx({"itch": true, "installer": "com.google.android.packageinstaller", "play": PLAY_INFO})
	assert_eq(AppUpdate.choose(c), AppUpdate.NONE)

func test_installed_by_play_never_downloads_an_apk() -> void:
	var c: Dictionary = _ctx({"itch": true, "state": "optional", "apk": APK})
	assert_false(AppUpdate.can_sideload(true, AppUpdate.PLAY_STORE))
	assert_eq(AppUpdate.choose(c), AppUpdate.STORE_LINK)
	assert_eq(AppUpdate.choose(_with(c, {"play": PLAY_INFO})), AppUpdate.PLAY_IMMEDIATE)

func test_play_build_sideloaded_never_downloads_an_apk() -> void:
	assert_false(AppUpdate.can_sideload(false, "com.android.chrome"))
	var c: Dictionary = _ctx({"installer": "com.android.chrome", "state": "optional", "apk": APK})
	assert_eq(AppUpdate.choose(c), AppUpdate.STORE_LINK)

func test_apk_link_from_live_content() -> void:
	assert_eq(AppUpdate.apk_url({"latest": {"android": "1.3.0", "android_apk": APK}}), APK)
	assert_eq(AppUpdate.apk_url({"latest": {"android_apk": "http://example.org/a.apk"}}), "")
	assert_eq(AppUpdate.apk_url({"latest": {"android_apk": "https://example.org/a.zip"}}), "")
	assert_eq(AppUpdate.apk_url({"latest": "1.3.0"}), "")
	assert_eq(AppUpdate.apk_url({}), "")

func test_apk_link_passes_the_data_only_check() -> void:
	assert_false(LiveContent.has_code({"latest": {"android_apk": APK}}))

func test_apk_file_name_is_safe() -> void:
	assert_eq(AppUpdate.apk_file_name(APK), "Chimora-1.3.0.apk")
	assert_eq(AppUpdate.apk_file_name("https://example.org/dl/x.apk?token=1"), "x.apk")
	assert_eq(AppUpdate.apk_file_name("https://example.org/dl/../a b.apk"), "a_b.apk")
	assert_eq(AppUpdate.apk_file_name("https://example.org/download"), "chimora-update.apk")

func test_progress_and_size_line() -> void:
	assert_eq(AppUpdate.progress(50, 200), 0.25)
	assert_eq(AppUpdate.progress(10, 0), -1.0)
	assert_eq(AppUpdate.progress(300, 200), 1.0)
	assert_eq(AppUpdate.size_text(1048576, 4194304), "1.0 / 4.0 MB")
	assert_eq(AppUpdate.size_text(1048576, -1), "1.0 MB")

# --- iOS and desktop -----------------------------------------------------------------------

func test_ios_opens_the_app_store_never_a_download() -> void:
	assert_eq(AppUpdate.choose({"platform": "ios", "state": "optional", "apk": APK, "itch": true}), AppUpdate.APP_STORE)
	assert_eq(AppUpdate.choose({"platform": "ios", "state": "required"}), AppUpdate.APP_STORE)
	assert_eq(AppUpdate.choose({"platform": "ios", "state": "none", "play": PLAY_INFO}), AppUpdate.NONE)
	assert_eq(AppUpdate.app_store_url(Online.APP_STORE_ID), "itms-apps://apps.apple.com/app/id6831632885")

func test_desktop_and_browser_show_nothing() -> void:
	assert_eq(AppUpdate.choose({"platform": "", "state": "required", "play": PLAY_INFO}), AppUpdate.NONE)

# --- Presets and plugin ----------------------------------------------------------------------

func _android_presets() -> Dictionary:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var out: Dictionary = {}
	for s: String in cfg.get_sections():
		if not s.ends_with(".options") and str(cfg.get_value(s, "platform", "")) == "Android":
			out[str(cfg.get_value(s, "name", ""))] = {"features": str(cfg.get_value(s, "custom_features", "")),
				"install": "android.permission.REQUEST_INSTALL_PACKAGES" in cfg.get_value(s + ".options", "permissions/custom_permissions", PackedStringArray()),
				"custom": cfg.get_value(s + ".options", "permissions/custom_permissions", PackedStringArray())}
	return out

func test_only_the_itch_preset_may_install_apks() -> void:
	var all: Dictionary = _android_presets()
	assert_eq(all.size(), 3)
	for name: String in all:
		var p: Dictionary = all[name]
		var itch: bool = "itch" in p.features.split(",")
		assert_eq(p.install, itch, name)
		assert_eq((p.custom as PackedStringArray).size(), 1 if itch else 0, name)
	assert_true(all["Android (itch)"].install)
	assert_false(all["Android"].install, "the Play build updates through Google Play only")

func test_app_update_plugin_goes_into_android_exports() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	assert_has(enabled, "res://addons/chimora_appupdate/plugin.cfg")
	var dep: String = load("res://addons/chimora_appupdate/plugin.gd").APP_UPDATE
	assert_eq(dep, "com.google.android.play:app-update:2.1.0")
	var gradle: String = FileAccess.get_file_as_string("res://plugins/chimora_appupdate/android/build.gradle")
	assert_string_contains(gradle, "com.google.android.play:app-update:")
	assert_string_contains(gradle, "'2.1.0'")
	assert_string_contains(FileAccess.get_file_as_string("res://tools/build_appupdate_plugin.sh"), "-PappUpdateVersion=2.1.0")

# --- Update panel ----------------------------------------------------------------------------

func _updater(fake: FakePlay) -> AppUpdater:
	var u := AppUpdater.new(fake)
	add_child_autofree(u)
	return u

func test_store_link_opens_on_update() -> void:
	var u: AppUpdater = _updater(null)
	var opened: Array[String] = []
	u.open_url = func(url: String) -> void: opened.append(url)
	u.run(AppUpdate.APP_STORE, false)
	assert_true(u.panel.visible)
	assert_eq(u.panel.button_texts(), ["Update", "Later"] as Array[String])
	u.panel.chosen.emit(0)
	assert_eq(opened, ["itms-apps://apps.apple.com/app/id6831632885"] as Array[String])
	assert_false(u.panel.visible)

func test_required_store_link_offers_try_again() -> void:
	var u: AppUpdater = _updater(null)
	var opened: Array[String] = []
	u.open_url = func(url: String) -> void: opened.append(url)
	u.run(AppUpdate.STORE_LINK, true)
	assert_eq(u.panel.button_texts(), ["Update", "Try again"] as Array[String])
	u.panel.chosen.emit(1)
	assert_eq(opened.size(), 0)

func test_play_immediate_cancelled_closes_the_panel() -> void:
	var fake := FakePlay.new()
	var u: AppUpdater = _updater(fake)
	await u.run(AppUpdate.PLAY_IMMEDIATE, false)
	assert_eq(fake.starts, [true] as Array[bool])
	assert_false(u.panel.visible)

func test_play_flexible_shows_progress_then_restart() -> void:
	var fake := FakePlay.new()
	fake.flow_result = AppUpdate.RESULT_OK
	var u: AppUpdater = _updater(fake)
	u.run(AppUpdate.PLAY_FLEXIBLE, false)
	assert_eq(fake.starts, [false] as Array[bool])
	assert_eq(u.panel.button_texts(), ["Keep playing"] as Array[String])
	fake.update_event.emit(JSON.stringify({"kind": "progress", "status": AppUpdate.STATUS_DOWNLOADING, "bytes": 5, "total": 10}))
	assert_eq(u.panel._bar.value, 0.5)
	fake.update_event.emit(JSON.stringify({"kind": "progress", "status": AppUpdate.STATUS_DOWNLOADED, "bytes": 10, "total": 10}))
	assert_eq(u.panel.button_texts(), ["Restart now", "Later"] as Array[String])
	u.panel.chosen.emit(0)
	assert_eq(fake.completed, 1)

func test_offer_on_desktop_shows_nothing() -> void:
	var u: AppUpdater = _updater(FakePlay.new())
	assert_eq(await u.offer("required"), AppUpdate.NONE)
	assert_false(u.panel.visible)

func test_panel_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	for s: String in [AppUpdater.TEXT_PLAY, AppUpdater.TEXT_FLEX, AppUpdater.TEXT_FLEX_REQUIRED, AppUpdater.TEXT_READY,
			AppUpdater.TEXT_PLAY_FAILED, AppUpdater.TEXT_APK, AppUpdater.TEXT_APK_DONE, AppUpdater.TEXT_APK_FAILED,
			AppUpdater.TEXT_STORE, AppUpdater.TEXT_STORE_REQUIRED, "Update available", "Keep playing", "Restart now", "Install", "Cancel"]:
		assert_true(de.has(s), s)
