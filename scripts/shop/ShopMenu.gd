class_name ShopMenu
extends RefCounted
## The shop (items 4177-4184), opened only from the menu by the player (item 4028).
## Tabs: Advantages, Packs, Pass, Looks, Riftglass, plus My purchases, Spending limit and About.
## Rows show name and price; "+" marks an advantage in the game. Prices in euro come from the store;
## Riftglass prices always show their euro value. No direct purchase prompts (UWG annex no. 28).

const ADVANTAGE_MARK: String = "+ "
const RG_NO_VALUE: String = "Riftglass has no money value and cannot be changed back into euro or passed on."
const LOCKED_TEXT: String = "The shop is closed for your age. Ask a grown-up."
const ABOUT_TEXT: String = "About purchases:\n- Chimora is free. Everything in the shop is optional.\n- Each offer gives exactly what it lists. Nothing is random.\n- \"+\" marks an advantage in the game. In the Fair League bought advantages do not count.\n- Riftglass is a right to use, it has no money value and cannot be changed back.\n- Payment and refunds go through Apple or Google.\n- Monthly limits protect you: 15 EUR (13-15), 30 EUR (16-17), adults choose up to 300 EUR."
const WEB_TEXT: String = "The shop is only in the app for iPhone and Android. The browser test version cannot buy anything."
const WITHDRAWAL_TEXT: String = "Before your first purchase: digital goods are delivered at once. You agree that the right of withdrawal ends when the delivery starts. Refunds go through Apple or Google."

static func run(menu: MenuHost) -> void:
	# Item 4111: the browser test version cannot buy; the shop lives in the apps only.
	if OS.has_feature("web"):
		await menu.info(WEB_TEXT)
		return
	var r: Dictionary = await Billing.refresh_state()
	if not r.ok:
		await menu.info("No connection right now. Try again in a moment.")
		return
	if not bool(Billing.state.get("open", true)):
		await menu.info("The shop is closed for a moment. Please look again later.")
		return
	if Billing.band() == null:
		if await AgeGate.run(menu) < 0:
			return
		await Billing.refresh_state()
	if Billing.kids_locked():
		await menu.info(LOCKED_TEXT)
		return
	await _query_prices()
	await Billing.claim()
	while true:
		var entries: Array[String] = []
		for t: String in ShopCatalog.TABS:
			entries.append(ShopCatalog.TAB_NAMES[t])
		entries.append_array(["My purchases", "Spending limit", "About purchases", "Help with purchases"])
		# Apple guideline 3.1.1: bought unlocks and the pass can be restored (only with a store).
		if Billing.available():
			entries.append("Restore purchases")
		var idx: int = await menu.pick_strings(title(), entries)
		if idx < 0:
			return
		if idx < ShopCatalog.TABS.size():
			await _run_tab(menu, ShopCatalog.TABS[idx])
		elif entries[idx] == "My purchases":
			await _run_history(menu)
		elif entries[idx] == "Spending limit":
			await _run_limit(menu)
		elif entries[idx] == "Help with purchases":
			await run_help(menu)
		elif entries[idx] == "Restore purchases":
			var n: int = await Billing.restore()
			await menu.info(Loc.t("Restored: %d purchases.") % n if n > 0 else Loc.t("Nothing to restore. Bought unlocks and the pass are already here."))
		else:
			await menu.info(ABOUT_TEXT)

## The help page on Riftglass, the pass, refunds and limits (/kaeufe or /purchases, item 4045).
static func run_help(menu: Node) -> void:
	var url: String = LegalInfo.purchases_url()
	var text: String = Loc.t("Help with purchases: Riftglass, the pass, refunds and spending limits.") + "\n" + url
	if await menu.pick_strings(text, ["Open the page", "Back"] as Array[String]) == 0:
		OS.shell_open(url)

## "Shop  Riftglass 500 (≈ 4,95 €)" (item 4183).
static func title() -> String:
	return Loc.t("Shop") + "\n" + ShopCatalog.rg_text(Billing.balance())

