extends GutTest
## KAMPF_PLAN_1000 items 531, 539, 540, 548, 557: varying first-win gifts, the signal lantern, the
## pair battle (two Wayfarers against you and Kestra) and the Wayfarer money balance.

const BRAM: Dictionary = {"id": "bram", "trainer": "Ridgewalker Bram", "team": [{"species": "Shalebat", "level": 7}]}
const HIGH: Dictionary = {"id": "fuse", "trainer": "Miner Fuse", "team": [{"species": "Shalebat", "level": 36}]}
const WARDEN: Dictionary = {"id": "isa", "trainer": "Isa", "team": [{"species": "Zephlet", "level": 9}], "warden": "x"}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _tier_items(ring: int) -> Array:
	for t: Dictionary in WayfarerRewards.data().tiers:
		if ring <= int(t.max_ring):
			return t.items
	return []

# --- 531: first-win gifts ---------------------------------------------------------------------

func test_reward_items_exist() -> void:
	var tiers: Array = WayfarerRewards.data().tiers
	assert_gte(tiers.size(), 3)
	var last: int = 0
	for t: Dictionary in tiers:
		assert_gt(int(t.max_ring), last, "tiers go up")
		last = int(t.max_ring)
		for it: Variant in t.items:
			assert_false(Database.item(str(it)).is_empty(), str(it))

func test_gift_depends_on_the_wayfarer_and_its_ring() -> void:
	var a: String = WayfarerRewards.pick(BRAM, "crowcrest", 7)
	assert_eq(a, WayfarerRewards.pick(BRAM, "crowcrest", 7), "the same Wayfarer always gives the same")
	assert_has(_tier_items(7), a)
	assert_has(_tier_items(36), WayfarerRewards.pick(HIGH, "bellows_deep", 36), "a stronger Wayfarer gives from a higher tier")
	var seen: Dictionary = {}
	for i: int in 12:
		seen[WayfarerRewards.pick({"id": "w%d" % i, "trainer": "W", "team": BRAM.team}, "crowcrest", 7)] = true
	assert_gt(seen.size(), 1, "the gifts vary between Wayfarers")
	assert_eq(WayfarerRewards.top_ring(HIGH, "Kindlop"), 36)

func test_gift_is_given_once_and_not_by_wardens() -> void:
	var item: String = WayfarerRewards.grant(BRAM, "crowcrest", "Kindlop")
	assert_false(item.is_empty())
	assert_eq(GameState.item_count(item), 1)
	assert_eq(WayfarerRewards.grant(BRAM, "crowcrest", "Kindlop"), "", "only on the first win")
	assert_eq(GameState.item_count(item), 1)
	assert_eq(WayfarerRewards.grant(WARDEN, "steps", "Kindlop"), "", "Wardens give their own thanks")
	assert_eq(WayfarerRewards.pick({"id": "swarm", "wild": true, "team": BRAM.team}, "murk", 7), "")
	assert_string_contains(WayfarerRewards.line(BRAM, item), "Ridgewalker Bram")

# --- 539, 540: the signal lantern -------------------------------------------------------------

func test_lantern_blinks_unless_motion_is_reduced() -> void:
	assert_true(NPC.lantern_lit(0, false))
	assert_false(NPC.lantern_lit(NPC.LANTERN_BLINK_MS, false))
	assert_true(NPC.lantern_lit(NPC.LANTERN_BLINK_MS * 2, false))
	assert_true(NPC.lantern_lit(NPC.LANTERN_BLINK_MS, true), "steady with reduced motion")

func test_who_may_be_waved_off() -> void:
	assert_true(TrainerData.may_wave_off(BRAM))
	assert_false(TrainerData.may_wave_off(WARDEN))
	assert_false(TrainerData.may_wave_off({"id": "b", "team": BRAM.team, "boss": "ashen_heart"}))
	assert_false(TrainerData.may_wave_off({"id": "s", "team": BRAM.team, "wild": true}))
	assert_false(TrainerData.may_wave_off(_npc("saltmarsh", "kestra_tag")), "story battles do not wait")

func test_npc_lantern_redraws() -> void:
	var n := NPC.new()
	add_child_autofree(n)
	n.setup(BRAM.merged({"x": 1, "y": 1}))
	n.signal_lantern = true
	assert_true(n.signal_lantern)
	n.signal_lantern = false
	assert_false(n.signal_lantern)

