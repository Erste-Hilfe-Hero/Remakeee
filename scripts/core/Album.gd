class_name Album
extends RefCounted
## Monthly sticker album (plan area 8, items 3482-3483). Every calendar month (server time) has
## FIELDS sticker fields, each a fixed task that can be done any time in that month. The tasks
## are drawn from data/events.json "album_tasks" with the seed "chimora-album-YYYY-MM", the same
## for everyone. A full album pays FULL_WAYMARKS once and puts that month's sticker on the
## sticker wall. Missing a month costs nothing: the next one simply starts fresh.
## State: GameState.records["album"] = {"month", "tasks": [{"id", "n", "seen"?}], "full"};
## stickers: GameState.records["album_stickers"] = [month keys].

const DATA_PATH: String = "res://data/events.json"
const FIELDS: int = 12
const FULL_WAYMARKS: int = 100
## At most this many fields name one place.
const MAX_PLACE_FIELDS: int = 2

static var _defs: Array[Dictionary] = []

static func defs() -> Array[Dictionary]:
	if _defs.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		if d is Dictionary:
			for t: Variant in (d as Dictionary).get("album_tasks", []):
				if t is Dictionary:
					_defs.append(t)
	return _defs

static func def(id: String) -> Dictionary:
	for t: Dictionary in defs():
		if str(t.id) == id:
			return t
	return {}

static func month_key() -> String:
	var d: Dictionary = Online.date_now()
	return "%04d-%02d" % [int(d.year), int(d.month)]

## The FIELDS task ids for [param month], the same every time.
static func draw(month: String) -> Array[String]:
	var pool: Array[Dictionary] = defs().duplicate()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-album-" + month)
	var out: Array[String] = []
	var places: int = 0
	while out.size() < FIELDS and not pool.is_empty():
		var t: Dictionary = pool.pop_at(r.randi_range(0, pool.size() - 1))
		if t.has("map"):
			if places >= MAX_PLACE_FIELDS:
				continue
			places += 1
		out.append(str(t.id))
	return out

static func _valid(st: Dictionary) -> bool:
	var tasks: Variant = st.get("tasks")
	if not tasks is Array:
		return false
	for e: Variant in tasks:
		if not e is Dictionary or not (e as Dictionary).has("id"):
			return false
	return true

## This month's album, started fresh when the month changed.
static func state() -> Dictionary:
	var month: String = month_key()
	var st: Dictionary = GameState.as_dict(GameState.records.get("album", {}))
	var stored: String = str(st.get("month", ""))
	if GameState.time_went_back(stored, month) and _valid(st):
		return st
	if stored != month or not _valid(st):
		var tasks: Array = []
		for id: String in draw(month):
			tasks.append({"id": id, "n": 0})
		st = {"month": month, "tasks": tasks, "full": false}
		GameState.records["album"] = st
	return st

static func is_done(entry: Dictionary) -> bool:
	return GameState.as_int(entry.get("n", 0)) >= int(def(str(entry.get("id", ""))).get("n", 1))

static func filled() -> int:
	var n: int = 0
	for e: Dictionary in state().tasks:
		if is_done(e):
			n += 1
	return n

static func stickers() -> Array:
	var s: Variant = GameState.records.get("album_stickers", [])
	return s if s is Array else []

## Counts game event [param event] for this month's fields (DailyTasks.record calls it, plus
## "daily" when a daily task is done). Returns the lines to show.
static func record(event: String, info: Dictionary = {}, amount: int = 1) -> Array[String]:
	var lines: Array[String] = []
	var st: Dictionary = state()
	for entry: Dictionary in st.tasks:
		if is_done(entry):
			continue
		var t: Dictionary = def(str(entry.id))
		if t.is_empty() or not DailyTasks.matches(t, event, info):
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
			entry["n"] = mini(GameState.as_int(entry.get("n", 0)) + amount, int(t.get("n", 1)))
		if is_done(entry):
			lines.append(Loc.t("Album sticker: %s") % Loc.t(str(t.text)))
	if not bool(st.get("full", false)) and filled() >= (st.tasks as Array).size() and not (st.tasks as Array).is_empty():
		st["full"] = true
		var wall: Array = stickers()
		if not str(st.month) in wall:
			# Each month pays once, even if its album state was ever drawn again.
			wall.append(str(st.month))
			GameState.records["album_stickers"] = wall
			lines.append(Loc.t("The album for %s is full! Its sticker goes on your wall.") % str(st.month))
			lines.append_array(Waymarks.reward_lines(Waymarks.earn(FULL_WAYMARKS, "album")))
	return lines

## Goals screen block: fields with progress.
static func lines() -> Array[String]:
	var st: Dictionary = state()
	var out: Array[String] = [Loc.t("Album %s: %d/%d stickers") % [str(st.month), filled(), (st.tasks as Array).size()]]
	for entry: Dictionary in st.tasks:
		var t: Dictionary = def(str(entry.id))
		var need: int = int(t.get("n", 1))
		out.append("%s %s %d/%d" % ["[x]" if is_done(entry) else "[ ]", Loc.t(str(t.get("text", entry.id))), mini(GameState.as_int(entry.get("n", 0)), need), need])
	if bool(st.get("full", false)):
		out.append(Loc.t("Full! A new album starts next month."))
	else:
		out.append(Loc.t("A full album: %d Waymarks and a sticker for your wall.") % FULL_WAYMARKS)
	return out

## Sticker wall lines: one per full month.
static func wall_lines() -> Array[String]:
	var out: Array[String] = []
	for m: Variant in stickers():
		out.append(Loc.t("Sticker for %s") % str(m))
	return out
