class_name Spirling
extends RefCounted
## A Spirling instance owned by a Wayfarer or met in the wild.
## Holds all mutable state; the SpirlingData it points to is never changed.

const STAT_KEYS: Array[String] = ["hp", "atk", "def", "foc", "spd"]
const SPARK_MAX: int = 12
const MAX_MOVES: int = 4
const START_ENERGY: int = 10
const MAX_ENERGY: int = 10
const MAX_LEVEL: int = 60
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

var data: SpirlingData
var nickname: String = ""
var level: int = 1
var xp: int = 0
var spark: Dictionary[String, int] = {}
var hp: int = 1
var energy: int = START_ENERGY
var status: String = ""
## Turns left for timed statuses (Soak, Daze, Drowse). 0 for open-ended ones.
var status_turns: int = 0
var moves: Array[MoveData] = []
var uid: String = ""
## Held item id ("" for none). Only items with a "held" block can be held.
var held: String = ""
## Rare colour variant. Cosmetic only, never stronger.
var prism: bool = false
## Battle-only stat stages (BattleRules.STAGE_MIN..STAGE_MAX), cleared by end_battle().
var stages: Dictionary[String, int] = {}
## Temperament id (TEMPERAMENTS), stored since save version 4.
var temper: String = ""
## Regional imprint id ("" = none), see plan area 1, item 218.
var variant: String = ""
## Where and when it was met: map id, its ring then, and the day number (days since 1970).
var origin_map: String = ""
var met_ring: int = 0
var met_day: int = 0
## Species names of the two Spirlings that sang it into being (Echo offspring), else empty.
var lineage: Array[String] = []
## Fully right Echo calls in a row while it was in the team (unfold rule "echo_streak").
var echo_streak: int = 0

## [param rng] rolls the hidden Spark values; pass the battle or game RNG for reproducibility.
func _init(d: SpirlingData = null, lvl: int = 1, rng: RandomNumberGenerator = null) -> void:
	if d == null:
		return
	data = d
	level = clampi(lvl, 1, MAX_LEVEL)
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

func display_name() -> String:
	return nickname if not nickname.is_empty() else data.species_name

func elements() -> Array[int]:
	return data.elements

func _curve(base: int, key: String, offset: float, div: float) -> int:
	var s: float = float(base) + float(spark.get(key, 0)) * SPARK_WEIGHT
	return int(floor(s * (float(level) + offset) / div))

## Battle-only max HP multiplier for Rift bosses (BattleRules.BOSSES). Never saved.
var hp_mult: float = 1.0

func max_hp() -> int:
	return maxi(1, int(_curve(data.base_hp, "hp", HP_LEVEL_OFFSET, HP_LEVEL_DIV) * _temper_mult("hp") * hp_mult))

func _stat(key: String) -> int:
	return int((_curve(data.base_stat(key), key, STAT_LEVEL_OFFSET, STAT_LEVEL_DIV) + STAT_FLAT) * _temper_mult(key))

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
	return TEMPER_BONUS if str(temperament().stat) == key else 1.0

## Raw stats (no status modifiers). Battle code uses the effective_* versions.
func atk() -> int: return _stat("atk")
func def() -> int: return _stat("def")
func foc() -> int: return _stat("foc")
func spd() -> int: return _stat("spd")

func stage(stat: String) -> int:
	return int(stages.get(stat, 0))

## ATK after status (Scorch, or the Kindling trait), stages and held item.
func effective_atk() -> int:
	var m: float = StatusRules.atk_mult(status)
	if status == "scorch":
		m = float(BattleRules.trait_info(data.trait_id).get("scorch_atk", m))
	return int(atk() * m * BattleRules.stage_mult(stage("atk")) * BattleRules.mult_key(self, "atk_mult"))

func effective_def() -> int:
	return int(def() * BattleRules.stage_mult(stage("def")) * BattleRules.mult_key(self, "def_mult"))

func effective_foc() -> int:
	return int(foc() * BattleRules.stage_mult(stage("foc")) * BattleRules.mult_key(self, "foc_mult"))

## SPD after status (Soak), stages and held item.
func effective_spd() -> int:
	return int(spd() * StatusRules.spd_mult(status) * BattleRules.stage_mult(stage("spd")) * BattleRules.mult_key(self, "spd_mult"))

func is_fainted() -> bool:
	return hp <= 0

func hp_fraction() -> float:
	return float(hp) / float(max_hp())

func can_afford(move: MoveData) -> bool:
	return energy >= move.energy_cost

## Full heal (rest stops between battles).
func restore() -> void:
	hp = max_hp()
	status = ""
	status_turns = 0
	energy = START_ENERGY

## Clears battle-only state when a battle ends. Statuses do not persist outside battle.
func end_battle() -> void:
	stages.clear()
	status = ""
	status_turns = 0
	energy = START_ENERGY

static func xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	return int(floor(XP_MULT * pow(float(lvl), XP_EXP)))

func xp_to_next() -> int:
	if level >= MAX_LEVEL:
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
	return {
		"species": data.species_name,
		"nickname": nickname,
		"level": level,
		"xp": xp,
		"spark": spark.duplicate(),
		"hp": hp,
		"moves": move_names,
		"uid": uid,
		"held": held,
		"prism": prism,
		"temper": temperament().id,
		"variant": variant,
		"origin_map": origin_map,
		"met_ring": met_ring,
		"met_day": met_day,
		"lineage": lineage.duplicate(),
		"echo_streak": echo_streak,
	}

## Rebuilds a Spirling from to_dict() output. Returns null if the species is unknown.
static func from_dict(d: Dictionary) -> Spirling:
	var sd: SpirlingData = Database.species(str(d.get("species", "")))
	if sd == null:
		return null
	var s := Spirling.new()
	s.data = sd
	s.nickname = str(d.get("nickname", ""))
	s.level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	s.xp = int(d.get("xp", xp_for_level(s.level)))
	var sp: Dictionary = d.get("spark", {})
	for key: String in STAT_KEYS:
		s.spark[key] = clampi(int(sp.get(key, 0)), 0, SPARK_MAX)
	for move_name: Variant in d.get("moves", []):
		var md: MoveData = Database.move(str(move_name))
		if md != null:
			s.moves.append(md)
	if s.moves.is_empty():
		s.moves = sd.default_moves(s.level, MAX_MOVES)
	s.uid = str(d.get("uid", ""))
	s.held = str(d.get("held", ""))
	s.prism = bool(d.get("prism", false))
	# Saves before version 4 have no "temper": keep the one the uid gave them back then.
	s.temper = str(d.get("temper", legacy_temper(s.uid)))
	if not temper_info(s.temper).id == s.temper:
		s.temper = legacy_temper(s.uid)
	s.variant = str(d.get("variant", ""))
	s.origin_map = str(d.get("origin_map", ""))
	s.met_ring = int(d.get("met_ring", 0))
	s.met_day = int(d.get("met_day", 0))
	var lin: Variant = d.get("lineage", [])
	s.lineage.assign((lin if lin is Array else []).map(func(x: Variant) -> String: return str(x)))
	s.echo_streak = maxi(0, int(d.get("echo_streak", 0)))
	s.hp = clampi(int(d.get("hp", s.max_hp())), 0, s.max_hp())
	return s
