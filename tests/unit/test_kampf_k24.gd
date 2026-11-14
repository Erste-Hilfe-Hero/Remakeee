extends GutTest
## KAMPF_PLAN_1000 Energy items 50 (most Energy per kind), 64 (Energy lesson), 67 (bench regen),
## 72 (bigger pips in one-hand mode), 73 (Energy flows back after a Rest), 74 (Damp Sparks) and
## 77 (Sunk Cost grows with the Energy spent).

const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	Loc.set_language("en")
	EnergyKit._data = {}

## Item 50 ships with no role in data/kampf_energy.json (the roles wait for a balance pass), so
## these tests lend the rule a Weaver +2 and Vanguard +1.
func _with_roles() -> void:
	var d: Dictionary = EnergyKit.data().duplicate(true)
	d["role_cap"] = {"weaver": 2, "vanguard": 1}
	EnergyKit._data = d

func _duel(mine: Array[Spirling], theirs: Array[Spirling], variants: Array[String] = []) -> BattleModel:
	var m := BattleModel.new(mine, theirs, true, 5, 0)
	m.items_allowed = false
	m.variants = variants
	m.start()
	return m

# --- 50 ---------------------------------------------------------------------------------------

func test_role_sets_the_most_energy_from_10_to_12() -> void:
	_with_roles()
	assert_eq(EnergyKit.cap_of(BattleFixtures.make("Kindlop", 20)), 10, "kindler")
	assert_eq(EnergyKit.cap_of(BattleFixtures.make("Puddlet", 20)), 11, "vanguard")
	assert_eq(EnergyKit.cap_of(BattleFixtures.make("Kelpup", 20)), 12, "weaver")
	for sd: SpirlingData in Database.spirlings.values():
		var c: int = Spirling.MAX_ENERGY + EnergyKit.role_bonus(sd.role)
		assert_between(c, 10, 12, sd.species_name)

func test_weaver_starts_at_10_and_rests_up_to_12() -> void:
	_with_roles()
	var me: Spirling = BattleFixtures.make("Kelpup", 20, ["Bowl Over"])
	var m: BattleModel = _duel([me] as Array[Spirling], [BattleFixtures.make("Mossling", 20, ["Bowl Over"])] as Array[Spirling])
	assert_eq(me.energy, Spirling.START_ENERGY, "the start stays 10")
	assert_eq(m.energy_cap_of(BattleModel.Side.PLAYER, me), 12)
	m.change_energy(BattleModel.Side.PLAYER, 9)
	assert_eq(me.energy, 12)
	var plain: Spirling = m.active_spirling(BattleModel.Side.FOE)
	m.change_energy(BattleModel.Side.FOE, 9)
	assert_eq(plain.energy, 10, "a bulwark holds 10")

func test_rules_book_names_the_roles_and_the_bench() -> void:
	_with_roles()
	var text: String = "\n".join(RulesBook.energy())
	assert_string_contains(text, "Weaver kinds hold 2 more Energy (12 in all).")
	assert_string_contains(text, "waits on the bench")

# --- 67 ---------------------------------------------------------------------------------------

func test_bench_gains_energy_only_after_it_fought() -> void:
	var lead: Spirling = BattleFixtures.make("Kindlop", 20, ["Bowl Over"])
	var second: Spirling = BattleFixtures.make("Talusk", 20, ["Bowl Over"])
	var m: BattleModel = _duel([lead, second] as Array[Spirling], [BattleFixtures.make("Mossling", 20, ["Bowl Over"])] as Array[Spirling])
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	second.energy = 4
	assert_eq(EnergyKit.bench_tick(m), 0, "the second never stood in front")
	assert_eq(second.energy, 4)
	m.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	lead.energy = 3
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(lead.energy, 3 + int(EnergyKit.num("bench_regen", 1.0)), "+1 on the bench")
	lead.energy = 10
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(lead.energy, 10, "never above its cap")

# --- 74 ---------------------------------------------------------------------------------------

func test_damp_sparks_drains_a_soaked_spirling() -> void:
	assert_true(BattleRules.validate_variants().is_empty(), str(BattleRules.validate_variants()))
	assert_eq(int(BattleRules.variant_values(["damp_sparks"] as Array[String]).get("soak_drain", 0)), 2)
	var foe: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var m: BattleModel = _duel([BattleFixtures.make("Kindlop", 20, ["Bowl Over"])] as Array[Spirling], [foe] as Array[Spirling], ["damp_sparks"] as Array[String])
	foe.status = "soak"
	foe.status_turns = 3
	foe.energy = 6
	var said: bool = false
	for e: BattleEvent in m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1)):
		if e.type == T.TECHNIQUE and e.describe().begins_with("The water seeps into"):
			said = true
	assert_true(said, "the log says so")
	assert_eq(foe.energy, 6 + BattleModel.REST_ENERGY + BattleModel.ENERGY_PER_TURN - 2)

func test_no_drain_without_the_variant() -> void:
	var foe: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var m: BattleModel = _duel([BattleFixtures.make("Kindlop", 20, ["Bowl Over"])] as Array[Spirling], [foe] as Array[Spirling])
	foe.status = "soak"
	foe.status_turns = 3
	foe.energy = 6
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(foe.energy, 6 + BattleModel.REST_ENERGY + BattleModel.ENERGY_PER_TURN)

# --- 77 ---------------------------------------------------------------------------------------

func test_spent_mult_grows_and_stops() -> void:
	assert_almost_eq(EnergyKit.spent_mult(0), 1.0, 0.0001)
	assert_almost_eq(EnergyKit.spent_mult(10), 1.0 + 10.0 * EnergyKit.num("spent_per", 0.04), 0.0001)
	assert_almost_eq(EnergyKit.spent_mult(999), EnergyKit.spent_mult(int(EnergyKit.num("spent_max", 15.0))), 0.0001)

