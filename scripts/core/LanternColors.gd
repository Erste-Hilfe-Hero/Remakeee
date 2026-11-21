class_name LanternColors
extends RefCounted
## Flame colours of the Wayfarer's lantern (KAMPF_PLAN_1000 item 837): cosmetic endgame rewards
## from data/lantern_colors.json. The chosen id lives in GameState.records[RECORD].

const DATA_PATH: String = "res://data/lantern_colors.json"
const RECORD: String = "lantern_color"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = v if v is Dictionary else {"default": "", "colors": []}
	return _data

static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Variant in data().get("colors", []):
		if c is Dictionary:
			out.append(c)
	return out

static func by_id(id: String) -> Dictionary:
	for c: Dictionary in all():
		if str(c.id) == id:
			return c
	return {}

## True once the colour's unlock is met in [param records] and [param flags].
static func is_unlocked(c: Dictionary, records: Dictionary, flags: Dictionary, hall_clears: int) -> bool:
	var u: Dictionary = c.get("unlock", {}) if c.get("unlock") is Dictionary else {}
	if u.has("flag") and not bool(flags.get(str(u.flag), false)):
		return false
	if u.has("record") and int(records.get(str(u.record), 0)) < int(u.get("at", 1)):
		return false
	if u.has("hall_clears") and hall_clears < int(u.hall_clears):
		return false
	return true

static func unlocked() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var clears: int = BattleHalls.total_clears()
	for c: Dictionary in all():
		if is_unlocked(c, GameState.records, GameState.flags, clears):
			out.append(c)
	return out

## The chosen colour id, or the default when the choice is unknown or locked again.
static func current_id() -> String:
	var id: String = str(GameState.records.get(RECORD, ""))
	for c: Dictionary in unlocked():
		if str(c.id) == id:
			return id
	return str(data().get("default", ""))

static func choose(id: String) -> bool:
	for c: Dictionary in unlocked():
		if str(c.id) == id:
			GameState.records[RECORD] = id
			return true
	return false

static func color() -> Color:
	return Color(str(by_id(current_id()).get("color", "f2c14e")))
