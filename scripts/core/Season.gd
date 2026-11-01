class_name Season
extends RefCounted
## Seasonal festivals (item 89), read from the device calendar. Nothing is downloaded and
## nothing is missed for good: each festival comes back every year. During a festival, wild
## Spirlings of its elements show up more often, and the crier in Brindlewick hands out one
## gift per festival per year.

## Weight factor for boosted species in encounter rolls (normal weight x2, boosted x3).
const BOOST_NUM: int = 3
const BOOST_DEN: int = 2

const FESTIVALS: Array[Dictionary] = [
	{"id": "bloom_fair", "months": [4, 5], "name": "Bloom Fair", "elements": [Elements.E.BLOOM, Elements.E.GALE], "gift": "bark_wrap",
		"text": "The Bloom Fair is on! Bloom and Gale Spirlings are out in the spring air."},
	{"id": "tide_days", "months": [7, 8], "name": "Tide Days", "elements": [Elements.E.TIDE, Elements.E.VOLT], "gift": "tide_pearl",
		"text": "It's the Tide Days! Tide and Volt Spirlings play in the summer storms."},
	{"id": "lantern_nights", "months": [10, 11], "name": "Lantern Nights", "elements": [Elements.E.LUMEN, Elements.E.UMBRA], "gift": "echo_lumen",
		"text": "The Lantern Nights have begun! Lumen and Umbra Spirlings follow the lights."},
	{"id": "hearth_weeks", "months": [12, 1], "name": "Hearth Weeks", "elements": [Elements.E.EMBER, Elements.E.STONE], "gift": "spark_charm",
		"text": "The Hearth Weeks are here! Ember and Stone Spirlings gather where it's warm."},
]

## The festival running in [param month] (1-12), or {} outside festival months.
static func for_month(month: int) -> Dictionary:
	for f: Dictionary in FESTIVALS:
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

## Flag that marks this year's gift of [param festival] as taken.
static func gift_flag(festival: Dictionary, year: int) -> String:
	return "season_%s_%d" % [festival.get("id", ""), year]
