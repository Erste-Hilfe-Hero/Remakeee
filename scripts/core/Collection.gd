class_name Collection
extends RefCounted
## Spirlog collection goals (item 49, plan area 8): bonding with more kinds of Spirling earns
## gifts and Waymarks, and seeing more kinds earns Waymarks too. Each goal pays out once;
## claimed goals are kept in GameState.records["collection"].

const GOALS: Array[Dictionary] = [
	{"id": "kinds_3", "bonded": 3, "item": "strong_tonic", "count": 2, "waymarks": 20},
	{"id": "kinds_5", "bonded": 5, "item": "revival_leaf", "count": 1, "waymarks": 30},
	{"id": "kinds_8", "bonded": 8, "item": "spark_charm", "count": 1, "waymarks": 40},
	{"id": "kinds_11", "bonded": 11, "item": "tide_pearl", "count": 1, "waymarks": 60},
	{"id": "kinds_all", "bonded": -1, "item": "", "count": 0, "money": 5000, "waymarks": 200},
]
## "Seen" steps (plan 3351): Waymarks only.
const SEEN_GOALS: Array[Dictionary] = [
	{"id": "seen_5", "seen": 5, "waymarks": 10},
	{"id": "seen_10", "seen": 10, "waymarks": 20},
	{"id": "seen_15", "seen": 15, "waymarks": 30},
	{"id": "seen_all", "seen": -1, "waymarks": 60},
]
## Bonded and grown to this ring: the species gets a star in the Spirlog (plan 3353).
const STAR_LEVEL: int = 30
const STAR: String = "\ue002"

static func seen_kinds(spirlog: Dictionary) -> int:
	var n: int = 0
	for v: Variant in spirlog.values():
		if v is Dictionary and bool((v as Dictionary).get("seen", false)):
			n += 1
	return n

## True if [param species] is bonded and one of the player's Spirlings of it is ring 30 or more.
static func starred(species: String) -> bool:
	if not bool((GameState.spirlog.get(species, {}) as Dictionary).get("bonded", false)):
		return false
	for s: Spirling in Achievements.all_spirlings():
		if s.data.species_name == species and s.level >= STAR_LEVEL:
			return true
	return false

static func bonded_kinds(spirlog: Dictionary) -> int:
	var n: int = 0
	for v: Variant in spirlog.values():
		if bool((v as Dictionary).get("bonded", false)):
			n += 1
	return n

## How many kinds a goal needs (-1 = every species in the game).
static func needed(goal: Dictionary, total: int) -> int:
	return total if int(goal.bonded) < 0 else int(goal.bonded)

## Goals reached but not yet claimed, in order.
static func ready(spirlog: Dictionary, claimed: Dictionary, total: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var have: int = bonded_kinds(spirlog)
	for g: Dictionary in GOALS:
		if not claimed.has(g.id) and have >= needed(g, total):
			out.append(g)
	return out

## The next goal still ahead, or {} when all are reached.
static func next_goal(spirlog: Dictionary, total: int) -> Dictionary:
	var have: int = bonded_kinds(spirlog)
	for g: Dictionary in GOALS:
		if have < needed(g, total):
			return g
	return {}

## Claims every reached goal: adds the gifts and returns the lines to show.
static func claim() -> Array[String]:
	var claimed: Dictionary = (GameState.records.get("collection", {}) as Dictionary).duplicate()
	var total: int = Database.spirlings.size()
	var lines: Array[String] = []
	for g: Dictionary in ready(GameState.spirlog, claimed, total):
		claimed[g.id] = true
		var n: int = needed(g, total)
		if str(g.item) != "":
			GameState.add_item(str(g.item), int(g.count))
			var item_name: String = str(Database.item(str(g.item)).get("name", g.item))
			lines.append("Spirlog goal: %d kinds bonded! You received %s x%d." % [n, item_name, int(g.count)])
		if int(g.get("money", 0)) > 0:
			GameState.money += int(g.money)
			lines.append("Spirlog complete! Every kind bonded. You received %d coins." % int(g.money))
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(int(g.get("waymarks", 0)), "collection")))
	var seen: int = seen_kinds(GameState.spirlog)
	for g: Dictionary in SEEN_GOALS:
		var need: int = total if int(g.seen) < 0 else int(g.seen)
		if claimed.has(g.id) or seen < need:
			continue
		claimed[g.id] = true
		lines.append(Loc.t("Spirlog: %d kinds seen!") % need)
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(int(g.waymarks), "collection")))
	if not lines.is_empty():
		GameState.records["collection"] = claimed
	return lines

## "Bonded 4 of 21 kinds. Next gift at 6." for the Spirlog and Records screens.
static func progress_text(spirlog: Dictionary, total: int) -> String:
	var g: Dictionary = next_goal(spirlog, total)
	if g.is_empty():
		return "Bonded %d of %d kinds." % [bonded_kinds(spirlog), total]
	return "Bonded %d of %d kinds. Next gift at %d." % [bonded_kinds(spirlog), total, needed(g, total)]
