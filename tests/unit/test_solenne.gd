extends GutTest
## Solenne, Act IV (owner decision 2026-11-10: twelve Rifts, the last three in Solenne): the town
## of Ochrewell, the Tower, Oasis and Sun Rift with their Wardens, puzzles and rules, the level
## curve past Odalys, Kaia's betrayal and the finale that waits for all twelve seals.

const RIFTS: Dictionary = {
	"tower_rift": {"warden": "warden_aurelio", "id": "tower", "rule": "sandstorm", "gift": "echo_squall", "size": 5, "open": ""},
	"oasis_rift": {"warden": "warden_kaia", "id": "oasis", "rule": "dry_well", "gift": "echo_dawn_mend", "size": 5, "open": "rift_tower_sealed"},
	"sun_rift": {"warden": "warden_emrys", "id": "sun", "rule": "high_noon", "gift": "echo_radiant_lance", "size": 5, "open": "rift_oasis_sealed"},
}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _top(team: Array) -> int:
	var top: int = 0
	for e: Variant in team:
		top = maxi(top, int((e as Dictionary).get("level", 0)))
	return top

func test_world_is_valid() -> void:
	assert_eq(WorldValidator.validate(), PackedStringArray())

func test_ochrewell_is_reached_from_saltglass_after_ashmere() -> void:
	var town: MapData = MapData.load_map("ochrewell")
	assert_eq(town.region, "solenne")
	assert_ne(town.heal_point, Vector2i(-1, -1), "Ochrewell has a rest spot")
	var salt: MapData = MapData.load_map("saltglass")
	var into: Array = salt.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == "ochrewell")
	assert_eq(into.size(), 2)
	for w: Dictionary in into:
		var b: Array = salt.blocks.filter(func(bb: Dictionary) -> bool: return int(bb.x) == int(w.x) and int(bb.y) == int(w.y))
		assert_eq(str(b[0].open_flag), "rift_shade_sealed", "the sand road opens once Ashmere's last Rift is mended")
	assert_true("solenne" in WorldValidator.REGIONS)

func test_rifts_follow_the_warden_shape() -> void:
	for mid: String in RIFTS:
		var r: Dictionary = RIFTS[mid]
		var m: MapData = MapData.load_map(mid)
		assert_not_null(m, mid)
		if m == null:
			continue
		assert_eq(m.region, "solenne", mid)
		var w: Dictionary = _npc(mid, str(r.warden))
		assert_eq(str(w.get("warden", "")), str(r.id), mid)
		assert_eq(str(w.get("rule", "")), str(r.rule), mid)
		assert_true(BattleRules.RULES.has(str(r.rule)), mid)
		assert_eq(w.get("mend_items", []), [r.gift], mid)
		assert_eq(str(w.get("rematch_after", "")), "story_complete", mid)
		assert_eq((w.team as Array).size(), int(r.size), mid + " team size")
		for e: Variant in w.team:
			assert_not_null(Database.species(str(e.species)), "%s: %s" % [mid, e.species])
		assert_not_null(Database.move(str(Database.item(str(r.gift)).get("teaches", ""))), str(r.gift))
		var crew: int = 0
		var acolytes: int = 0
		for n: Dictionary in m.npcs:
			if TrainerData.is_trainer(n) and not n.has("warden"):
				crew += 1
				acolytes += 1 if str(n.get("trainer", "")).begins_with("Rift Acolyte") else 0
		assert_eq(crew, 3, mid + ": two Wayfarers and an acolyte")
		assert_eq(acolytes, 1, mid)
		assert_lt(m.heal_point.y, 6, mid + " rests above the puzzle, before the Warden")
		var flags: Array = m.blocks.map(func(b: Dictionary) -> String: return str(b.open_flag))
		assert_has(flags, "rift_%s_sealed" % r.id, mid + " shortcut")
		# The way in from Ochrewell and its lock.
		var town: MapData = MapData.load_map("ochrewell")
		for wp: Dictionary in town.warps.filter(func(x: Dictionary) -> bool: return str(x.to) == mid):
			var lock: Array = town.blocks.filter(func(b: Dictionary) -> bool: return int(b.x) == int(wp.x) and int(b.y) == int(wp.y))
			if str(r.open).is_empty():
				assert_eq(lock.size(), 0, mid + " is open from the start")
			else:
				assert_eq(str(lock[0].open_flag), str(r.open), mid)

