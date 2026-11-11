class_name Survey
extends RefCounted
## Mapping the world as you walk (area 3 items 1245, 1246, 1273): every cell within RADIUS of the
## player counts as seen, one bit per cell in GameState.map_cells[map id]. The survey share
## ("Kartierquote") of a map is seen walkable cells over all walkable cells. Also the player's
## own world map marks.

const RADIUS: int = 3
const MAX_MARKS: int = 30
const MARK_ICONS: Array[String] = ["star", "cross", "question", "heart", "arrow", "hammer"]
const MINIMAP_MODES: Array[String] = ["on", "off", "outdoor"]

static func _bits(map_id: String, cells: int) -> PackedByteArray:
	var b: Variant = GameState.map_cells.get(map_id)
	var bytes: int = (cells + 7) / 8
	if not b is PackedByteArray or (b as PackedByteArray).size() != bytes:
		var fresh := PackedByteArray()
		fresh.resize(bytes)
		fresh.fill(0)
		b = fresh
	return b

static func is_seen(m: MapData, c: Vector2i) -> bool:
	if not m.in_bounds(c):
		return false
	var b: Variant = GameState.map_cells.get(m.id)
	if not b is PackedByteArray:
		return false
	var i: int = c.y * m.width + c.x
	return i / 8 < (b as PackedByteArray).size() and ((b as PackedByteArray)[i / 8] >> (i % 8)) & 1 == 1

## Marks the cells around [param center] as seen. Returns how many were new.
static func reveal(m: MapData, center: Vector2i, radius: int = RADIUS) -> int:
	var b: PackedByteArray = _bits(m.id, m.width * m.height)
	var added: int = 0
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + 1:
				continue
			var c: Vector2i = center + Vector2i(dx, dy)
			if not m.in_bounds(c):
				continue
			var i: int = c.y * m.width + c.x
			if (b[i / 8] >> (i % 8)) & 1 == 0:
				b[i / 8] |= 1 << (i % 8)
				added += 1
	GameState.map_cells[m.id] = b
	return added

## Survey share of [param m] in percent (0-100): walkable cells seen.
static func percent(m: MapData) -> int:
	var total: int = 0
	var seen: int = 0
	for y: int in m.height:
		for x: int in m.width:
			var c := Vector2i(x, y)
			if not m.is_walkable(c):
				continue
			total += 1
			if is_seen(m, c):
				seen += 1
	return 100 if total == 0 else seen * 100 / total

## True if any cell of [param map_id] was seen (the map was visited).
static func visited(map_id: String) -> bool:
	var b: Variant = GameState.map_cells.get(map_id)
	return b is PackedByteArray and (b as PackedByteArray).count(0) < (b as PackedByteArray).size()

## Whether the minimap shows on [param m] for the current setting.
static func minimap_shows(m: MapData) -> bool:
	if not ShopEffects.owns_setting("minimap"):
		return false
	match GameState.minimap:
		"off":
			return false
		"outdoor":
			return m != null and m.outdoor
	return true

# --- Marks ----------------------------------------------------------------------------------

## Adds a mark; false when the list is full or the icon unknown.
static func add_mark(map_id: String, cell: Vector2i, icon: String) -> bool:
	if GameState.map_marks.size() >= MAX_MARKS or not icon in MARK_ICONS:
		return false
	GameState.map_marks.append({"map": map_id, "x": cell.x, "y": cell.y, "icon": icon})
	return true

static func remove_mark(i: int) -> void:
	if i >= 0 and i < GameState.map_marks.size():
		GameState.map_marks.remove_at(i)

static func marks_on(map_id: String) -> Array:
	return GameState.map_marks.filter(func(mk: Dictionary) -> bool: return str(mk.map) == map_id)

# --- Saving -----------------------------------------------------------------------------------

static func cells_to_save(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in cells:
		if cells[k] is PackedByteArray:
			out[str(k)] = Marshalls.raw_to_base64(cells[k])
	return out

## True when [param s] is padded base64 (length a multiple of 4, only the base64 alphabet).
static func is_base64(s: String) -> bool:
	if s.length() % 4 != 0:
		return false
	var body: String = s.trim_suffix("=").trim_suffix("=")
	for i: int in body.length():
		var c: int = body.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 43 or c == 47):
			return false
	return true

static func cells_from_save(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for k: Variant in raw:
		var v: Variant = (raw as Dictionary)[k]
		# Damaged saves: only well-formed base64 is decoded (the engine errors on anything else).
		if v is String and (v as String).length() <= 8192 and is_base64(v):
			out[str(k)] = Marshalls.base64_to_raw(v)
	return out

static func marks_from_save(raw: Variant) -> Array:
	var out: Array = []
	if not raw is Array:
		return out
	for mk: Variant in raw:
		if out.size() >= MAX_MARKS:
			break
		if mk is Dictionary and str((mk as Dictionary).get("icon", "")) in MARK_ICONS:
			out.append({"map": str(mk.get("map", "")), "x": int(mk.get("x", 0)), "y": int(mk.get("y", 0)), "icon": str(mk.icon)})
	return out
