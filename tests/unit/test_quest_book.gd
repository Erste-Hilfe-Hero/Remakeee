extends GutTest
## Quest Book (Chimora 1.3.2): every quest leads to a place on the world map, the tabs list
## quests by their flags, and "Where next?", the map ring and the goal line agree.

func after_each() -> void:
	QuestLog.tracked = ""
	Loc.set_language("en")

func _all_quests() -> Array:
	return QuestLog.main_goals() + QuestLog.side_goals()

func test_every_quest_where_maps_to_a_world_map_place() -> void:
	var places: Dictionary = WorldAtlas.places()
	for g: Dictionary in _all_quests():
		var p: String = QuestLog.target_place(g, {})
		assert_true(places.has(p), "quest %s (%s) has no place on the world map" % [g.id, QuestLog.where_of(g)])
		for i: int in (g.get("stages", []) as Array).size():
			var st: Dictionary = g.stages[i]
			var m: String = str(st.get("map", "")) if st.has("map") else QuestLog.map_for_where(str(st.get("where", g.get("where", ""))))
			assert_true(places.has(WorldAtlas.place_of(m)), "stage %d of %s (%s) has no place" % [i, g.id, st.get("where", "")])

func test_every_where_text_resolves() -> void:
	for g: Dictionary in _all_quests():
		assert_false(QuestLog.where_of(g).is_empty(), "quest %s has no where" % g.id)
		assert_false(QuestLog.map_for_where(QuestLog.where_of(g)).is_empty(), "%s: %s" % [g.id, QuestLog.where_of(g)])

func test_places_aliases_name_real_maps() -> void:
	for k: String in QuestLog.data().get("places", {}):
		assert_true(MapData.exists(str(QuestLog.data().places[k])), k)

func test_main_goal_follows_the_next_goto() -> void:
	var rifts: Dictionary = QuestLog.find("rifts")
	var f: Dictionary = {"aldo_gift": true, "met_kestra": true}
	assert_eq(QuestLog.target_map(rifts, f), "cinder_rift")
	f["rift_cinder_sealed"] = true
	assert_eq(QuestLog.target_map(rifts, f), "mist_rift")

func test_tabs_list_quests_by_state() -> void:
	var f: Dictionary = {}
	assert_eq(QuestLog.book(QuestLog.MAIN, f).map(func(g: Dictionary) -> String: return g.id), ["wake"])
	assert_true(QuestLog.book(QuestLog.DONE, f).is_empty())
	f["aldo_gift"] = true
	f["page_1"] = true
	f["page_2"] = true
	assert_eq(QuestLog.book(QuestLog.MAIN, f)[0].id, "maps", "the current main quest is on top")
	assert_eq(QuestLog.book(QuestLog.DONE, f)[0].id, "wake")
	var side: Array = QuestLog.book(QuestLog.SIDE, f).map(func(g: Dictionary) -> String: return g.id)
	assert_true("pages" in side)
	assert_eq(QuestLog.progress(QuestLog.find("pages"), f), Vector2i(2, 6))
	f["pages_all"] = true
	assert_false("pages" in QuestLog.book(QuestLog.SIDE, f).map(func(g: Dictionary) -> String: return g.id))
	assert_true("pages" in QuestLog.book(QuestLog.DONE, f).map(func(g: Dictionary) -> String: return g.id))
	assert_eq(QuestLog.progress(QuestLog.find("pages"), f), Vector2i(6, 6))

func test_each_quest_is_in_exactly_one_tab_or_hidden() -> void:
	var f: Dictionary = {"aldo_gift": true, "met_kestra": true, "rift_cinder_sealed": true}
	for g: Dictionary in _all_quests():
		var n: int = 0
		for tab: String in QuestLog.BOOK_TABS:
			n += 1 if QuestLog.book(tab, f).has(g) else 0
		assert_eq(n, 0 if QuestLog.state(g, f) == "hidden" else 1, str(g.id))

func test_a_new_quest_appears_by_its_flags_alone() -> void:
	var side: Array = QuestLog.data().side
	var q: Dictionary = {"id": "t_daily", "text": "Daily test quest.", "where": "Madderby", "show": "t_daily_on", "done": "t_daily_done", "progress": ["t_d1", "t_d2", "t_d3"]}
	side.append(q)
	var f: Dictionary = {"t_daily_on": true, "t_d1": true}
	assert_true(QuestLog.book(QuestLog.SIDE, f).has(q))
	assert_eq(QuestLog.progress(q, f), Vector2i(1, 3))
	assert_eq(QuestLog.target_place(q, f), "madderby")
	f["t_daily_done"] = true
	assert_true(QuestLog.book(QuestLog.DONE, f).has(q))
	side.erase(q)

