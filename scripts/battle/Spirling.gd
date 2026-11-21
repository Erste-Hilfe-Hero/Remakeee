class_name Spirling
extends RefCounted
## A Spirling instance owned by a Wayfarer or met in the wild.
## Holds all mutable state; the SpirlingData it points to is never changed.

const STAT_KEYS: Array[String] = ["hp", "atk", "def", "foc", "spd"]
const SPARK_MAX: int = 12
const MAX_MOVES: int = 4
const START_ENERGY: int = 10
const MAX_ENERGY: int = 10
## Spirlings have no top ring (owner decision 2026-11-12): XP and stats follow their formulas
## for any ring. STORY_RING is the top ring of story content (Wardens, echoes, endgame) and the
## ring online duels and the open league normalise to; it never stops a Spirling growing.
## Kept apart from the genre's well-known 100 (docs/legal/IP_PATENT_AUDIT.md, item 15).
const STORY_RING: int = 60
## Sanity bound against broken or forged save data only (same as server_config save_level_max).
## Not a game cap: at the XP curve below it takes over 30 billion XP.
const LEVEL_SANITY: int = 9999
## Newest era a Spirling can come from (EraManager.NEWEST, Era V Living). Saves used to cut
## Era V Spirlings back to Era IV (bug plan 1373).
const MAX_ERA: int = 5
## Chance that a wild Spirling is a rare Prism colour variant (cosmetic only).
const PRISM_CHANCE: float = 1.0 / 256.0

## Chimora's own stat curve:
##   HP    = floor((base + spark/2) * (L + 18) / 20)
##   other = floor((base + spark/2) * (L + 12) / 28) + 4
const HP_LEVEL_OFFSET: float = 18.0
const HP_LEVEL_DIV: float = 20.0
const STAT_LEVEL_OFFSET: float = 12.0
const STAT_LEVEL_DIV: float = 28.0
const STAT_FLAT: int = 4
const SPARK_WEIGHT: float = 0.5
## Total XP needed to reach level L = floor(XP_MULT * L ^ XP_EXP).
const XP_MULT: float = 1.2
const XP_EXP: float = 2.6
## Temperament (item 37): a small, penalty-free lean toward one stat. Since save version 4 it is
## stored in "temper"; new Spirlings pick it from the uid (no extra RNG roll). The last four only
## colour behaviour and texts and lean toward no stat (plan area 1, item 313).
const TEMPERAMENTS: Array[Dictionary] = [
	{"id": "fierce", "label": "Fierce", "stat": "atk", "text": "Hits a little harder."},
	{"id": "stalwart", "label": "Stalwart", "stat": "def", "text": "Shrugs off blows a little better."},
	{"id": "keen", "label": "Keen", "stat": "foc", "text": "Focuses a little sharper."},
	{"id": "brisk", "label": "Brisk", "stat": "spd", "text": "Moves a little quicker."},
	{"id": "hearty", "label": "Hearty", "stat": "hp", "text": "Has a little more stamina."},
	{"id": "even", "label": "Even", "stat": "", "text": "Calm and balanced."},
	{"id": "curious", "label": "Curious", "stat": "", "text": "Noses into everything new."},
	{"id": "shy", "label": "Shy", "stat": "", "text": "Stays close and watches first."},
	{"id": "proud", "label": "Proud", "stat": "", "text": "Holds its head high, win or lose."},
	{"id": "gentle", "label": "Gentle", "stat": "", "text": "Careful with everyone around it."},
]
## Saves before version 4 read the temperament from the uid over the first six only.
const LEGACY_TEMPERAMENTS: int = 6
const TEMPER_BONUS: float = 1.05
## Power Core (shop item 4750): the temperament's lean doubles for this Spirling.
const TEMPER_CORE_BONUS: float = 1.10