func test_each_rift_has_its_own_puzzle() -> void:
	# Tower: four shutters in the chalked order.
	var steps: Dictionary = {}
	for s: Dictionary in MapData.load_map("tower_rift").signs:
		var action: String = str(Dialogue.get_entry(str(s.dialogue)).get("action", ""))
		if action.begins_with("bell "):
			var p: PackedStringArray = action.split(" ")
			assert_eq(p[1], "tower_rift_open")
			assert_eq(p[4], "shutter")
			steps[int(p[2])] = int(p[3])
	assert_eq(steps.keys().size(), 4)
	for n: int in [1, 2, 3, 4]:
		assert_eq(GameState.press_switch("tower_rift_open", n, 4), GameState.SwitchResult.SOLVED if n == 4 else GameState.SwitchResult.STEP)
	# Oasis: the low gate drowns above mark 1, the high gate needs mark 2.
	var oasis: MapData = MapData.load_map("oasis_rift")
	assert_eq(oasis.sluices.size(), 3)
	for level: int in [0, 1, 2, 3]:
		var f: Dictionary = {}
		WorldMechanics.water_flags(level, f)
		oasis.apply_blocks(f)
		assert_eq(oasis.is_walkable(Vector2i(4, 12)), level <= 1, "low gate at mark %d" % level)
		assert_eq(oasis.is_walkable(Vector2i(4, 6)), level >= 2, "high gate at mark %d" % level)
	# Sun: two sun-weights on two plates.
	var sun: MapData = MapData.load_map("sun_rift")
	assert_eq(sun.puzzles.size(), 1)
	assert_eq(str(sun.puzzles[0].flag), "sun_rift_open")
	assert_eq(PuzzleRoom.start_boulders(sun).size(), 2)

func test_wardens_level_past_odalys_and_caps_continue() -> void:
	var odalys: int = _top(_npc("shade_rift", "warden_odalys").team)
	var last: int = odalys
	var sealed: int = GameState.STORY_RIFTS.find("tower")
	for mid: String in ["tower_rift", "oasis_rift", "sun_rift"]:
		var team: Array = _npc(mid, str(RIFTS[mid].warden)).team
		var top: int = _top(team)
		assert_gt(top, odalys, mid + " is above Odalys")
		assert_gte(top, last, mid)
		assert_lte(top, GameState.LEVEL_CAPS[sealed], mid + " fits the ring cap")
		last = top
		sealed += 1
	assert_lte(last, _top(StoryBattles.get_def("echo_1").team), "the finale still tops Solenne")
	assert_eq(GameState.LEVEL_CAPS.size(), GameState.STORY_RIFTS.size() + 1)
	assert_eq(GameState.LEVEL_CAPS[-1], Spirling.STORY_RING)

func test_kaia_is_revealed_after_the_fight() -> void:
	var kaia: Dictionary = _npc("oasis_rift", "warden_kaia")
	var before: String = " ".join(PackedStringArray(Dialogue.lines_for(Dialogue.get_entry(str(kaia.intro)), {})))
	assert_false(before.contains("Brass Veil"), "no hint of the Veil before the duel")
	var after: String = " ".join(PackedStringArray(Dialogue.lines_for(Dialogue.get_entry(str(kaia.defeat)), {})))
	assert_string_contains(after, "Brass Veil")
	var factor: Dictionary = _npc("ochrewell", "factor")
	assert_eq(str(factor.show_flag), "rift_oasis_sealed")
	assert_false(StoryBattles.get_def("veil_factor").is_empty())

