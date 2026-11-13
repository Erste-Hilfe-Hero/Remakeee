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
	# A refunded setting goes back to its plain state, it does not keep working (bug plan 1360).
	if not owns_setting("retro") and EraManager.retro_filter != 0:
		EraManager.set_retro_filter(0)
	if not owns_setting("day_night"):
		GameState.day_night = true
	if not owns_setting("weather"):
		GameState.weather = true
	if not owns_setting("wild_ward"):
		GameState.wild_ward = false
	if not owns_setting("fast_text") and GameState.text_speed == GameState.TextSpeed.FAST:
		GameState.text_speed = GameState.TextSpeed.NORMAL

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
	"bench_lessons": "bench_lessons", "wild_ward": "wild_ward",
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

## Boosts that count steps instead of battles (Encounter Call, item 4838; Lure and Shimmer Scents,
## pay-to-win step 5).
const STEP_KINDS: Array[String] = ["encounters", "rare", "gleam"]

## How much more often wild Spirlings show up right now (2 while an Encounter Call runs).
static func encounter_mult() -> float:
	return float(GameState.shop_boosts.get("encounters", {}).get("mult", 1.0)) if boost_left("encounters") > 0 else 1.0

## One step on the map: step boosts count down. True when one just ran out.
static func step_done() -> bool:
	return not step_kinds_done().is_empty()

## One step on the map: step boosts count down. Returns the kinds that just ran out.
static func step_kinds_done() -> Array[String]:
	var ended: Array[String] = []
	for kind: String in STEP_KINDS:
		if not GameState.shop_boosts.has(kind):
			continue
		var b: Dictionary = GameState.shop_boosts[kind]
		b.left = int(b.left) - 1
		if int(b.left) <= 0:
			GameState.shop_boosts.erase(kind)
			ended.append(kind)
	return ended

## Note shown when the step boost [param kind] runs out.
const STEP_END_NOTES: Dictionary = {"encounters": "The Encounter Call fades.", "rare": "The Lure Scent fades.",
	"gleam": "The Shimmer Scent fades."}

## Names of the boosts for the status lines.
const BOOST_NAMES: Dictionary = {"growth": "Growth", "coins": "Coins", "overcharge": "Overcharge",
	"encounters": "Encounter Call", "rare": "Lure Scent", "gleam": "Shimmer Scent"}

## One line per running boost ("Growth x2: 14 battles left"), for the team view and after each
## battle (item 4342).
static func boost_lines() -> Array[String]:
	var out: Array[String] = []
	for kind: String in ["growth", "coins", "overcharge", "encounters", "rare", "gleam"]:
		var left: int = boost_left(kind)
		if left <= 0:
			continue
		var b: Dictionary = GameState.shop_boosts[kind]
		var head: String = Loc.t(str(BOOST_NAMES[kind]))
		if kind in ["rare", "gleam"]:
			head += " x%s" % String.num(float(b.get("mult", 1.0)), 1).trim_suffix(".0")
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
## seal, amulet and Bond Head Start percents plus the permanent growth percent, 10 per extra Ring of the Ring Cap Seal, plus
## the crystal points in the team.
static func account_power() -> int:
	var tiers: Array[int] = seal_tiers()
	var n: int = 0
	for i: int in SEAL_KINDS.size():
		n += seal_percent(SEAL_KINDS[i], tiers[i])
	var am: Array[int] = amulet_tiers()
	for i: int in AMULET_KINDS.size():
		n += seal_percent(AMULET_KINDS[i], am[i])
	n += roundi(growth_plus() * 100.0)
	n += ring_cap_bonus() * 10
	n += seal_percent("bond_edge", bond_edge_tier())
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
	var s: Spirling = Spirling.new(d, clampi(int(g.get("level", 1)), 1, Spirling.STORY_RING))
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = Spirling.SPARK_MAX
	# The temperament came from a random uid, so two buys could differ in HP (336 vs 352).
	s.temper = str(g.get("temper", Spirling.TEMPERAMENTS[0].id))
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