# --- 548: pair battle -------------------------------------------------------------------------

func test_saltmarsh_tag_is_two_wayfarers() -> void:
	var tag: Dictionary = _npc("saltmarsh", "kestra_tag")
	assert_eq(str(tag.pair.name), "Hauler Wren")
	assert_true(WorldValidator.format_errors(tag, "saltmarsh").is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var team: Array[Spirling] = TrainerData.build_team(tag, "Kindlop", rng, GameState.Difficulty.TAMER)
	assert_eq(team.size(), (tag.team as Array).size() + (tag.pair.team as Array).size(), "both teams fight")
	assert_eq(team[-1].data.species_name, "Mirkmole", "Wren's Spirling joins last")
	var info: Dictionary = TrainerData.battle_info(tag, team, 1)
	assert_eq(str(info.name), "Hauler Tobin & Hauler Wren")
	assert_eq(info.front, [1, 2] as Array[int])
	assert_eq(str(info.partner.name), "Cartographer Kestra", "you still fight beside Kestra")

func test_pair_needs_name_team_and_two_foes() -> void:
	assert_false(WorldValidator.format_errors({"id": "x", "front": [1, 2], "pair": {"name": "Y"}}).is_empty())
	assert_false(WorldValidator.format_errors({"id": "x", "front": [1, 2], "pair": {"team": BRAM.team}}).is_empty())
	assert_false(WorldValidator.format_errors({"id": "x", "pair": {"name": "Y", "team": BRAM.team}}).is_empty(), "1 v 1 cannot hold a pair")
	assert_false(WorldValidator.format_errors({"id": "x", "front": [1, 2], "pair": {"name": "Y", "team": [{"species": "Nope"}]}}).is_empty())
	assert_true(WorldValidator.format_errors({"id": "x", "front": [1, 2], "pair": {"name": "Y", "team": BRAM.team}}).is_empty())
	assert_eq(TrainerData.pair_name(BRAM), "Ridgewalker Bram")

# --- 557: Wayfarer money balance --------------------------------------------------------------

func test_money_rates_are_ordered() -> void:
	assert_lt(TrainerData.REMATCH_MONEY_PER_LEVEL, TrainerData.MONEY_PER_LEVEL, "a rematch pays less than a first win")
	assert_lt(TrainerData.MONEY_PER_LEVEL, TrainerData.WARDEN_MONEY_PER_LEVEL, "a Warden pays more")
	var last: int = 0
	var rng := RandomNumberGenerator.new()
	for ring: int in [5, 10, 20, 40, 60]:
		var team: Array[Spirling] = [Spirling.new(Database.species("Shalebat"), ring, rng)]
		var m: int = TrainerData.prize_money({"id": "x", "team": []}, team)
		assert_gt(m, last, "the default prize grows with the ring")
		last = m

func test_map_money_is_balanced() -> void:
	var dir := DirAccess.open("res://data/maps")
	var checked: int = 0
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var m: MapData = MapData.load_map(f.get_basename())
		var warden_low: int = 2147483647
		var wayfarer_high: int = 0
		var high_id: String = ""
		for n: Dictionary in m.npcs:
			if not TrainerData.is_trainer(n) or TrainerData.is_wild_horde(n):
				continue
			var top: int = 0
			for e: Variant in TrainerData.team_entries(n, "Kindlop"):
				top = maxi(top, int((e as Dictionary).get("level", 5)))
			if top <= 0:
				continue
			var money: int = int(n.get("money", top * (TrainerData.WARDEN_MONEY_PER_LEVEL if n.has("warden") else TrainerData.MONEY_PER_LEVEL)))
			assert_gt(money, TrainerData.REMATCH_MONEY_PER_LEVEL * top, "%s/%s: the first win pays more than a rematch at its ring" % [f, n.id])
			if n.has("warden"):
				warden_low = mini(warden_low, money)
			elif money > wayfarer_high:
				wayfarer_high = money
				high_id = str(n.id)
			checked += 1
		if warden_low < 2147483647 and wayfarer_high > 0:
			assert_gte(warden_low, wayfarer_high, "%s: no Wayfarer (%s) pays more than the Warden" % [f, high_id])
	assert_gt(checked, 100, "all map Wayfarers are checked")
