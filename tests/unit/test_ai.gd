extends GutTest
## AI tiers 0-2.

const Side := BattleModel.Side

func before_all() -> void:
	Database.load_all()

func test_tier0_always_picks_a_legal_move() -> void:
	var foe: Array[Spirling] = [BattleFixtures.make("Kindlop", 10)]
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 10)] as Array[Spirling], foe)
	var ai := BattleAI.new(0)
	for i: int in 50:
		var a: BattleAction = ai.choose(m, Side.FOE)
		assert_true(m.is_legal(a))

func test_ai_rests_when_out_of_energy() -> void:
	var foe: Array[Spirling] = [BattleFixtures.make("Kindlop", 10)]
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 10)] as Array[Spirling], foe)
	foe[0].energy = 0
	for lvl: int in [0, 1, 2]:
		assert_eq(BattleAI.new(lvl).choose(m, Side.FOE).kind, BattleAction.Kind.REST)

func test_tier1_prefers_super_effective() -> void:
	# Kindlop knows a Stone move and an Ember move; Ember is x2 into Mossling.
	var foe: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Headlong Charge", "Cinder Nip"])]
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 20)] as Array[Spirling], foe)
	var a: BattleAction = BattleAI.new(1).choose(m, Side.FOE)
	assert_eq(foe[0].moves[a.move_index].move_name, "Cinder Nip")

func test_tier1_values_status_on_unstatused_target() -> void:
	var foe: Array[Spirling] = [BattleFixtures.make("Shalebat", 20, ["Hush"])]
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 20)] as Array[Spirling], foe)
	var ai := BattleAI.new(1)
	var fresh: float = ai.score_move(m, Side.FOE, 0)
	m.party(Side.PLAYER)[0].status = "jolt"
	assert_gt(fresh, ai.score_move(m, Side.FOE, 0))

func test_tier2_swaps_out_of_bad_matchup() -> void:
	# Foe Mossling faces an Ember attacker; its teammate Puddlet resists Ember.
	var player: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])]
	var foe: Array[Spirling] = [BattleFixtures.make("Mossling", 20), BattleFixtures.make("Puddlet", 20)]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	var a: BattleAction = BattleAI.new(2).choose(m, Side.FOE)
	assert_eq(a.kind, BattleAction.Kind.SWAP)
	assert_eq(a.swap_index, 1)

func test_tier2_heals_when_low() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Mossling", 20)]
	var foe: Array[Spirling] = [BattleFixtures.make("Kindlop", 20)]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	m.foe_items = {"tonic": 1}
	foe[0].hp = 3
	var a: BattleAction = BattleAI.new(2).choose(m, Side.FOE)
	assert_eq(a.kind, BattleAction.Kind.ITEM)

func test_replacement_prefers_good_matchup() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Mossling", 20, ["Lichen Lash"])]
	var foe: Array[Spirling] = [BattleFixtures.make("Zippit", 20), BattleFixtures.make("Puddlet", 20), BattleFixtures.make("Kindlop", 20)]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	foe[0].hp = 0
	assert_eq(BattleAI.new(1).choose_replacement(m, Side.FOE), 2, "Kindlop (Ember) beats Bloom")
