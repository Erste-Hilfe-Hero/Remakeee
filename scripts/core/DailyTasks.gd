class_name DailyTasks
extends RefCounted
## Daily tasks (plan area 8): every day by the server clock three tasks are drawn from
## data/events.json with the seed "chimora-tasks-YYYY-MM-DD". Each pays REWARD Waymarks, all
## three together pay BONUS more. Only tasks that the save can do are drawn (places already
## reached, elements living there), at most one battle task per day, and each fits in about
## 15 minutes. Progress lives in GameState.daily_tasks, so it is part of the (server) save and
## survives a device change on the same day. Missing a day costs nothing: there is no streak.

const PER_DAY: int = 3
const REWARD: int = 10
const BONUS: int = 10
const MAX_BATTLE_TASKS: int = 1
const DATA_PATH: String = "res://data/events.json"

static var _defs: Array[Dictionary] = []

static func defs() -> Array[Dictionary]:
	if _defs.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f == null:
			return _defs
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for t: Variant in (d as Dictionary).get("daily_tasks", []):
				if t is Dictionary:
					_defs.append(t)
	return _defs

static func def(id: String) -> Dictionary:
	for t: Dictionary in defs():
		if str(t.id) == id:
			return t
	return {}

static func day_key() -> String:
	return DailyFind.today_key()

## Map ids the save has reached (visited maps, rest spots, where the player stands).
static func reached_maps() -> Array[String]:
	var out: Array[String] = []
	for m: Variant in GameState.records.get("maps_visited", []):
		if not str(m) in out:
			out.append(str(m))
	for m: Variant in GameState.visited_rests.keys():
		if not str(m) in out:
			out.append(str(m))
	for m: String in [GameState.current_map, GameState.heal_map]:
		if not m in out:
			out.append(m)
	return out

## Remembers that the player reached [param map_id] (Overworld calls this on every map load).
static func note_map(map_id: String) -> void:
	var seen: Array = GameState.records.get("maps_visited", [])
	if not map_id in seen:
		seen.append(map_id)
		GameState.records["maps_visited"] = seen