static func _query_prices() -> void:
	var ids: Array[String] = []
	for o: Dictionary in ShopCatalog.offers():
		if bool(o.get("ready", false)):
			ids.append(str(o.product_id))
	await Billing.query_products(ids)

## The price shown in a row: Riftglass if it has one, otherwise the store's price text.
static func row_price(o: Dictionary) -> String:
	if int(o.get("rg_price", 0)) > 0:
		return Loc.t("%d Riftglass") % int(o.rg_price)
	var p: String = Billing.price_text(o)
	return p if not p.is_empty() else "-"

static func row_text(o: Dictionary) -> String:
	return (ADVANTAGE_MARK if ShopCatalog.is_advantage(o) else "") + Loc.t(str(o.name)) + "  " + row_price(o)

static func _run_tab(menu: MenuHost, tab: String) -> void:
	while true:
		var list: Array[Dictionary] = ShopCatalog.in_tab(tab)
		if list.is_empty():
			await menu.info("Nothing here yet. New offers come with updates.")
			return
		var entries: Array[Dictionary] = []
		for o: Dictionary in list:
			entries.append({"text": row_text(o), "disabled": Billing.block_reason(o, int(o.rg_price) > 0) in ["offer_limit", "not_yet"]})
		var idx: int = await menu.pick(Loc.t(ShopCatalog.TAB_NAMES[tab]) + "  " + ShopCatalog.rg_text(Billing.balance()), entries)
		if idx < 0:
			return
		await _run_offer(menu, list[idx])

## The Wayfarer Pass page (items 4636, 4651, 4652): every benefit with its number, the price per
## month, that it renews by itself and how to cancel, and whether it runs now.
static func pass_text(o: Dictionary) -> String:
	var rg: int = PASS_DAILY_RG
	var lines: Array[String] = [Loc.t(str(o.name)), Loc.t("Advantage in the game"), "", pass_status_text(), "", Loc.t("What the pass gives:")]
	lines.append("- " + Loc.t("+%d%% growth for the whole team, also together with a Growth Crystal") % roundi((ShopEffects.PASS_GROWTH - 1.0) * 100.0))
	lines.append("- " + Loc.t("%d Riftglass every day (%d in 30 days), missed days paid up to 7 days later") % [rg, rg * 30])
	lines.append("- " + Loc.t("+%d energy over the maximum in battles against the world (11 of 10)") % ShopEffects.PASS_ENERGY)
	lines.append("- " + Loc.t("1 extra Rift Breath in every Warden battle (only in that battle)"))
	lines.append("- " + Loc.t("1 extra bond try per battle: the first failed bond gives no free action"))
	lines.append("")
	lines.append(Loc.t("In echo duels only the growth works."))
	lines.append(Loc.t("Works in the Open League, not in the Fair League."))
	lines.append(Loc.t("When the pass ends, every benefit ends at once. Riftglass and items you got stay yours."))
	lines.append("")
	lines.append(Loc.t("Price: %s per month, renews automatically.") % ShopCatalog.format_eur(int(o.get("eur_cents", 0))))
	lines.append(Loc.t("Cancel any time in the App Store or Google Play."))
	var band: Variant = Billing.state.get("band")
	if band != null and int(band) < 18:
		# Item 4046: minors start and renew the pass only with the parents' OK in the store.
		lines.append(Loc.t("Under 18: ask your parents first. Every renewal needs their OK in the store."))
	var p: String = Billing.price_text(o)
	if not p.is_empty():
		lines.append(Loc.t("Price in the store: %s") % p)
	return "\n".join(lines)

## The pass's daily Riftglass when the server sent no number (server_config shop_pass_daily).
const PASS_DAILY_RG: int = 30

## "Your pass runs until 6. 12." or "No pass right now." (item 4653).
static func pass_status_text() -> String:
	var u: Variant = Billing.state.get("pass_until")
	var until: int = int(u) if u is int or u is float else 0
	if not ShopEffects.pass_active() or until <= 0:
		return Loc.t("No pass right now.")
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(until + Time.get_time_zone_from_system().get("bias", 0) * 60)
	return Loc.t("Your pass runs until %s.") % ("%d. %d." % [int(d.day), int(d.month)])

