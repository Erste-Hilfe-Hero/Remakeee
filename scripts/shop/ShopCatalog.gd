class_name ShopCatalog
extends RefCounted
## Loads and checks data/shop.json, the only list of shop offers (docs/MONETIZATION.md).
## The server has the same offers (tools/shop/build_offers_sql.py writes them into a migration).
##
## Offer fields: id, kind (advantage | cosmetic | comfort | currency), tab, name, desc, rg_price
## (Riftglass, 0 = not for Riftglass), eur_cents (direct store price tier), store_type,
## product_id, grants, league_scope (open | none | look), duration, limit, requires, min_band, ready.
## Optional (pay-to-win step 7): badge (BADGES), discount_pct (true against single prices), featured,
## icon (res:// path), ends_at (ISO date), bonus_pct and first_buy_double (Riftglass tiers), rotation
## (daily and weekly deals, see deal_active).

const PATH: String = "res://data/shop.json"
const KINDS: Array[String] = ["advantage", "cosmetic", "comfort", "currency"]
## Shop tabs in menu order (item 4179).
const TABS: Array[String] = ["advantages", "packs", "pass", "looks", "riftglass"]
const TAB_NAMES: Dictionary = {"advantages": "Advantages", "packs": "Packs", "pass": "Pass", "looks": "Looks",
	"riftglass": "Riftglass"}
const STORE_TYPES: Array[String] = ["consumable", "non_consumable", "subscription"]
const LEAGUE_SCOPES: Array[String] = ["open", "none", "look"]
## "spirling" hands over one Spirling with fixed values (pay-to-win plan points 61-80, ShopEffects.bought_spirling).
## "card" is the Monthly Card: {"t": "card", "id": "monthly_card", "n": Riftglass per day, "days": 30}, paid by
## the server function shop_card_daily (step 7).
const GRANT_TYPES: Array[String] = ["rg", "item", "unlock", "coins", "pass", "choice", "spirling", "card"]
## Badges a shop row may carry. "hot" marks the rotating daily and weekly deals; "bestseller" needs real
## purchase counts, which the game does not collect, so no offer carries it yet.
const BADGES: Array[String] = ["bestseller", "best_value", "new", "limited", "hot"]
## Fields that would mean a random or chance-based content. No offer may have one (item 4021).
const RANDOM_FIELDS: Array[String] = ["chance", "chances", "odds", "random", "roll", "rolls", "weight", "weights", "draw",
	"draws", "pool", "gacha", "lootbox", "rarity_table", "w"]
## Fields that change values in battle. Cosmetics and comfort offers have none (items 4278, 4314).
const STAT_FIELDS: Array[String] = ["stats", "boost", "held", "teaches", "heal", "power", "mult", "bonus"]
## Store price tiers: whole euros minus one cent, up to 99,99 EUR (Apple and Google both have them).
const MAX_EUR_CENTS: int = 9999
## 100 Riftglass = 0,99 EUR (item 4221).
const EUR_CENTS_PER_100: int = 99

static var _data: Dictionary = {}
static var _offers: Array[Dictionary] = []
static var _by_id: Dictionary[String, Dictionary] = {}

static func load_all() -> void:
	if not _offers.is_empty():
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = raw if raw is Dictionary else {}
	for o: Variant in _data.get("offers", []):
		if o is Dictionary:
			_offers.append(o)
			_by_id[str(o.get("id", ""))] = o

## The whole shop.json (offers plus "advantage_values").
static func data() -> Dictionary:
	load_all()
	return _data

static func offers() -> Array[Dictionary]:
	load_all()
	return _offers

## Jacket colour ("4f7a3a") of the look offer that unlocks [param key] (item 4277), or "".
static func jacket_color(key: String) -> String:
	if key.is_empty():
		return ""
	var o: Dictionary = look_offer(key)
	return str(o.get("color", ""))

## The look offer whose only grant is the unlock [param key] ({} if none).
static func look_offer(key: String) -> Dictionary:
	for o: Dictionary in offers():
		var g: Array = o.get("grants", [])
		if str(o.get("tab", "")) == "looks" and g.size() == 1 and g[0] is Dictionary and str(g[0].get("id", "")) == key:
			return o
	return {}

static func offer(id: String) -> Dictionary:
	load_all()
	return _by_id.get(id, {})

static func by_product(product_id: String) -> Dictionary:
	for o: Dictionary in offers():
		if str(o.get("product_id", "")) == product_id:
			return o
	return {}

