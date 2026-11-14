extends GutTest
## Plan area 1, items 64, 243-251: the Spirlog as map-book pages.

var _saved: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	GameState.from_dict(_saved)

func test_seen_on_sight_bonded_on_bond_and_maps_are_kept() -> void:
	GameState.current_map = "fernstair"
	GameState.mark_seen("Croziel")
	assert_true(SpirlogBook.is_seen(GameState.spirlog, "Croziel"))
	assert_false(SpirlogBook.is_bonded(GameState.spirlog, "Croziel"))
	GameState.current_map = "crowcrest"
	GameState.mark_seen("Croziel")
	var found: Array[Dictionary] = SpirlogBook.found_on(Database.species("Croziel"), GameState.spirlog)
	assert_eq(found.size(), 2)
	assert_eq(str(found[0].ground), "fern")
	assert_eq(str(found[1].ground), "scree")
	assert_eq(SpirlogBook.found_line(Database.species("Croziel"), GameState.spirlog), "Fernstair (Fern), Crowcrest (Scree)")
	assert_eq(str(GameState.spirlog.Croziel.first_map), "fernstair", "first map stays the first")

func test_unseen_kinds_are_outlines_with_their_number() -> void:
	var sd: SpirlingData = Database.species("Glasstarn")
	assert_eq(SpirlogBook.list_line(sd, GameState.spirlog), "33   ???")
	GameState.mark_seen("Glasstarn")
	assert_eq(SpirlogBook.list_line(sd, GameState.spirlog), "33 + Glasstarn")
	GameState.mark_seen("Glasstarn", true)
	assert_eq(SpirlogBook.list_line(sd, GameState.spirlog), "33 * Glasstarn")

func test_lore_opens_sentence_by_sentence() -> void:
	var sd: SpirlingData = Database.species("Kindlop")
	var all: PackedStringArray = SpirlogBook.split_sentences(sd.lore)
	assert_eq(all.size(), 2)
	GameState.spirlog.clear()
	assert_eq(SpirlogBook.lore_sentences(sd, GameState.spirlog).size(), 0)
	GameState.mark_seen("Kindlop")
	assert_eq(SpirlogBook.lore_sentences(sd, GameState.spirlog), all.slice(0, 1))
	GameState.mark_seen("Kindlop", true)
	assert_eq(SpirlogBook.lore_sentences(sd, GameState.spirlog), all.slice(0, 2))
	var three: SpirlingData = SpirlingData.new()
	three.species_name = "Kindlop"
	three.lore = "One. Two. Three."
	assert_eq(SpirlogBook.lore_sentences(three, GameState.spirlog).size(), 2)
	for i: int in SpirlogBook.LORE_BATTLES:
		GameState.note_battle_end()
	assert_eq(SpirlogBook.lore_sentences(three, GameState.spirlog).size(), 3, "after ten battles together")

func test_chapters_only_for_open_regions() -> void:
	assert_eq(SpirlogBook.open_regions(GameState.flags), ["veydal"] as Array[String])
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		assert_eq(sd.region, "veydal")
	GameState.set_flag("region_open_corvane")
	assert_eq(SpirlogBook.open_regions(GameState.flags), ["veydal", "corvane"] as Array[String])
	GameState.mark_seen("Talusk", true)
	GameState.mark_seen("Croziel")
	var p: Dictionary = SpirlogBook.chapter_progress("veydal", GameState.spirlog)
	assert_eq(int(p.total), 73, "70 kinds, Velahra, Hallowmur and Scriptorax")
	assert_eq(int(p.bonded), 2, "Kindlop and Talusk")
	assert_eq(int(p.seen), 3)
	assert_eq(SpirlogBook.chapter_line("veydal", GameState.spirlog), "Veydal: 3 seen, 2 bonded")

