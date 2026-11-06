class_name BattleRules
extends RefCounted
## Data tables for battle depth: stat stages, passive traits, held items, Rift fields and
## Warden rules. Battle code reads these tables; nothing switches on ids elsewhere.

const STAGE_MIN: int = -3
const STAGE_MAX: int = 3
const STAGE_STATS: Array[String] = ["atk", "def", "foc", "spd"]

## Overcharge moves: each leftover Energy point adds this much to the power multiplier.
const OVERCHARGE_PER_ENERGY: float = 0.12
## At most this much leftover Energy goes into one Overcharge (the rest stays).
const OVERCHARGE_MAX_EXTRA: int = 5

## Energy tax (energy_tax effect): extra Energy per move, and how many turns a tax holds by default.
const ENERGY_TAX_COST: int = 1
const ENERGY_TAX_TURNS: int = 2
## field_element moves: power added while they take the active field's element.
const FIELD_ELEMENT_POWER: int = 20
## Most snares (side_snare) that can lie on one side at once.
const MAX_SNARES: int = 3
## Turns a heal_block holds by default.
const HEAL_BLOCK_TURNS: int = 3
## After an energy_burn the target can't be burned again for this many turns.
const BURN_GUARD_TURNS: int = 1
## Long fights: from this turn on nobody heals in battle any more (arts, gifts, fields, keepsakes),
## so two Spirlings that mend faster than they hurt each other can't stall forever.
const WEARY_TURN: int = 40

## Short tag for a snare, shown under the bench row: "SC" for a Scorch snare, "-SP" for a Pace
## drop, "HP" for a Vigor cut.
static func snare_tag(snare: Dictionary) -> String:
	if not str(snare.get("status", "")).is_empty():
		return str(snare.status).substr(0, 2).to_upper()
	var st: Variant = snare.get("stage", {})
	if st is Dictionary and not (st as Dictionary).is_empty():
		var k: String = str((st as Dictionary).keys()[0])
		return ("+" if int(st[k]) > 0 else "-") + k.substr(0, 2).to_upper()
	return "HP"

## Field (Rift resonance) multipliers for the boosted and the weakened element.
const FIELD_BOOST: float = 1.2
const FIELD_WEAKEN: float = 0.85
## A Resonance move (moves.json "field") lays its field for this many turns; then the place's
## own field (or none) comes back.
const RESONANCE_TURNS: int = 5

## Passive traits (one per species, in spirlings.json "trait"). Keys:
##   scorch_atk:    ATK multiplier while Scorched (replaces the usual drop)
##   phys_taken:    multiplier on physical damage taken
##   regen_div:     heal max_hp / regen_div at the end of each turn
##   energy_per_turn: extra Energy each turn
##   immune:        statuses that can't be applied
##   low_hp_boost:  damage multiplier for moves of its own element below 1/3 HP
const TRAITS: Dictionary[String, Dictionary] = {
	"kindling": {"label": "Kindling", "text": "Scorch raises its Might instead of lowering it.", "scorch_atk": 1.25},
	"thick_hide": {"label": "Thick Hide", "text": "Takes 15% less damage from physical arts.", "phys_taken": 0.85},
	"deep_roots": {"label": "Deep Roots", "text": "Recovers a little Vigor at the end of each turn.", "regen_div": 16},
	"surge": {"label": "Surge", "text": "Gains 1 extra Energy each turn.", "energy_per_turn": 1},
	"steady": {"label": "Steady", "text": "Can't be Dazed.", "immune": ["daze"]},
	"slick": {"label": "Slick", "text": "Can't be Rooted.", "immune": ["root"]},
	"light_sleeper": {"label": "Light Sleeper", "text": "Can't be Drowsed.", "immune": ["drowse"]},
	"last_stand": {"label": "Last Stand", "text": "Its own element hits 30% harder below 1/3 Vigor.", "low_hp_boost": 1.3},
}

