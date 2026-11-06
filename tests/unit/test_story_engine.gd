extends GutTest
## Story engine (plan area 4, items 1335-1343, 1370-1377, 1680): dialogue choices, conditions,
## "next", after_flag lists, story numbers and choices in the save, the cut-scene player.

func before_each() -> void:
	Database.load_all()
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 0, Database.STARTERS[0], 1)

func test_after_flag_list_takes_last_set_variant() -> void:
	var e: Dictionary = {"lines": ["a"], "after_flag": [
		{"flag": "ch1", "lines": ["b"]}, {"flag": "ch2", "lines": ["c"]}]}
	assert_eq(Dialogue.lines_for(e, {}), ["a"] as Array[String])
	assert_eq(Dialogue.lines_for(e, {"ch1": true}), ["b"] as Array[String])
	assert_eq(Dialogue.lines_for(e, {"ch1": true, "ch2": true}), ["c"] as Array[String])
	assert_eq(Dialogue.lines_for(e, {"ch2": true}), ["c"] as Array[String])

func test_old_single_after_flag_still_works() -> void:
	var e: Dictionary = {"lines": ["a"], "after_flag": {"flag": "x", "lines": ["b"]}}
	assert_eq(Dialogue.lines_for(e, {"x": true}), ["b"] as Array[String])

func test_conditions() -> void:
	var sp: String = Database.STARTERS[0]
	assert_true(Dialogue.check({"flag": "got_starter"}, GameState.flags))
	assert_false(Dialogue.check({"not_flag": "got_starter"}, GameState.flags))
	assert_true(Dialogue.check({"has_species": sp}, GameState.flags))
	assert_false(Dialogue.check({"has_species": Database.STARTERS[1]}, GameState.flags))
	var el: String = Elements.E.keys()[Database.species(sp).elements[0]]
	assert_true(Dialogue.check({"has_element": el.to_lower()}, GameState.flags))
	assert_true(Dialogue.check({"party_size_min": 1}, GameState.flags))
	assert_false(Dialogue.check({"party_size_min": 2}, GameState.flags))
	assert_false(Dialogue.check({"has_item": "tonic"}, GameState.flags))
	GameState.add_item("tonic", 1)
	assert_true(Dialogue.check({"has_item": "tonic"}, GameState.flags))
	assert_true(Dialogue.check({"chapter_min": 0}, GameState.flags))
	assert_false(Dialogue.check({"chapter_min": 3}, GameState.flags))
	assert_true(Dialogue.check({"chapter_min": 3}, {"aldo_gift": true, "met_kestra": true, "rift_cinder_sealed": true, "rift_tide_sealed": true}))
	assert_false(Dialogue.check({"nonsense": 1}, GameState.flags), "unknown conditions fail")

func test_story_vars_and_choices() -> void:
	assert_eq(GameState.story_var("kestra_trust"), 0)
	GameState.add_story_var("kestra_trust", 1)
	GameState.add_story_var("kestra_trust", 1)
	assert_eq(GameState.story_var("kestra_trust"), 2)
	assert_true(Dialogue.check({"var_min": {"kestra_trust": 2}}, GameState.flags))
	assert_false(Dialogue.check({"var_min": {"kestra_trust": 3}}, GameState.flags))
	assert_true(Dialogue.check({"var_max": {"kestra_trust": 2}}, GameState.flags))
	GameState.record_choice("kestra_dock", "together")
	assert_true(Dialogue.check({"choice": {"kestra_dock": "together"}}, GameState.flags))

func test_story_state_survives_save_round_trip() -> void:
	GameState.set_story_var("veit_respect", 2)
	GameState.record_choice("ending", "gate")
	var d: Dictionary = GameState.to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Other", 0, Database.STARTERS[0], 0)
	assert_eq(GameState.story_var("veit_respect"), 0)
	GameState.from_dict(d)
	assert_eq(GameState.story_var("veit_respect"), 2)
	assert_eq(str(GameState.story_choices.get("ending")), "gate")
	assert_eq(int(GameState.story_choices.get("_v")), GameState.STORY_CHOICES_VERSION)

func test_old_save_without_story_state_loads() -> void:
	GameState.from_dict({"tamer": {"name": "Old"}})
	assert_true(GameState.story_vars.is_empty())
	assert_true(GameState.story_choices.is_empty())

func test_choices_filter_by_if() -> void:
	var e: Dictionary = {"lines": ["?"], "choices": [{"text": "A"}, {"text": "B", "if": {"flag": "x"}}]}
	assert_eq(Dialogue.choices_for(e, {}).size(), 1)
	assert_eq(Dialogue.choices_for(e, {"x": true}).size(), 2)