## Offers the shop shows in [param tab]: only those whose effect is built ("ready").
static func in_tab(tab: String, include_unready: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Dictionary in offers():
		if str(o.get("tab", "")) == tab and (include_unready or bool(o.get("ready", false))) and in_save_window(o):
			out.append(o)
	return out

## Offers that show only in the first days of a journey (200 list item 180), by offer id. Kept in
## the client, not in data/shop.json, because the server catalog does not know a save's start day.
const SAVE_DAYS: Dictionary = {"rg_starter": 7}

## True while [param o] may show: offers in [constant SAVE_DAYS] only in that many first days of the
## journey (GameState.start_day), checked on [param day] (today when -1). No days left are ever shown
## (no countdown). Without a journey running the offer stays.
static func save_days(o: Dictionary) -> int:
	return int(SAVE_DAYS.get(str(o.get("id", "")), 0))

static func in_save_window(o: Dictionary, day: int = -1) -> bool:
	var days: int = save_days(o)
	if days <= 0 or GameState.start_day <= 0:
		return true
	var d: int = GameState.today() if day < 0 else day
	return d - GameState.start_day < days

static func is_advantage(o: Dictionary) -> bool:
	return str(o.get("kind", "")) == "advantage"

## Euro value of a Riftglass amount in cents, rounded down to whole cents (item 4221).
static func euro_cents(rg: int) -> int:
	return int(floor(float(rg) * EUR_CENTS_PER_100 / 100.0))

## "≈ 2,97 €" for 300 Riftglass. Only a hint: real prices come from the store.
static func euro_hint(rg: int) -> String:
	return "≈ " + format_eur(euro_cents(rg))

## How each language writes a euro amount, as the stores write it on a phone in that language
## (CLDR): "%s" is the number. A language not listed writes "€0.99". One format per language, so
## a hint "(≈ 0,99 €)" and the store's "0,99 €" never stand side by side in two styles (French
## shop, 1.2.0 store shots).
const EUR_FORMATS: Dictionary[String, String] = {"de": "%s €", "fr": "%s €", "es": "%s €", "it": "%s €",
	"pt_BR": "€ %s", "nl": "€ %s", "pl": "%s €", "tr": "€%s", "ru": "%s €"}

## "2,97 €" (German), "€2.97" (English) and so on per EUR_FORMATS.
static func format_eur(cents: int, lang: String = "") -> String:
	var code: String = Loc.language() if lang.is_empty() else lang
	var num: String = "%d.%02d" % [cents / 100, absi(cents) % 100]
	if not EUR_FORMATS.has(code):
		return "€" + num
	return EUR_FORMATS[code] % num.replace(".", ",")

## "300 Riftglass (≈ 2,97 €)" (item 4180).
static func rg_text(rg: int) -> String:
	return Loc.t("%d Riftglass") % rg + " (" + euro_hint(rg) + ")"

## The grants of [param o] merged by what they give, in catalog order (Ali: "make clear what is
## inside"): {"t", "id", "n"} plus "species"/"level" for a Spirling. Items and Riftglass add up
## their amounts, repeated unlocks count tiers (the Seal Set's 7 power_seal = Power Seal VII),
## a pass adds up its days.
static func contents(o: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Dictionary = {}
	for g: Variant in o.get("grants", []):
		if not g is Dictionary:
			continue
		var t: String = str(g.get("t", ""))
		var n: int = int(g.get("days", 0)) if t == "pass" else (1 if t == "unlock" or t == "spirling" else int(g.get("n", 1)))
		if t == "card":
			out.append({"t": t, "id": str(g.get("id", "")), "n": n, "days": int(g.get("days", 0)), "offer": str(o.get("id", ""))})
			continue
		var key: String = t + ":" + str(g.get("id", g.get("species", "")))
		if at.has(key) and t != "spirling":
			out[at[key]].n = int(out[at[key]].n) + n
			continue
		at[key] = out.size()
		var e: Dictionary = {"t": t, "id": str(g.get("id", "")), "n": n, "offer": str(o.get("id", ""))}
		if t == "spirling":
			e["species"] = str(g.get("species", ""))
			e["level"] = int(g.get("level", 1))
		out.append(e)
	return out

## Offers whose only grant is the unlock [param key], in catalog order (tiers I, II, ...).
static func unlock_tiers(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Dictionary in offers():
		var g: Array = o.get("grants", [])
		if g.size() == 1 and g[0] is Dictionary and str(g[0].get("t", "")) == "unlock" and str(g[0].get("id", "")) == key:
			out.append(o)
	return out

## The offer that names unlock [param key] at tier [param n] ({} if no offer sells it alone).
static func unlock_offer(key: String, n: int) -> Dictionary:
	var tiers: Array[Dictionary] = unlock_tiers(key)
	if tiers.is_empty():
		return {}
	return tiers[clampi(n, 1, tiers.size()) - 1]

## Display name of an item id: the item's own name, else the offer of that id, else the id.
static func item_name(id: String) -> String:
	var it: Dictionary = Database.item(id)
	if not it.is_empty():
		return Loc.t(str(it.get("name", id)))
	return Loc.t(str(offer(id).get("name", id)))

## Name of one contents entry without its amount ("Ring Tonic", "Power Seal VII").
static func entry_name(e: Dictionary) -> String:
	match str(e.t):
		"item":
			return item_name(str(e.id))
		"unlock":
			# A tier offer (Power Seal III) names itself; a set names the tier its unlocks reach.
			var own: Dictionary = offer(str(e.get("offer", "")))
			var u: Dictionary = own if (own.get("grants", []) as Array).size() == 1 else unlock_offer(str(e.id), int(e.n))
			if not u.is_empty():
				return Loc.t(str(u.name))
			var i: int = FriendsMenu.GIFT_CARDS.keys().find(str(e.id).trim_prefix("gift_card_"))
			if str(e.id).begins_with("gift_card_") and i >= 0:
				return Loc.t(ShopMenu.GIFT_CARD_NAMES[i])
			return str(e.id)
		"choice":
			return Loc.t("Element Prism of your choice")
		"pass":
			return Loc.t("Wayfarer Pass for %d days") % int(e.n)
		"spirling":
			# Filled in first, then translated as a whole: ja, ko, tr and zh write it with {0} and {1}.
			return Loc.t("%s at Ring %d with the highest Spark in every value" % [str(e.species), int(e.level)])
		"card":
			return Loc.t("Monthly Card")
	return ""

## How many of an entry the player gets: tiered unlocks and the pass count as one.
static func entry_amount(e: Dictionary) -> int:
	if str(e.t) in ["pass", "card"] or (str(e.t) == "unlock" and unlock_tiers(str(e.id)).size() > 1):
		return 1
	return int(e.n)

## One contents entry as a line: "5x Ring Tonic", "300 Riftglass", "2000 coins".
static func entry_line(e: Dictionary) -> String:
	match str(e.t):
		"rg":
			return Loc.t("%d Riftglass") % int(e.n)
		"coins":
			return Loc.t("%d coins") % int(e.n)
		"card":
			return Loc.t("%d Riftglass every day for %d days") % [int(e.n), int(e.days)]
	return "%dx %s" % [entry_amount(e), entry_name(e)]

## Every contents entry as a line for the detail view, generated from the grants.
static func grant_lines(o: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in contents(o):
		out.append(entry_line(e))
	return out

## The short contents for a shop row: "5x Rift Breath, 5x Overcharge Core, 5x Glass Spark".
## Long sets show the first three and how many more.
static func contents_line(o: Dictionary) -> String:
	var lines: Array[String] = grant_lines(o)
	if lines.size() > 4:
		return ", ".join(lines.slice(0, 3)) + ", " + Loc.t("and %d more") % (lines.size() - 3)
	return ", ".join(lines)

## What one contents entry does, in plain words (the item's or the unlock's own text).
static func entry_effect(e: Dictionary, o: Dictionary) -> String:
	match str(e.t):
		"rg":
			return Loc.t("Shop currency to pay for offers.")
		"coins":
			return Loc.t("Money for the merchants in the world.")
		"card":
			return Loc.t("Collected in the shop once a day. Missed days wait for you.")
		"item":
			var it: Dictionary = Database.item(str(e.id))
			return Loc.t(str(it.get("description", offer(str(e.id)).get("desc", ""))))
		"unlock":
			var u: Dictionary = unlock_offer(str(e.id), int(e.n))
			return Loc.t(str(u.get("desc", o.get("desc", ""))))
		"choice":
			var names: Array[String] = []
			for id: Variant in o.get("choice", []):
				names.append(item_name(str(id)))
			return Loc.t("Choose one: %s") % ", ".join(names)
	return Loc.t(str(o.get("desc", "")))

## How long one contents entry lasts, in plain words.
static func entry_duration(e: Dictionary, o: Dictionary) -> String:
	match str(e.t):
		"rg", "coins":
			return Loc.t("yours until you spend it")
		"unlock", "spirling":
			return Loc.t("permanent")
		"card":
			return Loc.t("%d days") % int(e.days)
		"pass":
			return Loc.t("while the pass runs")
		"choice":
			var opts: Array = o.get("choice", [])
			return entry_duration({"t": "item", "id": str(opts[0]) if not opts.is_empty() else ""}, o)
	var d: String = str(offer(str(e.id)).get("duration", ""))
	if d.is_empty():
		d = "permanent" if Database.item(str(e.id)).has("held") or Database.item(str(e.id)).has("gear") else "once"
	match d:
		"permanent":
			return Loc.t("permanent")
		"once":
			return Loc.t("used up when used")
		"monthly":
			return Loc.t("while the pass runs")
	return Loc.t("%s from the moment you use it") % Loc.t(d)

## "Duration: permanent" when every part lasts the same, else "" (each part then shows its own).
static func duration_line(o: Dictionary) -> String:
	var seen: Array[String] = []
	for e: Dictionary in contents(o):
		var d: String = entry_duration(e, o)
		if not d in seen:
			seen.append(d)
	return Loc.t("Duration: %s") % seen[0] if seen.size() == 1 else ""

## Whether the offer can be bought again, as a plain rule (never a countdown, item 4042).
static func repeat_line(o: Dictionary) -> String:
	if str(o.get("store_type", "")) == "subscription":
		return Loc.t("Renews every month until you cancel.")
	var lim: Variant = o.get("limit")
	if lim is Dictionary:
		var n: int = int(lim.get("n", 1))
		if str(lim.get("per", "account")) == "week":
			return Loc.t("Once a week per account.") if n == 1 else Loc.t("Up to %d times a week per account.") % n
		return Loc.t("Once per account.") if n == 1 else Loc.t("Up to %d times per account.") % n
	var only_unlocks: bool = true
	for g: Variant in o.get("grants", []):
		if g is Dictionary and str(g.get("t", "")) != "unlock":
			only_unlocks = false
	if only_unlocks:
		return Loc.t("Buy once: it stays unlocked for good.")
	if str(o.get("store_type", "")) == "non_consumable":
		return Loc.t(StoreNames.pick(StoreNames.BUY_AGAIN))
	return Loc.t("Can be bought again any time.")

## The line under a shop row: short contents, then duration and whether it can be bought again.
static func row_hint(o: Dictionary) -> String:
	var d: String = duration_line(o)
	return contents_line(o) + "\n" + (d + ". " if not d.is_empty() else "") + repeat_line(o)

## The card of a coin merchant's item before buying (in-game shops): what you get, what it does,
## how long it lasts, that it can be bought again, the price and the coins you have.
static func merchant_card(item_id: String, price: int) -> String:
	var it: Dictionary = Database.item(item_id)
	var e: Dictionary = {"t": "item", "id": item_id, "n": 1}
	return "\n".join([item_name(item_id), "", Loc.t("Contents:"), "- " + entry_line(e), Loc.t(str(it.get("description", ""))), "",
		Loc.t("Duration: %s") % entry_duration(e, {}), Loc.t("Can be bought again any time."),
		Loc.t("Price: %d coins (you have %d)") % [price, GameState.money]])

## What a pack's contents cost one by one in Riftglass (item 4685): Riftglass counts as itself,
## each item as its own offer's Riftglass price, a choice as the first option's price.
## Riftglass price of the offer that sells only the unlock [param key] (0 if none does).
static func _unlock_price(key: String) -> int:
	for o: Dictionary in offers():
		var g: Array = o.get("grants", [])
		if g.size() == 1 and g[0] is Dictionary and str(g[0].get("t", "")) == "unlock" and str(g[0].get("id", "")) == key:
			return int(o.get("rg_price", 0))
	return 0

static func single_value(o: Dictionary) -> int:
	var v: int = 0
	var seen: Dictionary = {}
	for g: Variant in o.get("grants", []):
		if not g is Dictionary:
			continue
		match str(g.get("t", "")):
			"rg":
				v += int(g.n)
			"item":
				v += int(g.get("n", 1)) * int(offer(str(g.id)).get("rg_price", 0))
			"unlock":
				# Repeated unlocks of a tier row (the Seal Set) are worth the tiers they reach, one by one.
				var key: String = str(g.get("id", ""))
				var tiers: Array[Dictionary] = unlock_tiers(key)
				var k: int = int(seen.get(key, 0))
				seen[key] = k + 1
				v += int(tiers[k].get("rg_price", 0)) if k < tiers.size() else _unlock_price(key)
			"card":
				v += int(g.get("n", 0)) * int(g.get("days", 0))
			"choice":
				var opts: Variant = o.get("choice", [])
				if opts is Array and not (opts as Array).is_empty():
					v += int(g.get("n", 1)) * int(offer(str(opts[0])).get("rg_price", 0))
	return v

## --- Pay-to-win step 7 (27 Nov 2026): Riftglass bonus, first purchase double, deals. ---

## What the offer costs in Riftglass terms: its Riftglass price, or for a store-only offer its euro tier
## at 100 Riftglass per 0,99 EUR (a 4,99 EUR offer = 500).
static func price_value(o: Dictionary) -> int:
	var rg: int = int(o.get("rg_price", 0))
	return rg if rg > 0 else int(o.get("eur_cents", 0)) + 1

## The true discount in whole percent against the single prices (rounded down), 0 when none.
static func true_discount(o: Dictionary) -> int:
	var single: int = single_value(o)
	var price: int = price_value(o)
	if single <= price or single <= 0:
		return 0
	return (single - price) * 100 / single

## Base amount of a Riftglass tier: 100 per 0,99 EUR (rg_glass_1000 = 1000).
static func rg_base(o: Dictionary) -> int:
	return int(o.get("eur_cents", 0)) + 1

## Riftglass a tier gives on a normal purchase: base plus bonus_pct.
static func rg_total(o: Dictionary) -> int:
	var base: int = rg_base(o)
	return base + base * int(o.get("bonus_pct", 0)) / 100

## Extra Riftglass on the first purchase of a first_buy_double tier per account (the base once more).
static func first_buy_extra(o: Dictionary) -> int:
	return rg_base(o) if bool(o.get("first_buy_double", false)) else 0

## Offset of Berlin time from UTC at [param unix]: summer time from the last Sunday of March 01:00 UTC
## to the last Sunday of October 01:00 UTC (EU rule). The server counts shop days in Berlin time.
static func berlin_offset(unix: int) -> int:
	var y: int = int(Time.get_datetime_dict_from_unix_time(unix).year)
	var starts: int = _last_sunday_utc(y, 3) + 3600
	var ends: int = _last_sunday_utc(y, 10) + 3600
	return 7200 if unix >= starts and unix < ends else 3600

static func _last_sunday_utc(year: int, month: int) -> int:
	var t: int = int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month + 1, "day": 1})) - 86400
	var wd: int = int(Time.get_datetime_dict_from_unix_time(t).weekday)
	return t - wd * 86400

## Shop day number (days since 1 Jan 1970 in Berlin time).
static func shop_day(unix: int) -> int:
	return floori(float(unix + berlin_offset(unix)) / 86400.0)

## Weekday of a shop day, Monday = 0 (1 Jan 1970 was a Thursday).
static func weekday_of(day: int) -> int:
	return posmod(day + 3, 7)

## Week number of a shop day, weeks start on Monday.
static func week_of(day: int) -> int:
	return floori(float(day + 3) / 7.0)

## Whether a rotating deal is on sale at [param unix]. Deals carry "rotation": {"per": "day", "weekday": 0..6}
## (sold on that weekday) or {"per": "week", "index": i, "cycle": n} (sold in weeks where week % n == i).
## Fixed by the date, no chance. Offers without rotation are always on sale. Same rule on the server
## (_shop_deal_on, migration 20261127100100_shop_p2w_step7.sql).
static func deal_active(o: Dictionary, unix: int) -> bool:
	var r: Variant = o.get("rotation")
	if not r is Dictionary:
		return true
	var day: int = shop_day(unix)
	if str(r.get("per", "")) == "day":
		return weekday_of(day) == int(r.get("weekday", -1))
	return posmod(week_of(day), maxi(1, int(r.get("cycle", 1)))) == int(r.get("index", -1))

## Unix time the current sale of a rotating deal ends (Berlin midnight), 0 without rotation. The shop shows
## it as a plain time ("until Monday 0:00"), never as a running countdown (MONETIZATION.md rule 5).
static func deal_ends_at(o: Dictionary, unix: int) -> int:
	var r: Variant = o.get("rotation")
	if not r is Dictionary:
		return 0
	var day: int = shop_day(unix)
	var end_day: int = day + 1 if str(r.get("per", "")) == "day" else day + 7 - weekday_of(day)
	var guess: int = end_day * 86400 - 3600
	return end_day * 86400 - berlin_offset(guess)

const WEEKDAYS: Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

## When a rotating deal is sold, in plain words ("" without rotation).
static func rotation_line(o: Dictionary) -> String:
	var r: Variant = o.get("rotation")
	if not r is Dictionary:
		return ""
	if str(r.get("per", "")) == "day":
		return Loc.t("On sale every %s.") % Loc.t(WEEKDAYS[clampi(int(r.get("weekday", 0)), 0, 6)])
	return Loc.t("On sale every %d weeks, Monday to Sunday.") % int(r.get("cycle", 1))

## Problems in the catalog (empty = fine). Used by tests and tools/validate_data.gd.
static func validate() -> Array[String]:
	return ShopValidator.check(offers())
