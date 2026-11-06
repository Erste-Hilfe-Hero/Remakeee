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
	assert_eq(QuestLog.current(flags).id, "home")
	flags["aldo_dock_told"] = true
	assert_eq(QuestLog.current(flags).id, "lamp")
	flags["mirela_lamp"] = true
	assert_eq(QuestLog.current(flags).id, "crossing")
	assert_eq(str(QuestLog.current(flags).act), "Act II: The Colours of Corvane")

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
			# Answers in a choice set flags too.
			for c: Variant in (d[k].get("choices", []) if d[k] is Dictionary else []):
				if c is Dictionary and c.has("flag"):
					settable[str(c.flag)] = true
			# Actions that set flags themselves: quest_show <id> ..., switch <puzzle> ...
			for one: String in (str(d[k].get("action", "")).split(";") if d[k] is Dictionary else PackedStringArray()):
				var act: PackedStringArray = one.strip_edges().split(" ")
				if act.size() > 1 and act[0] == "quest_show":
					settable["q_%s_asked" % act[1]] = true
					settable["q_%s_done" % act[1]] = true
				if act.size() > 1 and act[0] == "switch":
					settable[act[1]] = true
				# "page <n>" sets page_<n>, and the last page sets pages_all.
				if act.size() > 1 and act[0] == "page":
					settable["page_%s" % act[1]] = true
					settable["pages_all"] = true
				# "echo_song <flag>" sets its flag on a good echo.
				if act.size() > 1 and act[0] == "echo_song":
					settable[act[1]] = true
				if act[0] == "choose_starter":
					settable["got_starter"] = true
	# Cut-scenes set flags with "flag" steps (data/scenes).
	for f: String in DirAccess.get_files_at("res://data/scenes"):
		var sc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenes/" + f))
		for step: Variant in sc.get("steps", []):
			if step is Dictionary and step.has("flag"):
				for fl: Variant in (step.flag if step.flag is Array else [step.flag]):
					settable[str(fl)] = true
	for f: String in DirAccess.get_files_at("res://data/maps"):
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		for n: Variant in m.get("npcs", []):
			if n.has("beaten_flag"):
				settable[str(n.beaten_flag)] = true
			if n.has("warden"):
				settable["rift_%s_sealed" % n.warden] = true
			for wf: Variant in n.get("win_flags", []):
				settable[str(wf)] = true
	# Story figures on area 3's maps (data/story_npcs.json) and story duels.
	for mid: Variant in StoryPlacements.data():
		for n: Variant in StoryPlacements.for_map(str(mid)).get("npcs", []):
			if n.has("beaten_flag"):
				settable[str(n.beaten_flag)] = true
			if n.has("warden"):
				settable["rift_%s_sealed" % n.warden] = true
	for id: Variant in StoryBattles.data():
		if StoryBattles.has(str(id)):
			settable[StoryBattles.beaten_flag(str(id))] = true
	for f: String in QuestLog.all_flags():
		assert_true(settable.has(f), "quest flag '%s' is never set by dialogue or maps" % f)
