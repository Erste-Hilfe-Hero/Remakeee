extends GutTest
## Content: every Spirling has art and can be met in the world, and dex numbers are unique.

func before_all() -> void:
	Database.load_all()

func test_every_species_has_art() -> void:
	for name: String in Database.spirlings:
		for side: String in ["front", "back"]:
			var path: String = "res://art/era1/spirlings/%s_%s.png" % [name.to_lower(), side]
			assert_true(ResourceLoader.exists(path), "missing %s" % path)

func test_dex_ids_are_unique_and_dense() -> void:
	var ids: Array[int] = []
	for sd: SpirlingData in Database.spirlings.values():
		assert_false(ids.has(sd.dex_id), "duplicate dex id %d" % sd.dex_id)
		ids.append(sd.dex_id)
	ids.sort()
	assert_eq(ids[0], 1)
	assert_eq(ids[-1], ids.size(), "dex ids should run 1..N without gaps")

## A species is reachable if it is a starter, spawns somewhere, or evolves from one that is.
func test_every_species_is_reachable() -> void:
	var reach: Dictionary = {}
	for sp: String in Database.STARTERS:
		reach[sp] = true
	var enc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	for area: String in enc:
		for s: Dictionary in enc[area].spawns:
			reach[str(s.species)] = true
	var grew: bool = true
	while grew:
		grew = false
		for sd: SpirlingData in Database.spirlings.values():
			if reach.has(sd.species_name) and sd.evolves_to != null and not reach.has(sd.evolves_to.species_name):
				reach[sd.evolves_to.species_name] = true
				grew = true
	for name: String in Database.spirlings:
		assert_true(reach.has(name), "%s can't be met anywhere" % name)

func test_lumen_and_umbra_have_base_forms() -> void:
	var seen: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.elements.size() == 1:
			seen[sd.elements[0]] = true
	for e: int in Elements.E.values():
		if e == Elements.E.STONE:
			continue  # Stone shows up in duals (Shalebat, Calderox, Duskdigger).
		assert_true(seen.has(e), "no single-element %s Spirling" % Elements.element_name(e))
