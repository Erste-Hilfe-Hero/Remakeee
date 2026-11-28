extends GutTest
## chimora:// deep links (DeepLink.gd): chimora://event/<id> opens the Goals screen, any other
## chimora:// link only opens the game, other schemes are ignored.

class FakeIntent extends RefCounted:
	var data: Variant
	var id: int
	func _init(d: Variant, i: int) -> void:
		data = d
		id = i
	func getDataString() -> Variant:
		return data
	func hashCode() -> int:
		return id

class FakeActivity extends RefCounted:
	var intent: Variant
	func getIntent() -> Variant:
		return intent

class FakeRuntime extends RefCounted:
	var activity: Variant
	func getActivity() -> Variant:
		return activity

func before_each() -> void:
	DeepLink.route = ""
	DeepLink.event_id = ""
	DeepLink._last_android = ""

func after_each() -> void:
	before_each()

func test_event_link() -> void:
	assert_eq(DeepLink.parse("chimora://event/spring-festival"), {"route": "event", "id": "spring-festival"})

func test_scheme_and_route_ignore_case() -> void:
	assert_eq(DeepLink.parse("CHIMORA://Event/abc_1"), {"route": "event", "id": "abc_1"})

func test_query_fragment_and_spaces_are_dropped() -> void:
	assert_eq(DeepLink.parse("  chimora://event/e42?src=appstore#top  "), {"route": "event", "id": "e42"})
	assert_eq(DeepLink.parse("chimora://event/e42/"), {"route": "event", "id": "e42"})

func test_encoded_id_is_decoded() -> void:
	assert_eq(DeepLink.parse("chimora://event/week%2D7"), {"route": "event", "id": "week-7"})

func test_other_chimora_links_just_open() -> void:
	for url: String in ["chimora://", "chimora:", "chimora://share/abc", "chimora://event",
			"chimora://event/", "chimora://event/a/b", "chimora://event/bad%20id", "chimora://event/x<y>",
			"chimora://event/" + "a".repeat(DeepLink.ID_MAX + 1)]:
		assert_eq(DeepLink.parse(url), {"route": "open"}, url)

func test_id_length_limit() -> void:
	var id: String = "a".repeat(DeepLink.ID_MAX)
	assert_eq(DeepLink.parse("chimora://event/" + id), {"route": "event", "id": id})

func test_other_schemes_are_ignored() -> void:
	for url: String in ["", "https://chimora.example/event/1", "chimoras://event/1", "://event/1",
			"mailto:event/1", "event/1"]:
		assert_eq(DeepLink.parse(url), {}, url)

func test_handle_event_waits_for_the_overworld() -> void:
	assert_true(DeepLink.handle("chimora://event/e1"))
	assert_eq(DeepLink.route, "event")
	assert_eq(DeepLink.event_id, "e1")
	assert_eq(DeepLink.take(), "event")
	assert_eq(DeepLink.take(), "")

func test_handle_open_and_foreign_links_open_no_screen() -> void:
	assert_true(DeepLink.handle("chimora://share/x"))
	assert_false(DeepLink.handle("https://example.com"))
	assert_eq(DeepLink.route, "")

func test_android_reads_intent_data_once() -> void:
	var act := FakeActivity.new()
	act.intent = FakeIntent.new("chimora://event/e1", 7)
	var rt := FakeRuntime.new()
	rt.activity = act
	assert_eq(DeepLink.android_url(rt), "chimora://event/e1")
	assert_eq(DeepLink.android_url(rt), "", "a resume with the same intent opens nothing")
	act.intent = FakeIntent.new("chimora://event/e1", 8)
	assert_eq(DeepLink.android_url(rt), "chimora://event/e1", "the same link tapped again is a new intent")

func test_android_without_link() -> void:
	var rt := FakeRuntime.new()
	assert_eq(DeepLink.android_url(rt), "")
	var act := FakeActivity.new()
	rt.activity = act
	assert_eq(DeepLink.android_url(rt), "")
	act.intent = FakeIntent.new(null, 1)
	assert_eq(DeepLink.android_url(rt), "")

func test_poll_off_mobile_does_nothing() -> void:
	DeepLink.poll()
	assert_eq(DeepLink.route, "")


func test_ios_preset_declares_the_scheme() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var plist: String = str(cfg.get_value("preset.1.options", "application/additional_plist_content", ""))
	assert_string_contains(plist, "<key>CFBundleURLSchemes</key><array><string>chimora</string></array>")
	assert_string_contains(plist, "ITSAppUsesNonExemptEncryption")

func test_android_export_adds_the_intent_filter() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	assert_has(enabled, "res://addons/chimora_deeplink/plugin.cfg")
	var filter: String = load("res://addons/chimora_deeplink/plugin.gd").INTENT_FILTER
	assert_string_contains(filter, "android.intent.action.VIEW")
	assert_string_contains(filter, "android.intent.category.BROWSABLE")
	assert_string_contains(filter, "<data android:scheme=\"chimora\" />")
