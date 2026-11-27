class_name RiftglassSinks
extends RefCounted
## Riftglass in play (Ali, 27 Nov 2026: "diese Waehrung ... im Spiel richtig rein"). Bought
## Riftglass is spent where the player needs it, at fixed prices from data/riftglass_sinks.json:
## - "continue": a lost story battle goes on, the whole team back with full Vigor (price rises
##   per continue in the same battle, at most continue_max()). Never in leagues, duels, raids,
##   halls or on Rift-Born (continue_allowed).
## - "heal": the whole team fully healed anywhere outside battle.
## - "bond_boost": +bond_boost() on one bond try, fixed, chosen before the Echo call.
## - "trip_skip": a roaming trip comes home now, price per started hour left.
## - "lamp_relight": the Lamp Watch lamp can be lit again today.
## - "warden_retry": after a lost Warden battle, stay right before the Warden, team rested.
## - "growth_x2": Growth x2 for the next battles.
## The server (public.rg_spend, migration 20261127120000_rg_sinks.sql) has the same price table
## and takes the Riftglass; the game applies the effect only after it said ok. A small free
## amount comes once a day (public.rg_daily_claim), so every player learns the currency.
## Children's accounts (under 13) see none of this and never a shop pointer.

const PATH: String = "res://data/riftglass_sinks.json"
const REASONS: Array[String] = ["continue", "heal", "bond_boost", "trip_skip", "lamp_relight", "warden_retry", "growth_x2"]
## Trainer keys a wild battle may carry and still be a plain story battle.
const WILD_KEYS: Array[String] = ["ambush", "model", "resume", "backdrop", "name"]
## Model meta: Riftglass may be used in this battle (story battle, set by the overworld).
const STORY_META: String = "rg_story"
## Highest bond boost a replay accepts.
const BOND_BOOST_MAX: float = 0.5

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = v if v is Dictionary else {}
	return _data

static func sink(reason: String) -> Dictionary:
	var s: Variant = data().get("sinks", {}).get(reason, {})
	return s if s is Dictionary else {}

static func daily_rg() -> int:
	return int(data().get("daily_rg", 0))

## Price of [param reason]; [param used] is how often it was used for this battle already
## (continue), [param hours] the started hours left (trip skip). 0 means it cannot be bought.
static func price(reason: String, used: int = 0, hours: int = 0) -> int:
	var s: Dictionary = sink(reason)
	match reason:
		"continue":
			var p: Array = s.get("prices", [])
			return int(p[used]) if used >= 0 and used < mini(p.size(), continue_max()) else 0
		"trip_skip":
			if hours < 1 or hours > int(s.get("max_hours", 0)):
				return 0
			return hours * int(s.get("price_per_hour", 0))
	return int(s.get("price", 0))

static func continue_max() -> int:
	var s: Dictionary = sink("continue")
	return mini((s.get("prices", []) as Array).size(), int(s.get("max_per_ref", 0)))

static func bond_boost() -> float:
	return clampf(float(sink("bond_boost").get("bonus", 0.0)), 0.0, BOND_BOOST_MAX)

static func growth_battles() -> int:
	return int(sink("growth_x2").get("battles", 0))

static func growth_mult() -> float:
	return float(sink("growth_x2").get("mult", 1.0))

## Started hours in [param seconds] (59 min left = 1 hour).
static func hours_left(seconds: int) -> int:
	return ceili(maxf(0.0, float(seconds)) / 3600.0)

# --- Where Riftglass may be used -------------------------------------------------------------

## True for a battle against the world where a continue is fair: a story Wayfarer or Warden
## (TrainerData.battle_info "story") or a plain wild battle. Not in echo duels, friendly or
## practice bouts, leagues and raids (a ready model from the server), halls, towers and
## challenge runs, and not on Rift-Born or where items are not allowed.
static func continue_allowed(trainer: Dictionary, wild: bool, difficulty: int, items_allowed: bool) -> bool:
	if difficulty == GameState.Difficulty.RIFT_BORN or not items_allowed:
		return false
	if trainer.has("player_team") or bool(trainer.get("friendly", false)) or bool(trainer.get("practice", false)):
		return false
	if bool(trainer.get("story", false)):
		return not trainer.has("model")
	if not wild:
		return false
	for k: Variant in trainer:
		if not str(k) in WILD_KEYS:
			return false
	return not trainer.has("model") or trainer.has("resume")

