extends GutTest
## Roster data rules from AGENTS.md M1.

func before_all() -> void:
	Database.reload_data()

func test_all_15_spirlings_have_learnsets_from_moves_json() -> void:
	assert_eq(Database.spirlings.size(), 357, "87 before the act lines, 58 Solenne, 58 Ashmere, 54 Corvane and 30 Veydal kinds, 70 Era III Quillmarch kinds")
	for sd: SpirlingData in Database.spirlings.values():
		assert_gt(sd.learnset_moves.size(), 0, sd.species_name)
		for mv: MoveData in sd.learnset_moves:
			assert_true(Database.moves.has(mv.move_name))

func test_every_element_has_at_least_3_moves() -> void:
	var counts: Dictionary[int, int] = {}
	for mv: MoveData in Database.moves.values():
		counts[mv.element] = counts.get(mv.element, 0) + 1
	for e: int in Elements.E.values():
		assert_gte(counts.get(e, 0), 3, Elements.E.keys()[e])

func test_fresh_spirling_knows_up_to_4_moves_from_its_learnset() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 20)
	assert_between(s.moves.size(), 1, 4)
	for mv: MoveData in s.moves:
		assert_true(Database.species("Kindlop").learnset_moves.has(mv))

func test_level_up_learns_move() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 4)
	var learned: Array[MoveData] = s.level_up()
	assert_eq(s.level, 5)
	assert_eq(learned.size(), 1)
	assert_eq(learned[0].move_name, "Heat Haze")

func test_evolution() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 16)
	assert_true(s.can_evolve())
	s.evolve()
	assert_eq(s.data.species_name, "Smoldrake")
	assert_eq(Database.species("Kindlop").species_name, "Kindlop", "species data untouched")

func test_spirling_round_trips_through_dict() -> void:
	var s := Spirling.new(Database.species("Zippit"), 12)
	s.nickname = "Bzz"
	s.hp = 7
	var copy: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(copy.to_dict(), s.to_dict())
