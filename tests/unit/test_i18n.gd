extends GutTest
## Languages (item 62): the German table covers every player-facing text, patterns carry
## values over, and switching language reaches Labels through Godot's translation server.

var de: PatternTranslation
var table: Dictionary

func before_all() -> void:
	Database.load_all()
	table = Loc.load_table("de")
	de = Loc.load_translation("de")

func after_all() -> void:
	Loc.set_language("en")

func _keep() -> Array:
	return table.get("keep", [])

func test_table_loads() -> void:
	assert_not_null(de)
	assert_gt(de.exact.size(), 400)
	assert_gt(de.patterns.size(), 50)

func test_placeholders_match() -> void:
	for k: String in table.strings.keys():
		var v: String = table.strings[k]
		var ns: int = k.count("%s")
		var nd: int = k.count("%d")
		if v.contains("{0}"):
			var n: int = ns + nd
			for i: int in n:
				assert_true(v.contains("{%d}" % i), "%s: missing {%d}" % [k, i])
		else:
			assert_eq(v.count("%s"), ns, "%%s count in '%s'" % k)
			assert_eq(v.count("%d"), nd, "%%d count in '%s'" % k)

func _all_dialogue_lines() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at("res://data/dialogue"):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
		for v: Variant in d.values():
			if v is Array:
				for s: Variant in v:
					out.append(str(s))
			elif v is Dictionary:
				for s: Variant in v.get("lines", []):
					out.append(str(s))
				var af: Variant = v.get("after_flag")
				if af is Dictionary:
					for s: Variant in af.get("lines", []):
						out.append(str(s))
	return out

func test_every_dialogue_line_is_translated() -> void:
	var missing: Array[String] = []
	for s: String in _all_dialogue_lines():
		if de.lookup(s) == "":
			missing.append(s)
	assert_eq(missing, [] as Array[String], "dialogue without German text (run tools/i18n_extract.py)")

func test_items_and_spirlog_are_translated() -> void:
	var missing: Array[String] = []
	for it: Dictionary in Database.items.values():
		for k: String in ["name", "description"]:
			var s: String = str(it.get(k, ""))
			if s != "" and de.lookup(s) == "":
				missing.append(s)
	for sd: SpirlingData in Database.spirlings.values():
		for s: String in [sd.lore, sd.habitat]:
			if s != "" and de.lookup(s) == "":
				missing.append(s)
	assert_eq(missing, [] as Array[String])

func test_quests_and_maps_are_translated() -> void:
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var missing: Array[String] = []
	for group: Variant in q.values():
		if group is Array:
			for g: Dictionary in group:
				for k: String in ["text", "where"]:
					var s: String = str(g.get(k, ""))
					if s != "" and de.lookup(s) == "":
						missing.append(s)
	for f: String in DirAccess.get_files_at("res://data/maps"):
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		var n: String = str(m.get("name", ""))
		if de.lookup(n) == "":
			missing.append(n)
	assert_eq(missing, [] as Array[String])

func test_patterns_carry_values() -> void:
	assert_eq(de.lookup("Kindlop took 12 damage."), "Kindlop erleidet 12 Schaden.")
	assert_eq(de.lookup("Volume: 80%"), "Lautstärke: 80%")
	assert_eq(de.lookup("You got Tonic x2!"), "Du hast Tonikum x2 bekommen!", "item names inside patterns are translated")
	assert_eq(de.lookup("Used Tonic on Kindlop."), "Tonikum bei Kindlop benutzt.")

func test_reordered_values() -> void:
	assert_eq(de.lookup("Kindlop's Might goes up a lot."), "Wucht von Kindlop legt kräftig zu.")

func test_sentences_and_lines_combine() -> void:
	assert_eq(de.lookup("Kindlop took 9 damage. A keen hit! It's overwhelming!"),
		"Kindlop erleidet 9 Schaden. Ein scharfer Treffer! Das ist überwältigend!")
	assert_eq(de.lookup("Tonic\nRestores 25 Vigor."), "Tonikum\nStellt 25 Kraft wieder her.")

func test_unknown_text_is_left_alone() -> void:
	assert_eq(de.lookup("Kindlop"), "")
	assert_eq(de.lookup("zzz qqq"), "")

func test_battle_events_are_translated() -> void:
	var samples: Array[BattleEvent] = [
		BattleEvent.new(BattleEvent.Type.SEND_OUT, {"name": "Kindlop"}),
		BattleEvent.new(BattleEvent.Type.DAMAGE, {"name": "Kindlop", "amount": 7, "eff": 2.0, "crit": true}),
		BattleEvent.new(BattleEvent.Type.STATUS_APPLIED, {"name": "Kindlop", "status": "scorch"}),
		BattleEvent.new(BattleEvent.Type.FAINTED, {"name": "Kindlop"}),
		BattleEvent.new(BattleEvent.Type.LEVEL_UP, {"name": "Kindlop", "level": 9}),
		BattleEvent.new(BattleEvent.Type.STAT_CHANGED, {"name": "Kindlop", "stat": "spd", "delta": -1}),
		BattleEvent.new(BattleEvent.Type.BATTLE_START, {"wild": true, "foe_name": "Kindlop", "prism": true}),
	]
	for e: BattleEvent in samples:
		var en: String = e.describe()
		var t: String = de.lookup(en)
		assert_ne(t, "", "untranslated: " + en)
		assert_false(t.contains("%"), en)
	assert_eq(de.lookup(samples[2].describe()), "Kindlop leidet an Brand!")

func test_set_language_switches_labels() -> void:
	Loc.set_language("de")
	assert_eq(Loc.t("New Game"), "Neues Spiel")
	assert_eq(String(TranslationServer.translate("Settings")), "Einstellungen")
	var l := Label.new()
	l.text = "Back"
	add_child_autofree(l)
	await wait_process_frames(1)
	assert_eq(l.get_text(), "Back", "the source text stays English")
	assert_eq(String(l.tr("Back")), "Zurück")
	Loc.set_language("en")
	assert_eq(Loc.t("New Game"), "New Game")

func test_language_is_saved() -> void:
	var before: String = GameState.language
	GameState.language = "de"
	var d: Dictionary = GameState.settings_to_dict()
	GameState.language = ""
	GameState.settings_from_dict(d)
	assert_eq(GameState.language, "de")
	assert_eq(Loc.language(), "de")
	GameState.language = before
	GameState.apply_display()
	Loc.set_language("en")

func test_font_has_every_german_glyph() -> void:
	var missing: Dictionary = {}
	for v: String in table.strings.values():
		for i: int in v.length():
			if v.unicode_at(i) == 10 or PixelFont.GLYPHS.has(v[i]):
				continue
			missing[v[i]] = true
	assert_eq(missing.keys(), [], "glyphs the pixel font lacks")
