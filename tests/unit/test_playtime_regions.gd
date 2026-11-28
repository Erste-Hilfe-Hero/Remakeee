extends GutTest
## tools/act_hours.py measures every post-game era region too (owner rule: at least 20 h per act
## and per era region). Each region sheet and each region in data/eras.json has an entry under
## "regions" in data/playtime.json with the same era, so a new region is never left unmeasured.

func _json(path: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw if raw is Dictionary else {}

func test_every_era_region_is_measured() -> void:
	var regions: Dictionary = _json("res://data/playtime.json").get("regions", {})
	assert_false(regions.is_empty(), "playtime.json lists the era regions")
	for path: String in ["res://data/region2.json", "res://data/region4.json", "res://data/region5.json"]:
		var sheet: Dictionary = _json(path)
		var id: String = str(sheet.get("id", ""))
		assert_true(regions.has(id), "%s is measured" % id)
		if regions.has(id):
			assert_eq(int(regions[id].era), int(sheet.era), id)
			assert_eq(str(regions[id].sheet), path.trim_prefix("res://"), id)
			assert_eq(str(regions[id].region), id, id)
	var eras: Dictionary = _json("res://data/eras.json").get("regions", {})
	for id: String in eras:
		assert_true(regions.has(id), "%s is measured" % id)
		if regions.has(id):
			assert_eq(int(regions[id].era), int(eras[id]), id)

func test_regions_do_not_reuse_act_regions() -> void:
	var cfg: Dictionary = _json("res://data/playtime.json")
	var act_regions: Array = []
	for a: Variant in cfg.acts.values():
		act_regions.append(str((a as Dictionary).region))
	for id: Variant in cfg.regions:
		assert_false(str(cfg.regions[id].region) in act_regions, str(id))
		assert_between(int(cfg.regions[id].era), 2, 5, str(id))
