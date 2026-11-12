extends GutTest
## Overworld terrain look per era (data/era_overworld_look.json, EraTerrainLook,
## docs/ERA_FEEL_TILES.md): every era is configured, a later era never loses what an earlier
## one had, Era I stays a flat two-frame map, and reduced motion freezes everything that moves.

const ERA_REGIONS: Dictionary[int, Array] = {1: ["veydal", "corvane", "ashmere", "solenne"], 2: ["vellmarch"], 3: ["quillmarch"], 4: ["halcyra"], 5: ["quivermoor"]}
const TOWN_ROWS: Array[String] = ["TTTTTT", "T.RR.T", "T.HD.T", "T.__~T", "T,*_~T", "TTTTTT"]

var _reduce: bool
var _retro: int
var _unlocked: int

func before_each() -> void:
	_reduce = GameState.reduce_motion
	_retro = EraManager.retro_filter
	_unlocked = EraManager.unlocked_era
	GameState.reduce_motion = false

func after_each() -> void:
	GameState.reduce_motion = _reduce
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(mini(_retro, _unlocked))
	EraTerrainLook.enabled = true

func _map(region: String, biome: String = "town") -> MapData:
	return MapData.from_dict("look_test", {"name": "Look", "region": region, "outdoor": true, "biome": biome, "rows": TOWN_ROWS})

func _look(region: String, era: int, biome: String = "town") -> EraTerrainLook:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.set_retro_filter(era)
	var host := Node2D.new()
	add_child_autofree(host)
	var ground := TileMapLayer.new()
	host.add_child(ground)
	var people := Node2D.new()
	host.add_child(people)
	var cam := Camera2D.new()
	host.add_child(cam)
	var m: MapData = _map(region, biome)
	m.paint(ground)
	var look := EraTerrainLook.new()
	host.add_child(look)
	host.move_child(look, 1)
	look.show_map(m, ground, cam, people)
	return look

func test_data_file_is_sound() -> void:
	assert_eq(EraTerrainLook.problems(), [] as Array[String])

func test_every_era_is_configured() -> void:
	for era: int in range(EraManager.Era.INK, EraManager.NEWEST + 1):
		var c: Dictionary = EraTerrainLook.era_cfg(era)
		assert_false(c.is_empty(), "era %d" % era)
		assert_gt(int(c.anim.frames), 1, "era %d animates" % era)
		assert_false((c.anim.kinds as Dictionary).is_empty(), "era %d has animated kinds" % era)

func test_every_era_region_gets_its_own_tier() -> void:
	for era: int in ERA_REGIONS:
		for region: String in ERA_REGIONS[era]:
			assert_eq(EraTerrainLook.tier_for(region, EraManager.NEWEST), era, region)

func test_old_regions_keep_their_look_and_retro_caps_new_ones() -> void:
	assert_eq(EraTerrainLook.tier_for("veydal", 5), 1)
	assert_eq(EraTerrainLook.tier_for("quivermoor", 2), 2)
	assert_eq(EraTerrainLook.tier_for("halcyra", 1), 1)

func test_later_eras_never_lose_a_feature() -> void:
	for era: int in range(EraManager.Era.WASH, EraManager.NEWEST + 1):
		var now: Dictionary = EraTerrainLook.era_cfg(era)
		var before: Dictionary = EraTerrainLook.era_cfg(era - 1)
		for key: String in EraTerrainLook.BOOL_KEYS:
			assert_true(bool(now[key]) or not bool(before[key]), "era %d keeps %s" % [era, key])
		for key: String in EraTerrainLook.NUM_KEYS:
			assert_gte(float(now[key]), float(before[key]), "era %d %s" % [era, key])
		assert_gte(int(now.anim.frames), int(before.anim.frames), "era %d frames" % era)
		for kind_name: String in before.anim.kinds:
			assert_true((now.anim.kinds as Dictionary).has(kind_name), "era %d still animates %s" % [era, kind_name])

func test_each_era_adds_something() -> void:
	for era: int in range(EraManager.Era.WASH, EraManager.NEWEST + 1):
		assert_ne(JSON.stringify(_features(era)), JSON.stringify(_features(era - 1)), "era %d" % era)

func _features(era: int) -> Dictionary:
	var c: Dictionary = EraTerrainLook.era_cfg(era).duplicate(true)
	c.erase("name")
	return c

func test_era_one_is_flat_with_two_frames_of_water_and_flowers() -> void:
	var c: Dictionary = EraTerrainLook.era_cfg(1)
	assert_eq(int(c.anim.frames), 2)
	var kinds: Array = (c.anim.kinds as Dictionary).keys()
	kinds.sort()
	assert_eq(kinds, ["FLOWER", "WATER"])
	for key: String in EraTerrainLook.BOOL_KEYS:
		assert_false(bool(c[key]), key)
	for key: String in EraTerrainLook.NUM_KEYS:
		assert_eq(float(c[key]), 0.0, key)