## Rift fields. A map sets "field"; every battle there uses it. A Resonance move lays one for a
## few turns. Optional keys:
##   blocks:        statuses that can't take hold while the field lasts
##   regen_element: Spirlings of this element heal max_hp / regen_div at the end of each turn
const FIELDS: Dictionary[String, Dictionary] = {
	"ash_storm": {"label": "Ash Storm", "boost": "EMBER", "weaken": "TIDE",
		"intro": "Ash swirls through the Rift. Ember arts burn brighter, Tide arts sputter."},
	"high_tide": {"label": "High Tide", "boost": "TIDE", "weaken": "EMBER", "blocks": ["scorch"],
		"intro": "The water rises around you. Tide arts surge, Ember arts fizzle, and nothing catches fire."},
	"deep_murk": {"label": "Deep Murk", "boost": "UMBRA", "weaken": "LUMEN",
		"intro": "The hollow swallows the light. Umbra arts deepen, Lumen arts dim."},
	"static_veil": {"label": "Static Veil", "boost": "VOLT", "weaken": "STONE",
		"intro": "The air crackles. Volt arts snap harder, Stone arts crumble."},
	"pollen_drift": {"label": "Pollen Drift", "boost": "BLOOM", "weaken": "GALE", "regen_element": "BLOOM", "regen_div": 16,
		"intro": "Pollen drifts through the Rift. Bloom arts flourish and Bloom Spirlings mend, Gale arts stall."},
	"dawn_glow": {"label": "Dawn Glow", "boost": "LUMEN", "weaken": "UMBRA",
		"intro": "A pale dawn fills the Rift. Lumen arts shine, Umbra arts thin out."},
}

## Element reactions: a move of "element" that hits a foe with "status" either hits harder
## ("mult") or washes the status away after the hit ("cure").
const REACTIONS: Array[Dictionary] = [
	{"element": "VOLT", "status": "soak", "mult": 1.2, "text": "The charge races through the soaked %s!"},
	{"element": "TIDE", "status": "scorch", "cure": true, "text": "The water douses the embers on %s!"},
]

## The reaction a [param move] sets off on [param target], or {}.
static func reaction(move: MoveData, target: Spirling) -> Dictionary:
	if target == null or target.status.is_empty() or not move.is_damaging():
		return {}
	for r: Dictionary in REACTIONS:
		if move.element == Elements.E.get(str(r.element), -1) and target.status == str(r.status):
			return r
	return {}

## True while [param field] keeps [param status] from taking hold.
static func field_blocks(field: String, status: String) -> bool:
	return status in FIELDS.get(field, {}).get("blocks", [])

## Warden rules (npc "rule"). foe_energy: extra Energy per turn for the Warden's side;
## player_stage: stat stages every player Spirling starts with.
## The Story forms (items 671, 674): foe_energy_every gives the extra Energy only every N-th turn,
## lead_only puts the player stages on the player's first Spirling alone.
const RULES: Dictionary[String, Dictionary] = {
	"ember_pulse": {"label": "Ember Pulse", "text": "The foe's Spirlings gain 1 extra Energy every turn.", "foe_energy": 1},
	"undertow": {"label": "Undertow", "text": "The current drags at you: your Spirlings start with less Pace.", "player_stage": {"spd": -1}},
	"ember_pulse_soft": {"label": "Ember Pulse", "text": "The foe's Spirlings gain 1 extra Energy every second turn.", "foe_energy": 1, "foe_energy_every": 2},
	"undertow_soft": {"label": "Undertow", "text": "The current drags at your lead: it starts with less Pace.", "player_stage": {"spd": -1}, "lead_only": true},
}

## Multi-Spirling battles: a sweep ("foes" move) that reaches more than one foe deals this share to each.
const SPREAD_MULT: float = 0.75
## Most Spirlings one side can field at once. Four 28 px sprites still fit the 144 px width.
const MAX_FRONT: int = 4

