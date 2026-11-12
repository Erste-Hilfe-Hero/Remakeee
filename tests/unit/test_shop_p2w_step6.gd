extends GutTest
## Pay-to-win step 6 (plan sections 1-3, the points without new store products or art): master
## techniques, Second Gift Slot, Seventh Team Place, Deep Rift Breath, Spirling Radar, Wish Charm,
## Storage Wings, Tide Shell, Spirlog Atlas, Triple Find of the Day, Wild Ward, Swift Steps,
## Pocket Rest, Rift Script Pack, Journey Start Trio, the pass Spirling of the day and the Power note.

const MASTER_ELEMENTS: Array[String] = ["ember", "tide", "bloom", "volt", "stone", "gale", "lumen", "umbra", "ink", "echo", "acid", "frost"]
const OTHER_IDS: Array[String] = ["rg_gift_slot", "rg_team_slot_7", "rg_rift_breath_deep", "rg_radar", "rg_wish_charm",
	"rg_storage_wing_1", "rg_storage_wing_2", "rg_storage_wing_3", "rg_storage_wing_4", "rg_storage_wing_5", "rg_tide_pearl",
	"rg_spirlog_atlas", "rg_daily_find_x3", "rg_wild_ward", "rg_swift_steps", "rg_rest_anywhere", "rg_script_pack", "rg_starter_trio"]

var _state: Dictionary
var _inv: Dictionary
var _party: Array[Spirling]
var _storage: Array[Spirling]
var _flags: Dictionary
var _ward: bool
var _records: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state.duplicate(true)
	_inv = GameState.inventory.duplicate(true)
	_party = GameState.party.duplicate()
	_storage = GameState.storage.duplicate()
	_flags = GameState.flags.duplicate(true)
	_ward = GameState.wild_ward
	_records = GameState.records.duplicate(true)

func after_each() -> void:
	Billing.state = _state
	GameState.inventory = _inv
	GameState.party = _party
	GameState.storage = _storage
	GameState.flags = _flags
	GameState.wild_ward = _ward
	GameState.records = _records

static func _ids() -> Array[String]:
	var out: Array[String] = []
	for e: String in MASTER_ELEMENTS:
		out.append("rg_master_" + e)
	out.append_array(OTHER_IDS)
	return out

func test_offers_are_fixed_riftglass_only_with_full_grant_data() -> void:
	var mine: Array[Dictionary] = []
	for id: String in _ids():
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id)
		assert_eq(str(o.kind), "advantage", id)
		assert_true(bool(o.rg_only), id)
		assert_true(bool(o.ready), id)
		assert_eq(int(o.min_band), 13, id)
		assert_eq(int(o.eur_cents), int(o.rg_price) - 1, "euro equivalent shown for " + id)
		assert_true(str(o.get("duration", "")) in ["once", "permanent"], "duration given for " + id)
		if str(o.duration) == "permanent":
			assert_eq(int(o.limit.n), 1, "permanent offers are once per account: " + id)
			assert_eq(str(o.store_type), "non_consumable", id)
		else:
			assert_false(o.has("limit"), "used-up offers can be bought again: " + id)
		for g: Dictionary in o.grants:
			if str(g.t) == "item":
				assert_gt(int(g.n), 0, "item amount for " + id)
		mine.append(o)
	assert_eq(ShopValidator.check(mine), [] as Array[String])
	assert_eq(ShopCatalog.validate(), [] as Array[String])
	var products: Array = JSON.parse_string(FileAccess.get_file_as_string("res://store/products.json")).products
	for p: Dictionary in products:
		assert_false(str(p.offer) in _ids(), "no store product for " + str(p.offer))