## Riftglass can be used right now: online, the shop state is known and the account is not a
## child's. Nothing about Riftglass is shown otherwise.
static func visible() -> bool:
	return not OS.has_feature("web") and Online.is_online() and Billing.state.has("balance") and not Billing.kids_locked()

## Why [param cost] cannot be paid now ("" = it can).
static func why_not(cost: int) -> String:
	if OS.has_feature("web") or not Online.is_online() or not Billing.state.has("balance"):
		return "offline"
	if Billing.kids_locked():
		return "age"
	if bool(Billing.state.get("locked", false)):
		return "limit_reached"
	if cost <= 0:
		return "not_available"
	if Billing.balance() < cost:
		return "not_enough"
	return ""

## Pays [param cost] Riftglass for [param reason] on the server. [param ref] is the battle
## (continue, bond boost), the started hours left (trip skip) or "". Returns the server's
## answer ({"ok": true, "balance": n} or {"ok": false, "error": ...}).
static func spend(reason: String, ref: String, cost: int) -> Dictionary:
	var why: String = why_not(cost)
	if not why.is_empty():
		return {"ok": false, "error": why}
	var r: Dictionary = await Online.call_fn("rg_spend", {"p_reason": reason, "p_ref": ref, "p_expected": cost})
	if not r.ok:
		return {"ok": false, "error": "offline" if bool(r.get("net", false)) else str(r.get("error", "error"))}
	var d: Dictionary = r.data if r.data is Dictionary else {}
	if d.has("balance"):
		Billing.state["balance"] = int(d.balance)
	return d

## The free Riftglass of the day, once per day and account (server day, Europe/Berlin).
## Returns the Riftglass added (0 = already taken today, offline or a child's account).
static func claim_daily() -> int:
	if not Online.is_online():
		return 0
	var r: Dictionary = await Online.call_fn("rg_daily_claim")
	if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
		return 0
	if r.data.has("balance") and Billing.state.has("balance"):
		Billing.state["balance"] = int(r.data.balance)
	return int(r.data.get("added", 0))

# --- Texts -----------------------------------------------------------------------------------

## "Heal the team: 100 Riftglass (≈ 0,99 €)" style price line.
static func cost_text(cost: int) -> String:
	return ShopCatalog.rg_text(cost)

static func balance_line() -> String:
	return Loc.t("You have %d Riftglass.") % Billing.balance()

## A clear line why it did not work. Never a purchase prompt; children get no shop pointer.
static func error_text(why: String, cost: int = 0) -> String:
	match why:
		"not_enough":
			return Loc.t("Not enough Riftglass: this costs %d, you have %d.") % [cost, Billing.balance()]
		"offline":
			return Loc.t("No connection right now. Riftglass needs the server.")
		"age":
			return Loc.t("Riftglass is not available on this account.")
		"limit_reached":
			return Loc.t("Riftglass is locked for now. Look in the shop under My purchases.")
		"used_up":
			return Loc.t("That was the last one here.")
		"slow_down":
			return Loc.t("That was a lot in a short time. Please wait a while.")
		"price_changed":
			return Loc.t("The price has changed. Please look again.")
	return Loc.t("That did not work. No Riftglass was taken.")

## The shop's Riftglass page, for the "not enough" message outside battle. Children's accounts
## never get here (their rows are hidden); the age question comes first like in the shop.
static func open_riftglass_page(menu: MenuHost) -> void:
	if OS.has_feature("web") or Billing.kids_locked():
		return
	var r: Dictionary = await Billing.refresh_state()
	if not r.ok:
		await menu.info(error_text("offline"))
		return
	if Billing.band() == null:
		if await AgeGate.run(menu) < 0:
			return
		await Billing.refresh_state()
	if Billing.kids_locked():
		await menu.info(ShopMenu.LOCKED_TEXT)
		return
	await ShopMenu._query_prices()
	await ShopMenu._run_tab(menu, "riftglass")

