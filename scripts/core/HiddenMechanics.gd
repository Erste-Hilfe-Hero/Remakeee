class_name HiddenMechanics
extends RefCounted
## Hidden mechanics of 1.3.2 (data/hidden_mechanics.json, team page docs/HIDDEN_MECHANICS.md):
## secret unfold paths, rare spawns under a certain sky or moon, hidden things on map cells, a
## Spirling's favourite sky (its knack) and a few dated easter eggs. The battle touches live in
## scripts/battle/HiddenBattle.gd. Nothing here is sold or rolled for money; the moon, weekday and
## date follow the Berlin calendar day, so every player sees the same moon. What a player found is
## kept in GameState.records (found ids, a count for the badges, presses per spot), so old saves
## load unchanged.

const DATA_PATH: String = "res://data/hidden_mechanics.json"
## A new moon at 2000-01-06 18:14 UTC and the mean length of a lunar month in days.
const MOON_EPOCH: int = 947182440
const SYNODIC_DAYS: float = 29.530588853
## Moon age windows (days) of the full and the new moon, about two days each.
const FULL_FROM: float = 13.77
const FULL_TO: float = 15.77
const NEW_WITHIN: float = 1.0

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = raw if raw is Dictionary else {}
	return _data

# --- Calendar ------------------------------------------------------------------------------

## Days since 1 Jan 1970 in Berlin time.
static func berlin_day(unix: int) -> int:
	return floori(float(unix + ShopCatalog.berlin_offset(unix)) / 86400.0)

## Moon age in days (0 new moon, about 14.8 full moon) at noon of Berlin day [param day].
static func moon_age(day: int) -> float:
	var t: float = float(day) * 86400.0 + 43200.0 - float(MOON_EPOCH)
	return fposmod(t / 86400.0, SYNODIC_DAYS)

## "full", "new" or "" for Berlin day [param day].
static func moon(day: int) -> String:
	var age: float = moon_age(day)
	if age >= FULL_FROM and age < FULL_TO:
		return "full"
	if age < NEW_WITHIN or age >= SYNODIC_DAYS - NEW_WITHIN:
		return "new"
	return ""