## Rift bosses (npc "boss"): one swollen Spirling the whole party faces at once. Its HP and its
## actions per turn grow with how many Spirlings the player fields, so a lone starter is not crushed:
##   hp_per_ally:  max HP multiplier per player Spirling on the field (never below 1)
##   max_actions:  actions per turn when the player fields 4 (1 more for every 2 fielded)
const BOSSES: Dictionary[String, Dictionary] = {
	"ashen_heart": {"label": "Ashen Heart", "hp_per_ally": 0.8, "max_actions": 2,
		"text": "The Hush gathers into one burning heart. It is far too strong to face alone!",
		"phase": {"at": 0.5, "stage": {"atk": 1, "spd": 1}, "field": "ash_storm",
			"text": "The Ashen Heart flares up! Its embers spin faster."}},
	"drowned_heart": {"label": "Drowned Heart", "hp_per_ally": 0.7, "max_actions": 2,
		"text": "The Rift's water heaves up around a drowned heart. Its guard stands beside it!",
		"phase": {"at": 0.5, "stage": {"def": 1, "foc": 1}, "field": "high_tide",
			"text": "The Drowned Heart pulls the tide around itself!"}},
}

## Second phase of a boss (BOSSES[id].phase), or {}. Once its HP falls to "at" of max HP the boss
## wakes up: its "stage" changes apply and its "field" (if any) takes over for the rest of the fight.
static func boss_phase(boss_id: String) -> Dictionary:
	var p: Variant = BOSSES.get(boss_id, {}).get("phase", {})
	return p if p is Dictionary else {}

## Max HP multiplier for a boss facing [param fielded] player Spirlings.
static func boss_hp_mult(boss_id: String, fielded: int) -> float:
	var b: Dictionary = BOSSES.get(boss_id, {})
	if b.is_empty():
		return 1.0
	return maxf(1.0, float(b.get("hp_per_ally", 1.0)) * fielded)

## Actions per turn for a boss facing [param fielded] player Spirlings (at least 1).
static func boss_actions(boss_id: String, fielded: int) -> int:
	var b: Dictionary = BOSSES.get(boss_id, {})
	if b.is_empty():
		return 1
	return clampi(1 + (fielded - 1) / 2, 1, int(b.get("max_actions", 1)))

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

## Power multiplier of a bonus_vs_status move against [param target] (1.0 when it doesn't apply).
## "*" matches any status, "stage_down" any lowered stat stage.
static func status_bonus(move: MoveData, target: Spirling) -> float:
	if target == null:
		return 1.0
	for fx: Dictionary in move.effects:
		if StringName(fx.get("id", "")) != &"bonus_vs_status":
			continue
		var want: String = str(fx.get("vs_status", ""))
		var hit: bool = false
		if want == "stage_down":
			for stat: String in STAGE_STATS:
				hit = hit or target.stage(stat) < 0
		elif not target.status.is_empty():
			hit = want == "*" or want == target.status
		if hit:
			return float(fx.get("vs_mult", 1.0))
	return 1.0

static var _resolved: Dictionary[String, MoveData] = {}

## The move as it lands right now: a field_element move takes the element the active field
## boosts and gains power. Returns [param move] itself when nothing changes; the changed copy is
## cached per move and field, so MoveData from the Database is never mutated.
static func resolve_move(move: MoveData, field: String) -> MoveData:
	var f: Dictionary = FIELDS.get(field, {})
	if f.is_empty():
		return move
	for fx: Dictionary in move.effects:
		if StringName(fx.get("id", "")) != &"field_element":
			continue
		var key: String = move.move_name + "@" + field
		if not _resolved.has(key):
			var copy: MoveData = move.duplicate()
			copy.element = Elements.E.get(str(f.boost), move.element)
			copy.power = move.power + int(fx.get("power_bonus", FIELD_ELEMENT_POWER))
			_resolved[key] = copy
		return _resolved[key]
	return move

## Damage multiplier from traits, held items, the field and status bonuses for one hit.
static func damage_mult(user: Spirling, target: Spirling, move: MoveData, field: String) -> float:
	var m: float = field_mult(field, move.element)
	m *= status_bonus(move, target)
	m *= float(reaction(move, target).get("mult", 1.0))
	if move.kind == MoveData.Kind.PHYSICAL:
		m *= mult_key(target, "phys_taken")
	var boost: float = float(trait_info(user.data.trait_id).get("low_hp_boost", 1.0))
	if boost != 1.0 and move.element in user.elements() and user.hp * 3 < user.max_hp():
		m *= boost
	return m
