class_name Landmarks
extends RefCounted
## Era I landmarks (map design plan item 509): each outdoor place of Acts I-III has one tall
## thing you know it by, from its act's own set (data/landmarks.json, art from
## tools/art/gen_landmarks.py). The sprite stands on a solid map cell and covers the cell above.

const PATH: String = "res://data/landmarks.json"
## Which act draws which kinds. A kind belongs to exactly one region (its name prefix).
const KINDS: Dictionary[String, Array] = {
	"veydal": ["standing_stone", "cairn", "beacon", "tide_post"],
	"corvane": ["heron_post", "drying_rack", "sluice_wheel", "dye_mill"],
	"ashmere": ["smelter_stack", "bell_frame", "salt_obelisk"],
}

static var _maps: Dictionary = {}

static func all() -> Dictionary:
	if _maps.is_empty():
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_maps = (d as Dictionary).get("maps", {})
	return _maps

## The landmark of [param map_id], or {}.
static func for_map(map_id: String) -> Dictionary:
	return all().get(map_id, {})

static func cell(lm: Dictionary) -> Vector2i:
	return Vector2i(int(lm.get("x", -1)), int(lm.get("y", -1)))

## The region a kind belongs to ("" when no act draws it).
static func region_of(kind: String) -> String:
	for r: String in KINDS:
		for k: String in KINDS[r]:
			if kind == "%s_%s" % [r, k]:
				return r
	return ""

## res:// path of the sprite for [param kind] in the active era (falls back to Era I).
static func art_path(kind: String) -> String:
	return EraManager.art_path("landmarks/%s.png" % kind)

## What talking to the landmark on [param at] of [param map_id] shows (translated), or [].
static func lines_at(map_id: String, at: Vector2i) -> Array[String]:
	var lm: Dictionary = for_map(map_id)
	if lm.is_empty() or cell(lm) != at:
		return [] as Array[String]
	return [Loc.t(str(lm.name)), Loc.t(str(lm.line))] as Array[String]
