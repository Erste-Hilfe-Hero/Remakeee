class_name Exchange
extends RefCounted
## Marla's exchange stand in the lighthouse (plan area 8): items for Waymarks only, never coins
## or real money. Offers and weekly stock come from data/endgame.json. The stand opens with the
## base offers once the first Rift is mended and shows everything after Act I. Stock refills
## every Monday by the server clock (ISO week, like the weekly challenge).

const DATA_PATH: String = "res://data/endgame.json"
## Act I ends when Aldo has heard about the dock (quest "home" done).
const ACT1_FLAG: String = "aldo_dock_told"

## Offers of the week (plan 3141): WEEKLY_PICKS of the open list exchange_weekly.
const WEEKLY_PICKS: int = 3

static var _offers: Array[Dictionary] = []
static var _weekly: Array[Dictionary] = []

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

## The whole open list of possible weekly offers (plan 3142), in data order.
static func weekly_list() -> Array[Dictionary]:
	if _weekly.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for o: Variant in (d as Dictionary).get("exchange_weekly", []):
					if o is Dictionary:
						var e: Dictionary = (o as Dictionary).duplicate()
						e["weekly"] = true
						_weekly.append(e)
	return _weekly

## The WEEKLY_PICKS offers of week [param wk] ("2026-W45"), the same for every player.
static func weekly_for(wk: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = weekly_list().duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-stand-" + wk)
	var out: Array[Dictionary] = []
	while out.size() < WEEKLY_PICKS and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out

## Whole days until the Monday restock by the server clock (1 to 7).
static func days_to_restock() -> int:
	var now: int = Online.unix_now()
	var wd: int = int(Time.get_datetime_dict_from_unix_time(now).weekday)
	if wd == 0:
		wd = 7
	var midnight: int = now - now % 86400
	var next_monday: int = midnight + (8 - wd) * 86400
	return maxi(1, ceili(float(next_monday - now) / 86400.0))

static func restock_line() -> String:
	var n: int = days_to_restock()
	return Loc.t("Restock on Monday, in 1 day.") if n == 1 else Loc.t("Restock on Monday, in %d days.") % n

## Screen text with the whole weekly list; this week's picks are marked.
static func weekly_list_text() -> String:
	var now: Array[String] = []
	for o: Dictionary in weekly_for(week()):
		now.append(str(o.item))
	var out: PackedStringArray = [Loc.t("Marla's weekly crates: three of these each week, the same for everyone.")]
	for o: Dictionary in weekly_list():
		out.append("%s %s  %s%d  x%d" % ["[x]" if str(o.item) in now else "[ ]", Loc.t(str(Database.item(str(o.item)).get("name", o.item))), Waymarks.GLYPH, int(o.price), int(o.stock)])
	out.append(restock_line())
	return "\n".join(out)

## Savings goal (plan 3126): an offer of the stand, shown as a bar of what is still missing.
static func goal() -> Dictionary:
	var id: String = str(GameState.records.get("exchange_goal", ""))
	if id == "":
		return {}
	for o: Dictionary in all_offers() + weekly_list():
		if str(o.item) == id:
			return o
	return {}

static func set_goal(item_id: String) -> void:
	GameState.records["exchange_goal"] = item_id

static func goal_line() -> String:
	var o: Dictionary = goal()
	if o.is_empty():
		return ""
	var price: int = maxi(1, int(o.price))
	var have: int = mini(GameState.waymarks, price)
	var filled: int = have * 10 / price
	var nm: String = Loc.t(str(Database.item(str(o.item)).get("name", o.item)))
	if have >= price:
		return Loc.t("Savings goal %s: ready to trade at Marla's stand.") % nm
	return Loc.t("Savings goal %s: [%s] %d more Waymarks") % [nm, "#".repeat(filled) + "-".repeat(10 - filled), price - have]

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
	if full_unlocked():
		out.append_array(weekly_for(week()))
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
	GameState.records["count_trade"] = int(GameState.records.get("count_trade", 0)) + 1
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
	return "%s\n%s\n\n%s\n%s\n%s\n%s" % [
		Loc.t(str(it.get("name", o.item))),
		Loc.t(str(it.get("description", ""))),
		Loc.t("Price: %d Waymarks (you have %d)") % [int(o.price), GameState.waymarks],
		Loc.t("In your satchel: %d") % GameState.item_count(str(o.item)),
		Loc.t("Left this week: %d of %d") % [left(o), int(o.stock)], restock_line()]
