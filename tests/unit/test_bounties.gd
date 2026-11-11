extends GutTest
## Daily bounty fights (item 1117) and the certificate (item 1120).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_board_is_stable_and_valid() -> void:
	var a: Array[Dictionary] = Bounties.board("2026-11-11", 20)
	assert_eq(a, Bounties.board("2026-11-11", 20))
	assert_eq(a.size(), int(Bounties.data().per_day))
	var ids: Dictionary = {}
	for m: Dictionary in a:
		ids[m.id] = true
		assert_gt(int(m.price), 0)
		for s: Variant in m.team:
			assert_true(Database.spirlings.has(str(s)), "unknown species %s" % s)
	assert_eq(ids.size(), a.size(), "no mark twice on one board")

func test_boards_vary_and_tips_happen() -> void:
	var boards: Dictionary = {}
	var tipped: int = 0
	for d: int in range(1, 29):
		var b: Array[Dictionary] = Bounties.board("2026-02-%02d" % d, 20)
		boards[str(b)] = true
		for m: Dictionary in b:
			if m.tipped:
				tipped += 1
				assert_eq(int(m.ring), 20 + int(Bounties.data().ring_offset[b.find(m)]) + int(Bounties.data().tip_ring_bonus))
	assert_gt(boards.size(), 4)
	assert_gt(tipped, 0, "the snitch should strike sometimes")

func test_claim_once_with_fixer_cut() -> void:
	var day: String = "2026-11-11"
	var m: Dictionary = Bounties.board(day, 20)[0]
	var before: int = GameState.money
	var paid: int = Bounties.claim(day, 20, str(m.id))
	assert_eq(paid, Bounties.payout(int(m.price)))
	assert_lt(paid, int(m.price))
	assert_eq(GameState.money, before + paid)
	assert_eq(Bounties.claim(day, 20, str(m.id)), 0)
	assert_eq(Bounties.claim(day, 20, "nobody"), 0)
	assert_eq(Bounties.claimed("2026-11-12"), [])

func test_certificate_only_at_100() -> void:
	assert_eq(Bounties.certificate(99, "Tess"), [] as Array[String])
	var c: Array[String] = Bounties.certificate(100, "Tess")
	assert_gt(c.size(), 2)
	assert_true(bool(GameState.records.get(Bounties.CERT, false)))

func test_board_line() -> void:
	var m: Dictionary = {"name": "Velvet Tam", "ring": 22, "price": 600, "tipped": true}
	assert_string_contains(Bounties.line(m), "Velvet Tam")
	assert_string_contains(Bounties.line(m), "tipped off")
