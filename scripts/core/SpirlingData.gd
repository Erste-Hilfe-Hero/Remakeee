class_name SpirlingData
extends Resource
## Static species data loaded from data/spirlings.json. Never mutated at runtime.

const DEFAULT_BOND_RATE: float = 0.45

@export var dex_id: int
@export var species_name: String
@export var elements: Array[int] = []
@export var base_hp: int
@export var base_atk: int
@export var base_def: int
@export var base_foc: int
@export var base_spd: int
@export var evolves_to: SpirlingData
@export var evolve_level: int = 0
@export var bond_rate: float = DEFAULT_BOND_RATE
## Passive trait id (see BattleRules.TRAITS), or "".
@export var trait_id: String = ""
## Item that makes it evolve when used on it (Bag), or "". Works at any level.
@export var evolve_item: String = ""
## If set, the level evolution only happens after a battle in this map.
@export var evolve_map: String = ""
## Spirlog entry.
@export var lore: String = ""
@export var height: String = ""
@export var habitat: String = ""
## XP granted when defeated, before the level factor.
@export var xp_yield: int = 50
## Learnset as two parallel arrays (level, move), sorted by level.
@export var learnset_levels: PackedInt32Array = []
@export var learnset_moves: Array[MoveData] = []
## One sprite set per art era (era1..era4)
@export var sprites: Dictionary = {}

## Moves this species learns exactly at [param level].
func moves_learned_at(level: int) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for i: int in learnset_levels.size():
		if learnset_levels[i] == level:
			out.append(learnset_moves[i])
	return out

## The newest [param max_count] moves known at [param level] (what a fresh Spirling knows).
func default_moves(level: int, max_count: int) -> Array[MoveData]:
	var known: Array[MoveData] = []
	for i: int in learnset_levels.size():
		if learnset_levels[i] <= level and not known.has(learnset_moves[i]):
			known.append(learnset_moves[i])
	if known.size() <= max_count:
		return known
	var kept: Array[MoveData] = known.slice(known.size() - max_count)
	# The newest arts may all be status arts (late support picks); keep at least
	# MIN_DAMAGING_DEFAULT hits by swapping the oldest status art for the newest hit left out.
	var older: Array[MoveData] = known.slice(0, known.size() - max_count)
	older.reverse()
	for mv: MoveData in older:
		if _damaging_count(kept) >= MIN_DAMAGING_DEFAULT:
			break
		if not mv.is_damaging():
			continue
		for i: int in kept.size():
			if not kept[i].is_damaging():
				kept.remove_at(i)
				kept.insert(0, mv)
				break
	return kept

## A Spirling's default four (wild, Wayfarer teams) hold at least this many damage arts.
const MIN_DAMAGING_DEFAULT: int = 2

static func _damaging_count(list: Array[MoveData]) -> int:
	var n: int = 0
	for mv: MoveData in list:
		n += 1 if mv.is_damaging() else 0
	return n

func base_stat(key: String) -> int:
	match key:
		"hp": return base_hp
		"atk": return base_atk
		"def": return base_def
		"foc": return base_foc
		"spd": return base_spd
	return 0
