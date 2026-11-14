extends GutTest
## Plan area 2, items 734-739: Tamer AI tiers and keepsakes, Warden ring caps, Tailwind.

func _npc(map_id: String, id: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	for n: Variant in d.npcs:
		if str(n.get("id", "")) == id:
			return n
	return {}

func test_tamer_ai_tiers() -> void:
	var tamer: int = GameState.Difficulty.TAMER
	var orrin: Dictionary = _npc("cinder_rift", "warden_orrin")
	var bram: Dictionary = _npc("crowcrest", "bram")
	assert_eq(TrainerData.ai_tier(orrin, GameState.AI_LEVELS[tamer], tamer), 2)
	assert_eq(TrainerData.ai_tier(bram, GameState.AI_LEVELS[tamer], tamer), 1)
	assert_eq(TrainerData.ai_tier({"ai": 3}, 1, tamer), 1, "Tamer Wayfarers always tier 1")
	assert_eq(TrainerData.ai_tier(orrin, 0, GameState.Difficulty.STORY), TrainerData.WARDEN_MIN_AI, "the floor stays")
	assert_eq(TrainerData.ai_tier(orrin, 3, GameState.Difficulty.RIFT_BORN), 3)
	var team: Array[Spirling] = TrainerData.build_team(orrin, "", RandomNumberGenerator.new(), tamer)
	assert_eq(int(TrainerData.battle_info(orrin, team, 1, tamer).ai), 2)

func test_no_keepsakes_below_veteran() -> void:
	var def: Dictionary = {"team": [{"species": "Kindlop", "level": 10, "held": "spark_coil"}]}
	for d: int in [GameState.Difficulty.STORY, GameState.Difficulty.TAMER]:
		assert_eq(TrainerData.build_team(def, "", RandomNumberGenerator.new(), d)[0].held, "", "difficulty %d" % d)
	assert_eq(TrainerData.build_team(def, "", RandomNumberGenerator.new(), GameState.Difficulty.VETERAN)[0].held, "spark_coil")
	assert_eq(TrainerData.build_team(def, "", RandomNumberGenerator.new())[0].held, "spark_coil", "untuned keeps the data")

func test_warden_teams_fit_the_ring_cap() -> void:
	# Orrin guards the first Rift (no Rift sealed yet), Brisa the second, Maelis the third.
	var wardens: Array = [["cinder_rift", "warden_orrin", 0], ["mist_rift", "warden_brisa", 1], ["tide_rift", "warden_maelis", 2]]
	for w: Array in wardens:
		var cap: int = GameState.LEVEL_CAPS[int(w[2])]
		for d: int in [GameState.Difficulty.VETERAN, GameState.Difficulty.RIFT_BORN]:
			for s: Spirling in TrainerData.build_team(_npc(w[0], w[1]), "", RandomNumberGenerator.new(), d, cap):
				assert_lte(s.level, cap, "%s %s R%d on %d" % [w[1], s.data.species_name, s.level, d])

func test_warden_card_names_the_cap() -> void:
	var orrin: Dictionary = _npc("cinder_rift", "warden_orrin")
	var team: Array[Spirling] = TrainerData.build_team(orrin, "", RandomNumberGenerator.new(), GameState.Difficulty.VETERAN, 12)
	assert_true(WardenCard.text(orrin, team, GameState.Difficulty.VETERAN, 12).contains("R12"))
	assert_false(WardenCard.text(orrin, team, GameState.Difficulty.TAMER, Spirling.STORY_RING).contains("R12."))

func test_tailwind_offer_rules() -> void:
	var story: int = GameState.Difficulty.STORY
	var tamer: int = GameState.Difficulty.TAMER
	assert_false(Tailwind.offered(story, 1))
	assert_true(Tailwind.offered(story, 2))
	assert_false(Tailwind.offered(tamer, 2))
	assert_true(Tailwind.offered(tamer, 3))
	for d: int in [GameState.Difficulty.VETERAN, GameState.Difficulty.RIFT_BORN]:
		assert_false(Tailwind.offered(d, 99), "never on difficulty %d" % d)
	assert_eq(Tailwind.energy_cut(story), 2)
	assert_eq(Tailwind.energy_cut(tamer), 0)

func test_tailwind_counts() -> void:
	var rec: Dictionary = {}
	Tailwind.note_outcome(rec, "bram", false)
	Tailwind.note_outcome(rec, "bram", false)
	assert_eq(Tailwind.losses(rec, "bram"), 2)
	assert_eq(Tailwind.losses(rec, "lio"), 0)
	Tailwind.note_outcome(rec, "bram", true)
	assert_eq(Tailwind.losses(rec, "bram"), 0, "a win clears the count")
	assert_eq(Tailwind.note_use(rec), 1)
	assert_eq(Tailwind.note_use(rec), 2)
	assert_eq(int(rec.tailwind_used), 2)

func test_foe_starts_with_less_energy() -> void:
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 10, RandomNumberGenerator.new())]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Puddlet"), 10, RandomNumberGenerator.new())]
	var m := BattleModel.new(mine, foes, false, 7, 1)
	m.start_energy_cut = [0, 2]
	m.start()
	assert_eq(m.active_spirling(1).energy, m.active_spirling(0).energy - 2)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "")
	assert_eq(int(snap.foe_energy_cut), 2)
