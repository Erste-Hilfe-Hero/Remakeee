extends GutTest
## Quivermoor, the post-game Era V region (data/region5.json, scripts/core/Region5.gd): unlock
## after the Halcyra finale, the Era V chain, its look, atlas, stage colours and battle camera.

var _d: Dictionary = {}
var _unlocked: int
var _retro: int

func before_all() -> void:
	Database.load_all()
	_d = Region5.data()

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	EraManager.set_region("")

func _eras() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(EraManager.ERAS_PATH))

func test_opens_after_the_era_four_finale() -> void:
	assert_eq(int(_d.era), EraManager.Era.LIVING)
	assert_eq(str(_d.unlock_flag), str(EraManager.unlock_flags()["5"]), "same flag that opens Era V")
	assert_false(Region5.is_open({}))
	assert_false(Region5.is_open({"era3_finale_done": true, "halcyra_done": true}), "mark_finales turns halcyra_done into the flag")
	assert_true(Region5.is_open({"era4_finale_done": true}))

func test_region_era_is_data_driven() -> void:
	assert_eq(EraManager.region_era(str(_d.id)), EraManager.Era.LIVING)
	assert_eq(EraManager.region_era("halcyra"), EraManager.Era.PANORAMA)
	assert_eq(EraManager.region_era("veydal"), EraManager.Era.INK)

func test_halcyra_finale_opens_quivermoor_and_its_own_finale_is_era_five() -> void:
	var flags: Dictionary = {"halcyra_done": true}
	EraManager.mark_finales(flags)
	assert_true(Region5.is_open(flags))
	assert_eq(str(_eras().finale_flags.era5_finale_done), str(_d.finale_flag))
	assert_false(flags.has("era5_finale_done"))
	flags[str(_d.finale_flag)] = true
	assert_true(Region5.is_done(flags))
	EraManager.mark_finales(flags)
	assert_true(flags.get("era5_finale_done", false))

func test_era_five_waits_for_era_four() -> void:
	EraManager.unlocked_era = EraManager.Era.WASH
	EraManager.set_retro_filter(0)
	EraManager.unlock_from_flags(func(f: String) -> bool: return f == "era4_finale_done")
	assert_eq(EraManager.unlocked_era, EraManager.Era.WASH, "Era V stays shut while Era IV is locked")
	var chain: Array = ["story_complete", "era2_finale_done", "era3_finale_done", "era4_finale_done"]
	EraManager.unlock_from_flags(func(f: String) -> bool: return chain.has(f))
	assert_eq(EraManager.unlocked_era, EraManager.Era.LIVING)

func test_towns_routes_and_rifts_link_up() -> void:
	var towns: Dictionary = {}
	var cells: Dictionary = {}
	for k: String in ["towns", "routes", "rifts"]:
		for e: Dictionary in _d[k]:
			assert_false(cells.has(str(e.pos)), "%s cell" % e.id)
			cells[str(e.pos)] = true
	for t: Dictionary in _d.towns:
		towns[t.id] = true
	assert_eq(towns.size(), 5)
	assert_eq((_d.routes as Array).size(), 6)
	for r: Dictionary in _d.rifts:
		assert_true(towns.has(str(r.near)), "%s near a town" % r.id)
	var reached: Dictionary = {str(_d.arrival.to): true}
	for i: int in 10:
		for r: Dictionary in _d.routes:
			var a: String = str(r.links[0])
			var b: String = str(r.links[1])
			assert_true(towns.has(a) and towns.has(b), "%s links towns" % r.id)
			if reached.has(a) or reached.has(b):
				reached[a] = true
				reached[b] = true
	assert_eq(reached.size(), towns.size(), "every town reachable from the rope")

func _cap() -> int:
	return int(_eras().ring_caps["5"])

