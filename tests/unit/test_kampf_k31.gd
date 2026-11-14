extends GutTest
## KAMPF_PLAN_1000 area "Bosse und Wardens", items 404 (phase calls a guard), 405 (phase marks),
## 406 (phase music), 415 (rewards per difficulty), 417 (heart echoes), 418 (heart rush).

func _drowned(guard_down: bool, difficulty: int = GameState.Difficulty.VETERAN) -> BattleModel:
	var mine: Array[Spirling] = []
	for i: int in 4:
		mine.append(BattleFixtures.make("Puddlet", 18, ["Fizz Pop"]))
	var foes: Array[Spirling] = [BattleFixtures.make("Riptail", 18, ["Fizz Pop"]), BattleFixtures.make("Kelpup", 16, ["Fizz Pop"])]
	var m := BattleModel.new(mine, foes, false, 7, 0)
	m.front_size = [4, 2]
	m.foe_boss = "drowned_heart"
	m.boss_difficulty = difficulty
	m.start()
	if guard_down:
		m.deal_damage(BattleModel.Side.FOE, 9999, {}, 1)
		m.slots[BattleModel.Side.FOE][1] = -1
	return m

func _ashen() -> BattleModel:
	var boss: Spirling = BattleFixtures.make("Smoldrake", 14, ["Cinder Nip"])
	var m := BattleModel.new([BattleFixtures.make("Puddlet", 14, ["Fizz Pop"])] as Array[Spirling], [boss] as Array[Spirling], false, 7, 0)
	m.foe_boss = "ashen_heart"
	m.start()
	return m

# --- 404 ---------------------------------------------------------------------------------

func test_phase_calls_a_guard_into_the_empty_slot() -> void:
	var m: BattleModel = _drowned(true)
	var boss: Spirling = m.active_spirling(BattleModel.Side.FOE, 0)
	assert_eq(BossRules.guard_slot(m), 1)
	m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.55))
	assert_true(m.boss_phase_done)
	var guard: Spirling = m.active_spirling(BattleModel.Side.FOE, 1)
	assert_not_null(guard, "the guard stands in slot 1")
	assert_true(m.is_standing(guard))
	assert_eq(guard.data.species_name, "Kelpup")
	assert_eq(guard.level, boss.level - 2)
	assert_eq(m.parties[BattleModel.Side.FOE].size(), 3)

func test_story_and_tamer_hearts_call_nobody() -> void:
	for d: int in [-1, GameState.Difficulty.STORY, GameState.Difficulty.TAMER]:
		var m: BattleModel = _drowned(true, d)
		var boss: Spirling = m.active_spirling(BattleModel.Side.FOE, 0)
		m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.55))
		assert_true(m.boss_phase_done)
		assert_eq(m.parties[BattleModel.Side.FOE].size(), 2, "difficulty %d keeps the tuned heart" % d)

func test_no_guard_while_the_old_one_stands() -> void:
	var m: BattleModel = _drowned(false)
	var boss: Spirling = m.active_spirling(BattleModel.Side.FOE, 0)
	assert_eq(BossRules.guard_slot(m), -1)
	m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.55))
	assert_true(m.boss_phase_done)
	assert_eq(m.parties[BattleModel.Side.FOE].size(), 2, "nobody new joins")

func test_single_front_boss_calls_nobody() -> void:
	var m: BattleModel = _ashen()
	assert_eq(BossRules.guard_slot(m), -1)
	assert_null(BossRules.call_guard(m, m.active_spirling(BattleModel.Side.FOE), {"species": "Kelpup"}))

# --- 405 ---------------------------------------------------------------------------------

func test_phase_marks_list_every_phase_to_come() -> void:
	var m: BattleModel = _ashen()
	var marks: Array[float] = BattleInfo.phase_marks(m)
	assert_eq(marks.size(), 2, "second phase and the late phase")
	assert_almost_eq(marks[0], 0.5, 0.001)
	assert_almost_eq(marks[1], 0.25, 0.001)
	var boss: Spirling = m.active_spirling(BattleModel.Side.FOE)
	m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.55))
	assert_eq(BattleInfo.phase_marks(m), [0.25] as Array[float], "the passed mark is gone")
	m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.25))
	assert_true(BattleInfo.phase_marks(m).is_empty())