## Detail view (item 4181): full contents, exact effect, duration, league effect, then the price options.
static func detail_text(o: Dictionary) -> String:
	if str(o.get("store_type", "")) == "subscription":
		return pass_text(o)
	var lines: Array[String] = [Loc.t(str(o.name))]
	if ShopCatalog.is_advantage(o):
		lines.append(Loc.t("Advantage in the game"))
	lines.append(Loc.t(str(o.desc)))
	lines.append("")
	lines.append(Loc.t("Contents:"))
	for g: String in ShopCatalog.grant_lines(o):
		lines.append("- " + g)
	match str(o.get("duration", "once")):
		"permanent":
			lines.append(Loc.t("Lasts: for good"))
		"monthly":
			lines.append(Loc.t("Lasts: while the pass runs"))
		"once":
			lines.append(Loc.t("Lasts: used up when used"))
		var d:
			lines.append(Loc.t("Lasts: %s") % Loc.t(d))
	match str(o.get("league_scope", "none")):
		"open":
			lines.append(Loc.t("Works in the Open League, not in the Fair League."))
		"look":
			lines.append(Loc.t("Only looks. Visible everywhere, no effect."))
		_:
			lines.append(Loc.t("Does not work in leagues."))
	var lim: String = limit_line(o)
	if not lim.is_empty():
		lines.append(lim)
	lines.append("")
	if str(o.get("tab", "")) == "packs" and ShopCatalog.single_value(o) > 0:
		lines.append(Loc.t("Worth one by one: %s") % ShopCatalog.rg_text(ShopCatalog.single_value(o)))
	# Under every Riftglass pack (item 4034).
	if str(o.get("kind", "")) == "currency":
		lines.append(Loc.t(RG_NO_VALUE))
	if int(o.get("rg_price", 0)) > 0:
		lines.append(Loc.t("Price: %s") % ShopCatalog.rg_text(int(o.rg_price)))
	var p: String = Billing.price_text(o)
	if not p.is_empty():
		lines.append(Loc.t("Price in the store: %s") % p)
	return "\n".join(lines)

## How often an offer can be bought, as a plain rule, never as a countdown like "only 3 left" (item 4042).
static func limit_line(o: Dictionary) -> String:
	var lim: Variant = o.get("limit")
	if not lim is Dictionary:
		return ""
	var n: int = int(lim.get("n", 1))
	if str(lim.get("per", "account")) == "week":
		return Loc.t("Once a week per account.") if n == 1 else Loc.t("Up to %d times a week per account.") % n
	return Loc.t("Once per account.") if n == 1 else Loc.t("Up to %d times per account.") % n

static func _run_offer(menu: MenuHost, o: Dictionary) -> void:
	# An owned jacket, backdrop or text frame is worn or taken off here (items 4277, 4281).
	if str(o.get("slot", "")) == "gift_card" and Billing.unlocked("gift_card_" + FriendsMenu.GIFT_CARDS.keys()[0]) > 0:
		await _run_gift_cards(menu)
		return
	var key: String = look_key(o)
	if not key.is_empty() and Billing.unlocked(key) > 0:
		await _run_wear(menu, o, key)
		return
	# Looks are shown before they are bought (item 4291).
	await menu.info(detail_text(o) + ShopPreview.preview_text(o), await ShopPreview.picture(o, menu))
	var options: Array[String] = []
	var kinds: Array[bool] = []
	if int(o.get("rg_price", 0)) > 0:
		options.append(Loc.t("Pay with Riftglass: %d") % int(o.rg_price))
		kinds.append(true)
	if not Billing.price_text(o).is_empty():
		options.append(Loc.t("Pay in the store: %s") % Billing.price_text(o))
		kinds.append(false)
	if options.is_empty():
		await menu.info("Purchases are only possible in the app from the App Store or Google Play.")
		return
	var idx: int = await menu.pick_strings(Loc.t(str(o.name)), options)
	if idx < 0:
		return
	var choice: Variant = null
	if o.get("choice") is Array:
		choice = await _pick_choice(menu, o)
		if choice == null:
			return
	if not await _withdrawal_ok(menu):
		return
	var with_rg: bool = kinds[idx]
	var why: String = Billing.block_reason(o, with_rg)
	if not why.is_empty():
		await menu.info(reason_text(why))
		return
	var r: Dictionary
	if with_rg:
		var after: int = Billing.balance() - int(o.rg_price)
		var q: String = Loc.t("Spend %d Riftglass? Your balance after: %s") % [int(o.rg_price), ShopCatalog.rg_text(after)]
		# "No" comes first and is selected (item 4182).
		if await menu.pick_strings(q, ["No", "Yes"] as Array[String]) != 1:
			return
		r = await Billing.buy_with_riftglass(o, choice)
	else:
		r = await Billing.buy_in_store(o, choice)
	if bool(r.get("ok", false)):
		Sound.sfx("save")
		await menu.info(Loc.t("Done. %s is yours.") % Loc.t(str(o.name)))
	elif str(r.get("error", "")) != "cancelled":
		await menu.info(reason_text(str(r.get("error", ""))))

