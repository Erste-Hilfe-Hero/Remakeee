extends GutTest
## "Mine!" bonding (owner, 9 Nov): one button, tap fast, the Spirling pulls back.

func _game() -> BondMinigame:
	var g := BondMinigame.new()
	g.rng = RandomNumberGenerator.new()
	g.rng.seed = 7
	g.size = Vector2(240, 160)
	add_child_autofree(g)
	return g

func test_rarer_spirlings_pull_harder() -> void:
	var common: Dictionary = {"phases": [[0, 1, 2, 0]], "state": "none"}
	var rare: Dictionary = {"phases": [[0, 1, 2, 0, 1], [2, 1, 0, 2, 1]], "state": "none"}
	assert_lt(BondMinigame.mine_pull(common), BondMinigame.mine_pull(rare))
	var mended: Dictionary = {"phases": [[0, 1, 2, 0]], "state": "mended"}
	assert_lt(BondMinigame.mine_pull(mended), BondMinigame.mine_pull(common), "a mended Rift helps")

func test_ten_fast_taps_fill_the_bar() -> void:
	var g: BondMinigame = _game()
	g.run_mine({"phases": [[0, 1, 2, 0]], "state": "none"})
	for i: int in 10:
		g.mine_tap()
	assert_almost_eq(g.mine_fill, 1.0, 0.001)
	assert_eq(g._phase, BondMinigame.Phase.RESULT, "a full bar ends the tug at once")
	assert_almost_eq(g._score, 1.0, 0.001)

func test_bar_drains_without_taps() -> void:
	var g: BondMinigame = _game()
	g.run_mine({"phases": [[0, 1, 2, 0]], "state": "none"})
	for i: int in 5:
		g.mine_tap()
	g._process(1.0)
	assert_lt(g.mine_fill, 0.5, "the Spirling pulls back")
	g._process(BondMinigame.MINE_TIME)
	assert_eq(g._phase, BondMinigame.Phase.RESULT, "time is up")
	assert_lt(g._score, 1.0)

func test_mine_is_the_default_style() -> void:
	assert_eq(GameState.bond_style, "mine")
