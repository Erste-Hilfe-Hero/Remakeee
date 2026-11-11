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
	return m * (PASS_GROWTH if pass_active() else 1.0) * (1.0 + growth_plus())

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

## --- Pay-to-win step 1 (Ali, 10 Nov 2026): seals, stat crystals, permanent growth. ---
## Values live in data/shop.json "advantage_values"; the server only counts tiers (entitlements).

## Seal kinds in the order of BattleModel.seals rows: power, guard, speed.
const SEAL_KINDS: Array[String] = ["power_seal", "guard_seal", "speed_seal"]

static func _values() -> Dictionary:
	var v: Variant = ShopCatalog.data().get("advantage_values", {})
	return v if v is Dictionary else {}

## Highest tier of seal [param kind] (7 for power and guard, 5 for speed).
static func seal_max(kind: String) -> int:
	var t: Variant = _values().get(kind, [])
	return (t as Array).size() if t is Array else 0

## Percent of seal [param kind] at [param tier] (0 for tier 0 or an unknown kind).
static func seal_percent(kind: String, tier: int) -> int:
	var t: Variant = _values().get(kind, [])
	if not t is Array or tier <= 0:
		return 0
	return int((t as Array)[mini(tier, (t as Array).size()) - 1])

## Tier clamped to what the data knows.
static func clamp_tier(kind: String, tier: int) -> int:
	return clampi(tier, 0, seal_max(kind))

## The account's seal tiers [power, guard, speed] from the server's unlocks. Each bought tier
## adds 1 to the unlock count, so the count is the tier.
static func seal_tiers() -> Array[int]:
	var out: Array[int] = []
	for k: String in SEAL_KINDS:
		out.append(clamp_tier(k, Billing.unlocked(k)))
	return out

## Seal tiers for a battle: story, raids and the Open League get them, the Fair League and echo
## duels never do. [param context] is "story", "raid", "league_open", "league_fair" or "echo".
static func seals_for(context: String) -> Array[int]:
	if context in ["story", "raid", "league_open"]:
		return seal_tiers()
	return [0, 0, 0] as Array[int]

## Damage factor from the attacker's power tier and the target's guard tier.
static func seal_damage_mult(power_tier: int, guard_tier: int) -> float:
	return (1.0 + seal_percent("power_seal", power_tier) / 100.0) * (1.0 - seal_percent("guard_seal", guard_tier) / 100.0)

## Speed factor from a speed tier.
static func seal_speed_mult(speed_tier: int) -> float:
	return 1.0 + seal_percent("speed_seal", speed_tier) / 100.0

## Most crystal points one stat of one Spirling can carry: twice the free Spark cap.
static func crystal_cap() -> int:
	return int(_values().get("crystal_cap", Spirling.SPARK_MAX * 2))

## Extra growth from the permanent Growth Seal (+50 %).
static func growth_plus() -> float:
	return float(_values().get("growth_plus", 0.0)) if Billing.unlocked("growth_plus") > 0 else 0.0

## Extra Rings over the Veteran Ring cap from the Ring Cap Seal (pay-to-win step 3, plan point 47).
static func ring_cap_bonus() -> int:
	return int(_values().get("ring_cap_plus", 0)) if Billing.unlocked("ring_cap_plus") > 0 else 0

## Account power (shown in the team view): the sum of every active bought advantage in points,
## seal percents plus the permanent growth percent, 10 per extra Ring of the Ring Cap Seal, plus
## the crystal points in the team.
static func account_power() -> int:
	var tiers: Array[int] = seal_tiers()
	var n: int = 0
	for i: int in SEAL_KINDS.size():
		n += seal_percent(SEAL_KINDS[i], tiers[i])
	n += roundi(growth_plus() * 100.0)
	n += ring_cap_bonus() * 10
	for s: Spirling in GameState.party:
		for k: String in s.crystal:
			n += int(s.crystal[k])
	return n

## Adds [param n] crystal points to stat [param key] of [param s], up to crystal_cap().
## Returns the points really added (0 when the stat is full).
static func add_crystal(s: Spirling, key: String, n: int) -> int:
	var cur: int = int(s.crystal.get(key, 0))
	var add: int = clampi(n, 0, crystal_cap() - cur)
	if add <= 0:
		return 0
	var old_max: int = s.max_hp()
	s.crystal[key] = cur + add
	if key == "hp":
		s.hp = mini(s.max_hp(), s.hp + s.max_hp() - old_max)
	return add

## Required tier for a tier offer: "tier:<unlock>:<n>" means the account owns exactly n tiers,
## so tier n+1 is bought by paying only the difference. True when [param owned] fits.
static func tier_ok(req: String, owned: int) -> bool:
	return owned == int(req.get_slice(":", 2))

## --- Pay-to-win step 2 (Ali, 11 Nov 2026): Spirlings for sale, bond lures, seal set. ---

## The Spirling a "spirling" grant hands over: the named species at the named Ring, the highest
## Spark in every value, marked as bought (never traded or lent). Null for an unknown species.
static func bought_spirling(g: Dictionary) -> Spirling:
	var d: SpirlingData = Database.species(str(g.get("species", "")))
	if d == null:
		return null
	var s: Spirling = Spirling.new(d, clampi(int(g.get("level", 1)), 1, Spirling.MAX_LEVEL))
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = Spirling.SPARK_MAX
	# The temperament came from the random uid, so two purchases differed in one stat.
	s.temper = str(g.get("temper", "even"))
	s.shop_bought = true
	s.hp = s.max_hp()
	return s

## "none:<unlock>,<unlock>" means the account owns none of these unlocks (the Seal Set).
## [param count] gives the owned count of one unlock.
static func none_ok(req: String, count: Callable) -> bool:
	for k: String in req.get_slice(":", 1).split(",", false):
		if int(count.call(k)) > 0:
			return false
	return true