func test_the_generation_steps() -> void:
	assert_true((EraTerrainLook.era_cfg(2).anim.kinds as Dictionary).has("TALL_GRASS"), "Era II grass moves")
	assert_false(bool(EraTerrainLook.era_cfg(2).edges))
	for key: String in ["edges", "contact_shade", "reflections"]:
		assert_true(bool(EraTerrainLook.era_cfg(3)[key]), "Era III " + key)
	assert_false(bool(EraTerrainLook.era_cfg(3).drop_shadows))
	assert_true(bool(EraTerrainLook.era_cfg(4).drop_shadows))
	assert_gt(int(EraTerrainLook.era_cfg(4).canopy_lift), 0)
	assert_eq(float(EraTerrainLook.era_cfg(4).town_zoom), 0.0)
	assert_false(bool(EraTerrainLook.era_cfg(4).banners))
	assert_true(bool(EraTerrainLook.era_cfg(5).banners))
	assert_gt(float(EraTerrainLook.era_cfg(5).parallax_px), 0.0)
	assert_gt(float(EraTerrainLook.era_cfg(5).town_zoom), 0.0)
	assert_true(bool(EraTerrainLook.era_cfg(5).anim.wave))
	assert_true((EraTerrainLook.era_cfg(5).anim.kinds as Dictionary).has("GRASS"))

func test_raised_atlases_exist_for_the_layered_eras() -> void:
	for era: int in [3, 4, 5]:
		for region: String in ERA_REGIONS[era]:
			var path: String = str(EraTerrainLook.shared("raised_atlas")) % [era, region]
			assert_true(FileAccess.file_exists(path), path)

func test_frames_cycle_and_freeze_with_reduced_motion() -> void:
	assert_eq(EraTerrainLook.anim_frame(5, 4, false), 1)
	assert_eq(EraTerrainLook.anim_frame(8, 8, false), 0)
	for t: int in 9:
		assert_eq(EraTerrainLook.anim_frame(t, 8, true), 0)

func test_sway_and_scroll_stay_small() -> void:
	assert_eq(EraTerrainLook.sway_offset(2, 0, Vector2i.ZERO, false), 0)
	assert_eq(EraTerrainLook.sway_offset(2, 1, Vector2i.ZERO, false), 1)
	var seen: Dictionary = {}
	for f: int in 8:
		var off: int = EraTerrainLook.sway_offset(8, f, Vector2i.ZERO, true)
		assert_between(off, -1, 1)
		seen[off] = true
		assert_between(EraTerrainLook.scroll_offset(8, f), 0, 4)
	assert_eq(seen.size(), 3, "swings both ways")
	assert_ne(EraTerrainLook.sway_offset(8, 1, Vector2i(0, 0), true), EraTerrainLook.sway_offset(8, 1, Vector2i(4, 0), true), "the wave travels")
	assert_eq(EraTerrainLook.sway_offset(8, 1, Vector2i(0, 0), false), EraTerrainLook.sway_offset(8, 1, Vector2i(4, 0), false))
	assert_eq(EraTerrainLook.scroll_offset(4, 0), EraTerrainLook.scroll_offset(4, 4), "the drift loops")

func test_shadow_follows_the_sun() -> void:
	var foot := Rect2(0, 8, 16, 8)
	var right: PackedVector2Array = EraTerrainLook.shadow_hull(foot, EraTerrainLook.shadow_shift(Vector2(0.5, 0.25), 12.0))
	var left: PackedVector2Array = EraTerrainLook.shadow_hull(foot, EraTerrainLook.shadow_shift(Vector2(-0.5, 0.25), 12.0))
	assert_eq(right.size(), 6)
	assert_eq(left.size(), 6)
	assert_eq(_bounds(right), Rect2(0, 8, 22, 11))
	assert_eq(_bounds(left), Rect2(-6, 8, 22, 11))
	var dawn: Array = EraTerrainLook.sun_of(DayCycle.Phase.DAWN, true, true).dir
	var dusk: Array = EraTerrainLook.sun_of(DayCycle.Phase.DUSK, true, true).dir
	assert_lt(float(dawn[0]), 0.0, "morning shadows fall west")
	assert_gt(float(dusk[0]), 0.0, "evening shadows fall east")

func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		r = r.expand(p)
	return r

func test_sun_is_plain_day_indoors_or_with_the_day_cycle_off() -> void:
	var day: Dictionary = EraTerrainLook.sun_of(DayCycle.Phase.DAY, true, true)
	assert_ne(EraTerrainLook.sun_of(DayCycle.Phase.NIGHT, true, true), day)
	assert_eq(EraTerrainLook.sun_of(DayCycle.Phase.NIGHT, false, true), day)
	assert_eq(EraTerrainLook.sun_of(DayCycle.Phase.NIGHT, true, false), day)

