class_name Masters
extends RefCounted
## Master Wayfarers (plan area 8, items 3288-3290): eight strong tamers at fixed places in
## Veydal. They appear once both Rifts are mended (flag SHOW_FLAG) and field one element each
## with teams at ring 45 to 55. The first win pays FIRST_WAYMARKS, later wins WEEKLY_WAYMARKS
## once per ISO week. Wins live in GameState.records["masters"]: id -> {"first", "week"}.

const DATA_PATH: String = "res://data/endgame.json"
const SHOW_FLAG: String = "storage_remote"
const FIRST_WAYMARKS: int = 80
const WEEKLY_WAYMARKS: int = 5
const TEAM_SIZE: int = 4
const MIN_RING: int = 45
const MAX_RING: int = 55

static var _list: Array[Dictionary] = []

static func list() -> Array[Dictionary]:
	if _list.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for m: Variant in (d as Dictionary).get("masters", []):
					if m is Dictionary:
						_list.append(m)
	return _list

static func find(id: String) -> Dictionary:
	for m: Dictionary in list():
		if str(m.id) == id:
			return m
	return {}

## True once the masters show up in the world (both Rifts mended).
static func open() -> bool:
	return GameState.has_flag(SHOW_FLAG)

## NPC definitions for the masters on map [param map_id] (MapData adds them to the map).
static func npcs_for(map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in list():
		if str(m.get("map", "")) == map_id:
			out.append({"id": "master_" + str(m.id), "x": int(m.x), "y": int(m.y), "facing": str(m.get("facing", "down")),
				"sprite": str(m.get("sprite", "villager")), "dialogue": "masters/" + str(m.id), "show_flag": SHOW_FLAG})
	return out

static func level(m: Dictionary) -> int:
	return clampi(int(m.get("level", MIN_RING)), MIN_RING, MAX_RING)

## Which of the three prepared teams master [param id] fields (plan 3300): the first until the
## week after the first win, then one per week, the same for the whole week.
static func variant(id: String) -> int:
	var m: Dictionary = find(id)
	var n: int = (m.get("teams", []) as Array).size()
	var rec: Dictionary = record(id)
	if n <= 1 or str(rec.get("first", "")) == "":
		return 0
	var week: String = WeeklyChallenge.this_week()
	if week <= str(rec.get("first_week", rec.get("week", week))):
		return 0
	return absi(hash([id, week])) % n

## The master's team: the prepared team of data/endgame.json (plan 3291) with its arts and
## keepsakes, picked by variant(). Without prepared teams: TEAM_SIZE Spirlings of their element,
## final forms for their ring, the lead two rings under the master.
static func team(id: String) -> Array[Spirling]:
	var m: Dictionary = find(id)
	var out: Array[Spirling] = []
	if m.is_empty():
		return out
	var prepared: Array = m.get("teams", [])
	if not prepared.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["chimora-master", id, variant(id)])
		return TrainerData.build_team({"team": prepared[variant(id)]}, "", rng)
	var lv: int = level(m)
	var e: int = int(Elements.E.get(str(m.get("element", "")), -1))
	var fits := func(sd: SpirlingData) -> bool:
		var evo_at: int = BalanceSim.evolve_at(sd)
		return lv >= BalanceSim.min_level(sd) and not (evo_at > 0 and lv >= evo_at)
	var pool: Array[SpirlingData] = []
	var rest: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		if fits.call(sd):
			if e in sd.elements:
				pool.append(sd)
			else:
				rest.append(sd)
	var by_dex := func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id
	pool.sort_custom(by_dex)
	rest.sort_custom(by_dex)
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-master-" + id)
	# Different species where the element has enough, others fill the gaps.
	while pool.size() < TEAM_SIZE and not rest.is_empty():
		pool.append(rest.pop_at(r.randi_range(0, rest.size() - 1)))
	var picks: Array[SpirlingData] = pool.duplicate()
	for k: int in TEAM_SIZE:
		if picks.is_empty():
			picks = pool.duplicate()
		var sd: SpirlingData = picks.pop_at(r.randi_range(0, picks.size() - 1))
		out.append(Spirling.new(sd, lv - 2 + mini(k, 2), r))
	return out

