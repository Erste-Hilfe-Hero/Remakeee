class_name BattleRules
extends RefCounted
## Data tables for battle depth: stat stages, passive traits, held items, Rift fields and
## Warden rules. Battle code reads these tables; nothing switches on ids elsewhere.

const STAGE_MIN: int = -3
const STAGE_MAX: int = 3
const STAGE_STATS: Array[String] = ["atk", "def", "foc", "spd"]
## Chimora keeps stages to these four on purpose (items 237, 238): no accuracy or evasion stages,
## because a dodge stack only makes a fight long and frustrating. Pinned by test_stage_values.gd.
## A foe whose Might reaches this stage gets a warning line (item 227).
const STAGE_WARN: int = 2

## Overcharge moves: each leftover Energy point adds this much to the power multiplier.
const OVERCHARGE_PER_ENERGY: float = 0.12
## At most this much leftover Energy goes into one Overcharge (the rest stays).
const OVERCHARGE_MAX_EXTRA: int = 5
## Overcharge chain (KAMPF_PLAN item 59): an Overcharge art in the turn right after the same
## Spirling's last one adds this much to the power multiplier.
const OVERCHARGE_CHAIN_BONUS: float = 0.15

## Power multiplier of an Overcharge art that has [param left] Energy left after its own cost.
static func overcharge_mult(left: int, chained: bool = false) -> float:
	return 1.0 + OVERCHARGE_PER_ENERGY * clampi(left, 0, OVERCHARGE_MAX_EXTRA) + (OVERCHARGE_CHAIN_BONUS if chained else 0.0)

## Energy tax (energy_tax effect): extra Energy per move, and how many turns a tax holds by default.
const ENERGY_TAX_COST: int = 1
const ENERGY_TAX_TURNS: int = 2
## field_element moves: power added while they take the active field's element.
const FIELD_ELEMENT_POWER: int = 20
## Most snares (side_snare) that can lie on one side at once.
const MAX_SNARES: int = 3
## Long fights: from this turn on nobody heals in battle any more (arts, gifts, fields, keepsakes),
## so two Spirlings that mend faster than they hurt each other can't stall forever.
const WEARY_TURN: int = 40
## Turns a heal_block holds by default.
const HEAL_BLOCK_TURNS: int = 3
## After an energy_burn the target can't be burned again for this many turns.
const BURN_GUARD_TURNS: int = 1
## Turns a Calm Veil (status_veil effect, item 193) holds by default.
const STATUS_VEIL_TURNS: int = 5

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
## Root Mend (item 492): turns of mending after the art and the share of max Vigor per turn.
const MEND_TURNS: int = 3
const MEND_DIV: int = 16
## Turns a field_extend art adds to the Resonance field in play.
const FIELD_EXTEND_TURNS: int = 2

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
	# Items 194, 195: contact_status/contact_chance pass a status on to a physical attacker,
	# cure_on_swap drops its status when it steps back to the bench.
	"glimmer_skin": {"label": "Glimmer Skin", "text": "A physical hit on it may Scorch whoever struck it (3 in 10).", "contact_status": "scorch", "contact_chance": 0.3},
	"unruffled": {"label": "Unruffled", "text": "Its status falls away when it steps back to your side.", "cure_on_swap": true},
}