func test_book_rows_show_text_place_and_progress() -> void:
	var f: Dictionary = {"aldo_gift": true, "page_1": true}
	var main: Array[Dictionary] = PauseMenu.quest_book_rows(QuestLog.MAIN, f)
	assert_eq(main[0].quest, "maps")
	assert_not_null(main[0].get("icon"))
	assert_string_contains(str(main[0].hint), "Brindlewick")
	var pages: Dictionary = {}
	for r: Dictionary in PauseMenu.quest_book_rows(QuestLog.SIDE, f):
		if r.get("quest") == "pages":
			pages = r
	assert_true(str(pages.text).begins_with("1/6  "), "progress stays visible at the start")
	var empty: Array[Dictionary] = PauseMenu.quest_book_rows(QuestLog.DONE, {})
	assert_eq(empty.size(), 1)
	assert_true(bool(empty[0].get("disabled", false)))

func test_where_next_marker_matches_goal_line_and_doors() -> void:
	var f: Dictionary = {"aldo_gift": true}
	var g: Dictionary = QuestLog.find("pages")
	QuestLog.tracked = "pages"
	var place: String = QuestLog.target_place(g, f)
	assert_eq(QuestLog.goal_maps(f), [QuestLog.target_map(g, f)] as Array[String], "goal doors lead to the marked map")
	assert_eq(WorldAtlas.place_of(QuestLog.goal_maps(f)[0]), place)
	assert_string_contains(QuestLog.hud_text(f), QuestLog.place_name(place), "goal line names the marked place")
	assert_string_contains(QuestLog.hud_text(f), "(0/6)")
	var view := WorldMapView.new()
	view.restore({"highlight": place, "show_highlight": true})
	assert_eq(view.highlight, place, "the map rings the same place")
	view.free()

func test_tracking_the_main_goal_after_act_one_shows_a_line() -> void:
	var f: Dictionary = {"aldo_gift": true, "met_kestra": true, "rift_cinder_sealed": true, "rift_mist_sealed": true,
		"rift_tide_sealed": true, "kestra_dock_talk": true, "aldo_dock_told": true, "mirela_lamp": true}
	assert_eq(QuestLog.hud_text(f), "")
	QuestLog.tracked = QuestLog.current(f).id
	assert_string_contains(QuestLog.hud_text(f), QuestLog.place_name(QuestLog.target_place(QuestLog.current(f), f)))
	assert_eq(QuestLog.goal_maps(f), [QuestLog.target_map(QuestLog.current(f), f)] as Array[String])

func test_a_finished_tracked_quest_falls_back_to_the_main_goal() -> void:
	var f: Dictionary = {"aldo_gift": true, "pages_all": true}
	QuestLog.tracked = "pages"
	assert_true(QuestLog.tracked_goal(f).is_empty())
	assert_eq(QuestLog.hud_text(f), "Go to the Map House")
	assert_eq(QuestLog.goal_maps(f), ["map_house"] as Array[String])

func test_open_quest_places_need_a_known_place() -> void:
	var f: Dictionary = {"aldo_gift": true}
	var target: String = QuestLog.target_place(QuestLog.current(f), f)
	assert_false(target in QuestLog.open_places(f, {}))
	assert_true(target in QuestLog.open_places(f, {target: WorldAtlas.Known.SIGHTED}))

func test_quest_book_texts_are_translated() -> void:
	for lang: String in Loc.LANGUAGES:
		if lang == "en":
			continue
		Loc.set_language(lang)
		for s: String in [PauseMenu.QUEST_BOOK, PauseMenu.QUEST_BOOK_HINT, PauseMenu.WHERE_NEXT, PauseMenu.NO_QUESTS,
				"Main", "Side", "Done", "To %s", "Quest goal: %s", "Goal line follows this."]:
			assert_ne(Loc.t(s), s, "%s: %s" % [lang, s])

func test_book_rows_are_translated_with_progress() -> void:
	Loc.set_language("de")
	var f: Dictionary = {"aldo_gift": true, "met_kestra": true, "rift_tide_sealed": true}
	var row: Dictionary = PauseMenu.quest_book_rows(QuestLog.MAIN, f)[0]
	assert_eq(str(row.text), "1/3  " + Loc.t(str(QuestLog.find("rifts").text)))
	assert_ne(Loc.t(str(QuestLog.find("rifts").text)), str(QuestLog.find("rifts").text))
