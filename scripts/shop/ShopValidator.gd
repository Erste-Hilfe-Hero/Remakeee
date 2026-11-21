class_name ShopValidator
extends RefCounted
## Checks the shop catalog (data/shop.json) against the shop rules in docs/MONETIZATION.md:
## fixed contents without chance, store price tiers, Riftglass multiples of 100, product ids,
## no value fields on cosmetics, shop closed under 13. Messages are for developers only.

## Problems in [param offers] (empty = fine).
static func check(offers: Array[Dictionary]) -> Array[String]:
	var errs: Array[String] = []
	var ids: Dictionary = {}
	var products: Dictionary = {}
	for o: Dictionary in offers:
		var id: String = str(o.get("id", ""))
		var where: String = "offer '%s'" % id
		if not id.begins_with("rg_"):
			errs.append(where + ": id must start with rg_ (shop goods never appear at merchants)")
		if ids.has(id):
			errs.append(where + ": duplicate id")
		ids[id] = true
		for k: String in ["kind", "tab", "name", "desc", "rg_price", "eur_cents", "store_type", "product_id", "grants",
				"league_scope", "min_band", "ready"]:
			if not o.has(k):
				errs.append(where + ": missing " + k)
		if not str(o.get("kind", "")) in ShopCatalog.KINDS:
			errs.append(where + ": bad kind")
		if not str(o.get("tab", "")) in ShopCatalog.TABS:
			errs.append(where + ": bad tab")
		if not str(o.get("store_type", "")) in ShopCatalog.STORE_TYPES:
			errs.append(where + ": bad store_type")
		if not str(o.get("league_scope", "")) in ShopCatalog.LEAGUE_SCOPES:
			errs.append(where + ": bad league_scope")
		var rg: int = int(o.get("rg_price", -1))
		if rg < 0 or rg % 100 != 0:
			errs.append(where + ": Riftglass price must be a multiple of 100 (item 4219)")
		var eur: int = int(o.get("eur_cents", 0))
		if eur <= 0 or eur > ShopCatalog.MAX_EUR_CENTS or eur % 100 != 99:
			errs.append(where + ": eur_cents must be a store tier like 299")
		if str(o.get("kind", "")) != "currency" and rg > 0 and eur != rg - 1:
			errs.append(where + ": direct price must be the Riftglass price minus one cent (item 4220)")
		var pid: String = str(o.get("product_id", ""))
		if not pid.begins_with("de.chimora.game.") or pid.length() > 100:
			errs.append(where + ": product id must look like de.chimora.game.<kind>.<name> (item 4065)")
		if products.has(pid):
			errs.append(where + ": duplicate product id " + pid)
		products[pid] = true
		if int(o.get("min_band", 0)) < 13:
			errs.append(where + ": the shop is closed under 13 (item 4248)")
		_check_random(o, where, errs)
		var grants: Variant = o.get("grants", [])
		if not grants is Array or (grants as Array).is_empty():
			errs.append(where + ": no grants")
		else:
			for g: Variant in grants:
				if not g is Dictionary or not str(g.get("t", "")) in ShopCatalog.GRANT_TYPES:
					errs.append(where + ": bad grant " + str(g))
				elif str(g.t) == "choice" and not o.get("choice") is Array:
					errs.append(where + ": choice grant without a choice list (chosen before buying, item 4688)")
				var gid: String = str((g as Dictionary).get("id", "")) if g is Dictionary else ""
				if gid != "" and Database.species(gid) != null:
					errs.append(where + ": a Spirling is sold only as a \"spirling\" grant")
				elif g is Dictionary and str(g.t) == "spirling":
					if Database.species(str(g.get("species", ""))) == null:
						errs.append(where + ": spirling grant names no species in spirlings.json")
					if int(g.get("level", 0)) < 1 or int(g.get("level", 0)) > Spirling.STORY_RING:
						errs.append(where + ": spirling grant needs a level from 1 to the Ring cap")
					if str(o.get("store_type", "")) != "non_consumable" or int((o.get("limit", {}) as Dictionary).get("n", 0)) != 1:
						errs.append(where + ": a Spirling offer is non_consumable and once per account")
				elif bool(o.get("ready", false)) and g is Dictionary and str(g.t) == "item" and Database.item(gid).is_empty():
					errs.append(where + ": ready offer grants %s, which is no item in items.json" % gid)
		if str(o.get("kind", "")) in ["cosmetic", "comfort"]:
			for k: String in ShopCatalog.STAT_FIELDS:
				if o.has(k):
					errs.append(where + ": %s offers have no value fields (%s)" % [o.kind, k])
			if str(o.get("league_scope", "")) != "look" and str(o.kind) == "cosmetic":
				errs.append(where + ": cosmetics use league_scope look")
		if str(o.get("kind", "")) == "currency":
			if rg != 0:
				errs.append(where + ": Riftglass is not sold for Riftglass")
		_check_was_price(o, where, errs)
		_check_wording(o, where, errs)
	return errs

## A struck-through old price (item 4037, PAngV § 11) needs the dates of the higher price:
## was_since and was_until ("YYYY-MM-DD"), at least 30 days apart, and the old price must be higher.
static func _check_was_price(o: Dictionary, where: String, errs: Array[String]) -> void:
	if not o.has("was_rg_price"):
		return
	var since: int = Time.get_unix_time_from_datetime_string(str(o.get("was_since", "")))
	var until: int = Time.get_unix_time_from_datetime_string(str(o.get("was_until", "")))
	if since <= 0 or until <= 0:
		errs.append(where + ": was_rg_price needs was_since and was_until dates (item 4037)")
	elif until - since < 30 * 86400:
		errs.append(where + ": the old price must have been sold for at least 30 days (item 4037)")
	if int(o.was_rg_price) <= int(o.get("rg_price", 0)):
		errs.append(where + ": was_rg_price must be higher than rg_price")

## Paid offers never sound free (item 4035): no "free", "as a gift" or "for nothing" in name or text.
## ("gifts" alone stays allowed: it names Spirling gifts and gifts to friends, both game features.)
static func _check_wording(o: Dictionary, where: String, errs: Array[String]) -> void:
	var text: String = (str(o.get("name", "")) + " " + str(o.get("desc", ""))).to_lower()
	for w: String in ["free", "for nothing", "gratis", "as a gift", "geschenkt"]:
		if text.contains(w):
			errs.append(where + ": paid offers never say '%s' (item 4035)" % w)

static func _check_random(v: Variant, where: String, errs: Array[String]) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if str(k).to_lower() in ShopCatalog.RANDOM_FIELDS:
				errs.append(where + ": field '%s' means random content (item 4021)" % k)
			_check_random(v[k], where, errs)
	elif v is Array:
		for x: Variant in v:
			_check_random(x, where, errs)