var data: SpirlingData
var nickname: String = ""
var level: int = 1
var xp: int = 0
var spark: Dictionary[String, int] = {}
## Stat crystal points from the shop (stat key -> points, up to ShopEffects.crystal_cap()).
## They count like Spark. League and raid rows never carry them.
var crystal: Dictionary[String, int] = {}
var hp: int = 1
var energy: int = START_ENERGY
var status: String = ""
## Turns left for timed statuses (Soak, Daze, Drowse). 0 for open-ended ones.
var status_turns: int = 0
var moves: Array[MoveData] = []
var uid: String = ""
## Held item id ("" for none). Only items with a "held" block can be held.
var held: String = ""
## Saved keepsake sets (KeepsakeKit, KAMPF_PLAN_1000 307): item id per set, "" for an empty one.
## Saved as "held_sets" only when set.
var held_sets: Array[String] = []
## Rare colour variant. Cosmetic only, never stronger.
var prism: bool = false
## Power Core used on this Spirling (saved as "core" only when true).
var temper_core: bool = false
## Gleam form: the species' own alternate palette (GleamRules). Wild ones roll it at
## data/gleam.json "wild_one_in"; the shop's Gleam Prism gives it too. Kept on unfurling and trades.
var gleam: bool = false
## +10 % on all five values from the shop's Gleam Prism (items 4791-4794). Saves from before wild
## Gleams have only "gleam", which then meant this boost. The Fair League never carries it.
var gleam_boost: bool = false
## Bought in the shop as a Spirling offer (pay-to-win plan, points 61-80): never traded or lent.
## Saved as "shop".
var shop_bought: bool = false
const GLEAM_MULT: float = 1.1
## Battle-only stat stages (BattleRules.STAGE_MIN..STAGE_MAX), cleared by end_battle().
var stages: Dictionary[String, int] = {}
## True while it fights as a Rift boss: an open-ended status ends after StatusRules.BOSS_OPEN_TURNS
## (timed ones and stage drops are halved by BossRules in BattleModel). Cleared by end_battle().
var boss_guard: bool = false
## Battle-only: turns it surely loses to a status combo (StatusRules.COMBOS). Cleared by end_battle().
var sure_skip: int = 0
## Battle-only: turns left on an Energy tax (energy_tax effect): every move costs more meanwhile.
## Counted down at the end of each turn, so a fresh tax of N holds for the next N turns.
var energy_tax: int = 0
## Battle-only: turns left on a Glass Spark (shop, plan item 4501): +1 energy at each turn end.
var energy_surge: int = 0
## Battle-only: move name -> turns it stays locked (moves.json "cooldown"), same counting.
var cooldowns: Dictionary[String, int] = {}
## Battle-only: turns left on a heal block (heal_block effect), same counting.
var heal_block: int = 0
## Battle-only: turns left on a sworn Ink Oath (BattleRules.oath()); the debt is collected at 0.
var oath_turns: int = 0
## Battle-only: turns of mending left from Root Mend (1/16 max Vigor at each turn end).
var mend_turns: int = 0
## Battle-only: turns left in which an energy_burn can't take Energy again, same counting.
var burn_guard: int = 0
## Battle-only: the turn this Spirling last used an Overcharge art (-9 for none), so a second one
## in the very next turn chains (KAMPF_PLAN item 59).
var overcharge_turn: int = -9
## Battle-only: arts of this element cost BattleRules.FIELD_COST_CUT less (the place's own field's
## "cheap_element", set by BattleModel whenever the field changes; -1 for none, KAMPF_PLAN item 75).
var cheap_element: int = -1
## Battle-only: turns left in which this Spirling gains no Energy (energy_lock effect, item 47),
## counted down at the end of each turn like the Energy tax.
var energy_lock: int = 0
## Temperament id (TEMPERAMENTS), stored since save version 4.
var temper: String = ""
## Regional imprint id ("" = none), see plan area 1, item 218.
var variant: String = ""
## Where and when it was met: map id, its ring then, and the day number (days since 1970).
var origin_map: String = ""
## The era (1-4) of the place it was bonded. It stays the same when the Spirling is traded.
var origin_era: int = 1
var met_ring: int = 0
var met_day: int = 0
## Storage box this Spirling rests in (GameState.storage_boxes index) and the favourite mark:
## favourites are never released and never moved by a multi-select (plan area 1, items 375-377).
var box: int = 0
var favorite: bool = false
## Favourite art (KAMPF_PLAN item 605): the battle menu starts on it when no art was used yet.
var fav_art: String = ""
## True while its hidden gift is awake (HiddenGifts); it then replaces the species' gift.
var hidden_gift: bool = false
## The shop's Second Gift Slot is open (pay-to-win step 6, plan point 12): the hidden gift of its
## line works next to its gift (ShopEffects.gift_table). Saved as "gift_slot"; never traded.
var gift_slot: bool = false
## A bonus gift of the Kampf plan (TraitKit.bonus_options) it learned next to its own, or "".
## Saved as "bonus_trait" only when set.
var bonus_trait: String = ""
## Species names of the two Spirlings that sang it into being (Echo offspring), else empty.
var lineage: Array[String] = []
## Fully right Echo calls in a row while it was in the team (unfold rule "echo_streak").
var echo_streak: int = 0
## Kinship 0..Kinship.max_value() (era function "kinship", Era II): grows in battle and on the
## road (Kinship.gd); unfold rule "kinship" waits for it.
var kinship: int = 0

