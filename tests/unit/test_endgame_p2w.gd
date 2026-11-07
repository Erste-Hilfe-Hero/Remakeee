extends GutTest
## Plan area 8, P2 batch: no shop hints beside endgame rewards for anyone (3502), the break
## reminder (3503) and progress bars that always carry numbers (3534).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	PlayReminder.reset()
	GameState.play_reminder = true

func after_each() -> void:
	PlayReminder.reset()
	GameState.play_reminder = true
	GameState.high_contrast = false

func _endgame_text() -> String:
	var parts: Array[String] = []
	for tab: String in ["Today", "Week", "Collection", "Season path"]:
		parts.append(Goals.tab_text(tab))
	parts.append_array(Waymarks.history_lines(20))
	parts.append_array(RiftTower.card_lines())
	parts.append_array(Completion.missing_lines())
	return "\n".join(parts)

func test_no_shop_offer_next_to_waymarks() -> void:
	GameState.rifts_sealed.append("cinder")
	GameState.set_flag(GameState.ACT1_END_FLAG)
	Waymarks.earn(50, "daily_task")
	var text: String = _endgame_text().to_lower()
	assert_false(text.contains("riftglass"), "no premium currency beside Waymarks")
	for o: Dictionary in ShopCatalog.offers():
		var nm: String = str(o.get("name", "")).to_lower()
		if nm.length() >= 6:
			assert_false(text.contains(nm), nm)

func test_break_reminder_once_after_90_minutes() -> void:
	assert_eq(PlayReminder.tick(60.0 * 89), "")
	var note: String = PlayReminder.tick(60.0)
	assert_string_contains(note, "90")
	assert_eq(PlayReminder.tick(3600.0), "", "only once a session")

func test_break_reminder_can_be_switched_off() -> void:
	GameState.play_reminder = false
	assert_eq(PlayReminder.tick(60.0 * 200), "")
	var keys: Array = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_has(keys, "play_reminder")
	assert_false(bool(GameState.settings_to_dict().play_reminder))
	GameState.settings_from_dict({"play_reminder": true})
	assert_true(GameState.play_reminder)

func test_bars_carry_numbers_in_high_contrast() -> void:
	GameState.high_contrast = true
	var digits := RegEx.create_from_string("\\d+\\s*/\\s*\\d+|\\d+ more")
	var bar := RegEx.create_from_string("\\[[#-]+\\]")
	var lines: Array[String] = SeasonPath.goal_lines()
	GameState.rifts_sealed.append("cinder")
	Exchange.set_goal(str(Exchange.offers()[0].item))
	lines.append(Exchange.goal_line())
	var bars: int = 0
	for l: String in lines:
		if bar.search(l) != null:
			bars += 1
			assert_not_null(digits.search(l), l)
	assert_gt(bars, 1, "both bars were checked")
