extends GutTest
## Plan area 8, P2 batch: Rift towers Cinder Stair and Tide Shaft (plan 3266-3271, 3275).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_two_towers_open_after_their_rift() -> void:
	assert_eq(RiftTower.list().size(), 2)
	var cinder: Dictionary = RiftTower.find("cinder_stair")
	var tide: Dictionary = RiftTower.find("tide_shaft")
	assert_eq(RiftTower.floors(cinder), 15)
	assert_eq(RiftTower.floors(tide), 15)
	assert_false(RiftTower.is_open(cinder))
	GameState.set_flag("rift_cinder_sealed")
	assert_true(RiftTower.is_open(cinder))
	assert_false(RiftTower.is_open(tide))

func test_echoes_only_of_the_tower_elements() -> void:
	for t: Dictionary in RiftTower.list():
		var els: Array[int] = RiftTower.elements_of(t)
		assert_eq(els.size(), 3)
		var run := RiftTower.new(t, 42)
		for f: int in RiftTower.floors(t):
			var team: Array[Spirling] = run.team(f)
			assert_eq(team.size(), RiftTower.ECHO_TEAM, "%s floor %d" % [t.id, f])
			for s: Spirling in team:
				assert_true(s.data.elements.any(func(e: int) -> bool: return e in els), s.data.species_name)
				assert_eq(s.level, RiftTower.level_for(f))
		assert_eq(run.team(3).map(func(s: Spirling) -> String: return s.data.species_name),
			RiftTower.new(t, 42).team(3).map(func(s: Spirling) -> String: return s.data.species_name), "same seed, same echoes")

func test_ring_30_and_three_at_most() -> void:
	assert_eq(RiftTower.MAX_TEAM, 3)
	assert_true(RiftTower.eligible(GameState.party).is_empty(), "a new team is below ring 30")
	GameState.party[0].level = RiftTower.MIN_RING
	assert_eq(RiftTower.eligible(GameState.party).size(), 1)
	var text: String = RiftTower.entrance_text(RiftTower.find("cinder_stair"))
	assert_string_contains(text, str(RiftTower.MIN_RING))

func test_tide_shaft_counts_down_and_darkens() -> void:
	var tide: Dictionary = RiftTower.find("tide_shaft")
	assert_eq(RiftTower.floor_label(tide, 0), Loc.t("Depth %d of %d") % [15, 15])
	assert_eq(RiftTower.floor_label(RiftTower.find("cinder_stair"), 0), Loc.t("Floor %d of %d") % [1, 15])
	assert_eq(RiftTower.shade(tide, 0), 0.0)
	assert_gt(RiftTower.shade(tide, 10), RiftTower.shade(tide, 5))
	assert_eq(RiftTower.shade(RiftTower.find("cinder_stair"), 10), 0.0)

func test_waymarks_once_per_floor_and_badges() -> void:
	var t: Dictionary = RiftTower.find("cinder_stair")
	RiftTower.finish(t, 4)
	assert_eq(GameState.waymarks, 4 * RiftTower.FLOOR_WAYMARKS)
	RiftTower.finish(t, 3)
	assert_eq(GameState.waymarks, 4 * RiftTower.FLOOR_WAYMARKS, "no new floor, no pay")
	RiftTower.finish(t, 15)
	assert_eq(GameState.waymarks, 15 * RiftTower.FLOOR_WAYMARKS + RiftTower.TOP_WAYMARKS)
	assert_true(Achievements.earned("cinder_proof"))
	assert_false(Achievements.earned("deep_diver"))

func test_tower_card_lists_all_three() -> void:
	var lines: Array[String] = RiftTower.card_lines()
	assert_eq(lines.size(), 3)
	GameState.set_flag("rift_tide_sealed")
	assert_string_contains("\n".join(RiftTower.card_lines()), Loc.t("Tide Shaft"))
