class_name Expeditions
extends RefCounted
## Roaming trips (plan area 8, items 3446-3448): Aldo sends up to MAX Spirlings from storage
## on a trip of 4, 8 or 12 hours by server time. Each plan brings back a fixed, shown-before
## reward: coins, Waymarks and one common item. Spirlings on a trip stay in storage (marked
## with the backpack GLYPH) and cannot be called back until they are home.
## State: GameState.records["expeditions"] = [{"uid", "hours", "start"}].

const DATA_PATH: String = "res://data/endgame.json"
## Backpack glyph in PixelFont (U+E004).
const GLYPH: String = ""

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		if d is Dictionary:
			_data = (d as Dictionary).get("expeditions", {})
	return _data

static func max_trips() -> int:
	return int(data().get("max", 3))

static func plans() -> Array:
	return data().get("plans", [])

static func plan_for(hours: int) -> Dictionary:
	for p: Variant in plans():
		if p is Dictionary and int((p as Dictionary).get("hours", 0)) == hours:
			return p
	return {}

## The trips under way, damaged entries left out.
static func trips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = GameState.records.get("expeditions", [])
	if not raw is Array:
		return out
	for t: Variant in raw:
		if t is Dictionary and (t as Dictionary).has("uid") and not plan_for(int((t as Dictionary).get("hours", 0))).is_empty():
			out.append(t)
	return out

static func is_away(uid: String) -> bool:
	if uid == "":
		return false
	for t: Dictionary in trips():
		if str(t.uid) == uid:
			return true
	return false

static func _spirling(uid: String) -> Spirling:
	for s: Spirling in GameState.storage:
		if s.uid == uid:
			return s
	return null

## Storage Spirlings that can go on a trip now.
static func ready_to_go() -> Array[Spirling]:
	var out: Array[Spirling] = []
	for s: Spirling in GameState.storage:
		if s.uid != "" and not is_away(s.uid):
			out.append(s)
	return out

static func can_send() -> bool:
	return trips().size() < max_trips() and not ready_to_go().is_empty()

## Sends [param s] (in storage) on a trip of [param hours]. Returns false if not allowed.
static func send(s: Spirling, hours: int) -> bool:
	if s == null or not s in GameState.storage or s.uid == "" or is_away(s.uid):
		return false
	if plan_for(hours).is_empty() or trips().size() >= max_trips():
		return false
	var list: Array = trips()
	list.append({"uid": s.uid, "hours": hours, "start": Online.unix_now()})
	GameState.records["expeditions"] = list
	return true

## Seconds until trip [param t] is home (0 when back). Server time, so a changed device clock
## neither ends a trip early nor pays it twice.
static func seconds_left(t: Dictionary) -> int:
	var end: int = int(t.get("start", 0)) + int(t.get("hours", 0)) * 3600
	return maxi(0, end - Online.unix_now())

## The reward line for a plan, shown before sending ("4 h: 150 coins, 4 Waymarks, Tonic").
static func plan_text(p: Dictionary) -> String:
	var item: String = str(p.get("item", ""))
	var item_name: String = Loc.t(str(Database.item(item).get("name", item))) if Database.items.has(item) else item
	return Loc.t("%d h: %d coins, %d Waymarks, %s") % [int(p.hours), int(p.coins), int(p.waymarks), item_name]

## Brings every finished trip home and pays it. Returns the lines to show.
static func collect() -> Array[String]:
	var lines: Array[String] = []
	var keep: Array = []
	for t: Dictionary in trips():
		var s: Spirling = _spirling(str(t.uid))
		if s == null:
			# The Spirling left storage some other way (old save): the trip just ends.
			continue
		if seconds_left(t) > 0:
			keep.append(t)
			continue
		var p: Dictionary = plan_for(int(t.hours))
		GameState.money += int(p.coins)
		var item: String = str(p.get("item", ""))
		if Database.items.has(item):
			GameState.add_item(item)
		lines.append(Loc.t("%s is back from the trip with %d coins and %s.") % [s.display_name(), int(p.coins),
			Loc.t(str(Database.item(item).get("name", item)))])
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(int(p.waymarks), "expedition")))
		GameState.records["expeditions_done"] = int(GameState.records.get("expeditions_done", 0)) + 1
	GameState.records["expeditions"] = keep
	return lines

## "Name: 3 h 20 min left" for each trip.
static func status_lines() -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in trips():
		var s: Spirling = _spirling(str(t.uid))
		var left: int = seconds_left(t)
		var who: String = s.display_name() if s != null else "?"
		if left <= 0:
			out.append(Loc.t("%s: back home") % who)
		else:
			out.append(Loc.t("%s: %d h %d min left") % [who, left / 3600, (left / 60) % 60])
	return out
