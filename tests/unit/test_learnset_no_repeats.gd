extends GutTest
## Bug plan item 1337 (learn lists without gaps): 28 species had learn-list entries that
## repeated a move they already knew, so those level-ups taught nothing.

func before_all() -> void:
	Database.reload_data()

func test_no_species_learns_the_same_move_twice() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var seen: Dictionary[String, int] = {}
		for i: int in sd.learnset_moves.size():
			var mv: MoveData = sd.learnset_moves[i]
			assert_false(seen.has(mv.move_name), "%s learns %s again at level %d" % [sd.species_name, mv.move_name, sd.learnset_levels[i]])
			seen[mv.move_name] = sd.learnset_levels[i]

func test_every_learn_level_teaches_something_new() -> void:
	var sd: SpirlingData = Database.species("Millwhit")
	for lv: int in [9, 17, 21]:
		var known: Array[MoveData] = []
		for i: int in sd.learnset_levels.size():
			if sd.learnset_levels[i] < lv:
				known.append(sd.learnset_moves[i])
		for i: int in sd.learnset_levels.size():
			if sd.learnset_levels[i] == lv:
				assert_false(known.has(sd.learnset_moves[i]), "Millwhit level %d" % lv)
