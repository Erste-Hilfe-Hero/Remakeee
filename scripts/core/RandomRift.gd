class_name RandomRift
extends RefCounted
## Random Rift (plan items 1107, 1108): every day a new hall put together from a field, a rule
## and rounds echo teams, the same for everyone on that day. A player may fight with three
## rented Spirlings at the hall's ring instead of the own team, so everyone has the same chance.
## The first clear of a day pays Waymarks.

const KEY: String = "random_rift"

var day: String = ""
var field: String = ""
var rule: String = ""
var ring: int = 50

static func data() -> Dictionary:
	return IdeasC.section("random_rift")

func _init(p_day: String) -> void:
	day = p_day
	var d: Dictionary = data()
	var fields: Array = d.get("fields", [])
	var rules: Array = d.get("rules", [])
	field = str(fields[_pick("field", fields.size())]) if not fields.is_empty() else ""
	rule = str(rules[_pick("rule", rules.size())]) if not rules.is_empty() else ""
	ring = int(d.get("ring", 50))

func _pick(what: String, n: int) -> int:
	return absi(hash(["chimora-random-rift", day, what])) % n

func _rng(salt: Variant) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["chimora-random-rift", day, salt])
	return r

func rounds() -> int:
	return int(data().get("rounds", 3))

## Echo team of round [param i] from the whole species list.
func team(i: int) -> Array[Spirling]:
	var r: RandomNumberGenerator = _rng(i)
	var names: Array = Database.spirlings.keys()
	names.sort()
	var pick: Array = []
	for k: int in int(data().get("team", 3)):
		pick.append(names[r.randi_range(0, names.size() - 1)])
	return IdeasC.team(pick, ring, r)

## Today's rental team: the same three for everyone.
func rentals() -> Array[Spirling]:
	var r: RandomNumberGenerator = _rng("rent")
	var pool: Array = (data().get("rental_pool", []) as Array).duplicate()
	var pick: Array = []
	while pick.size() < int(data().get("team", 3)) and not pool.is_empty():
		pick.append(pool.pop_at(r.randi_range(0, pool.size() - 1)))
	return IdeasC.team(pick, ring, r)

func intro() -> String:
	var f: String = Loc.t(str(BattleRules.FIELDS[field].label)) if BattleRules.FIELDS.has(field) else field
	var ru: String = Loc.t(str(BattleRules.RULES[rule].label)) if BattleRules.RULES.has(rule) else rule
	return Loc.t(str(data().get("intro", "%s %s"))) % [f, ru]

func cleared() -> bool:
	return str(GameState.records.get(KEY, "")) == day

## Books today's clear. Returns the reward lines (once a day).
func clear() -> Array[String]:
	if cleared():
		return [] as Array[String]
	GameState.records[KEY] = day
	return Waymarks.reward_lines(Waymarks.earn(int(data().get("waymarks", 0)), "tower"))
