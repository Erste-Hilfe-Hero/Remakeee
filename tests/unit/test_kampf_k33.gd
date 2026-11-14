extends GutTest
## docs/KAMPF_PLAN_1000.md items 437 (festival boss), 439 (badge per boss), 440 (boss replays),
## 451 (AI developer view), 462 (boss AI plays its phases), 467 (AI notes in replays).

const Side := BattleModel.Side

var _records: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_records = GameState.records
	GameState.records = {}

func after_each() -> void:
	GameState.records = _records

func _boss(moves: Array[String], ai_level: int = 2) -> BattleModel:
	var mine: Array[Spirling] = [BattleFixtures.make("Puddlet", 14, ["Fizz Pop"])]
	var boss: Array[Spirling] = [BattleFixtures.make("Smoldrake", 14, moves)]
	var m := BattleModel.new(mine, boss, false, 7, ai_level)
	m.front_size = [1, 1]
	m.foe_boss = "ashen_heart"
	m.boss_difficulty = GameState.Difficulty.TAMER
	m.start()
	return m

func _duel(seed_value: int) -> BattleModel:
	var mine: Array[Spirling] = [BattleFixtures.make("Mossling", 16, ["Lichen Lash"])]
	var foes: Array[Spirling] = [BattleFixtures.make("Kindlop", 16, ["Cinder Nip", "Kindle Up"])]
	var m := BattleModel.new(mine, foes, false, seed_value, 2)
	m.start()
	return m

func _notes(events: Array[BattleEvent]) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	for e: BattleEvent in events:
		if e.type == BattleEvent.Type.AI_NOTE:
			out.append(e)
	return out

# --- 462: boss AI phases ---------------------------------------------------------

func test_boss_phase_modes() -> void:
	var m: BattleModel = _boss(["Cinder Nip"])
	assert_eq(BossRules.ai_phase(m, Side.FOE, 0), "")
	assert_eq(BossRules.ai_phase(m, Side.PLAYER, 0), "", "only the boss slot")
	m.field = BossRules.HOLD_FIELD["ashen_heart"]
	assert_eq(BossRules.ai_phase(m, Side.FOE, 0), "held")
	m.field = ""
	m.boss_phase_done = true
	m.boss_late_done = BossRules.late_phases("ashen_heart").size()
	assert_eq(BossRules.ai_phase(m, Side.FOE, 0), "final")
	m._boss_weak_until = m.turn + 1
	assert_eq(BossRules.ai_phase(m, Side.FOE, 0), "open", "the weak point comes first")

func test_final_phase_stops_setup_and_hits_harder() -> void:
	var m: BattleModel = _boss(["Cinder Nip", "Kindle Up"])
	var ai := BattleAI.new(2)
	var hit_before: float = ai.score_move(m, Side.FOE, 0, 0, 0)
	var setup_before: float = ai.score_move(m, Side.FOE, 1, 0, 0)
	assert_gt(setup_before, 0.0, "Kindle Up is worth something early")
	m.boss_phase_done = true
	m.boss_late_done = BossRules.late_phases("ashen_heart").size()
	assert_almost_eq(ai.score_move(m, Side.FOE, 1, 0, 0), 0.0, 0.0001, "no setup in the last phase")
	assert_gt(ai.score_move(m, Side.FOE, 0, 0, 0), hit_before, "hits count more in the last phase")

func test_held_boss_wants_its_field_gone() -> void:
	var m: BattleModel = _boss(["Cinder Nip", "Ash Call"])
	var ai := BattleAI.new(2)
	m.field = "dawn_glow"
	var free: float = ai.score_move(m, Side.FOE, 1, 0, 0)
	m.field = BossRules.HOLD_FIELD["ashen_heart"]
	var held: float = ai.score_move(m, Side.FOE, 1, 0, 0)
	assert_almost_eq(held - free, float(BossRules.AI_PHASE.held.field_break), 0.0001)

# --- 451, 467: AI notes ------------------------------------------------------------

func test_explain_is_sorted_and_draws_no_random_numbers() -> void:
	var m: BattleModel = _duel(11)
	var state: int = m.rng.state
	var rows: Array[Dictionary] = m.ai.explain(m, Side.FOE, 0)
	assert_eq(m.rng.state, state)
	assert_eq(rows.size(), 2)
	assert_gte(float(rows[0].score), float(rows[1].score))
	for r: Dictionary in rows:
		assert_true(str(r.move) in ["Cinder Nip", "Kindle Up"])

func test_notes_only_when_asked() -> void:
	var m: BattleModel = _duel(11)
	assert_true(_notes(m.submit_turn(BattleAction.make_rest(Side.PLAYER))).is_empty(), "off by default")
	m.explain_ai = AiNotes.REASON
	var notes: Array[BattleEvent] = _notes(m.submit_turn(BattleAction.make_rest(Side.PLAYER)))
	assert_eq(notes.size(), 1)
	var e: BattleEvent = notes[0]
	assert_eq(int(e.data.side), Side.FOE)
	assert_true(str(e.data.kind) in ["move", "rest"])
	if str(e.data.kind) == "move":
		assert_string_contains(e.describe(), str(e.data.pick))
		assert_true(e.data.has("score"))
	assert_false(e.describe().contains("\n"), "a replay note is one line")

