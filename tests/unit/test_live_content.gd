extends GutTest
## Live content (docs/LIVE_CONTENT.md): signature check, data-only rules, cache and fallback,
## per-platform version compare and the "What's new" panel.

const CACHE: String = "user://test_live_content_cache.json"
const FIXTURE: String = "res://tests/fixtures/live/signed_v2.json"

var _key: CryptoKey
var _pub: String
var _kept: Dictionary
var _open: Callable
var _opened: Array[String] = []

func before_all() -> void:
	_key = Crypto.new().generate_rsa(2048)
	_pub = _key.save_to_string(true)

func before_each() -> void:
	_kept = LiveContent.data
	LiveContent.data = {}
	if FileAccess.file_exists(CACHE):
		DirAccess.remove_absolute(CACHE)
	_open = MenuHost.open_url
	_opened.clear()
	MenuHost.open_url = func(url: String) -> void: _opened.append(url)

func after_each() -> void:
	LiveContent.data = _kept
	MenuHost.open_url = _open
	if FileAccess.file_exists(CACHE):
		DirAccess.remove_absolute(CACHE)

func _sign(body: String) -> String:
	return Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, body.sha256_buffer(), _key))

func _answer(d: Dictionary) -> Dictionary:
	var body: String = JSON.stringify(d)
	return {"version": d.version, "body": body, "signature": _sign(body)}

# --- Signature -----------------------------------------------------------------------------

func test_good_signature_verifies() -> void:
	var body: String = '{"version":3}'
	assert_true(LiveContent.verify(body, _sign(body), _pub))

func test_changed_body_fails() -> void:
	var sig: String = _sign('{"version":3}')
	assert_false(LiveContent.verify('{"version":4}', sig, _pub))

func test_bad_or_missing_signature_fails() -> void:
	assert_false(LiveContent.verify('{"version":3}', "", _pub))
	assert_false(LiveContent.verify('{"version":3}', "bm90IGEgc2lnbmF0dXJl", _pub))

func test_other_key_fails() -> void:
	var body: String = '{"version":3}'
	assert_false(LiveContent.verify(body, _sign(body)), "signed with a test key, checked against the game key")

func test_game_key_loads() -> void:
	assert_eq(CryptoKey.new().load_from_string(LiveContent.PUBLIC_KEY, true), OK)

func test_patch_signed_by_publish_tool_verifies_in_game() -> void:
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_true(LiveContent.verify(str(s.body), str(s.signature)), "tools/live/publish.py and Godot agree")
	assert_eq(int(LiveContent.accept(str(s.body), str(s.signature), "1.1.0").get("version", 0)), 2)

# --- Data only -----------------------------------------------------------------------------

func test_unknown_keys_and_code_are_refused() -> void:
	assert_true(LiveContent.parse('{"version":2,"script":"x"}').is_empty())
	assert_true(LiveContent.parse('{"version":2,"events":[{"run":"res://scripts/x.gd"}]}').is_empty())
	assert_true(LiveContent.parse('{"version":2,"texts":{"en":{"a":"patch.pck"}}}').is_empty())
	assert_true(LiveContent.parse('{"version":0}').is_empty())
	assert_true(LiveContent.parse('[1]').is_empty())

func test_news_links_are_allowed() -> void:
	var d: Dictionary = LiveContent.parse('{"version":2,"news":[{"title":"Hi","url":"https://example.org/notes.zip"}]}')
	assert_eq(int(d.get("version", 0)), 2)

func test_bundled_patch_is_valid() -> void:
	var d: Dictionary = LiveContent.load_bundled()
	assert_gte(int(d.get("version", 0)), 1)
	assert_eq(LiveContent.platform_version(d, "min_client", "ios"), "0", "nobody is locked out by the bundled data")
	assert_eq(LiveContent.platform_version(d, "min_client", "android"), "0")

# --- Cache and fallback --------------------------------------------------------------------

func test_verified_patch_is_taken_and_cached() -> void:
	assert_true(LiveContent.take(_answer({"version": 5, "news": []}), "1.1.0", CACHE, _pub))
	assert_eq(LiveContent.version(), 5)
	assert_eq(int(LiveContent.load_cache(CACHE, "1.1.0", _pub).get("version", 0)), 5)

func test_unsigned_patch_keeps_the_old_one() -> void:
	LiveContent.data = LiveContent.load_bundled()
	var a: Dictionary = _answer({"version": 9})
	a.signature = _sign('{"version":8}')
	assert_false(LiveContent.take(a, "1.1.0", CACHE, _pub))
	assert_eq(LiveContent.version(), LiveContent.load_bundled().version)
	assert_false(FileAccess.file_exists(CACHE))

func test_older_patch_is_ignored() -> void:
	LiveContent.data = {"version": 7}
	assert_false(LiveContent.take(_answer({"version": 6}), "1.1.0", CACHE, _pub))
	assert_eq(LiveContent.version(), 7)

