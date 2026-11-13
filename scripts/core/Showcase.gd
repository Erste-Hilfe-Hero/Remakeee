class_name Showcase
extends RefCounted
## The Showcase (era function "showcase", opens in Era III): a small stage show in Ledgerholm,
## no battle. The day picks a theme (Grace, Might, Poise or Wit, each one stat). The Wayfarer
## shows one Spirling for "rounds" rounds and picks one of its arts each round. Appeal of a round:
## the theme stat / 4, plus own_element for an art of its own element, plus status_art for a
## status art, plus kinship / kinship_div; the same art twice in a row counts repeat_mult.
## Three rivals score the player's best possible total times their spread. Prizes by place.
## Tuning in data/era_activities.json "showcase".

const FEATURE: String = "showcase"
const BEST: String = "showcase_best"

static func data() -> Dictionary:
	return EraActivities.section("showcase")

static func rounds() -> int:
	return maxi(1, int(data().get("rounds", 3)))

## Theme id of [param day] ("2026-11-12"): the same for everyone on a day.
static func theme_for(day: String) -> String:
	var ids: Array = (data().get("themes", {}) as Dictionary).keys()
	ids.sort()
	return str(ids[absi(hash(day)) % ids.size()]) if not ids.is_empty() else ""

static func theme_label(theme: String) -> String:
	return str((data().get("themes", {}) as Dictionary).get(theme, {}).get("label", theme))

static func _stat(s: Spirling, theme: String) -> int:
	match str((data().get("themes", {}) as Dictionary).get(theme, {}).get("stat", "")):
		"atk": return s.atk()
		"def": return s.def()
		"foc": return s.foc()
		"spd": return s.spd()
	return 0

## Appeal of one round: [param mv] shown by [param s] under [param theme], [param last] the art
## of the round before (or null).
static func appeal(s: Spirling, theme: String, mv: MoveData, last: MoveData = null) -> int:
	var a: float = _stat(s, theme) / 4.0
	if mv.element in s.elements():
		a += float(data().get("own_element", 6))
	if mv.kind == MoveData.Kind.STATUS:
		a += float(data().get("status_art", 4))
	a += s.kinship / maxf(1.0, float(data().get("kinship_div", 10)))
	if last != null and last == mv:
		a *= float(data().get("repeat_mult", 0.5))
	return roundi(a)

## The best total [param s] can reach (never repeating an art when it has two or more).
static func best_total(s: Spirling, theme: String) -> int:
	var best: Array[int] = []
	for mv: MoveData in s.moves:
		best.append(appeal(s, theme, mv))
	best.sort()
	best.reverse()
	if best.is_empty():
		return 0
	var total: int = 0
	for r: int in rounds():
		total += best[r % mini(2, best.size())] if best.size() > 1 else (best[0] if r == 0 else roundi(best[0] * float(data().get("repeat_mult", 0.5))))
	return total

## Rival totals for a show of [param s]: its best total times each spread.
static func rivals(s: Spirling, theme: String) -> Array[int]:
	var base: int = best_total(s, theme)
	var out: Array[int] = []
	for f: Variant in data().get("rival_spread", [0.7, 0.85, 0.97]):
		out.append(roundi(base * float(f)))
	return out

## Place 1..4 of [param total] against [param rival_totals] (ties go to the Wayfarer).
static func place(total: int, rival_totals: Array[int]) -> int:
	var p: int = 1
	for r: int in rival_totals:
		if r > total:
			p += 1
	return p

static func prize(place_won: int) -> int:
	var prizes: Array = data().get("prizes", [])
	return int(prizes[place_won - 1]) if place_won >= 1 and place_won <= prizes.size() else 0

## Keeps the best place in [param records] (1 is best). Returns true for a new best.
static func note(records: Dictionary, place_won: int) -> bool:
	var old: int = int(records.get(BEST, 99))
	if place_won < old:
		records[BEST] = place_won
		return true
	return false
