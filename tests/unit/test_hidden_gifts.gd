extends GutTest
## Hidden gifts: one per line, revealed by a (sometimes stale) tip from the informant, woken and
## put back to sleep freely from the unlock ring on (plan items 4756-4758).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_every_line_has_a_known_hidden_gift() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var id: String = HiddenGifts.gift_id(sd)
		assert_false(HiddenGifts.gift(id).is_empty(), "hidden gift for " + sd.species_name)
		assert_false(BattleRules.TRAITS.has(id), "hidden gifts have their own ids")

func test_whole_line_shares_one_gift() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		assert_eq(HiddenGifts.gift_id(sd), HiddenGifts.gift_id(GameState.first_form(sd)), sd.species_name)

func test_gift_effects_use_known_keys() -> void:
	var keys: Array[String] = ["label", "text", "scorch_atk", "phys_taken", "regen_div", "energy_per_turn", "immune", "low_hp_boost", "super_taken", "countercurrent"]
	for id: String in HiddenGifts.data().gifts:
		for k: String in HiddenGifts.gift(id):
			assert_true(k in keys, id + " uses " + k)

func test_tip_reveals_or_goes_stale_and_costs_only_the_fee() -> void:
	var sd: SpirlingData = Database.species("Kindlop")
	var cost: int = int(HiddenGifts.data().tip_cost)
	var seen: Dictionary = {}
	for i: int in 30:
		GameState.records.erase(HiddenGifts.TIPS)
		GameState.money = cost
		var res: Dictionary = HiddenGifts.buy_tip(sd, _rng(i))
		assert_true(res.ok)
		assert_eq(GameState.money, 0)
		assert_eq(HiddenGifts.revealed(sd.line_id), not bool(res.stale))
		seen[res.stale] = true
	assert_eq(seen.size(), 2, "true and stale tips both happen")
	GameState.money = 0
	assert_false(HiddenGifts.buy_tip(sd, _rng(1)).ok)

func test_wake_needs_tip_and_ring_and_can_sleep_again() -> void:
	var low := Spirling.new(Database.species("Kindlop"), 5, _rng(1))
	var high := Spirling.new(Database.species("Smoldrake"), int(HiddenGifts.data().unlock_ring), _rng(2))
	assert_false(HiddenGifts.can_wake(high), "needs the tip first")
	HiddenGifts.reveal("kindlop")
	assert_false(HiddenGifts.can_wake(low), "needs the ring")
	assert_true(HiddenGifts.can_wake(high))
	assert_true(HiddenGifts.toggle(high))
	assert_eq(high.gift_id(), "smouldering_debt")
	assert_false(HiddenGifts.toggle(high))
	assert_eq(high.gift_id(), high.data.trait_id)

func test_awake_gift_works_in_battle_rules() -> void:
	var s := Spirling.new(Database.species("Smoldrake"), 30, _rng(3))
	assert_false(BattleRules.is_immune(s, "drowse"))
	s.hidden_gift = true
	assert_true(BattleRules.is_immune(s, "drowse"))
	assert_eq(str(BattleRules.trait_info(s.gift_id()).label), "Smouldering Debt")

func test_hidden_gift_survives_a_save() -> void:
	var s := Spirling.new(Database.species("Smoldrake"), 30, _rng(3))
	s.hidden_gift = true
	var back: Spirling = Spirling.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_true(back.hidden_gift)

func test_informant_on_corvane_quay() -> void:
	var m: MapData = MapData.load_map("corvane_quay")
	var found: bool = false
	for n: Dictionary in m.npcs:
		found = found or str(n.get("id", "")) == "informant"
	assert_true(found)
	assert_eq(str(Dialogue.get_entry("corvane_quay/informant").get("action", "")), "informant")

func test_german_for_every_gift_and_line() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	var d: Dictionary = HiddenGifts.data()
	var lines: Array = d.tip_lines.duplicate()
	lines.append_array([d.informant, d.true_tip, d.stale_tip])
	for id: String in d.gifts:
		lines.append_array([d.gifts[id].label, d.gifts[id].text])
	for line: Variant in lines:
		assert_true(de.has(str(line)), "German missing: " + str(line))