## [param rng] rolls the hidden Spark values; pass the battle or game RNG for reproducibility.
func _init(d: SpirlingData = null, lvl: int = 1, rng: RandomNumberGenerator = null) -> void:
	if d == null:
		return
	data = d
	level = clampi(lvl, 1, LEVEL_SANITY)
	xp = xp_for_level(level)
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	for key: String in STAT_KEYS:
		spark[key] = r.randi_range(0, SPARK_MAX)
	uid = "%08x%08x" % [r.randi(), r.randi()]
	temper = str(TEMPERAMENTS[absi(uid.hash()) % TEMPERAMENTS.size()].id)
	moves = data.default_moves(level, MAX_MOVES)
	hp = max_hp()

## The gift in effect: the hidden gift while awake, else the species' gift.
func gift_id() -> String:
	if hidden_gift:
		var h: String = HiddenGifts.gift_id(data)
		if not h.is_empty():
			return h
	return data.trait_id

func display_name() -> String:
	return nickname if not nickname.is_empty() else data.species_name

## Element shift (Dye Bath, KAMPF_PLAN_1000 item 86): for a few turns of one battle the
## Spirling counts as this one element (-1 = its own elements).
var element_shift: int = -1
var element_shift_turns: int = 0

func elements() -> Array[int]:
	if element_shift >= 0:
		var shifted: Array[int] = [element_shift]
		return shifted
	var v: Dictionary = variant_info()
	if not v.is_empty() and not (v.elements as Array).is_empty():
		return v.elements
	return data.elements

## The regional imprint this Spirling shows ("variant" = region id), or {} (items 218-219).
func variant_info() -> Dictionary:
	if variant.is_empty() or data == null:
		return {}
	for v: Dictionary in data.variants:
		if str(v.region) == variant:
			return v
	return {}

## Takes on the imprint of [param region] if this kind has one there. True when it changed.
func apply_imprint(region: String) -> bool:
	for v: Dictionary in data.variants:
		if str(v.region) == region and variant != region:
			variant = region
			return true
	return false

func _curve(base: int, key: String, offset: float, div: float) -> int:
	var s: float = float(base) + float(spark.get(key, 0) + crystal.get(key, 0)) * SPARK_WEIGHT
	return int(floor(s * (float(level) + offset) / div))

## Battle-only max HP multiplier for Rift bosses (BattleRules.BOSSES). Never saved.
var hp_mult: float = 1.0

func max_hp() -> int:
	return maxi(1, int(_curve(data.base_hp, "hp", HP_LEVEL_OFFSET, HP_LEVEL_DIV) * _temper_mult("hp") * hp_mult * shop_mult()
		* BattleRules.mult_key(self, "hp_mult")))

func _stat(key: String) -> int:
	return int((_curve(data.base_stat(key), key, STAT_LEVEL_OFFSET, STAT_LEVEL_DIV) + STAT_FLAT) * _temper_mult(key) * shop_mult())

## Factor from shop purchases on this Spirling (Gleam form, item 4794).
func shop_mult() -> float:
	return GLEAM_MULT if gleam_boost else 1.0

## The temperament id saves before version 4 had, read from the uid ("even" without a uid).
static func legacy_temper(p_uid: String) -> String:
	if p_uid.is_empty():
		return "even"
	return str(TEMPERAMENTS[absi(p_uid.hash()) % LEGACY_TEMPERAMENTS].id)

static func temper_info(id: String) -> Dictionary:
	for t: Dictionary in TEMPERAMENTS:
		if t.id == id:
			return t
	return TEMPERAMENTS[5]

func temperament() -> Dictionary:
	return temper_info(temper if not temper.is_empty() else legacy_temper(uid))

