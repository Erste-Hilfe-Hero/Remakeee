class_name WorldEvents
extends RefCounted
## Small world events (plan area 8, items 3422-3424). Each server day draws, from a seed made of
## the date only, one event at one place and where the wandering merchant stands. So everyone
## sees the same on the same day. The event gives a small find on the first visit to its place
## that day; the merchant sells three goods for coins. What was claimed today lives in
## GameState.records["world_events"] = {"day", "claimed": [ids]}.

const EVENTS_PATH: String = "res://data/events.json"
const DATA_PATH: String = "res://data/endgame.json"
const MERCHANT_ID: String = "wandering_merchant"
const MERCHANT_SPRITE: String = "villager"

static var _events: Array[Dictionary] = []
static var _merchant: Dictionary = {}
## Tests can pin the merchant to a spot index (-1 = by date).
static var force_spot: int = -1

static func events() -> Array[Dictionary]:
	if _events.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH)) if FileAccess.file_exists(EVENTS_PATH) else null
		if d is Dictionary:
			for e: Variant in (d as Dictionary).get("world_events", []):
				if e is Dictionary:
					_events.append(e)
	return _events

static func merchant_data() -> Dictionary:
	if _merchant.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		if d is Dictionary:
			_merchant = (d as Dictionary).get("merchant", {})
	return _merchant

static func day_key() -> String:
	return DailyFind.today_key()

static func _rng(day: String, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-world-%s-%s" % [what, day])
	return r

## The day before [param day] ("YYYY-MM-DD"), for the "different place each day" rule.
static func previous_day(day: String) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)

## Today's event: one entry of data/events.json "world_events", the same for every player.
static func event_for(day: String) -> Dictionary:
	var list: Array[Dictionary] = events()
	if list.is_empty():
		return {}
	return list[_rng(day, "event").randi_range(0, list.size() - 1)]

static func _day_number(day: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(day + "T12:00:00") / 86400)

## The visiting order for block [param block] of n days: a seeded shuffle of all spots.
static func _block_order(block: int, n: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in n:
		order.append(i)
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-world-merchant-%d" % block)
	for i: int in range(n - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	return order

## Spot of the merchant on [param day]. Days come in blocks of one visit to every spot, so the
## merchant is never at the same place two days in a row (across blocks the first two swap).
static func _spot_index(day: String) -> int:
	var n: int = (merchant_data().get("spots", []) as Array).size()
	if n == 0:
		return -1
	if n == 1:
		return 0
	var d: int = _day_number(day)
	var block: int = floori(float(d) / n)
	var order: Array[int] = _block_order(block, n)
	var last_before: int = _block_order(block - 1, n)[n - 1]
	if order[0] == last_before:
		var t: int = order[0]
		order[0] = order[1]
		order[1] = t
	return order[posmod(d, n)]

## Where the merchant stands on [param day] and what they sell:
## {"map", "x", "y", "items": [item ids]}, or {} without data.
static func merchant_for(day: String) -> Dictionary:
	var spots: Array = merchant_data().get("spots", [])
	var i: int = force_spot if force_spot >= 0 else _spot_index(day)
	if i < 0 or i >= spots.size():
		return {}
	var out: Dictionary = (spots[i] as Dictionary).duplicate()
	var stock: Array = (merchant_data().get("stock", []) as Array).duplicate()
	var r := _rng(day, "stock")
	var items: Array[String] = []
	var n: int = int(merchant_data().get("per_day", 3))
	while items.size() < n and not stock.is_empty():
		items.append(str(stock.pop_at(r.randi_range(0, stock.size() - 1))))
	out["items"] = items
	return out

static func merchant() -> Dictionary:
	return merchant_for(day_key())

static func today() -> Dictionary:
	return event_for(day_key())

## The merchant NPC for map [param map_id] today (MapData adds it), or [].
static func npcs_for(map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: Dictionary = merchant()
	if not m.is_empty() and str(m.map) == map_id:
		out.append({"id": MERCHANT_ID, "x": int(m.x), "y": int(m.y), "facing": "down",
			"sprite": MERCHANT_SPRITE, "dialogue": "world/merchant"})
	return out

static func _state() -> Dictionary:
	var st: Dictionary = GameState.as_dict(GameState.records.get("world_events", {}))
	if str(st.get("day", "")) != day_key() or not st.get("claimed", []) is Array:
		st = {"day": day_key(), "claimed": []}
	return st

## Called on every map load: the first visit to today's event place gives its find.
## Returns the lines to show (already translated), or [] if there is nothing new.
static func on_visit(map_id: String) -> Array[String]:
	var lines: Array[String] = []
	var e: Dictionary = today()
	if e.is_empty() or str(e.get("map", "")) != map_id:
		return lines
	var st: Dictionary = _state()
	var claimed: Array = st.claimed
	if str(e.id) in claimed:
		return lines
	claimed.append(str(e.id))
	st["claimed"] = claimed
	GameState.records["world_events"] = st
	var item: String = str(e.get("item", ""))
	var count: int = maxi(1, int(e.get("count", 1)))
	lines.append(Loc.t(str(e.get("found", e.get("text", "")))))
	if Database.items.has(item):
		GameState.add_item(item, count)
		lines.append(Loc.t("You got %s x%d.") % [Loc.t(str(Database.item(item).get("name", item))), count])
	return lines

## Goals screen block (item 3424): today's event and where the merchant stands.
static func lines() -> Array[String]:
	var out: Array[String] = []
	var e: Dictionary = today()
	if not e.is_empty():
		var done: bool = str(e.id) in (_state().claimed as Array)
		out.append("%s %s" % ["[x]" if done else "[ ]", Loc.t(str(e.text))])
	var m: Dictionary = merchant()
	if not m.is_empty():
		var place: String = MapData.load_map(str(m.map)).display_name if MapData.exists(str(m.map)) else str(m.map)
		out.append(Loc.t("Wandering merchant today: %s") % Loc.t(place))
	return out
