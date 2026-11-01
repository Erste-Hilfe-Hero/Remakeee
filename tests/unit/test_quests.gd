extends GutTest
## Questlog: goal order, old-save tolerance, and every quest flag can really be set in game.

func test_goals_advance_in_order() -> void:
	var flags: Dictionary = {}
	assert_eq(QuestLog.current(flags).id, "wake")
	flags["aldo_gift"] = true
	assert_eq(QuestLog.current(flags).id, "maps")
	flags["met_kestra"] = true
	assert_eq(QuestLog.current(flags).id, "rifts")
	flags["rift_tide_sealed"] = true
	assert_eq(QuestLog.current(flags).id, "rifts")
	assert_string_contains(QuestLog.goal_text(QuestLog.current(flags), flags), "(1/2)")
	flags["rift_cinder_sealed"] = true
	assert_eq(QuestLog.current(flags).id, "dock")
	flags["kestra_dock_talk"] = true
	assert_eq(QuestLog.current(flags).id, "act1_end")

func test_old_save_without_new_flag_lands_on_later_goal() -> void:
	# Saves from before "met_kestra" existed: both Rifts mended, never set met_kestra.
	var flags: Dictionary = {"aldo_gift": true, "rift_tide_sealed": true, "rift_cinder_sealed": true}
	assert_eq(QuestLog.current(flags).id, "dock")

func test_side_goals_show_and_hide() -> void:
	var flags: Dictionary = {"met_kestra": true}
	var ids: Array = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return g.id)
	assert_true("spar" in ids)
	flags["kestra_spar"] = true
	ids = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return g.id)
	assert_false("spar" in ids)
	assert_string_contains(QuestLog.summary(flags), "Goal")

func test_every_quest_flag_is_set_somewhere() -> void:
	var settable: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://data/dialogue"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
		for k: Variant in d:
			if d[k] is Dictionary and d[k].has("flag"):
				settable[str(d[k].flag)] = true
	for f: String in DirAccess.get_files_at("res://data/maps"):
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		for n: Variant in m.get("npcs", []):
			if n.has("beaten_flag"):
				settable[str(n.beaten_flag)] = true
			if n.has("warden"):
				settable["rift_%s_sealed" % n.warden] = true
			for wf: Variant in n.get("win_flags", []):
				settable[str(wf)] = true
	for f: String in QuestLog.all_flags():
		assert_true(settable.has(f), "quest flag '%s' is never set by dialogue or maps" % f)
