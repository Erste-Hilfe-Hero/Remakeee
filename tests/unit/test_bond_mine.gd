extends GutTest
## "Mine!" bonding (owner, 9 Nov): one button, just tap it fast.

func _game() -> BondMinigame:
	var g := BondMinigame.new()
	g.rng = RandomNumberGenerator.new()
	g.rng.seed = 7
	g.size = Vector2(240, 160)
	add_child_autofree(g)
	return g

func test_rarer_spirlings_need_more_taps() -> void:
	var common: Dictionary = {"phases": [[0, 1, 2, 0]], "state": "none"}
	var rare: Dictionary = {"phases": [[0, 1, 2, 0, 1], [2, 1, 0, 2, 1]], "state": "none"}
	assert_eq(BondMinigame.mine_taps(common), 10)
	assert_eq(BondMinigame.mine_taps(rare), 16)
	var mended: Dictionary = {"phases": [[0, 1, 2, 0]], "state": "mended"}
	assert_eq(BondMinigame.mine_taps(mended), 8, "a mended Rift helps")

func test_ten_fast_taps_fill_the_bar() -> void:
	var g: BondMinigame = _game()
	g.run_mine({"phases": [[0, 1, 2, 0]], "state": "none"})
	for i: int in 10:
		g.mine_tap()
	assert_almost_eq(g.mine_fill, 1.0, 0.001)
	assert_eq(g._phase, BondMinigame.Phase.RESULT, "a full bar ends the tug at once")
	assert_almost_eq(g._score, 1.0, 0.001)

func test_half_the_taps_give_half_a_bar() -> void:
	var g: BondMinigame = _game()
	g.run_mine({"phases": [[0, 1, 2, 0]], "state": "none"})
	for i: int in 5:
		g.mine_tap()
	g._process(1.0)
	assert_almost_eq(g.mine_fill, 0.5, 0.001, "nothing pulls the bar back")
	g._process(BondMinigame.MINE_TIME)
	assert_eq(g._phase, BondMinigame.Phase.RESULT, "time is up")
	assert_almost_eq(g._score, 0.5, 0.001)

func test_mine_is_the_default_style() -> void:
	assert_eq(GameState.bond_style, "mine")
