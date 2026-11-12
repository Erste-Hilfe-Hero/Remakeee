class_name LegendQuests
extends RefCounted
## Lore quest chains of the six legendary Spirlings (data/legend_quests.json, Ali 2026-11-11).
## Each chain: a guide asks for the legend's relic, an old inscription tells its story, a
## witness hands over the relic and warns about the guide. Back at the guide the player hands
## the relic over or keeps it (Trust betrayal "lq_<legend>"): kept means the betrayal is caught,
## handed means the guide strikes first and has to be fought. Either way the legend then waits
## at its place (FirstVoices.LEGENDS "after" is the chain's ready flag).
##
## Bond rules for a legend (wild meeting only): it does not listen above a share of its HP, and
## the chain's outcome changes how readily it bonds afterwards. The shop's Bond Seal stays certain.

const PATH: String = "res://data/legend_quests.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {"bond": {}, "chains": {}}
	return _data

## Chain of [param species] ({} for any other kind).
static func chain(species: String) -> Dictionary:
	var c: Variant = data().get("chains", {}).get(species)
	return c if c is Dictionary else {}

static func species_list() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in data().get("chains", {}):
		out.append(str(k))
	return out

## Story flag of a chain step: "lq_<legend>_<step>" (met, lore1, lore2, kept, handed, ready,
## caught, struck).
static func flag(species: String, step: String) -> String:
	return "lq_%s_%s" % [species.to_lower(), step]

static func betrayal_id(species: String) -> String:
	return "lq_" + species.to_lower()

static func quest_id(species: String) -> String:
	return "legend_" + species.to_lower()

static func is_ready(species: String, flags: Dictionary) -> bool:
	return bool(flags.get(flag(species, "ready"), false))

## Factor on the bond chance of a wild legend: 0 while its HP share is above "listen_below_hp",
## "caught_factor" after the player kept the relic, "struck_factor" after the guide struck it.
## Any other Spirling: 1.
static func bond_factor(target: Spirling, flags: Dictionary) -> float:
	if target == null or target.data == null or chain(target.data.species_name).is_empty():
		return 1.0
	var b: Dictionary = data().get("bond", {})
	if target.hp_fraction() > float(b.get("listen_below_hp", 0.5)):
		return 0.0
	var sp: String = target.data.species_name
	if bool(flags.get(flag(sp, "caught"), false)):
		return float(b.get("caught_factor", 1.0))
	if bool(flags.get(flag(sp, "struck"), false)):
		return float(b.get("struck_factor", 1.0))
	return 1.0

## Errors in data/legend_quests.json against maps, dialogue, quests, clans and story duels.
static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for sp: String in species_list():
		var c: Dictionary = chain(sp)
		var where: String = "legend_quests/%s" % sp
		if Database.species(sp) == null:
			errors.append("%s: unknown species" % where)
		if FirstVoices.entry(sp).is_empty() or str(FirstVoices.entry(sp).get("after", "")) != flag(sp, "ready"):
			errors.append("%s: FirstVoices.LEGENDS must wait for '%s'" % [where, flag(sp, "ready")])
		for part: String in ["guide", "witness"]:
			var p: Dictionary = c.get(part, {})
			var m: MapData = MapData.load_map(str(p.get("map", "")))
			if m == null:
				errors.append("%s: %s map '%s' does not exist" % [where, part, p.get("map", "")])
				continue
			if m.npcs.filter(func(n: Dictionary) -> bool: return str(n.get("id", "")) == str(p.get("npc", ""))).is_empty():
				errors.append("%s: %s '%s' is not on '%s'" % [where, part, p.get("npc", ""), p.map])
		var lore: MapData = MapData.load_map(str(c.get("lore", {}).get("map", "")))
		if lore == null:
			errors.append("%s: lore map does not exist" % where)
		if Trust.betrayal(betrayal_id(sp)).is_empty():
			errors.append("%s: no betrayal '%s' in data/clans.json" % [where, betrayal_id(sp)])
		if not StoryBattles.has(str(c.get("battle", ""))):
			errors.append("%s: story battle '%s' does not exist" % [where, c.get("battle", "")])
		var found: bool = false
		for g: Variant in QuestLog.data().get("side", []):
			found = found or str((g as Dictionary).get("id", "")) == quest_id(sp)
		if not found:
			errors.append("%s: no side goal '%s'" % [where, quest_id(sp)])
	return errors
