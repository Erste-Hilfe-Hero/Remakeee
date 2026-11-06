extends GutTest
## Plan item 3764: the browser test build shows a "test version" band so nobody takes it for the
## finished game. The band comes from the Web preset's head include, outside the game canvas.

func test_web_preset_adds_the_test_band() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var found: bool = false
	for section: String in cfg.get_sections():
		if section.ends_with(".options") and cfg.has_section_key(section, "html/head_include"):
			var head: String = str(cfg.get_value(section, "html/head_include"))
			assert_string_contains(head, "Testversion")
			assert_string_contains(head, "pointer-events:none", "the band never takes taps from the game")
			found = true
	assert_true(found, "the Web preset has a head include")