## The unlock key of a jacket offer ("" for any other offer).
static func jacket_key(o: Dictionary) -> String:
	var g: Array = o.get("grants", [])
	if not o.has("color") or g.size() != 1 or not g[0] is Dictionary:
		return ""
	return str(g[0].get("id", ""))

## The unlock key of a look that can be worn now: a jacket, battle backdrop, text frame, hat or profile frame ("" otherwise).
static func look_key(o: Dictionary) -> String:
	var j: String = jacket_key(o)
	if not j.is_empty():
		return j
	var g: Array = o.get("grants", [])
	if str(o.get("tab", "")) == "looks" and g.size() == 1 and g[0] is Dictionary and (str(g[0].get("id", "")).begins_with("backdrop_") or str(g[0].get("id", "")).begins_with("frame_") or str(g[0].get("id", "")).begins_with("hat_") or str(g[0].get("id", "")).begins_with("card_frame_")):
		return str(g[0].id)
	return ""

## Owned looks that can be put on or off (wardrobe, item 4287): jackets, backdrops, text frames,
## hats, profile frames and the gift card set, in catalog order.
static func owned_looks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Dictionary in ShopCatalog.offers():
		if str(o.get("tab", "")) != "looks":
			continue
		if str(o.get("slot", "")) == "gift_card":
			if Billing.unlocked("gift_card_" + FriendsMenu.GIFT_CARDS.keys()[0]) > 0:
				out.append(o)
			continue
		var key: String = look_key(o)
		if not key.is_empty() and Billing.unlocked(key) > 0:
			out.append(o)
	return out

## True when the look of [param o] is in use now.
static func look_in_use(o: Dictionary) -> bool:
	if str(o.get("slot", "")) == "gift_card":
		return not GameState.gift_motif().is_empty()
	var key: String = look_key(o)
	return not key.is_empty() and key in [GameState.jacket, GameState.backdrop_look, GameState.text_frame, GameState.hat_look, GameState.card_frame]

## The wardrobe (item 4287): every bought look, put on or taken off here. Opened from Team and
## from Settings.
static func run_wardrobe(menu: MenuHost) -> void:
	while true:
		var looks: Array[Dictionary] = owned_looks()
		if looks.is_empty():
			await menu.info("Your wardrobe is empty. Looks you get in the shop show up here.")
			return
		var names: Array[String] = []
		for o: Dictionary in looks:
			names.append(Loc.t(str(o.name)) + ("  " + Loc.t("(in use)") if look_in_use(o) else ""))
		var idx: int = await menu.pick_strings("Wardrobe", names)
		if idx < 0:
			return
		var o: Dictionary = looks[idx]
		if str(o.get("slot", "")) == "gift_card":
			await _run_gift_cards(menu)
		else:
			await _run_wear(menu, o, look_key(o))

## Names of the greeting card motifs in the set (item 4285), in FriendsMenu.GIFT_CARDS order.
const GIFT_CARD_NAMES: Array[String] = ["Gift Card: Lantern", "Gift Card: Moth", "Gift Card: Wave", "Gift Card: Pine",
	"Gift Card: Kite", "Gift Card: Moon", "Gift Card: Shell", "Gift Card: Ember"]