func test_slots_fit_the_rarity_bands_and_rings_climb_past_halcyra() -> void:
	var last: int = 0
	for r: Dictionary in Region4.data().routes:
		last = maxi(last, int(r.ring[0]))
	assert_eq(_cap(), Spirling.ERA_MAX_LEVEL, "Era V opens the top ring")
	for r: Dictionary in _d.routes:
		assert_lte(int(r.ring[1]), _cap(), "%s ring" % r.id)
		assert_between(int(r.ring[0]) - last, 0, WorldValidator.MAX_RING_JUMP, "%s climbs" % r.id)
		last = int(r.ring[0])
		var total: int = 0
		for s: Dictionary in r.slots:
			total += int(s.weight)
			var sd: SpirlingData = Database.species(Region5.slot_species(s))
			assert_not_null(sd, str(s.slot))
			if sd != null:
				var band: Vector2i = SpirlingData.WEIGHT_BANDS[sd.rarity]
				assert_between(int(s.weight), band.x, band.y, "%s in the %s band" % [s.slot, sd.rarity])
		assert_eq(total, 100, r.id)
	assert_gt(Region5.open_slots().size(), 0, "slots wait for Quivermoor's own Spirlings")
	assert_false(Region5.route("hymnmarsh").is_empty())

func test_four_wardens_each_hold_a_rift() -> void:
	var ws: Array = Region5.wardens()
	assert_eq(ws.size(), 4)
	var ring: int = 0
	for w: Dictionary in ws:
		var r: Dictionary = Region5.rift(str(w.rift))
		assert_false(r.is_empty(), str(w.id))
		assert_eq(str(r.warden), str(w.id))
		assert_eq(str(r.flag), "rift_v5_%s_sealed" % str(r.id).trim_suffix("_rift"), "GameState.seal_rift key")
		assert_gt(int(w.ring), ring)
		assert_lte(int(w.ring), _cap())
		ring = int(w.ring)
		var elements: Dictionary = {}
		for t: Dictionary in w.team:
			var sd: SpirlingData = Database.species(Region5.slot_species(t))
			assert_not_null(sd, str(w.id))
			if sd != null:
				for e: Variant in sd.elements:
					elements[e] = true
			assert_lte(int(t.level), int(w.ring))
		assert_lte(elements.size(), 3, "%s keeps to three elements" % w.id)

func test_next_warden_follows_sealed_rifts() -> void:
	var f: Dictionary = {}
	assert_true(Region5.next_warden(f).is_empty(), "shut before the Era IV finale")
	f["era4_finale_done"] = true
	assert_eq(str(Region5.next_warden(f).id), "maudrey")
	f["rift_v5_wick_sealed"] = true
	assert_eq(str(Region5.next_warden(f).id), "ossian")
	for r: Dictionary in _d.rifts:
		f[r.flag] = true
	assert_true(Region5.next_warden(f).is_empty())

func test_story_is_a_chain_full_of_betrayal() -> void:
	var f: Dictionary = {str(_d.unlock_flag): true}
	var seen: int = 0
	var traitors: Dictionary = {}
	while not Region5.current_chapter(f).is_empty():
		var c: Dictionary = Region5.current_chapter(f)
		assert_false(str(c.betrayal.text).is_empty(), str(c.id))
		traitors[str(c.betrayal.by)] = int(traitors.get(str(c.betrayal.by), 0)) + 1
		if c.has("rift") and str(c.sets) != str(_d.finale_flag):
			assert_eq(str(c.sets), str(Region5.rift(str(c.rift)).flag), "%s ends with its Rift" % c.id)
		f[c.sets] = true
		seen += 1
		assert_lt(seen, 20)
	assert_eq(seen, (_d.story as Array).size())
	assert_true(Region5.is_done(f))
	assert_eq(GameState.ring_ceiling_for({"story_complete": true, "era2_finale_done": true, "era3_finale_done": true, "era4_finale_done": true}), _cap(), "the moor's rings can be reached")
	assert_gt(traitors.values().max(), 1, "someone betrays you twice")

func test_landmarks_span_several_screens() -> void:
	var places: Dictionary = {}
	for k: String in ["towns", "routes"]:
		for e: Dictionary in _d[k]:
			places[e.id] = true
	assert_gte((_d.landmarks as Array).size(), 3)
	for l: Dictionary in _d.landmarks:
		assert_true(places.has(str(l.at)), str(l.id))
		assert_gt(int(l.screens[0]) * int(l.screens[1]), 1, "%s spans screens" % l.id)
	assert_eq(Region5.landmarks_at("tallowmere").size(), 1)

func test_region_elements_are_in_the_chart() -> void:
	var types: Dictionary = Elements.chart().get("types", {})
	assert_true(_d.elements is Array, "own types come with Quivermoor's Spirlings")
	for e: String in _d.elements:
		assert_true(types.has(e), e)
		assert_eq(int(types[e].era), 5)

