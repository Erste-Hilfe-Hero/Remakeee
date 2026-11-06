class_name Speakers
## Who is speaking when a line names no one (plan item 2011): the NPC's own name, its Wayfarer
## name, or a role such as "Fisher". Lines starting with "Name: " are split by
## Dialogue.split_speaker and shown on the TextBox name tag.

## Roles of villagers whose lines carry no name, by NPC id.
const ROLES: Dictionary = {
	"archivist": "Archivist", "child": "Child", "crier": "Crier", "crystals": "Crystal seller",
	"elder": "Elder", "fisher": "Fisher", "gatherer": "Gatherer", "hauler": "Hauler",
	"hiker": "Hiker", "keeper": "Keeper", "reedcutter": "Reed cutter", "sparkseer": "Sparkseer",
	"trader": "Trader", "aldo": "Aldo", "ines": "Ines", "kestra": "Kestra", "tamsin": "Tamsin",
	"wynn": "Wynn",
}
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
