extends GutTest
## The 14 languages: every table loads, every letter is drawn (own pixel glyphs for Latin and
## Cyrillic, the CJK pixel fonts for Japanese, Korean and Chinese), device locales map to a game
## language and the menu rows fit in every language.

func after_all() -> void:
	Loc.set_language("en")

func test_fourteen_languages_with_their_own_names() -> void:
	assert_eq(Loc.LANGUAGES.size(), 14)
	for code: String in Loc.LANGUAGES:
		assert_true(Loc.LANGUAGE_NAMES.has(code), "name for " + code)
		if code != "en":
			assert_false(Loc.load_table(code).is_empty(), "table for " + code)

func test_device_locales_pick_a_language() -> void:
	assert_eq(Loc.language_for_locale("de_AT"), "de")
	assert_eq(Loc.language_for_locale("fr_CA"), "fr")
	assert_eq(Loc.language_for_locale("pt_PT"), "pt_BR")
	assert_eq(Loc.language_for_locale("zh_TW"), "zh_TW")
	assert_eq(Loc.language_for_locale("zh_Hant_HK"), "zh_TW")
	assert_eq(Loc.language_for_locale("zh_Hans_CN"), "zh_CN")
	assert_eq(Loc.language_for_locale("zh"), "zh_CN")
	assert_eq(Loc.language_for_locale("ja_JP"), "ja")
	assert_eq(Loc.language_for_locale("sv_SE"), "en")

## A letter is drawn if the pixel font has it, or (CJK languages only) the language's CJK font.
func _undrawn(code: String, text: String) -> Array[String]:
	var cjk: Font = null
	if code in Loc.CJK:
		cjk = load(PixelFont.CJK_FONT % code)
	var out: Array[String] = []
	for i: int in text.length():
		var ch: String = text[i]
		if ch == "\n" or PixelFont.has_glyph(ch):
			continue
		if cjk != null and cjk.has_char(text.unicode_at(i)):
			continue
		if not ch in out:
			out.append(ch)
	return out

func test_every_letter_of_every_language_is_drawn() -> void:
	for code: String in Loc.LANGUAGES:
		if code == "en":
			continue
		var missing: Array[String] = []
		for v: Variant in (Loc.load_table(code).get("strings", {}) as Dictionary).values():
			for ch: String in _undrawn(code, str(v)):
				if not ch in missing:
					missing.append(ch)
		assert_eq(missing, [] as Array[String], "%s letters without a glyph (Latin/Cyrillic: tools/fonts/gen_extra_glyphs.py, CJK: tools/fonts/build_cjk.py)" % code)

func test_language_names_are_drawn() -> void:
	for code: String in Loc.LANGUAGES:
		var name: String = Loc.LANGUAGE_NAMES[code]
		var c: String = code if code in Loc.CJK else "en"
		assert_eq(_undrawn(c, name), [] as Array[String], name)

func test_the_language_font_comes_first() -> void:
	Loc.set_language("zh_TW")
	var fb: Array[Font] = PixelFont.get_font().fallbacks
	assert_eq(fb.size(), 4, "all four CJK fonts stay as fallbacks")
	assert_eq(fb[0].resource_path, PixelFont.CJK_FONT % "zh_TW")
	Loc.set_language("ja")
	assert_eq(PixelFont.get_font().fallbacks[0].resource_path, PixelFont.CJK_FONT % "ja")
	assert_eq(PixelFont.get_large_font().fallbacks[0].resource_path, PixelFont.CJK_FONT % "ja")
	Loc.set_language("en")

func test_switching_translates_labels_in_every_language() -> void:
	for code: String in Loc.LANGUAGES:
		if code == "en":
			continue
		Loc.set_language(code)
		var shown: String = Loc.t("Settings")
		assert_ne(shown, "", code)
		assert_ne(shown, "Settings", code + " translates Settings")
	Loc.set_language("en")

## The in-app purchase note on the title screen is one line across the whole screen: it must
## be readable in full in every language (it was cut off before).
func test_title_purchase_note_fits_in_every_language() -> void:
	var room: float = float(ProjectSettings.get_setting("display/window/size/viewport_width")) - 4.0
	for code: String in Loc.LANGUAGES:
		Loc.set_language(code)
		var shown: String = Loc.t(TitleScreen.IAP_NOTE)
		var w: float = PixelFont.get_font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
		assert_lte(w, room, "%s: %s (%d px)" % [code, shown, int(w)])
	Loc.set_language("en")
