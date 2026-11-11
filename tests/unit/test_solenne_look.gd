extends GutTest
## Welt akt4: Solenne has its own Era I look - desert atlas, four sun inks, desert biome - while
## the other regions keep the shared atlas and inks.

func before_each() -> void:
	TilesetFactory.clear_cache()

func after_all() -> void:
	TilesetFactory.clear_cache()

func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

func test_solenne_has_its_own_atlas_with_the_shared_layout() -> void:
	var own: String = TilesetFactory.atlas_path("solenne")
	var shared: String = TilesetFactory.atlas_path("corvane")
	assert_true(own.ends_with("overworld_solenne.png"), own)
	assert_true(shared.ends_with("tiles/overworld.png"), shared)
	var a: Image = (load(own) as Texture2D).get_image()
	var b: Image = (load(shared) as Texture2D).get_image()
	assert_eq(a.get_size(), b.get_size(), "same columns and variant rows")
	assert_eq(a.get_width(), TilesetFactory.Kind.size() * TilesetFactory.TILE)

func test_tilesets_are_cached_per_region() -> void:
	var s: TileSet = TilesetFactory.get_tileset("solenne")
	assert_same(TilesetFactory.get_tileset("solenne"), s)
	assert_ne(TilesetFactory.get_tileset("corvane"), s)
	assert_same(TilesetFactory.get_tileset(""), TilesetFactory.get_tileset("corvane"))

func test_solenne_inks_are_four_tones_in_the_filter_quarters() -> void:
	var inks: Array[Color] = EraManager.inks_for("solenne")
	assert_eq(inks.size(), 4)
	assert_ne(inks, EraManager.INK_PALETTE)
	for i: int in inks.size():
		var l: float = _lum(inks[i])
		assert_between(l, i * 0.25, (i + 1) * 0.25, "ink %d stays in its luminance quarter" % i)
	assert_eq(EraManager.inks_for("corvane"), EraManager.INK_PALETTE)

func test_solenne_atlas_uses_only_the_four_solenne_inks() -> void:
	var img: Image = (load(TilesetFactory.atlas_path("solenne")) as Texture2D).get_image()
	var inks: Array[Color] = EraManager.inks_for("solenne")
	for y: int in range(0, img.get_height(), 3):
		for x: int in range(0, img.get_width(), 3):
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var hit: bool = false
			for k: Color in inks:
				if c.is_equal_approx(k) or (absf(c.r - k.r) < 0.01 and absf(c.g - k.g) < 0.01 and absf(c.b - k.b) < 0.01):
					hit = true
			if not hit:
				fail_test("pixel %d,%d is not a Solenne ink" % [x, y])
				return
	pass_test("Era I four tones")

func test_ochrewell_is_desert_with_cacti() -> void:
	var m: MapData = MapData.load_map("ochrewell")
	assert_eq(m.biome, "desert")
	assert_eq(RegionLook.biome("solenne"), "desert")
	assert_false(RegionLook.arrive_line("solenne").is_empty())
	assert_true(WeatherCycle.shares("desert").has("wind"))
	var cacti: int = 0
	for r: String in m.rows:
		cacti += r.count("T")
	assert_gte(cacti, 4)
