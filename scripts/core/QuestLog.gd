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

## Region tales after the story ("post", docs/STORY.md "Region tales"): the goals of
## [param region] in order, or every tale goal for "".
static func tale_goals(region: String = "") -> Array:
	return (data().get("post", []) as Array).filter(func(g: Dictionary) -> bool: return region.is_empty() or str(g.get("region", "")) == region)

## The regions with a tale, in play order.
static func tale_regions() -> Array[String]:
	var out: Array[String] = []
	for g: Dictionary in tale_goals():
		if not str(g.region) in out:
			out.append(str(g.region))
	return out

## True once the last goal of [param region]'s tale is done.
static func tale_done(region: String, flags: Dictionary) -> bool:
	var goals: Array = tale_goals(region)
	return not goals.is_empty() and _own_done(goals[-1], flags)

## The current goal of [param region]'s tale (same rule as the main story: done when its own
## flags are set or a later goal is done), {} while the region is shut or once the tale is done.
static func tale_goal(region: String, flags: Dictionary) -> Dictionary:
	var goals: Array = tale_goals(region)
	if goals.is_empty() or tale_done(region, flags) or not bool(flags.get(str(goals[0].get("opens", "")), false)):
		return {}
	for i: int in range(goals.size() - 1, -1, -1):
		if _own_done(goals[i], flags):
			return goals[i + 1]
	return goals[0]

## The tale goal to show: the first open region whose tale is not done yet, or {}.
static func tale_current(flags: Dictionary) -> Dictionary:
	for r: String in tale_regions():
		var g: Dictionary = tale_goal(r, flags)
		if not g.is_empty():
			return g
	return {}

## Every flag the quest file depends on (the data test checks each one can be set in game).
static func all_flags() -> Array[String]:
	var out: Array[String] = []
	for g: Variant in main_goals() + tale_goals():
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
	var tale: Dictionary = tale_current(flags)
	if not tale.is_empty():
		lines.append("")
		lines.append(str(tale.act))
		lines.append(goal_text(tale, flags))
		lines.append("Where: %s" % tale.where)
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

# --- Goal line and goal doors (plan Chimora 100, items 37-39) ---------------------------------

## True while the story is in its first act (the act of the first main goal): the goal line
## shows and the minimap is free.
static func in_act_one(flags: Dictionary) -> bool:
	var goals: Array = main_goals()
	return not goals.is_empty() and str(current(flags).get("act", "")) == str((goals[0] as Dictionary).get("act", ""))

## The short goal line for the overworld (translated, with "(k/n)" progress), or "" when the
## current goal has no "hud" text (after Act I). A quest picked with "Where next?" shows as
## "To <place>" instead, in every act (tracked_line).
static func hud_text(flags: Dictionary) -> String:
	# Goals open in Brindlewick, once the opening is over (Opening, 1.3.2).
	if Opening.active(flags):
		return ""
	var t: Dictionary = tracked_goal(flags)
	if not t.is_empty() and (not is_main(t) or str(t.get("hud", "")).is_empty()):
		return tracked_line(t, flags)
	var g: Dictionary = current(flags)
	var text: String = str(g.get("hud", ""))
	if text.is_empty():
		return ""
	text = Loc.t(text)
	var need: Array = g.get("done", [])
	if need.size() > 1:
		var have: int = 0
		for f: Variant in need:
			have += 1 if bool(flags.get(str(f), false)) else 0
		text += " (%d/%d)" % [have, need.size()]
	return text

## Maps the current goal still leads to: its "goto" entries whose "done" flag is not set yet
## (a single "goto" entry stands for every flag).
static func goal_maps(flags: Dictionary) -> Array[String]:
	if Opening.active(flags):
		return []
	# A quest picked with "Where next?" leads the goal doors to its target (a main goal with
	# "goto" keeps its own list, which starts with the same map).
	var t: Dictionary = tracked_goal(flags)
	if not t.is_empty() and (not is_main(t) or not t.has("goto")):
		var to: String = target_map(t, flags)
		return [to] if not to.is_empty() else ([] as Array[String])
	var g: Dictionary = current(flags)
	var go: Array = g.get("goto", [])
	var need: Array = g.get("done", [])
	var out: Array[String] = []
	for i: int in go.size():
		var flag: String = str(need[i]) if go.size() == need.size() else ""
		if flag.is_empty() or not bool(flags.get(flag, false)):
			out.append(str(go[i]))
	return out

