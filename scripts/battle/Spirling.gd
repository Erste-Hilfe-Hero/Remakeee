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
## Temperament (item 37): a small, penalty-free lean toward one stat, read from the uid so it
## needs no extra RNG roll and old saves keep a stable temperament.
const TEMPERAMENTS: Array[Dictionary] = [
	{"id": "fierce", "label": "Fierce", "stat": "atk", "text": "Hits a little harder."},
	{"id": "stalwart", "label": "Stalwart", "stat": "def", "text": "Shrugs off blows a little better."},
	{"id": "keen", "label": "Keen", "stat": "foc", "text": "Focuses a little sharper."},
	{"id": "brisk", "label": "Brisk", "stat": "spd", "text": "Moves a little quicker."},
	{"id": "hearty", "label": "Hearty", "stat": "hp", "text": "Has a little more stamina."},
	{"id": "even", "label": "Even", "stat": "", "text": "Calm and balanced."},
]
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
## Battle-only: turns left on an Energy tax (energy_tax effect): every move costs more meanwhile.
## Counted down at the end of each turn, so a fresh tax of N holds for the next N turns.
var energy_tax: int = 0
## Battle-only: move name -> turns it stays locked (moves.json "cooldown"), same counting.
var cooldowns: Dictionary[String, int] = {}
## Battle-only: turns left on a heal block (heal_block effect), same counting.
var heal_block: int = 0
## Battle-only: turns left in which an energy_burn can't take Energy again, same counting.
var burn_guard: int = 0

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

## Index into TEMPERAMENTS, derived from the uid (a fixed index for uid-less test Spirlings).
static func temperament_index(p_uid: String) -> int:
	if p_uid.is_empty():
		return TEMPERAMENTS.size() - 1
	return absi(p_uid.hash()) % TEMPERAMENTS.size()

func temperament() -> Dictionary:
	return TEMPERAMENTS[temperament_index(uid)]

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

## Energy [param move] costs right now: its own cost plus the Energy tax while one lasts.
func move_cost(move: MoveData) -> int:
	return move.energy_cost + (BattleRules.ENERGY_TAX_COST if energy_tax > 0 else 0)

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
	if heal_block > 0:
		heal_block -= 1
	if burn_guard > 0:
		burn_guard -= 1
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

## Clears battle-only state when a battle ends. Statuses do not persist outside battle.
func end_battle() -> void:
	stages.clear()
	energy_tax = 0
	heal_block = 0
	burn_guard = 0
	cooldowns.clear()
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
	if data.evolves_to == null or data.evolve_level <= 0 or level < data.evolve_level:
		return false
	return data.evolve_map.is_empty() or data.evolve_map == map_id

func can_evolve_with(item_id: String) -> bool:
	return data.evolves_to != null and not data.evolve_item.is_empty() and data.evolve_item == item_id

## Unfurling (Chimora's own form change): never automatic. Once a Spirling has enough rings
## (or stands in its special place), the player may unfurl it from the Team menu, and may
## furl it back to its earlier form at any time. Rings, arts and Spark stay the same.
func can_unfurl(map_id: String = "") -> bool:
	return can_evolve(map_id)

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

## Evolves in place (new species, same Spark, level, moves and HP fraction).
func evolve() -> void:
	if data.evolves_to == null:
		return
	var frac: float = hp_fraction()
	data = data.evolves_to
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
	s.hp = clampi(int(d.get("hp", s.max_hp())), 0, s.max_hp())
	return s
