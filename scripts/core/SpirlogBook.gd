class_name SpirlogBook
extends RefCounted
## The Spirlog as pages of Mirela's map book (plan area 1, items 64, 243-251): chapters per
## region, search and filters, lore that opens up step by step, where a kind was found and
## its unfold line. Pure data so the menu and the tests share it.

## Status filter values.
const STATUS_ALL: int = 0
const STATUS_BONDED: int = 1
const STATUS_SEEN_ONLY: int = 2
const STATUS_MISSING: int = 3
const STATUS_NAMES: Array[String] = ["all", "bonded", "only seen", "missing"]
## Battles with a kind in the team before its third lore sentence opens (item 250).
const LORE_BATTLES: int = 10
## Ground symbol per map (item 244): what you walked through when you met it.
const GROUNDS: Dictionary[String, String] = {
	"fernstair": "fern", "crowcrest": "scree", "thornridge": "scree", "saltmarsh": "reed",
	"murk_hollow": "cave", "cinder_rift": "rift", "tide_rift": "rift",
}
const GROUND_WORDS: Dictionary[String, String] = {
	"fern": "Fern", "scree": "Scree", "reed": "Reed", "cave": "Cave", "rift": "Rift", "": "Path",
}

## Veydal is always open; the others once GameState has the flag "region_open_<id>".
static func region_open(region: String, flags: Dictionary) -> bool:
	return region == "veydal" or bool(flags.get("region_open_%s" % region, false))

