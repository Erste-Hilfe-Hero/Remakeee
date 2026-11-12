extends GutTest
## Quillmarch, the post-game Era III region (data/region3.json, scripts/core/Region3.gd): opens
## after the Era II finale, its own look and atlas (data/region_looks.json, art/era3/tiles), its
## first Era III Spirlings and the elements Acid and Frost in the chart.

var _d: Dictionary = {}
var _unlocked: int
var _retro: int

func before_all() -> void:
	Database.load_all()
	_d = Region3.data()

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	TilesetFactory.clear_cache()

func _set_era(e: int) -> void:
	EraManager.unlocked_era = e
	EraManager.set_retro_filter(0)

func test_opens_after_the_era_two_finale_in_era_three() -> void:
	assert_eq(str(_d.id), "quillmarch")
	assert_eq(int(_d.era), 3)
	assert_eq(EraManager.REGION_ERA["quillmarch"], EraManager.Era.ETCHED)
	assert_eq(str(_d.unlock_flag), str(EraManager.unlock_flags()["3"]), "the flag that opens Era III opens Quillmarch")
	var f: Dictionary = {"story_complete": true}
	assert_false(Region3.is_open(f))
	f["vellmarch_done"] = true
	EraManager.mark_finales(f)
	assert_true(Region3.is_open(f), "Vellmarch's last chapter opens Quillmarch")
	f[str(_d.finale_flag)] = true
	EraManager.mark_finales(f)
	assert_true(bool(f.get(str(EraManager.unlock_flags()["4"]), false)), "Quillmarch's finale opens Era IV")

func test_towns_and_routes_link_up() -> void:
	var towns: Dictionary = {}
	var cells: Dictionary = {}
	for t: Dictionary in _d.towns:
		towns[t.id] = true
		assert_false(cells.has(str(t.pos)), "%s cell" % t.id)
		cells[str(t.pos)] = true
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
	assert_eq(reached.size(), towns.size(), "every town reachable from the landing")
	assert_eq(str(_d.arrival.from), str(Region2.data().story[-1].at), "the boat leaves from Vellmarch's last town")

func test_slots_use_own_spirlings_and_rings_climb_past_vellmarch() -> void:
	var vell_top: int = 0
	for r: Dictionary in Region2.data().routes:
		vell_top = maxi(vell_top, int(r.ring[1]))
	var last: int = 0
	var own: int = 0
	for r: Dictionary in _d.routes:
		assert_gte(int(r.ring[0]), last, "%s ring" % r.id)
		assert_gte(int(r.ring[0]), vell_top, "after Vellmarch")
		last = int(r.ring[0])
		var total: int = 0
		for s: Dictionary in r.slots:
			total += int(s.weight)
			var sp: String = Region3.slot_species(s)
			assert_true(Database.spirlings.has(sp), str(s.slot))
			if s.get("species") != null:
				own += 1
				assert_eq(Database.species(sp).region, "quillmarch", "%s is a Quillmarch kind" % sp)
		assert_eq(total, 100, r.id)
	assert_gte(own, 12, "most slots already hold Quillmarch's own Spirlings")
	assert_eq(Region3.open_slots().size(), 0, "the Acid and Frost kinds fill every slot")

func test_four_wardens_each_hold_a_rift() -> void:
	var ws: Array = Region3.wardens()
	assert_eq(ws.size(), 4)
	var ring: int = 0
	for w: Dictionary in ws:
		var r: Dictionary = Region3.rift(str(w.rift))
		assert_false(r.is_empty(), str(w.id))
		assert_eq(str(r.warden), str(w.id))
		assert_gt(int(w.ring), ring)
		ring = int(w.ring)
		for t: Dictionary in w.team:
			assert_true(Database.spirlings.has(Region3.slot_species(t)), str(w.id))
			assert_lte(int(t.level), int(w.ring))

func test_next_warden_follows_sealed_rifts() -> void:
	var f: Dictionary = {}
	assert_true(Region3.next_warden(f).is_empty(), "shut before the Era II finale")
	f[str(_d.unlock_flag)] = true
	assert_eq(str(Region3.next_warden(f).id), "mavet")
	f["v3_rift_bath_sealed"] = true
	assert_eq(str(Region3.next_warden(f).id), "quenby")
	for r: Dictionary in _d.rifts:
		f[r.flag] = true
	assert_true(Region3.next_warden(f).is_empty())

func test_story_is_a_chain_full_of_betrayal() -> void:
	var f: Dictionary = {str(_d.unlock_flag): true}
	var seen: int = 0
	while not Region3.current_chapter(f).is_empty():
		var c: Dictionary = Region3.current_chapter(f)
		assert_false(str(c.betrayal.text).is_empty(), str(c.id))
		f[c.sets] = true
		seen += 1
		assert_lt(seen, 20)
	assert_eq(seen, (_d.story as Array).size())
	assert_true(f.has(str(_d.finale_flag)))

