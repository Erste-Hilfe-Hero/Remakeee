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
	# Era2 tiles and characters ship: the active era wins.
	assert_eq(EraManager.art_path("tiles/overworld.png"), "res://art/era2/tiles/overworld.png")
	assert_eq(EraManager.art_path("chars/elder.png"), "res://art/era2/chars/elder.png")
	# No era2 Spirling sprites ship: those fall back to era1.
	assert_false(ResourceLoader.exists("res://art/era2/spirlings/wickit_front.png"))
	assert_eq(EraManager.art_path("spirlings/wickit_front.png"), "res://art/era1/spirlings/wickit_front.png")
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

func test_story_regions_stay_ink() -> void:
	_set_era(EraManager.Era.INK)
	for region: String in ["veydal", "corvane", "ashmere", "solenne"]:
		EraManager.unlock_region(region)
	assert_eq(EraManager.unlocked_era, EraManager.Era.INK)

func test_story_complete_unlocks_wash() -> void:
	_set_era(EraManager.Era.INK)
	EraManager.unlock_story_end(false)
	assert_eq(EraManager.unlocked_era, EraManager.Era.INK)
	EraManager.unlock_story_end(true)
	assert_eq(EraManager.unlocked_era, EraManager.Era.WASH)

func test_saved_higher_era_is_kept() -> void:
	EraManager.from_dict({"unlocked_era": EraManager.Era.ETCHED, "retro_filter": 1})
	EraManager.unlock_region("veydal")
	EraManager.unlock_story_end(true)
	assert_eq(EraManager.unlocked_era, EraManager.Era.ETCHED)
	assert_eq(EraManager.retro_filter, 1)

func test_era1_species_keeps_era1_in_era2_world() -> void:
	_set_era(EraManager.Era.WASH)
	assert_eq(EraManager.species_era("Wickit"), EraManager.Era.INK)
	assert_eq(EraManager.sprite_path("Wickit", "back"), "res://art/era1/spirlings/wickit_back.png")
	assert_eq(EraManager.battle_sprite_size("Wickit"), 56)

func test_era2_species_uses_era2_art_when_present() -> void:
	var sd: SpirlingData = Database.species("Wickit")
	var old: int = sd.era
	sd.era = EraManager.Era.ETCHED
	assert_eq(EraManager.battle_sprite_size("Wickit"), EraManager.BATTLE_SPRITE_SIZE[EraManager.Era.ETCHED])
	# No era2/era3 file yet: falls back to era1.
	assert_eq(EraManager.sprite_path("Wickit"), "res://art/era1/spirlings/wickit_front.png")
	assert_eq(EraManager.art_path_from("tiles/overworld.png", 2), "res://art/era2/tiles/overworld.png")
	assert_eq(EraManager.art_path_from("spirlings/wickit_back.png", 2), "res://art/era1/spirlings/wickit_back.png")
	sd.era = old

func test_era2_species_picks_era2_file() -> void:
	# An existing era2 file is preferred over era1 for a species from era 2.
	var sd: SpirlingData = Database.species("Wickit")
	var old: int = sd.era
	sd.era = EraManager.Era.WASH
	var dir: String = "res://art/era2/spirlings"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.save_png(dir + "/wickit_front.png")
	var p: String = EraManager.sprite_path("Wickit")
	DirAccess.remove_absolute(dir + "/wickit_front.png")
	DirAccess.remove_absolute(dir)
	sd.era = old
	assert_eq(p, "res://art/era2/spirlings/wickit_front.png")
