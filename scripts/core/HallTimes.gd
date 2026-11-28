class_name HallTimes
extends RefCounted
## Best times for every hall (plan item 1109): the fastest win in seconds per hall id
## (Master Rifts, Random Rift, master tour, the exam), kept in records["hall_times"].

const KEY: String = "hall_times"

static func best(hall: String) -> int:
	return int(GameState.as_dict(GameState.records.get(KEY, {})).get(hall, 0))

## Books a win of [param seconds]; true when it is a new best.
static func submit(hall: String, seconds: int) -> bool:
	if hall.is_empty() or seconds <= 0:
		return false
	var all: Dictionary = GameState.as_dict(GameState.records.get(KEY, {})).duplicate()
	var old: int = int(all.get(hall, 0))
	if old > 0 and seconds >= old:
		return false
	all[hall] = seconds
	GameState.records[KEY] = all
	return true

static func fmt(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

## One line per hall with a time, sorted by hall id; [param names] maps ids to shown names.
static func lines(names: Dictionary) -> Array[String]:
	var all: Dictionary = GameState.as_dict(GameState.records.get(KEY, {}))
	var ids: Array = all.keys()
	ids.sort()
	var out: Array[String] = []
	for id: Variant in ids:
		out.append("%s  %s" % [str(names.get(id, id)), fmt(int(all[id]))])
	return out
