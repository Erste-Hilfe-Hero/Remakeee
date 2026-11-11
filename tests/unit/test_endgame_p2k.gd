extends GutTest
## Plan area 8, P2 batch: collection set goals (plan 3355-3357, 3359, 3362, 3363, 3365).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _claimed() -> Dictionary:
	return GameState.records.get("collection", {})

func test_goal_ids_are_unique_and_kinds_known() -> void:
	var ids: Dictionary = {}
	for g: Dictionary in Collection.SET_GOALS + Collection.GOALS + Collection.SEEN_GOALS:
		assert_false(ids.has(g.id), str(g.id))
		ids[g.id] = true
	for g: Dictionary in Collection.SET_GOALS:
		assert_gt(Collection.set_total(str(g.kind)), 0, str(g.kind))
		assert_gt(int(g.waymarks), 0)

func test_arts_used_steps() -> void:
	var arts: Array[String] = Collection.learnable_arts()
	assert_gte(arts.size(), 40)
	for i: int in 20:
		Collection.note_art(arts[i])
	Collection.note_art(arts[0])
	assert_eq(Collection.set_count("arts"), 20, "each art counts once")
	var before: int = GameState.waymarks
	Collection.claim()
	assert_true(_claimed().has("arts_20"))
	assert_false(_claimed().has("arts_40"))
	assert_gt(GameState.waymarks, before)
	var paid: int = GameState.waymarks
	Collection.claim()
	assert_eq(GameState.waymarks, paid, "a goal pays once")

func test_elements_and_temperaments() -> void:
	assert_eq(Collection.set_total("elements"), Elements.E.size())
	assert_eq(Collection.set_total("temperaments"), Spirling.TEMPERAMENTS.size())
	for sd: SpirlingData in Database.spirlings.values():
		GameState.spirlog[sd.species_name] = {"seen": true, "bonded": true}
	assert_eq(Collection.set_count("elements"), Elements.E.size())
	assert_eq(Collection.set_count("lines"), Collection.set_total("lines"))
	Collection.claim()
	assert_true(_claimed().has("elements"))
	assert_true(_claimed().has("lines_seen"))

func test_pages_and_keepsakes() -> void:
	for i: int in range(1, Overworld.PAGE_COUNT + 1):
		GameState.set_flag("page_%d" % i)
	for id: String in Achievements.keepsakes():
		GameState.add_item(id)
	Collection.claim()
	assert_true(_claimed().has("pages"))
	assert_true(_claimed().has("keepsakes"))

func test_ring30_and_lines_in_goals_tab() -> void:
	var text: String = Goals.collection()
	assert_string_contains(text, Loc.t("Arts used"))
	assert_string_contains(text, Loc.t("Kinds at ring 30"))
	assert_eq(Collection.set_lines().size(), 8, "one line per kind of goal")
