class_name DailyBoard
extends RefCounted
## The daily card (Chimora 1.3.2, Ali): what one day brings, from data/daily.json. Everything is
## rolled from the local calendar date (DailyFind.today_key), so the game offline and online agree,
## and lives in GameState.records, so it travels with the (server) save.
## - Welcome gift: a 7-step cycle, one step per day the game is opened. A missed day costs
##   nothing: the cycle only moves on when a gift is taken, there is no streak and no clock.
##   Step 7 is the big one. The server pays the Riftglass part by the same steps (gift_rg).
## - Spirling of the day: one kind from the maps the save has reached, with where to find it; it
##   steps out featured_mult times as often there today. Bonding is unchanged.
## - Weekend weather: on Saturday and Sunday a special sky (a WeatherCycle kind) lies over a few
##   outdoor maps and some shy kinds there step out more often. Friday's card tells it ahead.

const PATH: String = "res://data/daily.json"
const GIFT_RECORD: String = "login_gift"
const CARD_RECORD: String = "daily_card"

static var _data: Dictionary = {}
static var _weekend_cache: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

static func today() -> String:
	return DailyFind.today_key()

# --- Dates ----------------------------------------------------------------------------------

## 0 Sunday .. 6 Saturday for the day key "YYYY-MM-DD".
static func weekday(day: String) -> int:
	return int(Time.get_date_dict_from_unix_time(Time.get_unix_time_from_datetime_string(day + "T12:00:00")).weekday)

static func next_day(day: String) -> String:
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(day + "T12:00:00") + 86400)

