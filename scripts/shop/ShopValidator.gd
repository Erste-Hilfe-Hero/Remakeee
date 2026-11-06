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
		if str(o.get("kind", "")) in ["cosmetic", "comfort"]:
			for k: String in ShopCatalog.STAT_FIELDS:
				if o.has(k):
					errs.append(where + ": %s offers have no value fields (%s)" % [o.kind, k])
			if str(o.get("league_scope", "")) != "look" and str(o.kind) == "cosmetic":
				errs.append(where + ": cosmetics use league_scope look")
		if str(o.get("kind", "")) == "currency":
			if rg != 0:
				errs.append(where + ": Riftglass is not sold for Riftglass")
	return errs

static func _check_random(v: Variant, where: String, errs: Array[String]) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if str(k).to_lower() in ShopCatalog.RANDOM_FIELDS:
				errs.append(where + ": field '%s' means random content (item 4021)" % k)
			_check_random(v[k], where, errs)
	elif v is Array:
		for x: Variant in v:
			_check_random(x, where, errs)
