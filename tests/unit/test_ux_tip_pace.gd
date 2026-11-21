extends GutTest
## Plan items 1990 (one tip per map change) and 1991 (no tips during the prologue).

var _tips_before: bool = true

func before_each() -> void:
	_tips_before = GameState.tips_enabled
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.tips_enabled = true

func after_each() -> void:
	GameState.tips_enabled = _tips_before
	GameState.in_game = false

func test_no_tip_before_the_partner_joins() -> void:
	assert_false(Overworld.tip_allowed({}, 3, -1), "prologue: no tips")
	assert_true(Overworld.tip_allowed({"got_starter": true}, 3, -1))

func test_one_tip_per_map_change() -> void:
	var f: Dictionary = {"got_starter": true}
	assert_false(Overworld.tip_allowed(f, 4, 4), "a tip already showed on this map")
	assert_true(Overworld.tip_allowed(f, 5, 4), "the next map may show one")

func test_pending_does_not_mark_the_tip_seen() -> void:
	GameState.flags.erase(Tips.flag("wild_area"))
	assert_true(Tips.pending("wild_area"))
	assert_true(Tips.pending("wild_area"), "still pending")
	Tips.take("wild_area")
	assert_false(Tips.pending("wild_area"))

func test_a_second_tip_waits_for_the_next_map() -> void:
	GameState.set_flag("got_starter")
	GameState.flags.erase(Tips.flag("wild_area"))
	var ow := Overworld.new()
	ow.map_changes = 2
	ow._tip_change = 2
	await ow.show_tip("wild_area")
	assert_eq(ow.waiting_tips, ["wild_area"] as Array[String])
	assert_true(Tips.pending("wild_area"), "not used up while it waits")
	ow.free()

func test_a_prologue_tip_waits_too() -> void:
	GameState.flags.erase("got_starter")
	GameState.flags.erase(Tips.flag("wild_area"))
	var ow := Overworld.new()
	await ow.show_tip("wild_area")
	assert_eq(ow.waiting_tips.size(), 1)
	ow.free()
