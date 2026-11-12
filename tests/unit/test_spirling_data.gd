extends GutTest
## Plan area 1 (items 1, 2, 6, 130-133, 336): every kind's data fits its rarity and role.

func before_all() -> void:
	Database.load_all()

func _raw() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/spirlings.json"))

func test_every_kind_has_the_new_fields() -> void:
	for s: Dictionary in _raw():
		for f: String in ["rarity", "region", "role", "origin", "line_id"]:
			assert_true(s.has(f), "%s has %s" % [s.name, f])
	for sd: SpirlingData in Database.spirlings.values():
		assert_true(sd.rarity in SpirlingData.RARITIES, sd.species_name)
		assert_true(sd.region in SpirlingData.REGIONS, sd.species_name)
		assert_true(sd.role in SpirlingData.ROLES, sd.species_name)
		assert_false(sd.origin.strip_edges().is_empty(), "%s has an origin" % sd.species_name)
		assert_false(sd.line_id.is_empty(), sd.species_name)

func test_stat_total_fits_the_rarity() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var total: int = sd.base_hp + sd.base_atk + sd.base_def + sd.base_foc + sd.base_spd
		var band: Vector2i = SpirlingData.STAT_TOTAL_BANDS[sd.rarity]
		assert_between(total, band.x, band.y, "%s (%s) stat total" % [sd.species_name, sd.rarity])

func test_bond_rate_fits_the_rarity() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var band: Vector2 = SpirlingData.BOND_RATE_BANDS[sd.rarity]
		assert_between(sd.bond_rate, band.x - 0.0001, band.y + 0.0001, "%s bond rate" % sd.species_name)

func test_elements_traits_and_learnsets_are_valid() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		assert_between(sd.elements.size(), 1, 2, sd.species_name)
		for e: int in sd.elements:
			assert_true(e in Elements.E.values(), "%s element" % sd.species_name)
		assert_true(BattleRules.TRAITS.has(sd.trait_id), "%s trait %s exists" % [sd.species_name, sd.trait_id])
		assert_false(sd.learnset_moves.is_empty(), "%s learns something" % sd.species_name)
	for s: Dictionary in _raw():
		for lvl: String in s.learnset:
			var list: Variant = s.learnset[lvl]
			for mv: Variant in (list if list is Array else [list]):
				assert_not_null(Database.move(str(mv)), "%s learns %s from moves.json" % [s.name, mv])

func test_encounter_weights_follow_rarity_and_ancients_never_spawn() -> void:
	assert_eq(WorldValidator.check_rarity_weights().size(), 0, "\n".join(WorldValidator.check_rarity_weights()))
	for id: String in EncounterTable.table_ids():
		for sp: String in EncounterTable.species_on(id):
			assert_ne(Database.species(sp).rarity, "ancient", "%s spawns at random in %s" % [sp, id])

func test_validator_catches_bad_new_fields() -> void:
	var dir: String = "user://validator_test_area1"
	DirAccess.make_dir_recursive_absolute(dir)
	var moves_path: String = dir + "/moves.json"
	var spirlings_path: String = dir + "/spirlings.json"
	var enc_path: String = dir + "/encounters.json"
	_write(moves_path, '[{"name":"Test Strike","element":"EMBER","kind":"PHYSICAL","power":40,"accuracy":1.0,"energy":2}]')
	_write(spirlings_path, '[{"dex_id":1,"name":"A","elements":["EMBER"],"rarity":"legendary","region":"moon","role":"x","origin":" ","bond_rate":0.5,"trait":"nope","base":{},"learnset":{"1":["Test Strike"]},"unfold":[{"to":"Z","rule":"luck","value":1}]},'
		+ '{"dex_id":2,"name":"B","elements":["EMBER"],"rarity":"shy","region":"veydal","role":"weaver","origin":"o","line_id":"b","bond_rate":0.5,"trait":"steady","base":{},"learnset":{"1":["Test Strike"]}},'
		+ '{"dex_id":3,"name":"C","elements":["EMBER"],"rarity":"ancient","region":"veydal","role":"weaver","origin":"o","line_id":"c","bond_rate":0.04,"trait":"steady","base":{},"learnset":{"1":["Test Strike"]}}]')
	_write(enc_path, '{"t":{"rate":0.1,"spawns":[{"species":"C","min":1,"max":2,"weight":5}]}}')
	var joined: String = "\n".join(DataValidator.validate(spirlings_path, moves_path, enc_path))
	assert_string_contains(joined, "unknown rarity 'legendary'")
	assert_string_contains(joined, "unknown region 'moon'")
	assert_string_contains(joined, "unknown role 'x'")
	assert_string_contains(joined, "'A': empty origin")
	assert_string_contains(joined, "needs a trait from BattleRules.TRAITS")
	assert_string_contains(joined, "unfolds into unknown 'Z'")
	assert_string_contains(joined, "unknown unfold rule 'luck'")
	assert_string_contains(joined, "'B': bond_rate 0.50 outside shy band")
	assert_string_contains(joined, "ancient 'C' must only be met in a fixed meeting")
	assert_string_contains(joined, "'A': can't be met anywhere")
	assert_string_contains(joined, "'B': can't be met anywhere")

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

