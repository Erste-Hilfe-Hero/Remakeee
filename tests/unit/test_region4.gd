extends GutTest
## Halcyra, the post-game Era IV region (data/region4.json, scripts/core/Region4.gd): unlock
## after the Era III finale, the Era IV chain, its look, atlas and battle stage colours.

var _d: Dictionary = {}
var _unlocked: int
var _retro: int

func before_all() -> void:
	Database.load_all()
	_d = Region4.data()

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	EraManager.set_region("")

func _eras() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(EraManager.ERAS_PATH))

func test_opens_after_the_era_three_finale() -> void:
	assert_eq(int(_d.era), EraManager.Era.PANORAMA)
	assert_eq(str(_d.unlock_flag), str(EraManager.unlock_flags()["4"]), "same flag that opens Era IV")
	assert_false(Region4.is_open({}))
	assert_false(Region4.is_open({"story_complete": true, "era2_finale_done": true}))
	assert_true(Region4.is_open({"era3_finale_done": true}))

func test_region_era_is_data_driven() -> void:
	assert_eq(EraManager.region_era(str(_d.id)), EraManager.Era.PANORAMA)
	assert_eq(EraManager.region_era("vellmarch"), EraManager.Era.WASH)
	assert_eq(EraManager.region_era("veydal"), EraManager.Era.INK)
	assert_eq(EraManager.region_era("nowhere"), EraManager.Era.INK)

func test_finale_sets_the_era_five_flag() -> void:
	assert_eq(str(_eras().finale_flags.era4_finale_done), str(_d.finale_flag))
	var flags: Dictionary = {}
	EraManager.mark_finales(flags)
	assert_false(flags.has("era4_finale_done"))
	flags[str(_d.finale_flag)] = true
	assert_true(Region4.is_done(flags))
	EraManager.mark_finales(flags)
	assert_true(flags.get("era4_finale_done", false))

func test_era_four_waits_for_era_three() -> void:
	EraManager.unlocked_era = EraManager.Era.WASH
	EraManager.set_retro_filter(0)
	var only_era3_flag: Callable = func(f: String) -> bool: return f == "era3_finale_done"
	EraManager.unlock_from_flags(only_era3_flag)
	assert_eq(EraManager.unlocked_era, EraManager.Era.WASH, "Era IV stays shut while Era III is locked")
	var chain: Array = ["story_complete", "era2_finale_done", "era3_finale_done"]
	EraManager.unlock_from_flags(func(f: String) -> bool: return chain.has(f))
	assert_eq(EraManager.unlocked_era, EraManager.Era.PANORAMA)

func test_towns_and_routes_link_up() -> void:
	var towns: Dictionary = {}
	var cells: Dictionary = {}
	for t: Dictionary in _d.towns:
		towns[t.id] = true
		assert_false(cells.has(str(t.pos)), "%s cell" % t.id)
		cells[str(t.pos)] = true
	for r: Dictionary in _d.routes:
		assert_false(cells.has(str(r.pos)), "%s cell" % r.id)
		cells[str(r.pos)] = true
	assert_gte(towns.size(), 5)
	assert_gte((_d.routes as Array).size(), 6)
	var reached: Dictionary = {str(_d.arrival.to): true}
	for i: int in 10:
		for r: Dictionary in _d.routes:
			var a: String = str(r.links[0])
			var b: String = str(r.links[1])
			assert_true(towns.has(a) and towns.has(b), "%s links towns" % r.id)
			if reached.has(a) or reached.has(b):
				reached[a] = true
				reached[b] = true
	assert_eq(reached.size(), towns.size(), "every town reachable from the top station")

func test_slots_feed_the_route_tables() -> void:
	var last: int = 0
	for r: Dictionary in _d.routes:
		assert_gte(int(r.ring[0]), last, "%s ring climbs" % r.id)
		last = int(r.ring[0])
		var spawns: Array = EncounterTable.table(str(r.id)).get("spawns", [])
		assert_eq(spawns.size(), (r.slots as Array).size(), "%s table has one spawn per slot" % r.id)
		for i: int in mini(spawns.size(), (r.slots as Array).size()):
			var s: Dictionary = r.slots[i]
			var sp: Dictionary = spawns[i]
			var sd: SpirlingData = Database.species(Region4.slot_species(s))
			assert_not_null(sd, str(s.slot))
			assert_eq(str(sp.species), Region4.slot_species(s), str(s.slot))
			assert_eq(int(sp.weight), int(s.weight), str(s.slot))
			assert_eq(str(sp.ground), str(s.ground), str(s.slot))
			assert_eq([int(sp.min), int(sp.max)], [int(r.ring[0]), int(r.ring[1])], str(s.slot))
			if sd != null:
				var band: Vector2i = SpirlingData.WEIGHT_BANDS[sd.rarity]
				assert_between(int(s.weight), band.x, band.y, "%s weight in the %s band" % [s.slot, sd.rarity])
	assert_eq(Region4.open_slots().size(), 0, "Halcyra's own kinds fill every slot and Warden ace")
	assert_false(Region4.route("mirror_flats").is_empty())

func test_four_wardens_each_hold_a_rift() -> void:
	var ws: Array = Region4.wardens()
	assert_eq(ws.size(), 4)
	var ring: int = 0
	for w: Dictionary in ws:
		var r: Dictionary = Region4.rift(str(w.rift))
		assert_false(r.is_empty(), str(w.id))
		assert_eq(str(r.warden), str(w.id))
		assert_gt(int(w.ring), ring)
		ring = int(w.ring)
		for t: Dictionary in w.team:
			assert_true(Database.spirlings.has(Region4.slot_species(t)), str(w.id))
			assert_lte(int(t.level), int(w.ring))

