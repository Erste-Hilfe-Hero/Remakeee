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
	# A refunded sixth team slot: the last Spirling goes to storage, so saves stay valid.
	while GameState.party.size() > GameState.party_max():
		GameState._store(GameState.party.pop_back(), true)

## Growth with the pass (+50 %, item 4625) times a running Growth Crystal (items 4345, 4346).
const PASS_GROWTH: float = 1.5

static func growth_mult() -> float:
	var m: float = float(GameState.shop_boosts.get("growth", {}).get("mult", 1.0))
	return m * (PASS_GROWTH if pass_active() else 1.0)

## The Wayfarer Pass runs. Only the server knows (shop_state, table subscriptions), so every pass
## advantage asks here, and all of them end the moment the server says the pass ended (items
## 4635, 4638).
static func pass_active() -> bool:
	return Billing.pass_active()

## Extra energy (start and maximum) for the whole team while an Overcharge Core runs (item 4495).
const OVERCHARGE: int = 2
## The pass: +1 energy over the maximum (11 of 10) in battles against the world (item 4632).
const PASS_ENERGY: int = 1
## Highest bonus a battle can carry (replays clamp to it).
const MAX_ENERGY_BONUS: int = OVERCHARGE + PASS_ENERGY
## The pass's free Rift Breath in Warden battles (item 4633).
const PASS_REVIVE: String = "rg_rift_breath"

## Energy bonus for the next battle. [param world] is false for echo duels, where the pass gives
## no energy (item 4652).
static func energy_bonus(world: bool = true) -> int:
	var n: int = OVERCHARGE if boost_left("overcharge") > 0 else 0
	if world and pass_active():
		n += PASS_ENERGY
	return n

## Battle-only items for the next battle: with the pass, 1 Rift Breath in every Warden battle that
## never goes into the bag (item 4633). Echo duels get none (item 4652).
static func battle_gifts(warden: bool, world: bool = true) -> Dictionary:
	return {PASS_REVIVE: 1} if warden and world and pass_active() else {}

## Failed bonds per battle that do not give the wild Spirling its free action: 1 with the pass
## (item 4634).
static func bond_grace() -> int:
	return 1 if pass_active() else 0

## Settings sold in the shop (Ali, 7 Nov): settings key -> unlock id from data/shop.json.
## Without the unlock the row says "Shop" and the feature stays at its plain state.
const SETTING_UNLOCKS: Dictionary[String, String] = {
	"damage_preview": "damage_preview", "minimap": "minimap", "fast_text": "fast_text",
	"retro": "retro_filter", "day_night": "sky_control", "weather": "sky_control",
	"bench_lessons": "bench_lessons",
}

## True when the setting [param key] is free or its shop unlock was bought.
static func owns_setting(key: String) -> bool:
	return not SETTING_UNLOCKS.has(key) or Billing.unlocked(SETTING_UNLOCKS[key]) > 0

## Shop offer name for a locked setting, for the "In the shop" note.
static func setting_offer_name(key: String) -> String:
	var o: Dictionary = ShopCatalog.offer("rg_" + str(SETTING_UNLOCKS.get(key, "")))
	return str(o.get("name", ""))

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
	var left: int = int(b.get("battles", b.get("steps", 0))) + (int(cur.left) if not cur.is_empty() and is_equal_approx(float(cur.mult), mult) else 0)
	GameState.shop_boosts[kind] = {"mult": mult, "left": left}
	GameState.inventory[id] = GameState.item_count(id) - 1
	if GameState.inventory[id] <= 0:
		GameState.inventory.erase(id)
	if kind in STEP_KINDS:
		return Loc.t("Works for the next %d steps.") % left
	return "Works for the next battle." if left == 1 else "Works for the next %d battles." % left

## Boosts that count steps instead of battles (Encounter Call, item 4838).
const STEP_KINDS: Array[String] = ["encounters"]

## How much more often wild Spirlings show up right now (2 while an Encounter Call runs).
static func encounter_mult() -> float:
	return float(GameState.shop_boosts.get("encounters", {}).get("mult", 1.0)) if boost_left("encounters") > 0 else 1.0