## Warps per map id, read once (the goal doors search the warp graph on every map change).
static var _warps: Dictionary = {}
const ROUTE_MAX_MAPS: int = 120

static func _warps_of(map_id: String) -> Array:
	if not _warps.has(map_id):
		var m: MapData = MapData.load_map(map_id) if MapData.exists(map_id) else null
		_warps[map_id] = m.warps if m != null else []
	return _warps[map_id]

## Cells of the warps on [param m] that start the shortest walk toward the nearest of
## [param targets] (item 38); empty on a target map or when no target can be reached.
static func goal_warps(m: MapData, targets: Array[String]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if m == null or targets.is_empty() or m.id in targets:
		return out
	_warps[m.id] = m.warps
	# Breadth-first over the warp graph; each map remembers the first step out of [param m].
	var first: Dictionary = {m.id: ""}
	var queue: Array[String] = [m.id]
	var found: String = ""
	while not queue.is_empty() and found.is_empty() and first.size() < ROUTE_MAX_MAPS:
		var at: String = queue.pop_front()
		for w: Variant in _warps_of(at):
			var to: String = str((w as Dictionary).get("to", ""))
			if to.is_empty() or first.has(to):
				continue
			first[to] = to if at == m.id else first[at]
			if to in targets:
				found = to
				break
			queue.append(to)
	if found.is_empty():
		return out
	for w: Dictionary in m.warps:
		if str(w.get("to", "")) == str(first[found]):
			out.append(Vector2i(int(w.x), int(w.y)))
	return out

# --- Quest Book and "Where next?" (Chimora 1.3.2) -----------------------------------------------

const MAIN: String = "Main"
const SIDE: String = "Side"
const DONE: String = "Done"
const BOOK_TABS: Array[String] = [MAIN, SIDE, DONE]

## The quest the player picked with "Where next?" ("" follows the main goal). Kept for the
## session only: nothing new is saved, and a quest that is no longer open is ignored.
static var tracked: String = ""

static func side_goals() -> Array:
	return data().get("side", [])

static func is_main(goal: Dictionary) -> bool:
	return main_goals().has(goal)

## True for a goal of a region tale after the story ("post").
static func is_tale(goal: Dictionary) -> bool:
	return tale_goals().has(goal)

## The quest with [param id], main, tale or side ({} when there is none).
static func find(id: String) -> Dictionary:
	for g: Variant in main_goals() + tale_goals() + side_goals():
		if str((g as Dictionary).get("id", "")) == id:
			return g
	return {}

## "open", "done" or "hidden" (a main or tale goal not reached yet, a side goal not shown yet).
static func state(goal: Dictionary, flags: Dictionary) -> String:
	if is_tale(goal):
		var region: String = str(goal.get("region", ""))
		var goals: Array = tale_goals(region)
		if tale_done(region, flags):
			return DONE
		var now: Dictionary = tale_goal(region, flags)
		if now.is_empty():
			return "hidden"
		var i: int = goals.find(goal)
		return DONE if i < goals.find(now) else ("open" if goal == now else "hidden")
	if is_main(goal):
		var i: int = main_goals().find(goal)
		var now: int = current_index(flags)
		if i < now or (i == now and _own_done(goal, flags)):
			return DONE
		return "open" if i == now else "hidden"
	if bool(flags.get(str(goal.get("done", "")), false)):
		return DONE
	return "open" if bool(flags.get(str(goal.get("show", "")), false)) else "hidden"

## Steps done and steps in all, e.g. (3, 6); (0, 0) for a quest with a single step.
static func progress(goal: Dictionary, flags: Dictionary) -> Vector2i:
	var story: bool = is_main(goal) or is_tale(goal)
	var steps: Array = goal.get("done", []) if story else goal.get("progress", [])
	var stages: Array = [] if story else goal.get("stages", [])
	var all: int = steps.size() if steps.size() > 1 or stages.is_empty() else stages.size()
	if all <= 1:
		return Vector2i.ZERO
	if state(goal, flags) == DONE:
		return Vector2i(all, all)
	var have: int = 0
	if steps.size() == all:
		for f: Variant in steps:
			have += 1 if bool(flags.get(str(f), false)) else 0
	else:
		have = clampi(GameState.story_var(stage_var(goal)), 0, all - 1)
	return Vector2i(have, all)

## Quests of one Quest Book tab: Main is the current main goal and then the goal of each open
## region tale, Side the open side goals, Done every finished quest, the latest main goal first. New entries of data/quests.json
## (daily, post-story) land in their tab by their flags alone.
static func book(tab: String, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match tab:
		MAIN:
			var g: Dictionary = current(flags)
			if not g.is_empty() and state(g, flags) == "open":
				out.append(g)
			for r: String in tale_regions():
				var t: Dictionary = tale_goal(r, flags)
				if not t.is_empty():
					out.append(t)
		SIDE:
			out = open_side_goals(flags)
		DONE:
			var mains: Array = main_goals().duplicate()
			mains.reverse()
			var tales: Array = tale_goals().duplicate()
			tales.reverse()
			for g: Variant in mains + tales + side_goals():
				if state(g, flags) == DONE:
					out.append(g)
	return out

## The quest picked with "Where next?" while it is open, else {}.
static func tracked_goal(flags: Dictionary) -> Dictionary:
	if tracked.is_empty():
		return {}
	var g: Dictionary = find(tracked)
	return g if not g.is_empty() and state(g, flags) == "open" else {}

## The current place text of a quest (the current step's first).
static func where_of(goal: Dictionary) -> String:
	return side_where(goal) if goal.has("show") else str(goal.get("where", ""))

static var _names: Dictionary = {}

## Map ids by lower-case display name; a place wins over a house of the same name.
static func _name_index() -> Dictionary:
	if _names.is_empty():
		var maps: Dictionary = WorldAtlas.layout().get("maps", {})
		var ids: Array = maps.keys()
		ids.sort()
		for id: Variant in ids:
			var path: String = MapData.DIR + str(id) + ".json"
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
			if not raw is Dictionary:
				continue
			var key: String = str((raw as Dictionary).get("name", id)).to_lower()
			if not _names.has(key) or (maps[_names[key]] as Dictionary).has("inside") and not (maps[id] as Dictionary).has("inside"):
				_names[key] = str(id)
	return _names

## The map a "where" text points to: the "places" table of data/quests.json, then the first
## part ("A / B", "A and B", "A, far end") that names a map. "" when nothing matches.
static func map_for_where(where: String) -> String:
	var alias: Dictionary = data().get("places", {})
	if alias.has(where):
		return str(alias[where])
	var parts: PackedStringArray = where.replace(" and the ", " / ").replace(" and ", " / ").split(" / ", false)
	for part: String in parts:
		var p: String = part.get_slice(",", 0).strip_edges()
		if alias.has(p):
			return str(alias[p])
		var k: String = p.to_lower()
		for key: String in [k, "the " + k, k.trim_prefix("the ")]:
			if _name_index().has(key):
				return str(_name_index()[key])
	return ""

## The map a quest leads to now: its own "map", a main goal's next "goto", else its "where".
static func target_map(goal: Dictionary, flags: Dictionary) -> String:
	var step: Dictionary = side_step(goal) if goal.has("show") else {}
	if step.has("map"):
		return str(step.map)
	if goal.has("map") and step.is_empty():
		return str(goal.map)
	if goal.has("goto"):
		var go: Array = goal.goto
		var need: Array = goal.get("done", [])
		for i: int in go.size():
			if go.size() != need.size() or not bool(flags.get(str(need[i]), false)):
				return str(go[i])
	return map_for_where(where_of(goal))

## The world map place of a quest's target ("" when it has none).
static func target_place(goal: Dictionary, flags: Dictionary) -> String:
	var m: String = target_map(goal, flags)
	return WorldAtlas.place_of(m) if not m.is_empty() else ""

## Places of the open quests (main goal first) the player has reached or sighted, for the
## small quest marks on the world map.
static func open_places(flags: Dictionary, known: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for g: Dictionary in book(MAIN, flags) + book(SIDE, flags):
		var p: String = target_place(g, flags)
		if not p.is_empty() and not p in out and int(known.get(p, WorldAtlas.Known.UNKNOWN)) != WorldAtlas.Known.UNKNOWN:
			out.append(p)
	return out

## Translated name of a world map place.
static func place_name(place: String) -> String:
	return Loc.t(MapData.load_map(place).display_name) if MapData.exists(place) else place

## The goal line for a picked quest: "To Mossgate (2/4)".
static func tracked_line(goal: Dictionary, flags: Dictionary) -> String:
	var p: String = target_place(goal, flags)
	var text: String = Loc.f("To %s", place_name(p)) if not p.is_empty() else Loc.t(str(goal.get("hud", goal.get("text", ""))))
	var pr: Vector2i = progress(goal, flags)
	return text + (" (%d/%d)" % [pr.x, pr.y] if pr.y > 0 else "")
