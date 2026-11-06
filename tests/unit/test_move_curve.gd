extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 575, 840-845, 848): data rules for
## every art, a fuzz run over the new arts, and replays with snares and cooldowns.

## Value factors for the curve check: a drawback lets an art be stronger for its cost, an extra
## effect makes it weaker. Damage arts land between CURVE_MIN and CURVE_MAX after the factor.
const CURVE_MIN: float = 9.0
const CURVE_MAX: float = 18.0
const FACTOR: Dictionary = {
	"priority_low": 0.75, "cooldown": 0.85, "self_stage_after": 0.9, "recoil": 0.85,
	"priority_high": 1.0, "foes": 1.15, "status": 1.1, "stage": 1.1, "bonus_vs_status": 1.15,
	"drain": 1.2, "energy_drain": 1.2, "energy_burn": 1.15, "field_element": 1.1, "ignore_stages": 1.1,
	"cure_target": 1.0, "delayed_hit": 0.8,
}

func before_all() -> void:
	Database.load_all()

## The new arts of plan area 2 (the ones without a learnset in the original roster).
const NEW_ARTS: Array[String] = [
	"Glow Knuckle", "Char Mark", "Spout Jab", "Deepwell Draught", "Pollen Prick", "Static Tag", "Grid Lock",
	"Grit Jab", "Crosswind", "Kite Cut", "Scatter Gale", "Beacon Ping", "Dawn Needle", "Shade Pounce",
	"Gloom Handoff", "Quarry Wall", "Landslip", "Shard Bed", "Monolith Drop", "Pumice Pelt", "Fault Line",
	"Downburst", "Draft Needle", "Squall Line", "Cloudbreak", "Capacitor Crash", "Pylon Snap", "Short Circuit",
	"Bellows Blast", "Coal Seed", "Furnace Heart", "Cinder Dash", "Brazier Pulse", "Salt Spray", "Rip Current",
	"Fathom Crush", "Bore Wave", "Shoal Trap", "Bramble Bed", "Wildgrowth Crash", "Husk Shed", "Thornwake",
	"Bark Burst", "Seed Spit", "Graft", "Overdraw", "Wire Trap", "Lull Breaker", "Chaff Feint", "Gale Mantle",
	"Sunwell Sip", "Daybreak Strike", "Prism Burst", "Starlit Lash", "Glow Trap", "Night Toll", "Eclipse Crush",
	"Murmur Bite", "Veil Step", "Gloam Pact", "Dusk Snare", "Gravel Hum", "Slow Quake", "Omen Bell",
]

func _factor(mv: MoveData) -> float:
	var f: float = 1.0
	if mv.priority < 0:
		f *= FACTOR.priority_low
	elif mv.priority > 0:
		f *= FACTOR.priority_high
	if mv.cooldown > 0:
		f *= FACTOR.cooldown
	if mv.is_area():
		f *= FACTOR.foes
	if mv.ignore_stages:
		f *= FACTOR.ignore_stages
	for fx: Dictionary in mv.effects:
		var id: String = str(fx.get("id", ""))
		match id:
			"inflict_status": f *= FACTOR.status
			"stat_change": f *= FACTOR.stage if bool(fx.get("self", true)) == (int(fx.get("amount", 1)) > 0) else FACTOR.self_stage_after
			_:
				if FACTOR.has(id):
					f *= float(FACTOR[id])
	return f

func test_every_damage_art_sits_on_the_curve() -> void:
	for mv: MoveData in Database.moves.values():
		if not mv.is_damaging() or mv.overcharge:
			continue
		var value: float = float(mv.power) * mv.accuracy / float(mv.energy_cost + 1) * _factor(mv)
		assert_between(value, CURVE_MIN, CURVE_MAX, "%s: power x accuracy / (energy + 1) x %0.2f = %0.1f" % [mv.move_name, _factor(mv), value])

