extends GutTest
## Store pictures and preview video (plan Chimora 100, items 86, 87, 89, 97): the live duel the
## tools show is a real one on the local stand-in of the server, and the tools give Online back.

const Shots: GDScript = preload("res://tools/store_shots_runner.gd")

func before_all() -> void:
	Database.load_all()

func test_store_duel_is_a_running_live_duel_and_online_is_restored() -> void:
	var keep_backend: OnlineBackend = Online.backend
	var keep_state: int = Online.state
	var duel: Array = Shots.start_duel(Shots.TEAM_MINE, Shots.TEAM_FOE, Shots.FRIEND)
	assert_true(duel[0] is LiveDuelStage)
	assert_true(Online.backend is LocalBackend)
	assert_eq(Online.state, Online.State.ONLINE)
	var st: Dictionary = (duel[1] as LocalBackend).call_fn("live_state", {"p_id": int(duel[2])}).data
	assert_eq(str(st.state), "running", str(st))
	assert_eq((st.teams as Array).size(), 2)
	Shots.end_duel(duel)
	assert_eq(Online.backend, keep_backend)
	assert_eq(Online.state, keep_state)

func test_store_kinds_exist_with_their_own_art() -> void:
	for kind: String in Shots.HERO + Shots.TEAM_MINE + Shots.TEAM_FOE + Shots.UNFURL:
		assert_not_null(Database.species(kind), kind)
		assert_false(EraManager.sprite_path(kind).is_empty(), kind)
	var old: SpirlingData = Database.species(Shots.UNFURL[0])
	assert_true(old.unfold.any(func(u: Dictionary) -> bool: return (u.to as SpirlingData).species_name == Shots.UNFURL[1]),
		"the unfurl picture shows a real step of the line")