func test_next_refs_resolve_in_same_file() -> void:
	assert_eq(Dialogue.resolve_ref("brindlewick/kestra_dock", "kestra_dock_2"), "brindlewick/kestra_dock_2")
	assert_eq(Dialogue.resolve_ref("brindlewick/kestra_dock", "story/page_1"), "story/page_1")
	assert_true(Dialogue.exists("story/page_1"))
	assert_false(Dialogue.exists("story/nope"))

func test_speaker_split_from_old_lines() -> void:
	assert_eq(Dialogue.split_speaker("Aldo: Hello."), PackedStringArray(["Aldo", "Hello."]))
	assert_eq(Dialogue.split_speaker("Warden Senna: Rain."), PackedStringArray(["Warden Senna", "Rain."]))
	assert_eq(Dialogue.split_speaker("FERRY TO CORVANE"), PackedStringArray(["", "FERRY TO CORVANE"]))
	assert_eq(Dialogue.split_speaker("'Day one. Note: ink.'"), PackedStringArray(["", "'Day one. Note: ink.'"]))

func test_story_data_has_no_dead_references() -> void:
	var errors: PackedStringArray = StoryValidator.validate()
	assert_eq(errors.size(), 0, "Story errors:\n" + "\n".join(errors))

func test_validator_catches_dead_references() -> void:
	var errors: PackedStringArray = []
	StoryValidator._check_entry("story/x", {"next": "missing_key", "if": {"has_species": "Nobody", "bad": 1},
		"action": "give_item no_such_item; scene no_scene; battle no_duel; fly_away",
		"choices": [{"text": "only one", "next": "nowhere"}]}, errors)
	var all: String = "\n".join(errors)
	for bit: String in ["missing_key", "Nobody", "bad", "no_such_item", "no_scene", "no_duel", "fly_away", "2 or 3", "nowhere"]:
		assert_string_contains(all, bit)

func test_scene_steps_are_known() -> void:
	assert_eq(ScenePlayer.step_kind({"say": ["x"]}), "say")
	assert_eq(ScenePlayer.step_kind({"fade": "out"}), "fade")
	assert_eq(ScenePlayer.step_kind({"bogus": 1}), "")
	assert_true(ScenePlayer.runs_when_skipped("flag", {}))
	assert_true(ScenePlayer.runs_when_skipped("give_item", {}))
	assert_false(ScenePlayer.runs_when_skipped("say", {}))
	assert_eq(ScenePlayer.seen_flag("act1_finale"), "scene_act1_finale_seen")

func test_skipped_scene_still_runs_effects() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	sp.skipping = true
	await sp.play("test_scene", {"steps": [
		{"say": ["Long talk."]}, {"wait": 5.0}, {"fade": "out"},
		{"flag": "test_scene_flag"}, {"give_item": "tonic", "count": 2},
		{"set_var": {"kestra_trust": 3}}, {"add_var": {"kestra_trust": 1}},
		{"spawn": "ghost", "x": 2, "y": 2}, {"move": "ghost", "path": ["left"]}]})
	assert_true(GameState.has_flag("test_scene_flag"))
	assert_eq(GameState.item_count("tonic"), 2)
	assert_eq(GameState.story_var("kestra_trust"), 4)
	assert_true(GameState.has_flag("scene_test_scene_seen"))
	assert_false(ow.scene_running)
	assert_almost_eq(ow.fade_rect().color.a, 0.0, 0.01)
	sp.queue_free()

func test_scene_moves_spawned_figure() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	var start: Vector2i = ow.player.cell
	await sp.play("walk", {"skippable": false, "steps": [{"face": "player", "dir": "left"}, {"emote": "player", "icon": "!"}]})
	assert_eq(ow.player.facing, "left")
	assert_eq(ow.player.cell, start)
	sp.queue_free()

func test_act1_scenes_play_through_when_skipped() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	for id: String in ["prologue", "mirela_lamp"]:
		var sp := ScenePlayer.new()
		sp.overworld = ow
		ow.add_child(sp)
		sp.skipping = true
		await sp.play(id)
		sp.queue_free()
	assert_true(GameState.has_flag("ferry_corvane_open"), "the nested finale scene ran")
	assert_eq(GameState.item_count("max_tonic"), 2)
	assert_true(GameState.has_flag("scene_prologue_seen"))

func test_warp_to_unbuilt_map_stops_the_scene() -> void:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	ow.text_box().auto_advance = true
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	var before: String = ow.map.id
	await sp.play("t", {"skippable": false, "steps": [{"action": "warp no_such_map 1 1"}, {"flag": "after_warp"}]})
	assert_false(GameState.has_flag("after_warp"))
	assert_false(GameState.has_flag("scene_t_seen"))
	assert_eq(ow.map.id, before)
	sp.queue_free()
