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
## Set goals (plan 3355-3365): Waymarks once each. "kind" names what is counted
## (set_count), "n" -1 means the whole set (set_total).
const SET_GOALS: Array[Dictionary] = [
	{"id": "ring30_5", "kind": "ring30", "n": 5, "waymarks": 20, "label": "Kinds at ring 30"},
	{"id": "ring30_10", "kind": "ring30", "n": 10, "waymarks": 40, "label": "Kinds at ring 30"},
	{"id": "ring30_all", "kind": "ring30", "n": -1, "waymarks": 100, "label": "Kinds at ring 30"},
	{"id": "lines_seen", "kind": "lines", "n": -1, "waymarks": 50, "label": "Lines seen in every form"},
	{"id": "arts_20", "kind": "arts", "n": 20, "waymarks": 20, "label": "Arts used"},
	{"id": "arts_40", "kind": "arts", "n": 40, "waymarks": 40, "label": "Arts used"},
	{"id": "arts_all", "kind": "arts", "n": -1, "waymarks": 80, "label": "Arts used"},
	{"id": "elements", "kind": "elements", "n": -1, "waymarks": 40, "label": "Elements bonded"},
	{"id": "pages", "kind": "pages", "n": -1, "waymarks": 100, "label": "Map book pages"},
	{"id": "keepsakes", "kind": "keepsakes", "n": -1, "waymarks": 50, "label": "Keepsakes held"},
	{"id": "temperaments", "kind": "temperaments", "n": -1, "waymarks": 50, "label": "Temperaments met"},
	{"id": "places", "kind": "places", "n": -1, "waymarks": 60, "label": "Kinds seen at every place"},
]

## Arts the player's Spirlings can learn (boss-only arts do not count).
static func learnable_arts() -> Array[String]:
	var seen: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		for mv: MoveData in sd.learnset_moves:
			if mv != null:
				seen[mv.move_name] = true
	var out: Array[String] = []
	for k: Variant in seen:
		out.append(str(k))
	out.sort()
	return out

## Notes an art used by the player's side in battle (BattleScene).
static func note_art(art: String) -> void:
	var used: Array = GameState.records.get("arts_used", [])
	if not art in used:
		used.append(art)
		GameState.records["arts_used"] = used

# --- Places, art book, Prism page and collector cards (plan 3358, 3360, 3361, 3364, 3366) ---

static var _habitats: Dictionary = {}

## Maps whose wild table has [param species], in map order (plan 3361).
static func habitat_maps(species: String) -> Array[String]:
	if _habitats.is_empty():
		for id: String in MapData.all_ids():
			var m: MapData = MapData.load_map(id)
			if m == null or m.encounter_table.is_empty():
				continue
			for sp: String in EncounterTable.species_on(m.encounter_table):
				if not _habitats.has(sp):
					_habitats[sp] = []
				if not id in (_habitats[sp] as Array):
					(_habitats[sp] as Array).append(id)
		_habitats["_built"] = []
	var out: Array[String] = []
	for id: Variant in _habitats.get(species, []):
		out.append(str(id))
	return out

## Habitat maps where the player has seen [param species].
static func places_seen(species: String) -> Array[String]:
	var maps: Array = (GameState.spirlog.get(species, {}) as Dictionary).get("maps", []) if GameState.spirlog.get(species) is Dictionary else []
	return habitat_maps(species).filter(func(id: String) -> bool: return id in maps)

static func places_done(species: String) -> bool:
	var all: Array[String] = habitat_maps(species)
	return not all.is_empty() and places_seen(species).size() == all.size()

static func _place_kinds() -> Array[SpirlingData]:
	return SpirlogBook.visible_kinds(GameState.flags).filter(func(sd: SpirlingData) -> bool: return not habitat_maps(sd.species_name).is_empty())

## Spirlog page line: places seen get their name and a "+", the others stay "???" (plan 3361).
static func places_line(species: String) -> String:
	var all: Array[String] = habitat_maps(species)
	if all.is_empty():
		return ""
	var seen: Array[String] = places_seen(species)
	var parts: PackedStringArray = []
	for id: String in all:
		parts.append(Spirling.place_name(id) + " +" if id in seen else "???")
	return Loc.t("Places: %s (%d of %d)") % [", ".join(parts), seen.size(), all.size()]

## The art book (plan 3358): every learnable art, a "+" before each one used in battle.
static func art_book_lines() -> Array[String]:
	var used: Array = GameState.records.get("arts_used", [])
	var arts: Array[String] = learnable_arts()
	var out: Array[String] = [Loc.t("Art book: %d of %d used") % [set_count("arts"), arts.size()]]
	for a: String in arts:
		out.append(("+ " if a in used else "  ") + Loc.t(a))
	return out