func _temper_mult(key: String) -> float:
	if str(temperament().stat) != key:
		return 1.0
	return TEMPER_CORE_BONUS if temper_core else TEMPER_BONUS

## Raw stats (no status modifiers). Battle code uses the effective_* versions.
func atk() -> int: return _stat("atk")
func def() -> int: return _stat("def")
func foc() -> int: return _stat("foc")
func spd() -> int: return _stat("spd")

func stage(stat: String) -> int:
	return int(stages.get(stat, 0))

## Factor of the [param stat] stage (half for lowered stages on a boss).
func stage_factor(stat: String) -> float:
	return BattleRules.stage_mult(stage(stat))

## ATK after status (Scorch, or the Kindling trait), stages and held item.
func effective_atk() -> int:
	var m: float = StatusRules.atk_mult(status)
	if status == "scorch":
		m = float(ShopEffects.gift_table(self).get("scorch_atk", m))
	return int(atk() * m * stage_factor("atk") * BattleRules.mult_key(self, "atk_mult"))

func effective_def() -> int:
	return int(def() * stage_factor("def") * BattleRules.mult_key(self, "def_mult"))

func effective_foc() -> int:
	return int(foc() * stage_factor("foc") * BattleRules.mult_key(self, "foc_mult"))

## SPD after status (Soak), stages and held item.
func effective_spd() -> int:
	return int(spd() * StatusRules.spd_mult(status) * stage_factor("spd") * BattleRules.mult_key(self, "spd_mult"))

func is_fainted() -> bool:
	return hp <= 0

func hp_fraction() -> float:
	return float(hp) / float(max_hp())

## Energy [param move] costs right now: its own cost plus the Energy tax while one lasts, minus
## the gift "cost_cut_from" (Low Flame, item 48) and the home field's cheap element (item 75).
## A cut never takes an art below 1 Energy, and an art that is free stays free.
func move_cost(move: MoveData) -> int:
	var c: int = move.energy_cost + (BattleRules.ENERGY_TAX_COST if energy_tax > 0 else 0)
	var from: int = int(ShopEffects.gift_table(self).get("cost_cut_from", 0)) if data != null else 0
	if from > 0 and move.energy_cost >= from:
		c -= 1
	if cheap_element >= 0 and move.element == cheap_element:
		c -= BattleRules.FIELD_COST_CUT
	c -= TraitKit.cost_cut(self, move)
	return maxi(c, mini(1, move.energy_cost))

## Turns [param move] stays locked after a use ("cooldown"), 0 when it is free.
func cooldown_left(move: MoveData) -> int:
	return int(cooldowns.get(move.move_name, 0))

## True if the move can be used now: enough Energy (tax included) and not locked by a cooldown.
func can_afford(move: MoveData) -> bool:
	return energy >= move_cost(move) and cooldown_left(move) <= 0

## Counts the battle-only timers (Energy tax, cooldowns) down by one at the end of a turn.
func tick_timers() -> void:
	if energy_tax > 0:
		energy_tax -= 1
	if energy_lock > 0:
		energy_lock -= 1
	if heal_block > 0:
		heal_block -= 1
	if burn_guard > 0:
		burn_guard -= 1
	if element_shift_turns > 0:
		element_shift_turns -= 1
		if element_shift_turns <= 0:
			element_shift = -1
	for k: String in cooldowns.keys():
		cooldowns[k] = int(cooldowns[k]) - 1
		if int(cooldowns[k]) <= 0:
			cooldowns.erase(k)

## Full heal (rest stops between battles).
func restore() -> void:
	hp = max_hp()
	status = ""
	status_turns = 0
	energy = START_ENERGY

## Clears battle-only state when a battle ends. The status goes too, unless [param keep_status]
## (BattleModel.keep_status, item 179) and it is one that lingers on a Spirling still standing.
func end_battle(keep_status: bool = false) -> void:
	stages.clear()
	boss_guard = false
	sure_skip = 0
	energy_tax = 0
	energy_surge = 0
	heal_block = 0
	mend_turns = 0
	burn_guard = 0
	element_shift = -1
	element_shift_turns = 0
	oath_turns = 0
	overcharge_turn = -9
	cheap_element = -1
	energy_lock = 0
	cooldowns.clear()
	if not (keep_status and not is_fainted() and StatusRules.lingers(status)):
		status = ""
		status_turns = 0
	energy = START_ENERGY