func test_look_has_retro_inks_and_tile_swatches() -> void:
	var look: Dictionary = RegionLook.look(str(_d.id))
	assert_eq(int(look.era), 5)
	var inks: Array[Color] = RegionLook.palette(str(_d.id))
	assert_eq(inks.size(), 4)
	for i: int in inks.size():
		var l: float = inks[i].get_luminance()
		assert_true(l >= i * 0.25 and l < (i + 1) * 0.25 + (0.01 if i == 3 else 0.0), "ink %d in its band" % i)
	assert_eq(EraManager.inks_for(str(_d.id))[0], inks[0], "Era I Retro filter uses Quivermoor's own inks")
	for k: Variant in TilesetFactory.Kind.keys():
		var sw: String = str(look.tiles.get(str(k), ""))
		assert_true(look.swatches.has(sw), "%s has a swatch" % k)
		assert_eq((look.swatches[sw] as Array).size(), 4)
	assert_false(RegionLook.arrive_line(str(_d.id)).is_empty())

func test_era_five_atlas_is_its_own() -> void:
	EraManager.unlocked_era = EraManager.Era.LIVING
	EraManager.set_retro_filter(0)
	assert_eq(TilesetFactory.atlas_path("quivermoor"), "res://art/era5/tiles/overworld_quivermoor.png")
	var tex: Texture2D = load(TilesetFactory.atlas_path("quivermoor"))
	var base: Texture2D = load(TilesetFactory.ATLAS_PATH)
	assert_eq(tex.get_size(), base.get_size(), "same layout as the shared atlas")
	EraManager.set_retro_filter(EraManager.Era.INK)
	assert_eq(TilesetFactory.atlas_path("quivermoor"), TilesetFactory.ATLAS_PATH, "Retro Era I keeps the ink atlas")

func test_stage_colours_follow_the_region() -> void:
	var base: Dictionary = EraManager.stage_config().colors
	var own: Dictionary = EraManager.stage_colors("quivermoor")
	assert_eq(own.size(), base.size(), "every stage colour set")
	assert_ne(str(own.sky_top), str(base.sky_top))
	assert_ne(str(own.sky_top), str(EraManager.stage_colors("halcyra").sky_top))

func test_battles_here_move_and_the_camera_sways_more() -> void:
	assert_true(BattleAnim.enabled_for(EraManager.region_era(str(_d.id))), "Era V: animated sprites and the camera")
	assert_false(BattleAnim.enabled_for(EraManager.region_era("halcyra")))
	var base: Dictionary = BattleAnim.config().get("camera", {})
	var own: Dictionary = BattleCamera.cam_cfg(str(_d.id))
	assert_gt(float(own.zoom), float(base.zoom))
	assert_gt(float(own.pan_share), float(base.pan_share))
	assert_eq(float(own.in_time), float(base.in_time), "unset values keep the era default")
	assert_eq(float(BattleCamera.cam_cfg("veydal").zoom), float(base.zoom))
	EraManager.set_region(str(_d.id))
	assert_eq(float(BattleCamera.cam_cfg().zoom), float(own.zoom), "the region on screen sets the sway")
	var f: Dictionary = BattleCamera.focus(Vector2(270, 200), Rect2(10, 120, 60, 60), Rect2(200, 20, 60, 60))
	assert_eq(f.scale, Vector2(float(own.zoom), float(own.zoom)))

func test_texts_have_german() -> void:
	var texts: Array[String] = [str(_d.name), str(_d.arrival.text)]
	for k: String in ["towns", "routes", "rifts", "wardens", "landmarks"]:
		for e: Dictionary in _d[k]:
			texts.append(str(e.name))
	for t: Dictionary in _d.towns:
		texts.append(str(t.text))
	for l: Dictionary in _d.landmarks:
		texts.append(str(l.text))
	for w: Dictionary in _d.wardens:
		texts.append_array([str(w.intro), str(w.defeat)])
	for c: Dictionary in _d.story:
		texts.append_array([str(c.title), str(c.text), str(c.betrayal.text)])
	var de: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/region5.json"))
	for s: String in texts:
		assert_true(de.strings.has(s) or s in de.keep, s)