## Regions whose chapter is shown, in SpirlingData.REGIONS order.
static func open_regions(flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for r: String in SpirlingData.REGIONS:
		if region_open(r, flags):
			out.append(r)
	return out

## Every kind of the open regions, by Spirlog number. Kinds of closed regions stay hidden,
## so "all kinds" always means a number the player can reach (item 64).
static func visible_kinds(flags: Dictionary) -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		if region_open(sd.region, flags):
			out.append(sd)
	out.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	return out

static func entry(spirlog: Dictionary, species: String) -> Dictionary:
	return GameState.upgrade_spirlog_entry(spirlog.get(species, {}))

static func is_seen(spirlog: Dictionary, species: String) -> bool:
	return bool(entry(spirlog, species).seen)

static func is_bonded(spirlog: Dictionary, species: String) -> bool:
	return bool(entry(spirlog, species).bonded)

## {"region", "total", "seen", "bonded"} for one chapter (item 251).
static func chapter_progress(region: String, spirlog: Dictionary) -> Dictionary:
	var out: Dictionary = {"region": region, "total": 0, "seen": 0, "bonded": 0}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region != region:
			continue
		out.total = int(out.total) + 1
		out.seen = int(out.seen) + (1 if is_seen(spirlog, sd.species_name) else 0)
		out.bonded = int(out.bonded) + (1 if is_bonded(spirlog, sd.species_name) else 0)
	return out

static func chapter_line(region: String, spirlog: Dictionary) -> String:
	var p: Dictionary = chapter_progress(region, spirlog)
	return "%s: %d seen, %d bonded" % [region.capitalize(), int(p.seen), int(p.bonded)]

## Kinds of the open regions that pass the filters (item 249). [param search] matches the name
## of seen kinds only, [param element] -1 and [param role] "" mean any.
static func filtered(spirlog: Dictionary, flags: Dictionary, search: String = "", element: int = -1,
		role: String = "", status: int = STATUS_ALL, region: String = "") -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	var q: String = search.strip_edges().to_lower()
	for sd: SpirlingData in visible_kinds(flags):
		var seen: bool = is_seen(spirlog, sd.species_name)
		var bonded: bool = is_bonded(spirlog, sd.species_name)
		if not region.is_empty() and sd.region != region:
			continue
		if not q.is_empty() and (not seen or sd.species_name.to_lower().find(q) < 0):
			continue
		# Element and role are only known once a kind has been seen.
		if element >= 0 and (not seen or not element in sd.elements):
			continue
		if not role.is_empty() and (not seen or sd.role != role):
			continue
		match status:
			STATUS_BONDED:
				if not bonded:
					continue
			STATUS_SEEN_ONLY:
				if not seen or bonded:
					continue
			STATUS_MISSING:
				if seen:
					continue
		out.append(sd)
	return out

## One list row: "07 * Mossling" (bonded), "+" (seen) or "07   ???" for an outline (item 245).
static func list_line(sd: SpirlingData, spirlog: Dictionary) -> String:
	var seen: bool = is_seen(spirlog, sd.species_name)
	var mark: String = " "
	if is_bonded(spirlog, sd.species_name):
		# A star once one of this kind grew to Ring 30 (plan area 8).
		mark = Collection.STAR if Collection.starred(sd.species_name) else "*"
	elif seen:
		mark = "+"
	return "%02d %s %s" % [sd.dex_id, mark, sd.species_name if seen else "???"]

## The lore sentences that are open: the first when seen, the second when bonded, the rest
## after LORE_BATTLES battles with one of this kind in the team (item 250).
static func lore_sentences(sd: SpirlingData, spirlog: Dictionary) -> PackedStringArray:
	var e: Dictionary = entry(spirlog, sd.species_name)
	var all: PackedStringArray = split_sentences(sd.lore)
	var n: int = 0
	if bool(e.seen):
		n = 1
	if bool(e.bonded):
		n = 2
	if int(e.get("battles", 0)) >= LORE_BATTLES:
		n = all.size()
	return all.slice(0, mini(n, all.size()))

static func split_sentences(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur: String = ""
	for i: int in text.length():
		cur += text[i]
		if text[i] in [".", "!", "?"] and (i + 1 >= text.length() or text[i + 1] == " "):
			out.append(cur.strip_edges())
			cur = ""
	if not cur.strip_edges().is_empty():
		out.append(cur.strip_edges())
	return out

## Maps where the kind has been seen, each with its ground symbol (item 244).
static func found_on(sd: SpirlingData, spirlog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Variant in entry(spirlog, sd.species_name).get("maps", []):
		var id: String = str(m)
		out.append({"map": id, "name": Spirling.place_name(id), "ground": str(GROUNDS.get(id, ""))})
	return out

static func found_line(sd: SpirlingData, spirlog: Dictionary) -> String:
	var parts: PackedStringArray = []
	for f: Dictionary in found_on(sd, spirlog):
		parts.append("%s (%s)" % [f.name, GROUND_WORDS.get(f.ground, "Path")])
	return ", ".join(parts)

## The whole unfold line of a kind, first form first (item 247).
static func line_of(sd: SpirlingData) -> Array[SpirlingData]:
	var first: SpirlingData = sd
	var guard: int = 0
	while Database.earlier_form(first) != null and guard < 8:
		first = Database.earlier_form(first)
		guard += 1
	var out: Array[SpirlingData] = [first]
	var i: int = 0
	while i < out.size() and out.size() < 8:
		for p: Dictionary in out[i].unfold:
			var to: SpirlingData = p.to
			if not out.has(to):
				out.append(to)
		i += 1
	return out

## The page text under the sprite (item 243). Unseen kinds have no page.
static func page_text(sd: SpirlingData, spirlog: Dictionary) -> String:
	var lines: PackedStringArray = []
	var els: PackedStringArray = []
	for el: int in sd.elements:
		els.append(Elements.element_name(el))
	lines.append("#%02d %s" % [sd.dex_id, sd.species_name])
	lines.append("/".join(els))
	if not sd.height.is_empty():
		lines.append("Height %s" % sd.height)
	if not sd.habitat.is_empty():
		lines.append("Lives in: %s" % sd.habitat)
	var found: String = found_line(sd, spirlog)
	lines.append("Found on: %s" % (found if not found.is_empty() else "unknown"))
	var bonded: bool = is_bonded(spirlog, sd.species_name)
	if bonded:
		lines.append("Origin: %s" % sd.origin)
		var tr: Dictionary = BattleRules.trait_info(sd.trait_id)
		if not tr.is_empty():
			lines.append("Gift: %s" % tr.label)
	lines.append("")
	for s: String in lore_sentences(sd, spirlog):
		lines.append(s)
	# Plan item 1706 (story area): a Rift and region line once the kind is bonded.
	if bonded and not SpirlogLore.line(sd.species_name).is_empty():
		lines.append(SpirlogLore.line(sd.species_name))
	if not bonded:
		lines.append("Bond with one to learn more.")
	elif lore_sentences(sd, spirlog).size() < split_sentences(sd.lore).size():
		lines.append("Travel with one to learn more.")
	return "\n".join(lines)
