class_name SpriteTiers
extends RefCounted
## Spirling sprite tiers (data/sprite_tiers.json, docs/ERA_SPRITE_TIERS.md). A Spirling keeps the
## look of its origin era; its tier is the era folder its art lives in. tools/art/gen_tiers.py
## builds the menu icons and the pose sheet of every kind from its front/back sprite. In an Era V
## battle every Spirling moves in its own tier's style: two ink frames for an Era I kind, full
## strips for an Era V kind.

const PATH: String = "res://data/sprite_tiers.json"
const HIDDEN: int = -1
const FLASH: int = -2
const FACINGS: Array[String] = ["front", "back"]
const HUE_SHADER_PATH: String = "res://shaders/gleam_hue.gdshader"

static var _cfg: Dictionary = {}
static var _icons: Dictionary = {}

static func config() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"tiers": {}}
	return _cfg

static func kinds() -> Array:
	return config().get("kinds", [])

## Rules of tier [param era] ({} when unknown).
static func tier(era: int) -> Dictionary:
	return (config().get("tiers", {}) as Dictionary).get(str(era), {})

## Tier of a sprite path ("res://art/era3/spirlings/x_front.png" -> 3), 0 when it is not era art.
static func tier_of_path(sprite_path: String) -> int:
	var at: int = sprite_path.find("/art/era")
	return int(sprite_path.substr(at + 8, 1)) if at >= 0 else 0

## Kind id of a sprite path ("…/kindlop_front.png" -> "kindlop").
static func id_of_path(sprite_path: String) -> String:
	var base: String = sprite_path.get_file().get_basename()
	for f: String in FACINGS:
		if base.ends_with("_" + f):
			return base.trim_suffix("_" + f)
	return base

## Pose sheet next to a sprite, "" when it has none.
static func sheet_path(sprite_path: String) -> String:
	return _sibling(sprite_path, "spirling_anim")

## Icon strip next to a sprite, "" when it has none.
static func icon_path(sprite_path: String) -> String:
	return _sibling(sprite_path, "spirling_icons")

static func _sibling(sprite_path: String, folder: String) -> String:
	if tier_of_path(sprite_path) == 0:
		return ""
	var p: String = "%s/%s/%s.png" % [sprite_path.get_base_dir().get_base_dir(), folder, id_of_path(sprite_path)]
	return p if ResourceLoader.exists(p) else ""

## True when battles of [param era] play the pose sheets.
static func animates(era: int) -> bool:
	return era >= int(config().get("anim_from_era", 5))

## Timeline of [param kind] in tier [param era]: {fps, loop, cells, dx, dy}.
static func timeline(era: int, kind: String) -> Dictionary:
	return (tier(era).get("anim", {}) as Dictionary).get(kind, {})

static func frame_count(era: int, kind: String) -> int:
	return maxi((timeline(era, kind).get("cells", [0]) as Array).size(), 1)

static func fps(era: int, kind: String) -> float:
	return float(timeline(era, kind).get("fps", 8))

## Seconds one pass of the strip takes.
static func duration(era: int, kind: String) -> float:
	return frame_count(era, kind) / fps(era, kind)

## Frame index at time [param t]; one-shot strips hold their last frame.
static func frame_at(era: int, kind: String, t: float) -> int:
	var n: int = frame_count(era, kind)
	var i: int = int(floor(maxf(t, 0.0) * fps(era, kind)))
	return posmod(i, n) if bool(timeline(era, kind).get("loop", false)) else mini(i, n - 1)

## Pose cell of frame [param f]: an index into the sheet, HIDDEN or FLASH.
static func cell(era: int, kind: String, f: int) -> int:
	var cells: Array = timeline(era, kind).get("cells", [0])
	return int(cells[f]) if f >= 0 and f < cells.size() else 0

## Offset of frame [param f] in art pixels: x is forward, y is down.
static func offset(era: int, kind: String, f: int) -> Vector2:
	var tl: Dictionary = timeline(era, kind)
	var dx: Array = tl.get("dx", [])
	var dy: Array = tl.get("dy", [])
	return Vector2(float(dx[f]) if f >= 0 and f < dx.size() else 0.0, float(dy[f]) if f >= 0 and f < dy.size() else 0.0)

## Region of pose [param pose] for [param facing] in a sheet of tier [param era].
static func cell_rect(era: int, facing: String, pose: int, sheet: Texture2D) -> Rect2:
	var s: float = sheet.get_height() / float(FACINGS.size())
	return Rect2(maxi(pose, 0) * s, maxi(FACINGS.find(facing), 0) * s, s, s)

## Index of the pose called [param name] in tier [param era], -1 when the tier has none.
static func pose_index(era: int, name: String) -> int:
	var poses: Array = tier(era).get("poses", [])
	for i: int in poses.size():
		if str((poses[i] as Dictionary).get("name", "")) == name:
			return i
	return -1

## Art x direction of "forward": front art faces left, back art faces right.
static func forward(facing: String) -> float:
	return 1.0 if facing == "back" else -1.0

## The "breath" pose of a sprite as its own texture (Era IV idle), null when its tier has none.
static func breath_texture(sprite_path: String, facing: String) -> Texture2D:
	var era: int = tier_of_path(sprite_path)
	var pose: int = pose_index(era, "breath")
	var sp: String = sheet_path(sprite_path)
	if pose < 0 or sp.is_empty() or era < int(config().get("breath_from_era", 4)):
		return null
	var at := AtlasTexture.new()
	at.atlas = load(sp)
	at.region = cell_rect(era, facing, pose, at.atlas)
	return at

## Menu icon sizes every kind has.
static func icon_sizes() -> Array:
	return config().get("icon_sizes", [])

## Generated menu icon of [param size] for the sprite at [param sprite_path], null when that size
## (or the kind's icon strip) does not exist.
static func icon(sprite_path: String, size: int) -> Texture2D:
	var key: String = "%s:%d" % [sprite_path, size]
	if _icons.has(key):
		return _icons[key]
	var out: Texture2D = null
	var p: String = icon_path(sprite_path)
	var x: int = 0
	for s: Variant in icon_sizes():
		if int(s) == size and not p.is_empty():
			var at := AtlasTexture.new()
			at.atlas = load(p)
			at.region = Rect2(x, 0, size, size)
			out = at
		x += int(s)
	_icons[key] = out
	return out

## Gleam hue turn (0..1) for a kind whose art is not in the four inks: the palette swap of
## shaders/gleam_palette.gdshader only knows inks, so later tiers turn their hues instead. Stages
## of a line share base colours and [param id] is the line id, so a line gleams alike; lines
## spread a little.
static func gleam_shift(id: String) -> float:
	var g: Dictionary = config().get("gleam", {})
	var steps: int = maxi(int(g.get("steps", 9)), 2)
	var spread: float = float(g.get("spread", 0.0))
	return float(g.get("hue_shift", 0.5)) + (float(id.hash() % steps) / float(steps - 1) - 0.5) * 2.0 * spread

static func clear_cache() -> void:
	_icons.clear()
