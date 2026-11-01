class_name BattleRules
extends RefCounted
## Data tables for battle depth: stat stages, passive traits, held items, Rift fields and
## Warden rules. Battle code reads these tables; nothing switches on ids elsewhere.

const STAGE_MIN: int = -3
const STAGE_MAX: int = 3
const STAGE_STATS: Array[String] = ["atk", "def", "foc", "spd"]

## Overcharge moves: each leftover Energy point adds this much to the power multiplier.
const OVERCHARGE_PER_ENERGY: float = 0.15

## Field (Rift resonance) multipliers for the boosted and the weakened element.
const FIELD_BOOST: float = 1.2
const FIELD_WEAKEN: float = 0.85

## Passive traits (one per species, in spirlings.json "trait"). Keys:
##   scorch_atk:    ATK multiplier while Scorched (replaces the usual drop)
##   phys_taken:    multiplier on physical damage taken
##   regen_div:     heal max_hp / regen_div at the end of each turn
##   energy_per_turn: extra Energy each turn
##   immune:        statuses that can't be applied
##   low_hp_boost:  damage multiplier for moves of its own element below 1/3 HP
const TRAITS: Dictionary[String, Dictionary] = {
	"kindling": {"label": "Kindling", "text": "Scorch raises its ATK instead of lowering it.", "scorch_atk": 1.25},
	"thick_hide": {"label": "Thick Hide", "text": "Takes 15% less damage from physical moves.", "phys_taken": 0.85},
	"deep_roots": {"label": "Deep Roots", "text": "Recovers a little HP at the end of each turn.", "regen_div": 16},
	"surge": {"label": "Surge", "text": "Gains 1 extra Energy each turn.", "energy_per_turn": 1},
	"steady": {"label": "Steady", "text": "Can't be Dazed.", "immune": ["daze"]},
	"slick": {"label": "Slick", "text": "Can't be Rooted.", "immune": ["root"]},
	"light_sleeper": {"label": "Light Sleeper", "text": "Can't be Drowsed.", "immune": ["drowse"]},
	"last_stand": {"label": "Last Stand", "text": "Its own element hits 30% harder below 1/3 HP.", "low_hp_boost": 1.3},
}

## Rift fields. A map sets "field"; every battle there uses it.
const FIELDS: Dictionary[String, Dictionary] = {
	"ash_storm": {"label": "Ash Storm", "boost": "EMBER", "weaken": "TIDE",
		"intro": "Ash swirls through the Rift. Ember moves burn brighter, Tide moves sputter."},
	"high_tide": {"label": "High Tide", "boost": "TIDE", "weaken": "EMBER",
		"intro": "The water rises around you. Tide moves surge, Ember moves fizzle."},
	"deep_murk": {"label": "Deep Murk", "boost": "UMBRA", "weaken": "LUMEN",
		"intro": "The hollow swallows the light. Umbra moves deepen, Lumen moves dim."},
}

## Warden rules (npc "rule"). foe_energy: extra Energy per turn for the Warden's side;
## player_stage: stat stages every player Spirling starts with.
const RULES: Dictionary[String, Dictionary] = {
	"ember_pulse": {"label": "Ember Pulse", "text": "Orrin's Spirlings gain 1 extra Energy every turn.", "foe_energy": 1},
	"undertow": {"label": "Undertow", "text": "The current drags at you: your Spirlings start with lower SPD.", "player_stage": {"spd": -1}},
}

static func stage_mult(stage: int) -> float:
	var s: int = clampi(stage, STAGE_MIN, STAGE_MAX)
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)

static func trait_info(id: String) -> Dictionary:
	return TRAITS.get(id, {})

## The "held" block of an item, or {} if it can't be held.
static func held_info(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	var h: Variant = Database.item(item_id).get("held", {})
	return h if h is Dictionary else {}

static func is_holdable(item_id: String) -> bool:
	return not held_info(item_id).is_empty()

## Sum of a numeric key over a Spirling's trait and held item (for additive keys).
static func add_key(s: Spirling, key: String) -> float:
	return float(trait_info(s.data.trait_id).get(key, 0.0)) + float(held_info(s.held).get(key, 0.0))

## Product of a multiplier key over trait and held item.
static func mult_key(s: Spirling, key: String) -> float:
	return float(trait_info(s.data.trait_id).get(key, 1.0)) * float(held_info(s.held).get(key, 1.0))

static func is_immune(s: Spirling, status: String) -> bool:
	return status in trait_info(s.data.trait_id).get("immune", [])

static func field_mult(field: String, element: int) -> float:
	var f: Dictionary = FIELDS.get(field, {})
	if f.is_empty():
		return 1.0
	if element == Elements.E.get(str(f.boost), -1):
		return FIELD_BOOST
	if element == Elements.E.get(str(f.weaken), -1):
		return FIELD_WEAKEN
	return 1.0

## Damage multiplier from traits, held items and the field for one hit.
static func damage_mult(user: Spirling, target: Spirling, move: MoveData, field: String) -> float:
	var m: float = field_mult(field, move.element)
	if move.kind == MoveData.Kind.PHYSICAL:
		m *= mult_key(target, "phys_taken")
	var boost: float = float(trait_info(user.data.trait_id).get("low_hp_boost", 1.0))
	if boost != 1.0 and move.element in user.elements() and user.hp * 3 < user.max_hp():
		m *= boost
	return m
