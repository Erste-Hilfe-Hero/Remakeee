extends GutTest
## Chimora 200 list items 83 (Spirlog progress in percent per era), 103 (held keepsake icon on
## the team picture) and 137 (event Spirlings with their own badge in the Spirlog).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _first_kind_of_era(era: int) -> SpirlingData:
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		if sd.era == era:
			return sd
	return null

func test_percent_rounds_down_so_hundred_means_complete() -> void:
	assert_eq(SpirlogBook.percent(0, 0), 0)
	assert_eq(SpirlogBook.percent(1, 3), 33)
	assert_eq(SpirlogBook.percent(2, 3), 66)
	assert_eq(SpirlogBook.percent(72, 73), 98)
	assert_eq(SpirlogBook.percent(73, 73), 100)

func test_era_progress_only_lists_eras_of_open_regions() -> void:
	var rows: Array[Dictionary] = SpirlogBook.era_progress(GameState.spirlog, GameState.flags)
	assert_eq(rows.size(), 1, "a new game only has Era I kinds")
	assert_eq(int(rows[0].era), 1)
	assert_eq(int(rows[0].total), SpirlogBook.visible_kinds(GameState.flags).size())
	GameState.flags["story_complete"] = true
	rows = SpirlogBook.era_progress(GameState.spirlog, GameState.flags)
	assert_eq(rows.size(), 2, "Vellmarch opens the Era II kinds")
	assert_eq(int(rows[1].era), 2)

func test_era_progress_counts_seen_and_bonded_per_era() -> void:
	GameState.flags["story_complete"] = true
	var one: SpirlingData = _first_kind_of_era(1)
	var two: SpirlingData = _first_kind_of_era(2)
	GameState.mark_seen(one.species_name, true)
	GameState.mark_seen(two.species_name)
	var rows: Array[Dictionary] = SpirlogBook.era_progress(GameState.spirlog, GameState.flags)
	assert_eq([int(rows[0].seen), int(rows[0].bonded)], [1, 1])
	assert_eq([int(rows[1].seen), int(rows[1].bonded)], [1, 0])

func test_era_rows_show_percent_and_a_bar() -> void:
	GameState.flags["story_complete"] = true
	var rows: Array[Dictionary] = PauseMenu.spirlog_era_rows()
	assert_eq(rows.size(), 2)
	assert_eq(str(rows[0].text), "Era I: 0% seen, 0% bonded")
	assert_string_contains(str(rows[1].text), "Era II: ")
	assert_true(rows[0].decorate is Callable, "each era row draws a bar")

func test_held_mark_only_for_a_held_keepsake() -> void:
	assert_null(KeepsakeIcons.held_mark(""))
	var icons: Dictionary = KeepsakeKit.data().get("icons", {})
	var with_icon: String = str(icons.keys()[0])
	assert_eq(KeepsakeIcons.held_mark(with_icon), KeepsakeIcons.for_era(with_icon))
	assert_false(icons.has("tonic"))
	assert_not_null(KeepsakeIcons.held_mark("tonic"), "a keepsake without its own icon gets the charm shape")
