class_name WeeklyGiant
extends RefCounted
## Weekly giant (plan item 1118): one swollen ancient Spirling per ISO week, the same for everyone,
## fought as a Rift boss. What counts is the share of its Vigor taken off in one battle; each
## tier reached pays Waymarks once per week. Kept in records["giant_week"] = {week, best, paid}.

const KEY: String = "giant_week"

static func data() -> Dictionary:
	return IdeasC.section("weekly_giant")

## {"species", "boss"} for [param week] such as "2026-W46".
static func giant(week: String) -> Dictionary:
	var all: Array = data().get("giants", [])
	return GameState.as_dict(all[absi(hash("chimora-giant-" + week)) % all.size()]) if not all.is_empty() else {}

static func foe(week: String, rng: RandomNumberGenerator) -> Array[Spirling]:
	return IdeasC.team([giant(week).get("species", "")], int(data().get("ring", 60)), rng)

static func record(week: String) -> Dictionary:
	var r: Dictionary = GameState.as_dict(GameState.records.get(KEY, {}))
	if str(r.get("week", "")) != week:
		return {"week": week, "best": 0, "paid": 0}
	return r.duplicate()

## Percent of Vigor taken off: 0 to 100.
static func share_pct(max_hp: int, hp_left: int) -> int:
	if max_hp <= 0:
		return 0
	return clampi(roundi(100.0 * float(max_hp - clampi(hp_left, 0, max_hp)) / float(max_hp)), 0, 100)

## Books a battle that took [param pct] percent. Returns the reward lines for newly reached tiers.
static func submit(week: String, pct: int) -> Array[String]:
	var r: Dictionary = record(week)
	r["best"] = maxi(int(r.best), clampi(pct, 0, 100))
	var out: Array[String] = []
	var tiers: Array = data().get("tiers", [])
	var paid: int = int(r.paid)
	while paid < tiers.size() and float(r.best) >= 100.0 * float(GameState.as_dict(tiers[paid]).get("share", 1.0)):
		out.append_array(Waymarks.reward_lines(Waymarks.earn(int(GameState.as_dict(tiers[paid]).get("waymarks", 0)), "weekly")))
		paid += 1
	r["paid"] = paid
	GameState.records[KEY] = r
	return out