static func xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	return int(floor(XP_MULT * pow(float(lvl), XP_EXP)))

func xp_to_next() -> int:
	if level >= LEVEL_SANITY:
		return 0
	return xp_for_level(level + 1) - xp

## Raises level by one, keeping the same HP fraction lost. Returns moves learned at the new level.
func level_up() -> Array[MoveData]:
	var old_max: int = max_hp()
	level += 1
	hp += max_hp() - old_max
	var learned: Array[MoveData] = []
	for mv: MoveData in data.moves_learned_at(level):
		if moves.has(mv):
			continue
		if moves.size() < MAX_MOVES:
			moves.append(mv)
			learned.append(mv)
	return learned

## True if this Spirling has reached its evolution level ([param map_id]: where the battle was,
## for species that only evolve in one place). Item evolutions use can_evolve_with().
func can_evolve(map_id: String = "") -> bool:
	return can_unfurl(map_id)

func can_evolve_with(item_id: String) -> bool:
	for p: Dictionary in data.unfold:
		if str(p.rule) == "item" and str(p.value) == item_id:
			return true
	return false

## Unfurling (Chimora's own form change): never automatic. Once a Spirling meets one of its
## unfold rules, the player may unfurl it from the Team menu, and may furl it back to its earlier
## form at any time. Rings, arts and Spark stay the same. [param map_id] is where it stands;
## the rest of the context (map pages, mended Rifts, time of day) comes from GameState.
func can_unfurl(map_id: String = "") -> bool:
	return not unfurl_targets(map_id).is_empty()

## Forms this Spirling can unfurl into right now (item paths are used from the Bag instead).
func unfurl_targets(map_id: String = "", ctx: Dictionary = {}) -> Array[SpirlingData]:
	var c: Dictionary = ctx if not ctx.is_empty() else unfold_context(map_id)
	var out: Array[SpirlingData] = []
	if data == null:
		return out
	for p: Dictionary in data.unfold:
		if unfold_ready(p, c) and not out.has(p.to):
			out.append(p.to)
	return out

## What the unfold rules look at: {"map", "pages", "mended", "phase"}.
## Reads the GameState autoload by node path, so data tools that run without autoloads
## (tools/validate_data.gd) can still load this script.
static func unfold_context(map_id: String = "") -> Dictionary:
	var gs: Node = null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		gs = tree.root.get_node_or_null(^"/root/GameState")
	var flags: Dictionary = gs.get("flags") if gs != null else {}
	var mended: Array = (gs.get("rifts_sealed") as Array).duplicate() if gs != null else []
	return {
		"map": map_id,
		"pages": map_pages(flags),
		"mended": mended,
		"phase": PHASE_IDS[DayCycle.current()],
	}

## Pages of Mirela's map book found (flags "page_1".."page_6", same as Overworld.pages_found).
static func map_pages(flags: Dictionary) -> int:
	var n: int = 0
	for i: int in range(1, 7):
		n += 1 if bool(flags.get("page_%d" % i, false)) else 0
	return n

## True if unfold path [param p] (from SpirlingData.unfold) is met in context [param ctx].
func unfold_ready(p: Dictionary, ctx: Dictionary) -> bool:
	var where: String = str(p.get("map", ""))
	if not where.is_empty() and where != str(ctx.get("map", "")):
		return false
	var v: Variant = p.get("value", 0)
	match str(p.get("rule", "ring")):
		"ring":
			return int(v) > 0 and level >= int(v)
		"map_pages":
			return int(ctx.get("pages", 0)) >= int(v)
		"mended":
			var rift: String = mend_rift(str(v))
			var mended: Array = ctx.get("mended", [])
			return mended.has(rift) if not rift.is_empty() else not mended.is_empty()
		"time":
			return str(ctx.get("phase", "")) == str(v)
		"echo_streak":
			return echo_streak >= int(v)
		"kinship":
			return int(v) > 0 and kinship >= int(v)
	return false

## The Rift a "mended" rule waits for. "origin" means the Rift nearest to where it was bonded.
func mend_rift(value: String) -> String:
	if value != "origin":
		return value
	if origin_map.ends_with("_rift"):
		return origin_map.trim_suffix("_rift")
	return str(ORIGIN_RIFTS.get(origin_map, ""))

