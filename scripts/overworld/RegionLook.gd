class_name RegionLook
extends RefCounted
## Era I look of each region (data/region_looks.json): its four screen inks, its biome name and
## arrival line (its tiles: TilesetFactory.atlas_path). Act II Corvane is the dye fens; regions not listed keep the base look.

const PATH: String = "res://data/region_looks.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

static func look(region: String) -> Dictionary:
	return data().get("regions", {}).get(region, {})

static func has_look(region: String) -> bool:
	return not look(region).is_empty()

## The region's four inks, darkest to lightest; empty when the region has no own look.
static func palette(region: String) -> Array[Color]:
	var out: Array[Color] = []
	for h: Variant in look(region).get("palette", []):
		out.append(Color(str(h)))
	return out

static func biome(region: String) -> String:
	return str(look(region).get("biome", ""))

## English line shown the first time the player walks into the region (empty when none).
static func arrive_line(region: String) -> String:
	return str(look(region).get("arrive", ""))