## The local day key at [param unix] (the same local calendar as Online.date_now).
static func local_day(unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(unix + bias)

# --- Welcome gift ---------------------------------------------------------------------------

static func gifts() -> Array:
	return data().get("gift", [])

static func _gift_state() -> Dictionary:
	var st: Variant = GameState.records.get(GIFT_RECORD, {})
	return st if st is Dictionary else {}

## Gifts taken so far (all time; it never goes down).
static func gifts_taken() -> int:
	return maxi(0, int(_gift_state().get("taken", 0)))

## Index (0..6) of the gift the next opening day brings.
static func gift_step() -> int:
	var n: int = gifts().size()
	return gifts_taken() % n if n > 0 else 0

static func gift_taken_on(day: String) -> bool:
	return str(_gift_state().get("day", "")) == day

## True when [param day] still has its gift: not taken today and the clock was not turned back.
static func gift_open(day: String) -> bool:
	if gifts().is_empty():
		return false
	var last: String = str(_gift_state().get("day", ""))
	return last != day and not GameState.time_went_back(last, day)

## "Tonic x2", "200 coins", "Spring Flask x1, 500 coins" for gift [param step].
static func gift_text(step: int) -> String:
	var all: Array = gifts()
	if all.is_empty():
		return ""
	var g: Dictionary = all[posmod(step, all.size())]
	var parts: PackedStringArray = []
	var item: String = str(g.get("item", ""))
	if item != "":
		parts.append("%s x%d" % [Loc.t(str(Database.item(item).get("name", item))), int(g.get("count", 1))])
	if int(g.get("coins", 0)) > 0:
		parts.append(Loc.t("%d coins") % int(g.coins))
	return ", ".join(parts)

## Gives the gift of [param day] once. Returns the lines to show, [] if nothing was due.
static func take_gift(day: String = "") -> Array[String]:
	if day.is_empty():
		day = today()
	var out: Array[String] = []
	if not gift_open(day):
		return out
	var step: int = gift_step()
	var g: Dictionary = gifts()[step]
	var item: String = str(g.get("item", ""))
	if item != "" and Database.items.has(item):
		GameState.add_item(item, maxi(1, int(g.get("count", 1))))
	GameState.money += maxi(0, int(g.get("coins", 0)))
	GameState.records[GIFT_RECORD] = {"day": day, "taken": gifts_taken() + 1}
	out.append(Loc.t("Welcome gift, day %d of 7: %s") % [step + 1, gift_text(step)])
	return out

## Riftglass the server gives on gift step [param step] (data "gift_rg"; the server's own count).
static func gift_rg(step: int) -> int:
	var rg: Array = data().get("gift_rg", [])
	return int(rg[posmod(step, rg.size())]) if not rg.is_empty() else 0

# --- Spirling of the day --------------------------------------------------------------------

## Kinds living on the reached maps [param maps], sorted.
static func meetable(maps: Array[String]) -> Array[String]:
	var tables: Array[String] = EncounterTable.table_ids()
	var out: Array[String] = []
	for m: String in maps:
		if not m in tables:
			continue
		for sp: String in EncounterTable.species_on(m):
			if not sp in out and Database.species(sp) != null:
				out.append(sp)
	out.sort()
	return out

## The Spirling of [param day] among the kinds of [param maps], "" when none lives there.
static func pick_featured(day: String, maps: Array[String]) -> String:
	var kinds: Array[String] = meetable(maps)
	if kinds.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-featured-" + day)
	return kinds[rng.randi_range(0, kinds.size() - 1)]

static func _card_state() -> Dictionary:
	var st: Variant = GameState.records.get(CARD_RECORD, {})
	return st if st is Dictionary else {}

## Today's Spirling, fixed for the whole day once it was drawn (a new place reached at noon does
## not change it).
static func featured(day: String = "") -> String:
	if day.is_empty():
		day = today()
	var st: Dictionary = _card_state()
	if str(st.get("day", "")) == day and st.has("featured"):
		return str(st.featured)
	var sp: String = pick_featured(day, DailyTasks.reached_maps())
	st = {"day": day, "featured": sp, "shown": str(st.get("day", "")) == day and bool(st.get("shown", false))}
	GameState.records[CARD_RECORD] = st
	return sp

## Reached maps where [param species] lives.
static func featured_places(species: String) -> Array[String]:
	var out: Array[String] = []
	var tables: Array[String] = EncounterTable.table_ids()
	for m: String in DailyTasks.reached_maps():
		if m in tables and species in EncounterTable.species_on(m) and not m in out:
			out.append(m)
	out.sort()
	return out

static func featured_mult() -> int:
	return maxi(1, int(data().get("featured_mult", 1)))

static func featured_line(day: String = "") -> String:
	var sp: String = featured(day)
	if sp.is_empty():
		return ""
	var places: PackedStringArray = []
	for m: String in featured_places(sp).slice(0, 2):
		places.append(Loc.t(Spirling.place_name(m)))
	if places.is_empty():
		return Loc.f("Spirling of the day: %s", [Loc.t(sp)])
	return Loc.f("Spirling of the day: %s. It steps out more often today in %s.", [Loc.t(sp), Loc.t(" and ").join(places)])

# --- Weekend weather ------------------------------------------------------------------------

static func is_weekend(day: String) -> bool:
	var wd: int = weekday(day)
	return wd == 0 or wd == 6

## The weekend events of [param day]: drawn from the Saturday's date, [] on weekdays.
static func weekend_events(day: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_weekend(day):
		return out
	var sat: String = day if weekday(day) == 6 else WorldEvents.previous_day(day)
	if _weekend_cache.has(sat):
		return _weekend_cache[sat]
	var cfg: Dictionary = data().get("weekend", {})
	var pool: Array = (cfg.get("events", []) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-weekend-" + sat)
	while out.size() < int(cfg.get("per_weekend", 1)) and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	_weekend_cache[sat] = out
	return out

## The weekend sky over map [param map_id] on [param day], "" when there is none.
static func weekend_kind(map_id: String, day: String) -> String:
	for e: Dictionary in weekend_events(day):
		if map_id in (e.get("maps", []) as Array):
			return str(e.kind)
	return ""

## Weight factors {species: mult} that the weekend lays on table [param table].
static func weekend_mults(table: String, day: String) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in weekend_events(day):
		if table in (e.get("maps", []) as Array):
			for sp: Variant in e.get("species", []):
				out[str(sp)] = maxi(1, int(e.get("mult", 1)))
	return out

static func _event_places(e: Dictionary) -> String:
	var places: PackedStringArray = []
	for m: Variant in e.get("maps", []):
		places.append(Loc.t(Spirling.place_name(str(m))))
	return Loc.t(" and ").join(places)

## Weekend lines for the card: on the weekend what lies where, on Friday what comes. No clocks.
static func weekend_lines(day: String) -> Array[String]:
	var out: Array[String] = []
	if is_weekend(day):
		for e: Dictionary in weekend_events(day):
			out.append(Loc.f("Weekend weather: %s over %s. Shy Spirlings step out more often there.", [Loc.t(str(e.name)), _event_places(e)]))
	elif weekday(day) == 5:
		for e: Dictionary in weekend_events(next_day(day)):
			out.append(Loc.f("This weekend: %s over %s.", [Loc.t(str(e.name)), _event_places(e)]))
	return out

# --- Encounters -----------------------------------------------------------------------------

## All weight factors of [param table] on [param day]: the swarm and kind of the week
## (WildRules.event_mults), the Spirling of the day and the weekend kinds, multiplied.
static func encounter_mults(table: String, day: String, featured_kind: String) -> Dictionary:
	var out: Dictionary = WildRules.event_mults(table, day)
	if featured_kind != "" and featured_kind in EncounterTable.species_on(table):
		out[featured_kind] = int(out.get(featured_kind, 1)) * featured_mult()
	var wk: Dictionary = weekend_mults(table, day)
	for sp: String in wk:
		out[sp] = int(out.get(sp, 1)) * int(wk[sp])
	return out

# --- The card -------------------------------------------------------------------------------

## True when today's card has not been shown yet (after the starter, once a day).
static func card_due(day: String = "") -> bool:
	if day.is_empty():
		day = today()
	# Not before the partner, and not in the opening: the first minutes have no popups (Opening).
	if not GameState.has_flag("got_starter") or Opening.active(GameState.flags):
		return false
	var st: Dictionary = _card_state()
	return not (str(st.get("day", "")) == day and bool(st.get("shown", false))) and not GameState.time_went_back(str(st.get("day", "")), day)

static func mark_shown(day: String = "") -> void:
	if day.is_empty():
		day = today()
	featured(day)
	var st: Dictionary = _card_state()
	st["shown"] = true
	GameState.records[CARD_RECORD] = st

## The card's text blocks for [param day], translated: {"gift_step", "gift", "gift_open",
## "featured", "tasks", "weekend"}.
static func card(day: String = "") -> Dictionary:
	if day.is_empty():
		day = today()
	var tasks: Array[String] = []
	for e: Dictionary in DailyTasks.today().get("tasks", []):
		var t: Dictionary = DailyTasks.def(str(e.id))
		var need: int = int(t.get("n", 1))
		tasks.append("%s %s %d/%d" % ["[x]" if DailyTasks.is_done(e) else "[ ]", Loc.t(str(t.get("text", e.id))), mini(int(e.get("n", 0)), need), need])
	var step: int = gift_step() if gift_open(day) else posmod(gift_step() - 1, maxi(1, gifts().size()))
	return {"gift_step": step, "gift": gift_text(step), "gift_open": gift_open(day),
		"featured": featured_line(day), "tasks": tasks, "weekend": weekend_lines(day)}
