class_name Festival
extends RefCounted
## Festival ribbons (plan area 8). During a festival (Season.gd, data/events.json) every won
## battle against Spirlings of the festival's elements pays RIBBONS_PER_WIN ribbons. Ribbons
## buy festival goods at Tilda's stand in Brindlewick, fill a five-stage festival goal that pays
## Waymarks, and the crier hands out one festival task a day. When a festival ends, leftover
## ribbons turn into Waymarks 1:1, so nothing is ever lost. Ribbons are kept per festival in
## GameState.festival_ribbons ("<id>_<year>" -> state).

const RIBBONS_PER_WIN: int = 3
const STAGES: Array[int] = [10, 25, 50, 100, 200]
const STAGE_WAYMARKS: int = 30
const TASK_RIBBONS: int = 5
const DATA_PATH: String = "res://data/events.json"

static var _tasks: Array[Dictionary] = []

## The running festival and its save key: {"fest": Dictionary, "key": String}, or {}.
static func active() -> Dictionary:
	var d: Dictionary = Online.date_now()
	var f: Dictionary = Season.for_month(int(d.month))
	if f.is_empty():
		return {}
	return {"fest": f, "key": "%s_%d" % [f.id, Season.festival_year(int(d.month), int(d.year))]}

static func _state(key: String) -> Dictionary:
	if not GameState.festival_ribbons.has(key):
		GameState.festival_ribbons[key] = {"ribbons": 0, "earned": 0, "stages": 0, "task": {}}
	return GameState.festival_ribbons[key]

## Ribbons held for the running festival (0 outside festivals).
static func ribbons() -> int:
	var a: Dictionary = active()
	if a.is_empty():
		return 0
	return int((GameState.festival_ribbons.get(a.key, {}) as Dictionary).get("ribbons", 0))

## Adds [param n] ribbons to the running festival and pays reached goal stages. Returns lines.
static func add(n: int) -> Array[String]:
	var lines: Array[String] = []
	var a: Dictionary = active()
	if a.is_empty() or n <= 0:
		return lines
	var st: Dictionary = _state(a.key)
	st.ribbons = int(st.ribbons) + n
	st.earned = int(st.earned) + n
	lines.append(Loc.t("+%d festival ribbons") % n)
	while int(st.stages) < STAGES.size() and int(st.earned) >= STAGES[int(st.stages)]:
		st.stages = int(st.stages) + 1
		lines.append(Loc.t("Festival goal %d of %d reached!") % [int(st.stages), STAGES.size()])
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(STAGE_WAYMARKS, "festival")))
	return lines

static func spend(n: int) -> bool:
	var a: Dictionary = active()
	if a.is_empty():
		return false
	var st: Dictionary = _state(a.key)
	if int(st.ribbons) < n:
		return false
	st.ribbons = int(st.ribbons) - n
	return true

## Turns the ribbons of festivals that are over into Waymarks 1:1. Returns lines.
static func settle() -> Array[String]:
	var lines: Array[String] = []
	var a: Dictionary = active()
	var now_key: String = str(a.get("key", ""))
	for k: Variant in GameState.festival_ribbons.keys():
		if str(k) == now_key:
			continue
		var left: int = int((GameState.festival_ribbons[k] as Dictionary).get("ribbons", 0))
		GameState.festival_ribbons.erase(k)
		if left > 0:
			lines.append(Loc.t("The festival is over. Your %d ribbons became Waymarks.") % left)
			lines.append_array(Waymarks.reward_lines(Waymarks.earn(left, "festival")))
	return lines

static func task_defs() -> Array[Dictionary]:
	if _tasks.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for t: Variant in (d as Dictionary).get("festival_tasks", []):
					if t is Dictionary:
						_tasks.append(t)
	return _tasks

static func task_def(id: String) -> Dictionary:
	for t: Dictionary in task_defs():
		if str(t.id) == id:
			return t
	return {}

## Today's crier task for [param fest] (the same for everyone on the same day).
static func draw_task(fest: Dictionary, day: String) -> String:
	var names: Array[String] = []
	for e: int in fest.get("elements", []):
		names.append(Elements.E.keys()[e])
	var pool: Array[String] = []
	for t: Dictionary in task_defs():
		if str(t.get("element", "")) in names:
			pool.append(str(t.id))
	pool.sort()
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-fest-" + day)
	return pool[rng.randi_range(0, pool.size() - 1)]

## The crier hands out today's task (once a day). Returns the task entry, or {} outside festivals.
static func take_task() -> Dictionary:
	var a: Dictionary = active()
	if a.is_empty():
		return {}
	var st: Dictionary = _state(a.key)
	var day: String = DailyTasks.day_key()
	if str((st.task as Dictionary).get("day", "")) != day:
		st.task = {"day": day, "id": draw_task(a.fest, day), "n": 0, "done": false}
	return st.task

## Counts a game event for festival ribbons and the crier's task. Returns reward lines.
static func record(event: String, info: Dictionary, amount: int = 1) -> Array[String]:
	var lines: Array[String] = settle()
	var a: Dictionary = active()
	if a.is_empty():
		return lines
	var names: Array[String] = []
	for e: int in a.fest.get("elements", []):
		names.append(Elements.E.keys()[e])
	if event == "win":
		for e: Variant in info.get("elements", []):
			if str(e) in names:
				lines.append_array(add(RIBBONS_PER_WIN))
				break
	var task: Dictionary = (_state(a.key).task as Dictionary)
	if task.is_empty() or bool(task.get("done", false)) or str(task.get("day", "")) != DailyTasks.day_key():
		return lines
	var t: Dictionary = task_def(str(task.id))
	if not t.is_empty() and DailyTasks.matches(t, event, info):
		task.n = mini(int(task.n) + amount, int(t.get("n", 1)))
		if int(task.n) >= int(t.get("n", 1)):
			task.done = true
			lines.append(Loc.t("Festival task done: %s") % Loc.t(str(t.text)))
			lines.append_array(add(TASK_RIBBONS))
	return lines

## Tilda's goods for the running festival: [{"item", "price"}].
static func shop() -> Array:
	var a: Dictionary = active()
	return [] if a.is_empty() else a.fest.get("shop", [])

## Buys [param item_id] for ribbons. Returns "" on success, else the reason.
static func buy(item_id: String) -> String:
	for o: Variant in shop():
		if str(o.item) == item_id:
			if not spend(int(o.price)):
				return "Not enough ribbons."
			GameState.add_item(item_id)
			return ""
	return "Tilda doesn't have that right now."
