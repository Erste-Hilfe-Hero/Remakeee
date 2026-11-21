extends GutTest
## The family business: Echo Core offspring inherit Spark and heirloom arts; the matchmaker's
## contract passes on more, unless she sold the match twice (then only the bonus is lost).

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

func _mk(species: String, lvl: int) -> Spirling:
	return Spirling.new(Database.species(species), lvl, _rng(lvl))

func _maxed(s: Spirling) -> Spirling:
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = Spirling.SPARK_MAX
	return s

func _core(a: Spirling, b: Spirling, contract: bool) -> Dictionary:
	return {"kind": "Kindlop", "parents": [a.data.species_name, b.data.species_name], "rests": 0, "wins": 0,
		"heir": Breeding.snapshot(a, b), "contract": contract}

func _kid() -> Spirling:
	var k := Spirling.new(Database.species("Kindlop"), 1, _rng(7))
	for key: String in Spirling.STAT_KEYS:
		k.spark[key] = 0
	return k

func _count_max(k: Spirling) -> int:
	var n: int = 0
	for key: String in Spirling.STAT_KEYS:
		n += 1 if k.spark[key] == Spirling.SPARK_MAX else 0
	return n

func test_snapshot_keeps_both_sparks_and_arts() -> void:
	var a := _mk("Smoldrake", 20)
	var b := _mk("Puddlet", 10)
	var snap: Dictionary = Breeding.snapshot(a, b)
	assert_eq((snap.spark as Array).size(), 2)
	for m: MoveData in a.moves + b.moves:
		assert_true(m.move_name in snap.arts)

func test_plain_inheritance_passes_best_spark_and_one_heirloom() -> void:
	var a := _maxed(_mk("Smoldrake", 20))
	var b := _mk("Puddlet", 10)
	var kid := _kid()
	var res: Dictionary = Breeding.inherit(kid, _core(a, b, false), _rng(3))
	assert_false(res.betrayed)
	assert_eq((res.stats as Array).size(), int(Breeding.data().spark_stats))
	assert_eq(_count_max(kid), int(Breeding.data().spark_stats))
	assert_eq((res.arts as Array).size(), 1)
	var art: MoveData = Database.move(str(res.arts[0]))
	assert_true(art.element in kid.data.elements, "heirloom shares the young one's element")
	assert_true(kid.moves.size() <= Spirling.MAX_MOVES)

func test_contract_passes_more_or_is_void_but_never_less() -> void:
	var a := _maxed(_mk("Smoldrake", 20))
	var b := _mk("Puddlet", 10)
	var seen: Dictionary = {}
	for i: int in 40:
		var kid := _kid()
		var res: Dictionary = Breeding.inherit(kid, _core(a, b, true), _rng(i))
		var want: int = int(Breeding.data().spark_stats if res.betrayed else Breeding.data().contract_spark_stats)
		assert_eq(_count_max(kid), want)
		assert_ne(str(res.line), "")
		seen[res.betrayed] = true
	assert_eq(seen.size(), 2, "both honoured and betrayed contracts happen over 40 cores")

func test_inheritance_never_lowers_spark() -> void:
	var a := _mk("Smoldrake", 20)
	var b := _mk("Puddlet", 10)
	for key: String in Spirling.STAT_KEYS:
		a.spark[key] = 0
		b.spark[key] = 0
	var kid := _maxed(Spirling.new(Database.species("Kindlop"), 1, _rng(2)))
	Breeding.inherit(kid, _core(a, b, true), _rng(5))
	assert_eq(_count_max(kid), 5)

func test_seal_contract_costs_the_fee_once() -> void:
	var a := _mk("Smoldrake", 20)
	var b := _mk("Puddlet", 10)
	GameState.party.append_array([a, b])
	GameState.sing_together(a, b, _rng(1))
	var core: Dictionary = Breeding.open_core()
	assert_false(core.is_empty())
	assert_true(core.has("heir"))
	GameState.money = 0
	assert_false(Breeding.seal_contract(core), "no money, no contract")
	var fee: int = int(Breeding.data().contract_fee)
	GameState.money = fee + 5
	assert_true(Breeding.seal_contract(core))
	assert_eq(GameState.money, 5)
	assert_false(Breeding.seal_contract(core), "one contract per core")
	assert_true(Breeding.open_core().is_empty())

func test_contract_and_heir_survive_a_save() -> void:
	var a := _mk("Smoldrake", 20)
	var b := _mk("Puddlet", 10)
	GameState.party.append_array([a, b])
	GameState.sing_together(a, b, _rng(1))
	GameState.money = 10000
	Breeding.seal_contract(Breeding.open_core())
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.from_dict(d)
	assert_true(bool(GameState.echo_cores[0].contract))
	assert_eq((GameState.echo_cores[0].heir.spark as Array).size(), 2)

func test_awakened_kid_carries_inheritance() -> void:
	var a := _maxed(_mk("Smoldrake", 20))
	var b := _mk("Kindlop", 10)
	GameState.party.append_array([a, b])
	GameState.sing_together(a, b, _rng(1))
	GameState.echo_cores[0]["rests"] = GameState.ECHO_CORE_RESTS
	var kids: Array[Spirling] = GameState.awaken_cores()
	assert_eq(kids.size(), 1)
	assert_true(kids[0].has_meta("inheritance"))

func test_matchmaker_stands_at_the_rest_spring() -> void:
	var m: MapData = MapData.load_map("rest_spring")
	var found: bool = false
	for n: Dictionary in m.npcs:
		found = found or str(n.get("id", "")) == "matchmaker"
	assert_true(found)
	assert_eq(str(Dialogue.get_entry("rest_spring/matchmaker").get("action", "")), "matchmaker")

func test_german_for_every_line() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	var d: Dictionary = Breeding.data()
	var lines: Array = d.rival_families.duplicate()
	lines.append_array(d.contract_lines)
	lines.append_array([d.matchmaker, d.honoured_line, d.betrayed_line])
	for line: Variant in lines:
		assert_true(de.has(str(line)), "German missing: " + str(line))
