class_name Exchange
extends RefCounted
## Marla's exchange stand in the lighthouse (plan area 8): items for Waymarks only, never coins
## or real money. Offers and weekly stock come from data/endgame.json. The stand opens with the
## base offers once the first Rift is mended and shows everything after Act I. Stock refills
## every Monday by the server clock (ISO week, like the weekly challenge).

const DATA_PATH: String = "res://data/endgame.json"
## Act I ends when Aldo has heard about the dock (quest "home" done).
const ACT1_FLAG: String = "aldo_dock_told"

static var _offers: Array[Dictionary] = []

static func all_offers() -> Array[Dictionary]:
	if _offers.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for o: Variant in (d as Dictionary).get("exchange", []):
					if o is Dictionary:
						_offers.append(o)
	return _offers

static func is_open() -> bool:
	return not GameState.rifts_sealed.is_empty()

static func full_unlocked() -> bool:
	return GameState.has_flag(ACT1_FLAG)

## Offers the save can see right now (base, plus full after Act I).
static func offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_open():
		return out
	for o: Dictionary in all_offers():
		if str(o.get("tier", "base")) == "base" or full_unlocked():
			out.append(o)
	return out

static func week() -> String:
	return WeeklyChallenge.this_week()

## This week's purchases: item id -> count (empty in a new week).
static func _bought() -> Dictionary:
	var rec: Dictionary = GameState.records.get("exchange", {})
	if str(rec.get("week", "")) != week():
		return {}
	return rec.get("bought", {})

static func left(o: Dictionary) -> int:
	return maxi(0, int(o.stock) - int(_bought().get(str(o.item), 0)))

static func find(item_id: String) -> Dictionary:
	for o: Dictionary in offers():
		if str(o.item) == item_id:
			return o
	return {}

## Trades Waymarks for [param item_id]. Returns "" on success, else the reason (shown as is).
static func buy(item_id: String) -> String:
	var o: Dictionary = find(item_id)
	if o.is_empty():
		return "Marla doesn't have that right now."
	if left(o) <= 0:
		return "Sold out for this week. Marla restocks on Monday."
	if not Waymarks.spend(int(o.price)):
		return "Not enough Waymarks."
	var bought: Dictionary = _bought().duplicate()
	bought[item_id] = int(bought.get(item_id, 0)) + 1
	GameState.records["exchange"] = {"week": week(), "bought": bought}
	GameState.add_item(item_id)
	return ""

## Menu line: "Spark Charm  120" or "... (sold out)".
static func label(o: Dictionary) -> String:
	var nm: String = Loc.t(str(Database.item(str(o.item)).get("name", o.item)))
	if left(o) <= 0:
		return Loc.t("%s  sold out") % nm
	return "%s  %s%d" % [nm, Waymarks.GLYPH, int(o.price)]

## The card shown before a trade: effect, price, how many the player owns and stock left.
static func describe(o: Dictionary) -> String:
	var it: Dictionary = Database.item(str(o.item))
	return "%s\n%s\n\n%s\n%s\n%s" % [
		Loc.t(str(it.get("name", o.item))),
		Loc.t(str(it.get("description", ""))),
		Loc.t("Price: %d Waymarks (you have %d)") % [int(o.price), GameState.waymarks],
		Loc.t("In your satchel: %d") % GameState.item_count(str(o.item)),
		Loc.t("Left this week: %d of %d") % [left(o), int(o.stock)]]