func test_search_and_filters() -> void:
	GameState.mark_seen("Talusk", true)
	GameState.mark_seen("Talusgard")
	var log: Dictionary = GameState.spirlog
	var f: Dictionary = GameState.flags
	assert_eq(SpirlogBook.filtered(log, f, "talus").size(), 2)
	assert_eq(SpirlogBook.filtered(log, f, "cairn").size(), 0, "unseen kinds can't be found by name")
	assert_eq(SpirlogBook.filtered(log, f, "", Elements.E.STONE).size(), 2)
	assert_eq(SpirlogBook.filtered(log, f, "", -1, "bulwark").size(), 2)
	assert_eq(SpirlogBook.filtered(log, f, "", -1, "", SpirlogBook.STATUS_BONDED).size(), 2, "Kindlop and Talusk")
	assert_eq(SpirlogBook.filtered(log, f, "", -1, "", SpirlogBook.STATUS_SEEN_ONLY).size(), 1)
	assert_eq(SpirlogBook.filtered(log, f, "", -1, "", SpirlogBook.STATUS_MISSING).size(), 70)

func test_unfold_line_and_page_text() -> void:
	var line: Array[SpirlingData] = SpirlogBook.line_of(Database.species("Talusgard"))
	assert_eq(line.map(func(s: SpirlingData) -> String: return s.species_name), ["Talusk", "Talusgard", "Cairnhold"])
	assert_eq(SpirlogBook.line_of(Database.species("Lanternel")).size(), 1)
	GameState.mark_seen("Talusk", true)
	var text: String = SpirlogBook.page_text(Database.species("Talusk"), GameState.spirlog)
	for part: String in ["#28 Talusk", "Stone", "Height 0.5 m", "Lives in:", "Origin:", "Gift: Thick Hide"]:
		assert_string_contains(text, part)
	assert_true(ResourceLoader.exists(SpirlogPage.sprite_path(Database.species("Talusk"))))

func test_page_opens_turns_and_closes() -> void:
	GameState.mark_seen("Talusk", true)
	GameState.mark_seen("Croziel")
	var kinds: Array[SpirlingData] = [Database.species("Kindlop"), Database.species("Talusk"), Database.species("Talusgard"), Database.species("Croziel")]
	var host := Control.new()
	add_child_autofree(host)
	var page := SpirlogPage.new()
	page.kinds = kinds
	page.index = 1
	host.add_child(page)
	page._build()
	page._show()
	assert_eq(page.current().species_name, "Talusk")
	assert_eq(page._line.get_child_count(), 3, "the whole line is shown")
	page._turn(1)
	assert_eq(page.current().species_name, "Croziel", "skips the unseen Talusgard")
	page._turn(1)
	assert_eq(page.current().species_name, "Kindlop", "wraps around")
	page.queue_free()

func test_collection_total_counts_open_regions_only() -> void:
	assert_eq(SpirlogBook.visible_kinds(GameState.flags).size(), 73, "70 kinds, Velahra, Hallowmur and Scriptorax")

func test_page_text_is_translated_line_by_line_with_its_lore() -> void:
	var lang: String = Loc._current
	var sd: SpirlingData = Database.species("Smoldrake")
	GameState.mark_seen("Smoldrake")
	GameState.spirlog["Smoldrake"]["bonded"] = true
	Loc.set_language("de")
	var text: String = SpirlogBook.translate_lines(SpirlogBook.page_text(sd, GameState.spirlog))
	Loc.set_language(lang)
	assert_false(text.contains("Lives in:"), "habitat line translated: " + text)
	assert_false(text.contains("Found on:"), "found line translated")
	assert_false(text.contains("Origin:"), "origin line translated")
	assert_false(text.contains("It cannot fly"), "lore translated")
	assert_true(text.contains("Rauchmähne"), "both open lore sentences in German")
	assert_false(text.contains("Ember"), "element name translated")
	assert_false(text.contains("Spare Flame"), "bonus gift names translated")

func test_sentences_split_at_cjk_marks() -> void:
	assert_eq(SpirlogBook.split_sentences("一つ目。二つ目！三つ目？").size(), 3)
	assert_eq(SpirlogBook.split_sentences("One. Two.").size(), 2)
