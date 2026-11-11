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
