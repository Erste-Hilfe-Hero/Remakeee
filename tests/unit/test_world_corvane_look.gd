extends GutTest
## World area: Act II Corvane has its own Era I look (data/region_looks.json): own inks,
## own tile atlas (tools/art/gen_tiles_corvane.py) and props on its maps.

const OUTDOOR: Array[String] = ["corvane_quay", "madderby", "woadfen", "stillwater", "greyreach"]

func after_each() -> void:
	EraManager.set_region("")
	TilesetFactory.clear_cache()

func test_corvane_has_four_inks_in_the_filter_bands() -> void:
	var inks: Array[Color] = RegionLook.palette("corvane")
	assert_eq(inks.size(), 4)
	for i: int in inks.size():
		var l: float = inks[i].r * 0.299 + inks[i].g * 0.587 + inks[i].b * 0.114
		assert_between(l, i * 0.25, (i + 1) * 0.25, "ink %d luminance" % i)

func test_corvane_inks_differ_from_the_base_ink() -> void:
	var inks: Array[Color] = EraManager.inks_for("corvane")
	for i: int in 4:
		assert_ne(inks[i], EraManager.INK_PALETTE[i])
	assert_eq(EraManager.inks_for("veydal"), EraManager.INK_PALETTE)

func test_set_region_swaps_the_screen_inks() -> void:
	EraManager.set_region("corvane")
	assert_eq(EraManager.current_region, "corvane")
	EraManager.set_region("veydal")
	assert_eq(EraManager.current_region, "veydal")

func test_corvane_uses_its_own_atlas_in_era_one() -> void:
	if EraManager.active_era() != EraManager.Era.INK:
		pending("not in Era I")
		return
	var own: String = TilesetFactory.atlas_path("corvane")
	assert_string_contains(own, "overworld_corvane.png")
	assert_true(ResourceLoader.exists(own) or FileAccess.file_exists(own))
	assert_false(TilesetFactory.atlas_path("veydal").contains("corvane"))
	assert_ne(TilesetFactory.get_tileset("corvane"), TilesetFactory.get_tileset("veydal"))

func test_atlas_has_the_base_layout() -> void:
	var tex: Texture2D = load("res://art/era1/tiles/overworld_corvane.png")
	assert_not_null(tex)
	if tex != null:
		assert_eq(tex.get_width(), TilesetFactory.TILE * TilesetFactory.Kind.size())
		assert_eq(tex.get_height(), TilesetFactory.TILE * TilesetFactory.VARIANT_ROWS)

func test_outdoor_maps_carry_fen_props() -> void:
	for id: String in OUTDOOR:
		var m: MapData = MapData.load_map(id)
		var vats: int = 0
		for row: String in m.rows:
			vats += row.count("@")
		assert_gt(vats, 0, "%s has dye vats" % id)

func test_biome_name_and_strings() -> void:
	assert_eq(RegionLook.biome("corvane"), "dye_fen")
	assert_eq(RegionLook.biome("veydal"), "")
	var line: String = RegionLook.arrive_line("corvane")
	assert_false(line.is_empty())
	assert_ne(Loc.load_table("de").get("strings", {}).get(line, ""), "", "German arrive line")
