class_name EchoPath
extends RefCounted
## The Echo Path (plan area 8, items 3462-3465, 3354): an endgame place behind the mended Cinder
## Rift. A chain of ROOMS small rooms, laid out again every week from the week number, the same
## for everyone. The rooms come from the hand-built templates in data/maps/echo_path.json
## "rooms"; each has one kind (KINDS) and one marker to talk to. Clearing all rooms opens the
## chest at the end: CHEST_WAYMARKS on the first clear of the week.
## The map file holds the entrance hall (floor 0), ROOMS slot floors ({"slot": n}, filled from
## this week's templates by MapData) and the end room (floor ROOMS + 1).
## State: GameState.records["echo_path"] = {"week", "done": [slot numbers], "chest": bool}.

const FILE: String = "echo_path"
const DATA_PATH: String = "res://data/maps/echo_path.json"
const ROOMS: int = 8
const KINDS: Array[String] = ["wild", "echo", "treasure", "rest", "riddle"]
const CHEST_WAYMARKS: int = 40
## Flag that opens the way in (the Cinder Rift is mended).
const OPEN_FLAG: String = "rift_cinder_sealed"
## Wild Spirlings of the week (the Spirlog names them).
const WEEK_SPECIES: int = 3
const WILD_RING: int = 40
const ECHO_RING: int = 44
const ECHO_TEAM: int = 3
## Every room is the same size: forward stairs at the top, back stairs at the bottom.
const WIDTH: int = 10
const HEIGHT: int = 8
const STAIRS_X: Array[int] = [4, 5]
const ARRIVE_UP := Vector2i(4, HEIGHT - 2)
const ARRIVE_DOWN := Vector2i(4, 1)
const MARKER_SPRITES: Dictionary = {"wild": "hush", "echo": "ranger", "treasure": "elder", "rest": "villager", "riddle": "warden"}

static var _raw: Dictionary = {}
## Tests can pin the week ("" = this server week).
static var force_week: String = ""

static func raw() -> Dictionary:
	if _raw.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		if d is Dictionary:
			_raw = d
	return _raw

static func templates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Variant in raw().get("rooms", []):
		if t is Dictionary:
			out.append(t)
	return out

static func week() -> String:
	return force_week if force_week != "" else WeeklyChallenge.this_week()

