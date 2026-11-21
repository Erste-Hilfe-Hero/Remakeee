class_name Expeditions
extends RefCounted
## Roaming trips (plan area 8, items 3446-3448): Aldo sends up to MAX Spirlings from storage
## on a trip of 4, 8 or 12 hours by server time. Each plan brings back a fixed, shown-before
## reward: coins, Waymarks and one common item. Spirlings on a trip stay in storage (marked
## with the backpack GLYPH) and cannot be called back until they are home.
## Plan 3449-3455: a trip goes to a known wild map ("dest") and brings one of that map's hidden
## finds (common ones only, else the plan's item). A Spirling sharing an element with the map's
## wild kinds brings MATCH_BONUS_PCT more coins. Each hour gives a quarter of a wild battle's
## growth, up to the story ring cap. A trip never fails and costs no Vigor. Sanctuary Spirlings
## (Iron Oath) never go, only storage ones. Each result is kept as a diary line.
## State: GameState.records["expeditions"] = [{"uid", "hours", "start", "dest"}],
## records["expedition_log"] = last LOG_SIZE diary lines.

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

const LOG_SIZE: int = 10

static func max_trips() -> int:
	return int(data().get("max", 3))

static func plans() -> Array:
	return data().get("plans", [])

static func match_bonus_pct() -> int:
	return int(data().get("match_bonus_pct", 50))

## Share of one wild battle's growth per hour away.
static func xp_share() -> float:
	return float(data().get("xp_per_hour", 0.25))

static func find_max_price() -> int:
	return int(data().get("find_max_price", 450))

## Wild maps this save already knows (visited), in visit order.
static func destinations() -> Array[String]:
	var out: Array[String] = []
	for m: Variant in GameState.records.get("maps_visited", []):
		var id: String = str(m)
		if MapData.exists(id) and not MapData.load_map(id).encounter_table.is_empty() and not id in out:
			out.append(id)
	return out

## Common hidden finds of a map (no gear, held, teaching or unfolding items, nothing dear).
static func finds(map_id: String) -> Array[String]:
	var out: Array[String] = []
	if not MapData.exists(map_id):
		return out
	for sc: Dictionary in MapData.load_map(map_id).secrets:
		var id: String = str(sc.get("item", ""))
		var it: Dictionary = Database.item(id) if Database.items.has(id) else {}
		if it.is_empty() or id in out or int(it.get("price", 0)) > find_max_price():
			continue
		if it.has("held") or it.has("gear") or it.has("teaches") or it.has("evolves") or bool(it.get("shop", false)):
			continue
		out.append(id)
	out.sort()
	return out

## Elements of the map's wild kinds.
static func map_elements(map_id: String) -> Array[int]:
	var out: Array[int] = []
	if not MapData.exists(map_id):
		return out
	for sp: String in EncounterTable.species_on(MapData.load_map(map_id).encounter_table):
		var sd: SpirlingData = Database.species(sp)
		if sd != null:
			for e: int in sd.elements:
				if not e in out:
					out.append(e)
	return out

static func element_match(s: Spirling, map_id: String) -> bool:
	var els: Array[int] = map_elements(map_id)
	return s != null and s.data.elements.any(func(e: int) -> bool: return e in els)

## Coins for a plan to [param map_id]: +MATCH_BONUS_PCT for a matching element (plan 3450).
static func coins_for(s: Spirling, p: Dictionary, map_id: String) -> int:
	var c: int = int(p.get("coins", 0))
	return c + c * match_bonus_pct() / 100 if element_match(s, map_id) else c

## The find for a trip: one of the map's finds, fixed by the trip, else the plan's item.
static func find_for(t: Dictionary) -> String:
	var f: Array[String] = finds(str(t.get("dest", "")))
	if f.is_empty():
		return str(plan_for(int(t.get("hours", 0))).get("item", ""))
	return f[absi(hash([str(t.get("uid", "")), int(t.get("start", 0))])) % f.size()]

## Growth for [param hours] away: a quarter of a wild battle at its own ring per hour (plan 3451).
static func xp_for(s: Spirling, hours: int) -> int:
	return int(float(s.data.xp_yield) * float(s.level) / BattleModel.XP_LEVEL_DIV * xp_share() * hours)

## Adds trip growth up to the story ring cap. Returns the rings gained.
static func grow(s: Spirling, amount: int) -> int:
	var cap: int = mini(GameState.progress_cap(), Spirling.STORY_RING)
	if s.level >= cap or amount <= 0:
		return 0
	var before: int = s.level
	s.xp = mini(s.xp + amount, Spirling.xp_for_level(cap))
	while s.level < cap and s.xp >= Spirling.xp_for_level(s.level + 1):
		s.level_up()
	return s.level - before

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

## Sends [param s] (in storage) on a trip of [param hours] to [param dest] (a known wild map,
## or "" for no map). Returns false if not allowed.
static func send(s: Spirling, hours: int, dest: String = "") -> bool:
	if s == null or not s in GameState.storage or s.uid == "" or is_away(s.uid):
		return false
	if plan_for(hours).is_empty() or trips().size() >= max_trips():
		return false
	if dest != "" and not dest in destinations():
		return false
	var list: Array = trips()
	list.append({"uid": s.uid, "hours": hours, "start": Online.unix_now(), "dest": dest})
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
		var dest: String = str(t.get("dest", ""))
		var coins: int = coins_for(s, p, dest)
		GameState.money += coins
		var item: String = find_for(t)
		if Database.items.has(item):
			GameState.add_item(item)
		var item_name: String = Loc.t(str(Database.item(item).get("name", item)))
		lines.append(Loc.t("%s is back from the trip with %d coins and %s.") % [s.display_name(), coins, item_name])
		var rings: int = grow(s, xp_for(s, int(t.hours)))
		if rings > 0:
			lines.append(Loc.t("%s grew %d rings on the way.") % [s.display_name(), rings])
		_log(diary_line(s, dest, item_name))
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(int(p.waymarks), "expedition")))
		GameState.records["expeditions_done"] = int(GameState.records.get("expeditions_done", 0)) + 1
	GameState.records["expeditions"] = keep
	return lines

## A short diary line: "Mossling found a Tonic in Fernstair" (plan 3453).
static func diary_line(s: Spirling, dest: String, item_name: String) -> String:
	if dest == "":
		return Loc.t("%s found a %s on the way") % [s.display_name(), item_name]
	return Loc.t("%s found a %s in %s") % [s.display_name(), item_name, Spirling.place_name(dest)]

static func _log(line: String) -> void:
	var log: Array = GameState.records.get("expedition_log", []) if GameState.records.get("expedition_log") is Array else []
	log.push_front(line)
	GameState.records["expedition_log"] = log.slice(0, LOG_SIZE)

static func diary() -> Array[String]:
	var out: Array[String] = []
	for l: Variant in GameState.records.get("expedition_log", []) if GameState.records.get("expedition_log") is Array else []:
		out.append(str(l))
	return out

## "Name: 3 h 20 min left" for each trip.
static func status_lines() -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in trips():
		var s: Spirling = _spirling(str(t.uid))
		var left: int = seconds_left(t)
		var who: String = s.display_name() if s != null else "?"
		if left <= 0:
			out.append(Loc.t("%s: back home") % who)
		elif left < 3600:
			# No countdown under an hour (plan 3501).
			out.append(Loc.t("%s: back today") % who)
		else:
			out.append(Loc.t("%s: %d h %d min left") % [who, left / 3600, (left / 60) % 60])
	return out
