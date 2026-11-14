extends GutTest
## Gleam form (feat/shiny): wild rate and chain math from data/gleam.json, deterministic rolls,
## palettes for every species, Gleam kept on unfurling, old saves and trades.

const FIXTURES: String = "res://tests/fixtures/saves/"
const SEED: int = 4242
const ROLLS: int = 200

var _saved: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_saved)

func test_rate_comes_from_data() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GleamRules.CONFIG_PATH))
	assert_eq(GleamRules.one_in(), int(cfg.wild_one_in))
	assert_almost_eq(GleamRules.chance(0), 1.0 / float(cfg.wild_one_in), 1e-9)

func test_base_rate_is_one_in_1024() -> void:
	assert_eq(GleamRules.one_in(), 1024)
	assert_almost_eq(GleamRules.chance(0), 1.0 / 1024.0, 1e-12)

func test_chain_raises_the_chance_up_to_its_cap() -> void:
	var cap: int = GleamRules.chain_max()
	var step: float = float(GleamRules.config().chain_step)
	assert_almost_eq(GleamRules.chance(1), (1.0 + step) / GleamRules.one_in(), 1e-12)
	assert_gt(GleamRules.chance(cap), GleamRules.chance(cap - 1))
	assert_eq(GleamRules.chance(cap + 50), GleamRules.chance(cap), "capped")
	assert_eq(GleamRules.chance(-3), GleamRules.chance(0))

func test_chain_counts_same_kind_and_resets() -> void:
	var a := Spirling.new(Database.species("Kindlop"), 5)
	var b := Spirling.new(Database.species("Zippit"), 5)
	var c: Dictionary = {}
	for i: int in GleamRules.chain_max() + 5:
		c = GleamRules.next_chain(c, a)
	assert_eq(int(c.count), GleamRules.chain_max())
	assert_eq(GleamRules.chain_for(c, "Kindlop"), GleamRules.chain_max())
	assert_eq(GleamRules.chain_for(c, "Zippit"), 0)
	c = GleamRules.next_chain(c, b)
	assert_eq(int(c.count), 1)
	b.gleam = true
	assert_eq(int(GleamRules.next_chain(c, b).count), 0, "a Gleam ends the chain")

func test_rolls_are_deterministic_for_a_seed() -> void:
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = SEED
	r2.seed = SEED
	for i: int in ROLLS:
		assert_eq(GleamRules.roll(r1, i % 12), GleamRules.roll(r2, i % 12))
	assert_eq(r1.randi(), r2.randi(), "one draw per roll keeps the streams in step")

func test_roll_matches_threshold() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = SEED
	var probe := RandomNumberGenerator.new()
	probe.seed = SEED
	for i: int in ROLLS:
		assert_eq(GleamRules.roll(r, 0), probe.randf() < GleamRules.chance(0))

func test_wild_encounter_rolls_are_deterministic() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = SEED
	b.seed = SEED
	for i: int in ROLLS:
		var x: Spirling = EncounterTable.roll("fernstair", a, [], "", {"species": "", "count": 0})
		var y: Spirling = EncounterTable.roll("fernstair", b, [], "", {"species": "", "count": 0})
		assert_eq(x.data.species_name, y.data.species_name)
		assert_eq(x.gleam, y.gleam)
		assert_false(x.gleam_boost, "a wild Gleam is a colour form only")

func test_every_species_has_a_palette() -> void:
	assert_gt(Database.spirlings.size(), 80)
	for sd: SpirlingData in Database.spirlings.values():
		assert_eq(GleamRules.palette(sd.species_name).size(), 4, sd.species_name)

func test_gleam_survives_unfurling() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 30)
	s.gleam = true
	var before: String = s.data.species_name
	s.evolve()
	assert_ne(s.data.species_name, before)
	assert_true(s.gleam)
	assert_true(Spirling.from_dict(s.to_dict()).gleam)
	s.furl_back()
	assert_true(s.gleam)

func test_wild_gleam_has_no_stat_boost() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 20)
	var atk: int = s.atk()
	s.gleam = true
	assert_eq(s.atk(), atk)
	s.gleam_boost = true
	assert_gt(s.atk(), atk)

func test_old_spirling_dict_loads_without_gleam() -> void:
	var s: Spirling = Spirling.from_dict({"species": "Kindlop", "level": 5})
	assert_false(s.gleam)
	assert_false(s.gleam_boost)

func test_old_prism_gleam_keeps_its_boost() -> void:
	var s: Spirling = Spirling.from_dict({"species": "Kindlop", "level": 5, "gleam": true})
	assert_true(s.gleam)
	assert_true(s.gleam_boost)

func test_old_saves_load_with_gleam_false() -> void:
	for f: String in DirAccess.get_files_at(FIXTURES):
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + f))
		if not raw is Dictionary or not SaveManager.migrate(raw) is Dictionary:
			continue
		SaveManager.apply_save(SaveManager.migrate(raw))
		for s: Spirling in GameState.party + GameState.storage:
			assert_false(s.gleam, f)
		assert_eq(int(GameState.gleam_chain.count), 0, f)

func test_chain_and_dex_survive_a_save() -> void:
	GameState.gleam_chain = {"species": "Kindlop", "count": 3}
	var s := Spirling.new(Database.species("Zippit"), 5)
	s.gleam = true
	GameState.note_spirlog(s)
	GameState.note_gleam_bonded(s)
	GameState.from_dict(GameState.to_dict())
	assert_eq(GameState.gleam_chain, {"species": "Kindlop", "count": 3})
	assert_true(bool(GameState.spirlog["Zippit"].gleam_bonded))
	assert_true(bool(GameState.spirlog["Zippit"].gleam_seen))

