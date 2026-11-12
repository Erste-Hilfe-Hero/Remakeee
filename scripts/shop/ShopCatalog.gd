class_name ShopCatalog
extends RefCounted
## Loads and checks data/shop.json, the only list of shop offers (docs/MONETIZATION.md).
## The server has the same offers (tools/shop/build_offers_sql.py writes them into a migration).
##
## Offer fields: id, kind (advantage | cosmetic | comfort | currency), tab, name, desc, rg_price
## (Riftglass, 0 = not for Riftglass), eur_cents (direct store price tier), store_type,
## product_id, grants, league_scope (open | none | look), duration, limit, requires, min_band, ready.

const PATH: String = "res://data/shop.json"
const KINDS: Array[String] = ["advantage", "cosmetic", "comfort", "currency"]
## Shop tabs in menu order (item 4179).
const TABS: Array[String] = ["advantages", "packs", "pass", "looks", "riftglass"]
const TAB_NAMES: Dictionary = {"advantages": "Advantages", "packs": "Packs", "pass": "Pass", "looks": "Looks",
	"riftglass": "Riftglass"}
const STORE_TYPES: Array[String] = ["consumable", "non_consumable", "subscription"]
const LEAGUE_SCOPES: Array[String] = ["open", "none", "look"]
## "spirling" hands over one Spirling with fixed values (pay-to-win plan points 61-80, ShopEffects.bought_spirling).
const GRANT_TYPES: Array[String] = ["rg", "item", "unlock", "coins", "pass", "choice", "spirling"]
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
		if str(o.get("tab", "")) == tab and (include_unready or bool(o.get("ready", false))):
			out.append(o)
	return out

static func is_advantage(o: Dictionary) -> bool:
	return str(o.get("kind", "")) == "advantage"

## Euro value of a Riftglass amount in cents, rounded down to whole cents (item 4221).
static func euro_cents(rg: int) -> int:
	return int(floor(float(rg) * EUR_CENTS_PER_100 / 100.0))

## "≈ 2,97 €" for 300 Riftglass. Only a hint: real prices come from the store.
static func euro_hint(rg: int) -> String:
	return "≈ " + format_eur(euro_cents(rg))

## "2,97 €" (German) or "€2.97" (other languages).
static func format_eur(cents: int) -> String:
	var whole: int = cents / 100
	var rest: int = absi(cents) % 100
	if Loc.language() == "de":
		return "%d,%02d €" % [whole, rest]
	return "€%d.%02d" % [whole, rest]

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
			return Loc.t("%s at Ring %d with the highest Spark in every value") % [Loc.t(str(e.species)), int(e.level)]
	return ""

## How many of an entry the player gets: tiered unlocks and the pass count as one.
static func entry_amount(e: Dictionary) -> int:
	if str(e.t) == "pass" or (str(e.t) == "unlock" and unlock_tiers(str(e.id)).size() > 1):
		return 1
	return int(e.n)

## One contents entry as a line: "5x Ring Tonic", "300 Riftglass", "2000 coins".
static func entry_line(e: Dictionary) -> String:
	match str(e.t):
		"rg":
			return Loc.t("%d Riftglass") % int(e.n)
		"coins":
			return Loc.t("%d coins") % int(e.n)
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
		return Loc.t("With Riftglass you can buy it again; in the App Store or Google Play only once.")
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
	for g: Variant in o.get("grants", []):
		if not g is Dictionary:
			continue
		match str(g.get("t", "")):
			"rg":
				v += int(g.n)
			"item":
				v += int(g.get("n", 1)) * int(offer(str(g.id)).get("rg_price", 0))
			"unlock":
				v += _unlock_price(str(g.get("id", "")))
			"choice":
				var opts: Variant = o.get("choice", [])
				if opts is Array and not (opts as Array).is_empty():
					v += int(g.get("n", 1)) * int(offer(str(opts[0])).get("rg_price", 0))
	return v

## Problems in the catalog (empty = fine). Used by tests and tools/validate_data.gd.
static func validate() -> Array[String]:
	return ShopValidator.check(offers())
