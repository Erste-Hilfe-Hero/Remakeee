class_name DungeonHints
extends RefCounted
## Hint boards at dungeon entrances (area 3 item 1027): after three failed tries in one room
## (a wrong bell, a fall through cracked floor, a "Reset room"), the board at the entrance
## shows a tip for that dungeon (flag "hint_<dungeon file>").

const FAILS_NEEDED: int = 3

static func hint_flag(file_id: String) -> String:
	return "hint_" + file_id

static func fails(room_id: String) -> int:
	return int((GameState.records.get("room_fails", {}) as Dictionary).get(room_id, 0))

## Counts one failed try in [param room_id] ("file@n"). True when this unlocks the tip.
static func note_fail(room_id: String) -> bool:
	var all: Dictionary = GameState.records.get("room_fails", {})
	all[room_id] = int(all.get(room_id, 0)) + 1
	GameState.records["room_fails"] = all
	var file: String = MapData.split_id(room_id)[0]
	if int(all[room_id]) >= FAILS_NEEDED and not GameState.has_flag(hint_flag(file)):
		GameState.set_flag(hint_flag(file))
		return true
	return false