func test_master_techniques_one_per_element_above_every_learned_one() -> void:
	var elements: Dictionary = {}
	var best_learned: float = 0.0
	for sd: SpirlingData in Database.spirlings.values():
		for mv: MoveData in sd.learnset_moves:
			if mv.is_damaging():
				best_learned = maxf(best_learned, float(mv.power) * mv.accuracy / float(mv.energy_cost + 1))
	for e: String in MASTER_ELEMENTS:
		var it: Dictionary = Database.item("rg_master_" + e)
		assert_true(bool(it.used_up), e)
		var mv: MoveData = Database.move(str(it.teaches))
		assert_not_null(mv, e)
		assert_eq(Elements.E.keys()[mv.element], e.to_upper(), "element of " + mv.move_name)
		elements[mv.element] = true
		assert_gt(float(mv.power) * mv.accuracy / float(mv.energy_cost + 1), best_learned, mv.move_name + " beats every learned art")
		assert_true(mv.effects.is_empty(), "no drawback on " + mv.move_name)
	assert_eq(elements.size(), 12, "12 elements, one each")

func test_master_technique_teaches_and_the_fair_league_drops_it() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 20)
	GameState.inventory["rg_master_ember"] = 1
	assert_false(GameState.can_learn_echo(Spirling.new(Database.species("Puddlet"), 20), "rg_master_ember"), "only for its element")
	assert_true(GameState.learn_from_item(s, "rg_master_ember", 0))
	assert_true(s.moves.has(Database.move("Crownfire Rend")))
	assert_eq(GameState.item_count("rg_master_ember"), 0, "used up")
	var names: Array = s.moves.map(func(m: MoveData) -> String: return m.move_name)
	var fair: Dictionary = LeagueRules.fair_row("Kindlop", names)
	assert_false("Crownfire Rend" in fair.moves, "the Fair League allows only learned techniques")
	var open: Dictionary = LeagueRules.build_team([{"species": "Kindlop", "level": 20, "moves": names}], LeagueRules.OPEN, [{"species": "Kindlop", "moves": names}])
	assert_true("Crownfire Rend" in open.team[0].moves, "the Open League keeps it")

static func _gift_species() -> SpirlingData:
	for sd: SpirlingData in Database.spirlings.values():
		var h: String = HiddenGifts.gift_id(sd)
		if not h.is_empty() and h != sd.trait_id and not sd.trait_id.is_empty():
			return sd
	return null

func test_second_gift_slot_adds_the_hidden_gift() -> void:
	var sd: SpirlingData = _gift_species()
	assert_not_null(sd)
	var s := Spirling.new(sd, 10)
	var first: Dictionary = BattleRules.trait_info(s.gift_id())
	assert_eq(ShopEffects.gift_table(s), first, "one gift without the slot")
	GameState.inventory["rg_gift_slot"] = 1
	assert_ne(GameState.use_item_outside_battle("rg_gift_slot", s), "")
	assert_true(s.gift_slot)
	assert_eq(GameState.item_count("rg_gift_slot"), 0, "used up")
	var both: Dictionary = ShopEffects.gift_table(s)
	var second: Dictionary = BattleRules.trait_info(HiddenGifts.gift_id(sd))
	for k: Variant in second:
		if str(k) == "immune":
			for x: Variant in second.immune:
				assert_has(both.immune, x)
		else:
			assert_true(both.has(k), "second gift key %s" % k)
	for k: Variant in first:
		if str(k) != "immune":
			assert_eq(both[k], first[k], "the own gift wins")
	GameState.inventory["rg_gift_slot"] = 1
	assert_eq(GameState.use_item_outside_battle("rg_gift_slot", s), "", "only once per Spirling")
	assert_eq(GameState.item_count("rg_gift_slot"), 1)
	assert_true(Spirling.from_dict(s.to_dict()).gift_slot, "saved")
	assert_eq(TradeMenu.mon_why(s), "shop_boosted", "never traded")
	assert_eq(LocalBackend.trade_mon_why(s.to_dict()), "shop_boosted")
	assert_false(EchoTeam.build(EchoTeam.snapshot([s] as Array[Spirling]), Spirling.STORY_RING)[0].gift_slot, "leagues and duels never carry it")