## One step on the map: step boosts count down. True when one just ran out.
static func step_done() -> bool:
	var ended: bool = false
	for kind: String in STEP_KINDS:
		if not GameState.shop_boosts.has(kind):
			continue
		var b: Dictionary = GameState.shop_boosts[kind]
		b.left = int(b.left) - 1
		if int(b.left) <= 0:
			GameState.shop_boosts.erase(kind)
			ended = true
	return ended

## Names of the boosts for the status lines.
const BOOST_NAMES: Dictionary = {"growth": "Growth", "coins": "Coins", "overcharge": "Overcharge",
	"encounters": "Encounter Call"}

## One line per running boost ("Growth x2: 14 battles left"), for the team view and after each
## battle (item 4342).
static func boost_lines() -> Array[String]:
	var out: Array[String] = []
	for kind: String in ["growth", "coins", "overcharge", "encounters"]:
		var left: int = boost_left(kind)
		if left <= 0:
			continue
		var b: Dictionary = GameState.shop_boosts[kind]
		var head: String = Loc.t(str(BOOST_NAMES[kind]))
		if kind in STEP_KINDS:
			out.append(head + ": " + (Loc.t("1 step left") if left == 1 else Loc.t("%d steps left") % left))
			continue
		if kind != "overcharge":
			head += " x%s" % String.num(float(b.get("mult", 1.0)), 1).trim_suffix(".0")
		out.append(head + ": " + (Loc.t("1 battle left") if left == 1 else Loc.t("%d battles left") % left))
	return out

## One battle is over: running boosts count down.
static func battle_done() -> void:
	for kind: String in GameState.shop_boosts.keys():
		if kind in STEP_KINDS:
			continue
		var b: Dictionary = GameState.shop_boosts[kind]
		b.left = int(b.left) - 1
		if int(b.left) <= 0:
			GameState.shop_boosts.erase(kind)

## Battle Skip (items 4839/4840): a wild battle against one foe at least [constant SKIP_GAP]
## Rings below the lead is fought by the player's AI in the background, through the normal
## battle model, so growth, coins and the replay stay right.
const SKIP_ITEM: String = "rg_skip_battle"
const SKIP_GAP: int = 10
const SKIP_MAX_TURNS: int = 100

## True when a Battle Skip may be used on [param foes].
static func can_skip(foes: Array[Spirling]) -> bool:
	if foes.size() != 1 or GameState.item_count(SKIP_ITEM) <= 0:
		return false
	var lead: int = GameState.first_healthy_index()
	return lead >= 0 and GameState.party[lead].level >= foes[0].level + SKIP_GAP

## Plays [param model] (not started yet) to its end with the player's AI and returns the inputs
## for the replay. No bag items are used. The first skip in the bag is used up.
static func skip_battle(model: BattleModel) -> Array:
	GameState.take_item(SKIP_ITEM)
	var brain := BattleAI.new(2)
	var inputs: Array = []
	model.start()
	var turns: int = 0
	while not model.is_finished() and turns < SKIP_MAX_TURNS:
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(0, model.switch_slot())[0]
			inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var a: BattleAction = brain.choose(model, 0)
		inputs.append(BattleReplay.action_to_dict(a))
		model.submit_turn(a)
		turns += 1
	return inputs

## Warden helps (items 4885-4888): only after at least one lost try without help, never in
## Rift-Born. They never touch levels, so the Ring cap stays.
const WARDEN_WEAKEN_ITEM: String = "rg_warden_weaken"

static func warden_help_allowed(losses: int, difficulty: int) -> bool:
	return losses >= 1 and difficulty != GameState.Difficulty.RIFT_BORN

static func can_weaken_warden(losses: int, difficulty: int) -> bool:
	return warden_help_allowed(losses, difficulty) and GameState.item_count(WARDEN_WEAKEN_ITEM) > 0

## Warden Lore (item 4883): the Warden card also lists the team, techniques and items.
static func has_warden_lore(losses: int, difficulty: int) -> bool:
	return warden_help_allowed(losses, difficulty) and Billing.unlocked("warden_lore") > 0

## Rift Anchor (item 4884): offered right after a lost Warden battle (that loss is the try
## without help), never in Rift-Born.
const RIFT_ANCHOR_ITEM: String = "rg_rift_anchor"

static func can_anchor(difficulty: int) -> bool:
	return warden_help_allowed(1, difficulty) and GameState.item_count(RIFT_ANCHOR_ITEM) > 0
