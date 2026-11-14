class_name IdeasC
extends RefCounted
## Loads data/ideas200c.json (own ideas 200, batch 3) once; each model reads its section.

const PATH: String = "res://data/ideas200c.json"

static var _data: Dictionary = {}

static func section(key: String) -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
	return GameState.as_dict(_data.get(key, {}))

## Spirlings of [param names] at [param ring], skipping unknown species.
static func team(names: Array, ring: int, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: Variant in names:
		if Database.spirlings.has(str(n)):
			out.append(Spirling.new(Database.spirlings[str(n)], clampi(ring, 1, Spirling.STORY_RING), rng))
	return out