func test_no_marks_without_a_boss() -> void:
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Puddlet", 10)] as Array[Spirling], [BattleFixtures.make("Kindlop", 10)] as Array[Spirling])
	assert_true(BattleInfo.phase_marks(m).is_empty())

# --- 406 ---------------------------------------------------------------------------------

func test_phase_music_per_phase() -> void:
	assert_eq(BossRules.phase_music(0), "")
	assert_eq(BossRules.phase_music(1), "")
	assert_eq(BossRules.phase_music(2), "warden")
	assert_eq(BossRules.phase_music(3), "battle_heart")
	assert_eq(BossRules.phase_music(4), "battle_heart")
	for era: int in range(1, 6):
		var t: String = "battle_heart" if era == 1 else "battle_heart_era%d" % era
		assert_true(ResourceLoader.exists("res://audio/music/%s.ogg" % t), t)

func test_phase_events_carry_their_number() -> void:
	var m: BattleModel = _ashen()
	var boss: Spirling = m.active_spirling(BattleModel.Side.FOE)
	m._events = []
	m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.55))
	m.deal_damage(BattleModel.Side.FOE, int(boss.max_hp() * 0.25))
	var phases: Array[int] = []
	for e: BattleEvent in m._events:
		if e.type == BattleEvent.Type.BOSS_PHASE and e.data.has("phase"):
			phases.append(int(e.data.phase))
	assert_eq(phases, [2, 3] as Array[int])

# --- 415 ---------------------------------------------------------------------------------

func test_rewards_grow_with_difficulty() -> void:
	var last: float = 0.0
	for d: int in 4:
		assert_gt(BossHall.money_mult(d), last, "difficulty %d pays more" % d)
		last = BossHall.money_mult(d)
		var items: Array = BossHall.reward_items(d)
		assert_false(items.is_empty())
		for it: Variant in items:
			assert_false(Database.item(str(it[0])).is_empty(), str(it[0]))
	assert_eq(BossHall.money_mult(99), BossHall.money_mult(3), "clamped")

# --- 417, 418 ----------------------------------------------------------------------------

func test_echoes_open_after_act_one_per_mended_heart() -> void:
	var flags: Dictionary = {"cinder_heart_mended": true, "tide_heart_mended": true}
	assert_true(BossHall.open_echoes(flags).is_empty(), "not before the end of Act I")
	flags[GameState.ACT1_END_FLAG] = true
	assert_eq(BossHall.open_echoes(flags).size(), 2)
	assert_false(BossHall.rush_open(flags))
	flags["mist_heart_mended"] = true
	assert_eq(BossHall.open_echoes(flags).size(), 3)
	assert_true(BossHall.rush_open(flags))

func test_echo_entries_are_real_bosses_with_teams() -> void:
	for e: Variant in BossHall.echoes():
		var entry: Dictionary = e
		assert_true(BattleRules.BOSSES.has(str(entry.boss)), str(entry.boss))
		var team: Array[Spirling] = BossHall.team(entry, RandomNumberGenerator.new(), GameState.Difficulty.RIFT_BORN)
		assert_eq(team.size(), (entry.team as Array).size(), "no Rift-Born extra on a heart")
		var info: Dictionary = BossHall.battle_info(entry)
		assert_eq(str(info.boss), str(entry.boss))
		assert_gt(int(info.money), 0)

func test_rush_books_best_and_first_clear_once() -> void:
	var rec: Dictionary = {}
	assert_false(BossHall.note_rush(rec, 1, 3))
	assert_eq(BossHall.rush_best(rec), 1)
	assert_true(BossHall.note_rush(rec, 3, 3), "first full clear")
	assert_false(BossHall.note_rush(rec, 3, 3), "only once")
	assert_false(BossHall.note_rush(rec, 2, 3))
	assert_eq(BossHall.rush_best(rec), 3)
	assert_eq(int(rec.heart_rush.runs), 4)
	assert_eq(int(rec.heart_rush.clears), 2)