## --- Pay-to-win step 4 (plan points 16 to 19): Crit Seal, Status Ward, Opening Shield. ---
## A second tier row beside the seals, [crit, ward, shield] (BattleModel.amulets). Same rules as
## the seals: story, raids and the Open League, never the Fair League or echo duels.
const AMULET_KINDS: Array[String] = ["crit_seal", "status_ward", "start_shield"]

## The account's amulet tiers [crit, ward, shield] from the server's unlocks.
static func amulet_tiers() -> Array[int]:
	var out: Array[int] = []
	for k: String in AMULET_KINDS:
		out.append(clamp_tier(k, Billing.unlocked(k)))
	return out

## Amulet tiers for a battle in [param context] (see seals_for).
static func amulets_for(context: String) -> Array[int]:
	if context in ["story", "raid", "league_open"]:
		return amulet_tiers()
	return [0, 0, 0] as Array[int]

## Amulet tiers [crit, ward, shield] from a snapshot or expect, clamped to the tiers the data knows.
static func amulet_row(v: Variant) -> Array:
	var out: Array = [0, 0, 0]
	if v is Array:
		for i: int in mini((v as Array).size(), AMULET_KINDS.size()):
			out[i] = clamp_tier(AMULET_KINDS[i], int(v[i]))
	return out

## Crit multiplier for DamageCalc.compute: [param base] times the normal chance plus the Crit Seal's
## percentage points, expressed as one factor on DamageCalc.CRIT_CHANCE.
static func crit_mult(base: float, crit_tier: int) -> float:
	return base + seal_percent("crit_seal", crit_tier) / 100.0 / DamageCalc.CRIT_CHANCE

## Chance (0..1) that a foe's status fails on a side with Status Ward [param tier].
static func ward_chance(tier: int) -> float:
	return seal_percent("status_ward", tier) / 100.0

## Damage factor on the first hit the lead takes with Opening Shield [param tier].
static func shield_mult(tier: int) -> float:
	return 1.0 - seal_percent("start_shield", tier) / 100.0

## Line at the start of a battle that names every bought advantage working in it (plan point 19).
## Empty when none works. [param seal_tier_row] and [param amulet_tier_row] are the player's tiers.
static func edge_line(seal_tier_row: Array, amulet_tier_row: Array) -> String:
	var parts: Array[String] = []
	var names: Array[String] = ["Power +%d%%", "Guard +%d%%", "Pace +%d%%"]
	for i: int in mini(seal_tier_row.size(), SEAL_KINDS.size()):
		var p: int = seal_percent(SEAL_KINDS[i], int(seal_tier_row[i]))
		if p > 0:
			parts.append(Loc.t(names[i]) % p)
	var a_names: Array[String] = ["Crits +%d", "Status Ward %d%%", "Opening Shield %d%%"]
	for i: int in mini(amulet_tier_row.size(), AMULET_KINDS.size()):
		var q: int = seal_percent(AMULET_KINDS[i], int(amulet_tier_row[i]))
		if q > 0:
			parts.append(Loc.t(a_names[i]) % q)
	if parts.is_empty():
		return ""
	return Loc.t("Shop advantages at work: %s") % ", ".join(parts)

## --- Pay-to-win step 5 (plan points 15, 25, 26, 28, 29, 32): bonding and collecting. ---

## How much more often uncommon, shy and ancient wild Spirlings step out while a Lure Scent runs.
static func rare_mult() -> float:
	return float(GameState.shop_boosts.get("rare", {}).get("mult", 1.0)) if boost_left("rare") > 0 else 1.0

## Factor on the wild Gleam chance while a Shimmer Scent runs.
static func gleam_mult() -> float:
	return float(GameState.shop_boosts.get("gleam", {}).get("mult", 1.0)) if boost_left("gleam") > 0 else 1.0

## The account's Bond Head Start tier (0 to 3).
static func bond_edge_tier() -> int:
	return clamp_tier("bond_edge", Billing.unlocked("bond_edge"))

## Added to the bond timing score in wild battles (0.1 per tier, values in advantage_values).
static func bond_edge() -> float:
	return seal_percent("bond_edge", bond_edge_tier()) / 100.0