## Element names (Elements.E keys) of wild Spirlings on the reached maps.
static func reachable_elements(maps: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var tables: Array[String] = EncounterTable.table_ids()
	for m: String in maps:
		if not m in tables:
			continue
		for sp: String in EncounterTable.species_on(m):
			var sd: SpirlingData = Database.species(sp)
			if sd == null:
				continue
			for e: int in sd.elements:
				var en: String = Elements.E.keys()[e]
				if not en in out:
					out.append(en)
	return out

## True if task [param t] can be done with the places and Spirlings this save can reach.
static func doable(t: Dictionary, maps: Array[String], elements: Array[String]) -> bool:
	var ev: String = str(t.get("event", ""))
	var wild_maps: int = 0
	for m: String in maps:
		if m in EncounterTable.table_ids():
			wild_maps += 1
	if t.has("map") and not str(t.map) in maps:
		return false
	if t.has("map") and ev == "win" and not str(t.map) in EncounterTable.table_ids():
		return false
	if t.has("element") and not str(t.element) in elements:
		return false
	if ev in ["win", "bond"] and wild_maps == 0:
		return false
	if ev == "bond" and GameState.party.is_empty():
		return false
	if bool(t.get("distinct", false)) and ev in ["rest", "visit"]:
		var places: int = GameState.visited_rests.size() if ev == "rest" else maps.size()
		if places < int(t.get("n", 1)):
			return false
	if ev == "visit" and t.has("map") and str(t.map) == GameState.current_map:
		return false
	return true

## Draws the tasks for [param day] (ids), the same every time for the same save state.
static func draw(day: String) -> Array[String]:
	var maps: Array[String] = reached_maps()
	var elements: Array[String] = reachable_elements(maps)
	var pool: Array[Dictionary] = []
	for t: Dictionary in defs():
		if doable(t, maps, elements):
			pool.append(t)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-tasks-" + day)
	var out: Array[String] = []
	var battles: int = 0
	while out.size() < PER_DAY and not pool.is_empty():
		var t: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		if str(t.get("kind", "")) == "battle":
			if battles >= MAX_BATTLE_TASKS:
				continue
			battles += 1
		out.append(str(t.id))
	return out

## Today's state, drawn fresh when the day changed: {"day", "tasks": [{"id", "n"}], "bonus"}.
static func today() -> Dictionary:
	var day: String = day_key()
	if str(GameState.daily_tasks.get("day", "")) != day or not _valid(GameState.daily_tasks):
		var tasks: Array = []
		for id: String in draw(day):
			tasks.append({"id": id, "n": 0})
		GameState.daily_tasks = {"day": day, "tasks": tasks, "bonus": false}
	return GameState.daily_tasks

## False for damaged task state (a broken save): it is then drawn again.
static func _valid(state: Dictionary) -> bool:
	var tasks: Variant = state.get("tasks")
	if not tasks is Array:
		return false
	for e: Variant in tasks:
		if not e is Dictionary or not (e as Dictionary).has("id") or not ((e as Dictionary).get("n", 0) is int or (e as Dictionary).get("n", 0) is float):
			return false
	return true

static func is_done(entry: Dictionary) -> bool:
	return int(entry.get("n", 0)) >= int(def(str(entry.get("id", ""))).get("n", 1))

## True if a game event matches task [param t]. [param info]: "map", "wild", "elements".
static func matches(t: Dictionary, event: String, info: Dictionary) -> bool:
	if str(t.get("event", "")) != event:
		return false
	if t.has("map") and str(info.get("map", "")) != str(t.map):
		return false
	if t.has("wild") and bool(info.get("wild", false)) != bool(t.wild):
		return false
	if t.has("element"):
		var els: Array = info.get("elements", [])
		if not str(t.element) in els:
			return false
	return true

## Counts game event [param event] ("win", "bond", "rest", "visit", "step", "photo") with
## [param info] towards today's tasks, pays Waymarks for finished ones and returns the reward
## lines (also queued in GameState.notices for the overworld to show).
static func record(event: String, info: Dictionary = {}, amount: int = 1) -> Array[String]:
	# Lifetime counters for achievements: count_win, count_win_wild, count_step, ...
	var counters: Array[String] = ["count_" + event]
	if event == "win":
		counters.append("count_win_wild" if bool(info.get("wild", false)) else "count_win_tamer")
	for c: String in counters:
		GameState.records[c] = int(GameState.records.get(c, 0)) + amount
	var state: Dictionary = today()
	var lines: Array[String] = []
	for entry: Dictionary in state.get("tasks", []):
		if is_done(entry):
			continue
		var t: Dictionary = def(str(entry.id))
		if t.is_empty() or not matches(t, event, info):
			continue
		if bool(t.get("distinct", false)):
			var where: Array = entry.get("seen", [])
			var m: String = str(info.get("key", info.get("map", "")))
			if m in where:
				continue
			where.append(m)
			entry["seen"] = where
			entry["n"] = where.size()
		else:
			entry["n"] = mini(int(entry.get("n", 0)) + amount, int(t.get("n", 1)))
		if is_done(entry):
			lines.append(Loc.t("Daily task done: %s") % Loc.t(str(t.text)))
			lines.append_array(Waymarks.reward_lines(Waymarks.earn(REWARD, "daily_task")))
			GameState.records["daily_tasks_done"] = int(GameState.records.get("daily_tasks_done", 0)) + 1
	if not bool(state.get("bonus", false)) and all_done():
		state["bonus"] = true
		lines.append(Loc.t("All of today's tasks are done!"))
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(BONUS, "daily_bonus")))
	lines.append_array(Festival.record(event, info, amount))
	GameState.notices.append_array(lines)
	return lines

static func all_done() -> bool:
	var tasks: Array = GameState.daily_tasks.get("tasks", [])
	if tasks.is_empty():
		return false
	for entry: Dictionary in tasks:
		if not is_done(entry):
			return false
	return true

## Goals screen block: one line per task with progress (k/n), already translated.
static func lines() -> Array[String]:
	var out: Array[String] = []
	var tasks: Array = today().get("tasks", [])
	if tasks.is_empty():
		return out
	out.append(Loc.t("Daily tasks (%d Waymarks each):") % REWARD)
	for entry: Dictionary in tasks:
		var t: Dictionary = def(str(entry.id))
		var need: int = int(t.get("n", 1))
		out.append("%s %s %d/%d" % ["[x]" if is_done(entry) else "[ ]", Loc.t(str(t.get("text", entry.id))), mini(int(entry.get("n", 0)), need), need])
	if all_done():
		out.append(Loc.t("All done. New tasks arrive tomorrow."))
	else:
		out.append(Loc.t("All three: %d Waymarks extra.") % BONUS)
	return out
