extends GutTest
## Area 3 items 1062 and 1065: every piece of Wayfarer Gear is given out at one fixed place
## (listed in docs/WORLD.md by tools/world_stats.py), and Veydal has at most 10 pieces.

const MAX_GEAR: int = 10

func _gear_ids() -> Array[String]:
	var out: Array[String] = []
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	for it: Dictionary in items:
		if str(it.get("description", "")).begins_with("Wayfarer Gear"):
			out.append(str(it.id))
	return out

func _givers() -> Dictionary:
	var out: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://data/dialogue"):
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
		if not d is Dictionary:
			continue
		for k: String in d:
			var e: Variant = d[k]
			if e is Dictionary:
				var act: PackedStringArray = str(e.get("action", "")).split(" ")
				if act.size() >= 2 and act[0] == "give_item":
					var arr: Array = out.get(act[1], [])
					arr.append("%s/%s" % [f.get_basename(), k])
					out[act[1]] = arr
	return out

func test_veydal_gear_fits_one_page() -> void:
	assert_between(_gear_ids().size(), 1, MAX_GEAR)

func test_every_gear_has_one_fixed_giver_listed_in_the_world_doc() -> void:
	var givers: Dictionary = _givers()
	var doc: String = FileAccess.get_file_as_string("res://docs/WORLD.md")
	for id: String in _gear_ids():
		assert_eq((givers.get(id, []) as Array).size(), 1, "%s is given at exactly one place: %s" % [id, givers.get(id, [])])
		assert_true(doc.contains("| `%s` |" % id), "%s is listed in docs/WORLD.md" % id)