func test_seventh_team_place() -> void:
	GameState.party.clear()
	Billing.state = {"unlocks": {"team_slot_7": 1}}
	assert_eq(GameState.party_max(), 6, "one more without the sixth place")
	Billing.state = {"unlocks": {"team_slot_6": 1, "team_slot_7": 1}}
	assert_eq(GameState.party_max(), 7)
	for i: int in 7:
		assert_true(GameState.receive_spirling(Spirling.new(Database.species("Zippit"), 5)), "member %d" % (i + 1))
	assert_false(GameState.receive_spirling(Spirling.new(Database.species("Zippit"), 5)), "never an eighth")
	Billing.state = {"unlocks": {"team_slot_6": 1}}
	ShopEffects.apply_unlocks()
	assert_eq(GameState.party.size(), 6, "a refunded place sends the seventh to storage")
	assert_eq(LeagueRules.TEAM_MAX, 5, "leagues and Raid Rifts stay at 5")
	var b := LocalBackend.new()
	b.db.users["u7"] = {"shop": {"unlocks": {"team_slot_6": 1, "team_slot_7": 1}}}
	assert_eq(b.party_max_of("u7"), 7)

func test_deep_rift_breath_has_no_battle_limit() -> void:
	var it: Dictionary = Database.item("rg_rift_breath_deep")
	assert_true(BattleModel.is_revive_item("rg_rift_breath_deep"))
	assert_eq(float(it.battle_revive), 0.5)
	assert_false(it.has("per_battle"))
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Zephlet", 5)] as Array[Spirling])
	m.items_used[0]["rg_rift_breath_deep"] = 9
	assert_true(m.item_left_this_battle(0, "rg_rift_breath_deep"))
	m.items_used[0]["rg_rift_breath"] = 1
	assert_false(m.item_left_this_battle(0, "rg_rift_breath"), "the plain Rift Breath stays at 1")

static func _rare_table() -> String:
	for id: String in EncounterTable.table_ids():
		if not ShopEffects.pass_rare_spawn(id).is_empty():
			return id
	return ""

func test_radar_names_the_rarer_kinds() -> void:
	var table: String = _rare_table()
	assert_ne(table, "")
	Billing.state = {"unlocks": {}}
	assert_eq(ShopEffects.radar_line(table), "")
	Billing.state = {"unlocks": {"radar": 1}}
	var line: String = ShopEffects.radar_line(table)
	assert_true(line.begins_with("Radar: "), line)
	assert_string_contains(line, str(ShopEffects.pass_rare_spawn(table).species))
	for sp: Dictionary in EncounterTable.table(table).spawns:
		if Database.species(str(sp.species)).rarity == "common":
			assert_false(line.contains(str(sp.species) + " ("), "common kinds are left out")

func _bond_once(seed_value: int, item: String) -> Dictionary:
	var foe := BattleFixtures.make("Zephlet", 5)
	foe.hp = 1
	for k: String in Spirling.STAT_KEYS:
		foe.spark[k] = 0
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [foe] as Array[Spirling], true, seed_value)
	m.inventory[item] = 1
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_bond(BattleModel.Side.PLAYER, 1.0, item), BattleAction.make_rest(BattleModel.Side.FOE))
	return {"ok": bool(BattleFixtures.first_of(ev, BattleEvent.Type.BOND_RESULT).data.success), "foe": foe}

func test_wish_charm_gives_top_spark_on_a_bond_that_works() -> void:
	var wins: int = 0
	for seed_value: int in 80:
		var r: Dictionary = _bond_once(seed_value, "rg_wish_charm")
		var foe: Spirling = r.foe
		for k: String in Spirling.STAT_KEYS:
			assert_eq(foe.spark[k], Spirling.SPARK_MAX if r.ok else 0, "seed %d %s" % [seed_value, k])
		wins += 1 if r.ok else 0
	assert_gt(wins, 0)
	assert_eq(float(Database.item("rg_wish_charm").get("bond_bonus", 0.0)), 0.0, "no better chance")
	assert_has(BattleScene.bond_charms({"rg_wish_charm": 1}), "rg_wish_charm", "offered in the bond menu")