func test_lean_points_away_from_the_centre_and_stops_with_reduced_motion() -> void:
	assert_eq(EraTerrainLook.lean(Vector2(180, 100), Vector2(100, 100), 3.0, 40.0, false), Vector2(2, 0))
	assert_eq(EraTerrainLook.lean(Vector2(-900, 900), Vector2(100, 100), 3.0, 40.0, false), Vector2(-3, 3))
	assert_eq(EraTerrainLook.lean(Vector2(180, 100), Vector2(100, 100), 3.0, 40.0, true), Vector2.ZERO)
	assert_eq(EraTerrainLook.lean(Vector2(180, 100), Vector2(100, 100), 0.0, 40.0, false), Vector2.ZERO)

func test_town_zoom_settles_on_crisp_pixels_and_is_off_with_reduced_motion() -> void:
	assert_almost_eq(EraTerrainLook.zoom_at(0.0, 0.1, 1.6, false), 0.9, 0.001)
	assert_eq(EraTerrainLook.zoom_at(1.6, 0.1, 1.6, false), 1.0)
	assert_eq(EraTerrainLook.zoom_at(9.0, 0.1, 1.6, false), 1.0)
	assert_gt(EraTerrainLook.zoom_at(0.8, 0.1, 1.6, false), EraTerrainLook.zoom_at(0.2, 0.1, 1.6, false))
	for t: float in [0.0, 0.5, 1.6]:
		assert_eq(EraTerrainLook.zoom_at(t, 0.1, 1.6, true), 1.0)
	assert_eq(EraTerrainLook.zoom_at(0.5, 0.0, 1.6, false), 1.0, "eras without the zoom")

func test_layer_takes_the_tier_of_the_region() -> void:
	var look: EraTerrainLook = _look("quivermoor", 5)
	assert_eq(look.tier, 5)
	assert_eq(look.canopy_root.get_parent(), look.get_parent(), "canopy sits in the world")
	assert_eq(look.canopy_root.get_index(), look.get_parent().get_child(2).get_index() + 1, "right over the people")
	assert_eq(look.canopy_root.size, Vector2(96, 96), "clipped to the map")
	assert_has(look.banner_cells(), Vector2i(3, 1), "a pennant on the ridge over the door")
	assert_gte(look.zoom_t, 0.0, "a town zooms in")
	assert_almost_eq(look.camera.zoom.x, 0.9, 0.001)
	look._process(5.0)
	assert_eq(look.camera.zoom, Vector2.ONE)

func test_a_route_and_an_older_era_do_not_zoom() -> void:
	assert_lt(_look("quivermoor", 5, "route").zoom_t, 0.0)
	var old: EraTerrainLook = _look("halcyra", 5)
	assert_eq(old.tier, 4)
	assert_lt(old.zoom_t, 0.0)
	assert_eq(old.camera.zoom, Vector2.ONE)

func test_story_act_stays_ink_even_in_the_newest_era() -> void:
	var look: EraTerrainLook = _look("veydal", 5)
	assert_eq(look.tier, 1)
	assert_eq(look.cfg, EraTerrainLook.era_cfg(1))
	assert_true(look.banner_cells().is_empty())

func test_reduced_motion_freezes_the_layer() -> void:
	GameState.reduce_motion = true
	var look: EraTerrainLook = _look("quivermoor", 5)
	assert_lt(look.zoom_t, 0.0)
	assert_eq(look.camera.zoom, Vector2.ONE)
	for i: int in 12:
		look._process(0.2)
		assert_eq(look.frame, 0)
	assert_eq(look._lean(Vector2(500, 500)), Vector2.ZERO)

func test_frames_run_without_reduced_motion() -> void:
	var look: EraTerrainLook = _look("quivermoor", 5)
	var seen: Dictionary = {}
	for i: int in 12:
		look._process(0.2)
		seen[look.frame] = true
	assert_gt(seen.size(), 2)

func test_pennants_fly_over_towers_only_in_era_five() -> void:
	var rows: Array[String] = ["......", "..|...", "..|...", "......"]
	for era: int in [4, 5]:
		EraManager.unlocked_era = EraManager.NEWEST
		EraManager.set_retro_filter(era)
		var look := EraTerrainLook.new()
		add_child_autofree(look)
		var ground := TileMapLayer.new()
		add_child_autofree(ground)
		var m: MapData = MapData.from_dict("look_tower", {"name": "T", "region": "quivermoor", "outdoor": true, "rows": rows})
		m.paint(ground)
		look.show_map(m, ground)
		assert_eq(look.banner_cells(), ([Vector2i(2, 1)] if era == 5 else []) as Array[Vector2i], "era %d" % era)

func test_switched_off_layer_draws_nothing() -> void:
	EraTerrainLook.enabled = false
	var look: EraTerrainLook = _look("quivermoor", 5)
	assert_true(look.cfg.is_empty())
	assert_lt(look.zoom_t, 0.0)
