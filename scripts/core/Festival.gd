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

## The crier's task grows one stage per festival celebrated in an earlier year (plan 3220).
const MAX_TASK_STAGE: int = 2

static var _tasks: Array[Dictionary] = []

## How many earlier years the player celebrated [param fest] (took its gift), up to MAX_TASK_STAGE.
static func task_stage(fest: Dictionary, year: int) -> int:
	var n: int = 0
	var prefix: String = "season_%s_" % str(fest.get("id", ""))
	for k: Variant in GameState.flags:
		var key: String = str(k)
		if key.begins_with(prefix) and GameState.has_flag(key) and key.trim_prefix(prefix).to_int() < year:
			n += 1
	return mini(n, MAX_TASK_STAGE)

## Stage of the running festival's task (0 outside festivals or in the first year).
static func current_stage() -> int:
	var a: Dictionary = active()
	if a.is_empty():
		return 0
	var d: Dictionary = Online.date_now()
	return task_stage(a.fest, Season.festival_year(int(d.month), int(d.year)))

## How many the task [param t] needs this year: its count times (stage + 1).
static func task_need(t: Dictionary) -> int:
	return int(t.get("n", 1)) * (current_stage() + 1)

## Element names of [param fest] (Season stores them as Elements.E values).
static func element_names(fest: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Variant in fest.get("elements", []):
		var i: int = int(Elements.E.get(str(e), -1)) if e is String else int(e)
		out.append(Loc.t(Elements.element_name(maxi(0, i))))
	return out

## A short note the first time the game starts during a festival (plan 3226), else "".
static func start_hint() -> String:
	var a: Dictionary = active()
	if a.is_empty() or str(GameState.records.get("festival_hint", "")) == str(a.key):
		return ""
	GameState.records["festival_hint"] = str(a.key)
	return Loc.t("The %s has begun! %s Spirlings are about, and Tilda's stand in Brindlewick trades festival goods.") % [
		Loc.t(str(a.fest.name)), " & ".join(element_names(a.fest))]

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
		lines.append_array(SeasonPath.add("festival_stage"))
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
	var stored: String = str((st.task as Dictionary).get("day", ""))
	if stored != day and not GameState.time_went_back(stored, day):
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
		var need: int = task_need(t)
		task.n = mini(GameState.as_int(task.get("n", 0)) + amount, need)
		if GameState.as_int(task.n) >= need:
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

## Whole days left of the running festival, today included (0 outside festivals).
static func days_left() -> int:
	var a: Dictionary = active()
	if a.is_empty():
		return 0
	var d: Dictionary = Online.date_now()
	var months: Array = (a.fest as Dictionary).months
	var y: int = int(d.year)
	var m: int = int(d.month)
	# Walk to the last month of this festival (Hearth Weeks run over New Year).
	while ((m % 12) + 1) in months:
		if m == 12:
			y += 1
		m = (m % 12) + 1
	var ny: int = y + 1 if m == 12 else y
	var nm: int = 1 if m == 12 else m + 1
	var end: int = Time.get_unix_time_from_datetime_dict({"year": ny, "month": nm, "day": 1})
	var today: int = Time.get_unix_time_from_datetime_dict({"year": int(d.year), "month": int(d.month), "day": int(d.day)})
	return maxi(1, (end - today) / 86400)

## Goals screen block (plan 3222): festival name, days left and ribbons; between festivals the
## next one with its elements.
static func goal_lines() -> Array[String]:
	var out: Array[String] = []
	var a: Dictionary = active()
	if not a.is_empty():
		# The last day reads "ends today", never a countdown under a day (plan 3501).
		if days_left() <= 1:
			out.append(Loc.t("%s: ends today, %d ribbons") % [Loc.t(str(a.fest.name)), ribbons()])
		else:
			out.append(Loc.t("%s: %d days left, %d ribbons") % [Loc.t(str(a.fest.name)), days_left(), ribbons()])
		return out
	var next: Dictionary = Season.next_after(int(Online.date_now().month))
	if not next.is_empty():
		var els: PackedStringArray = element_names(next)
		out.append(Loc.t("Next festival: %s (%s)") % [Loc.t(str(next.name)), ", ".join(els)])
	return out

