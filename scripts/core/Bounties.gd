class_name Bounties
extends RefCounted
## Daily bounty fights (plan item 1117) and the 100 percent certificate (item 1120).
## The Fixer pins data/bounties.json "per_day" marks a day, the same for everyone. A mark can
## be claimed once a day; the Fixer skims fixer_cut. A snitch may tip the mark off: it comes
## tip_ring_bonus rings stronger and the price is multiplied by tip_price_mult.

const DATA_PATH: String = "res://data/bounties.json"
const CLAIMED: String = "bounty_claimed"
const DAY: String = "bounty_day"
const TOTAL: String = "bounties_done"
const CERT: String = "certificate"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

## The board of [param day] at ring [param cap]: Array of {id, name, crime, team, ring, price, tipped}.
static func board(day: String, cap: int) -> Array[Dictionary]:
	var d: Dictionary = data()
	var marks: Array = (d.get("marks", []) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-bounty-" + day)
	var offsets: Array = d.get("ring_offset", [0])
	var out: Array[Dictionary] = []
	for i: int in mini(int(d.get("per_day", 3)), marks.size()):
		var m: Dictionary = marks.pop_at(rng.randi_range(0, marks.size() - 1))
		var tipped: bool = rng.randf() < float(d.get("tip_chance", 0.0))
		var ring: int = cap + int(offsets[i % offsets.size()]) + (int(d.get("tip_ring_bonus", 0)) if tipped else 0)
		var price: int = int(m.get("price", 0)) * (int(d.get("tip_price_mult", 1)) if tipped else 1)
		out.append({"id": str(m.id), "name": str(m.name), "crime": str(m.crime), "team": m.get("team", []),
			"ring": clampi(ring, 2, Spirling.STORY_RING), "price": price, "tipped": tipped})
	return out

static func claimed(day: String) -> Array:
	if str(GameState.records.get(DAY, "")) != day:
		return []
	return GameState.records.get(CLAIMED, [])

## Pays a won bounty after the Fixer's cut. Returns the coins paid, 0 if already claimed or unknown.
static func claim(day: String, cap: int, id: String) -> int:
	if id in claimed(day):
		return 0
	for m: Dictionary in board(day, cap):
		if m.id == id:
			if str(GameState.records.get(DAY, "")) != day:
				GameState.records[DAY] = day
				GameState.records[CLAIMED] = []
			(GameState.records[CLAIMED] as Array).append(id)
			GameState.records[TOTAL] = int(GameState.records.get(TOTAL, 0)) + 1
			var paid: int = payout(int(m.price))
			GameState.money += paid
			return paid
	return 0

static func payout(price: int) -> int:
	return price - roundi(price * float(data().get("fixer_cut", 0.0)))

## Board line for one mark.
static func line(m: Dictionary) -> String:
	var s: String = Loc.t("WANTED: %s, ring %d, %d coins") % [Loc.t(str(m.name)), int(m.ring), int(m.price)]
	if bool(m.tipped):
		s += " " + Loc.t("(tipped off, watch your back)")
	return s

## The certificate (item 1120): lines once the journey reads 100 percent, else empty.
static func certificate(percent: int, player: String) -> Array[String]:
	if percent < 100:
		return []
	var out: Array[String] = [Loc.t("Certificate of Completion"), Loc.t("Issued to %s, who did everything.") % player]
	for l: Variant in data().get("certificate_lines", []):
		out.append(Loc.t(str(l)))
	GameState.records[CERT] = true
	return out
