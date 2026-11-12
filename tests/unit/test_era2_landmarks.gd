extends GutTest
## Every Era I landmark has its Era II colouring (tools/art/era2_colourise.py), so Era II
## places show their landmark in the Aquarell look instead of the Era I inks.

func test_every_landmark_has_an_era2_sprite() -> void:
	var names: PackedStringArray = DirAccess.get_files_at("res://art/era1/landmarks")
	var n: int = 0
	for f: String in names:
		if not f.ends_with(".png"):
			continue
		n += 1
		var era2: String = "res://art/era2/landmarks/" + f
		assert_true(FileAccess.file_exists(era2), "%s has an Era II sprite" % f)
		var a: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/era1/landmarks/" + f))
		var b: Image = Image.load_from_file(ProjectSettings.globalize_path(era2))
		if a == null or b == null:
			continue
		assert_eq(b.get_size(), a.get_size(), "%s keeps its size" % f)
	assert_true(n > 0, "landmarks found")

func test_era2_picks_the_era2_landmark() -> void:
	var f: String = DirAccess.get_files_at("res://art/era1/landmarks")[0]
	assert_eq(EraManager.art_path_from("landmarks/" + f, 2), "res://art/era2/landmarks/" + f)
	assert_eq(EraManager.art_path_from("landmarks/" + f, 1), "res://art/era1/landmarks/" + f)