func test_storage_wings_reach_600_in_five_steps() -> void:
	var owned: int = 0
	var cost: int = 0
	for n: int in 5:
		var o: Dictionary = ShopCatalog.offer("rg_storage_wing_%d" % (n + 1))
		assert_eq(str(o.requires), "tier:storage_box:%d" % owned, "steps in order")
		Billing.state = {"unlocks": {"storage_box": owned}, "band": 18, "balance": 99999, "bought": {}}
		assert_eq(Billing.block_reason(o, true), "", "step %d open" % (n + 1))
		owned += (o.grants as Array).size()
		assert_eq(owned, ShopEffects.storage_wing_boxes(n + 1))
		cost += int(o.rg_price)
	assert_eq(GameState.STORAGE_BOXES_START * GameState.BOX_SIZE + owned * GameState.BOX_SIZE, 600)
	assert_lt(cost, 12 * int(ShopCatalog.offer("rg_storage_box").rg_price), "cheaper than single boxes")
	var single: Dictionary = ShopCatalog.offer("rg_storage_box")
	Billing.state = {"unlocks": {"storage_box": 11}, "band": 18, "balance": 99999, "bought": {}}
	assert_eq(Billing.block_reason(single, true), "")
	Billing.state = {"unlocks": {"storage_box": 12}, "band": 18, "balance": 99999, "bought": {}}
	assert_eq(Billing.block_reason(single, true), "offer_limit", "never more than 12 bought boxes")
	assert_true(ShopEffects.max_ok("max:storage_box:11", 11))
	assert_false(ShopEffects.max_ok("max:storage_box:11", 12))

func test_tide_shell_and_script_pack_hand_over_items() -> void:
	var shell: Dictionary = ShopCatalog.offer("rg_tide_pearl")
	assert_eq(str(shell.grants[0].id), "rg_tide_pearl")
	assert_eq(int(shell.grants[0].n), 1)
	var k := Spirling.new(Database.species("Kelpup"), 3)
	GameState.inventory["rg_tide_pearl"] = 1
	assert_string_contains(GameState.use_item_outside_battle("rg_tide_pearl", k), "Kelphound", "unfurls like the Tide Shell")
	assert_eq(GameState.item_count("rg_tide_pearl"), 0, "used up")
	GameState.inventory.erase("tide_pearl")
	GameState.furl_back(k)
	assert_eq(GameState.item_count("tide_pearl"), 1, "furled back it returns a plain Tide Shell")
	var pack: Dictionary = ShopCatalog.offer("rg_script_pack")
	var ids: Array = (pack.grants as Array).map(func(g: Dictionary) -> String: return str(g.id))
	for e: String in ["ember", "tide", "bloom", "volt", "stone", "gale", "lumen", "umbra"]:
		assert_has(ids, "rg_script_" + e)
	assert_eq(ShopCatalog.single_value(pack), 4000)
	assert_lt(int(pack.rg_price), 4000)

func test_spirlog_atlas_names_every_place() -> void:
	var species: String = ""
	for sd: SpirlingData in Database.spirlings.values():
		if not Collection.habitat_maps(sd.species_name).is_empty() and Collection.places_seen(sd.species_name).is_empty():
			species = sd.species_name
			break
	assert_ne(species, "")
	Billing.state = {"unlocks": {}}
	assert_string_contains(Collection.places_line(species), "???")
	Billing.state = {"unlocks": {"spirlog_atlas": 1}}
	var line: String = Collection.places_line(species)
	assert_false(line.contains("???"))
	assert_string_contains(line, Spirling.place_name(Collection.habitat_maps(species)[0]))

func _visits(day: String, table: String) -> int:
	var flags: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var n: int = 0
	for i: int in 400:
		if DailyFind.maybe_spawn(table, flags, rng, day) != null:
			n += 1
	return n

func test_triple_find_of_the_day() -> void:
	var day: String = "2026-11-13"
	var table: String = str(DailyFind.pick(day).table)
	Billing.state = {"unlocks": {}}
	assert_eq(_visits(day, table), 1)
	Billing.state = {"unlocks": {"daily_find_x3": 1}}
	assert_eq(_visits(day, table), 3)
	var flags: Dictionary = {DailyFind.flag_for("2026-11-14"): true}
	assert_true(DailyFind.met_later(flags, day), "no extra visits after a later day")

