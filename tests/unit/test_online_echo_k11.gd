extends GutTest
## KAMPF_PLAN_1000, area "Online-Kämpfe": echoes with held keepsakes, master AI in echo duels,
## online badges and a fairness check of the fair league and the echo duel.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _shop_keepsake() -> String:
	for id: String in Database.items:
		var it: Dictionary = Database.items[id]
		if it.get("held", null) is Dictionary and bool(it.get("shop", false)):
			return id
	return ""

func test_echo_keeps_held_keepsake_but_never_a_shop_one() -> void:
	var keep: String = Achievements.keepsakes()[0]
	GameState.party[0].held = keep
	var rows: Array = EchoTeam.snapshot(GameState.party)
	assert_eq(rows[0].get("held"), keep)
	var echo: Array[Spirling] = EchoTeam.build(rows, 60)
	assert_eq(echo[0].held, keep, "the friend's echo holds it")
	assert_eq(EchoTeam.build(rows, 60, 50)[0].held, keep, "also in a duel on the duel ring")
	var shop: String = _shop_keepsake()
	if not shop.is_empty():
		GameState.party[0].held = shop
		assert_false(EchoTeam.snapshot(GameState.party)[0].has("held"), "a bought keepsake never goes online")
		assert_eq(EchoTeam.build([{"species": "Kindlop", "level": 10, "held": shop}], 60)[0].held, "")
	assert_eq(EchoTeam.build([{"species": "Kindlop", "level": 10, "held": "nonsense"}], 60)[0].held, "")

func test_server_keeps_only_known_held_items() -> void:
	var s := LocalBackend.new()
	s.rng.seed = 1
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 12, "held": "iron_burr"}, {"species": "Puddlet", "level": 9, "held": "call me"}]})
	var team: Array = s.profile_of(s.me()).team
	assert_eq(team[0].get("held"), "iron_burr")
	assert_false(team[1].has("held"), "no free text in an echo")

func test_echo_duels_use_the_master_ai() -> void:
	assert_eq(EchoTeam.DUEL_AI, 3)

func test_online_badges_count_duels() -> void:
	EchoTeam.note_duel(GameState.records, true)
	EchoTeam.note_duel(GameState.records, false)
	assert_eq(Achievements.stat("record:echo_duels"), 2)
	assert_eq(Achievements.stat("record:echo_duel_wins"), 1)
	assert_false(Achievements.find("echo_duelist").is_empty())
	assert_false(Achievements.find("echo_victor").is_empty())

func test_fair_league_is_the_same_for_everyone() -> void:
	# Two players with the same kinds: one grinded, with sparks and a keepsake, one fresh.
	var strong: Array = [{"species": "Kindlop", "level": 60, "moves": ["Bowl Over"], "held": "iron_burr"}, {"species": "Puddlet", "level": 55, "moves": []}]
	var weak: Array = [{"species": "Kindlop", "level": 5, "moves": []}, {"species": "Puddlet", "level": 3, "moves": []}]
	var a: Dictionary = LeagueRules.build_team(strong, LeagueRules.FAIR, ["Kindlop", "Puddlet"])
	var b: Dictionary = LeagueRules.build_team(weak, LeagueRules.FAIR, ["Kindlop", "Puddlet"])
	assert_eq(a.team, b.team, "the fair league ignores levels, keepsakes and the saved moves")
	for row: Dictionary in a.team:
		assert_eq(int(row.level), LeagueRules.FAIR_RING)
		assert_false(row.has("held"))

func test_echo_duel_both_sides_on_one_ring() -> void:
	GameState.party[0].level = 7
	var mine: Array[Spirling] = EchoTeam.duel_copy(GameState.party, 50)
	var foes: Array[Spirling] = EchoTeam.build([{"species": "Puddlet", "level": 60}], Spirling.STORY_RING, 50)
	assert_eq(mine[0].level, 50)
	assert_eq(foes[0].level, 50)
	assert_eq(GameState.party[0].level, 7, "the real team is untouched")

func test_weekly_rule_is_one_valid_variant() -> void:
	var v: Array[String] = BattleHalls.variants_for(WeeklyChallenge.this_week())
	assert_eq(v.size(), 1)
	assert_eq(BattleRules.variant_conflict(v), "")

func test_echo_duel_fields_are_selectable() -> void:
	assert_eq(EchoTeam.field_names().size(), EchoTeam.DUEL_FIELDS.size())
	for f: String in EchoTeam.DUEL_FIELDS:
		assert_true(f.is_empty() or BattleRules.FIELDS.has(f), f)
	assert_eq(EchoTeam.duel_field(-1), "", "cancelled: no field")
	assert_eq(EchoTeam.duel_field(1), "ash_storm")
	assert_eq(EchoTeam.duel_field(99), "")
