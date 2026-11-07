class_name TradeMenu
extends RefCounted
## Trading items between friends (plan area 7, items 2791-2795, 2900). Only friends from
## friendship level 3 who have been friends for 7 days, only items marked "tradeable" (never shop
## items, never Spirlings). The server is the trustee: what you put in leaves your bag at once and
## waits there; once both confirmed the same offers, each side collects the other's items.
## Opened from Friends when the "trade" flag is on.

const ERRORS: Dictionary = {
	"feature_off": "Trading is closed right now.",
	"no_such_code": "You can only trade with friends.",
	"friend_level": "Trading opens at friendship level 3.",
	"too_new": "You can trade once you have been friends for 7 days.",
	"too_many": "You have 5 open trades. Finish one first.",
	"no_such_trade": "That trade is over.",
	"partner_gone": "This friend cannot trade with you any more. End the trade to get your items back.",
	"not_tradeable": "That item cannot be traded.",
	"not_enough": "You do not have that many.",
	"sync_first": "Your journey is still being saved. Try again in a moment.",
	"no_save": "Save your journey first, then try again.",
	"changed": "Your friend just changed the offer. Look at it again.",
	"empty": "Put something in first.",
	"already": "You already took these items.",
	"under_review": "Your account is being checked. Trading opens again after the check.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else FriendsMenu.error_text(r)

static func item_name(id: String) -> String:
	var it: Dictionary = Database.item(id)
	return Loc.t(str(it.get("name", id))) if not it.is_empty() else id

## "Tonic x3, Keen Lens" or "nothing".
static func offer_text(items: Variant) -> String:
	if not items is Dictionary or (items as Dictionary).is_empty():
		return Loc.t("nothing")
	var keys: Array = (items as Dictionary).keys()
	keys.sort()
	var parts: Array[String] = []
	for k: Variant in keys:
		var n: int = int(items[k])
		parts.append(item_name(str(k)) if n == 1 else "%s x%d" % [item_name(str(k)), n])
	return ", ".join(parts)

static func trade_line(t: Dictionary) -> String:
	var who: String = str(t.name) if t.get("name") != null else Loc.t("a former friend")
	var state: String
	if bool(t.get("collect", false)):
		state = Loc.t("done, take your items") if str(t.state) == "done" else Loc.t("ended, take your items back")
	elif bool(t.get("their_ok", false)):
		state = Loc.t("your friend confirmed")
	elif bool(t.get("my_ok", false)):
		state = Loc.t("you confirmed")
	else:
		state = Loc.t("open")
	return "%s  %s" % [who, state]

## Applies the bag change the server made to the stored save, on this device too, so both stay
## the same and the next save goes on top of the server's new revision.
static func apply_bag(bag: Variant, rev: int) -> void:
	var slot: int = SaveManager.slot
	if bag is Dictionary:
		for k: Variant in bag:
			GameState.add_item(str(k), int(bag[k]))
			if GameState.item_count(str(k)) <= 0:
				GameState.inventory.erase(str(k))
	Online.revs[slot] = rev
	Online._save_session()
	SaveManager.save_game()

## Calls a trade function that changes the bag: first makes sure the server has this journey,
## then sends the revision this device knows.
static func bag_call(fn: String, args: Dictionary) -> Dictionary:
	var slot: int = SaveManager.slot
	SaveManager.save_game()
	if not await Online.push(slot):
		return {"ok": true, "data": {"ok": false, "error": "sync_first"}}
	var full: Dictionary = args.duplicate()
	full["p_slot"] = slot
	full["p_rev"] = int(Online.revs.get(slot, 0))
	var r: Dictionary = await Online.call_fn(fn, full)
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		apply_bag(r.data.get("bag", {}), int(r.data.rev))
	return r

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

static func run(menu: PauseMenu) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("trade_list")
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var trades: Array = r.data.get("trades", [])
		var labels: Array[String] = []
		for t: Dictionary in trades:
			labels.append(trade_line(t))
		labels.append_array(["New trade...", "How trading works"] as Array[String])
		var idx: int = await menu.pick_strings("Trades", labels)
		if idx < 0:
			return
		if idx < trades.size():
			await _run_trade(menu, trades[idx], r.data.get("items", []))
		elif idx == trades.size():
			await open(menu)
		else:
			await menu.info("Friends from friendship level 3 who have been friends for 7 days can trade items. Spirlings and shop items are never traded. What you put in waits safely on the server. When you both confirm, you both get the other's items. If one of you changes the offer, both have to confirm again.")

static func open(menu: PauseMenu) -> void:
	var f: Dictionary = await Online.call_fn("friends_list")
	var friends: Array = f.data.get("friends", []) if f.ok and f.data is Dictionary else []
	if friends.is_empty():
		await menu.info("Trading is for friends. Add a friend first.")
		return
	var labels: Array[String] = []
	for x: Dictionary in friends:
		labels.append(str(x.name))
	var idx: int = await menu.pick_strings("Trade with whom?", labels)
	if idx < 0:
		return
	var r: Dictionary = await Online.call_fn("trade_open", {"p_code": str(friends[idx].code)})
	if _ok(r):
		Sound.sfx("confirm")
		await menu.info("The trade is open for 7 days. Put in what you want to give.")
	else:
		await menu.info(error_text(r))

static func _run_trade(menu: PauseMenu, t: Dictionary, tradeable: Array) -> void:
	var id: int = int(t.id)
	var title: String = "%s\n%s\n%s" % [trade_line(t), Loc.t("You give: %s") % offer_text(t.mine),
		Loc.t("You get: %s") % offer_text(t.theirs)]
	var opts: Array[String] = []
	if bool(t.get("collect", false)):
		opts.append("Take the items")
	else:
		opts.append_array(["Change my offer", "Confirm this trade", "End the trade"] as Array[String])
	if t.get("code") != null:
		opts.append("Report")
	var idx: int = await menu.pick_strings(title, opts)
	if idx < 0:
		return
	var r: Dictionary
	match opts[idx]:
		"Take the items":
			r = await bag_call("trade_collect", {"p_trade": id})
			if _ok(r):
				Sound.sfx("coin")
				await menu.info(Loc.t("You got: %s") % offer_text(r.data.get("bag", {})))
				return
		"Change my offer":
			var offer: Variant = await pick_offer(menu, t.mine, tradeable)
			if offer == null:
				return
			r = await bag_call("trade_put", {"p_trade": id, "p_items": offer})
			if _ok(r):
				await menu.info("Your offer is in. Both of you have to confirm again.")
				return
		"Confirm this trade":
			if not await menu.confirm(Loc.t("Give %s and get %s?") % [offer_text(t.mine), offer_text(t.theirs)]):
				return
			r = await Online.call_fn("trade_confirm", {"p_trade": id, "p_theirs": t.theirs})
			if _ok(r):
				Sound.sfx("confirm")
				await menu.info("Traded! Take your items now." if bool(r.data.get("done", false)) else "Confirmed. Now your friend has to confirm.")
				return
		"End the trade":
			if not await menu.confirm("End this trade? You both get your own items back."):
				return
			r = await Online.call_fn("trade_cancel", {"p_trade": id})
			if _ok(r):
				r = await bag_call("trade_collect", {"p_trade": id})
				if _ok(r):
					await menu.info("The trade is over. Your items are back in your bag.")
					return
		"Report":
			await FriendsMenu.report(menu, str(t.code), str(t.name), "trade")
			return
	await menu.info(error_text(r))

## Lets the player set the full offer: the bag's tradeable items and the counts. Null if left.
static func pick_offer(menu: PauseMenu, current: Variant, tradeable: Array) -> Variant:
	var offer: Dictionary = (current as Dictionary).duplicate() if current is Dictionary else {}
	while true:
		var ids: Array[String] = []
		for k: String in GameState.inventory:
			if tradeable.has(k) and GameState.item_count(k) + int(offer.get(k, 0)) > 0:
				ids.append(k)
		for k: Variant in offer:
			if not ids.has(str(k)):
				ids.append(str(k))
		ids.sort()
		var labels: Array[String] = []
		for k: String in ids:
			labels.append("%s  %d / %d" % [item_name(k), int(offer.get(k, 0)), GameState.item_count(k) + int(offer.get(k, 0))])
		labels.append(Loc.t("Done: %s") % offer_text(offer))
		var idx: int = await menu.pick_strings("What do you give? (up to 6 kinds)", labels)
		if idx < 0:
			return null
		if idx == ids.size():
			return offer
		var k: String = ids[idx]
		var have: int = GameState.item_count(k) + int(offer.get(k, 0))
		var counts: Array[String] = []
		for n: int in range(0, mini(have, 10) + 1):
			counts.append(str(n))
		if have > 10:
			counts.append(str(have))
		var ci: int = await menu.pick_strings(Loc.t("How many %s?") % item_name(k), counts)
		if ci < 0:
			continue
		var n: int = int(counts[ci])
		if n == 0:
			offer.erase(k)
		elif offer.has(k) or offer.size() < 6:
			offer[k] = n
		else:
			await menu.info("Up to 6 kinds of items per trade.")
	return null