## Maps next to a Rift: a Spirling bonded there waits for that Rift ("mended", "origin").
const ORIGIN_RIFTS: Dictionary[String, String] = {
	"crowcrest": "cinder", "thornridge": "cinder", "murk_hollow": "cinder",
	"saltmarsh": "tide", "fernstair": "tide",
}

## A short "what it still needs" line for each unfold path, for the Team menu (item 105).
func unfold_hints() -> Array[String]:
	var out: Array[String] = []
	if data == null:
		return out
	for p: Dictionary in data.unfold:
		out.append(unfold_hint(p))
	return out

func unfold_hint(p: Dictionary) -> String:
	var where: String = str(p.get("map", ""))
	var place: String = place_name(where)
	match str(p.get("rule", "ring")):
		"ring":
			if not where.is_empty():
				return "Needs: Ring %d and a battle in %s" % [int(p.value), place]
			return "Needs: Ring %d" % int(p.value)
		"item":
			return "Needs: %s" % str(Database.item(str(p.value)).get("name", p.value))
		"map_pages":
			return "Needs: %d pages of the map book" % int(p.value)
		"mended":
			var rift: String = mend_rift(str(p.value))
			if rift.is_empty():
				return "Needs: a mended Rift"
			return "Needs: %s mended" % place_name(rift + "_rift")
		"time":
			var phase: String = str(PHASE_WORDS.get(str(p.value), p.value))
			if not where.is_empty():
				return "Needs: %s in %s" % [phase, place]
			return "Needs: %s" % phase
		"echo_streak":
			return "Needs: %d perfect Echo calls in the team" % int(p.value)
		"kinship":
			return "Needs: Kinship %d (now %d)" % [int(p.value), kinship]
	return ""

## DayCycle.Phase index -> rule value, and the word shown in hints.
const PHASE_IDS: Array[String] = ["dawn", "day", "dusk", "night"]
const PHASE_WORDS: Dictionary[String, String] = {"dawn": "Dawn", "day": "Daytime", "dusk": "Dusk", "night": "Night"}

static func place_name(map_id: String) -> String:
	if map_id.is_empty() or not MapData.exists(map_id):
		return map_id.replace("_", " ").capitalize()
	return MapData.load_map(map_id).display_name

## The earlier form this one can furl back into, or null.
func earlier_form() -> SpirlingData:
	return Database.earlier_form(data)

func furl_back() -> void:
	var prev: SpirlingData = earlier_form()
	if prev == null:
		return
	var frac: float = hp_fraction()
	data = prev
	hp = maxi(1, int(round(frac * max_hp()))) if hp > 0 else 0

## Evolves in place (new species, same Spark, level, moves and HP fraction). [param target]
## picks one of several unfold paths; by default the first one that is ready, else the first.
func evolve(target: SpirlingData = null) -> void:
	var to: SpirlingData = target
	if to == null:
		var ready: Array[SpirlingData] = unfurl_targets()
		to = ready[0] if not ready.is_empty() else data.evolves_to
	if to == null:
		return
	var frac: float = hp_fraction()
	data = to
	# A fainted Spirling stays fainted: unfurling is no free revive.
	hp = maxi(1, int(round(frac * max_hp()))) if hp > 0 else 0

func to_dict() -> Dictionary:
	var move_names: Array[String] = []
	for mv: MoveData in moves:
		move_names.append(mv.move_name)
	var out: Dictionary = {
		"species": data.species_name,
		"nickname": nickname,
		"level": level,
		"xp": xp,
		"spark": spark.duplicate(),
		"crystal": crystal.duplicate(),
		"hp": hp,
		"moves": move_names,
		"uid": uid,
		"held": held,
		"prism": prism,
		"hidden_gift": hidden_gift,
		"gift_slot": gift_slot,
		"temper": temperament().id,
		"core": temper_core,
		"gleam": gleam,
		"gleam_boost": gleam_boost,
		"shop": shop_bought,
		"variant": variant,
		"origin_map": origin_map,
		"origin_era": origin_era,
		"met_ring": met_ring,
		"met_day": met_day,
		"lineage": lineage.duplicate(),
		"echo_streak": echo_streak,
		"kinship": kinship,
		"box": box,
		"favorite": favorite,
		"fav_art": fav_art,
		# A lingering status stays on between battles (item 179).
		"status": status,
		"status_turns": status_turns,
	}
	if not bonus_trait.is_empty():
		out["bonus_trait"] = bonus_trait
	if not held_sets.is_empty():
		out["held_sets"] = held_sets.duplicate()
	return out

