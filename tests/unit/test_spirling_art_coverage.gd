extends GutTest
## No placeholder in battle: every Spirling kind that a wild table, a region sheet or a Tamer
## team names ("species", or the "stand_in" a still-empty slot plays with) must be a known kind
## with a front and a back sprite (EraManager.sprite_path) and a Gleam palette. Also: every kind
## of data/spirlings.json has art, and Quivermoor's own Era V sprites (tools/art/gen_era5.py)
## keep the Era V rules. Numbers per era and region: python3 tools/art/art_gap.py.

const ERA5_DIR: String = "res://art/era5/spirlings/"
const ERA5_MAX_COLOURS: int = 26

func _json_files() -> Array[String]:
	var out: Array[String] = []
	for dir: String in ["res://data/", "res://data/maps/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				out.append(dir + f)
	out.sort()
	return out

func _collect(node: Variant, src: String, into: Dictionary) -> void:
	if node is Dictionary:
		for key: Variant in node:
			var v: Variant = node[key]
			if (key == "species" or key == "stand_in") and v is String and v != "":
				if not into.has(v):
					into[v] = src
			_collect(v, src, into)
	elif node is Array:
		for v: Variant in node:
			_collect(v, src, into)

## kind -> first file that names it
func _used() -> Dictionary:
	var out: Dictionary = {}
	for path: String in _json_files():
		_collect(JSON.parse_string(FileAccess.get_file_as_string(path)), path, out)
	return out

func _gleam() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/gleam_palettes.json"))["palettes"]

func _lacks(kind: String, gleam: Dictionary) -> String:
	var out: PackedStringArray = []
	for facing: String in ["front", "back"]:
		if EraManager.sprite_path(kind, facing) == "":
			out.append(facing)
	if not gleam.has(kind):
		out.append("gleam")
	return ", ".join(out)

func test_tables_and_teams_are_found() -> void:
	var used: Dictionary = _used()
	assert_gt(used.size(), 300, "the walk finds the kinds of the wild tables and teams")
	assert_true(used.has("Kindlop"), "a wild kind of data/encounters.json")
	assert_true(used.has("Peatlet"), "a stand-in of data/region5.json")

func test_every_kind_in_a_table_or_team_has_art() -> void:
	var gleam: Dictionary = _gleam()
	var used: Dictionary = _used()
	var bad: PackedStringArray = []
	for kind: String in used:
		if Database.species(kind) == null:
			bad.append("%s (%s): not a known kind" % [kind, used[kind]])
			continue
		var lacks: String = _lacks(kind, gleam)
		if lacks != "":
			bad.append("%s (%s): no %s" % [kind, used[kind], lacks])
	assert_eq(bad.size(), 0, "kinds without art in a table or team:\n" + "\n".join(bad))

func test_every_kind_in_the_data_has_art() -> void:
	var gleam: Dictionary = _gleam()
	var bad: PackedStringArray = []
	for sd: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://data/spirlings.json")):
		var lacks: String = _lacks(str(sd["name"]), gleam)
		if lacks != "":
			bad.append("%s: no %s" % [sd["name"], lacks])
	assert_eq(bad.size(), 0, "kinds without art:\n" + "\n".join(bad))

func test_a_kind_without_sprites_is_caught() -> void:
	assert_eq(EraManager.art_path_from("spirlings/no_such_kind_front.png", EraManager.NEWEST), "",
		"a missing sprite resolves to no path, which the checks above report")

func _era5_fronts() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(ERA5_DIR):
		if f.ends_with("_front.png"):
			out.append(f)
	out.sort()
	return out

func test_quivermoor_has_seventy_drawn_kinds() -> void:
	assert_gte(_era5_fronts().size(), 70, "70 own Era V Spirlings for Quivermoor")

func test_era5_sprites_keep_the_era_rules() -> void:
	var s: int = EraManager.BATTLE_SPRITE_SIZE[EraManager.Era.LIVING]
	for f: String in _era5_fronts():
		for side: String in ["front", "back"]:
			var path: String = ERA5_DIR + f.replace("_front", "_" + side)
			assert_true(FileAccess.file_exists(path), path)
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null:
				fail_test(path + " does not load")
				continue
			var cols: Dictionary = {}
			var soft: int = 0
			for y: int in img.get_height():
				for x: int in img.get_width():
					var c: Color = img.get_pixel(x, y)
					if c.a == 0.0:
						continue
					if c.a < 1.0:
						soft += 1
					cols[c.to_html(false)] = true
			if img.get_size() != Vector2i(s, s) or soft > 0 or cols.has("000000") or cols.size() < 8 or cols.size() > ERA5_MAX_COLOURS:
				fail_test("%s: size %s, %d colours, %d soft pixels, black %s" % [path, img.get_size(), cols.size(), soft, cols.has("000000")])
	pass_test("Era V sprites checked")