## "MM-DD" of Berlin day [param day].
static func date_key(day: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(day * 86400)
	return "%02d-%02d" % [int(d.month), int(d.day)]

static func weekday(day: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(day * 86400).weekday)

## The calendar part of a context: moon, weekday and date of the Berlin day of [param unix].
static func calendar(unix: int) -> Dictionary:
	var day: int = berlin_day(unix)
	return {"moon": moon(day), "weekday": weekday(day), "date": date_key(day), "day": day}

# --- Conditions ----------------------------------------------------------------------------

## Everything a "when" looks at on map [param m] right now.
static func context(m: MapData, unix: int = -1) -> Dictionary:
	if unix < 0:
		unix = Online.unix_now()
	var ctx: Dictionary = calendar(unix)
	ctx["map"] = m.id if m != null else ""
	ctx["region"] = m.region if m != null else ""
	ctx["phase"] = Spirling.PHASE_IDS[DayCycle.current()] if GameState.day_night else "day"
	ctx["weather"] = WeatherCycle.current(m, unix)
	ctx["chain"] = int(GameState.gleam_chain.get("count", 0))
	ctx["lead"] = GameState.party[0] if not GameState.party.is_empty() else null
	return ctx

## True when every key of [param when] holds in [param ctx]; Spirling keys (ring, held, kinship,
## knows) look at [param s]. An unknown key never holds, so a typo hides nothing by accident.
static func met(when: Dictionary, ctx: Dictionary, s: Spirling = null) -> bool:
	for k: String in when:
		var v: Variant = when[k]
		match k:
			"phase", "weather", "moon", "date", "map":
				if str(ctx.get(k, "")) != str(v):
					return false
			"weekday":
				if int(ctx.get(k, -1)) != int(v):
					return false
			"chain":
				if int(ctx.get(k, 0)) < int(v):
					return false
			"ring":
				if s == null or s.level < int(v):
					return false
			"kinship":
				if s == null or s.kinship < int(v):
					return false
			"held":
				if s == null or s.held != str(v):
					return false
			"knows":
				if s == null or not s.moves.any(func(mv: MoveData) -> bool: return mv.move_name == str(v)):
					return false
			"lead_element":
				var lead: Variant = ctx.get("lead")
				if not lead is Spirling or not int(Elements.E.get(str(v), -1)) in (lead as Spirling).elements():
					return false
			_:
				return false
	return true

# --- Found things --------------------------------------------------------------------------

## Marks [param id] as found; true the first time. Keeps the count the secret badges read.
static func note_found(id: String, records: Dictionary) -> bool:
	var key: String = str(data().get("found_record", "hidden_found"))
	var found: Array = records.get(key, [])
	if id in found:
		return false
	found.append(id)
	records[key] = found
	records[str(data().get("count_record", "hidden_found_n"))] = found.size()
	return true

static func is_found(id: String, records: Dictionary) -> bool:
	return id in (records.get(str(data().get("found_record", "hidden_found")), []) as Array)

# --- Unfolds -------------------------------------------------------------------------------

## Secret unfold targets of [param s] in [param ctx] (Spirling.unfold_context plus map). Weather
## and moon are worked out here when the context lacks them.
static func unfold_targets(s: Spirling, ctx: Dictionary) -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	if s == null or s.data == null:
		return out
	var c: Dictionary = ctx
	for u: Dictionary in data().get("unfolds", []):
		if str(u.from) != s.data.species_name:
			continue
		if not c.has("weather") or not c.has("moon"):
			c = _fill_sky(ctx)
		var to: SpirlingData = Database.species(str(u.to))
		if to != null and not out.has(to) and met(u.get("when", {}), c, s):
			out.append(to)
	return out

## Adds weather and calendar to an unfold context; reads the autoloads by node path, so data
## tools without autoloads still get a calm sky.
static func _fill_sky(ctx: Dictionary) -> Dictionary:
	var c: Dictionary = ctx.duplicate()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null(^"/root/GameState") if tree != null else null
	var unix: int = int(Time.get_unix_time_from_system())
	c.merge(calendar(unix), false)
	var map_id: String = str(c.get("map", ""))
	if not c.has("weather"):
		c["weather"] = "clear"
		if gs != null and not map_id.is_empty() and MapData.exists(map_id):
			c["weather"] = WeatherCycle.current(MapData.load_map(map_id), unix, bool(gs.get("weather")))
	return c

# --- Spawns --------------------------------------------------------------------------------

## Spawn entries of map [param map_id] whose "when" holds in [param ctx].
static func spawns_now(map_id: String, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sp: Dictionary in data().get("spawns", []):
		if str(sp.map) == map_id and met(sp.get("when", {}), ctx):
			out.append(sp)
	return out

## Maybe a rare wild Spirling of map [param map_id] under [param ctx]: {"wild", "line", "id"} or {}.
## [param rng] is only drawn from when an entry's conditions hold, so other maps roll as before.
static func maybe_spawn(map_id: String, table_id: String, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	for sp: Dictionary in spawns_now(map_id, ctx):
		if rng.randf() >= float(sp.get("chance", 0.0)):
			continue
		var sd: SpirlingData = Database.species(str(sp.species))
		if sd == null:
			continue
		var rings: Vector2i = spawn_rings(sp, table_id)
		var wild := Spirling.new(sd, rng.randi_range(rings.x, rings.y), rng)
		return {"wild": wild, "line": str(sp.get("line", "")), "id": str(sp.id)}
	return {}

## Ring range of spawn [param sp]: its own min/max, else the rings of the map's table.
static func spawn_rings(sp: Dictionary, table_id: String) -> Vector2i:
	if sp.has("min") and sp.has("max"):
		return Vector2i(int(sp.min), int(sp.max))
	var lo: int = 0
	var hi: int = 0
	for s: Dictionary in EncounterTable.table(table_id).get("spawns", []):
		lo = int(s.get("min", 2)) if lo == 0 else mini(lo, int(s.get("min", 2)))
		hi = maxi(hi, int(s.get("max", 4)))
	return Vector2i(maxi(1, lo), maxi(maxi(1, lo), hi))

# --- Spots ---------------------------------------------------------------------------------

## The spot on [param cell] of map [param map_id] answered by [param at] (tile, landmark, sign), or {}.
static func spot_at(map_id: String, cell: Vector2i, at: String) -> Dictionary:
	for p: Dictionary in data().get("spots", []):
		if str(p.map) == map_id and int(p.x) == cell.x and int(p.y) == cell.y and str(p.get("at", "tile")) == at:
			return p
	return {}

static func spot_flag(p: Dictionary) -> String:
	return str(p.get("flag", "hm_" + str(p.id)))

## True once a one-time spot gave what it holds.
static func spot_done(p: Dictionary, flags: Dictionary) -> bool:
	return not bool(p.get("repeat", false)) and bool(flags.get(spot_flag(p), false))

## One press on spot [param p]. Returns {} when nothing answers (conditions not met), else
## {"lines", "item", "count", "flag", "code"}: "code" true means the sign waits for a word
## (try_code), "flag" non-empty means the spot is done and the caller grants item and flag.
static func tap(p: Dictionary, ctx: Dictionary, records: Dictionary, flags: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	if spot_done(p, flags):
		var after: Array = p.get("after", [])
		return {} if after.is_empty() else {"lines": _strings(after), "item": "", "count": 0, "flag": "", "code": false}
	if not met(p.get("when", {}), ctx):
		return {}
	if p.has("code"):
		return {"lines": _strings(p.get("taps", [])), "item": "", "count": 0, "flag": "", "code": true}
	var need: int = int(p.get("times", 1))
	var taps_key: String = str(data().get("taps_record", "hidden_taps"))
	var taps: Dictionary = records.get(taps_key, {})
	var n: int = int(taps.get(str(p.id), 0)) + 1
	if n < need:
		taps[str(p.id)] = n
		records[taps_key] = taps
		var t: Array = p.get("taps", [])
		var line: Array[String] = [] as Array[String]
		if not t.is_empty():
			line.append(str(t[mini(n - 1, t.size() - 1)]))
		return {"lines": line, "item": "", "count": 0, "flag": "", "code": false}
	taps.erase(str(p.id))
	records[taps_key] = taps
	return {"lines": _strings(p.get("lines", [])), "item": str(p.get("item", "")), "count": int(p.get("count", 0)),
		"flag": spot_flag(p), "code": false}

## True when [param word] opens code spot [param p] (case and spaces do not matter).
static func code_ok(p: Dictionary, word: String) -> bool:
	return not str(p.get("code", "")).is_empty() and word.strip_edges().replace(" ", "").to_upper() == str(p.code).to_upper()

## The result of a right word at code spot [param p], like tap() on success.
static func code_result(p: Dictionary) -> Dictionary:
	return {"lines": _strings(p.get("lines", [])), "item": str(p.get("item", "")), "count": int(p.get("count", 0)),
		"flag": spot_flag(p), "code": false}

## Marks a finished tap: the spot's flag (one-time spots) and the found mark. The caller hands
## over the item (Overworld._action_give_item). True when the tap finished the spot.
static func grant(p: Dictionary, res: Dictionary, flags: Dictionary, records: Dictionary) -> bool:
	if res.is_empty() or str(res.get("flag", "")).is_empty():
		return false
	if not bool(p.get("repeat", false)):
		flags[str(res.flag)] = true
	note_found(str(p.id), records)
	return true

static func _strings(a: Array) -> Array[String]:
	var out: Array[String] = []
	for x: Variant in a:
		out.append(str(x))
	return out

# --- Knack: the favourite sky --------------------------------------------------------------

## The favourite sky of [param s] (clear, rain, fog, wind, storm), fixed by its uid.
static func knack(s: Spirling) -> String:
	var skies: Array = data().get("knack", {}).get("skies", WeatherCycle.KINDS)
	var key: String = s.uid if not s.uid.is_empty() else "%s|%s" % [s.data.species_name, str(s.spark)]
	return str(skies[posmod(hash("knack|" + key), skies.size())])

## What the Star Well says about each Spirling of [param party], in vague words.
static func knack_lines(party: Array) -> Array[String]:
	var words: Dictionary = data().get("knack", {}).get("words", {})
	var out: Array[String] = []
	for s: Spirling in party:
		out.append(Loc.t(str(words.get(knack(s), ""))) % s.display_name())
	return out

## After a won world battle under sky [param weather]: each Spirling that fought and loves that
## sky gains a little Kinship. Returns how many did.
static func after_battle(fought: Array, weather: String, won: bool) -> int:
	if not won:
		return 0
	var n: int = 0
	for s: Spirling in fought:
		if s != null and not s.is_fainted() and knack(s) == weather:
			Kinship.add(s, int(data().get("knack", {}).get("kinship", 1)))
			n += 1
	return n

# --- Dated easter eggs ---------------------------------------------------------------------

## The line of a dated easter egg for today, once per year, or "" (records "hm_date_<id>").
static func start_note(records: Dictionary, unix: int) -> String:
	var day: int = berlin_day(unix)
	var key: String = date_key(day)
	var year: int = int(Time.get_datetime_dict_from_unix_time(day * 86400).year)
	for d: Dictionary in data().get("dates", []):
		if str(d.date) != key:
			continue
		var rec: String = "hm_date_" + str(d.id)
		if int(records.get(rec, 0)) == year:
			return ""
		records[rec] = year
		note_found(str(d.id), records)
		return str(d.line)
	return ""
