extends GutTest
## Plan area 8, P2 batch: journey percent (plan 3380-3387).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

## Everything a full journey has: story, side goals, every kind bonded, every badge, every
## tower floor and every place.
func _complete_everything() -> void:
	for g: Variant in QuestLog.main_goals():
		for f: Variant in (g as Dictionary).get("done", []):
			GameState.set_flag(str(f))
	for g: Variant in QuestLog.data().get("side", []):
		GameState.set_flag(str((g as Dictionary).get("done", "")))
	for sd: SpirlingData in Database.spirlings.values():
		GameState.spirlog[sd.species_name] = {"seen": true, "bonded": true}
	var all: Dictionary = {}
	for a: Dictionary in Achievements.list():
		all[a.id] = "2026-11-06"
	GameState.records["achievements"] = all
	GameState.set_flag("gauntlet_clear")
	for t: Dictionary in RiftTower.list():
		GameState.records["rift_" + str(t.id)] = RiftTower.floors(t)
	var maps: Array = []
	for m: String in MapData.all_ids():
		maps.append(m)
	GameState.records["maps_visited"] = maps

func test_full_journey_is_exactly_100() -> void:
	_complete_everything()
	assert_eq(Completion.percent(), 100)
	assert_eq(Completion.missing_lines(), [Loc.t("Nothing left. Your journey is complete!")] as Array[String])

func test_event_only_badges_do_not_count() -> void:
	_complete_everything()
	var all: Dictionary = GameState.records.achievements
	for a: Dictionary in Achievements.list():
		if not Completion.counts(a):
			all.erase(a.id)
	assert_eq(Completion.percent(), 100, "festival and weekly echo badges are not needed")
	assert_false(Completion.counts(Achievements.find("weekly")))
	assert_false(Completion.counts(Achievements.find("festival_4")))

func test_rewards_once_and_never_taken_back() -> void:
	_complete_everything()
	var before: int = GameState.waymarks
	Completion.claim()
	var paid: int = 0
	for step: int in Completion.REWARD_STEPS:
		paid += int(Completion.REWARD_STEPS[step])
	assert_eq(GameState.waymarks - before, paid)
	assert_eq(int(GameState.records.completion), 100)
	GameState.records["achievements"] = {}
	Completion.claim()
	assert_eq(GameState.waymarks - before, paid, "a lower percent takes nothing back and pays nothing")
	assert_eq((GameState.records.completion_paid as Array).size(), 3)

func test_missing_list_and_slot_line() -> void:
	var m: Dictionary = Completion.missing()
	for k: String in Completion.WEIGHTS:
		assert_true(m.has(k), k)
		assert_lte((m[k] as Array).size(), 3, k)
	assert_false((m.towers as Array).is_empty())
	GameState.records["completion"] = 42
	assert_string_contains(SaveManager.summary_line(GameState.to_dict()), "42%")
	GameState.records["completion"] = 100
	assert_true(SaveManager.summary_line(GameState.to_dict()).begins_with(Collection.STAR))
