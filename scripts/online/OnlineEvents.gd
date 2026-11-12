class_name OnlineEvents
extends RefCounted
## Timed online events (Online 100, area 7): rules shared by the game and LocalBackend. The server
## does the same in 20261112000060_bund_events.sql from server_config.online_events.
## Kinds: festival (shared goal fed by world-goal steps, tiers in percent of the target), board
## (confirmed Rift wins after entering a team that fits the rules) and sighting (some Spirlings
## appear more often).

const CONFIG_PATH: String = "res://data/online_events.json"
const KINDS: Array[String] = ["festival", "board", "sighting"]
const TITLES: Dictionary = {"first": "Champion of %s", "top10": "Top ten of %s", "top_tenth": "Best tenth of %s",
	"took_part": "Took part in %s"}

## The newest event list the game fetched (event_list), for sighting days and the menu.
static var cached: Array = []
static var cached_at: int = 0

static func config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

## The ISO week number of the week key "2026-W46".
static func week_number(week_key: String) -> int:
	return int(week_key.split("-W")[1]) if week_key.contains("-W") else 0

## Monday 00:00 UTC of the week that holds [param unix].
static func week_start(unix: int) -> int:
	var day: int = unix - posmod(unix, 86400)
	var wd: int = int(Time.get_date_dict_from_unix_time(day).weekday)
	return day - (6 if wd == 0 else wd - 1) * 86400

## Id of the weekly event of the week starting [param start] ("week-2026-w46").
static func week_id(start: int) -> String:
	return "week-" + WeeklyChallenge.week_key(start).to_lower()

## The rotation entry for the week starting [param start] (by ISO week number, like the world goal).
static func weekly_template(rot: Array, start: int) -> Dictionary:
	if rot.is_empty():
		return {}
	return rot[week_number(WeeklyChallenge.week_key(start)) % rot.size()]

## Stage of a species along its unfold line: 1 for a first form.
static func stage_of(sd: SpirlingData) -> int:
	var n: int = 1
	var cur: SpirlingData = Database.earlier_form(sd)
	while cur != null and n < 10:
		n += 1
		cur = Database.earlier_form(cur)
	return n

## Whether species [param sd] fits event rules: any of "elements" (when given, by name such as
## "EMBER") and at most "max_stage" steps along its line.
static func fits(sd: SpirlingData, rules: Dictionary) -> bool:
	if sd == null:
		return false
	var els: Array = rules.get("elements", []) if rules.get("elements") is Array else []
	if not els.is_empty() and not sd.elements.any(func(e: int) -> bool: return Elements.E.keys()[e] in els):
		return false
	if rules.has("max_stage") and stage_of(sd) > int(rules.max_stage):
		return false
	return true

## Names of every species that fits [param rules] (tools/online/game_data_sql.py writes the same
## list as "allowed" for the server).
static func allowed(rules: Dictionary) -> Array:
	Database.load_all()
	var out: Array = []
	for n: String in Database.spirlings:
		if fits(Database.spirlings[n], rules):
			out.append(n)
	return out

## Why team [param names] cannot enter: "bad_team" (1-6 different known species), "rules", or "".
static func team_error(names: Array, rules: Dictionary) -> String:
	if names.is_empty() or names.size() > 6:
		return "bad_team"
	var seen: Dictionary = {}
	for n: Variant in names:
		var sd: SpirlingData = Database.species(str(n))
		if sd == null or seen.has(str(n)):
			return "bad_team"
		seen[str(n)] = true
	for n: Variant in names:
		if not fits(Database.species(str(n)), rules):
			return "rules"
	return ""

## upcoming, running or ended at [param now].
static func state_of(ev: Dictionary, now: int) -> String:
	if now < int(ev.get("starts", 0)):
		return "upcoming"
	return "running" if now < int(ev.get("ends", 0)) else "ended"

## Whether a festival with [param total] of [param target] reached [param pct] percent.
static func tier_reached(total: int, target: int, pct: int) -> bool:
	return total * 100 >= target * pct

## How many of [param tiers] (percent list) a festival reached.
static func tiers_reached(total: int, target: int, tiers: Array) -> int:
	var n: int = 0
	for p: Variant in tiers:
		n += 1 if tier_reached(total, target, int(p)) else 0
	return n

## The first title bracket that rank [param rank] of [param players] reaches, or "".
static func title_for(rank: int, players: int, titles: Array) -> String:
	for t: Dictionary in titles:
		if (t.has("rank") and rank <= int(t.rank)) or (t.has("pct") and rank * 100 <= int(t.pct) * players):
			return str(t.id)
	return ""

## Shown name of an event: its name in the player's language, else a name from its kind.
static func name_of(ev: Dictionary) -> String:
	var n: Variant = ev.get("name")
	if n is Dictionary or (n is String and not (n as String).is_empty()):
		return LiveContent.localized(n)
	match str(ev.get("kind", "")):
		"festival": return Loc.t("Festival")
		"board": return Loc.t("Rule week")
	return Loc.t("Sighting day")

static func title_text(title: String, event_name: String) -> String:
	return Loc.t(str(TITLES.get(title, "Took part in %s"))) % event_name

## Weight factor for wild [param species] from running sighting days in [member cached].
static func sighting_boost(species: String, now: int = -1) -> int:
	if cached.is_empty():
		return 1
	var t: int = now if now >= 0 else Online.unix_now()
	var best: int = 1
	for ev: Variant in cached:
		if ev is Dictionary and str(ev.get("kind", "")) == "sighting" and state_of(ev, t) == "running" \
				and (ev.get("species", []) as Array).has(species):
			best = maxi(best, clampi(int(ev.get("boost", 1)), 1, 10))
	return best

## Fetches the calendar into [member cached]; keeps the old list when that fails.
static func refresh() -> Dictionary:
	var r: Dictionary = await Online.call_fn("event_list")
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		cached = r.data.get("events", []) if r.data.get("events") is Array else []
		cached_at = int(r.data.get("now", 0))
	return r
