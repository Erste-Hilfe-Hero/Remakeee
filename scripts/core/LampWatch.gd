class_name LampWatch
extends RefCounted
## The Lamp Watch (update "The Lamp Watch", docs/WORLD.md): once per calendar day the player
## lights the Brindlewick lighthouse lamp. Each lit night one lost Spirling follows the light and
## can be answered with the Echo call outside battle. Nights 1-7 are fixed (data/lamp_watch.json)
## and bring a page of Mirela's lamp log each; afterwards a visitor of the pool comes. Only lit
## nights count, a missed day costs nothing (no streak). Works offline: the day is the local date
## (DailyFind.today_key), and a day at or before the last lit one lights nothing (clock turned back).
## State: GameState.records["lamp_watch"] = {"nights", "last_day", "answered", "hinted"}.

const PATH: String = "res://data/lamp_watch.json"
const RECORD: String = "lamp_watch"
## Flags for the side goal (data/quests.json "lamp"): one per fixed night, and the end.
const NIGHT_FLAG: String = "lamp_night_%d"
const DONE_FLAG: String = "lamp_watch_done"
const STARTER_A: String = "@starter_a"
const STARTER_B: String = "@starter_b"
## Ring 60 is the top of every Spirling (AGENTS.md).
const RING_MAX: int = 60

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
	return _data

static func nights() -> Array:
	return data().get("nights", [])

static func fixed_nights() -> int:
	return nights().size()

static func state(records: Dictionary) -> Dictionary:
	return GameState.as_dict(records.get(RECORD, {}))

static func _put(records: Dictionary, st: Dictionary) -> void:
	records[RECORD] = st

static func unlocked(flags: Dictionary) -> bool:
	return bool(flags.get(str(data().get("unlock_flag", "aldo_gift")), false))

static func nights_lit(records: Dictionary) -> int:
	return int(state(records).get("nights", 0))

## True when the lamp can be lit on [param day]: never lit, or only on earlier days.
static func can_light(records: Dictionary, day: String) -> bool:
	var last: String = str(state(records).get("last_day", ""))
	return last.is_empty() or day > last

static func lit_today(records: Dictionary, day: String) -> bool:
	return str(state(records).get("last_day", "")) == day

## True while tonight's visitor still waits for an answer.
static func visitor_waiting(records: Dictionary, day: String) -> bool:
	return lit_today(records, day) and str(state(records).get("answered", "")) != day

## The two storm Spirlings the player did not pick, in data order.
static func other_starters(starter: String) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in data().get("starters", []):
		if str(s) != starter:
			out.append(str(s))
	return out

## Night [param n] (1-based): {"species", "nickname", "gleam", "lines", "log", "gift"}.
## Past the fixed nights the pool is walked in a seeded order by [param day].
static func night(n: int, starter: String, day: String) -> Dictionary:
	var list: Array = nights()
	if n >= 1 and n <= list.size():
		var d: Dictionary = list[n - 1]
		var sp: String = str(d.get("visitor", ""))
		var others: Array[String] = other_starters(starter)
		if sp == STARTER_A or sp == STARTER_B:
			var i: int = 0 if sp == STARTER_A else 1
			sp = others[i] if i < others.size() else str(data().get("pool", ["Wickit"])[0])
		return {"species": sp, "nickname": str(d.get("nickname", "")), "gleam": bool(d.get("gleam", false)),
			"lines": d.get("lines", []), "log": d.get("log", []), "gift": d.get("gift", [])}
	var pool: Array = data().get("pool", [])
	var gifts: Array = data().get("pool_gifts", [])
	if pool.is_empty():
		return {}
	var h: int = absi(("lamp-" + day).hash())
	return {"species": str(pool[h % pool.size()]), "nickname": "", "gleam": false,
		"lines": data().get("pool_lines", []), "log": [],
		"gift": gifts[h % gifts.size()] if not gifts.is_empty() else []}

## Lights the lamp on [param day]: counts the night, sets its flags and returns night(n), or {}
## when the lamp was lit already that day (or a later one).
static func light(records: Dictionary, flags: Dictionary, starter: String, day: String) -> Dictionary:
	if not can_light(records, day):
		return {}
	var st: Dictionary = state(records).duplicate()
	var n: int = int(st.get("nights", 0)) + 1
	st["nights"] = n
	st["last_day"] = day
	st["answered"] = ""
	_put(records, st)
	if n <= fixed_nights():
		flags[NIGHT_FLAG % n] = true
	if n >= fixed_nights():
		flags[DONE_FLAG] = true
	var out: Dictionary = night(n, starter, day)
	out["night"] = n
	return out

## Tonight's visitor was answered (it joined); it does not come back today.
static func answer(records: Dictionary, day: String) -> void:
	var st: Dictionary = state(records).duplicate()
	st["answered"] = day
	_put(records, st)

## Ring of a visitor: the best Ring in [param party] minus ring_below, at least ring_min.
static func visitor_ring(party: Array[Spirling]) -> int:
	var top: int = 0
	for s: Spirling in party:
		top = maxi(top, s.level)
	return clampi(top - int(data().get("ring_below", 1)), int(data().get("ring_min", 3)), RING_MAX)

## The Spirling of tonight's visit [param info] (from night/light), or null for an unknown kind.
static func make_visitor(info: Dictionary, party: Array[Spirling], rng: RandomNumberGenerator) -> Spirling:
	var sd: SpirlingData = Database.species(str(info.get("species", "")))
	if sd == null:
		return null
	var s := Spirling.new(sd, visitor_ring(party), rng)
	s.nickname = str(info.get("nickname", ""))
	s.gleam = bool(info.get("gleam", false))
	return s

## Echo call score from which a visitor stays.
static func pass_score() -> float:
	return float(data().get("pass", 0.5))

## The pages of Mirela's lamp log found so far, one page per lit fixed night.
static func log_pages(records: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var list: Array = nights()
	for i: int in mini(nights_lit(records), list.size()):
		var lines: Array[String] = []
		for l: Variant in (list[i] as Dictionary).get("log", []):
			lines.append(Loc.t(str(l)))
		out.append("\n".join(lines))
	return out

## The card text under the lamp picture.
static func card_text(records: Dictionary, day: String) -> String:
	var n: int = nights_lit(records)
	var out: Array[String] = [Loc.t("Lamp Watch"), Loc.t("Nights lit: %d") % n,
		Loc.t("Mirela's lamp log: %d/%d pages") % [mini(n, fixed_nights()), fixed_nights()]]
	if n == 1:
		out.append(Loc.t("One more storm Spirling is still out in the dark."))
	if n < fixed_nights():
		out.append(Loc.t("Pages still hidden behind the lens: %d") % (fixed_nights() - n))
	if visitor_waiting(records, day):
		out.append(Loc.t("A visitor waits by the lamp."))
	if lit_today(records, day):
		out.append(Loc.t("The lamp burns until morning. Light it again tomorrow."))
	else:
		out.append(Loc.t("Tonight the lamp is still dark."))
	return "\n".join(out)

## The note when a save is continued on a day the lamp is still dark (once per day), else "".
static func start_hint(flags: Dictionary, records: Dictionary, day: String) -> String:
	if not unlocked(flags) or not can_light(records, day) or str(state(records).get("hinted", "")) == day:
		return ""
	var st: Dictionary = state(records).duplicate()
	st["hinted"] = day
	_put(records, st)
	if nights_lit(records) == 0:
		return "Aldo's lamp waits up the lighthouse stairs. Lost Spirlings follow its light."
	return "The lighthouse lamp is dark tonight. Who will follow the light?"