## Form an Unfurl Spark turns [param s] into: the first unfold path that needs no item, null if none.
static func unfurl_spark_target(s: Spirling) -> SpirlingData:
	if s == null or s.data == null:
		return null
	for p: Dictionary in s.data.unfold:
		if str(p.get("rule", "")) != "item" and p.get("to") is SpirlingData:
			return p.to
	return null

## --- Pay-to-win step 6 (plan points 10-14, 27, 30, 31, 33, 35-38, 40, 50, 51, 57, 58, 60). ---

## Team places from the Sixth and Seventh Team Place (0, 1 or 2) on top of GameState.MAX_PARTY.
static func extra_team_places() -> int:
	return (1 if Billing.unlocked("team_slot_6") > 0 else 0) + (1 if Billing.unlocked("team_slot_7") > 0 else 0)

## The gifts in effect on [param s] as one table: its gift, plus the hidden gift of its line when the
## shop's Second Gift Slot is open on it (plan point 12). The first gift wins where both set a key;
## "immune" lists are joined.
static func gift_table(s: Spirling) -> Dictionary:
	var first: Dictionary = BattleRules.trait_info(s.gift_id())
	var more: Array[String] = []
	var second_id: String = second_gift_id(s)
	if not second_id.is_empty():
		more.append(second_id)
	# Boss, Prism and learned bonus gifts of the Kampf plan (TraitKit).
	more.append_array(TraitKit.extra_ids(s))
	if more.is_empty():
		return first
	var out: Dictionary = first.duplicate(true)
	for id: String in more:
		var second: Dictionary = BattleRules.trait_info(id)
		for k: Variant in second:
			if str(k) == "immune":
				var imm: Array = (out.get("immune", []) as Array).duplicate()
				for x: Variant in second.immune:
					if not x in imm:
						imm.append(x)
				out["immune"] = imm
			elif not out.has(k):
				out[k] = second[k]
	return out

## The id of the second gift working on [param s] ("" without the Second Gift Slot, or when it
## would be the same gift twice).
static func second_gift_id(s: Spirling) -> String:
	if s == null or not s.gift_slot:
		return ""
	var h: String = HiddenGifts.gift_id(s.data)
	return "" if h.is_empty() or h == s.gift_id() else h

## True when the Second Gift Slot can open on [param s]: not open yet, and its line has a hidden
## gift that differs from the gift it has.
static func can_open_gift_slot(s: Spirling) -> bool:
	if s == null or s.gift_slot:
		return false
	var h: String = HiddenGifts.gift_id(s.data)
	return not h.is_empty() and h != s.gift_id()

## Spirling Radar (plan point 27): a note naming the rarer wild kinds of table [param table_id]
## and the ground they hide in. Empty without the unlock or when the place has none.
static func radar_line(table_id: String) -> String:
	if Billing.unlocked("radar") <= 0 or table_id.is_empty():
		return ""
	var parts: Array[String] = []
	for sp: Dictionary in EncounterTable.table(table_id).get("spawns", []):
		var sd: SpirlingData = Database.species(str(sp.get("species", "")))
		if sd == null or sd.rarity == "common":
			continue
		var grounds: Array[String] = EncounterTable.grounds_of(sp)
		var where: String = Loc.t("everywhere") if grounds.is_empty() else ", ".join(grounds.map(func(g: String) -> String: return Loc.t(g)))
		var part: String = "%s (%s, %s)" % [Loc.t(sd.species_name), Loc.t(sd.rarity), where]
		if not part in parts:
			parts.append(part)
	if parts.is_empty():
		return ""
	return Loc.t("Radar: %s") % "; ".join(parts)

## Spirlog Atlas (plan point 35): every place of a kind is named on its page.
static func spirlog_atlas() -> bool:
	return Billing.unlocked("spirlog_atlas") > 0

## How often the rare visitor of the day can be met (3 with the Triple Find of the Day, point 36).
static func daily_find_visits() -> int:
	return 3 if Billing.unlocked("daily_find_x3") > 0 else 1

## Wild Ward (plan point 37): bought and switched on in Settings, no wild Spirling steps out.
static func wild_ward_on() -> bool:
	return GameState.wild_ward and owns_setting("wild_ward")

