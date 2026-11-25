extends GutTest
## Chimora 200 list items 55 (shorter repeat animations), 59 (escape chance in words),
## 66 (foe heals with an item once per battle) and 76 (rare Spirlings' battle theme).

const Side := BattleModel.Side

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	RepeatShort.reset()

# --- 55 ---------------------------------------------------------------------------------------

func test_repeat_animation_is_quicker_the_second_time() -> void:
	assert_eq(RepeatShort.speed("art:Cinder Nip"), 1.0, "first time at full length")
	assert_eq(RepeatShort.speed("art:Cinder Nip"), RepeatShort.REPEAT_SPEED, "second time quicker")
	assert_eq(RepeatShort.speed("art:Fizz Pop"), 1.0, "another art still plays in full")
	assert_gt(RepeatShort.REPEAT_SPEED, 1.0)
	RepeatShort.reset()
	assert_eq(RepeatShort.speed("art:Cinder Nip"), 1.0, "a new session shows it in full again")

# --- 66 ---------------------------------------------------------------------------------------

func _hurt_foe() -> BattleModel:
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 20)] as Array[Spirling], [BattleFixtures.make("Kindlop", 20)] as Array[Spirling], false)
	m.foe_items = {"tonic": 5}
	m.party(Side.FOE)[0].hp = 3
	return m

func test_foe_heals_with_an_item_only_once() -> void:
	var m: BattleModel = _hurt_foe()
	assert_eq(BattleAI.new(2).choose(m, Side.FOE).kind, BattleAction.Kind.ITEM, "the first heal is allowed")
	m.items_used[Side.FOE] = {"tonic": 1}
	assert_eq(BattleAI.heal_items_spent(m, Side.FOE), 1)
	assert_ne(BattleAI.new(2).choose(m, Side.FOE).kind, BattleAction.Kind.ITEM, "no second healing item")

func test_player_auto_keeps_its_item_limit() -> void:
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 20)] as Array[Spirling], [BattleFixtures.make("Kindlop", 20)] as Array[Spirling], false)
	m.inventory = {"tonic": 5}
	m.party(Side.PLAYER)[0].hp = 3
	m.items_used[Side.PLAYER] = {"tonic": 1}
	assert_eq(BattleAI.new(2).choose(m, Side.PLAYER).kind, BattleAction.Kind.ITEM, "auto battle may still heal twice")