static func record(id: String) -> Dictionary:
	var all: Dictionary = GameState.as_dict(GameState.records.get("masters", {}))
	return GameState.as_dict(all.get(id, {}))

static func beaten(id: String) -> bool:
	return str(record(id).get("first", "")) != ""

static func beaten_count() -> int:
	var n: int = 0
	for m: Dictionary in list():
		if beaten(str(m.id)):
			n += 1
	return n

## Notes a win against master [param id] and pays what is due. Returns the reward lines.
static func win(id: String) -> Array[String]:
	var lines: Array[String] = []
	if find(id).is_empty():
		return lines
	var all: Dictionary = GameState.as_dict(GameState.records.get("masters", {}))
	var rec: Dictionary = GameState.as_dict(all.get(id, {}))
	var week: String = WeeklyChallenge.this_week()
	if str(rec.get("first", "")) == "":
		rec["first"] = Time.get_date_string_from_unix_time(Online.unix_now())
		rec["week"] = week
		rec["first_week"] = week
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(FIRST_WAYMARKS, "master")))
	elif str(rec.get("week", "")) < week:
		rec["week"] = week
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(WEEKLY_WAYMARKS, "master")))
	else:
		lines.append(Loc.t("The Waymarks for this master come back next week."))
	rec["wins"] = int(rec.get("wins", 0)) + 1
	all[id] = rec
	GameState.records["masters"] = all
	return lines

## True if beating [param id] this week still pays Waymarks.
static func pays_now(id: String) -> bool:
	var rec: Dictionary = record(id)
	return str(rec.get("first", "")) == "" or str(rec.get("week", "")) < WeeklyChallenge.this_week()

## Profile card (item 3290): place, theme and the player's own record.
static func profile(m: Dictionary) -> String:
	var parts: PackedStringArray = [Loc.t("%s, %s") % [str(m.name), Loc.t(str(m.title))]]
	var place: String = MapData.load_map(str(m.map)).display_name if MapData.exists(str(m.map)) else str(m.map)
	parts.append(Loc.t("Place: %s") % Loc.t(place))
	var e: int = int(Elements.E.get(str(m.get("element", "")), 0))
	parts.append(Loc.t("Theme: %s Spirlings, ring %d") % [Loc.t(Elements.element_name(e)), level(m)])
	var rec: Dictionary = record(str(m.id))
	if str(rec.get("first", "")) != "":
		parts.append(Loc.t("First win: %s (%d wins)") % [str(rec.first), int(rec.get("wins", 1))])
	else:
		parts.append(Loc.t("Not beaten yet."))
	return "\n".join(parts)

## Master round (plan 3292): all eight masters one after another in the lighthouse, open once
## every master is beaten. The first full clear pays ROUND_WAYMARKS once.
const ROUND_WAYMARKS: int = 100
const ROUND_REST_AFTER: int = 4

static func round_open() -> bool:
	return not list().is_empty() and beaten_count() >= list().size()

static func round_best() -> int:
	return int(GameState.records.get("master_round_best", 0))

## Books a master round that beat [param beaten] masters and returns the reward lines.
static func finish_round(beaten: int) -> Array[String]:
	GameState.records["master_round_best"] = maxi(round_best(), beaten)
	if beaten < list().size() or bool(GameState.records.get("master_round_paid", false)):
		return []
	GameState.records["master_round_paid"] = true
	return Waymarks.reward_lines(Waymarks.earn(ROUND_WAYMARKS, "master"))

## Menu lines for the profile list: "[x] Name, title".
static func lines() -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in list():
		out.append("%s %s" % ["[x]" if beaten(str(m.id)) else "[ ]", str(m.name)])
	return out
