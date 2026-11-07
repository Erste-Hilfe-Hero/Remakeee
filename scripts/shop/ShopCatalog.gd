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
const GRANT_TYPES: Array[String] = ["rg", "item", "unlock", "coins", "pass", "choice"]
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

## Every grant as a line for the detail view ("5 x Ring Tonic").
static func grant_lines(o: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for g: Variant in o.get("grants", []):
		if not g is Dictionary:
			continue
		match str(g.get("t", "")):
			"rg":
				out.append(Loc.t("%d Riftglass") % int(g.n))
			"coins":
				out.append(Loc.t("%d coins") % int(g.n))
			"item":
				var it: Dictionary = offer(str(g.id))
				var nm: String = Loc.t(str(it.get("name", g.id))) if not it.is_empty() else Loc.t(str(Database.item(str(g.id)).get("name", g.id)))
				out.append("%d x %s" % [int(g.get("n", 1)), nm])
			"unlock":
				out.append(Loc.t(str(o.get("name", ""))))
			"pass":
				out.append(Loc.t("Wayfarer Pass for %d days") % int(g.days))
			"choice":
				out.append(Loc.t("1 x Element Prism of your choice"))
	return out

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