## Walk speed factor on the map: 2 with Swift Steps (plan point 50).
static func walk_mult() -> float:
	return 2.0 if Billing.unlocked("swift_steps") > 0 else 1.0

## Pocket Rest (plan point 51): rest from the menu anywhere outside battle.
static func can_rest_anywhere() -> bool:
	return Billing.unlocked("rest_anywhere") > 0

## Rests the team through Pocket Rest. It counts for no daily task and moves no rest spot.
static func pocket_rest() -> bool:
	if not can_rest_anywhere():
		return false
	GameState.heal_party()
	return true

## Storage boxes owned after Storage Wing step [param step] (1 to 5, plan point 31).
static func storage_wing_boxes(step: int) -> int:
	var t: Variant = _values().get("storage_wing", [])
	if not t is Array or step <= 0:
		return 0
	return int((t as Array)[mini(step, (t as Array).size()) - 1])

## "max:<unlock>:<n>": the account owns at most n of the unlock (single Storage Boxes stop at 12).
static func max_ok(req: String, owned: int) -> bool:
	return owned <= int(req.get_slice(":", 2))

## Pass of the day (plan point 38): the spawn a pass holder meets first each day on table
## [param table_id], the rarer kind with the lowest weight (ties by name), {} when there is none.
static func pass_rare_spawn(table_id: String) -> Dictionary:
	var best: Dictionary = {}
	for sp: Dictionary in EncounterTable.table(table_id).get("spawns", []):
		var sd: SpirlingData = Database.species(str(sp.get("species", "")))
		if sd == null or sd.rarity == "common":
			continue
		if best.is_empty() or int(sp.get("weight", 1)) < int(best.get("weight", 1)) \
				or (int(sp.get("weight", 1)) == int(best.get("weight", 1)) and str(sp.species) < str(best.species)):
			best = sp
	return best

const PASS_RARE_FLAG: String = "pass_rare_%s"

## The pass holder's rare Spirling of the day on [param table_id], or null (no pass, met today,
## no rarer kind there). Sets the day's flag when it appears.
static func pass_rare(table_id: String, flags: Dictionary, rng: RandomNumberGenerator, day: String = "") -> Spirling:
	if not pass_active():
		return null
	if day.is_empty():
		day = DailyFind.today_key()
	var key: String = PASS_RARE_FLAG % day
	if bool(flags.get(key, false)):
		return null
	var sp: Dictionary = pass_rare_spawn(table_id)
	if sp.is_empty():
		return null
	var sd: SpirlingData = Database.species(str(sp.species))
	flags[key] = true
	var wild := Spirling.new(sd, rng.randi_range(int(sp.get("min", 2)), int(sp.get("max", 4))), rng)
	wild.restore()
	return wild

## Progress line for the team view (plan point 60, adults only, no button): what the best next
## tier offer would add to Power right now, e.g. "Shop: Power Seal II adds 5 Power". Empty when
## nothing is left or the player is under 18.
static func next_power_line() -> String:
	var b: Variant = Billing.band()
	if b == null or int(b) < 18:
		return ""
	var best: Dictionary = {}
	var best_gain: int = 0
	for o: Dictionary in ShopCatalog.offers():
		var req: String = str(o.get("requires", ""))
		if not bool(o.get("ready", false)) or not req.begins_with("tier:"):
			continue
		var kind: String = req.get_slice(":", 1)
		var owned: int = Billing.unlocked(kind)
		if seal_max(kind) <= 0 or not tier_ok(req, owned):
			continue
		var gain: int = seal_percent(kind, owned + 1) - seal_percent(kind, owned)
		if gain <= 0:
			continue
		# Most Power per Riftglass first; the cheaper offer wins a tie.
		if best.is_empty() or gain * int(best.rg_price) > best_gain * int(o.rg_price) \
				or (gain * int(best.rg_price) == best_gain * int(o.rg_price) and int(o.rg_price) < int(best.rg_price)):
			best = o
			best_gain = gain
	if best.is_empty():
		return ""
	return Loc.t("Shop: %s adds %d Power") % [Loc.t(str(best.name)), best_gain]