func test_acid_and_frost_are_era_three_elements_with_two_strengths_and_weaknesses() -> void:
	var types: Dictionary = Elements.chart().get("types", {})
	assert_eq(_d.elements, ["ACID", "FROST"])
	for e: String in _d.elements:
		assert_eq(int(types[e].era), 3, e)
		var strong: int = 0
		var weak: int = 0
		for o: String in types:
			var ad: bool = o in (types[e].strong as Array)
			var da: bool = e in (types[o].strong as Array)
			strong += 1 if ad and not da else 0
			weak += 1 if da and not ad else 0
		assert_gte(strong, 2, e)
		assert_gte(weak, 2, e)

func test_first_era_three_spirlings() -> void:
	var eras: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EraManager.ERAS_PATH))
	var drawn: Array = (eras.era3.starting_set as Array) + (eras.era3.first_batch as Array)
	var kinds: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == "quillmarch":
			kinds.append(sd)
	assert_eq(kinds.size(), 70, "70 own kinds: the hand-built first set plus the second batch (gen_era3.py --lines)")
	for sd: SpirlingData in kinds:
		assert_eq(sd.era, 3, sd.species_name)
		assert_eq(EraManager.sprite_path(sd.species_name), "res://art/era3/spirlings/%s_front.png" % sd.species_name.to_lower())
	for sp: Dictionary in drawn:
		var sd: SpirlingData = Database.species(str(sp.id).capitalize())
		assert_not_null(sd, str(sp.id))
		if sd == null:
			continue
		assert_eq(sd.era, 3)
		assert_eq(sd.region, "quillmarch")
		assert_eq(EraManager.sprite_path(sd.species_name), "res://art/era3/spirlings/%s_front.png" % sp.id)
		assert_eq(EraManager.battle_sprite_size(sd.species_name), 64)
		assert_eq(sd.line_id, str(sp.line), "stages of a line share it")
	assert_true(SpirlingData.REGIONS.has("quillmarch"))
	assert_false(SpirlogBook.region_open("quillmarch", {}), "hidden in the Spirlog before the Era II finale")
	assert_true(SpirlogBook.region_open("quillmarch", {str(_d.unlock_flag): true}))

func test_region_look_is_a_rich_era_three_palette() -> void:
	var look: Dictionary = RegionLook.look("quillmarch")
	assert_eq(int(look.era), 3)
	var pal: Array[Color] = RegionLook.palette("quillmarch")
	assert_eq(pal.size(), 16, "16 colours instead of four inks")
	var seen: Dictionary = {}
	for c: Color in pal:
		seen[c.to_html(false)] = true
	assert_eq(seen.size(), 16, "no colour twice")
	assert_eq(EraManager.inks_for("quillmarch"), EraManager.INK_PALETTE, "no four-ink filter look")
	assert_false(RegionLook.biome("quillmarch").is_empty())
	assert_ne(Loc.load_table("de").get("strings", {}).get(RegionLook.arrive_line("quillmarch"), ""), "", "German arrive line")

func test_own_atlas_in_era_three() -> void:
	_set_era(EraManager.Era.ETCHED)
	var own: String = TilesetFactory.atlas_path("quillmarch")
	assert_eq(own, "res://art/era3/tiles/overworld_quillmarch.png", "its own Era III atlas beats the Era II shared one")
	assert_eq(TilesetFactory.atlas_path("veydal"), "res://art/era2/tiles/overworld.png")
	var tex: Texture2D = load(own)
	assert_not_null(tex)
	if tex != null:
		assert_eq(tex.get_width(), TilesetFactory.TILE * TilesetFactory.Kind.size())
		assert_eq(tex.get_height(), TilesetFactory.TILE * TilesetFactory.VARIANT_ROWS)
	_set_era(EraManager.Era.WASH)
	assert_eq(TilesetFactory.atlas_path("quillmarch"), "res://art/era2/tiles/overworld.png", "not before Era III")

func test_texts_have_german() -> void:
	var texts: Array[String] = [str(_d.name), str(_d.arrival.text)]
	for k: String in ["towns", "routes", "rifts", "wardens"]:
		for e: Dictionary in _d[k]:
			texts.append(str(e.name))
	for t: Dictionary in _d.towns:
		texts.append(str(t.text))
	for w: Dictionary in _d.wardens:
		texts.append_array([str(w.intro), str(w.defeat)])
	for c: Dictionary in _d.story:
		texts.append_array([str(c.title), str(c.text), str(c.betrayal.text)])
	var de: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/region3.json"))
	for s: String in texts:
		assert_true(de.strings.has(s) or s in de.keep, s)
