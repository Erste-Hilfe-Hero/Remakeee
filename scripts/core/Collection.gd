class_name Collection
extends RefCounted
## Spirlog collection goals (item 49): bonding with more kinds of Spirling earns gifts.
## Each goal pays out once; claimed goals are kept in GameState.records["collection"].

## Rewards are only things from the game itself: items found in Veydal, coins, titles or
## Waymarks (the free season path, plan area 8) (plan area 1, item 410). Never anything the shop sells for Rift glass or real money, so
## collecting stays free of paid shortcuts. Kinds "item", "money" and "title" only.
const REWARD_KINDS: Array[String] = ["item", "money", "title", "waymarks"]

## Total series (item 409) and goals per region (item 408). "bonded": -1 means every kind
## (of that region, or in the game). "region": "" counts every open region.
const GOALS: Array[Dictionary] = [
	{"id": "kinds_3", "bonded": 3, "item": "strong_tonic", "count": 2, "waymarks": 20},
	{"id": "kinds_5", "bonded": 5, "item": "revival_leaf", "count": 1, "waymarks": 30},
	{"id": "kinds_8", "bonded": 8, "item": "spark_charm", "count": 1, "waymarks": 40},
	{"id": "kinds_12", "bonded": 12, "item": "tide_pearl", "count": 1, "waymarks": 60},
	{"id": "kinds_16", "bonded": 16, "item": "max_tonic", "count": 2, "waymarks": 70},
	{"id": "kinds_20", "bonded": 20, "item": "kin_charm", "count": 3, "waymarks": 80},
	{"id": "kinds_25", "bonded": 25, "item": "", "count": 0, "money": 2500, "waymarks": 90},
	{"id": "kinds_30", "bonded": 30, "item": "echo_lumen", "count": 1, "waymarks": 100},
	{"id": "kinds_all", "bonded": -1, "item": "", "count": 0, "money": 5000, "waymarks": 200},
	{"id": "veydal_10", "region": "veydal", "bonded": 10, "item": "", "count": 0, "title": "Veydal Wanderer", "waymarks": 40},
	{"id": "veydal_20", "region": "veydal", "bonded": 20, "item": "spark_charm", "count": 1, "waymarks": 60},
	{"id": "veydal_30", "region": "veydal", "bonded": 30, "item": "", "count": 0, "title": "Veydal Chronicler", "waymarks": 80},
	{"id": "veydal_all", "region": "veydal", "bonded": -1, "item": "", "count": 0, "money": 3000,
		"title": "Keeper of the Veydal Pages", "label": "the Veydal chapter stamp", "waymarks": 150},
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

## Bonded kinds, all or only those of [param region].
static func bonded_in(spirlog: Dictionary, region: String = "") -> int:
	var n: int = 0
	for k: Variant in spirlog:
		var v: Variant = spirlog[k]
		if not (v is Dictionary and bool((v as Dictionary).get("bonded", false))):
			continue
		if not region.is_empty():
			var sd: SpirlingData = Database.species(str(k))
			if sd == null or sd.region != region:
				continue
		n += 1
	return n

## Kinds in [param region] that the Spirlog shows (open regions only).
static func region_total(region: String, flags: Dictionary = {}) -> int:
	var n: int = 0
	for sd: SpirlingData in SpirlogBook.visible_kinds(flags):
		if sd.region == region:
			n += 1
	return n

## How many kinds goal [param goal] needs; [param total] is the size of its pool.
static func goal_need(goal: Dictionary, total: int, flags: Dictionary = {}) -> int:
	var pool: int = total if str(goal.get("region", "")).is_empty() else region_total(str(goal.region), flags)
	return pool if int(goal.bonded) < 0 else int(goal.bonded)

static func goal_have(goal: Dictionary, spirlog: Dictionary) -> int:
	return bonded_in(spirlog, str(goal.get("region", "")))

## The next goal and how many kinds are still missing, nearest first (item 411).
static func next_text(spirlog: Dictionary, total: int, flags: Dictionary = {}) -> String:
	var best: Dictionary = {}
	var best_left: int = 1 << 30
	for g: Dictionary in GOALS:
		var left: int = goal_need(g, total, flags) - goal_have(g, spirlog)
		if left > 0 and left < best_left:
			best = g
			best_left = left
	if best.is_empty():
		return ""
	return "%d more kinds until %s." % [best_left, Loc.t(goal_label(best, total, flags))]

## What a goal is called in the Goals menu.
static func goal_label(g: Dictionary, total: int, flags: Dictionary = {}) -> String:
	if g.has("label"):
		return str(g.label)
	if str(g.get("region", "")).is_empty():
		return "the gift for %d kinds" % goal_need(g, total, flags)
	return "the gift for %d kinds from %s" % [goal_need(g, total, flags), str(g.region).capitalize()]

## Titles earned from goals, in the order they were reached.
static func titles() -> Array[String]:
	var out: Array[String] = []
	for t: Variant in GameState.records.get("titles", []):
		out.append(str(t))
	return out

static func bonded_kinds(spirlog: Dictionary) -> int:
	var n: int = 0
	for v: Variant in spirlog.values():
		if bool((v as Dictionary).get("bonded", false)):
			n += 1
	return n

## How many kinds a goal needs (-1 = every species in the game).
static func needed(goal: Dictionary, total: int) -> int:
	return goal_need(goal, total)

## Goals reached but not yet claimed, in order.
static func ready(spirlog: Dictionary, claimed: Dictionary, total: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in GOALS:
		if not claimed.has(g.id) and goal_have(g, spirlog) >= needed(g, total):
			out.append(g)
	return out

## The next goal still ahead, or {} when all are reached.
static func next_goal(spirlog: Dictionary, total: int) -> Dictionary:
	var have: int = bonded_kinds(spirlog)
	for g: Dictionary in GOALS:
		if str(g.get("region", "")).is_empty() and have < needed(g, total):
			return g
	return {}

## Claims every reached goal: adds the gifts and returns the lines to show.
static func claim() -> Array[String]:
	var claimed: Dictionary = (GameState.records.get("collection", {}) as Dictionary).duplicate()
	var total: int = SpirlogBook.visible_kinds(GameState.flags).size()
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
			if g.id == "kinds_all":
				lines.append("Spirlog complete! Every kind bonded. You received %d coins." % int(g.money))
			else:
				lines.append("Spirlog goal: %d kinds bonded! You received %d coins." % [n, int(g.money)])
		if g.has("title"):
			var t: Array = GameState.records.get("titles", [])
			if not t.has(g.title):
				t.append(str(g.title))
			GameState.records["titles"] = t
			lines.append("New title: %s" % Loc.t(str(g.title)))
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
