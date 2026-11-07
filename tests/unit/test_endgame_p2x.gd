extends GutTest
## Plan area 8, P2 batch: red dot on "Goals" while a reward waits (3529) and "Collect all" (3530).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_nothing_waits_on_a_new_journey() -> void:
	Collection.claim()
	Completion.claim()
	assert_eq(Goals.pending(), 0)
	assert_eq(Goals.collect_all(), [Loc.t("Nothing to collect right now.")] as Array[String])

func test_a_reached_goal_waits_until_collected() -> void:
	var arts: Array[String] = Collection.learnable_arts()
	for i: int in 20:
		Collection.note_art(arts[i])
	assert_eq(Collection.unclaimed(), 1)
	assert_gt(Goals.pending(), 0)
	var before: int = GameState.waymarks
	var lines: Array[String] = Goals.collect_all()
	assert_gt(lines.size(), 0)
	assert_gt(GameState.waymarks, before)
	assert_eq(Collection.unclaimed(), 0)
	assert_eq(Goals.pending(), 0, "the dot goes away")

func test_trips_home_point_to_aldo() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 10)
	s.uid = "home"
	GameState.storage.append(s)
	Expeditions.send(s, 4)
	assert_eq(Goals.trips_home(), 0)
	(GameState.records["expeditions"] as Array)[0]["start"] = Online.unix_now() - 5 * 3600
	assert_eq(Goals.trips_home(), 1)
	assert_gt(Goals.pending(), 0)
	var text: String = "\n".join(Goals.collect_all())
	assert_string_contains(text, "Aldo")
	assert_eq(Expeditions.trips().size(), 1, "the trip itself is picked up at Aldo's")

func test_red_dot_texture() -> void:
	var t: Texture2D = Goals.dot()
	assert_not_null(t)
	assert_eq(t.get_width(), 5)
	assert_eq(Goals.dot(), t, "made once")
