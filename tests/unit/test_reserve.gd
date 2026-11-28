extends GutTest
## Hollowgate Reserve: entry fee, limited sightings and Echo calls, bait and rattle that trade
## calm against keenness, Spirlings that slip away, and a snitch that only costs a sighting.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _sight(species: String = "Mirkmole") -> Dictionary:
	return {"species": species, "level": 18, "bait": 0, "rattle": 0, "snitched": false}

func test_table_names_real_species() -> void:
	for row: Dictionary in Reserve.data().table:
		assert_not_null(Database.species(str(row.species)), str(row.species))
		assert_true(int(row.ring[0]) <= int(row.ring[1]))

func test_entry_costs_the_fee() -> void:
	GameState.money = 0
	assert_true(Reserve.enter().is_empty())
	var fee: int = int(Reserve.data().entry_fee)
	GameState.money = fee
	var run: Dictionary = Reserve.enter()
	assert_eq(GameState.money, 0)
	assert_eq(int(run.calls), int(Reserve.data().calls))
	assert_eq(int(GameState.records[Reserve.VISITS]), 1)

func test_sightings_run_out() -> void:
	var run: Dictionary = {"sightings": 2, "calls": 5}
	var s: Dictionary = Reserve.sighting(run, _rng(1))
	assert_not_null(Database.species(str(s.species)))
	Reserve.sighting(run, _rng(2))
	assert_true(Reserve.over(run))

func test_bait_calms_and_dulls_rattle_does_the_opposite() -> void:
	var plain: Dictionary = _sight()
	var baited: Dictionary = _sight()
	baited["bait"] = 1
	var rattled: Dictionary = _sight()
	rattled["rattle"] = 1
	assert_lt(Reserve.flee_odds(baited), Reserve.flee_odds(plain))
	assert_lt(Reserve.reach_odds(baited, 1.0), Reserve.reach_odds(plain, 1.0))
	assert_gt(Reserve.flee_odds(rattled), Reserve.flee_odds(plain))
	assert_gt(Reserve.reach_odds(rattled, 1.0), Reserve.reach_odds(plain, 1.0))
	assert_eq(Reserve.reach_odds(plain, 0.0), 0.0, "a silent call reaches nobody")

func test_stacks_are_capped() -> void:
	var run: Dictionary = {"sightings": 1, "calls": 5}
	var s: Dictionary = _sight()
	for i: int in 10:
		Reserve.act(run, s, "bait", _rng(i))
	assert_eq(int(s.bait), int(Reserve.data().max_stacks))

func test_calls_are_limited() -> void:
	var run: Dictionary = {"sightings": 3, "calls": 1}
	var s: Dictionary = _sight()
	Reserve.act(run, s, "call", _rng(1), 0.0)
	assert_eq(int(run.calls), 0)
	assert_true(Reserve.over(run))
	assert_false(Reserve.act(run, s, "call", _rng(1), 1.0).bonded, "no calls left")

func test_perfect_calls_reach_and_some_flee() -> void:
	var seen: Dictionary = {}
	for i: int in 60:
		var run: Dictionary = {"sightings": 1, "calls": 1}
		var s: Dictionary = _sight()
		s["rattle"] = 3
		var res: Dictionary = Reserve.act(run, s, "call", _rng(i), 1.0)
		if res.bonded:
			seen["bonded"] = true
		if res.fled:
			seen["fled"] = true
	assert_eq(seen.size(), 2)

func test_snitch_happens_sometimes() -> void:
	var snitched: int = 0
	for i: int in 200:
		snitched += 1 if Reserve.sighting({"sightings": 1}, _rng(i)).snitched else 0
	assert_gt(snitched, 0)
	assert_lt(snitched, 100)

func test_spirling_of_a_sighting() -> void:
	var s: Spirling = Reserve.spirling_of(_sight("Glimmoth"), _rng(1))
	assert_eq(s.data.species_name, "Glimmoth")
	assert_eq(s.level, 18)

func test_gate_in_greyreach() -> void:
	var m: MapData = MapData.load_map("greyreach")
	var found: bool = false
	for n: Dictionary in m.npcs:
		found = found or str(n.get("id", "")) == "reserve_gate"
	assert_true(found)
	assert_eq(str(Dialogue.get_entry("greyreach/reserve_gate").get("action", "")), "reserve")

func test_german_for_every_line() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	var d: Dictionary = Reserve.data()
	var lines: Array = d.welcome.duplicate()
	for k: String in ["boss", "ring", "bait_line", "rattle_line", "fled_line", "snitch_line", "bonded_line", "missed_line", "done_line"]:
		lines.append(d[k])
	for line: Variant in lines:
		assert_true(de.has(str(line)), "German missing: " + str(line))
