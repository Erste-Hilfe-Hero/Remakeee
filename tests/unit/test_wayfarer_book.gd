extends GutTest
## KAMPF_PLAN_1000 items 496, 507, 529, 530, 542: the Wayfarer book (local ranking, lantern post),
## the run timer and the optional foe scaling.

const BRAM: Dictionary = {"id": "bram", "trainer": "Ridgewalker Bram", "team": [{"species": "Shalebat", "level": 7}]}
const ISA: Dictionary = {"id": "isa", "trainer": "Isa", "team": [{"species": "Zephlet", "level": 9}], "warden": "x"}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _spirling(species: String, ring: int) -> Spirling:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return Spirling.new(Database.species(species), ring, rng)

func test_book_counts_wins_losses_and_best_turns() -> void:
	WayfarerBook.note(BRAM, "crowcrest", false, 9)
	WayfarerBook.note(BRAM, "crowcrest", true, 8)
	WayfarerBook.note(BRAM, "crowcrest", true, 5)
	WayfarerBook.note(BRAM, "crowcrest", true, 7)
	var e: Dictionary = WayfarerBook.entries()[0]
	assert_eq(int(e.wins), 3)
	assert_eq(int(e.losses), 1)
	assert_eq(int(e.best_turns), 5)
	assert_eq(str(e.name), "Ridgewalker Bram")
	assert_false((e.def as Dictionary).has("trainer"), "only the rematch keys are kept")

func test_wild_hordes_are_not_booked() -> void:
	WayfarerBook.note({"id": "swarm", "wild": true, "team": [{"species": "Shalebat"}]}, "murk", true, 3)
	WayfarerBook.note({"id": "sign"}, "murk", true, 3)
	assert_true(WayfarerBook.entries().is_empty())

func test_rankings() -> void:
	WayfarerBook.note(BRAM, "crowcrest", true, 4)
	WayfarerBook.note(ISA, "steps", false, 6)
	WayfarerBook.note(ISA, "steps", false, 6)
	WayfarerBook.note(ISA, "steps", true, 6)
	assert_eq(str(WayfarerBook.most_battled()[0].name), "Isa")
	assert_eq(WayfarerBook.toughest().size(), 1, "only Wayfarers you lost to")
	var page: String = WayfarerBook.page("2026-11-13")
	assert_string_contains(page, "Isa")
	assert_string_contains(page, "Ridgewalker Bram")

func test_lantern_post_lists_open_rematches() -> void:
	WayfarerBook.note(BRAM, "crowcrest", true, 4)
	assert_true(WayfarerBook.invitations("2026-11-13").is_empty(), "not beaten in the world yet")
	GameState.set_flag(TrainerData.beaten_flag(BRAM, "crowcrest"))
	assert_eq(WayfarerBook.invitations("2026-11-13"), ["Ridgewalker Bram"] as Array[String])
	GameState.records["rematch"] = {TrainerData.beaten_flag(BRAM, "crowcrest"): "2026-11-13"}
	assert_true(WayfarerBook.invitations("2026-11-13").is_empty(), "today's rematch is used")
	assert_string_contains(WayfarerBook.lantern_line("2026-11-14"), "Ridgewalker Bram")

func test_run_timer() -> void:
	assert_eq(RunTimer.format(3725.0), "1:02:05")
	assert_false(RunTimer.is_on())
	RunTimer.toggle()
	assert_true(RunTimer.is_on())
	var t := RunTimer.new()
	add_child_autofree(t)
	GameState.play_time = 61.0
	t._process(0.0)
	assert_true(t.visible)
	assert_eq(t.text, "0:01:01")

func test_foe_scaling_lifts_low_foes_within_the_cap() -> void:
	var party: Array[Spirling] = [_spirling("Kindlop", 30)]
	var foes: Array[Spirling] = [_spirling("Shalebat", 5), _spirling("Puddlet", 40)]
	ChallengeRules.scale_foes(foes, party)
	assert_eq(foes[0].level, 5, "off: no change")
	ChallengeRules.toggle_scaling()
	ChallengeRules.scale_foes(foes, party)
	var cap: int = mini(30 - ChallengeRules.SCALING_GAP, GameState.progress_cap() + GameState.FOE_OVER_CAP)
	assert_eq(foes[0].level, cap)
	assert_eq(foes[0].hp, foes[0].max_hp())
	assert_eq(foes[1].level, 40, "never lowered")
