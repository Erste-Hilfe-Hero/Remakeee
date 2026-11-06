class_name Season
extends RefCounted
## Seasonal festivals (item 89), read from the device calendar. Nothing is downloaded and
## nothing is missed for good: each festival comes back every year. During a festival, wild
## Spirlings of its elements show up more often, and the crier in Brindlewick hands out one
## gift per festival per year.

## Weight factor for boosted species in encounter rolls (normal weight x2, boosted x3).
const BOOST_NUM: int = 3
const BOOST_DEN: int = 2

## Festival data lives in data/events.json ("festivals"), so new festivals need no code change.
## Elements there are Elements.E names; festivals() turns them into Elements.E values.
const DATA_PATH: String = "res://data/events.json"
static var _festivals: Array[Dictionary] = []

static func festivals() -> Array[Dictionary]:
	if _festivals.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f == null:
			return _festivals
		var d: Variant = JSON.parse_string(f.get_as_text())
		if not d is Dictionary:
			return _festivals
		for v: Variant in (d as Dictionary).get("festivals", []):
			if not v is Dictionary:
				continue
			var fest: Dictionary = (v as Dictionary).duplicate(true)
			var els: Array[int] = []
			for e: Variant in fest.get("elements", []):
				els.append(int(Elements.E.get(str(e), 0)))
			fest["elements"] = els
			var months: Array[int] = []
			for m: Variant in fest.get("months", []):
				months.append(int(m))
			fest["months"] = months
			_festivals.append(fest)
	return _festivals

## The festival running in [param month] (1-12), or {} outside festival months.
static func for_month(month: int) -> Dictionary:
	for f: Dictionary in festivals():
		if month in (f.months as Array):
			return f
	return {}

static func current() -> Dictionary:
	return for_month(int(Online.date_now().month))

## Elements boosted by [param festival] (empty outside festivals).
static func boosted(festival: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for e: Variant in festival.get("elements", []):
		out.append(int(e))
	return out

## The next festival after [param month] (for the crier between festivals).
static func next_after(month: int) -> Dictionary:
	for i: int in range(1, 13):
		var f: Dictionary = for_month((month - 1 + i) % 12 + 1)
		if not f.is_empty():
			return f
	return {}

## The year a festival running in [param month] of [param year] started (Hearth Weeks run over New Year).
static func festival_year(month: int, year: int) -> int:
	return year - 1 if month == 1 else year

## The crier's gift of [param festival] in [param year]: one of its "gifts" list, changing each
## year (plan 3221); "gift" when there is no list.
static func gift_for(festival: Dictionary, year: int) -> String:
	var gifts: Array = festival.get("gifts", [])
	if gifts.is_empty():
		return str(festival.get("gift", ""))
	return str(gifts[posmod(year, gifts.size())])

const MONTH_NAMES: Array[String] = ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]

## Between festivals (plan 3223): "Next up: the Bloom Fair, from April, with Bloom & Gale Spirlings."
static func next_line(month: int) -> String:
	var nxt: Dictionary = next_after(month)
	if nxt.is_empty():
		return ""
	var start: int = int((nxt.months as Array)[0])
	return Loc.t("No festival right now. Next up: the %s, from %s, with %s Spirlings.") % [Loc.t(str(nxt.name)),
		Loc.t(MONTH_NAMES[start - 1]), " & ".join(Festival.element_names(nxt))]

## Flag that marks this year's gift of [param festival] as taken.
static func gift_flag(festival: Dictionary, year: int) -> String:
	return "season_%s_%d" % [festival.get("id", ""), year]
