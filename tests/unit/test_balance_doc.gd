extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 874-881): the generated parts of
## docs/BALANCE.md match the data. After a change, run tools/balance/run_all.sh (or, for the data
## sections only, godot --headless --path . -s res://tools/balance_doc.gd -- --data).

func before_all() -> void:
	Database.load_all()

func test_data_sections_match_the_data() -> void:
	var doc: String = FileAccess.get_file_as_string(BalanceDoc.DOC_PATH)
	for name: String in BalanceDoc.DATA_SECTIONS:
		assert_eq(BalanceDoc.current_section(doc, name), BalanceDoc.section(name).strip_edges(),
			"docs/BALANCE.md section %s is out of date: run tools/balance/run_all.sh" % name)

func test_every_generated_section_has_its_markers_and_content() -> void:
	var doc: String = FileAccess.get_file_as_string(BalanceDoc.DOC_PATH)
	var names: Array[String] = BalanceDoc.DATA_SECTIONS + BalanceDoc.SIM_SECTIONS
	for name: String in names:
		assert_string_contains(doc, "<!-- gen:%s -->" % name)
		assert_false(BalanceDoc.current_section(doc, name).is_empty(), name)
	for heading: String in ["## Neue Technik hinzufügen", "## Schwierigkeitsstufen", "## KI-Profile", "## Wächter-Rätsel schreiben",
			"## Regelvarianten", "## Änderungsprotokoll", "## Referenzteams", "## Full report at Lv36"]:
		assert_string_contains(doc, heading)

func test_tables_cover_every_profile_variant_and_difficulty() -> void:
	var prof: String = BalanceDoc.section("profiles")
	for id: String in ["balanced", "hothead", "wall", "spoiler", "field_keeper", "tactician", "apprentice", "enduring"]:
		assert_string_contains(prof, "| %s |" % id)
	assert_string_contains(prof, "crowcrest:lio", "who uses a profile")
	var vars: String = BalanceDoc.section("variants")
	for id: String in BattleRules.variants():
		assert_string_contains(vars, "`%s`" % id)
	var diff: String = BalanceDoc.section("difficulty")
	for n: String in BalanceDoc.DIFFICULTY_NAMES:
		assert_string_contains(diff, "| %s |" % n)
	assert_string_contains(BalanceDoc.section("ref_teams"), "| pre_orrin | 12 |")

func test_replace_section_swaps_only_the_marked_text() -> void:
	var doc: String = "a\n<!-- gen:x -->\nold\n<!-- /gen:x -->\nb"
	var out: String = BalanceDoc.replace_section(doc, "x", "new")
	assert_eq(out, "a\n<!-- gen:x -->\nnew\n<!-- /gen:x -->\nb")
	assert_eq(BalanceDoc.current_section(out, "x"), "new")
	assert_eq(BalanceDoc.replace_section(doc, "y", "new"), doc, "no markers, no change")

func test_change_log_lists_every_retuned_art() -> void:
	var t: String = BalanceDoc.changes_table({"moves": {"Lichen Lash": {"used": 10, "kos": 4}}})
	assert_string_contains(t, "| Lichen Lash | Power 40 | Power 35 | Too many KOs for 2 Energy | 0.94 | 0.40 |")
	for c: Array in BalanceDoc.CHANGES:
		assert_string_contains(t, "| %s |" % c[0])
