extends GutTest
## Nachhall: two Spirlings sing together at an Echo spring, their call forms an Echo Core,
## and a Hallkind wakes from it after steps or wins (plan area 1, items 183-186).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _mk(species: String, lvl: int = 10) -> Spirling:
	return Spirling.new(Database.species(species), lvl)

## A species that has an earlier form, and that line's first form.
func _evolved() -> Array[SpirlingData]:
	for sd: SpirlingData in Database.spirlings.values():
		if sd.rarity != "ancient" and Database.earlier_form(sd) != null:
			return [sd, GameState.first_form(sd)]
	return []

func test_spring_opens_with_second_rift() -> void:
	assert_false(GameState.echo_spring_open())
	GameState.set_flag("storage_remote")
	assert_true(GameState.echo_spring_open())

func test_sing_problems() -> void:
	var a := _mk("Kindlop")
	var b := _mk("Wickit")
	assert_ne(GameState.sing_problem(a, b), "", "not owned yet")
	GameState.party.append(a)
	GameState.storage.append(b)
	assert_eq(GameState.sing_problem(a, b), "")
	assert_ne(GameState.sing_problem(a, a), "", "needs two different Spirlings")
	assert_ne(GameState.sing_problem(a, null), "")
	var voice := _mk("Velahra", 40)
	GameState.storage.append(voice)
	assert_eq(GameState.sing_problem(a, voice), "A First Voice sings alone.")

func test_sing_together_forms_core_of_a_first_form() -> void:
	var pair: Array[SpirlingData] = _evolved()
	assert_eq(pair.size(), 2)
	var a := Spirling.new(pair[0], 30)
	var b := _mk("Wickit")
	GameState.party.append_array([a, b])
	var rng := RandomNumberGenerator.new()
	var kinds: Dictionary = {}
	for seed: int in 20:
		GameState.echo_cores.clear()
		rng.seed = seed
		var core: Dictionary = GameState.sing_together(a, b, rng)
		assert_false(core.is_empty())
		kinds[core.kind] = true
		assert_eq(core.parents, [pair[0].species_name, "Wickit"])
		assert_eq(int(core.rests), 0)
	assert_true(kinds.has(pair[1].species_name), "evolved parent gives its first form")
	assert_false(kinds.has(pair[0].species_name), "never the evolved form itself")
	assert_eq(GameState.party.size(), 2, "parents stay")

func test_core_limit() -> void:
	var a := _mk("Kindlop")
	var b := _mk("Wickit")
	GameState.party.append_array([a, b])
	for i: int in GameState.MAX_ECHO_CORES:
		assert_false(GameState.sing_together(a, b).is_empty())
	assert_true(GameState.sing_together(a, b).is_empty())
	assert_eq(GameState.echo_cores.size(), GameState.MAX_ECHO_CORES)

func test_core_wakes_after_rests() -> void:
	var a := _mk("Kindlop")
	var b := _mk("Wickit")
	GameState.party.append_array([a, b])
	GameState.sing_together(a, b)
	for i: int in GameState.ECHO_CORE_RESTS - 1:
		GameState.note_core_rest()
	assert_eq(GameState.awaken_cores().size(), 0)
	GameState.note_core_rest()
	var kids: Array[Spirling] = GameState.awaken_cores()
	assert_eq(kids.size(), 1)
	assert_eq(kids[0].level, 1, "Hallkind starts at Ring 1")
	assert_eq(kids[0].lineage, ["Kindlop", "Wickit"] as Array[String])
	assert_true(GameState.echo_cores.is_empty())
	assert_true((GameState.party + GameState.storage).has(kids[0]))

func test_core_wakes_after_wins() -> void:
	var a := _mk("Kindlop")
	var b := _mk("Wickit")
	GameState.party.append_array([a, b])
	GameState.sing_together(a, b)
	for i: int in GameState.ECHO_CORE_WINS:
		GameState.note_core_win()
	assert_eq(GameState.awaken_cores().size(), 1)

func test_cores_survive_save_and_bad_data_is_dropped() -> void:
	var a := _mk("Kindlop")
	var b := _mk("Wickit")
	GameState.party.append_array([a, b])
	GameState.sing_together(a, b)
	GameState.note_core_rest()
	GameState.note_core_win()
	var d: Dictionary = GameState.to_dict()
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(GameState.echo_cores.size(), 1)
	assert_eq(int(GameState.echo_cores[0].rests), 1)
	assert_eq(int(GameState.echo_cores[0].wins), 1)
	d["echo_cores"] = [{"kind": "NoSuchKind"}, "junk", {"kind": "Wickit", "rests": "x", "parents": 5},
		{"kind": "Wickit"}, {"kind": "Wickit"}, {"kind": "Wickit"}]
	GameState.from_dict(d)
	assert_eq(GameState.echo_cores.size(), GameState.MAX_ECHO_CORES)
	assert_eq(int(GameState.echo_cores[0].rests), 0)
	assert_eq(GameState.echo_cores[0].parents, [])
	d.erase("echo_cores")
	GameState.from_dict(d)
	assert_true(GameState.echo_cores.is_empty(), "old saves have no cores")

func test_walking_never_wakes_a_core() -> void:
	# Legal review (item 186): no step counter, cores wake only from wins or rests.
	assert_false("note_core_step" in GameState.get_method_list().map(func(m: Dictionary) -> String: return m.name))
	assert_false(GameState.core_ready({"kind": "Wickit", "steps": 100000, "rests": 0, "wins": 0}))
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	var stepped: String = src.substr(src.find("func _on_player_stepped"), 600)
	assert_false(stepped.contains("core"), "the step handler never touches Echo Cores")
