class_name SpirlingData
extends Resource
## Static species data loaded from data/spirlings.json. Never mutated at runtime.

const DEFAULT_BOND_RATE: float = 0.45
## Rarity tiers (plan area 1, items 130-133): bond rate band and encounter weight band per tier.
## Ancient Spirlings (the First Voices) never appear in random encounter tables.
const RARITIES: Array[String] = ["common", "uncommon", "shy", "ancient"]
const BOND_RATE_BANDS: Dictionary[String, Vector2] = {
	"common": Vector2(0.45, 0.55), "uncommon": Vector2(0.25, 0.35),
	"shy": Vector2(0.08, 0.15), "ancient": Vector2(0.03, 0.05),
}
const WEIGHT_BANDS: Dictionary[String, Vector2i] = {
	"common": Vector2i(25, 45), "uncommon": Vector2i(10, 24), "shy": Vector2i(2, 9),
}
## Base stat total allowed per rarity (data check in test_spirling_data.gd).
const STAT_TOTAL_BANDS: Dictionary[String, Vector2i] = {
	"common": Vector2i(260, 470), "uncommon": Vector2i(260, 520),
	"shy": Vector2i(260, 520), "ancient": Vector2i(520, 640),
}
const REGIONS: Array[String] = ["veydal", "corvane", "ashmere", "solenne", "vellmarch", "quillmarch", "halcyra"]
const ROLES: Array[String] = ["vanguard", "bulwark", "weaver", "striker", "kindler"]
## Unfold (unfurl) rules, see Spirling.unfold_ready().
const UNFOLD_RULES: Array[String] = ["ring", "item", "map_pages", "mended", "time", "echo_streak"]

@export var dex_id: int
@export var species_name: String
@export var elements: Array[int] = []
@export var base_hp: int
@export var base_atk: int
@export var base_def: int
@export var base_foc: int
@export var base_spd: int
@export var rarity: String = "common"
@export var region: String = "veydal"
@export var role: String = ""
## The first two marks of its Echo call (0..2, never the same twice), so meeting a kind again
## sounds familiar (plan area 1, item 278).
@export var cry_motif: Array[int] = []
## Held item id that suits this kind, shown in storage as "Suits it: ..." (item 355).
@export var keepsake_hint: String = ""
## Regional imprints (items 218-219): [{"region", "elements": [Elements.E], "palette", "lore",
## "trait"}]. A Veydal kind that lives long in another region shows this form there, without
## a new Spirlog number. The chosen one is stored in Spirling.variant (the region id).
@export var variants: Array[Dictionary] = []
## One line about where this kind comes from (Spirlog).
@export var origin: String = ""
## Id of the unfold line this kind belongs to (the first form's name in lower case).
@export var line_id: String = ""
## Unfold paths: [{"to": SpirlingData, "rule": String, "value": Variant, "map": String}].
## A kind can have more than one path. The first path also fills evolves_to and friends below,
## which older code and tests still read.
@export var unfold: Array[Dictionary] = []
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
## Art era this species comes from; its sprite keeps that era's look in every region.
@export var era: int = 1
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