## Pays [param cost] for [param reason] from a menu outside battle: asks first with the price,
## says why when it cannot, and offers the shop's Riftglass page when Riftglass is short (not
## with [param shop_link] false, e.g. right after a defeat). True once the server took the
## Riftglass (the caller then applies the effect).
static func pay_in_menu(menu: MenuHost, reason: String, ref: String, cost: int, question: String, shop_link: bool = true) -> bool:
	if not visible():
		await menu.info(error_text(why_not(cost), cost))
		return false
	var why: String = why_not(cost)
	if why == "not_enough" and shop_link:
		if await menu.confirm(error_text(why, cost), "Riftglass shop", "Back"):
			await open_riftglass_page(menu)
		return false
	if not why.is_empty():
		await menu.info(error_text(why, cost))
		return false
	if not await menu.confirm(question + "\n" + cost_text(cost) + "\n" + balance_line(), "Use", "Back"):
		return false
	var d: Dictionary = await spend(reason, ref, cost)
	if not bool(d.get("ok", false)):
		await menu.info(error_text(str(d.get("error", "")), cost))
		return false
	Sound.sfx("coin")
	return true

## "Riftglass" in the pause menu: heal the team anywhere, Growth x2, and the shop's Riftglass
## page. Only shown while visible().
static func run_menu(menu: MenuHost) -> void:
	while true:
		var rows: Array[Dictionary] = [
			{"text": Loc.t("Heal team: %d") % price("heal")},
			{"text": Loc.t("Growth x2: %d") % price("growth_x2")},
			{"text": "Riftglass shop"}]
		var i: int = await menu.pick(Loc.t("Riftglass") + "\n" + ShopMenu.balance_text(), rows)
		match i:
			0:
				if await pay_in_menu(menu, "heal", "", price("heal"), Loc.t("Heal the whole team now? Full Vigor, Energy, no states.")):
					GameState.heal_party()
					Sound.sfx("heal")
					await menu.info("Your team is fully rested.")
			1:
				if growth_blocked():
					await menu.info("A stronger boost is still working.")
				elif await pay_in_menu(menu, "growth_x2", "", price("growth_x2"), Loc.t("Growth x2 for the next %d battles?") % growth_battles()):
					apply_growth()
					await menu.info("  ".join(ShopEffects.boost_lines()))
			2:
				await open_riftglass_page(menu)
			_:
				return

# --- Effects (only after the server said ok) -------------------------------------------------

## Growth x2 for the next growth_battles() battles. A stronger running boost is never replaced
## (asked before paying, growth_blocked); the same one adds its battles.
static func growth_blocked() -> bool:
	var cur: Dictionary = GameState.shop_boosts.get("growth", {})
	return not cur.is_empty() and float(cur.get("mult", 1.0)) > growth_mult()

static func apply_growth() -> void:
	var cur: Dictionary = GameState.shop_boosts.get("growth", {})
	var left: int = growth_battles()
	if not cur.is_empty() and is_equal_approx(float(cur.get("mult", 1.0)), growth_mult()):
		left += int(cur.get("left", 0))
	GameState.shop_boosts["growth"] = {"mult": growth_mult(), "left": left}

## The trip [param t] is home now: its start moves back so the time is up.
static func apply_trip_skip(t: Dictionary) -> void:
	var list: Array = GameState.records.get("expeditions", [])
	for x: Variant in list:
		if x is Dictionary and str(x.get("uid", "")) == str(t.get("uid", "")) and int(x.get("start", 0)) == int(t.get("start", 0)):
			x["start"] = Online.unix_now() - int(x.get("hours", 0)) * 3600
	GameState.records["expeditions"] = list

## The lamp can be lit again today.
static func apply_lamp_relight(records: Dictionary) -> void:
	var st: Dictionary = LampWatch.state(records).duplicate()
	st["last_day"] = ""
	records[LampWatch.RECORD] = st
