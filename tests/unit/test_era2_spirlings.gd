extends GutTest
## Era II battle sprites (tools/art/gen_era2.py, Vellmarch's own Spirlings): the limited-colour
## rules of the Era II look, checked on the files in art/era2/spirlings/.

const DIR: String = "res://art/era2/spirlings/"
const MAX_COLOURS: int = 8

func _fronts() -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(DIR)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with("_front.png"):
			out.append(f)
	out.sort()
	return out

func _load(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))

func test_vellmarch_has_seventy_kinds() -> void:
	assert_gte(_fronts().size(), 70, "70 own Era II Spirlings for Vellmarch")

func test_every_front_has_a_back() -> void:
	for f: String in _fronts():
		assert_true(FileAccess.file_exists(DIR + f.replace("_front.png", "_back.png")), f + ": back sprite")

func test_size_matches_the_era() -> void:
	var s: int = EraManager.BATTLE_SPRITE_SIZE[EraManager.Era.WASH]
	for f: String in _fronts():
		for side: String in ["front", "back"]:
			var img: Image = _load(DIR + f.replace("front", side))
			assert_not_null(img, f + " " + side)
			if img != null:
				assert_eq(img.get_size(), Vector2i(s, s), f + " " + side + ": era size")

func test_limited_colour() -> void:
	for f: String in _fronts():
		var img: Image = _load(DIR + f)
		if img == null:
			continue
		var cols: Dictionary = {}
		var half_alpha: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a == 0.0:
					continue
				if c.a < 1.0:
					half_alpha += 1
				cols[c.to_html(false)] = true
		assert_between(cols.size(), 4, MAX_COLOURS, f + ": 4 to 8 colours")
		assert_false(cols.has("000000"), f + ": coloured outline, no pure black")
		assert_eq(half_alpha, 0, f + ": no soft edges")

func test_front_and_back_share_a_palette() -> void:
	for f: String in _fronts():
		var a: Image = _load(DIR + f)
		var b: Image = _load(DIR + f.replace("_front", "_back"))
		if a == null or b == null:
			continue
		var front: Dictionary = {}
		for y: int in a.get_height():
			for x: int in a.get_width():
				if a.get_pixel(x, y).a > 0.0:
					front[a.get_pixel(x, y).to_html(false)] = true
		var extra: int = 0
		for y: int in b.get_height():
			for x: int in b.get_width():
				if b.get_pixel(x, y).a > 0.0 and not front.has(b.get_pixel(x, y).to_html(false)):
					extra += 1
		assert_eq(extra, 0, f + ": back uses the front's colours")
