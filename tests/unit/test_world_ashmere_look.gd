extends GutTest
## Act III Ashmere has its own Era I look: own atlas, own four inks, ash props on its maps.

const ASH_MAPS: Array[String] = ["ashmere_station", "cinderfold", "saltglass", "kiln_rift"]

var _era: int
var _retro: int

func before_all() -> void:
	Database.load_all()
	_era = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_all() -> void:
	EraManager.unlocked_era = _era
	EraManager.set_retro_filter(_retro)
	EraManager.set_region_ink("")

func _set_era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

func test_ashmere_has_its_own_atlas_in_era_one() -> void:
	_set_era(EraManager.Era.INK)
	assert_eq(TilesetFactory.atlas_path("ashmere"), "res://art/era1/tiles/overworld_ashmere.png")
	assert_eq(TilesetFactory.atlas_path("veydal"), "res://art/era1/tiles/overworld_veydal.png")
	assert_ne(TilesetFactory.get_tileset("ashmere"), TilesetFactory.get_tileset("veydal"))
	var tex: Texture2D = load(TilesetFactory.atlas_path("ashmere"))
	var base: Texture2D = load(TilesetFactory.ATLAS_PATH)
	assert_eq(tex.get_size(), base.get_size(), "same layout as the shared atlas")

func test_newer_era_keeps_its_own_shared_atlas() -> void:
	_set_era(EraManager.Era.WASH)
	assert_eq(TilesetFactory.atlas_path("ashmere"), "res://art/era2/tiles/overworld.png")
	_set_era(EraManager.Era.INK)

func test_ashmere_inks_are_four_and_ordered_dark_to_light() -> void:
	var ink: Array = TilesetFactory.look("ashmere").ink
	assert_eq(ink.size(), 4)
	var last: float = -1.0
	for h: Variant in ink:
		var l: float = Color(str(h)).get_luminance()
		assert_gt(l, last, "ink %s lighter than the one before" % h)
		last = l

func test_region_ink_switches_and_falls_back() -> void:
	EraManager.set_region_ink("ashmere")
	assert_eq(EraManager.ink[1], Color(str(TilesetFactory.look("ashmere").ink[1])))
	assert_ne(EraManager.ink, EraManager.INK_PALETTE)
	EraManager.set_region_ink("veydal")
	assert_eq(EraManager.ink, EraManager.INK_PALETTE)

func test_ashmere_maps_carry_ash_props_and_stay_connected() -> void:
	for id: String in ASH_MAPS:
		var m: MapData = MapData.load_map(id)
		assert_eq(m.region, "ashmere", id)
		var blooms: int = 0
		for row: String in m.rows:
			blooms += row.count("*")
		assert_gt(blooms, 0, "%s has ember blooms" % id)
		for sp: String in m.spots:
			var c: Vector2i = Vector2i(int(m.spots[sp][0]), int(m.spots[sp][1]))
			assert_false(TilesetFactory.kind_for(m.rows[c.y][c.x]) in [TilesetFactory.Kind.TREE, TilesetFactory.Kind.ROCK],
				"%s spot %s not under a prop" % [id, sp])
