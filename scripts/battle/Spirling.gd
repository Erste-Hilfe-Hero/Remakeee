class_name Spirling
extends RefCounted
## A Spirling instance owned by a Tamer or met in the wild.
## Holds all mutable state; the SpirlingData it points to is never changed.

const STAT_KEYS: Array[String] = ["hp", "atk", "def", "foc", "spd"]
const SPARK_MAX: int = 15
const MAX_MOVES: int = 4
const START_ENERGY: int = 10
const MAX_ENERGY: int = 10
const MAX_LEVEL: int = 100

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

func max_hp() -> int:
	return maxi(1, _curve(data.base_hp, "hp", HP_LEVEL_OFFSET, HP_LEVEL_DIV))

func _stat(key: String) -> int:
	return _curve(data.base_stat(key), key, STAT_LEVEL_OFFSET, STAT_LEVEL_DIV) + STAT_FLAT

## Raw stats (no status modifiers). Battle code uses the effective_* versions.
func atk() -> int: return _stat("atk")
func def() -> int: return _stat("def")
func foc() -> int: return _stat("foc")
func spd() -> int: return _stat("spd")

## ATK after status modifiers (Scorch).
func effective_atk() -> int:
	return int(atk() * StatusRules.atk_mult(status))

## SPD after status modifiers (Soak).
func effective_spd() -> int:
	return int(spd() * StatusRules.spd_mult(status))

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

## True if this Spirling has reached its evolution level.
func can_evolve() -> bool:
	return data.evolves_to != null and data.evolve_level > 0 and level >= data.evolve_level

## Evolves in place (new species, same Spark, level, moves and HP fraction).
func evolve() -> void:
	if data.evolves_to == null:
		return
	var frac: float = hp_fraction()
	data = data.evolves_to
	hp = maxi(1, int(round(frac * max_hp())))

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
	s.hp = clampi(int(d.get("hp", s.max_hp())), 0, s.max_hp())
	return s
