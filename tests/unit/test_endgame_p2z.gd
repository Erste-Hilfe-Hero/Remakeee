extends GutTest
## Plan area 8, P2 batch for the Echo Path: healing only in the rest room (3467), giving up keeps
## the finds (3468), wild Spirlings at the ring cap minus 5 (3469), open only after Act I (3472)
## and the best time of the week kept in this save only (3474).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	EchoPath.force_week = "2031-01-06"
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_all() -> void:
	EchoPath.force_week = ""
	Online.clock_offset = 0

func test_opens_only_after_act_one() -> void:
	assert_eq(EchoPath.OPEN_FLAG, GameState.ACT1_END_FLAG)
	var m: MapData = MapData.load_map("cinder_rift")
	m.apply_blocks({"rift_cinder_sealed": true})
	assert_false(m.is_walkable(Vector2i(7, 1)), "a mended Rift alone does not open it")
	m.apply_blocks({"rift_cinder_sealed": true, GameState.ACT1_END_FLAG: true})
	assert_true(m.is_walkable(Vector2i(7, 1)))
	GameState.set_flag("rift_cinder_sealed")
	assert_false(Goals.tab_text("Week").contains(Loc.t("Echo Path: %d of %d rooms this week") % [0, EchoPath.ROOMS]))
	GameState.set_flag(GameState.ACT1_END_FLAG)
	assert_string_contains(Goals.tab_text("Week"), Loc.t("Echo Path: %d of %d rooms this week") % [0, EchoPath.ROOMS])

func test_wild_rooms_are_five_under_the_cap() -> void:
	GameState.set_flag(GameState.ACT1_END_FLAG)
	assert_eq(EchoPath.WILD_RING, GameState.progress_cap() - 5)
	for slot: int in range(1, EchoPath.ROOMS + 1):
		var s: Spirling = EchoPath.wild_for(slot)
		if s != null:
			assert_eq(s.level, Spirling.STORY_RING - 5)
	var team: Array[Spirling] = EchoPath.echo_team(1)
	assert_eq(team.size(), EchoPath.ECHO_TEAM, "enough kinds for the echoes at the higher ring")
	assert_gt(team[0].level, EchoPath.WILD_RING)

func test_no_rest_point_outside_the_rest_room() -> void:
	var raw: String = FileAccess.get_file_as_string(EchoPath.DATA_PATH)
	for word: String in ["\"heal\"", "heal_point", "\"camp\""]:
		assert_false(raw.contains(word), word)
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	var body: String = src.substr(src.find("func _action_echo_room"))
	body = body.substr(0, body.find("\nfunc ", 1))
	assert_eq(body.count("heal_party"), 1, "one heal, in the rest room")
	assert_lt(body.find("\"rest\":"), body.find("heal_party"))

func test_giving_up_keeps_the_finds() -> void:
	var slot: int = -1
	for s: int in range(1, EchoPath.ROOMS + 1):
		if EchoPath.kind_of(s) == "treasure":
			slot = s
			break
	assert_gt(slot, 0, "a treasure room this week")
	var item: String = str(EchoPath.template_for(slot).get("item", "tonic"))
	var before: int = GameState.item_count(item)
	assert_gt(EchoPath.take_treasure(slot).size(), 0)
	EchoPath.clear(1 if slot != 1 else 2)
	# The player walks out. Later the same week everything is still there, only the chest waits.
	var waymarks: int = GameState.waymarks
	assert_eq(GameState.item_count(item), before + maxi(1, int(EchoPath.template_for(slot).get("count", 1))))
	assert_eq(EchoPath.done_count(), 2)
	EchoPath.open_chest()
	assert_eq(GameState.waymarks, waymarks, "the chest stays shut")

func test_best_time_is_kept_per_week() -> void:
	assert_eq(EchoPath.best_time(), -1)
	EchoPath.clear(1)
	Online.clock_offset = 25 * 60
	for s: int in range(2, EchoPath.ROOMS + 1):
		EchoPath.clear(s)
	var text: String = "\n".join(EchoPath.open_chest())
	assert_eq(EchoPath.best_time(), 25 * 60)
	assert_string_contains(text, Loc.t("%d min") % 25)
	assert_true(GameState.records.has("echo_path_best"))
	assert_eq(EchoPath.time_text(65 * 60), Loc.t("%d h %02d min") % [1, 5])
	# Nothing about it goes to the server rankings.
	for path: String in ["res://scripts/online/Online.gd", "res://scripts/online/Leagues.gd"]:
		if FileAccess.file_exists(path):
			assert_false(FileAccess.get_file_as_string(path).contains("echo_path_best"), path)
