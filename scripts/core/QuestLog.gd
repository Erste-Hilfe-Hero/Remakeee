class_name QuestLog
extends RefCounted
## Story goals from data/quests.json, worked out from world flags (nothing extra is saved).
## A main goal counts as done when all its "done" flags are set or any later goal is done,
## so older saves that skipped a newer flag still land on the right goal.

const PATH: String = "res://data/quests.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {"main": [], "side": []}
	return _data

static func main_goals() -> Array:
	return data().get("main", [])

static func _own_done(goal: Dictionary, flags: Dictionary) -> bool:
	var need: Array = goal.get("done", [])
	if need.is_empty():
		return false
	for f: Variant in need:
		if not bool(flags.get(str(f), false)):
			return false
	return true

## Index of the current main goal (the last one once everything is done).
static func current_index(flags: Dictionary) -> int:
	var goals: Array = main_goals()
	for i: int in range(goals.size() - 1, -1, -1):
		if _own_done(goals[i], flags):
			return mini(i + 1, goals.size() - 1)
	return 0

static func current(flags: Dictionary) -> Dictionary:
	var goals: Array = main_goals()
	return goals[current_index(flags)] if not goals.is_empty() else {}

## The goal text with progress, e.g. "... (1/2)" for goals with several flags.
static func goal_text(goal: Dictionary, flags: Dictionary) -> String:
	var text: String = str(goal.get("text", ""))
	var need: Array = goal.get("done", [])
	if need.size() > 1:
		var have: int = 0
		for f: Variant in need:
			have += 1 if bool(flags.get(str(f), false)) else 0
		text += " (%d/%d)" % [have, need.size()]
	return text

static func open_side_goals(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Variant in data().get("side", []):
		var d: Dictionary = g
		if bool(flags.get(str(d.get("show", "")), false)) and not bool(flags.get(str(d.get("done", "")), false)):
			out.append(d)
	return out

## Every flag the quest file depends on (the data test checks each one can be set in game).
static func all_flags() -> Array[String]:
	var out: Array[String] = []
	for g: Variant in main_goals():
		for f: Variant in (g as Dictionary).get("done", []):
			out.append(str(f))
	for g: Variant in data().get("side", []):
		out.append(str((g as Dictionary).get("show", "")))
		out.append(str((g as Dictionary).get("done", "")))
	return out

## Text for the Goals screen.
static func summary(flags: Dictionary) -> String:
	var g: Dictionary = current(flags)
	var lines: PackedStringArray = ["Goal", goal_text(g, flags)]
	if not str(g.get("where", "")).is_empty():
		lines.append("Where: %s" % g.where)
	var side: Array[Dictionary] = open_side_goals(flags)
	if not side.is_empty():
		lines.append("")
		lines.append("Also")
		for s: Dictionary in side:
			lines.append("- " + str(s.get("text", "")))
	return "\n".join(lines)
