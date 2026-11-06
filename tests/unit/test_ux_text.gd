extends GutTest
## Plan area 5, German and English: menu texts fit the 144 px screen, placeholders survive,
## no English is left on German menus, Chimora's own words, plural forms.

## Room for a row's text: screen 144 - menu margins 2x6 - frame 2x5 - row padding 5 + 2.
const ROW_TEXT_WIDTH: int = 115

var _was_in_game: bool

func before_all() -> void:
	Database.load_all()
	_was_in_game = GameState.in_game

func after_all() -> void:
	GameState.in_game = _was_in_game
	Loc.set_language("en")

## Every fixed menu row the player can meet, with On and Off both ways.
static func menu_rows() -> Array[String]:
	var out: Array[String] = []
	var was: bool = GameState.in_game
	GameState.in_game = true
	var rows: Array = []
	for g: Array in MenuHost.SETTINGS_GROUPS:
		rows.append(g)
	for grp: String in ["game", "sound"]:
		rows.append_array(MenuHost.settings_rows(grp))
	rows.append_array(MenuHost.display_rows())
	rows.append_array(MenuHost.controls_rows())
	GameState.in_game = was
	for r: Array in rows:
		var t: String = str(r[1])
		out.append(t)
		if t.ends_with(": On"):
			out.append(t.trim_suffix("On") + "Off")
		elif t.ends_with(": Off"):
			out.append(t.trim_suffix("Off") + "On")
	for d: String in MenuHost.DIFFICULTY_TEXT:
		out.append(d)
		out.append("Challenge: %s" % d)
	for t: String in PauseMenu.MENU_LABELS:
		out.append(t)
	out.append_array(["Continue", "New Game", "Load...", "Settings", "Back", "Yes", "No",
		"Get a transfer code", "Enter a code...", "Online rules", "Privacy", "Delete account...",
		"Friends, mail: On", "Friends, mail: Off", "Try again", "Open the store",
		"No, I am new", "Yes, I have a code", "Lantern Mail", "Add a friend...", "World goal of the week",
		"Weekly board", "Blocked Wayfarers", "Copy my code", "Sound test...", "Music", "Sound effects",
		"Cries", "Imprint & privacy", "Licences", "Take the Iron Oath", "Not now", "Delete", "Keep"])
	return out

func _width(text: String) -> float:
	return PixelFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x

func test_menu_rows_fit_in_english_and_german() -> void:
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		for t: String in menu_rows():
			var shown: String = Loc.t(t)
			assert_lte(_width(shown), float(ROW_TEXT_WIDTH), "%s row too wide (%d px): %s" % [lang, int(_width(shown)), shown])
	Loc.set_language("en")

func test_german_menus_have_no_english_left() -> void:
	Loc.set_language("de")
	var keep: Array[String] = ["OK", "Team", "Spirlog", "Veteran"]
	for t: String in menu_rows():
		var shown: String = Loc.t(t)
		if shown == t and not t in keep:
			assert_ne(shown, t, "no German for menu row: " + t)
	Loc.set_language("en")

func test_placeholders_and_name_survive_translation() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de.json"))
	var strings: Dictionary = table.strings
	for k: String in strings.keys():
		var v: String = strings[k]
		assert_eq(v.count("{name}"), k.count("{name}"), "{name} kept in: " + k)
		if not v.contains("{0}"):
			# German may write "50 %" with a space; the placeholders must all stay.
			assert_eq(v.count("%%"), k.count("%%"), "%%%% kept in: " + k)
			assert_eq(v.count("%d"), k.count("%d"), "%%d kept in: " + k)

func test_chimora_words_not_genre_words() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de.json"))
	var en_words := RegEx.create_from_string("\\b(Level|Lv|XP|HP|Trainers?|Tamers?|Ability|Abilities|Evolution|Experience)\\b")
	var de_words := RegEx.create_from_string("\\b(Level|Lv\\b|XP\\b|KP\\b|EP\\b|Trainer|Tamer|Fähigkeit|Entwicklung|Erfahrung)")
	for k: String in table.strings.keys():
		assert_null(en_words.search(k), "genre word in English text: " + k)
		assert_null(de_words.search(str(table.strings[k])), "genre word in German text: " + str(table.strings[k]))

func test_plural_forms() -> void:
	assert_eq(Loc.plural(1, "%d coin", "%d coins"), "1 coin")
	assert_eq(Loc.plural(3, "%d coin", "%d coins"), "3 coins")
	Loc.set_language("de")
	assert_eq(Loc.t(Loc.plural(1, "%d coin", "%d coins")), "1 Münze")
	assert_eq(Loc.t(Loc.plural(2, "%d coin", "%d coins")), "2 Münzen")
	Loc.set_language("en")

func test_language_change_is_announced() -> void:
	var got: Array[String] = []
	var cb := func(code: String) -> void: got.append(code)
	Loc.events.language_changed.connect(cb)
	Loc.set_language("de")
	Loc.set_language("de")
	Loc.set_language("en")
	Loc.events.language_changed.disconnect(cb)
	assert_eq(got, ["de", "en"] as Array[String], "only real changes are sent")
