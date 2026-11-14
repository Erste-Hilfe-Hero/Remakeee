extends GutTest
## KAMPF_PLAN_1000 items 15, 22, 24, 27, 28, 29: initiative from behind, Soft Defeat on Story,
## the battle pause, the bench marks of the team rows and the short opening line at 2x / 4x.

const Side := BattleModel.Side
const T := BattleEvent.Type

var _flags: Dictionary
var _difficulty: int

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_difficulty = GameState.difficulty

func after_each() -> void:
	GameState.flags = _flags
	GameState.difficulty = _difficulty

func _mk(species: String, level: int = 15) -> Spirling:
	return BattleFixtures.make(species, level, ["Cinder Nip"] as Array[String])

func _first(ev: Array[BattleEvent], t: T) -> BattleEvent:
	for e: BattleEvent in ev:
		if e.type == t:
			return e
	return null

# --- 15 -------------------------------------------------------------------------------------------

func test_behind_means_the_cell_the_wayfarer_turns_its_back_on() -> void:
	var npc := Vector2i(5, 5)
	assert_true(BattleOpening.from_behind(npc, Vector2i.DOWN, Vector2i(5, 4)), "looks down, player above")
	assert_false(BattleOpening.from_behind(npc, Vector2i.DOWN, Vector2i(5, 6)), "face to face")
	assert_false(BattleOpening.from_behind(npc, Vector2i.DOWN, Vector2i(4, 5)), "from the side")
	assert_true(BattleOpening.from_behind(npc, Vector2i.LEFT, Vector2i(6, 5)))
	assert_false(BattleOpening.from_behind(npc, Vector2i.ZERO, Vector2i(5, 4)))

func test_wardens_and_bosses_are_never_caught() -> void:
	assert_true(BattleOpening.may_catch({"trainer": "Wayfarer Ilse"}))
	assert_false(BattleOpening.may_catch({"trainer": "Warden", "warden": 1}))
	assert_false(BattleOpening.may_catch({"trainer": "Rift thing", "boss": "rift_maw"}))

func test_initiative_lets_the_slower_player_act_first_once() -> void:
	# Mossling is far slower than Zippit; only the initiative puts it first.
	var m := BattleModel.new([_mk("Mossling")] as Array[Spirling], [_mk("Zippit")] as Array[Spirling], false, 3, 0)
	m.trainer_name = "Wayfarer Ilse"
	m.initiative = true
	var line: BattleEvent = _first(m.start(), T.TECHNIQUE)
	assert_not_null(line)
	assert_eq(line.describe(), "You caught Wayfarer Ilse from behind! Your side moves first.")
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0))
	assert_eq(int(_first(ev, T.MOVE_USED).data.side), Side.PLAYER)
	if not m.is_finished():
		ev = m.submit_turn(BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_move(Side.FOE, 0))
		assert_eq(int(_first(ev, T.MOVE_USED).data.side), Side.FOE, "only the first turn")

func test_no_initiative_in_wild_battles_and_it_survives_a_replay() -> void:
	var m := BattleModel.new([_mk("Mossling")] as Array[Spirling], [_mk("Zippit")] as Array[Spirling], true, 3, 0)
	m.initiative = true
	assert_null(_first(m.start(), T.TECHNIQUE))
	assert_false(BattleOpening.player_first(m, Side.PLAYER))
	var d := BattleModel.new([_mk("Mossling")] as Array[Spirling], [_mk("Zippit")] as Array[Spirling], false, 3, 0)
	d.initiative = true
	assert_true(BattleReplay.snapshot(d, "", "").get("initiative", false))

# --- 22 -------------------------------------------------------------------------------------------

func test_soft_defeat_is_a_story_option_and_off_by_default() -> void:
	GameState.flags.erase(SoftDefeat.FLAG)
	assert_false(SoftDefeat.is_on())
	assert_false(SoftDefeat.applies(GameState.Difficulty.STORY, false))
	assert_true(SoftDefeat.applies(GameState.Difficulty.STORY, true))
	for d: int in [GameState.Difficulty.TAMER, GameState.Difficulty.VETERAN, GameState.Difficulty.RIFT_BORN]:
		assert_false(SoftDefeat.applies(d, true))
	SoftDefeat.set_on(true)
	assert_true(SoftDefeat.is_on())

func test_soft_defeat_wakes_the_team_with_half_its_vigor() -> void:
	assert_almost_eq(SoftDefeat.share(), 0.5, 0.0001, "data/battle_flow.json")
	var a := _mk("Kindlop", 20)
	var b := _mk("Puddlet", 20)
	a.hp = 0
	b.hp = 3
	b.status = "scorch"
	SoftDefeat.wake([a, b])
	assert_eq(a.hp, ceili(a.max_hp() * 0.5))
	assert_eq(b.hp, ceili(b.max_hp() * 0.5))
	assert_eq(b.status, "")
	assert_false(a.is_fainted())

