class_name ShopEffects
extends RefCounted
## What bought unlocks do in the game (plan area 10). The server is the truth: these read
## Billing.state (shop_state), which is fetched after every login. Bag items (keepsakes,
## Echo Scents, Spark Shards) work through their items.json entries like any other item.

## Coin prices at world merchants with the Merchant's Seal (item 4970).
const MERCHANT_DISCOUNT: float = 0.8

## Merchant price multiplier: 0.8 with rg_merchant_discount, else 1.0 (item 4971).
static func merchant_mult() -> float:
	return MERCHANT_DISCOUNT if Billing.unlocked("merchant_discount") > 0 else 1.0

## A merchant's coin price after the discount, never below 1.
static func merchant_price(price: int) -> int:
	if price <= 0:
		return price
	return maxi(1, int(floor(price * merchant_mult())))

## Brings the journey in line with the server's unlocks. Storage boxes only grow here: a box
## that holds Spirlings is never taken away (plan item 4597).
static func apply_unlocks() -> void:
	var boxes: int = Billing.unlocked("storage_box")
	if boxes > GameState.storage_box_bonus:
		GameState.storage_box_bonus = boxes
		GameState.ensure_boxes()

## Growth with the pass (+50 %, item 4625) times a running Growth Crystal (items 4345, 4346).
const PASS_GROWTH: float = 1.5

static func growth_mult() -> float:
	var m: float = float(GameState.shop_boosts.get("growth", {}).get("mult", 1.0))
	return m * (PASS_GROWTH if Billing.pass_active() else 1.0)

## Coins from Wayfarer battles with a running Coin Gleam.
static func coin_mult() -> float:
	return float(GameState.shop_boosts.get("coins", {}).get("mult", 1.0))

## Battles left on a boost ("growth" or "coins"), 0 when none runs.
static func boost_left(kind: String) -> int:
	return int(GameState.shop_boosts.get(kind, {}).get("left", 0))

## Starts the boost of bag item [param id] and uses it up. A stronger boost that still runs is
## never replaced by a weaker one; the same one adds its battles. Returns the text to show, or "".
static func start_boost(id: String) -> String:
	var b: Variant = Database.item(id).get("boost")
	if not b is Dictionary or GameState.item_count(id) <= 0:
		return ""
	var kind: String = str(b.kind)
	var mult: float = float(b.mult)
	var cur: Dictionary = GameState.shop_boosts.get(kind, {})
	if not cur.is_empty() and float(cur.mult) > mult:
		return "A stronger boost is still working."
	var left: int = int(b.battles) + (int(cur.left) if not cur.is_empty() and is_equal_approx(float(cur.mult), mult) else 0)
	GameState.shop_boosts[kind] = {"mult": mult, "left": left}
	GameState.inventory[id] = GameState.item_count(id) - 1
	if GameState.inventory[id] <= 0:
		GameState.inventory.erase(id)
	return "Works for the next %d battles." % left

## One battle is over: running boosts count down.
static func battle_done() -> void:
	for kind: String in GameState.shop_boosts.keys():
		var b: Dictionary = GameState.shop_boosts[kind]
		b.left = int(b.left) - 1
		if int(b.left) <= 0:
			GameState.shop_boosts.erase(kind)
