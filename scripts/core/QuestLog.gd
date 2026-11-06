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

## Side-goal text with progress for goals that list "progress" flags, e.g. "... (2/6)".
static func side_text(goal: Dictionary, flags: Dictionary) -> String:
	var text: String = str(side_step(goal).get("text", goal.get("text", "")))
	var steps: Array = goal.get("progress", [])
	if not steps.is_empty():
		var have: int = 0
		for f: Variant in steps:
			have += 1 if bool(flags.get(str(f), false)) else 0
		text += " (%d/%d)" % [have, steps.size()]
	return text

## Story number that holds the current step of a side goal with "stages" (plan item 1631).
static func stage_var(goal: Dictionary) -> String:
	return "q_%s_stage" % str(goal.get("id", ""))

## The current step of a side goal with stages ({} if it has none): text and where.
static func side_step(goal: Dictionary) -> Dictionary:
	var stages: Array = goal.get("stages", [])
	if stages.is_empty():
		return {}
	var i: int = clampi(GameState.story_var(stage_var(goal)), 0, stages.size() - 1)
	return stages[i] if stages[i] is Dictionary else {}

## Where to go for a side goal (the current step's place first).
static func side_where(goal: Dictionary) -> String:
	return str(side_step(goal).get("where", goal.get("where", "")))

static func open_side_goals(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Variant in data().get("side", []):
		var d: Dictionary = g
		if bool(flags.get(str(d.get("show", "")), false)) and not bool(flags.get(str(d.get("done", "")), false)):
			out.append(d)
	return out

## True once every side goal is done (achievement "helper").
static func side_goals_done(flags: Dictionary) -> bool:
	var side: Array = data().get("side", [])
	if side.is_empty():
		return false
	for g: Variant in side:
		if not bool(flags.get(str((g as Dictionary).get("done", "")), false)):
			return false
	return true

## Every flag the quest file depends on (the data test checks each one can be set in game).
static func all_flags() -> Array[String]:
	var out: Array[String] = []
	for g: Variant in main_goals():
		for f: Variant in (g as Dictionary).get("done", []):
			out.append(str(f))
	for g: Variant in data().get("side", []):
		out.append(str((g as Dictionary).get("show", "")))
		out.append(str((g as Dictionary).get("done", "")))
		for f: Variant in (g as Dictionary).get("progress", []):
			out.append(str(f))
	return out

## Flag that remembers a chapter card was shown.
static func card_flag(goal: Dictionary) -> String:
	return "card_%s" % str(goal.get("chapter", goal.get("id", ""))).to_snake_case().left(40)

## The chapter card to show when the goal moves from [param before] to [param now]:
## [chapter] or [act, chapter] when the act changes too; [] when the chapter stays the same
## or its card was shown already.
static func card_for(before: int, now: int, flags: Dictionary) -> Array[String]:
	var goals: Array = main_goals()
	if now < 0 or now >= goals.size():
		return []
	var g: Dictionary = goals[now]
	var old: Dictionary = goals[before] if before >= 0 and before < goals.size() else {}
	var chapter: String = str(g.get("chapter", ""))
	if chapter.is_empty() or chapter == str(old.get("chapter", "")) or bool(flags.get(card_flag(g), false)):
		return []
	var act: String = str(g.get("act", ""))
	if not act.is_empty() and act != str(old.get("act", "")):
		return [act, chapter]
	return [chapter]

## Text for the Goals screen.
static func summary(flags: Dictionary) -> String:
	var g: Dictionary = current(flags)
	var lines: PackedStringArray = []
	if not str(g.get("act", "")).is_empty():
		lines.append(str(g.act))
	if not str(g.get("chapter", "")).is_empty():
		lines.append(str(g.chapter))
	lines.append("Goal")
	lines.append(goal_text(g, flags))
	if not str(g.get("where", "")).is_empty():
		lines.append("Where: %s" % g.where)
	var side: Array[Dictionary] = open_side_goals(flags)
	if not side.is_empty():
		lines.append("")
		lines.append("Also")
		for s: Dictionary in side:
			lines.append("- " + side_text(s, flags))
			var where: String = side_where(s)
			if not where.is_empty():
				lines.append("  " + ("Where: %s" % where))
	return "\n".join(lines)
