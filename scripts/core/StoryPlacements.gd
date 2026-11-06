class_name StoryPlacements
extends RefCounted
## Story figures and signs placed on maps from outside the map files (plan area 4):
## data/story_npcs.json maps a map id to {"npcs": [...], "signs": [...]} in the map format.
## Area 3 builds the maps; the story adds its people and triggers here, so a figure appears
## as soon as its map exists, and nobody has to edit someone else's map file.

const PATH: String = "res://data/story_npcs.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

static func for_map(map_id: String) -> Dictionary:
	var d: Variant = data().get(map_id)
	return d if d is Dictionary else {}

## Adds the story figures and signs for [param m] (called by MapData.load_map with the map
## file). An entry may name a "spot" instead of x/y: the map file's "spots" {"name": [x, y]}
## gives the cell, so area 3 decides where on its map a story figure stands.
## Entries whose spot the map does not have yet are left out.
static func apply(m: MapData, raw: Dictionary = {}) -> void:
	var extra: Dictionary = for_map(m.id)
	var spots: Dictionary = raw.get("spots", {}) if raw.get("spots") is Dictionary else {}
	for kind: String in ["npcs", "signs"]:
		for e: Variant in extra.get(kind, []):
			if not e is Dictionary:
				continue
			var d: Dictionary = (e as Dictionary).duplicate(true)
			if d.has("spot"):
				var c: Variant = spots.get(str(d.spot))
				if not (c is Array and (c as Array).size() == 2):
					continue
				d["x"] = int(c[0])
				d["y"] = int(c[1])
			if kind == "npcs":
				m.npcs.append(d)
			else:
				m.signs.append(d)

## The scene to play when the player enters [param map_id], or "" (once per scene, and only
## while its "if" holds). Entry format: "on_enter": {"scene": "id", "if": {...}}.
static func enter_scene(map_id: String, flags: Dictionary) -> String:
	var on: Variant = for_map(map_id).get("on_enter")
	if not on is Dictionary:
		return ""
	var id: String = str((on as Dictionary).get("scene", ""))
	if id.is_empty() or bool(flags.get(ScenePlayer.seen_flag(id), false)):
		return ""
	if (on as Dictionary).has("if") and not Dialogue.check(on.get("if"), flags):
		return ""
	return id

## Spot names the story needs on [param map_id] (for the validator and area 3).
static func spots_needed(map_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var extra: Dictionary = for_map(map_id)
	for kind: String in ["npcs", "signs"]:
		for e: Variant in extra.get(kind, []):
			if e is Dictionary and (e as Dictionary).has("spot"):
				out.append(str(e.spot))
	return out