func test_sunk_cost_counts_the_energy_paid() -> void:
	var mv: MoveData = Database.move("Sunk Cost")
	assert_not_null(mv)
	assert_true(mv.spent_scale)
	var me: Spirling = BattleFixtures.make("Kelpup", 30, ["Sunk Cost", "Bowl Over"])
	var m: BattleModel = _duel([me] as Array[Spirling], [BattleFixtures.make("Talusk", 30, ["Bowl Over"])] as Array[Spirling])
	m.submit_turn(BattleAction.make_move(0, 1), BattleAction.make_rest(1))
	assert_eq(EnergyKit.spent_of(m, me), Database.move("Bowl Over").energy_cost)
	assert_almost_eq(CommandMenu.overcharge_now(m, me, mv), EnergyKit.spent_mult(EnergyKit.spent_of(m, me)), 0.0001)
	assert_gt(CommandMenu.overcharge_now(m, me, mv), 1.0, "the menu shows the growth")

func test_sunk_cost_hits_harder_after_spending() -> void:
	var dmg: Array[int] = []
	for spent: int in [0, 10]:
		var me: Spirling = BattleFixtures.make("Kelpup", 30, ["Sunk Cost"])
		var foe: Spirling = BattleFixtures.make("Talusk", 30, ["Bowl Over"])
		var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
		EnergyKit.note_spent(m, me, spent)
		var full: int = foe.hp
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		dmg.append(full - foe.hp)
	assert_gt(dmg[1], dmg[0])

func test_hesper_sells_sunk_cost_and_its_card_explains_it() -> void:
	var shop: String = str(Dialogue.get_entry("lighthouse/hesper").get("action", ""))
	assert_string_contains(shop, " echo_sunk_cost")
	assert_eq(str(Database.items["echo_sunk_cost"].get("teaches", "")), "Sunk Cost")
	assert_has(ArtsSim.ARTS, "Sunk Cost")
	var info: String = CommandMenu.move_info(Database.move("Sunk Cost"))
	assert_string_contains(info, "for each Energy spent on arts this battle")
	Loc.set_language("de")
	assert_string_contains(CommandMenu.move_info(Database.move("Sunk Cost")), "ausgegebene Energie")

# --- 72, 73 -----------------------------------------------------------------------------------

func test_shipped_data_keeps_every_kind_at_10() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		assert_eq(Spirling.MAX_ENERGY + EnergyKit.role_bonus(sd.role), Spirling.MAX_ENERGY, sd.species_name)

func test_one_hand_mode_draws_bigger_pips() -> void:
	assert_eq(EnergyKit.pip_size(2.0, false), 2.0)
	assert_eq(EnergyKit.pip_size(2.0, true), EnergyKit.num("one_hand_pip", 3.0))
	assert_gt(EnergyKit.pip_size(2.0, true), 2.0)
	assert_eq(EnergyKit.pip_size(5.0, true), 5.0, "never smaller than the era's own")

func test_rest_fills_the_pips_one_after_another() -> void:
	var step: float = 0.1
	assert_eq(EnergyKit.flow_lit(4, 7, 0.0, step), 5, "the first gained pip at once")
	assert_eq(EnergyKit.flow_lit(4, 7, 0.15, step), 6)
	assert_eq(EnergyKit.flow_lit(4, 7, 5.0, step), 7, "never more than the new value")
	assert_eq(EnergyKit.flow_lit(7, 4, 0.0, step), 4, "a loss does not flow")
	assert_almost_eq(EnergyKit.flow_time(4, 7), 3.0 * EnergyKit.num("rest_flow_step", 0.12), 0.0001)
	var look: Dictionary = InfoStrip.flow_look(5, 4, 6)
	assert_true(bool(look.fill))
	assert_eq(int(look.grow), 1, "the newest pip pops")
	assert_false(bool(InfoStrip.flow_look(6, 4, 6).fill), "the next one still waits")

func test_strip_shows_as_many_pips_as_the_kind_holds() -> void:
	var strip := InfoStrip.new()
	strip.set_spirling(BattleFixtures.make("Kelpup", 20))
	assert_eq(strip.energy_cap, 10, "no role holds more in the shipped data")
	_with_roles()
	strip.set_spirling(BattleFixtures.make("Kelpup", 20))
	assert_eq(strip.energy_cap, 12)
	strip.free()

# --- 64 ---------------------------------------------------------------------------------------

func test_energy_lesson_comes_when_it_is_needed() -> void:
	var low := BattleEvent.new(T.ENERGY_CHANGED, {"side": BattleModel.Side.PLAYER, "energy": 2})
	assert_eq(BattleInfo.tip_for(low), "energy_low")
	assert_eq(BattleInfo.tip_for(BattleEvent.new(T.ENERGY_CHANGED, {"side": BattleModel.Side.PLAYER, "energy": 8})), "")
	assert_eq(BattleInfo.tip_for(BattleEvent.new(T.ENERGY_CHANGED, {"side": BattleModel.Side.FOE, "energy": 1})), "", "not for the foe")
	assert_eq(BattleInfo.tip_for(BattleEvent.new(T.REST, {"side": BattleModel.Side.PLAYER})), "energy_rest")
	for id: String in ["energy_low", "energy_rest"]:
		assert_true(Tips.LINES.has(id) and Tips.TOPICS.has(id), id)
		assert_lte(Tips.LINES[id].size(), Tips.MAX_LINES)
	Loc.set_language("de")
	assert_ne(Loc.t(Tips.lines_of("energy_rest", true)[0]), Tips.lines_of("energy_rest", true)[0], "German")