func test_wild_ward_needs_the_unlock() -> void:
	GameState.wild_ward = true
	Billing.state = {"unlocks": {}}
	assert_false(ShopEffects.wild_ward_on())
	ShopEffects.apply_unlocks()
	assert_false(GameState.wild_ward, "a refunded ward switches off")
	Billing.state = {"unlocks": {"wild_ward": 1}}
	GameState.wild_ward = true
	assert_true(ShopEffects.wild_ward_on())
	var keys: Array = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_has(keys, "wild_ward")

func test_swift_steps_and_pocket_rest() -> void:
	Billing.state = {"unlocks": {}}
	assert_eq(ShopEffects.walk_mult(), 1.0)
	assert_false(ShopEffects.pocket_rest())
	Billing.state = {"unlocks": {"swift_steps": 1, "rest_anywhere": 1}}
	assert_eq(ShopEffects.walk_mult(), 2.0)
	var s := Spirling.new(Database.species("Zippit"), 10)
	s.hp = 1
	GameState.party = [s] as Array[Spirling]
	var rests: int = int(GameState.records.get("count_rest", 0))
	assert_true(ShopEffects.pocket_rest())
	assert_eq(s.hp, s.max_hp())
	assert_eq(int(GameState.records.get("count_rest", 0)), rests, "counts for no daily task")
	var w := GridWalker.new()
	w.speed_mult = 2.0
	w.step("down", false)
	assert_almost_eq(w._duration, GridWalker.WALK_TIME / 2.0, 0.0001)
	w.free()

func test_journey_start_trio() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_starter_trio")
	assert_eq((o.grants as Array).size(), 3)
	for g: Dictionary in o.grants:
		assert_eq(str(g.t), "spirling")
		assert_eq(int(g.level), 15)
		var s: Spirling = ShopEffects.bought_spirling(g)
		assert_eq(s.level, 15)
		assert_true(s.shop_bought)
		for k: String in Spirling.STAT_KEYS:
			assert_eq(s.spark[k], Spirling.SPARK_MAX)

func test_pass_holder_meets_the_rarest_kind_once_a_day() -> void:
	var table: String = _rare_table()
	var rng := RandomNumberGenerator.new()
	var flags: Dictionary = {}
	Billing.state = {"pass_active": false}
	assert_null(ShopEffects.pass_rare(table, flags, rng, "2026-11-13"))
	Billing.state = {"pass_active": true}
	var s: Spirling = ShopEffects.pass_rare(table, flags, rng, "2026-11-13")
	assert_not_null(s)
	assert_eq(s.data.species_name, str(ShopEffects.pass_rare_spawn(table).species))
	assert_ne(s.data.rarity, "common")
	assert_null(ShopEffects.pass_rare(table, flags, rng, "2026-11-13"), "once a day")
	assert_not_null(ShopEffects.pass_rare(table, flags, rng, "2026-11-14"))

func test_power_note_is_for_adults_only() -> void:
	Billing.state = {"unlocks": {}, "band": 16}
	assert_eq(ShopEffects.next_power_line(), "")
	Billing.state = {"unlocks": {}, "band": 18}
	assert_eq(ShopEffects.next_power_line(), "Shop: Bond Head Start I adds 10 Power", "most Power per Riftglass")
	Billing.state = {"unlocks": {"bond_edge": 3}, "band": 18}
	assert_eq(ShopEffects.next_power_line(), "Shop: Power Seal I adds 5 Power", "a tie goes to the first tier offer")

func test_every_bond_offer_names_a_number() -> void:
	var regex := RegEx.create_from_string("[0-9]")
	for o: Dictionary in ShopCatalog.offers():
		var g: Array = o.grants
		if g.size() != 1 or str(g[0].get("t", "")) != "item":
			continue
		var it: Dictionary = Database.item(str(g[0].id))
		if float(it.get("bond_bonus", 0.0)) > 0.0 or bool(it.get("bond_wish", false)):
			assert_not_null(regex.search(str(o.desc)), "%s says how much" % o.id)
