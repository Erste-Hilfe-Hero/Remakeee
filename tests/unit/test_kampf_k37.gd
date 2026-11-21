extends GutTest
## KAMPF_PLAN_1000 items 837 (lantern flame colours as endgame rewards, data/lantern_colors.json)
## and 855 (a friend's echo team as a team code).

var _records: Dictionary
var _flags: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_records = GameState.records.duplicate(true)
	_flags = GameState.flags.duplicate(true)
	GameState.records = {}
	GameState.flags = {}

func after_each() -> void:
	GameState.records = _records
	GameState.flags = _flags

func test_lantern_colours_are_valid_and_the_default_is_always_lit() -> void:
	var ids: Dictionary = {}
	for c: Dictionary in LanternColors.all():
		assert_false(ids.has(c.id), "unique id %s" % c.id)
		ids[c.id] = true
		assert_true(Color.html_is_valid(str(c.color)), str(c.id))
		assert_false(str(c.name).is_empty() or str(c.hint).is_empty(), str(c.id))
		assert_ne(Loc.t(str(c.name)), "", str(c.id))
	assert_gte(ids.size(), 4, "a handful of colours to earn")
	var d: Dictionary = LanternColors.by_id(str(LanternColors.data().default))
	assert_true((d.unlock as Dictionary).is_empty(), "the default needs nothing")
	assert_eq(LanternColors.unlocked().size(), 1, "a new journey has only the default")
	assert_eq(LanternColors.current_id(), str(d.id))

func test_unlock_rules() -> void:
	var c: Dictionary = {"unlock": {"record": "endless_best", "at": 20}}
	assert_false(LanternColors.is_unlocked(c, {"endless_best": 19}, {}, 0))
	assert_true(LanternColors.is_unlocked(c, {"endless_best": 20}, {}, 0))
	assert_false(LanternColors.is_unlocked({"unlock": {"flag": "gauntlet_clear"}}, {}, {}, 0))
	assert_true(LanternColors.is_unlocked({"unlock": {"flag": "gauntlet_clear"}}, {}, {"gauntlet_clear": true}, 0))
	assert_false(LanternColors.is_unlocked({"unlock": {"hall_clears": 10}}, {}, {}, 9))
	assert_true(LanternColors.is_unlocked({"unlock": {"hall_clears": 10}}, {}, {}, 10))

func test_earned_colours_can_be_chosen_locked_ones_cannot() -> void:
	assert_false(LanternColors.choose("ember_red"), "locked before the stair is climbed")
	GameState.flags["gauntlet_clear"] = true
	assert_true(LanternColors.choose("ember_red"))
	assert_eq(LanternColors.current_id(), "ember_red")
	assert_eq(LanternColors.color(), Color("e0563a"))
	GameState.flags.erase("gauntlet_clear")
	assert_eq(LanternColors.current_id(), str(LanternColors.data().default), "a lost unlock falls back to the default")

func test_a_friends_echo_team_gives_a_team_code_that_fights_in_the_halls() -> void:
	var rows: Array = [{"species": "Kindlop", "level": 30, "moves": []}, {"species": "Zippit", "level": 31, "moves": []},
		{"species": "Wickit", "level": 32, "moves": []}, {"species": "Mossling", "level": 33, "moves": []}]
	var code: String = EchoTeam.team_code(rows)
	assert_eq(code.length(), BattleHalls.CODE_LEN)
	assert_eq(BattleHalls.parse_team_code(code), ["Kindlop", "Zippit", "Wickit"] as Array[String], "the first three, in order")
	assert_eq(BattleHalls.parse_team_code(NameKeyboard.pretty(code)), ["Kindlop", "Zippit", "Wickit"] as Array[String], "the shown form parses too")
	assert_eq(EchoTeam.team_code(rows.slice(0, 2)), "", "two Spirlings are not a team code")
	assert_eq(EchoTeam.team_code([{"species": "Nobody"}, rows[0], rows[1]]), "", "unknown species are skipped")
	assert_string_contains(FriendsMoreMenu.team_code_text("Ben", code), NameKeyboard.pretty(code))

func test_the_friend_menu_offers_the_code_only_with_an_echo_team() -> void:
	assert_true("Their team code" in FriendsMoreMenu.friend_entries({"has_team": true}))
	assert_false("Their team code" in FriendsMoreMenu.friend_entries({"has_team": false}))

# --- Item 948: fair bosses -------------------------------------------------------------------

func test_bosses_stay_within_the_fair_caps() -> void:
	assert_eq(KampfChecks.boss_errors(), PackedStringArray(), "the real bosses are fair")
	var bosses: Dictionary = BattleRules.BOSSES.duplicate(true)
	var b: Dictionary = bosses["ashen_heart"]
	b.max_actions = KampfChecks.FAIR_MAX_ACTIONS + 1
	b.hp_per_ally = KampfChecks.FAIR_HP_PER_ALLY + 0.5
	b.phase.stage = {"atk": 2, "spd": 1}
	var errs: String = "\n".join(KampfChecks.boss_errors(bosses))
	for bit: String in ["max_actions above", "hp_per_ally above", "gains 3 stages"]:
		assert_string_contains(errs, bit)

func test_a_story_boss_acts_once_and_never_more_than_the_cap() -> void:
	for id: String in BattleRules.BOSSES:
		assert_eq(BattleRules.boss_actions_for(id, 5, GameState.Difficulty.STORY), 1, id)
		for d: int in 4:
			assert_lte(BattleRules.boss_actions_for(id, 5, d), KampfChecks.FAIR_MAX_ACTIONS, "%s on difficulty %d" % [id, d])
