extends GutTest
## The three Rifts of 2026-11 (Mist, Root, Shade; owner decision: twelve Rifts instead of six):
## maps, Wardens, story order, reachability, the level curve and the new Warden rules.

const RIFTS: Dictionary = {
	"mist_rift": {"region": "veydal", "warden": "warden_brisa", "id": "mist", "from": "crowcrest", "rule": "fog_bank", "gift": "echo_tailwind", "size": 3},
	"root_rift": {"region": "corvane", "warden": "warden_darrow", "id": "root", "from": "woadfen", "rule": "vine_tangle", "gift": "echo_root_grip", "size": 4},
	"shade_rift": {"region": "ashmere", "warden": "warden_odalys", "id": "shade", "from": "saltglass", "rule": "night_dark", "gift": "echo_night_veil", "size": 5},
}

## The main battles in story order: [map or "" for a story duel, npc or duel id].
const STORY_ORDER: Array = [
	["cinder_rift", "warden_orrin"], ["mist_rift", "warden_brisa"], ["tide_rift", "warden_maelis"],
	["rain_rift", "warden_senna"], ["mirror_rift", "warden_joral"], ["", "kestra_root_tag"],
	["root_rift", "warden_darrow"], ["greyreach", "veit"], ["kiln_rift", "warden_tovan"],
	["glass_rift", "warden_ilse"], ["", "veit_2"], ["shade_rift", "veit_s"], ["shade_rift", "warden_odalys"],
	["", "kestra_3"], ["", "echo_1"], ["", "echo_2"], ["", "echo_3"],
]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	var m: MapData = MapData.load_map(map_id)
	for n: Dictionary in m.npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _team(entry: Array) -> Array:
	if str(entry[0]).is_empty():
		return StoryBattles.get_def(str(entry[1])).get("team", [])
	return _npc(str(entry[0]), str(entry[1])).get("team", [])

func _top(team: Array) -> int:
	var top: int = 0
	for e: Variant in team:
		top = maxi(top, int((e as Dictionary).get("level", 0)))
	return top

func test_maps_and_wardens_follow_the_warden_shape() -> void:
	for mid: String in RIFTS:
		var r: Dictionary = RIFTS[mid]
		var m: MapData = MapData.load_map(mid)
		assert_not_null(m, mid)
		if m == null:
			continue
		assert_eq(m.region, str(r.region), mid)
		var w: Dictionary = _npc(mid, str(r.warden))
		assert_eq(str(w.get("warden", "")), str(r.id), mid)
		assert_eq(str(w.get("rule", "")), str(r.rule), mid)
		assert_eq(w.get("mend_items", []), [r.gift], mid)
		assert_eq(str(w.get("rematch_after", "")), "story_complete", mid)
		assert_eq((w.team as Array).size(), int(r.size), mid + " team size")
		for e: Variant in w.team:
			assert_not_null(Database.species(str(e.species)), "%s: %s is a Spirling from data/spirlings.json" % [mid, e.species])
		# Item 1605: a line before waking, after the duel, after the mend and after the finale.
		var entry: Dictionary = Dialogue.get_entry(str(w.dialogue))
		var after: Array = (entry.get("after_flag", []) as Array).map(func(a: Dictionary) -> String: return str(a.flag))
		assert_false((entry.get("lines", []) as Array).is_empty(), mid)
		assert_eq(after, ["rift_%s_sealed" % r.id, "story_complete"], mid)
		assert_true(Dialogue.exists(str(w.defeat)), mid)
		# Two Wayfarers and one acolyte on the way, a rest spot before the Warden.
		var crew: int = 0
		var acolytes: int = 0
		for n: Dictionary in m.npcs:
			if TrainerData.is_trainer(n) and not n.has("warden") and not n.has("boss") and not n.has("beaten_flag"):
				crew += 1
				acolytes += 1 if str(n.get("trainer", "")).begins_with("Rift Acolyte") else 0
		assert_eq(crew, 3, mid)
		assert_eq(acolytes, 1, mid)
		assert_ne(m.heal_point, Vector2i(-1, -1), mid + " has a rest spot")
		assert_lt(m.heal_point.y, 7, mid + " rests above the puzzle gate, before the Warden")
		var item: Dictionary = Database.item(str(r.gift))
		assert_not_null(Database.move(str(item.get("teaches", ""))), str(r.gift))