## Kinds met in Prism colours, for their own Spirlog page (plan 3364). No odds are shown.
static func prism_kinds() -> Array[String]:
	var out: Array[String] = []
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		var e: Variant = GameState.spirlog.get(sd.species_name)
		if e is Dictionary and bool((e as Dictionary).get("prism_seen", false)):
			out.append(sd.species_name)
	return out

static func prism_lines() -> Array[String]:
	var kinds: Array[String] = prism_kinds()
	var out: Array[String] = [Loc.t("Prism page: %d of %d kinds met in Prism colours") % [kinds.size(), SpirlogBook.visible_kinds(GameState.flags).size()]]
	for sp: String in kinds:
		out.append("  " + sp)
	return out

## Every art the kind's whole line can learn.
static func line_arts(sd: SpirlingData) -> Array[String]:
	var out: Array[String] = []
	for member: SpirlingData in SpirlogBook.line_of(sd):
		for mv: MoveData in member.learnset_moves:
			if mv != null and not mv.move_name in out:
				out.append(mv.move_name)
	return out

## A collector card opens once the kind is bonded, at ring 30 and every art of its line was used (plan 3366).
static func card_open(sd: SpirlingData) -> bool:
	if not starred(sd.species_name):
		return false
	var used: Array = GameState.records.get("arts_used", [])
	return line_arts(sd).all(func(a: String) -> bool: return a in used)

static func cards_open() -> int:
	return SpirlogBook.visible_kinds(GameState.flags).filter(func(sd: SpirlingData) -> bool: return card_open(sd)).size()

## Visible kinds grouped by line ("line_id", else the kind itself).
static func lines() -> Dictionary:
	var out: Dictionary = {}
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		var key: String = sd.line_id if sd.line_id != "" else sd.species_name
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(sd.species_name)
	return out

static func _seen(species: String) -> bool:
	return bool((GameState.spirlog.get(species, {}) as Dictionary).get("seen", false))

static func _bonded(species: String) -> bool:
	return bool((GameState.spirlog.get(species, {}) as Dictionary).get("bonded", false))

static func set_count(kind: String) -> int:
	match kind:
		"ring30":
			return SpirlogBook.visible_kinds(GameState.flags).filter(func(sd: SpirlingData) -> bool: return starred(sd.species_name)).size()
		"lines":
			var n: int = 0
			var l: Dictionary = lines()
			for k: Variant in l:
				if (l[k] as Array).all(func(sp: Variant) -> bool: return _seen(str(sp))):
					n += 1
			return n
		"arts":
			var used: Array = GameState.records.get("arts_used", [])
			return learnable_arts().filter(func(a: String) -> bool: return a in used).size()
		"elements":
			var els: Dictionary = {}
			for sd: SpirlingData in Database.spirlings.values():
				if _bonded(sd.species_name):
					for e: int in sd.elements:
						els[e] = true
			return els.size()
		"pages":
			return Overworld.pages_found(GameState.flags)
		"keepsakes":
			return Achievements.stat("keepsakes")
		"places":
			return _place_kinds().filter(func(sd: SpirlingData) -> bool: return places_done(sd.species_name)).size()
		"temperaments":
			var t: Dictionary = {}
			for s: Spirling in Achievements.all_spirlings():
				t[str(s.temperament().id)] = true
			return t.size()
	return 0

static func set_total(kind: String) -> int:
	match kind:
		"ring30":
			return SpirlogBook.visible_kinds(GameState.flags).size()
		"lines":
			return lines().size()
		"arts":
			return learnable_arts().size()
		"elements":
			return Elements.E.size()
		"pages":
			return Overworld.PAGE_COUNT
		"keepsakes":
			return Achievements.keepsakes().size()
		"temperaments":
			return Spirling.TEMPERAMENTS.size()
		"places":
			return _place_kinds().size()
	return 0

static func set_need(g: Dictionary) -> int:
	return set_total(str(g.kind)) if int(g.n) < 0 else int(g.n)

## One line per kind of set goal, for its next step: "Arts used: 12/20".
static func set_lines() -> Array[String]:
	var claimed: Dictionary = GameState.records.get("collection", {})
	var pick: Dictionary = {}
	var order: Array[String] = []
	for g: Dictionary in SET_GOALS:
		var kind: String = str(g.kind)
		if not pick.has(kind):
			order.append(kind)
			pick[kind] = g
		elif claimed.has(str((pick[kind] as Dictionary).id)):
			pick[kind] = g
	var out: Array[String] = []
	for kind: String in order:
		var g: Dictionary = pick[kind]
		var need: int = set_need(g)
		out.append("%s: %d/%d" % [Loc.t(str(g.label)), mini(set_count(kind), need), need])
	return out

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
	for g: Dictionary in SET_GOALS:
		if claimed.has(g.id) or set_count(str(g.kind)) < set_need(g):
			continue
		claimed[g.id] = true
		lines.append(Loc.t("Collection goal: %s %d/%d!") % [Loc.t(str(g.label)), set_need(g), set_need(g)])
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
