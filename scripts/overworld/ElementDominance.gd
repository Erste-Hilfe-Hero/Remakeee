class_name ElementDominance
extends RefCounted
## Element dominance per region as a wild spawn table (KAMPF_PLAN_1000 item 102): the region's
## dominant elements join the encounter boost, so their Spirlings step out more often there.
## Data in data/element_dominance.json.

const PATH: String = "res://data/element_dominance.json"

static var _data: Dictionary = {}

static func regions() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = (raw as Dictionary).get("regions", {}) if raw is Dictionary else {}
	return _data

## The dominant elements of [param region]; empty for a region without an entry.
static func boost(region: String) -> Array[int]:
	var out: Array[int] = []
	for e: Variant in regions().get(region, []):
		if Elements.E.has(str(e)) and not int(Elements.E[str(e)]) in out:
			out.append(int(Elements.E[str(e)]))
	return out