## The owned gift card set: pick the motif that goes on gifts, or the plain card.
static func _run_gift_cards(menu: MenuHost) -> void:
	var kinds: Array = FriendsMenu.GIFT_CARDS.keys()
	var options: Array[String] = []
	for i: int in kinds.size():
		var mark: String = "  " + Loc.t("(in use)") if GameState.gift_card == "gift_card_" + str(kinds[i]) else ""
		options.append(Loc.t(GIFT_CARD_NAMES[i]) + mark)
	options.append(Loc.t("Plain card"))
	var idx: int = await menu.pick_strings(Loc.t("Card for your gifts"), options)
	if idx < 0:
		return
	GameState.gift_card = "" if idx >= kinds.size() else "gift_card_" + str(kinds[idx])
	Online.push_profile()
	if GameState.gift_card.is_empty():
		await menu.info("Your gifts go out on the plain card again.")
	else:
		await menu.info(Loc.t("Your gifts now go out on %s.") % Loc.t(GIFT_CARD_NAMES[idx]))

static func _run_wear(menu: MenuHost, o: Dictionary, key: String) -> void:
	if key.begins_with("frame_"):
		var on: bool = GameState.text_frame == key
		if await menu.pick_strings(Loc.t(str(o.name)) + "  " + Loc.t("(yours)"), [("Stop using it" if on else "Use for text")] as Array[String]) != 0:
			return
		GameState.text_frame = "" if on else key
		await menu.info(Loc.t("Text shows in the plain box again.") if on else Loc.t("Text now shows in %s.") % Loc.t(str(o.name)))
		return
	if key.begins_with("card_frame_"):
		var used: bool = GameState.card_frame == key
		if await menu.pick_strings(Loc.t(str(o.name)) + "  " + Loc.t("(yours)"), [("Stop using it" if used else "Show to friends")] as Array[String]) != 0:
			return
		GameState.card_frame = "" if used else key
		Online.push_profile()
		await menu.info(Loc.t("Friends see your plain name again.") if used else Loc.t("Friends now see your name in %s.") % Loc.t(str(o.name)))
		return
	if key.begins_with("hat_"):
		var has_on: bool = GameState.hat_look == key
		if await menu.pick_strings(Loc.t(str(o.name)) + "  " + Loc.t("(yours)"), [("Take it off" if has_on else "Wear it")] as Array[String]) != 0:
			return
		GameState.hat_look = "" if has_on else key
		await menu.info(Loc.t("You take off the hat.") if has_on else Loc.t("You wear the %s.") % Loc.t(str(o.name)))
		return
	var backdrop: bool = key.begins_with("backdrop_")
	var wearing: bool = (GameState.backdrop_look if backdrop else GameState.jacket) == key
	var opt: String
	if backdrop:
		opt = "Stop using it" if wearing else "Use in battles"
	else:
		opt = "Take it off" if wearing else "Wear it"
	if await menu.pick_strings(Loc.t(str(o.name)) + "  " + Loc.t("(yours)"), [opt] as Array[String]) != 0:
		return
	if backdrop:
		GameState.backdrop_look = "" if wearing else key
		await menu.info(Loc.t("Battles show the place you are in again.") if wearing else Loc.t("Battles now show %s.") % Loc.t(str(o.name)))
		return
	GameState.jacket = "" if wearing else key
	await menu.info(Loc.t("You wear your own colour again.") if wearing else Loc.t("You wear the %s.") % Loc.t(str(o.name)))

static func _pick_choice(menu: MenuHost, o: Dictionary) -> Variant:
	var names: Array[String] = []
	for id: Variant in o.choice:
		names.append(str(ShopCatalog.offer(str(id)).get("name", id)))
	var i: int = await menu.pick_strings("Choose before buying", names)
	return null if i < 0 else str(o.choice[i])