func test_rifts_are_reached_from_their_region_and_lead_back() -> void:
	for mid: String in RIFTS:
		var from: String = str(RIFTS[mid].from)
		var into: Array = MapData.load_map(from).warps.filter(func(w: Dictionary) -> bool: return str(w.to) == mid)
		assert_eq(into.size(), 1, "%s leads into %s" % [from, mid])
		var back: Array = MapData.load_map(mid).warps.filter(func(w: Dictionary) -> bool: return str(w.to) == from)
		assert_gt(back.size(), 0, "%s leads back to %s" % [mid, from])

func test_every_new_battle_is_reachable_and_no_dead_end() -> void:
	assert_eq(WorldValidator.validate(), PackedStringArray())
	var entries: Dictionary = WorldValidator.entry_cells(MapData.all_ids())
	for mid: String in RIFTS:
		var m: MapData = MapData.load_map(mid)
		var reach: Dictionary = WorldValidator.reachable_cells(m, entries.get(mid, []))
		for n: Dictionary in m.npcs:
			var c := Vector2i(int(n.x), int(n.y))
			var near: bool = false
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				near = near or reach.has(c + d)
			assert_true(near, "%s: %s can be reached" % [mid, n.id])
		# The shortcut back opens on the mend, the way up on the puzzle.
		var flags: Array = m.blocks.map(func(b: Dictionary) -> String: return str(b.open_flag))
		assert_has(flags, "rift_%s_sealed" % RIFTS[mid].id, mid + " shortcut")
		assert_has(flags, mid + "_open", mid + " puzzle gate")

func test_puzzles_open_their_gate() -> void:
	for mid: String in ["mist_rift", "root_rift"]:
		var m: MapData = MapData.load_map(mid)
		var steps: Dictionary = {}
		for s: Dictionary in m.signs:
			var action: String = str(Dialogue.get_entry(str(s.dialogue)).get("action", ""))
			if action.begins_with("bell "):
				var p: PackedStringArray = action.split(" ")
				assert_eq(p[1], mid + "_open")
				steps[int(p[2])] = int(p[3])
		assert_eq(steps.keys().size(), 3, mid)
		for n: int in [1, 2, 3]:
			assert_eq(GameState.press_switch(mid + "_open", n, 3), GameState.SwitchResult.SOLVED if n == 3 else GameState.SwitchResult.STEP)
		assert_true(GameState.has_flag(mid + "_open"))
	var shade: MapData = MapData.load_map("shade_rift")
	assert_eq(str(shade.beam.flag), "shade_rift_open")
	var ways: Dictionary = {Vector2i(6, 8): "\\", Vector2i(6, 10): "\\", Vector2i(3, 10): "/"}
	assert_true(WorldMechanics.beam_hits(shade, ways), "two mirrors light the beacon")

func test_story_order_and_level_curve() -> void:
	assert_eq(GameState.STORY_RIFTS, ["cinder", "mist", "tide", "rain", "mirror", "root", "kiln", "glass", "shade"] as Array[String])
	var last: int = 0
	for entry: Array in STORY_ORDER:
		var team: Array = _team(entry)
		assert_false(team.is_empty(), str(entry))
		var top: int = _top(team)
		assert_gte(top, last, "%s (ring %d) comes after ring %d" % [entry, top, last])
		last = top
	var ids: Array = QuestLog.main_goals().map(func(g: Dictionary) -> String: return str(g.id))
	assert_lt(ids.find("rifts"), ids.find("dock"))
	assert_lt(ids.find("rifts2"), ids.find("rift_root"))
	assert_lt(ids.find("rift_root"), ids.find("veit"))
	assert_lt(ids.find("veit_plate"), ids.find("rift_shade"))
	assert_lt(ids.find("rift_shade"), ids.find("far_end"))
	for i: int in range(1, GameState.LEVEL_CAPS.size()):
		assert_gt(GameState.LEVEL_CAPS[i], GameState.LEVEL_CAPS[i - 1], "caps rise with every Rift")

func test_wild_rings_fit_the_place_in_the_story() -> void:
	var rings: Dictionary = {"mist_rift": [12, 15], "root_rift": [23, 25], "shade_rift": [32, 35]}
	for id: String in rings:
		for s: Dictionary in EncounterTable.table(id).get("spawns", []):
			assert_between(int(s.min), int(rings[id][0]), int(rings[id][1]), "%s %s" % [id, s.species])
			assert_between(int(s.max), int(rings[id][0]), int(rings[id][1]), "%s %s" % [id, s.species])