func test_old_spirlog_entry_gets_gleam_fields() -> void:
	var e: Dictionary = GameState.upgrade_spirlog_entry({"seen": true, "bonded": true})
	assert_false(bool(e.gleam_seen))
	assert_false(bool(e.gleam_bonded))

func test_wild_gleam_trades_and_shop_gleam_does_not() -> void:
	assert_eq(LocalBackend.trade_mon_why({"uid": "a", "species": "Kindlop", "gleam": true, "gleam_boost": false}), "")
	assert_eq(LocalBackend.trade_mon_why({"uid": "a", "species": "Kindlop", "gleam": true, "gleam_boost": true}), "shop_boosted")
	assert_eq(LocalBackend.trade_mon_why({"uid": "a", "species": "Kindlop", "gleam": true}), "shop_boosted", "legacy prism Gleam")
	var travelled: Dictionary = LocalBackend.trade_mon_clean({"uid": "a", "species": "Kindlop", "gleam": true, "gleam_boost": false})
	assert_true(Spirling.from_dict(travelled).gleam, "a traded Gleam keeps its form")

func test_prism_still_works_on_a_wild_gleam() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 5)
	s.gleam = true
	GameState.add_item("rg_gleam_prism")
	assert_true(GameState.use_gleam_prism(s))
	assert_true(s.gleam_boost)
	assert_false(GameState.use_gleam_prism(s))

## Every spirlings.json entry (all regions, legendaries, Era II elements) has a usable Gleam:
## four valid colours with the outline darkest, not the plain inks, a material, and a sprite whose
## pixels are all inks, so the shader really recolours every pixel.
func test_every_spirlings_json_entry_has_a_valid_gleam_variant() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(Database.SPIRLINGS_PATH))
	assert_true(raw is Array)
	var pal_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GleamRules.PALETTE_PATH))
	var names: Dictionary = {}
	for sp: Dictionary in raw:
		var kind: String = str(sp.name)
		names[kind] = true
		var hexes: Array = (pal_file.palettes as Dictionary).get(kind, [])
		assert_eq(hexes.size(), 4, kind + ": four Gleam colours")
		if hexes.size() != 4:
			continue
		for h: Variant in hexes:
			assert_true(str(h).is_valid_hex_number() and str(h).length() == 6, "%s: %s is a colour" % [kind, h])
		var pal: Array[Color] = GleamRules.palette(kind)
		var distinct: Dictionary = {}
		for c: Color in pal:
			distinct[c.to_html(false)] = true
		assert_eq(distinct.size(), 4, kind + ": four distinct tones")
		for i: int in range(1, 4):
			assert_lt(pal[0].get_luminance(), pal[i].get_luminance(), kind + ": outline is the darkest")
		assert_ne(pal.slice(1), EraManager.INK_PALETTE.slice(1), kind + ": differs from the normal inks")
		assert_not_null(GleamRules.material(kind), kind + ": has a Gleam material")
		for facing: String in ["front", "back"]:
			var path: String = EraManager.sprite_path(kind, facing)
			assert_false(path.is_empty(), "%s %s sprite" % [kind, facing])
			if path.begins_with("res://art/era1/"):
				assert_eq(_off_ink_pixels(path), 0, "%s %s: every pixel is an ink" % [kind, facing])
	assert_eq(names.size(), (raw as Array).size(), "names are unique")
	assert_eq((pal_file.palettes as Dictionary).size(), names.size(), "no palette for a removed kind")

func _off_ink_pixels(path: String) -> int:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return -1
	var bad: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var hit: bool = false
			for ink: Color in EraManager.INK_PALETTE:
				if Vector3(c.r - ink.r, c.g - ink.g, c.b - ink.b).length() < 0.03:
					hit = true
					break
			bad += 0 if hit else 1
	return bad

func test_encounter_sparkle_and_sound_cue_exist() -> void:
	var cfg: Dictionary = GleamRules.config()
	assert_true(FileAccess.file_exists(Sound.SFX_DIR % str(cfg.sfx)), "Gleam sound cue file")
	assert_gt(int(cfg.sparkles), 0)
	assert_gt(float(cfg.sparkle_time), 0.0)
	assert_not_null(ElementFx.shape("glint", 0), "sparkle texture")

func test_spirlog_gleam_counter() -> void:
	var book: Dictionary = {
		"Kindlop": {"seen": true, "bonded": true, "gleam_seen": true, "gleam_bonded": true},
		"Zippit": {"seen": true, "gleam_seen": true},
		"Mossling": {"seen": true, "bonded": true},
	}
	var c: Dictionary = SpirlogBook.gleam_counts(book)
	assert_eq(int(c.seen), 2)
	assert_eq(int(c.bonded), 1)
	assert_eq(int(c.total), Database.spirlings.size())
	assert_eq(SpirlogBook.gleam_bonded_kinds(book), PackedStringArray(["Kindlop"]))
	assert_eq(SpirlogBook.gleam_line(book), GleamRules.STAR + " Gleam: 2 seen, 1 bonded")
	assert_eq(int(SpirlogBook.chapter_progress("veydal", book).gleam), 1)
	assert_eq(int(SpirlogBook.gleam_counts({}).seen), 0)