func test_tampered_cache_falls_back() -> void:
	LiveContent.take(_answer({"version": 5}), "1.1.0", CACHE, _pub)
	var f: FileAccess = FileAccess.open(CACHE, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(CACHE).replace("5", "6"))
	f.close()
	assert_true(LiveContent.load_cache(CACHE, "1.1.0", _pub).is_empty())

func test_missing_cache_is_empty() -> void:
	assert_true(LiveContent.load_cache(CACHE, "1.1.0", _pub).is_empty())

func test_patch_for_newer_game_is_skipped() -> void:
	assert_false(LiveContent.take(_answer({"version": 5, "requires": "2.0.0"}), "1.1.0", CACHE, _pub))
	assert_true(LiveContent.take(_answer({"version": 5, "requires": "1.1.0"}), "1.1.0", CACHE, _pub))

func test_no_answer_changes_nothing() -> void:
	LiveContent.data = {"version": 3}
	assert_false(LiveContent.take({"version": 0}, "1.1.0", CACHE, _pub))
	assert_false(LiveContent.take(null, "1.1.0", CACHE, _pub))
	assert_eq(LiveContent.version(), 3)

# --- Versions ------------------------------------------------------------------------------

func test_compare_versions() -> void:
	assert_eq(LiveContent.compare_versions("1.1.0", "1.1.0"), 0)
	assert_eq(LiveContent.compare_versions("1.1", "1.1.0"), 0)
	assert_eq(LiveContent.compare_versions("1.9.0", "1.10.0"), -1)
	assert_eq(LiveContent.compare_versions("2.0.0", "1.99.99"), 1)
	assert_eq(LiveContent.compare_versions("1.1.0", "0"), 1)

func test_update_state_per_platform() -> void:
	var c: Dictionary = {"min_client": {"ios": "1.2.0", "android": "0"}, "latest": {"ios": "1.2.0", "android": "1.3.0"}}
	assert_eq(LiveContent.update_state(c, "ios", "1.1.0"), "required")
	assert_eq(LiveContent.update_state(c, "android", "1.1.0"), "optional", "the iOS minimum does not lock out Android")
	assert_eq(LiveContent.update_state(c, "android", "1.3.0"), "none")
	assert_eq(LiveContent.update_state(c, "", "0.1.0"), "none", "desktop and browser never ask")

func test_missing_fields_lock_nobody_out() -> void:
	assert_eq(LiveContent.update_state({}, "ios", "1.0.0"), "none")
	assert_eq(LiveContent.update_state({}, "android", "1.0.0"), "none")

func test_store_version_makes_update_optional() -> void:
	assert_eq(LiveContent.update_state({}, "ios", "1.1.0", "1.2.0"), "optional")
	assert_eq(LiveContent.update_state({}, "ios", "1.2.0", "1.2.0"), "none")

func test_itunes_lookup_answer() -> void:
	assert_eq(LiveContent.itunes_version('{"resultCount":1,"results":[{"version":"1.2.0","trackId":6831632885}]}'), "1.2.0")
	assert_eq(LiveContent.itunes_version('{"resultCount":0,"results":[]}'), "")
	assert_eq(LiveContent.itunes_version("oops"), "")

func test_client_version_name_matches_export_presets() -> void:
	var text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var re := RegEx.create_from_string("version/name=\"([^\"]*)\"")
	for m: RegExMatch in re.search_all(text):
		assert_eq(m.get_string(1), Online.CLIENT_VERSION_NAME)

func test_ios_store_link_names_the_app() -> void:
	assert_true(Online.ITUNES_LOOKUP.ends_with("6831632885"))

# --- What's new ----------------------------------------------------------------------------

func test_news_texts_follow_the_language() -> void:
	LiveContent.data = {"version": 2, "news": [{"date": "2026-11-01", "title": {"en": "Old", "de": "Alt"}},
		{"date": "2026-11-10", "title": {"en": "New", "de": "Neu"}, "url": "https://example.org"}]}
	assert_eq(LiveContent.news()[0].title, "New")
	Loc.set_language("de")
	assert_eq(LiveContent.news()[0].title, "Neu")
	Loc.set_language("en")

func test_news_panel_lists_news_and_discord() -> void:
	LiveContent.data = {"version": 2, "news": [{"date": "2026-11-10", "title": "Patch 1.2", "body": "Fixes."}]}
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var done: Array[bool] = [false]
	var runner := func() -> void:
		await host.run_news()
		done[0] = true
	runner.call()
	await wait_process_frames(1)
	assert_true(host.last_rows.has("Patch 1.2"))
	assert_true(host.last_rows.has("Join our Discord"))
	host.picker.picked.emit(host.last_rows.find("Join our Discord"))
	await wait_process_frames(2)
	assert_eq(_opened, [MenuHost.DISCORD_URL] as Array[String])
	host.picker.picked.emit(-1)
	await wait_process_frames(2)
	assert_true(done[0])

func test_panel_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	for s: String in ["What's new", "Update", "Later", "Open the link?", "A new version of Chimora is out."]:
		assert_true(de.has(s), s)
