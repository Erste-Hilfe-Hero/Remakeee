extends GutTest
## Plan area 8, P2 batch: loan-team weeks of the weekly echo (plan 3192-3194).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_twelve_valid_loan_teams() -> void:
	var teams: Array[Dictionary] = WeeklyChallenge.loan_teams()
	assert_gte(teams.size(), 12)
	var ids: Dictionary = {}
	for t: Dictionary in teams:
		assert_false(ids.has(t.id), "unique id %s" % t.id)
		ids[t.id] = true
		assert_eq((t.team as Array).size(), WeeklyChallenge.TEAM_SIZE)
		for e: Dictionary in t.team:
			var sd: SpirlingData = Database.species(str(e.species))
			assert_not_null(sd, str(e.species))
			if sd == null:
				continue
			assert_lte(BalanceSim.min_level(sd), int(t.ring), "%s exists at ring %d" % [e.species, t.ring])
			assert_between((e.moves as Array).size(), 1, 4)
			for m: Variant in e.moves:
				assert_not_null(Database.move(str(m)), str(m))

func test_every_second_week_is_a_loan_week() -> void:
	assert_true(WeeklyChallenge.is_loan_week("2026-W45"))
	assert_false(WeeklyChallenge.is_loan_week("2026-W46"))
	var ch := WeeklyChallenge.new("2026-W45", 12)
	assert_false(ch.loan.is_empty())
	assert_eq(ch.level, int(ch.loan.ring), "echoes match the loan ring")
	assert_eq(ch.loan, WeeklyChallenge.new("2026-W45", 50).loan, "same loan team for everyone")
	assert_string_contains(ch.preview_text(), "Loan-team week")
	var normal := WeeklyChallenge.new("2026-W46", 12)
	assert_true(normal.loan.is_empty())
	assert_string_contains(normal.preview_text(), "Next week everyone gets the same loan team")

func test_loan_party_is_fixed_and_fresh() -> void:
	var ch := WeeklyChallenge.new("2026-W45", 12)
	var p: Array[Spirling] = ch.loan_party()
	assert_eq(p.size(), WeeklyChallenge.TEAM_SIZE)
	for i: int in p.size():
		var e: Dictionary = ch.loan.team[i]
		assert_eq(p[i].data.species_name, str(e.species))
		assert_eq(p[i].level, int(ch.loan.ring))
		assert_eq(p[i].moves.map(func(m: MoveData) -> String: return m.move_name), e.moves)
		assert_eq(p[i].hp, p[i].max_hp())

func test_save_keeps_the_own_team_while_on_loan() -> void:
	var own: String = GameState.party[0].data.species_name
	GameState.party_on_loan = GameState.party
	GameState.party = WeeklyChallenge.new("2026-W45", 12).loan_party()
	var d: Dictionary = GameState.to_dict()
	assert_eq((d.party as Array).size(), 1)
	assert_eq(str(d.party[0].species), own, "a save during the run never stores the loan team")
	GameState.reset()
	assert_true(GameState.party_on_loan.is_empty())