func test_next_warden_follows_sealed_rifts() -> void:
	var f: Dictionary = {}
	assert_true(Region4.next_warden(f).is_empty(), "shut before the Era III finale")
	f["era3_finale_done"] = true
	assert_eq(str(Region4.next_warden(f).id), "isaura")
	f["rift_v4_orrery_sealed"] = true
	assert_eq(str(Region4.next_warden(f).id), "halloran")
	for r: Dictionary in _d.rifts:
		f[r.flag] = true
	assert_true(Region4.next_warden(f).is_empty())

func test_story_is_a_chain_full_of_betrayal() -> void:
	var f: Dictionary = {str(_d.unlock_flag): true}
	var seen: int = 0
	while not Region4.current_chapter(f).is_empty():
		var c: Dictionary = Region4.current_chapter(f)
		assert_false(str(c.betrayal.text).is_empty(), str(c.id))
		f[c.sets] = true
		seen += 1
		assert_lt(seen, 20)
	assert_eq(seen, (_d.story as Array).size())
	assert_true(Region4.is_done(f))

func test_landmarks_span_several_screens() -> void:
	var places: Dictionary = {}
	for t: Dictionary in _d.towns:
		places[t.id] = true
	for r: Dictionary in _d.routes:
		places[r.id] = true
	assert_gte((_d.landmarks as Array).size(), 3)
	for l: Dictionary in _d.landmarks:
		assert_true(places.has(str(l.at)), str(l.id))
		assert_gt(int(l.screens[0]) * int(l.screens[1]), 1, "%s spans screens" % l.id)
	assert_eq(Region4.landmarks_at("starwell").size(), 1)

func test_seventy_own_era_four_spirlings() -> void:
	var kinds: Array[SpirlingData] = []
	var own: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == "halcyra":
			kinds.append(sd)
			for e: int in sd.elements:
				own[Elements.E.find_key(e)] = true
	assert_eq(kinds.size(), 70, "70 own kinds (tools/art/lines/halcyra.py, gen_era4.py --lines)")
	for sd: SpirlingData in kinds:
		assert_eq(sd.era, 4, sd.species_name)
		assert_eq(EraManager.sprite_path(sd.species_name), "res://art/era4/spirlings/%s_front.png" % sd.species_name.to_lower())
		assert_eq(EraManager.battle_sprite_size(sd.species_name), 96)
	for e: String in _d.elements:
		assert_true(own.has(e), "%s is carried by Halcyra's kinds" % e)
	for r: Dictionary in _d.routes:
		for s: Dictionary in r.slots:
			assert_eq(Database.species(Region4.slot_species(s)).region, "halcyra", str(s.slot))
	for w: Dictionary in _d.wardens:
		assert_eq(Database.species(Region4.slot_species(w.team[-1])).region, "halcyra", "%s ace" % w.id)
	assert_false(SpirlogBook.region_open("halcyra", {}), "hidden in the Spirlog before the Era III finale")
	assert_true(SpirlogBook.region_open("halcyra", {str(_d.unlock_flag): true}))

func test_region_elements_are_in_the_chart() -> void:
	var types: Dictionary = Elements.chart().get("types", {})
	assert_true(_d.elements is Array, "own types come with Halcyra's Spirlings")
	for e: String in _d.elements:
		assert_true(types.has(e), e)
		assert_eq(int(types[e].era), 4)

func test_look_has_retro_inks_and_tile_swatches() -> void:
	var look: Dictionary = RegionLook.look(str(_d.id))
	assert_eq(int(look.era), 4)
	var inks: Array[Color] = RegionLook.palette(str(_d.id))
	assert_eq(inks.size(), 4)
	for i: int in inks.size():
		var l: float = inks[i].get_luminance()
		assert_true(l >= i * 0.25 and l < (i + 1) * 0.25 + (0.01 if i == 3 else 0.0), "ink %d in its band" % i)
	assert_eq(EraManager.inks_for(str(_d.id))[0], inks[0], "Era I Retro filter uses Halcyra's own inks")
	for k: Variant in TilesetFactory.Kind.keys():
		var sw: String = str(look.tiles.get(str(k), ""))
		assert_true(look.swatches.has(sw), "%s has a swatch" % k)
		assert_eq((look.swatches[sw] as Array).size(), 4)
	assert_false(RegionLook.arrive_line(str(_d.id)).is_empty())

func test_era_four_atlas_wins_over_the_older_shared_one() -> void:
	EraManager.unlocked_era = EraManager.Era.PANORAMA
	EraManager.set_retro_filter(0)
	assert_eq(TilesetFactory.atlas_path("halcyra"), "res://art/era4/tiles/overworld_halcyra.png")
	assert_eq(TilesetFactory.atlas_path("ashmere"), "res://art/era2/tiles/overworld.png", "older act atlas loses")
	var tex: Texture2D = load(TilesetFactory.atlas_path("halcyra"))
	var base: Texture2D = load(TilesetFactory.ATLAS_PATH)
	assert_eq(tex.get_size(), base.get_size(), "same layout as the shared atlas")
	EraManager.set_retro_filter(EraManager.Era.INK)
	assert_eq(TilesetFactory.atlas_path("halcyra"), TilesetFactory.ATLAS_PATH, "Retro Era I keeps the ink atlas")

func test_stage_colours_follow_the_region() -> void:
	var base: Dictionary = EraManager.stage_config().colors
	var own: Dictionary = EraManager.stage_colors("halcyra")
	assert_eq(own.size(), base.size(), "every stage colour set")
	assert_ne(str(own.sky_low), str(base.sky_low))
	assert_eq(str(EraManager.stage_colors("veydal").sky_low), str(base.sky_low))

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
	var de: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/region4.json"))
	for s: String in texts:
		assert_true(de.strings.has(s) or s in de.keep, s)
