extends GutTest
## Battle UI per era: type badges, command colour code, matchup feedback, colour-blind mode.

func test_badges_ink_in_era_one_colour_later() -> void:
	for el: int in [0, 1, 2]:
		assert_eq(BattleUiStyle.badge_color(1, el), UITheme.INK)
		assert_eq(BattleUiStyle.badge_color(2, el), Elements.color(el))

func test_command_stripes_from_era_two() -> void:
	assert_eq(BattleUiStyle.command_color(1, "item"), Color.TRANSPARENT)
	var seen: Array[Color] = []
	for c: String in ["move", "swap", "item", "bond", "run"]:
		var col: Color = BattleUiStyle.command_color(3, c)
		assert_ne(col, Color.TRANSPARENT, c)
		assert_false(col in seen, c)
		seen.append(col)

func test_matchup_kinds() -> void:
	assert_eq(BattleUiStyle.matchup(2.0), "strong")
	assert_eq(BattleUiStyle.matchup(0.5), "weak")
	assert_eq(BattleUiStyle.matchup(0.0), "none")
	assert_eq(BattleUiStyle.matchup(1.0), "")
	assert_eq(BattleUiStyle.matchup(-1.0), "")

func test_matchup_colour_only_from_era_two() -> void:
	assert_eq(BattleUiStyle.matchup_color(1, 2.0), UITheme.INK)
	assert_ne(BattleUiStyle.matchup_color(2, 2.0), BattleUiStyle.matchup_color(2, 0.5))
	assert_eq(BattleUiStyle.matchup_color(2, 1.0), UITheme.INK)

func test_colour_blind_adds_shape_marks() -> void:
	assert_eq(BattleUiStyle.matchup_mark(2.0, false), "")
	var strong: String = BattleUiStyle.matchup_mark(2.0, true)
	var weak: String = BattleUiStyle.matchup_mark(0.5, true)
	assert_false(strong.is_empty())
	assert_ne(strong, weak)
	assert_eq(BattleUiStyle.matchup_mark(1.0, true), "")

func test_colour_blind_forces_hp_pattern() -> void:
	assert_false(BattleUiStyle.hp_pattern(3, false))
	assert_true(BattleUiStyle.hp_pattern(3, true))
	assert_true(BattleUiStyle.hp_pattern(1, false))

func test_setting_saved() -> void:
	var was: bool = GameState.color_blind
	GameState.color_blind = true
	var keys: Array = []
	for r: Array in MenuHost.display_rows():
		keys.append(r[0])
	assert_has(keys, "color_blind")
	GameState.color_blind = was