func test_finale_needs_every_rift_and_every_heart() -> void:
	var gate: Dictionary = Dialogue.get_entry("ashmere/undrawn_gate")
	var need: Array = (gate.get("if", {}) as Dictionary).get("flag", [])
	assert_eq(need, GameState.finale_flags())
	assert_eq(need.size(), GameState.STORY_RIFTS.size() + GameState.RIFT_HEARTS.size())
	var flags: Dictionary = {}
	for f: String in GameState.finale_flags():
		flags[f] = true
	assert_true(Dialogue.check(gate.if, flags))
	flags.erase("rift_shade_sealed")
	assert_false(Dialogue.check(gate.if, flags), "one open Rift keeps the Undrawn closed")
	assert_eq(str(gate.get("else", "")), "undrawn_gate_wait")

func test_old_saves_see_the_new_rifts_as_open_tasks() -> void:
	# A 1.0 save after the finale: every old Rift mended, the new ones never seen.
	var flags: Dictionary = {"aldo_dock_told": true, "act2_end": true, "undrawn_reached": true, "story_complete": true}
	for r: String in ["cinder", "tide", "rain", "mirror", "kiln", "glass"]:
		flags["rift_%s_sealed" % r] = true
	var ids: Array = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return str(g.id))
	for id: String in ["mist_rift", "root_rift", "shade_rift"]:
		assert_has(ids, id)
	flags["rift_mist_sealed"] = true
	ids = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return str(g.id))
	assert_does_not_have(ids, "mist_rift")
	assert_has(ids, "mist_heart")

func test_kestra_waits_at_the_dock_after_all_three_veydal_rifts() -> void:
	GameState.seal_rift("cinder")
	GameState.seal_rift("tide")
	assert_true(GameState.has_flag("storage_remote"))
	assert_false(GameState.has_flag(GameState.VEYDAL_RIFTS_FLAG))
	GameState.seal_rift("mist")
	assert_true(GameState.has_flag(GameState.VEYDAL_RIFTS_FLAG))
	assert_eq(str(_npc("brindlewick", "kestra_dock").show_flag), GameState.VEYDAL_RIFTS_FLAG)

func test_new_wardens_rematch_only_after_the_finale() -> void:
	var w: Dictionary = _npc("mist_rift", "warden_brisa")
	var flags: Dictionary = {TrainerData.beaten_flag(w, "mist_rift"): true}
	assert_false(TrainerData.can_rematch(w, "mist_rift", flags, {}, "2026-11-10"))
	flags["story_complete"] = true
	assert_true(TrainerData.can_rematch(w, "mist_rift", flags, {}, "2026-11-10"))

# --- The three Warden rules ------------------------------------------------------------------

func _duel(rule: String, seed_value: int, mine: Spirling, foe: Spirling) -> BattleModel:
	var m := BattleModel.new([mine] as Array[Spirling], [foe] as Array[Spirling], false, seed_value, 1)
	m.foe_rule = rule
	m.start()
	return m

func test_fog_bank_lowers_accuracy_on_both_sides() -> void:
	assert_almost_eq(BattleRules.rule_number("fog_bank", "accuracy_mult"), 0.85, 0.001)
	assert_almost_eq(BattleRules.rule_number("", "accuracy_mult"), 1.0, 0.001)
	var misses: int = 0
	for seed_value: int in 40:
		var m: BattleModel = _duel("fog_bank", seed_value, BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String]),
			BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String]))
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0))
		for e: BattleEvent in ev:
			misses += 1 if e.type == BattleEvent.Type.MISSED else 0
	assert_gt(misses, 0, "a sure art can miss in the fog")

func test_vine_tangle_mends_the_weakest_spirling() -> void:
	var me: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String])
	var m: BattleModel = _duel("vine_tangle", 3, me, foe)
	me = m.active_spirling(0)
	foe = m.active_spirling(1)
	me.hp = me.max_hp() / 4
	var before: int = me.hp
	var foe_before: int = foe.hp
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_gt(me.hp, before, "the lower one is mended")
	assert_eq(foe.hp, foe_before, "the healthier one is not")

func test_night_dark_hides_who_moves_first() -> void:
	var slow_first: int = 0
	for seed_value: int in 30:
		var fast: Spirling = BattleFixtures.make("Zephlet", 30, ["Lichen Lash"] as Array[String])
		var slow: Spirling = BattleFixtures.make("Talusk", 30, ["Lichen Lash"] as Array[String])
		var m: BattleModel = _duel("night_dark", seed_value, slow, fast)
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0))
		var first: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.MOVE_USED)
		if first != null and int(first.data.get("side", -1)) == BattleModel.Side.PLAYER:
			slow_first += 1
	assert_gt(slow_first, 0, "in the dark the slower Spirling sometimes acts first")
