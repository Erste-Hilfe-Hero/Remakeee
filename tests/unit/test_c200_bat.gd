extends GutTest
## Chimora 200 list items 55 (shorter repeat animations), 59 (escape chance in words),
## 66 (foe heals with an item once per battle) and 76 (rare Spirlings' battle theme).

const Side := BattleModel.Side

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	# Battle scenes in earlier test files leave arts in the session list.
	RepeatShort.reset()

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

# --- 59 ---------------------------------------------------------------------------------------

func _wild(my_level: int, foe_level: int) -> BattleModel:
	return BattleFixtures.model([BattleFixtures.make("Kindlop", my_level)] as Array[Spirling], [BattleFixtures.make("Zippit", foe_level)] as Array[Spirling])

func test_escape_words_follow_the_chance() -> void:
	var m: BattleModel = _wild(20, 20)
	var me: Spirling = m.active_spirling(Side.PLAYER)
	var words: Dictionary = {}
	for tries: int in [0, 1, 2]:
		m.flee_attempts = tries
		var c: float = m.escape_chance(me)
		var w: String = BattleInfo.escape_words(m)
		var want: String = "Escape looks easy." if c >= BattleInfo.ESCAPE_EASY else ("Escape might work." if c >= BattleInfo.ESCAPE_HARD else "Escape looks hard.")
		assert_eq(w, want)
		words[w] = true
	m.flee_attempts = 3
	assert_eq(BattleInfo.escape_words(m), "Escape looks easy.", "every try makes it easier")
	var slow: BattleModel = _wild(3, 60)
	assert_eq(BattleInfo.escape_words(slow), "Escape looks hard.", "a much faster foe")

func test_escape_words_never_show_a_number() -> void:
	for lv: Array in [[20, 20], [3, 60], [60, 3]]:
		var w: String = BattleInfo.escape_words(_wild(lv[0], lv[1]))
		assert_false(w.is_empty())
		assert_false(RegEx.create_from_string("[0-9%]").search(w) != null, w)

func test_no_escape_words_outside_wild_battles() -> void:
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 20)] as Array[Spirling], [BattleFixtures.make("Zippit", 20)] as Array[Spirling], false)
	assert_eq(BattleInfo.escape_words(m), "")

func test_escape_chance_matches_the_run_roll() -> void:
	var a: BattleModel = _wild(20, 20)
	var b: BattleModel = _wild(20, 20)
	a.submit_turn(BattleAction.make_run(Side.PLAYER))
	b.submit_turn(BattleAction.make_run(Side.PLAYER))
	assert_eq(a.outcome, b.outcome, "same seed, same result")
	assert_eq(a.flee_attempts, 1)

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

# --- 76 ---------------------------------------------------------------------------------------

func test_rare_foes() -> void:
	assert_false(BattleAudio.rare_foes([BattleFixtures.make("Zippit", 10)] as Array[Spirling]))
	assert_false(BattleAudio.rare_foes([BattleFixtures.make("Smoldrake", 10)] as Array[Spirling]), "shy is too common")
	assert_true(BattleAudio.rare_foes([BattleFixtures.make("Velahra", 10)] as Array[Spirling]), "ancient kind")
	var prism: Spirling = BattleFixtures.make("Zippit", 10)
	prism.prism = true
	assert_true(BattleAudio.rare_foes([BattleFixtures.make("Kindlop", 10), prism] as Array[Spirling]), "a Prism one")
	var elder: Spirling = BattleFixtures.make("Zippit", 10)
	elder.set_meta(WildRules.ELDER_META, true)
	assert_true(BattleAudio.rare_foes([elder] as Array[Spirling]), "an Elder")

func test_rare_theme_is_its_own_existing_track() -> void:
	var rare: String = BattleAudio.theme("", false, false, false, "", true)
	assert_ne(rare, "battle")
	assert_true(ResourceLoader.exists(Sound.MUSIC_DIR % rare), rare)
	assert_true(MusicDirector.is_battle_track(rare))
	assert_eq(BattleAudio.theme("", false, true, true, "", true), rare, "ahead of festival and night")
	assert_eq(BattleAudio.theme("", true, false, false, "", true), "warden", "a Warden keeps its own")
	assert_eq(BattleAudio.theme("", false, false, false, "", false), "battle")