func test_soft_defeat_row_shows_only_on_story() -> void:
	var was: bool = GameState.in_game
	GameState.in_game = true
	GameState.difficulty = GameState.Difficulty.STORY
	var keys: Array = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_has(keys, "soft_defeat")
	GameState.difficulty = GameState.Difficulty.VETERAN
	keys = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_does_not_have(keys, "soft_defeat")
	GameState.in_game = was

# --- 24 -------------------------------------------------------------------------------------------

func test_pause_list_starts_with_resume_and_holds_the_settings() -> void:
	var pause: Array[String] = BattleComfort.more_pages(BattleComfort.PAUSE_TITLE)
	assert_eq(pause[0], "Resume")
	assert_has(pause, "Settings")
	assert_does_not_have(BattleComfort.more_pages("More"), "Resume", "the Log's More list has no Resume")

func test_pause_halts_auto_and_only_opens_mid_battle() -> void:
	assert_true(BattleComfort.runs(false, false))
	assert_false(BattleComfort.runs(false, true), "paused")
	assert_false(BattleComfort.runs(true, false), "app in the background")
	assert_true(BattleComfort.may_pause(false, false))
	assert_false(BattleComfort.may_pause(true, false), "battle over")
	assert_false(BattleComfort.may_pause(false, true), "another list is open")

func test_start_or_escape_opens_the_pause_in_battle() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/BattleScene.gd")
	assert_string_contains(src, "event.is_action_pressed(GameState.MENU_ACTION)")
	assert_string_contains(src, "_more_menu(BattleComfort.PAUSE_TITLE)")
	assert_string_contains(src, "while _paused and is_inside_tree():")

# --- 27, 28 ---------------------------------------------------------------------------------------

func test_team_rows_count_the_bench_that_still_comes() -> void:
	var mine: Array[Spirling] = [_mk("Kindlop"), _mk("Puddlet"), _mk("Mossling")]
	var theirs: Array[Spirling] = [_mk("Zippit"), _mk("Mossling")]
	var m := BattleFixtures.model(mine, theirs, false)
	assert_eq(BattleHud.fielded(m, Side.PLAYER), [0])
	assert_eq(BattleHud.fielded(m, Side.FOE), [0])
	mine[2].hp = 0
	for pair: Array in [[mine, Side.PLAYER, 1], [theirs, Side.FOE, 1]]:
		var row := TeamRow.new()
		add_child_autofree(row)
		row.set_party(pair[0], BattleHud.fielded(m, int(pair[1])))
		assert_eq(row.bench(), int(pair[2]))
		assert_true(bool(row.marks[0].field))
		assert_false(bool(row.marks[1].field))
		assert_string_contains(row.screen_reader_text(), "%d still to come" % int(pair[2]))

# --- 29 -------------------------------------------------------------------------------------------

func test_opening_line_is_short_at_2x_and_4x() -> void:
	var wild := BattleEvent.new(T.BATTLE_START, {"wild": true, "foe_name": "Mossling", "count": 1})
	assert_eq(BattleOpening.start_line(wild, 1.0), wild.describe())
	assert_eq(BattleOpening.start_line(wild, 2.0), "A hushed Mossling!")
	assert_lt(BattleOpening.start_line(wild, 4.0).length(), wild.describe().length())
	var duel := BattleEvent.new(T.BATTLE_START, {"wild": false, "trainer": "Wayfarer Ilse", "count": 1})
	assert_eq(BattleOpening.start_line(duel, 4.0), "Duel with Wayfarer Ilse!")
	assert_eq(Dialogue.split_speaker(BattleOpening.start_line(duel, 4.0))[0], "", "no name tag")
	var boss := BattleEvent.new(T.BATTLE_START, {"wild": false, "boss": true, "trainer": "The Maw", "count": 1})
	assert_eq(BattleOpening.start_line(boss, 2.0), "The Maw rises!")
	var swarm := BattleEvent.new(T.BATTLE_START, {"wild": true, "count": 3})
	assert_eq(BattleOpening.start_line(swarm, 2.0), "A swarm of 3!")

func test_odd_colours_keep_the_full_line() -> void:
	var gleam := BattleEvent.new(T.BATTLE_START, {"wild": true, "foe_name": "Mossling", "count": 1, "gleam": true})
	assert_eq(BattleOpening.start_line(gleam, 4.0), gleam.describe())
