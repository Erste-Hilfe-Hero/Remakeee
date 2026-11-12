extends GutTest
## Ring cap past 60 for the later eras (data/eras.json "ring_caps"): Halcyra (Era IV) has rings
## 78 to 96, so Spirling.ERA_MAX_LEVEL is 96 and GameState.ring_ceiling() opens it era by era.
## Until Era III opens, everything stays at Spirling.MAX_LEVEL (60).

var _flags: Dictionary
var _difficulty: int

func before_each() -> void:
	_flags = GameState.flags
	_difficulty = GameState.difficulty
	GameState.flags = {}

func after_each() -> void:
	GameState.flags = _flags
	GameState.difficulty = _difficulty as GameState.Difficulty

func _caps() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://data/eras.json")) as Dictionary).ring_caps

func test_ceiling_opens_era_by_era() -> void:
	assert_eq(GameState.ring_ceiling_for({}), Spirling.MAX_LEVEL)
	assert_eq(GameState.ring_ceiling_for({"story_complete": true}), Spirling.MAX_LEVEL, "Era II stays at 60")
	var era3: Dictionary = {"story_complete": true, "era2_finale_done": true}
	assert_eq(GameState.ring_ceiling_for(era3), int(_caps()["3"]))
	era3["era3_finale_done"] = true
	assert_eq(GameState.ring_ceiling_for(era3), Spirling.ERA_MAX_LEVEL, "Halcyra opens the top ring")
	era3["era4_finale_done"] = true
	assert_eq(GameState.ring_ceiling_for(era3), int(_caps()["5"]), "Quivermoor (Era V) keeps the top ring")
	assert_eq(GameState.ring_ceiling_for({"era3_finale_done": true}), Spirling.MAX_LEVEL, "eras open in order")

func test_caps_rise_and_end_at_the_era_max() -> void:
	var caps: Dictionary = _caps()
	var last: int = Spirling.MAX_LEVEL
	for e: int in range(2, Spirling.MAX_ERA + 1):
		assert_gte(int(caps[str(e)]), last, "era %d" % e)
		last = int(caps[str(e)])
	assert_eq(last, Spirling.ERA_MAX_LEVEL)
	assert_ne(Spirling.ERA_MAX_LEVEL, 100, "own numbers (test_originality)")

func test_halcyra_rings_fit_its_cap() -> void:
	var src: String = FileAccess.get_file_as_string("res://data/region4.json")
	var top: int = 0
	var rx := RegEx.create_from_string("\"ring\": *\\[?\\s*(\\d+)(?:,\\s*(\\d+))?")
	for m: RegExMatch in rx.search_all(src):
		top = maxi(top, int(m.get_string(2)) if not m.get_string(2).is_empty() else int(m.get_string(1)))
	assert_gt(top, Spirling.MAX_LEVEL)
	assert_lte(top, int(_caps()["4"]))

func test_spirlings_keep_rings_past_sixty() -> void:
	var s: Spirling = BattleFixtures.make("Mossling", 90)
	assert_eq(s.level, 90, "a Halcyra foe is not clamped to 60")
	assert_eq(BattleFixtures.make("Mossling", 500).level, Spirling.ERA_MAX_LEVEL)
	var d: Dictionary = s.to_dict()
	assert_eq(Spirling.from_dict(d).level, 90)
	assert_gt(s.max_hp(), BattleFixtures.make("Mossling", 60).max_hp())

func test_xp_curve_keeps_rising_past_sixty() -> void:
	var step: int = 0
	for lvl: int in range(2, Spirling.ERA_MAX_LEVEL + 1):
		var d: int = Spirling.xp_for_level(lvl) - Spirling.xp_for_level(lvl - 1)
		assert_gt(d, step, "ring %d costs more than the one before" % lvl)
		step = d

func test_level_cap_follows_the_ceiling() -> void:
	GameState.difficulty = GameState.Difficulty.TAMER
	assert_eq(GameState.level_cap(), Spirling.MAX_LEVEL)
	GameState.flags = {"story_complete": true, "era2_finale_done": true, "era3_finale_done": true}
	assert_eq(GameState.level_cap(), Spirling.ERA_MAX_LEVEL)