func test_developer_table_lists_every_scored_art() -> void:
	var m: BattleModel = _duel(11)
	m.explain_ai = AiNotes.TABLE
	var e: BattleEvent = _notes(m.submit_turn(BattleAction.make_rest(Side.PLAYER)))[0]
	assert_eq((e.data.table as Array).size(), 2)
	assert_string_contains(e.describe(), "AI tier 2")
	assert_eq(AiNotes.level_for(AiNotes.REASON), AiNotes.REASON, "no switch, no table")

func test_notes_do_not_change_the_battle() -> void:
	var plain: BattleModel = _duel(23)
	var noted: BattleModel = _duel(23)
	noted.explain_ai = AiNotes.TABLE
	for i: int in 30:
		if plain.is_finished():
			break
		plain.submit_turn(BattleAction.make_move(Side.PLAYER, 0))
		noted.submit_turn(BattleAction.make_move(Side.PLAYER, 0))
	assert_eq(noted.outcome, plain.outcome)
	assert_eq(noted.turn, plain.turn)
	assert_eq(noted.rng.state, plain.rng.state)
	assert_eq(noted.party(Side.FOE)[0].hp, plain.party(Side.FOE)[0].hp)

func test_note_lines() -> void:
	assert_eq(AiNotes.describe({"name": "Kindlop", "kind": "move", "pick": "Cinder Nip", "score": 80, "alt": "Kindle Up", "alt_score": 20}),
		"Kindlop picks Cinder Nip (80) over Kindle Up (20).")
	assert_eq(AiNotes.describe({"name": "Kindlop", "kind": "rest", "phase": "final"}),
		"Kindlop rests: nothing it can pay is worth it now. Last phase: it holds nothing back.")
	assert_eq(AiNotes.points(0.834), 83)

# --- 440: boss replays ---------------------------------------------------------------

func test_keeps_the_fastest_win_per_boss() -> void:
	var rec: Dictionary = {}
	assert_true(BossRules.keep_replay(rec, "mist_heart", 9, {"seed": 1}))
	assert_false(BossRules.keep_replay(rec, "mist_heart", 12, {"seed": 2}), "slower win is not kept")
	assert_true(BossRules.keep_replay(rec, "mist_heart", 6, {"seed": 3}))
	assert_false(BossRules.keep_replay(rec, "ashen_heart", 5, {}), "no replay, nothing kept")
	var kept: Array[Dictionary] = BossRules.replays(rec)
	assert_eq(kept.size(), 1)
	assert_eq(int(kept[0].turns), 6)
	assert_eq(int((kept[0].replay as Dictionary).seed), 3)
	assert_eq(str(kept[0].label), "Mist Heart")

func test_kept_boss_replay_plays_back() -> void:
	var m: BattleModel = _boss(["Cinder Nip"])
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "rift")
	snap["inputs"] = []
	var rec: Dictionary = {}
	BossRules.keep_replay(rec, "ashen_heart", 4, snap)
	var back: BattleModel = BattleReplay.build_model(BossRules.replays(rec)[0].replay)
	assert_not_null(back)
	assert_eq(back.foe_boss, "ashen_heart")

# --- 439: a badge per boss --------------------------------------------------------------

func test_every_boss_has_a_badge() -> void:
	for id: String in BattleRules.BOSSES:
		var a: Dictionary = Achievements.find("boss_" + id)
		assert_false(a.is_empty(), id)
		assert_eq(str(a.stat), "boss_wins:" + id)
		assert_true(Achievements.known_stat(str(a.stat)))
		assert_false(Achievements.earned("boss_" + id))
	BossRules.note_win(GameState.records, "drowned_heart", 7)
	assert_eq(Achievements.stat("boss_wins:drowned_heart"), 1)
	assert_true(Achievements.earned("boss_drowned_heart"))
	assert_false(Achievements.earned("boss_mist_heart"))

# --- 437: festival boss -----------------------------------------------------------------

func test_every_festival_has_an_echo() -> void:
	for f: Dictionary in Season.festivals():
		var e: Dictionary = FestivalBoss.entry(str(f.id))
		assert_false(e.is_empty(), str(f.id))
		assert_true(BattleRules.BOSSES.has(str(e.boss)), str(f.id))
		assert_true(Database.spirlings.has(str(e.species)), str(f.id))
		var team: Array[Spirling] = FestivalBoss.team(str(f.id), 30, RandomNumberGenerator.new())
		assert_eq(team.size(), 1)
		assert_eq(team[0].level, 32)

func test_festival_echo_needs_a_beaten_heart_and_pays_once() -> void:
	var rec: Dictionary = {}
	assert_false(FestivalBoss.unlocked("hearth_weeks", rec))
	BossRules.note_win(rec, "ashen_heart", 10)
	assert_true(FestivalBoss.unlocked("hearth_weeks", rec))
	assert_false(FestivalBoss.unlocked("tide_days", rec), "another heart")
	assert_true(FestivalBoss.note_win("hearth_weeks_2026", rec))
	assert_true(FestivalBoss.won("hearth_weeks_2026", rec))
	assert_false(FestivalBoss.note_win("hearth_weeks_2026", rec), "paid once per festival year")
	assert_false(FestivalBoss.won("hearth_weeks_2027", rec))

func test_echo_ring_is_clamped() -> void:
	assert_eq(FestivalBoss.ring_for(5), int(FestivalBoss.data().ring_min))
	assert_eq(FestivalBoss.ring_for(40), 40 + int(FestivalBoss.data().ring_over))
	assert_eq(FestivalBoss.ring_for(Spirling.STORY_RING), Spirling.STORY_RING)