func test_accuracy_and_status_chances_stay_fair() -> void:
	for mv: MoveData in Database.moves.values():
		assert_gte(mv.accuracy, 0.75, mv.move_name)
		if mv.is_damaging():
			for fx: Dictionary in mv.effects:
				if StringName(fx.get("id", "")) == &"inflict_status":
					assert_lte(float(fx.get("chance", 1.0)), 0.3, "%s: a damage art lands its status at most 30%% of the time" % mv.move_name)

func test_cooldown_arts_are_big_hits() -> void:
	for mv: MoveData in Database.moves.values():
		if mv.cooldown > 0:
			assert_gte(mv.power, 110, mv.move_name)
			assert_gte(mv.energy_cost, 7, mv.move_name)

func test_every_element_has_a_full_kit() -> void:
	for e: int in Elements.E.values():
		var all: int = 0
		var status: int = 0
		var cheap: int = 0
		for mv: MoveData in Database.moves.values():
			if mv.element != e:
				continue
			all += 1
			status += 1 if mv.kind == MoveData.Kind.STATUS else 0
			cheap += 1 if mv.energy_cost <= 2 else 0
		var n: String = Elements.E.keys()[e]
		assert_gte(all, 14, "%s has at least 14 arts" % n)
		assert_gte(status, 3, "%s has at least 3 status arts" % n)
		assert_gte(cheap, 1, "%s has an art for 1 or 2 Energy" % n)

func test_every_species_has_an_early_own_hit_and_two_elements_by_30() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var early: bool = false
		var elems: Dictionary = {}
		for i: int in sd.learnset_levels.size():
			var mv: MoveData = sd.learnset_moves[i]
			var lv: int = sd.learnset_levels[i]
			if lv <= 5 and mv.is_damaging() and mv.element in sd.elements:
				early = true
			if lv <= 30:
				elems[mv.element] = true
		# An evolved form starts at its evolve level; its early hit comes from the base form.
		var base_form: bool = BalanceSim.stage(sd) == 1
		if base_form:
			assert_true(early, "%s has a damage art of its own element by ring 5" % sd.species_name)
		assert_gte(elems.size(), 2, "%s knows arts of at least 2 elements by ring 30" % sd.species_name)

func test_learnsets_stay_at_most_14() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var seen: Dictionary = {}
		for mv: MoveData in sd.learnset_moves:
			seen[mv.move_name] = true
		assert_lte(seen.size(), 14, sd.species_name)

func test_fuzz_new_arts_only() -> void:
	var species: Array = Database.spirlings.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = 845
	var capped: int = 0
	for i: int in 300:
		var teams: Array[Array] = [[], []]
		for side: int in 2:
			for k: int in 2:
				var s := Spirling.new(Database.species(str(species[rng.randi_range(0, species.size() - 1)])), rng.randi_range(10, 50), rng)
				# Like a default kit, every Spirling carries at least two damage arts.
				var picks: Array[MoveData] = []
				while picks.size() < 4:
					var mv: MoveData = Database.move(NEW_ARTS[rng.randi_range(0, NEW_ARTS.size() - 1)])
					var hits: int = picks.filter(func(x: MoveData) -> bool: return x.is_damaging()).size()
					if picks.has(mv) or (not mv.is_damaging() and picks.size() - hits >= 2):
						continue
					picks.append(mv)
				s.moves = picks
				teams[side].append(s)
		var mine: Array[Spirling] = []
		mine.assign(teams[0])
		var theirs: Array[Spirling] = []
		theirs.assign(teams[1])
		var m := BattleModel.new(mine, theirs, false, rng.randi(), 2)
		m.items_allowed = false
		m.field = ["", "ash_storm", "static_veil", "pollen_drift"][i % 4]
		m.start()
		var brain := BattleAI.new(2)
		var turns: int = 0
		while not m.is_finished() and turns < 60:
			if m.needs_player_switch():
				m.submit_switch(m.swap_candidates(0, m.switch_slot())[0])
				continue
			m.submit_turn(brain.choose(m, 0))
			turns += 1
		if not m.is_finished():
			capped += 1
	assert_eq(capped, 0, "no battle with only new arts hits the 60-turn cap")

