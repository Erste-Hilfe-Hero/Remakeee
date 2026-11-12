extends GutTest
## APK size budget (docs/RELEASE.md): the debug APK compresses the engine library, and the
## Android presets leave dev-only folders out of the package.

const DEV_ONLY: Array[String] = ["tests/*", "tools/*", "docs/*", "store/*", "server/*", "supabase/*", "live/*"]

func _presets() -> Dictionary:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var out: Dictionary = {}
	for s: String in cfg.get_sections():
		if s.begins_with("preset.") and not s.ends_with(".options"):
			out[str(cfg.get_value(s, "name", ""))] = {"main": s, "options": s + ".options", "cfg": cfg}
	return out

func test_debug_apk_compresses_native_libraries() -> void:
	var p: Dictionary = _presets()["Android APK (debug)"]
	var cfg: ConfigFile = p.cfg
	assert_true(bool(cfg.get_value(p.options, "gradle_build/compress_native_libraries", false)))

func test_android_presets_leave_out_dev_folders() -> void:
	var all: Dictionary = _presets()
	for name: String in ["Android", "Android APK (debug)"]:
		var p: Dictionary = all[name]
		var cfg: ConfigFile = p.cfg
		var filters: PackedStringArray = str(cfg.get_value(p.main, "exclude_filter", "")).split(",")
		var trimmed: Array[String] = []
		for f: String in filters:
			trimmed.append(f.strip_edges())
		for dev: String in DEV_ONLY:
			assert_true(dev in trimmed, "%s leaves out %s" % [name, dev])
