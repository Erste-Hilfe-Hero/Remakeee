class_name BattleFixtures
extends RefCounted
## Shared builders for battle tests.

## A Spirling with fixed Spark 8 in every stat, so tests do not depend on random Spark rolls.
static func make(species: String, level: int, move_names: Array[String] = []) -> Spirling:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var s := Spirling.new(Database.species(species), level, rng)
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = 8
	s.hp = s.max_hp()
	if not move_names.is_empty():
		s.moves.clear()
		for n: String in move_names:
			s.moves.append(Database.move(n))
	return s

## A synthetic species with every base stat = [param base] and the given elements.
static func balanced_species(base: int, elements: Array[int]) -> SpirlingData:
	var sd := SpirlingData.new()
	sd.species_name = "Testling"
	sd.elements = elements
	sd.base_hp = base
	sd.base_atk = base
	sd.base_def = base
	sd.base_foc = base
	sd.base_spd = base
	return sd

static func from_species(sd: SpirlingData, level: int) -> Spirling:
	var s := Spirling.new()
	s.data = sd
	s.level = level
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = 8
	s.hp = s.max_hp()
	return s

## A move built in code (not from JSON).
static func move(element: int, power: int, kind: MoveData.Kind = MoveData.Kind.PHYSICAL) -> MoveData:
	var m := MoveData.new()
	m.move_name = "Test Move"
	m.element = element
	m.power = power
	m.kind = kind
	m.accuracy = 1.0
	m.energy_cost = 2
	return m

static func model(mine: Array[Spirling], theirs: Array[Spirling], wild: bool = true, seed_value: int = 7, ai_level: int = 0) -> BattleModel:
	var m := BattleModel.new(mine, theirs, wild, seed_value, ai_level)
	m.start()
	return m

static func types_of(events: Array[BattleEvent]) -> Array[int]:
	var out: Array[int] = []
	for e: BattleEvent in events:
		out.append(e.type)
	return out

static func first_of(events: Array[BattleEvent], t: BattleEvent.Type) -> BattleEvent:
	for e: BattleEvent in events:
		if e.type == t:
			return e
	return null
