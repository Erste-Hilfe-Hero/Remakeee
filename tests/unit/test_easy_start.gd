extends GutTest
## Easier start (Ali, 7 Nov): 20 free Kin Charms, a step-by-step bonding tutorial,
## newcomer bond grace and the EXP bar on the player's battle strip.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_new_game_starts_with_twenty_kin_charms() -> void:
	assert_eq(GameState.START_KIN_CHARMS, 20)
	assert_eq(int(GameState.inventory.get("kin_charm", 0)), 20)
	assert_true(Database.item("kin_charm").has("bond_bonus"))

func test_bond_tutorial_walks_through_every_step() -> void:
	# Steps 1-2 at the start of the first wild battle, 3-4 when Bond is first picked.
	var lines: Array[String] = Tips.lines_of("bond", true) + Tips.lines_of("bond_mine", true)
	var all: String = "\n".join(lines)
	for step: int in [1, 2, 3, 4]:
		assert_string_contains(all, "Bonding step %d" % step)
	assert_string_contains(all, "Tap Mine!")
	assert_string_contains(all, "20")
	assert_string_contains("\n".join(Tips.lines_of("bond_mine", false)), "Press A as fast")

func test_newcomer_until_six_spirlings() -> void:
	assert_true(GameState.is_newcomer())
	for i: int in GameState.NEWCOMER_SPIRLINGS:
		GameState.receive_spirling(BattleFixtures.make("Mossling", 5))
	assert_false(GameState.is_newcomer())

func test_xp_fraction_runs_from_ring_to_next_ring() -> void:
	var s: Spirling = BattleFixtures.make("Mossling", 10)
	s.xp = Spirling.xp_for_level(10)
	assert_almost_eq(InfoStrip.xp_fraction(s), 0.0, 0.001)
	var lo: int = Spirling.xp_for_level(10)
	var hi: int = Spirling.xp_for_level(11)
	s.xp = lo + (hi - lo) / 2
	assert_almost_eq(InfoStrip.xp_fraction(s), 0.5, 0.05)
	s.level = 150
	s.xp = Spirling.xp_for_level(150) + (Spirling.xp_for_level(151) - Spirling.xp_for_level(150)) / 2
	assert_almost_eq(InfoStrip.xp_fraction(s), 0.5, 0.05, "no full bar at an old cap")

func test_player_strip_tracks_xp_and_reads_it_out() -> void:
	var strip := InfoStrip.new()
	strip.show_xp = true
	var s: Spirling = BattleFixtures.make("Mossling", 10)
	s.xp = Spirling.xp_for_level(10)
	strip.set_spirling(s)
	assert_eq(strip.xp_left, s.xp_to_next())
	s.xp += 5
	strip.set_xp(s)
	assert_eq(strip.xp_left, s.xp_to_next())
	assert_string_contains(strip.screen_reader_text(), "%d" % s.xp_to_next())
	strip.free()