func _replay_round_trip(player: Array[Spirling], foe: Array[Spirling], seed_value: int) -> void:
	var m := BattleModel.new(player, foe, false, seed_value, 2)
	m.items_allowed = false
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "lake")
	var brain := BattleAI.new(2)
	var lines: Array[String] = []
	m.event_emitted.connect(func(e: BattleEvent) -> void: lines.append(e.describe()))
	m.start()
	var inputs: Array = []
	var guard: int = 0
	while not m.is_finished() and guard < 80:
		guard += 1
		if m.needs_player_switch():
			var idx: int = m.swap_candidates(0, m.switch_slot())[0]
			inputs.append(BattleReplay.switch_to_dict(idx))
			m.submit_switch(idx)
			continue
		var a: BattleAction = brain.choose(m, 0)
		inputs.append(BattleReplay.action_to_dict(a))
		m.submit_turn(a)
	snap["inputs"] = inputs
	snap = JSON.parse_string(JSON.stringify(snap))
	var again: BattleModel = BattleReplay.build_model(snap)
	var lines2: Array[String] = []
	again.event_emitted.connect(func(e: BattleEvent) -> void: lines2.append(e.describe()))
	assert_eq(BattleReplay.simulate(snap), m.outcome)
	# simulate builds its own model; play it once more on ours to compare every line.
	again.start()
	for v: Variant in snap.inputs:
		if again.is_finished():
			break
		var d: Dictionary = v
		if str(d.get("t", "")) == "switch":
			again.submit_switch(int(d.get("i", 0)))
		else:
			again.submit_turn(BattleReplay.action_from_dict(d))
	assert_eq(lines2, lines, "the replay tells the same story, line by line")

func test_snares_and_cooldowns_replay_exactly() -> void:
	var p: Array[Spirling] = [BattleFixtures.make("Obsidroth", 44, ["Shard Bed", "Monolith Drop", "Dusk Snare", "Grit Jab"] as Array[String]),
		BattleFixtures.make("Zephlet", 40, ["Scatter Gale", "Kite Cut", "Crosswind", "Draft Needle"] as Array[String])]
	var f: Array[Spirling] = [BattleFixtures.make("Calderox", 44, ["Coal Seed", "Furnace Heart", "Cinder Dash", "Char Mark"] as Array[String]),
		BattleFixtures.make("Riptail", 40, ["Shoal Trap", "Fathom Crush", "Rip Current", "Spout Jab"] as Array[String])]
	_replay_round_trip(p, f, 4242)

func test_delayed_hits_replay_exactly() -> void:
	var p: Array[Spirling] = [BattleFixtures.make("Lumenewt", 40, ["Omen Bell", "Prism Ray", "Shard Bed", "Daybreak Strike"] as Array[String]),
		BattleFixtures.make("Zephlet", 40, ["Scatter Gale", "Kite Cut", "Crosswind", "Draft Needle"] as Array[String])]
	var f: Array[Spirling] = [BattleFixtures.make("Calderox", 40, ["Coal Seed", "Furnace Heart", "Cinder Dash", "Omen Bell"] as Array[String]),
		BattleFixtures.make("Riptail", 40, ["Shoal Trap", "Fathom Crush", "Rip Current", "Spout Jab"] as Array[String])]
	_replay_round_trip(p, f, 451)

func test_one_cooldown_art_and_one_snare_per_species_at_most() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		var cooldowns: Dictionary = {}
		var snares: Dictionary = {}
		for mv: MoveData in sd.learnset_moves:
			if mv.cooldown > 0:
				cooldowns[mv.move_name] = true
			for fx: Dictionary in mv.effects:
				if StringName(fx.get("id", "")) == &"side_snare":
					snares[mv.move_name] = true
		assert_lte(cooldowns.size(), 1, "%s: %s" % [sd.species_name, cooldowns.keys()])
		assert_lte(snares.size(), 1, "%s: %s" % [sd.species_name, snares.keys()])