## Rebuilds a Spirling from to_dict() output. Returns null if the species is unknown.
static func from_dict(d: Dictionary) -> Spirling:
	var sd: SpirlingData = Database.species(str(d.get("species", "")))
	if sd == null:
		return null
	var s := Spirling.new()
	s.data = sd
	s.nickname = str(d.get("nickname", ""))
	s.level = clampi(_num(d.get("level"), 1), 1, LEVEL_SANITY)
	s.xp = _num(d.get("xp"), xp_for_level(s.level))
	var sp: Variant = d.get("spark", {})
	for key: String in STAT_KEYS:
		s.spark[key] = clampi(_num((sp as Dictionary).get(key) if sp is Dictionary else 0, 0), 0, SPARK_MAX)
	var cr: Variant = d.get("crystal", {})
	if cr is Dictionary:
		for key: String in STAT_KEYS:
			var n: int = clampi(_num((cr as Dictionary).get(key), 0), 0, ShopEffects.crystal_cap())
			if n > 0:
				s.crystal[key] = n
	var mv: Variant = d.get("moves", [])
	for move_name: Variant in (mv if mv is Array else []):
		var md: MoveData = Database.move(str(move_name))
		if md != null:
			s.moves.append(md)
	if s.moves.is_empty():
		s.moves = sd.default_moves(s.level, MAX_MOVES)
	s.uid = str(d.get("uid", ""))
	s.held = str(d.get("held", ""))
	for id: Variant in (d.get("held_sets", []) if d.get("held_sets") is Array else []):
		s.held_sets.append(str(id) if BattleRules.is_holdable(str(id)) else "")
	s.prism = d.get("prism") is bool and d.get("prism")
	s.hidden_gift = d.get("hidden_gift") is bool and d.get("hidden_gift")
	s.gift_slot = d.get("gift_slot") is bool and d.get("gift_slot")
	s.bonus_trait = str(d.get("bonus_trait", "")) if TraitKit.traits().has(str(d.get("bonus_trait", ""))) else ""
	# Saves before version 4 have no "temper": keep the one the uid gave them back then.
	s.temper = str(d.get("temper", legacy_temper(s.uid)))
	if not temper_info(s.temper).id == s.temper:
		s.temper = legacy_temper(s.uid)
	s.temper_core = d.get("core") is bool and d.get("core")
	s.gleam = d.get("gleam") is bool and d.get("gleam")
	s.gleam_boost = d.get("gleam_boost") is bool and d.get("gleam_boost") if d.has("gleam_boost") else s.gleam
	s.shop_bought = d.get("shop") is bool and d.get("shop")
	s.variant = str(d.get("variant", ""))
	s.origin_map = str(d.get("origin_map", ""))
	s.origin_era = clampi(_num(d.get("origin_era"), 1), 1, MAX_ERA)
	s.met_ring = _num(d.get("met_ring"), 0)
	s.met_day = _num(d.get("met_day"), 0)
	var lin: Variant = d.get("lineage", [])
	s.lineage.assign((lin as Array).map(func(x: Variant) -> String: return str(x)) if lin is Array else [])
	s.echo_streak = maxi(0, _num(d.get("echo_streak"), 0))
	s.kinship = clampi(_num(d.get("kinship"), 0), 0, 1000)
	s.box = maxi(0, _num(d.get("box"), 0))
	s.favorite = d.get("favorite") is bool and d.get("favorite")
	s.fav_art = str(d.get("fav_art", ""))
	s.hp = clampi(_num(d.get("hp"), s.max_hp()), 0, s.max_hp())
	if StatusRules.lingers(str(d.get("status", ""))) and s.hp > 0:
		s.status = str(d.status)
		s.status_turns = maxi(0, _num(d.get("status_turns"), 0))
	return s

## A save number as int; anything that is not a finite number in int range gives [param fallback].
static func _num(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float and is_finite(v) and absf(v) < 9.0e18:
		return int(v)
	return fallback