static func _rng(w: String, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-echo-path-%s-%s" % [what, w])
	return r

## Template indexes for slots 1..ROOMS in week [param w]: one room of every kind, the rest
## drawn from what is left, then shuffled. The same for every player.
static func order(w: String = "") -> Array[int]:
	if w == "":
		w = week()
	var r := _rng(w, "order")
	var all: Array[Dictionary] = templates()
	var left: Array[int] = []
	for i: int in all.size():
		left.append(i)
	var picks: Array[int] = []
	for k: String in KINDS:
		var of_kind: Array[int] = []
		for i: int in left:
			if str(all[i].get("kind", "")) == k:
				of_kind.append(i)
		if not of_kind.is_empty():
			var i: int = of_kind[r.randi_range(0, of_kind.size() - 1)]
			picks.append(i)
			left.erase(i)
	while picks.size() < ROOMS and not left.is_empty():
		picks.append(left.pop_at(r.randi_range(0, left.size() - 1)))
	for i: int in range(picks.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var t: int = picks[i]
		picks[i] = picks[j]
		picks[j] = t
	return picks

static func template_for(slot: int, w: String = "") -> Dictionary:
	var o: Array[int] = order(w)
	if slot < 1 or slot > o.size():
		return {}
	return templates()[o[slot - 1]]

static func slot_id(slot: int) -> String:
	return MapData.floor_id(FILE, slot)

static func end_id() -> String:
	return MapData.floor_id(FILE, ROOMS + 1)

## Floor dictionary for slot [param slot] this week: the template's rows and marker plus
## stairs up to the next room and down to the one before (MapData.from_dict calls this).
static func build_room(slot: int, w: String = "") -> Dictionary:
	var t: Dictionary = template_for(slot, w)
	if t.is_empty():
		return {}
	var room: Dictionary = t.duplicate(true)
	var kind: String = str(t.get("kind", "wild"))
	var up: String = slot_id(slot + 1) if slot < ROOMS else end_id()
	var down: String = slot_id(slot - 1) if slot > 1 else FILE
	var warps: Array = []
	for x: int in STAIRS_X:
		warps.append({"x": x, "y": 0, "to": up, "tx": ARRIVE_UP.x, "ty": ARRIVE_UP.y, "facing": "up"})
		warps.append({"x": x, "y": HEIGHT - 1, "to": down, "tx": ARRIVE_DOWN.x, "ty": ARRIVE_DOWN.y, "facing": "down"})
	room["warps"] = warps
	var mk: Array = t.get("marker", [2, 3])
	var dialogue: String = "echo_path/" + (str(t.riddle) if kind == "riddle" and t.has("riddle") else kind)
	room["npcs"] = [{"id": "echo_marker_%d" % slot, "x": int(mk[0]), "y": int(mk[1]), "facing": "down",
		"sprite": str(MARKER_SPRITES.get(kind, "villager")), "dialogue": dialogue}]
	room["name"] = "%s %d/%d" % [str(raw().get("name", "Echo Path")), slot, ROOMS]
	room.erase("kind")
	room.erase("marker")
	room.erase("riddle")
	room.erase("item")
	room.erase("count")
	return room

## Slot number of map [param map_id] (1..ROOMS), or 0.
static func slot_of(map_id: String) -> int:
	var parts: Array = MapData.split_id(map_id)
	if str(parts[0]) != FILE:
		return 0
	var n: int = int(parts[1])
	return n if n >= 1 and n <= ROOMS else 0

static func kind_of(slot: int) -> String:
	return str(template_for(slot).get("kind", ""))

static func state() -> Dictionary:
	var st: Dictionary = GameState.as_dict(GameState.records.get("echo_path", {}))
	var stored: String = str(st.get("week", ""))
	if stored != week() and not GameState.time_went_back(stored, week()) or not st.get("done", []) is Array:
		st = {"week": week(), "done": [], "chest": false}
		GameState.records["echo_path"] = st
	return st

static func is_done(slot: int) -> bool:
	return slot in (state().done as Array)

static func done_count() -> int:
	return (state().done as Array).size()

static func all_done() -> bool:
	return done_count() >= ROOMS

## Marks room [param slot] as cleared this week. Returns true the first time.
static func clear(slot: int) -> bool:
	if slot < 1 or slot > ROOMS or is_done(slot):
		return false
	var st: Dictionary = state()
	var done: Array = st.done
	done.append(slot)
	st["done"] = done
	GameState.records["echo_path"] = st
	return true

## The week's wild Spirlings: WEEK_SPECIES kinds, never ancient ones, the same for everyone.
static func week_species(w: String = "") -> Array[String]:
	if w == "":
		w = week()
	var pool: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		if sd.rarity != "ancient":
			pool.append(sd)
	pool.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	var r := _rng(w, "species")
	var out: Array[String] = []
	while out.size() < WEEK_SPECIES and not pool.is_empty():
		out.append(pool.pop_at(r.randi_range(0, pool.size() - 1)).species_name)
	return out

## The wild Spirling waiting in room [param slot]: one of the week's kinds.
static func wild_for(slot: int) -> Spirling:
	var list: Array[String] = week_species()
	if list.is_empty():
		return null
	var sd: SpirlingData = Database.species(list[posmod(slot, list.size())])
	if sd == null:
		return null
	return Spirling.new(sd, WILD_RING, _rng(week(), "wild%d" % slot))

## The Wanderer echo in room [param slot]: ECHO_TEAM Spirlings, the same all week.
static func echo_team(slot: int) -> Array[Spirling]:
	var out: Array[Spirling] = []
	var pool: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		var evo_at: int = BalanceSim.evolve_at(sd)
		if sd.rarity != "ancient" and ECHO_RING >= BalanceSim.min_level(sd) and not (evo_at > 0 and ECHO_RING >= evo_at):
			pool.append(sd)
	pool.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	var r := _rng(week(), "echo%d" % slot)
	while out.size() < ECHO_TEAM and not pool.is_empty():
		out.append(Spirling.new(pool.pop_at(r.randi_range(0, pool.size() - 1)), ECHO_RING, r))
	return out

## Treasure room [param slot]: its find on the first clear of the week. Returns the lines.
static func take_treasure(slot: int) -> Array[String]:
	var lines: Array[String] = []
	var t: Dictionary = template_for(slot)
	if str(t.get("kind", "")) != "treasure" or not clear(slot):
		return lines
	var item: String = str(t.get("item", "tonic"))
	var count: int = maxi(1, int(t.get("count", 1)))
	if Database.items.has(item):
		GameState.add_item(item, count)
		lines.append(Loc.t("You got %s x%d.") % [Loc.t(str(Database.item(item).get("name", item))), count])
	return lines

## The chest at the end: CHEST_WAYMARKS once a week when every room is cleared.
static func open_chest() -> Array[String]:
	var lines: Array[String] = []
	var st: Dictionary = state()
	if not all_done():
		lines.append(Loc.t("The chest stays shut. Rooms cleared this week: %d of %d.") % [done_count(), ROOMS])
		return lines
	if bool(st.get("chest", false)):
		lines.append(Loc.t("The chest is empty. A new path forms next week."))
		return lines
	st["chest"] = true
	GameState.records["echo_path"] = st
	GameState.records["echo_path_clears"] = GameState.as_int(GameState.records.get("echo_path_clears", 0)) + 1
	lines.append(Loc.t("The chest opens with a soft chime."))
	lines.append_array(Waymarks.reward_lines(Waymarks.earn(CHEST_WAYMARKS, "echo_path")))
	return lines

## Spirlog hint (plan 3354): which kinds roam the Echo Path this week.
static func spirlog_hint() -> String:
	var names: PackedStringArray = []
	for sp: String in week_species():
		names.append(sp)
	return Loc.t("Echo Path this week: %s") % ", ".join(names)

## Goals screen line.
static func goal_line() -> String:
	var st: Dictionary = state()
	return "%s %s" % ["[x]" if bool(st.get("chest", false)) else "[ ]", Loc.t("Echo Path: %d of %d rooms this week") % [done_count(), ROOMS]]