static func _withdrawal_ok(menu: MenuHost) -> bool:
	if bool(Billing.state.get("withdrawal_ok", false)):
		return true
	await menu.info(WITHDRAWAL_TEXT)
	if await menu.pick_strings("Agree and continue?", ["No", "Yes"] as Array[String]) != 1:
		return false
	var r: Dictionary = await Online.call_fn("shop_withdrawal_ok")
	if r.ok:
		Billing.state["withdrawal_ok"] = true
	return r.ok

static func reason_text(why: String) -> String:
	match why:
		"not_enough": return "Not enough Riftglass."
		"limit", "limit_reached": return "Your monthly limit is reached. The shop opens again next month."
		"offer_limit": return "You already have this offer as often as it is sold."
		"not_yet": return "This offer comes later in the journey."
		"no_store": return "Purchases are only possible in the app from the App Store or Google Play."
		"age", "age_needed": return LOCKED_TEXT
		"offline": return "No connection right now. Try again in a moment."
		"price_changed": return "The price has changed. Please look again."
		"shop_closed": return "The shop is closed for a moment. Please look again later."
		"not_available": return "Nothing here yet. New offers come with updates."
		"pending": return "The purchase waits for approval. It arrives by itself once it is paid."
		"already_owned": return "You bought this before. It is being checked and arrives by itself."
		"declined": return "The payment was declined. Nothing was charged."
		"busy": return "A purchase is still running. Please wait a moment."
		"store_error", "verify_failed": return "The store did not answer. Nothing was charged twice: open purchases are checked again by themselves."
	return "Something unexpected happened. Nothing was charged twice: open purchases are checked again by themselves."

## "My purchases" (item 4184).
static func history_text(rows: Array) -> String:
	if rows.is_empty():
		return Loc.t("No purchases yet.")
	var lines: Array[String] = []
	for p: Variant in rows:
		if not p is Dictionary:
			continue
		var o: Dictionary = ShopCatalog.offer(str(p.offer))
		var price: String = Loc.t("%d Riftglass") % int(p.rg) if str(p.store) == "riftglass" else ShopCatalog.format_eur(int(p.eur_cents))
		var line: String = "%s  %s  %s" % [Time.get_date_string_from_unix_time(int(p.at)), Loc.t(str(o.get("name", p.offer))), price]
		if str(p.status) == "refunded":
			line += "  " + Loc.t("(refunded)")
		lines.append(line)
	return "\n".join(lines)

static func _run_history(menu: MenuHost) -> void:
	var r: Dictionary = await Online.call_fn("shop_history")
	if not r.ok:
		await menu.info("No connection right now. Try again in a moment.")
		return
	await menu.info(Loc.t("My purchases") + "\n\n" + history_text(r.data if r.data is Array else []))

static func limit_text() -> String:
	var s: Dictionary = Billing.state
	var t: String = Loc.t("Monthly limit: %s") % ShopCatalog.format_eur(int(s.get("cap_cents", 0)))
	t += "\n" + Loc.t("Spent this month: %s") % ShopCatalog.format_eur(int(s.get("spent_cents", 0)))
	if s.get("raise_to_cents") != null:
		t += "\n" + Loc.t("Raising to %s on %s") % [ShopCatalog.format_eur(int(s.raise_to_cents)),
			Time.get_date_string_from_unix_time(int(s.get("raise_at", 0)))]
	return t

static func _run_limit(menu: MenuHost) -> void:
	await Billing.refresh_state()
	if int(Billing.state.get("band", 0)) < 18:
		await menu.info(limit_text() + "\n\n" + Loc.t("This limit is fixed for your age group."))
		return
	var caps: Array[int] = [0, 1000, 2500, 5000, 10000, 20000, 30000]
	var entries: Array[String] = []
	for c: int in caps:
		entries.append(ShopCatalog.format_eur(c))
	var i: int = await menu.pick_strings(limit_text() + "\n" + Loc.t("Lower: at once. Higher: after 7 days."), entries)
	if i < 0:
		return
	var r: Dictionary = await Online.call_fn("shop_set_limit", {"p_cap_cents": caps[i]})
	await Billing.refresh_state()
	if not r.ok:
		await menu.info("No connection right now. Try again in a moment.")
		return
	await menu.info(limit_text())