# --- Other regions and regional imprints (plan area 1, items 61-63, 218-219) ---------------

func _lines_in(region: String) -> Dictionary:
	var lines: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == region:
			lines[sd.line_id] = true
	return lines

func test_corvane_ashmere_and_solenne_lines_wait_in_the_data() -> void:
	Database.load_all()
	# Includes the legendaries Zephyrel (Corvane), Monolurk and Vorlucent (Ashmere), Lumivane (Solenne).
	assert_eq(_lines_in("corvane").size(), 31, "9 lines before and 22 Act II lines (tools/art/lines/corvane.py)")
	var corvane: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		corvane += 1 if sd.region == "corvane" and sd.rarity != "ancient" else 0
	assert_eq(corvane, 70, "every story act has 70 own Spirlings (legendaries not counted)")
	assert_eq(_lines_in("ashmere").size(), 32, "8 lines before and 24 Act III lines (tools/art/lines/ashmere.py)")
	var ashmere: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		ashmere += 1 if sd.region == "ashmere" and sd.rarity != "ancient" else 0
	assert_eq(ashmere, 70, "every story act has 70 own Spirlings (legendaries not counted)")
	assert_eq(_lines_in("solenne").size(), 31, "7 lines before and 24 Act IV lines (tools/art/lines/solenne.py)")
	var solenne: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		solenne += 1 if sd.region == "solenne" and sd.rarity != "ancient" else 0
	assert_eq(solenne, 70, "every story act has 70 own Spirlings (legendaries not counted)")
	var veydal: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		veydal += 1 if sd.region == "veydal" and sd.rarity != "ancient" else 0
	assert_eq(veydal, 70, "every story act has 70 own Spirlings (legendaries not counted, 14 Act I lines in tools/art/lines/veydal.py)")

	for sd: SpirlingData in Database.spirlings.values():
		if sd.region != "veydal":
			assert_true(ResourceLoader.exists("res://art/era1/spirlings/%s_front.png" % sd.species_name.to_lower()), "%s has a placeholder sprite" % sd.species_name)
			assert_true(ResourceLoader.exists("res://art/era1/spirlings/%s_back.png" % sd.species_name.to_lower()))

func test_closed_regions_stay_out_of_the_spirlog_and_the_wild() -> void:
	var kinds: Array[SpirlingData] = SpirlogBook.visible_kinds({})
	for sd: SpirlingData in kinds:
		assert_eq(sd.region, "veydal")
	# A wild table holds kinds of its own region or of an earlier act, never of a later one.
	# WorldValidator.REGIONS is the world order (acts, then the post-game regions such as Vellmarch).
	var enc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout.json"))
	for area: String in enc:
		var region: String = str((layout.maps.get(area, {}) as Dictionary).get("region", "veydal"))
		for s: Dictionary in enc[area].spawns:
			var own: String = Database.species(str(s.species)).region
			assert_gte(WorldValidator.REGIONS.find(region), 0, "%s has a known region" % area)
			assert_lte(WorldValidator.REGIONS.find(own), WorldValidator.REGIONS.find(region), "%s in %s" % [s.species, area])
	assert_eq(SpirlogBook.visible_kinds({"region_open_corvane": true}).size(), kinds.size() + 71)
	assert_true(SpirlogBook.region_open("solenne", {"rift_shade_sealed": true}), "the sand road opens the chapter")
	assert_false(SpirlogBook.region_open("solenne", {}))

func test_act_tables_use_mostly_their_own_kinds() -> void:
	# Owner rule: an act's wild tables carry at most about 20 % kinds of earlier acts (by weight).
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_layout.json"))
	for id: String in EncounterTable.table_ids():
		var region: String = str((layout.maps.get(id, {}) as Dictionary).get("region", "veydal"))
		if region != "solenne" and region != "ashmere" and region != "corvane":
			continue
		var own: int = 0
		var all: int = 0
		for s: Dictionary in EncounterTable.table(id).spawns:
			all += int(s.weight)
			own += int(s.weight) if Database.species(str(s.species)).region == region else 0
		assert_gte(float(own) / all, 0.8, id)

func test_regional_imprint_changes_element_but_keeps_the_spirlog_number() -> void:
	var sd: SpirlingData = Database.species("Zephlet")
	assert_false(sd.variants.is_empty())
	var s := Spirling.new(sd, 10)
	var plain: Array[int] = s.elements().duplicate()
	assert_false(s.apply_imprint("solenne"), "no Solenne imprint for Zephlet")
	assert_true(s.apply_imprint("corvane"))
	assert_eq(s.variant, "corvane")
	assert_ne(s.elements(), plain)
	assert_true(Elements.E.TIDE in s.elements())
	assert_eq(s.variant_info().palette, "rain")
	var back: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(back.elements(), s.elements(), "the imprint survives a save")
	assert_eq(back.data.dex_id, sd.dex_id)

func test_every_variant_is_well_formed() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		for v: Dictionary in sd.variants:
			assert_true(str(v.region) in SpirlingData.REGIONS and str(v.region) != sd.region, sd.species_name)
			assert_false((v.elements as Array).is_empty(), sd.species_name)
			assert_true(BattleRules.TRAITS.has(str(v.trait)), sd.species_name)
			assert_false(str(v.lore).is_empty())