func test_finale_needs_all_twelve_seals() -> void:
	assert_eq(GameState.STORY_RIFTS.size(), 12)
	var gate: Dictionary = Dialogue.get_entry("ashmere/undrawn_gate")
	var need: Array = (gate.get("if", {}) as Dictionary).get("flag", [])
	assert_eq(need, GameState.finale_flags())
	var flags: Dictionary = {}
	for f: String in GameState.finale_flags():
		flags[f] = true
	assert_true(Dialogue.check(gate.if, flags))
	flags.erase("rift_sun_sealed")
	assert_false(Dialogue.check(gate.if, flags), "Solenne keeps the Undrawn closed")

func test_old_saves_keep_working() -> void:
	# A save from before Solenne, past the finale: the old nine Rifts mended.
	var flags: Dictionary = {"aldo_dock_told": true, "act2_end": true, "undrawn_reached": true, "story_complete": true}
	for r: String in ["cinder", "mist", "tide", "rain", "mirror", "root", "kiln", "glass", "shade"]:
		flags["rift_%s_sealed" % r] = true
	assert_ne(str(QuestLog.current(flags).id), "solenne", "a finished story does not fall back to Solenne")
	var ids: Array = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return str(g.id))
	assert_has(ids, "tower_rift", "the new Rifts show up as open tasks")
	flags["rift_tower_sealed"] = true
	ids = QuestLog.open_side_goals(flags).map(func(g: Dictionary) -> String: return str(g.id))
	assert_does_not_have(ids, "tower_rift")
	assert_has(ids, "oasis_rift")

# --- The three Warden rules ------------------------------------------------------------------

func _duel(rule: String, seed_value: int, mine: Spirling, foe: Spirling) -> BattleModel:
	var m := BattleModel.new([mine] as Array[Spirling], [foe] as Array[Spirling], false, seed_value, 1)
	m.foe_rule = rule
	m.start()
	return m

func test_sandstorm_spares_stone() -> void:
	var m: BattleModel = _duel("sandstorm", 3, BattleFixtures.make("Zephlet", 36, ["Breeze Slice"] as Array[String]),
		BattleFixtures.make("Talusk", 36, ["Pebble Toss"] as Array[String]))
	var me: Spirling = m.active_spirling(0)
	var foe: Spirling = m.active_spirling(1)
	var me_before: int = me.hp
	var foe_before: int = foe.hp
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_lt(me.hp, me_before, "Gale takes the sand")
	assert_eq(foe.hp, foe_before, "Stone shrugs it off")

func test_dry_well_halves_heals() -> void:
	var dry: BattleModel = _duel("dry_well", 3, BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String]),
		BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String]))
	var wet: BattleModel = _duel("", 3, BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String]),
		BattleFixtures.make("Calderox", 40, ["Cinder Nip"] as Array[String]))
	for m: BattleModel in [dry, wet]:
		m.active_spirling(0).hp = 10
	assert_eq(dry.heal(0, 40), 20)
	assert_eq(wet.heal(0, 40), 40)

func test_high_noon_lifts_lumen_arts() -> void:
	assert_almost_eq(BattleRules.rule_number("high_noon", "lumen_mult"), 1.3, 0.001)
	assert_almost_eq(BattleRules.rule_number("fog_bank+high_noon", "lumen_mult"), 1.3, 0.001)
	var totals: Array[int] = []
	for rule: String in ["high_noon", ""]:
		var m: BattleModel = _duel(rule, 5, BattleFixtures.make("Calderox", 40, ["Prism Ray"] as Array[String]),
			BattleFixtures.make("Calderox", 40, ["Prism Ray"] as Array[String]))
		var sum: int = 0
		for e: BattleEvent in m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0)):
			if e.type == BattleEvent.Type.DAMAGE:
				sum += int(e.data.get("amount", 0))
		totals.append(sum)
	assert_gt(totals[0], totals[1], "the noon sun burns brighter")
