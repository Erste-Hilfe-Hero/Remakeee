class_name Speakers
## Who is speaking in a dialogue, for the name line above the text (plan item 2011).
##
## Story lines often begin with "Name: ". That part moves into the name line. Lines without it
## keep the speaker of the line before, or the NPC's own name (a Wayfarer's name, or a role
## such as "Fisher" for villagers who have none).

## Roles of villagers whose lines carry no name, by NPC id.
const ROLES: Dictionary = {
	"archivist": "Archivist", "child": "Child", "crier": "Crier", "crystals": "Crystal seller",
	"elder": "Elder", "fisher": "Fisher", "gatherer": "Gatherer", "hauler": "Hauler",
	"hiker": "Hiker", "keeper": "Keeper", "reedcutter": "Reed cutter", "sparkseer": "Sparkseer",
	"trader": "Trader", "aldo": "Aldo", "ines": "Ines", "kestra": "Kestra", "tamsin": "Tamsin",
	"wynn": "Wynn",
}
## A name is at most this long, so "Tangled in the reeds: ..." stays narration.
const MAX_NAME: int = 22

## Splits "Kestra: Hello." into ["Kestra", "Hello."]. A name is one or two words, each
## starting with a capital letter. Anything else returns ["", line].
static func split(line: String) -> Array[String]:
	var at: int = line.find(": ")
	if at <= 0 or at > MAX_NAME:
		return ["", line] as Array[String]
	var name: String = line.left(at)
	var words: PackedStringArray = name.split(" ")
	if words.size() > 2:
		return ["", line] as Array[String]
	for w: String in words:
		if w.is_empty() or w[0] != w[0].to_upper() or w[0] == w[0].to_lower():
			return ["", line] as Array[String]
	return [name, line.substr(at + 2)] as Array[String]

## The name to show for [param npc] before any line names someone ("" for signs).
static func name_for(npc: NPC) -> String:
	if npc == null:
		return ""
	var d: Dictionary = npc.definition
	if d.get("name") is String and not str(d.name).is_empty():
		return Loc.t(str(d.name))
	if d.get("trainer") is String and not str(d.trainer).is_empty():
		return Loc.t(str(d.trainer))
	var id: String = npc.npc_id.trim_suffix("_dock")
	return Loc.t(str(ROLES.get(id, "")))
