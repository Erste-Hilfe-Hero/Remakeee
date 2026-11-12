extends GutTest
## Bug sweep 12 Nov 2026: what an offer shows (ShopCatalog.contents) is what a purchase hands
## over (LocalShop._grant and Billing.apply_grant), for every offer in data/shop.json.

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_inventory: Dictionary
var _old_money: int
var s: LocalBackend
var shop: LocalShop

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_inventory = GameState.inventory.duplicate()
	_old_money = GameState.money

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	GameState.inventory = _old_inventory
	GameState.money = _old_money

func before_each() -> void:
	s = LocalBackend.new()
	shop = LocalShop.of(s)
	Online.backend = s
	Online.state = Online.State.ONLINE
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	GameState.inventory = {}
	GameState.money = 0

func _add(d: Dictionary, key: String, n: int) -> void:
	d[key] = int(d.get(key, 0)) + n

## What the shop shows for [param o], as "kind:id" -> amount. A pass is a subscription, not a grant.
func _shown(o: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in ShopCatalog.contents(o):
		match str(e.t):
			"pass":
				pass
			"spirling":
				_add(out, "spirling:%s:%d" % [e.species, int(e.level)], int(e.n))
			"rg", "coins", "choice":
				_add(out, str(e.t), int(e.n))
			_:
				_add(out, "%s:%s" % [e.t, e.id], int(e.n))
	return out

## What one purchase of [param o] hands over on the server and then puts into the journey.
func _given(o: Dictionary, choice: String) -> Dictionary:
	var uid: String = s.me()
	var st: Dictionary = shop._shop(uid)
	var balance: int = shop.balance_of(uid)
	var unlocks: Dictionary = (st.unlocks as Dictionary).duplicate()
	var sent: int = (st.deliveries as Array).size()
	shop._grant(uid, 1, o, choice if not choice.is_empty() else null)
	var out: Dictionary = {}
	if shop.balance_of(uid) != balance:
		_add(out, "rg", shop.balance_of(uid) - balance)
	for k: String in st.unlocks:
		if int(st.unlocks[k]) != int(unlocks.get(k, 0)):
			_add(out, "unlock:" + k, int(st.unlocks[k]) - int(unlocks.get(k, 0)))
	GameState.inventory = {}
	GameState.money = 0
	var picked: bool = false
	for d: Dictionary in (st.deliveries as Array).slice(sent):
		for g: Dictionary in d.grants:
			if str(g.t) == "spirling":
				var sp: Spirling = ShopEffects.bought_spirling(g)
				assert_not_null(sp, "%s: %s exists" % [o.id, g.get("species", "")])
				if sp != null:
					_add(out, "spirling:%s:%d" % [sp.data.species_name, sp.level], 1)
				continue
			Billing.apply_grant(g)
			# The chosen piece comes as a plain item: count it as the choice it was shown as.
			if not picked and not choice.is_empty() and str(g.t) == "item" and str(g.id) == choice:
				picked = true
				_add(out, "choice", int(g.n))
				GameState.inventory[choice] = GameState.item_count(choice) - int(g.n)
	for id: String in GameState.inventory:
		if GameState.item_count(id) != 0:
			_add(out, "item:" + id, GameState.item_count(id))
	if GameState.money != 0:
		_add(out, "coins", GameState.money)
	return out

func test_every_offer_hands_over_exactly_what_it_shows() -> void:
	var seen: int = 0
	for o: Dictionary in ShopCatalog.offers():
		var options: Array = o.get("choice", []) if o.get("choice") is Array else []
		var choice: String = str(options[0]) if not options.is_empty() else ""
		var shown: Dictionary = _shown(o)
		assert_eq(_given(o, choice), shown, "%s: handed over = shown" % o.id)
		if str(o.get("store_type", "")) != "subscription":
			assert_false(shown.is_empty(), "%s shows something" % o.id)
		for key: String in shown:
			if key.begins_with("item:"):
				assert_not_null(Database.item(key.trim_prefix("item:")), "%s: %s is a real item" % [o.id, key])
		for id: Variant in options:
			assert_not_null(Database.item(str(id)), "%s: choice %s is a real item" % [o.id, id])
		seen += 1
	assert_gt(seen, 100, "the whole catalog was checked")

func test_a_choice_pack_hands_over_the_chosen_piece() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_rift_pack_1")
	var pick: String = str(o.choice[1])
	shop._grant(s.me(), 1, o, pick)
	var bag: Array = shop._shop(s.me()).deliveries[0].grants
	assert_true(bag.has({"t": "item", "id": pick, "n": 1}), str(bag))
