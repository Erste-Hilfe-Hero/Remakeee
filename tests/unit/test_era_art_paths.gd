extends GutTest
## Art lookups follow the active era and fall back to older eras when a file is missing.

var _unlocked: int
var _retro: int

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)

func _set_era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

func test_era1_paths() -> void:
	_set_era(EraManager.Era.INK)
	assert_eq(EraManager.art_path("tiles/overworld.png"), "res://art/era1/tiles/overworld.png")
	assert_eq(TilesetFactory.atlas_path(), TilesetFactory.ATLAS_PATH)

func test_era2_falls_back_to_era1() -> void:
	_set_era(EraManager.Era.WASH)
	assert_false(ResourceLoader.exists("res://art/era2/tiles/overworld.png"))
	assert_eq(EraManager.art_path("tiles/overworld.png"), "res://art/era1/tiles/overworld.png")
	assert_eq(EraManager.art_path("chars/elder.png"), "res://art/era1/chars/elder.png")
	assert_eq(EraManager.sprite_path("Wickit"), "res://art/era1/spirlings/wickit_front.png")

func test_missing_everywhere_is_empty() -> void:
	_set_era(EraManager.Era.PANORAMA)
	assert_eq(EraManager.art_path("nope/missing.png"), "")

func test_era_change_clears_caches() -> void:
	_set_era(EraManager.Era.INK)
	var ts: TileSet = TilesetFactory.get_tileset()
	GridWalker.sheet_for("elder")
	ElementFx.shape("drop", 0)
	assert_false(GridWalker._sheets.is_empty())
	assert_false(ElementFx._tex.is_empty())
	_set_era(EraManager.Era.WASH)
	assert_true(GridWalker._sheets.is_empty())
	assert_true(ElementFx._tex.is_empty())
	assert_ne(TilesetFactory.get_tileset(), ts, "tileset rebuilt after era change")