## Rift fields. A map sets "field"; every battle there uses it. A Resonance move lays one for a
## few turns. Optional keys:
##   blocks:        statuses that can't take hold while the field lasts
##   regen_element: Spirlings of this element heal max_hp / regen_div at the end of each turn
##   rest_bonus:    extra Energy for every Rest while the field lasts (KAMPF_PLAN item 42)
const FIELDS: Dictionary[String, Dictionary] = {
	"ash_storm": {"label": "Ash Storm", "boost": "EMBER", "weaken": "TIDE",
		"intro": "Ash swirls through the Rift. Ember arts burn brighter, Tide arts sputter."},
	"high_tide": {"label": "High Tide", "boost": "TIDE", "weaken": "EMBER", "blocks": ["scorch"], "rest_bonus": 1,
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

## Element reactions: a move of "element" that hits a foe with "status" hits harder ("mult"),
## washes the status away after the hit ("cure") and/or moves a stage of the foe ("stage").
## At most one reaction per hit: the first row that fits wins, and no two rows share a pair.
const REACTIONS: Array[Dictionary] = [
	{"element": "VOLT", "status": "soak", "mult": 1.2, "text": "The charge races through the soaked %s!"},
	{"element": "TIDE", "status": "scorch", "cure": true, "text": "The water douses the embers on %s!"},
	{"element": "STONE", "status": "jolt", "mult": 1.1, "cure": true, "text": "The stone grounds the charge in %s!"},
	{"element": "GALE", "status": "soak", "cure": true, "stage": {"spd": -1}, "text": "The gust blows %s dry, and it slows down!"},
	{"element": "LUMEN", "status": "drowse", "mult": 1.3, "cure": true, "text": "The light startles %s awake!"},
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
## "difficulty": the difficulties (GameState order) a rule may be used on (item 677). Field rules
## (items 675, 676, "warden_only"): "field_opening" lays a field for the first turns, "field_cycle"
## brings a field back every "on" + "off" turns and announces it one turn ahead.
const RULES: Dictionary[String, Dictionary] = {
	"ember_pulse": {"label": "Ember Pulse", "text": "The foe's Spirlings gain 1 extra Energy every turn.", "foe_energy": 1, "difficulty": [1, 2, 3],
		"turning": {"text": "The pulse flares: the foe's Spirlings gain 1 Energy at once.", "full_text": "The pulse quickens: now 2 extra Energy every turn.",
			"line": "One left? Then the embers burn for both of us!", "foe_energy_once": 1, "full_foe_energy": 1}},
	"undertow": {"label": "Undertow", "text": "The current drags at you: your Spirlings start with less Pace.", "player_stage": {"spd": -1}, "difficulty": [1, 2, 3],
		"turning": {"text": "The current deepens: your next Spirling to come in loses Might.", "line": "The tide turns. Whoever you send next, it pulls under!", "next_in_stage": {"atk": -1}}},
	"ember_pulse_soft": {"label": "Ember Pulse", "text": "The foe's Spirlings gain 1 extra Energy every second turn.", "foe_energy": 1, "foe_energy_every": 2, "difficulty": [0]},
	"undertow_soft": {"label": "Undertow", "text": "The current drags at your lead: it starts with less Pace.", "player_stage": {"spd": -1}, "lead_only": true, "difficulty": [0]},
	"ash_rain": {"label": "Ash Rain", "text": "Ash rains down: for 3 turns the Ash Storm can't be called away.",
		"field_opening": {"field": "ash_storm", "turns": 3, "locked": true}, "difficulty": [2, 3], "warden_only": true},
	"tide_turn": {"label": "Tide Turn", "text": "The tide comes and goes: High Tide for 2 turns, then 2 turns of calm.",
		"field_cycle": {"field": "high_tide", "on": 2, "off": 2}, "difficulty": [2, 3], "warden_only": true},
	# The Rifts added in 2026-11 (Mist, Root, Shade). Both sides feel these rules:
	# "accuracy_mult" scales every art's accuracy, "vine_heal_div" mends the weakest Spirling in
	# front by max Vigor / div after each round, "hidden_order" lets the seeded RNG instead of
	# Pace decide who moves first among arts of the same priority.
	"fog_bank": {"label": "Fog Bank", "text": "Thick fog: every art on both sides is less accurate.", "accuracy_mult": 0.85,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	"vine_tangle": {"label": "Vine Tangle", "text": "Vines creep in: each round they mend the weakest Spirling in front.", "vine_heal_div": 12,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	"night_dark": {"label": "Night Dark", "text": "In the dark nobody sees who moves first: Pace no longer sets the order.", "hidden_order": 1,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	# The Rifts of Solenne (Act IV). "sand_chip_div": after each round every standing Spirling in
	# front that is not Stone loses max Vigor / div; "heal_mult" scales every heal from arts,
	# gifts and the field; "lumen_mult" scales the damage of Lumen arts. Both sides feel them.
	"sandstorm": {"label": "Sandstorm", "text": "Sand howls through the wind towers: every Spirling in front that is not Stone loses a little Vigor each round.", "sand_chip_div": 16,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	"dry_well": {"label": "Dry Well", "text": "The oasis has been sold dry: every heal on both sides is halved.", "heal_mult": 0.5,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	"high_noon": {"label": "High Noon", "text": "The sun stands straight overhead: Lumen arts on both sides hit harder.", "lumen_mult": 1.3,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	# KAMPF_PLAN item 54. "player_energy_cut": Energy every player Spirling starts without.
	"low_tide": {"label": "Low Tide", "text": "The water has drawn back: your Spirlings start with 1 Energy less.", "player_energy_cut": 1,
		"difficulty": [1, 2, 3]},
	# KAMPF_PLAN_1000 item 409. "stages_locked": no stat stage moves on either side; "rest_cut":
	# resting gives that much less Energy on both sides.
	"still_air": {"label": "Still Air", "text": "Not a breath of wind: no stat stage rises or falls on either side.", "stages_locked": 1,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	"ebb": {"label": "Ebb", "text": "The water has run out: resting gives 1 Energy less on both sides.", "rest_cut": 1,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
	# Item 210: "no_status" keeps every status off both sides (BattleModel.status_block).
	"hushed_air": {"label": "Hushed Air", "text": "The air hangs dead still: no status takes hold on either side.", "no_status": 1,
		"difficulty": [0, 1, 2, 3], "warden_only": true},
}

## The number a Warden rule key adds up to over every rule in [param rule_string] (0 when none
## sets it). Keys ending in "_mult" multiply instead and start at 1.
static func rule_number(rule_string: String, key: String) -> float:
	var mult: bool = key.ends_with("_mult")
	var out: float = 1.0 if mult else 0.0
	for id: String in split_rules(rule_string):
		if not RULES[id].has(key):
			continue
		if mult:
			out *= float(RULES[id][key])
		else:
			out += float(RULES[id][key])
	return out
## The Warden turning point (items 678, 679): when the Warden's second-to-last Spirling drops, a
## rule with a "turning" block grows for the rest of the battle. Only the Tamer-and-up forms carry
## one, so Story never turns. "foe_energy_once" is Energy for the foe's Spirlings on the spot,
## "next_in_stage" hits the next Spirling the player sends in. From Veteran on (BattleModel.
## rule_turn_full) "full_foe_energy" adds to the rule's Energy every turn and "full_text" is shown.
static func turning(rule_id: String) -> Dictionary:
	return RULES.get(rule_id, {}).get("turning", {})

## Several rules join with "+" in one rule string ("ember_pulse+ash_rain"); at most this many at
## once below Veteran, RULE_STACK_HIGH from Veteran on (item 677).
const RULE_STACK: int = 1
const RULE_STACK_HIGH: int = 2

## The known rule ids in [param rule_string] ("a+b"), in order.
static func split_rules(rule_string: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in rule_string.split("+", false):
		if RULES.has(id) and not id in out:
			out.append(id)
	return out

## How many rules may stack on [param difficulty].
static func rule_stack(difficulty: int) -> int:
	return RULE_STACK_HIGH if difficulty >= 2 else RULE_STACK

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
	"mist_heart": {"label": "Mist Heart", "hp_per_ally": 0.7, "max_actions": 2,
		"text": "The fog knots itself into one grey heart. It drifts at you from every side!",
		"phase": {"at": 0.5, "stage": {"spd": 1, "foc": 1}, "field": "static_veil",
			"text": "The Mist Heart crackles! Lightning flickers in the fog."}},
}

## Foe Energy at the start per difficulty (item 749): Story foes start with 2 less (8), Rift-Born
## foes gain 1 extra at the end of the first turn. The player always starts with the normal 10.
const FOE_START_CUT: Array[int] = [2, 0, 0, 0]
const FOE_TURN1_ENERGY: Array[int] = [0, 0, 0, 1]

static func foe_start_cut(difficulty: int) -> int:
	return FOE_START_CUT[difficulty] if difficulty >= 0 and difficulty < FOE_START_CUT.size() else 0

static func foe_turn1_energy(difficulty: int) -> int:
	return FOE_TURN1_ENERGY[difficulty] if difficulty >= 0 and difficulty < FOE_TURN1_ENERGY.size() else 0

## Boss tuning per difficulty (Story, Tamer, Veteran, Rift-Born; plan area 2 items 747, 748):
## the most actions a boss takes per turn (0 = as BOSSES says), extra actions once the second
## phase starts, and the share of max HP that starts it.
const BOSS_ACTION_CAP: Array[int] = [1, 0, 0, 0]
const BOSS_PHASE_BONUS: Array[int] = [0, 0, 0, 1]
const BOSS_PHASE_AT: Array[float] = [0.5, 0.5, 0.5, 0.6]

## Actions per turn on [param difficulty] (-1 for none set) before the second phase.
static func boss_actions_for(boss_id: String, fielded: int, difficulty: int) -> int:
	var n: int = boss_actions(boss_id, fielded)
	if difficulty >= 0 and difficulty < BOSS_ACTION_CAP.size() and BOSS_ACTION_CAP[difficulty] > 0:
		n = mini(n, BOSS_ACTION_CAP[difficulty])
	return n

## The HP share that starts the second phase on [param difficulty].
static func boss_phase_at(boss_id: String, difficulty: int) -> float:
	var at: float = float(boss_phase(boss_id).get("at", 0.5))
	if difficulty >= 0 and difficulty < BOSS_PHASE_AT.size():
		at = maxf(at, BOSS_PHASE_AT[difficulty])
	return at

## Second phase of a boss (BOSSES[id].phase), or {}. Once its HP falls to "at" of max HP the boss
## wakes up: its "stage" changes apply and its "field" (if any) takes over for the rest of the fight.
static func boss_phase(boss_id: String) -> Dictionary:
	var p: Variant = BOSSES.get(boss_id, {}).get("phase", {})
	return p if p is Dictionary else {}

## Max HP multiplier for a boss facing [param fielded] player Spirlings.
## [param scale] shrinks "hp_per_ally" (Story bosses use 0.8, plan item 729).
static func boss_hp_mult(boss_id: String, fielded: int, scale: float = 1.0) -> float:
	var b: Dictionary = BOSSES.get(boss_id, {})
	if b.is_empty():
		return 1.0
	return maxf(1.0, float(b.get("hp_per_ally", 1.0)) * scale * fielded)

## Actions per turn for a boss facing [param fielded] player Spirlings (at least 1).
static func boss_actions(boss_id: String, fielded: int) -> int:
	var b: Dictionary = BOSSES.get(boss_id, {})
	if b.is_empty():
		return 1
	return clampi(1 + (fielded - 1) / 2, 1, int(b.get("max_actions", 1)))

static func stage_mult(stage: int) -> float:
	var s: int = clampi(stage, STAGE_MIN, STAGE_MAX)
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)

## "Might +2: x2.00" (item 222): a stage and the factor it puts on the stat.
static func stage_line(stat_label: String, stage: int) -> String:
	return "%s %s%d: x%.2f" % [stat_label, "+" if stage > 0 else "", stage, stage_mult(stage)]

static var _oath: Dictionary = {}

## The Ink Oath rules (data/ink_oath.json).
static func oath() -> Dictionary:
	if _oath.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ink_oath.json"))
		_oath = v if v is Dictionary else {}
	return _oath

static func trait_info(id: String) -> Dictionary:
	return TRAITS[id] if TRAITS.has(id) else HiddenGifts.gift(id)

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
	return float(ShopEffects.gift_table(s).get(key, 0.0)) + float(held_info(s.held).get(key, 0.0))

## Product of a multiplier key over trait and held item.
static func mult_key(s: Spirling, key: String) -> float:
	return float(ShopEffects.gift_table(s).get(key, 1.0)) * float(held_info(s.held).get(key, 1.0))

static func is_immune(s: Spirling, status: String) -> bool:
	return status in ShopEffects.gift_table(s).get("immune", [])

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
	# Element Prisms from the shop: one element hits harder (plan item 4402).
	var held: Dictionary = held_info(user.held)
	if held.has("elem") and move.element == Elements.E.get(str(held.elem), -1):
		m *= float(held.get("elem_mult", 1.0))
	var boost: float = float(ShopEffects.gift_table(user).get("low_hp_boost", 1.0))
	if boost != 1.0 and move.element in user.elements() and user.hp * 3 < user.max_hp():
		m *= boost
	return m

# --- Rule variants (plan area 2, items 780, 781) ---------------------------------------------

const VARIANTS_PATH: String = "res://data/rule_variants.json"
## Most variants that can be on at once.
const MAX_VARIANTS: int = 3
## Every number key a variant may set, with the value of the normal rules. BattleModel reads only
## these; a variant is nothing but a set of them, so no variant needs its own code.
const VARIANT_KEYS: Dictionary[String, float] = {
	"start_energy": 10.0, "max_energy": 10.0, "energy_per_turn": 1.0, "rest_energy": 2.0,
	"swap_energy_cost": 0.0, "hp_mult": 1.0, "stab": 1.25, "status_max_turns": 0.0,
	"reaction_scale": 1.0, "chip_from_turn": 0.0,
	# 1 locks every stage change; stage-only arts can't be picked (item 788).
	"stages_locked": 0.0,
	# Every N turns the battle seed lays a random field, announced a turn early (item 791).
	"field_swirl_every": 0.0,
	# 1: Rest is only there when no art can be paid, as a plain pass (item 792).
	"rest_only_as_pass": 0.0,
}

## True for an art that does nothing but change stages (locked by "stages_locked").
static func stage_only(mv: MoveData) -> bool:
	if mv.is_damaging() or mv.effects.is_empty():
		return false
	for fx: Dictionary in mv.effects:
		if not StringName(fx.get("id", "")) in [&"stat_change", &"self_stage_after", &"stage_steal", &"stage_copy", &"stage_swap"]:
			return false
	return true

static var _variants: Dictionary = {}
## Seals the rule banner can draw for a variant (item 796); each variant names its own.
const VARIANT_SYMBOLS: Array[String] = ["spark", "full", "toll", "glass", "block", "ring", "bars", "cross",
	"hourglass", "line", "swirl", "wedge"]

## Every variant from data/rule_variants.json (cached). Unknown keys and one-sided excludes are
## reported by validate_variants.
static func variants() -> Dictionary:
	if _variants.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(VARIANTS_PATH)) if FileAccess.file_exists(VARIANTS_PATH) else null
		if raw is Dictionary:
			_variants = (raw as Dictionary).duplicate(true)
			_variants.erase("_doc")
	return _variants

## Problems in the variant file: unknown keys, excludes naming no variant or only one way.
static func validate_variants() -> Array[String]:
	var out: Array[String] = []
	var all: Dictionary = variants()
	var seals: Dictionary = {}
	for id: String in all:
		var seal: String = str(all[id].get("symbol", ""))
		if not seal in VARIANT_SYMBOLS:
			out.append("%s: unknown symbol %s" % [id, seal])
		elif seals.has(seal):
			out.append("%s: symbol %s already used by %s" % [id, seal, seals[seal]])
		seals[seal] = id
		for k: String in (all[id].get("keys", {}) as Dictionary):
			if not VARIANT_KEYS.has(k):
				out.append("%s: unknown key %s" % [id, k])
		for ex: Variant in all[id].get("excludes", []):
			if not all.has(str(ex)):
				out.append("%s: excludes unknown %s" % [id, ex])
			elif not id in (all[str(ex)].get("excludes", []) as Array):
				out.append("%s: excludes %s, but not the other way" % [id, ex])
	return out

## Why [param ids] cannot be played together ("" when they can): too many, unknown, or excluded.
static func variant_conflict(ids: Array[String]) -> String:
	if ids.size() > MAX_VARIANTS:
		return "At most %d variants at once." % MAX_VARIANTS
	var all: Dictionary = variants()
	for i: int in ids.size():
		if not all.has(ids[i]):
			return "Unknown variant %s." % ids[i]
		for j: int in range(i + 1, ids.size()):
			if ids[j] == ids[i] or ids[j] in (all[ids[i]].get("excludes", []) as Array):
				return "%s and %s don't go together." % [all[ids[i]].label, all[ids[j]].get("label", ids[j])]
	return ""

## Up to [param count] variants that go together, drawn from [param seed_value] (item 799): the
## same seed always gives the same list, in the file's sorted order of ids.
static func draw_variants(seed_value: int, count: int) -> Array[String]:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var pool: Array = variants().keys()
	pool.sort()
	var out: Array[String] = []
	while out.size() < mini(count, MAX_VARIANTS) and not pool.is_empty():
		var id: String = str(pool.pop_at(r.randi_range(0, pool.size() - 1)))
		var trial: Array[String] = out.duplicate()
		trial.append(id)
		if variant_conflict(trial).is_empty():
			out = trial
	return out

## "Glass Blades, Late End" for [param ids], translated.
static func variant_names(ids: Array[String]) -> String:
	var names: PackedStringArray = []
	for id: String in ids:
		names.append(Loc.t(str(variants().get(id, {}).get("label", id))))
	return ", ".join(names)

## The merged keys of [param ids] over the normal values, or {} when they conflict.
static func variant_values(ids: Array[String]) -> Dictionary:
	var out: Dictionary = VARIANT_KEYS.duplicate()
	if not variant_conflict(ids).is_empty():
		return {}
	for id: String in ids:
		var keys: Dictionary = variants()[id].get("keys", {})
		for k: String in keys:
			out[k] = float(keys[k])
	return out

