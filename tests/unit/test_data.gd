extends GutTest
## Pins the authored JSON: every reference must resolve.

func test_data_has_no_broken_references() -> void:
	var errors: PackedStringArray = DataValidator.validate()
	assert_eq(errors.size(), 0, "Data errors:\n" + "\n".join(errors))

func test_validator_catches_bad_evolution() -> void:
	var dir: String = "user://validator_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var moves_path: String = dir + "/moves.json"
	var spirlings_path: String = dir + "/spirlings.json"
	_write(moves_path, '[{"name":"Test Strike","element":"EMBER","kind":"PHYSICAL","power":40,"accuracy":1.0,"energy":2}]')
	_write(spirlings_path, '[{"dex_id":1,"name":"A","elements":["EMBER","NOPE"],"base":{},"evolves_to":"Missing","evolve_level":5,"learnset":{"1":["Unknown Move"]}}]')
	var errors: PackedStringArray = DataValidator.validate(spirlings_path, moves_path)
	var joined: String = "\n".join(errors)
	assert_string_contains(joined, "unknown element 'NOPE'")
	assert_string_contains(joined, "evolves_to 'Missing'")
	assert_string_contains(joined, "learnset move 'Unknown Move'")

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_element_chart_matches_spec() -> void:
	var E := Elements.E
	assert_eq(Elements.single(E.EMBER, E.BLOOM), 2.0)
	assert_eq(Elements.single(E.BLOOM, E.EMBER), 0.5)
	assert_eq(Elements.single(E.LUMEN, E.UMBRA), 2.0, "Lumen beats Umbra (data/type_chart.json)")
	assert_eq(Elements.single(E.UMBRA, E.LUMEN), 0.5, "no mutual pair left in the chart")
	assert_eq(Elements.multiplier(E.TIDE, [E.EMBER, E.STONE]), 4.0, "dual elements multiply")
	for atk: int in E.values():
		assert_eq((Elements.STRONG[atk] as Array).size(), 2, "each element beats exactly 2")
