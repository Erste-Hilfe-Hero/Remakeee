class_name FriendsMenu
extends RefCounted
## Menu > Friends: friend code, friends with Wanderer cards, requests, Lantern Mail (greetings and
## daily gifts), the world goal of the week and the weekly board (items 21-48, 81-85, 121-160).
## Picking "Echo duel" closes the menu and leaves the friend's team in [member PauseMenu.echo_duel].

const REPORT_REASONS: Array[String] = ["Name not okay", "Unkind greetings", "Cheating", "Something else"]
const GOAL_TEXT: Dictionary = {
	"battles": "Win battles",
	"bonds": "Bond with wild Spirlings",
	"rests": "Rest your team at rest spots",
}

static func run(menu: PauseMenu) -> void:
	if not Online.is_online():
		await menu.info(Online.error_text())
		return
	if not Online.social_on():
		await menu.info("Friends and greetings are switched off. You can switch them on under Settings, Account.")
		return
	while true:
		var got: Array[Dictionary] = await fetch_lists(menu)
		var r: Dictionary = got[0]
		var mail_r: Dictionary = got[1]
		if not r.ok or not r.data is Dictionary:
			# Stay in the menu with "Try again" and "Back" (item 2149).
			var again: int = await menu.pick_strings(Online.error_text(r.error), ["Try again"] as Array[String])
			if again < 0:
				return
			continue
		var data: Dictionary = r.data
		var friends: Array = data.get("friends", [])
		var incoming: Array = data.get("incoming", [])
		var unread: int = 0
		if mail_r.ok and mail_r.data is Array:
			for m: Dictionary in mail_r.data:
				unread += 0 if bool(m.opened) else 1
		var labels: Array[String] = []
		for f: Dictionary in friends:
			labels.append(friend_line(f))
		var first_extra: int = labels.size()
		labels.append("Lantern Mail (%d new)" % unread if unread > 0 else "Lantern Mail")
		labels.append("Requests (%d)" % incoming.size() if incoming.size() > 0 else "Requests")
		labels.append("Add a friend...")
		labels.append("Copy my code")
		labels.append("World goal of the week")
		labels.append("Weekly board")
		labels.append("Blocked Wayfarers")
		if Online.flag_on("bund"):
			labels.append("Bund")
		if Online.flag_on("raid"):
			labels.append("Raid Rifts")
		if Online.flag_on("trade"):
			labels.append("Trades")
		if Online.flag_on("daily_gift"):
			labels.append("Daily gift")
		if Online.flag_on("live_duel"):
			labels.append("Live duels")
		labels.append("My wish list")
		if Online.flag_on("lend"):
			labels.append("Lent Spirlings")
		if Online.flag_on("events"):
			labels.append("Events")
		labels.append("Suggested Wayfarers")
		if Online.flag_on("invite"):
			labels.append("Invite a friend")
		var title: String = "Friends %d   Your code %s" % [friends.size(), Online.pretty_code(Online.friend_code())]
		var idx: int = await menu.pick_strings(title, labels)
		if idx < 0:
			return
		if idx < first_extra:
			if await run_friend(menu, friends[idx]):
				return
			continue
		match idx - first_extra:
			0: await run_mail(menu, mail_r.data if mail_r.data is Array else [])
			1: await run_requests(menu, incoming, data.get("outgoing", []))
			2: await add_friend(menu)
			3: copy_code(menu)
			4: await run_goal(menu)
			5: await run_boards(menu)
			6: await run_blocked(menu, data.get("blocked", []))
		match labels[idx]:
			"Bund": await BundMenu.run(menu)
			"Trades": await TradeMenu.run(menu)
			"Daily gift": await run_daily_gift(menu)
			"Live duels": await LiveDuelMenu.run(menu, friends)
			"My wish list": await run_wishes(menu)
			"Lent Spirlings": await run_loans(menu)
			"Events": await EventsMenu.run(menu)
			"Suggested Wayfarers": await FriendsMoreMenu.run_suggestions(menu)
			"Invite a friend": await FriendsMoreMenu.run_invite(menu)
			"Raid Rifts":
				await RaidMenu.run(menu)
				if not menu.raid_attempt.is_empty():
					return

## Friends and Lantern Mail are asked for at the same time, while the menu already shows
## "Loading..." (item 2129). Returns [friends_list result, mail_list result].
static func fetch_lists(menu: MenuHost) -> Array[Dictionary]:
	var got: Array[Dictionary] = [{}, {}]
	var done: Array[int] = [0]
	var ask := func(i: int, fn: String) -> void:
		got[i] = await Online.call_fn(fn)
		done[0] += 1
	ask.call(0, "friends_list")
	ask.call(1, "mail_list")
	if done[0] < 2:
		menu.picker.pick("Friends", [{"text": "Loading...", "disabled": true}] as Array[Dictionary], false)
		while done[0] < 2 and menu.is_inside_tree():
			await menu.get_tree().process_frame
		if menu.picker.visible:
			menu.picker.picked.emit(-1)
	return got

## Profile frames from the shop (item 4284): the marks drawn around a name on the friend
## list and the Wanderer card. Only looks.
const CARD_FRAMES: Dictionary[String, Array] = {
	"leaf": ["~", "~"], "shell": ["(", ")"], "gear": ["[", "]"],
	"star": ["+", "+"], "ripple": ["=", "="], "ember": ["^", "^"],
}

## Greeting card motifs from the shop (item 4285): the border line drawn above and below a
## friend's gift when it is opened, and the mark on the mail line. Only looks.
const GIFT_CARDS: Dictionary[String, String] = {
	"lantern": "o-o-o-o-o-o", "moth": "}{ }{ }{ }{", "wave": "~~~~~~~~~~~~", "pine": "^ ^ ^ ^ ^ ^",
	"kite": "<> <> <> <>", "moon": "( ) ( ) ( )", "shell": "@ @ @ @ @ @", "ember": "* . * . * .",
}

## The gift's card motif from the sender ("" for the plain card).
static func gift_motif(m: Dictionary) -> String:
	var k: String = str(m.get("motif", "")) if m.get("motif") is String else ""
	return k if GIFT_CARDS.has(k) else ""

## [param text] on the sender's greeting card: the motif's border above and below.
static func on_card(m: Dictionary, text: String) -> String:
	var k: String = gift_motif(m)
	if k.is_empty():
		return text
	return "%s\n%s\n%s" % [GIFT_CARDS[k], text, GIFT_CARDS[k]]

## [param name] inside the friend's profile frame (from their card), or plain.
static func framed_name(f: Dictionary) -> String:
	var name: String = str(f.get("name", ""))
	var c: Variant = f.get("card", {})
	var kind: String = str(c.get("frame", "")) if c is Dictionary and c.get("frame") is String else ""
	if not CARD_FRAMES.has(kind):
		return name
	return "%s%s%s" % [CARD_FRAMES[kind][0], name, CARD_FRAMES[kind][1]]

## "● Mara  Lv3  Brindlewick": online dot, friendship level, where they are.
static func friend_line(f: Dictionary) -> String:
	var dot: String = "*" if bool(f.get("online", false)) else "-"
	var where: String = str(f.get("place", "")) if bool(f.get("online", false)) else Loc.t(last_seen_text(int(f.get("last_seen", 0))))
	# "+" marks a favourite (point 59), "!" a reward waiting (points 56, 57).
	var mark: String = ("+" if bool(f.get("fav", false)) else "") + ("!" if FriendsMoreMenu.has_ready(f) else "")
	return "%s %s%s  Bond %d  %s" % [dot, mark, framed_name(f), int(f.get("level", 1)), where]

static func last_seen_text(unix: int) -> String:
	var ago: int = maxi(0, Online.unix_now() - unix)
	if ago < 3600:
		return "seen %d min ago" % maxi(1, ago / 60)
	if ago < 86400:
		return "seen %d h ago" % (ago / 3600)
	return "seen %d days ago" % (ago / 86400)

## The Wanderer card (item 24).
static func card_text(f: Dictionary) -> String:
	var c: Dictionary = f.get("card", {}) if f.get("card") is Dictionary else {}
	var lines: Array[String] = [
		"%s   Code %s" % [framed_name(f), Online.pretty_code(str(f.get("code", "")))],
		"Favourite: %s" % (str(f.favorite) if not str(f.get("favorite", "")).is_empty() else "-"),
		"Rifts sealed: %d" % int(c.get("seals", 0)),
		"Spirlog: %d seen, %d bonded" % [int(c.get("seen", 0)), int(c.get("bonded", 0))],
		"Play time: %d h" % int(c.get("hours", 0)),
		"Friendship %d (%d points)" % [int(f.get("level", 1)), int(f.get("points", 0))],
	]
	return Loc.t("\n".join(lines)) + "\n" + FriendsMoreMenu.rank_line(f) + "\n" + wish_text(f.get("wishes", []))

## "Wishes: Tonic, Remedy" or "Wishes: -" (point 46).
static func wish_text(wishes: Variant) -> String:
	var names: Array[String] = []
	for w: Variant in (wishes if wishes is Array else []):
		names.append(item_name(str(w)))
	return Loc.t("Wishes: %s") % (", ".join(names) if not names.is_empty() else "-")

## One friend. Returns true when the menu should close (echo duel picked).
static func run_friend(menu: PauseMenu, f: Dictionary) -> bool:
	var code: String = str(f.code)
	while true:
		var left: int = int(f.get("gifts_left", 0 if bool(f.get("gift_sent", false)) else 1))
		var gift: String = "Gift sent today" if left <= 0 else (Loc.t("Send a gift (%d left today)") % left if left > 1 else "Send today's gift")
		var entries: Array[String] = ["Wayfarer card", gift, "Send a greeting...", "Wave", "Echo duel", "Remove friend", "Block", "Report...",
			"Send a card..."]
		if Online.flag_on("lend"):
			entries.append("Lend a Spirling...")
		entries.append_array(FriendsMoreMenu.friend_entries(f))
		var idx: int = await menu.pick_strings(str(f.name), entries)
		if idx >= 9:
			if entries[idx] == "Lend a Spirling...":
				await lend(menu, code, str(f.name))
			else:
				await FriendsMoreMenu.run_entry(menu, f, entries[idx])
			continue
		match idx:
			-1:
				return false
			0:
				await menu.info(card_text(f))
			1:
				if left <= 0:
					await menu.info("You already sent %s a gift today. Tomorrow you can send another." % str(f.name))
					continue
				var r: Dictionary = await Online.call_fn("gift_send", {"p_code": code})
				if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
					f["gifts_left"] = int(r.data.get("left", 0))
					f["gift_sent"] = int(f.gifts_left) <= 0
					Sound.sfx("gift")
					await menu.info("Your gift is on its way to %s." % str(f.name))
				else:
					await menu.info(error_text(r))
			2:
				var p: int = await menu.pick_strings("Greeting for %s" % str(f.name), Phrases.LIST)
				if p >= 0:
					await _send(menu, code, "phrase", p)
			3:
				await _send(menu, code, "wave", 0)
			4:
				if not bool(f.get("has_team", false)):
					await menu.info("%s has no echo team yet." % str(f.name))
					continue
				var t: Dictionary = await Online.call_fn("friend_team", {"p_code": code})
				if not (t.ok and t.data is Dictionary and bool(t.data.get("ok", false))):
					await menu.info(error_text(t))
					continue
				var ring: int = EchoTeam.duel_ring(t.data)
				if await menu.confirm("Echo duel with %s's team? Everyone fights at Ring %d. Nothing is lost, your team is rested after." % [str(f.name), ring]):
					menu.echo_duel = {"code": code, "name": str(t.data.name), "team": t.data.team, "ring": ring}
					return true
			5:
				if await menu.confirm("Remove %s from your friends?" % str(f.name)):
					await Online.call_fn("friend_remove", {"p_code": code})
					return false
			6:
				if await menu.confirm("Block %s? You will not get requests, greetings or gifts from them." % str(f.name)):
					await Online.call_fn("block", {"p_code": code})
					await menu.info("%s is blocked." % str(f.name))
					return false
			7:
				await report(menu, code, str(f.name))
			8:
				await send_card(menu, code, str(f.name))
	return false

## A greeting card with a Spirling from your journey on it (point 48).
static func send_card(menu: MenuHost, code: String, name: String) -> void:
	var species: Array[String] = []
	for sp: Spirling in GameState.party + GameState.storage:
		if not species.has(sp.data.species_name):
			species.append(sp.data.species_name)
	if species.is_empty():
		await menu.info("Bond with a Spirling first. Cards show one of yours.")
		return
	var pick: int = await menu.pick_strings(Loc.t("Which Spirling goes on the card for %s?") % name, species)
	if pick < 0:
		return
	var nums: Array = Phrases.allowed("post")
	var texts: Array[String] = []
	for n: Variant in nums:
		texts.append(Phrases.text(int(n)))
	var p: int = await menu.pick_strings("Card text", texts)
	if p < 0:
		return
	var r: Dictionary = await Online.call_fn("card_send", {"p_code": code, "p_species": species[pick], "p_phrase": int(nums[p])})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("confirm")
		await menu.info(Loc.t("Your card is on its way to %s.") % name)
	else:
		await menu.info(gift_error_text(r))

## Lends a copy of one of your Spirlings to a friend for one raid or one live duel (point 45).
static func lend(menu: MenuHost, code: String, name: String) -> void:
	var mons: Array[Spirling] = []
	var labels: Array[String] = []
	for sp: Spirling in GameState.party + GameState.storage:
		mons.append(sp)
		labels.append(Loc.t("%s R%d") % [sp.data.species_name, sp.level])
	var pick: int = await menu.pick_strings(Loc.t("Lend which Spirling to %s?") % name, labels)
	if pick < 0:
		return
	if not await menu.confirm(Loc.t("%s gets a copy for one raid or one live duel within 2 days. Yours stays with you.") % name):
		return
	SaveManager.save_game()
	if not await Online.push(SaveManager.slot):
		await menu.info(TradeMenu.error_text({"ok": true, "data": {"ok": false, "error": "sync_first"}}))
		return
	var r: Dictionary = await Online.call_fn("lend_offer", {"p_code": code, "p_slot": SaveManager.slot, "p_uid": mons[pick].uid})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("confirm")
		await menu.info(Loc.t("%s can now take your Spirling into one battle.") % name)
	else:
		await menu.info(gift_error_text(r))

## Loans you gave and got; unused ones can be ended.
static func run_loans(menu: MenuHost) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("lend_list")
		if not (r.ok and r.data is Dictionary and bool(r.data.get("ok", false))):
			await menu.info(gift_error_text(r))
			return
		var rows: Array = []
		var labels: Array[String] = []
		for l: Dictionary in r.data.get("lent", []):
			rows.append(l)
			labels.append(loan_line(l, true))
		for l: Dictionary in r.data.get("borrowed", []):
			rows.append(l)
			labels.append(loan_line(l, false))
		var idx: int = await menu.pick_strings("Lent Spirlings" if not rows.is_empty() else "Lent Spirlings\nNothing lent right now.", labels)
		if idx < 0:
			return
		if str(rows[idx].state) == "lent" and await menu.confirm("End this loan?"):
			await Online.call_fn("lend_end", {"p_loan": int(rows[idx].id)})

static func loan_line(l: Dictionary, mine: bool) -> String:
	var who: String = str(l.name) if l.get("name") != null else Loc.t("a former friend")
	var mon: String = str((l.mon as Dictionary).get("species", "?")) if l.get("mon") is Dictionary else "?"
	if str(l.get("state", "")) == "used":
		return Loc.t("%s with %s: used") % [mon, who]
	return Loc.t("%s lent to %s") % [mon, who] if mine else Loc.t("%s from %s, ready for one battle") % [mon, who]

## Your wish list: up to 3 items your friends see on your Wayfarer card (point 46).
static func run_wishes(menu: MenuHost) -> void:
	var r: Dictionary = await Online.call_fn("wish_get")
	if not (r.ok and r.data is Dictionary and bool(r.data.get("ok", false))):
		await menu.info(gift_error_text(r))
		return
	var wishes: Array = (r.data.get("wishes", []) as Array).duplicate()
	var items: Array = r.data.get("items", [])
	var most: int = int(r.data.get("max", 3))
	while true:
		var labels: Array[String] = []
		for w: Variant in wishes:
			labels.append(Loc.t("Remove %s") % item_name(str(w)))
		if wishes.size() < most:
			labels.append("Add a wish...")
		var idx: int = await menu.pick_strings(wish_text(wishes), labels)
		if idx < 0:
			return
		if idx < wishes.size():
			wishes.remove_at(idx)
		else:
			var names: Array[String] = []
			var ids: Array = items.filter(func(x: Variant) -> bool: return not wishes.has(x))
			for x: Variant in ids:
				names.append(item_name(str(x)))
			var p: int = await menu.pick_strings("Add a wish...", names)
			if p < 0:
				continue
			wishes.append(ids[p])
		var w: Dictionary = await Online.call_fn("wish_set", {"p_items": wishes})
		if not (w.ok and w.data is Dictionary and bool(w.data.get("ok", false))):
			await menu.info(gift_error_text(w))
			return

static func _send(menu: MenuHost, code: String, kind: String, phrase: int) -> void:
	# A small action: with a weak connection it waits and goes out later (plan item 3011).
	var r: Dictionary = await Online.send_small("mail_send", {"p_code": code, "p_kind": kind, "p_phrase": phrase})
	if r.ok and r.data is Dictionary and bool(r.data.get("queued", false)):
		await menu.info("It goes out as soon as the connection is back.")
	elif r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("confirm")
		await menu.info("Sent!")
	else:
		await menu.info(error_text(r))

static func report(menu: MenuHost, code: String, name: String, context: String = "friends") -> void:
	var reason: int = await menu.pick_strings("Why do you report %s?" % name, REPORT_REASONS)
	if reason < 0:
		return
	var r: Dictionary = await Online.call_fn("report_in", {"p_code": code, "p_reason": reason, "p_context": context, "p_object": ""})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		await menu.info(Loc.t("Thank you. Your report has number %d. We will look at it and tell you the result under Account, Messages from the team.") % int(r.data.get("report_id", 0))
			+ "\n" + Loc.t("You can also block %s.") % name)
	else:
		await menu.info(error_text(r))

## Puts the own friend code on the clipboard (item 2171).
static func copy_code(menu: MenuHost) -> void:
	DisplayServer.clipboard_set(Online.pretty_code(Online.friend_code()))
	Sound.sfx("confirm")
	menu.toast("Copied.")

static func add_friend(menu: MenuHost) -> void:
	await menu.info("Your friend code is %s. Share it only with people you know. Never share your real name or address." % Online.pretty_code(Online.friend_code()))
	var code: String = await CodePrompt.ask(menu, "Friend code of your friend", 8)
	if code.is_empty():
		return
	var r: Dictionary = await Online.call_fn("friend_request", {"p_code": code})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		if str(r.data.get("status", "")) == "accepted":
			Sound.sfx("friend")
			await menu.info("You are friends now!")
		else:
			await menu.info("Request sent. You are friends once they accept.")
	else:
		await menu.info(error_text(r))

static func run_requests(menu: MenuHost, incoming: Array, outgoing: Array) -> void:
	if incoming.is_empty():
		var waiting: Array[String] = []
		for o: Dictionary in outgoing:
			waiting.append(str(o.name))
		if waiting.is_empty():
			await menu.info("No new requests.")
		else:
			await menu.info("No new requests.\nWaiting for: %s" % ", ".join(waiting))
		return
	for req: Dictionary in incoming:
		var idx: int = await menu.pick_strings("%s wants to be friends." % str(req.name), ["Accept", "Decline", "Block"] as Array[String])
		match idx:
			0:
				await Online.call_fn("friend_respond", {"p_code": req.code, "p_accept": true})
				Sound.sfx("friend")
			1:
				await Online.call_fn("friend_respond", {"p_code": req.code, "p_accept": false})
			2:
				await Online.call_fn("block", {"p_code": req.code})
			_:
				return

static func run_blocked(menu: MenuHost, blocked: Array) -> void:
	if blocked.is_empty():
		await menu.info("You have not blocked anyone.")
		return
	var names: Array[String] = []
	for b: Dictionary in blocked:
		names.append(str(b.name))
	var idx: int = await menu.pick_strings("Unblock someone?", names)
	if idx >= 0 and await menu.confirm("Unblock %s?" % names[idx]):
		await Online.call_fn("unblock", {"p_code": blocked[idx].code})

# --- Lantern Mail ---------------------------------------------------------------------------

## One line of mail; unread mail starts with "! ". Translated here because of that mark.
static func mail_line(m: Dictionary) -> String:
	var new: String = "" if bool(m.get("opened", false)) else "! "
	return new + Loc.t(_mail_text(m))

static func _mail_text(m: Dictionary) -> String:
	var n: String = str(m.get("name", ""))
	match str(m.get("kind", "")):
		"gift":
			return ("Gift from %s" % n if not bool(m.opened) else "Gift from %s: %s" % [n, item_name(str(m.item))])
		"wave":
			return Phrases.WAVE % n
		"thanks":
			return Phrases.THANKS % n
		"card":
			return "%s sent a card with %s: %s" % [n, str(m.get("species", "")), Phrases.text(int(m.get("phrase", 0)))]
		"echo":
			return ("%s's team fought beside your echo and won." % n if int(m.phrase) == 1 else "%s's team fought beside your echo." % n)
		"duel":
			return ("%s won a duel against your echo." % n if int(m.phrase) == 1 else "Your echo won a duel against %s!" % n)
		_:
			return "%s: %s" % [n, Phrases.text(int(m.get("phrase", 0)))]

static func item_name(id: String) -> String:
	return Loc.t(str(Database.item(id).get("name", id)))

static func run_mail(menu: MenuHost, mail: Array) -> void:
	while true:
		var labels: Array[String] = []
		for m: Dictionary in mail:
			labels.append(mail_line(m))
		labels.append("What can be in a gift?")
		var idx: int = await menu.pick_strings("Lantern Mail" if not mail.is_empty() else "Lantern Mail\nNo mail yet.", labels)
		if idx < 0:
			return
		if idx == mail.size():
			await menu.info(gift_table_text())
			continue
		var m: Dictionary = mail[idx]
		if str(m.kind) == "gift" and not bool(m.opened):
			var r: Dictionary = await Online.call_fn("gift_open", {"p_id": m.id})
			if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
				var item: String = str(r.data.item)
				m.opened = true
				m.item = item
				if not bool(r.data.get("again", false)):
					GameState.add_item(item)
					SaveManager.save_game()
				Sound.sfx("coin")
				var where: String = str(m.get("place", ""))
				if where.is_empty():
					await menu.info(on_card(m, Loc.t("%s sent you %s!") % [str(m.name), item_name(item)]))
				else:
					await menu.info(on_card(m, Loc.t("%s sent you %s from %s!") % [str(m.name), item_name(item), where]))
			else:
				await menu.info(error_text(r))
			continue
		if not bool(m.opened):
			await Online.call_fn("mail_open", {"p_id": m.id})
			m.opened = true
		if str(m.kind) == "gift":
			await thank_gift(menu, m)
		elif str(m.kind) in ["phrase", "wave", "card"]:
			if await menu.confirm(mail_line(m) + "\n\n" + Loc.t("Say thanks?")):
				await _send(menu, str(m.code), "thanks", 1)
		else:
			await menu.info(mail_line(m))

## Thanks for a gift: once per gift, friendship points for both (point 49).
static func thank_gift(menu: MenuHost, m: Dictionary) -> void:
	if bool(m.get("thanked", false)):
		await menu.info(mail_line(m) + "\n\n" + Loc.t("You already said thanks."))
		return
	var pts: int = int(LocalTradeGifts.config().get("thanks_points", 2))
	if not await menu.confirm(mail_line(m) + "\n\n" + Loc.t("Say thanks? You both get %d friendship points.") % pts):
		return
	var r: Dictionary = await Online.call_fn("gift_thank", {"p_id": m.id})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		m["thanked"] = true
		Sound.sfx("confirm")
		await menu.info("Thanks sent!")
	else:
		await menu.info(gift_error_text(r))

## The open gift table with chances (item 182).
static func gift_table_text() -> String:
	var lines: Array[String] = ["A gift holds one of these:"]
	var table: Array = LocalBackend.DEFAULT_CONFIG.gift_table
	var total: int = 0
	for e: Dictionary in table:
		total += int(e.w)
	for e: Dictionary in table:
		lines.append("%s  %d%%" % [item_name(str(e.item)), int(round(100.0 * int(e.w) / total))])
	lines.append("You can open %d gifts a day." % int(LocalBackend.DEFAULT_CONFIG.gift_open_limit))
	return Loc.t("\n".join(lines))

# --- World goal and weekly board ---------------------------------------------------------------

static func goal_text(g: Dictionary) -> String:
	var target: int = maxi(1, int(g.get("target", 1)))
	var total: int = int(g.get("total", 0))
	var pct: int = mini(100, int(100.0 * total / target))
	var bar: String = ""
	for i: int in 10:
		bar += "#" if i < pct / 10 else "."
	var lines: Array[String] = [
		"This week: %s" % str(GOAL_TEXT.get(str(g.get("kind", "")), g.get("kind", ""))),
		"All Wayfarers: %d of %d" % [total, target],
		"[%s] %d%%" % [bar, pct],
		"You helped: %d" % int(g.get("mine", 0)),
	]
	if int(g.get("online_now", 0)) > 1:
		lines.append("%d Wayfarers are in Veydal" % int(g.online_now))
	return Loc.t("\n".join(lines))

## Tiers reached and not claimed yet (1-4).
static func open_tiers(g: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if int(g.get("mine", 0)) <= 0:
		return out
	for tier: int in range(1, 5):
		if int(g.get("total", 0)) * 4 >= int(g.get("target", 1)) * tier and int(g.get("claimed", 0)) & (1 << (tier - 1)) == 0:
			out.append(tier)
	return out

static func run_goal(menu: MenuHost) -> void:
	var r: Dictionary = await Online.call_fn("community_get")
	if not r.ok or not r.data is Dictionary:
		await menu.info(Online.error_text(r.error))
		return
	var g: Dictionary = r.data
	var tiers: Array[int] = open_tiers(g)
	var text: String = goal_text(g)
	if int(g.get("mine", 0)) <= 0:
		text += "\n\n" + Loc.t("Help once this week to share the rewards at 25, 50, 75 and 100 percent.")
	await menu.info(text)
	for tier: int in tiers:
		var c: Dictionary = await Online.call_fn("community_claim", {"p_tier": tier})
		if c.ok and c.data is Dictionary and bool(c.data.get("ok", false)):
			var item: String = str(c.data.item)
			GameState.add_item(item)
			Sound.sfx("coin")
			await menu.info("The world reached %d%%! You received %s." % [tier * 25, item_name(item)])
	if not tiers.is_empty():
		SaveManager.save_game()

static func run_board(menu: MenuHost) -> void:
	var friends_only: bool = true
	while true:
		var r: Dictionary = await Online.call_fn("weekly_board", {"p_friends": friends_only})
		if not r.ok or not r.data is Dictionary:
			await menu.info(Online.error_text(r.error))
			return
		var lines: Array[String] = []
		for row: Dictionary in r.data.get("rows", []):
			var n: String = str(row.get("name", ""))
			var you: String = "  " + Loc.t("(you)") if bool(row.get("me", false)) else ""
			lines.append("%d. %s  %d%s" % [int(row.rank), n if not n.is_empty() else "Wanderer", int(row.score), you])
		if lines.is_empty():
			lines.append("No runs yet this week. Try the weekly challenge!")
		var title: String = "Weekly board, friends" if friends_only else "Weekly board, everyone"
		var idx: int = await menu.pick_strings(title + "\n" + "\n".join(lines), ["Show everyone" if friends_only else "Show friends"] as Array[String])
		if idx < 0:
			return
		friends_only = not friends_only

## The weekly boards: the weekly challenge, and (when switched on) Rift times and league wins.
static func run_boards(menu: MenuHost) -> void:
	var rift_on: bool = Online.flag_on("rift_board")
	var league_on: bool = Online.flag_on("league_board")
	if not rift_on and not league_on:
		await run_board(menu)
		return
	while true:
		var opts: Array[String] = ["Weekly challenge"]
		if rift_on:
			opts.append("Rift times")
		if league_on:
			opts.append_array(["Fair League wins", "Open League wins"] as Array[String])
		var idx: int = await menu.pick_strings("Weekly boards", opts)
		if idx < 0:
			return
		match opts[idx]:
			"Weekly challenge": await run_board(menu)
			"Rift times": await run_rift_board(menu)
			"Fair League wins": await run_week_board(menu, "league_board", {"p_league": "fair"}, "Fair League wins this week", "%d wins")
			"Open League wins": await run_week_board(menu, "league_board", {"p_league": "open"}, "Open League wins this week", "%d wins")

static func rift_name(id: String) -> String:
	return Loc.t("%s Rift") % Loc.t(id.capitalize())

static func run_rift_board(menu: MenuHost) -> void:
	var rifts: Array[String] = GameState.rifts_sealed.duplicate()
	if rifts.is_empty():
		await menu.info("Mend a Rift first. Your fastest win against its Warden then shows here.")
		return
	var labels: Array[String] = []
	for r: String in rifts:
		labels.append(rift_name(r))
	var idx: int = await menu.pick_strings("Rift times", labels)
	if idx < 0:
		return
	await run_week_board(menu, "rift_board", {"p_rift": rifts[idx]}, Loc.t("%s, fewest rounds this week") % rift_name(rifts[idx]), "%d rounds")

## One weekly board: friends first, "Show everyone" switches. [param unit] formats the value.
static func run_week_board(menu: MenuHost, fn: String, args: Dictionary, title: String, unit: String) -> void:
	var friends_only: bool = true
	while true:
		var full: Dictionary = args.duplicate()
		full["p_friends"] = friends_only
		var r: Dictionary = await Online.call_fn(fn, full)
		if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
			await menu.info(error_text(r))
			return
		var lines: Array[String] = []
		for row: Dictionary in r.data.get("rows", []):
			var n: String = str(row.get("name", ""))
			var you: String = "  " + Loc.t("(you)") if bool(row.get("me", false)) else ""
			lines.append("%d. %s  %s%s" % [int(row.rank), n if not n.is_empty() else "Wanderer", Loc.t(unit) % int(row.score), you])
		if lines.is_empty():
			lines.append(Loc.t("Nobody on this board yet this week."))
		var head: String = Loc.t(title) + "\n" + (Loc.t("Friends") if friends_only else Loc.t("Everyone"))
		var idx: int = await menu.pick_strings(head + "\n" + "\n".join(lines), ["Show everyone" if friends_only else "Show friends"] as Array[String])
		if idx < 0:
			return
		friends_only = not friends_only

## "Tonic 30 %, Remedy 20 %, ..." from the open table the server rolls from.
static func daily_table_text(table: Variant) -> String:
	var total: int = 0
	for e: Variant in (table if table is Array else []):
		total += int((e as Dictionary).get("w", 0)) if e is Dictionary else 0
	var parts: Array[String] = []
	for e: Variant in (table if table is Array else []):
		if e is Dictionary and total > 0:
			parts.append("%s %d %%" % [item_name(str(e.item)), roundi(100.0 * int(e.w) / total)])
	return ", ".join(parts)

## Daily online gift: one free item a day, rolled by the server and put into the saved bag.
## Nothing to buy, no other offer on this screen.
static func run_daily_gift(menu: MenuHost) -> void:
	var st: Dictionary = await Online.call_fn("daily_gift_state")
	if not st.ok or not st.data is Dictionary or not bool(st.data.get("ok", false)):
		await menu.info(error_text(st))
		return
	var chances: String = Loc.t("What it can be: %s") % daily_table_text(st.data.get("table", []))
	if not bool(st.data.get("ready", false)):
		await menu.info(Loc.t("You already opened today's gift. A new one waits tomorrow.") + "\n" + chances)
		return
	var idx: int = await menu.pick_strings(Loc.t("A gift is waiting for you today.") + "\n" + chances, ["Open the gift"] as Array[String])
	if idx < 0:
		return
	var r: Dictionary = await TradeMenu.bag_call("daily_gift_claim", {})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("coin")
		await menu.info(Loc.t("You got: %s") % item_name(str(r.data.item)))
	else:
		await menu.info(TradeMenu.error_text(r))

static func error_text(r: Dictionary) -> String:
	var e: String = r.error
	if r.ok and r.data is Dictionary:
		e = str(r.data.get("error", ""))
	match e:
		"no_such_code": return "No Wayfarer has that code."
		"not_friends": return "You can only do that with friends."
		"already_today": return "Already done today. Tomorrow again!"
		"slow_down": return "That was a lot at once. Please wait a little."
		"full": return "That friend list is full."
		"limit_today": return "You opened all gifts you can today. The rest waits for tomorrow."
		"social_off": return "Friends and greetings are switched off."
	return Online.error_text(e)

## Texts for cards, thanks, wishes and loans (Online 100, area 5); everything else as error_text.
static func gift_error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	match e:
		"no_species": return "Cards show a Spirling from your journey."
		"cards_today": return "You sent all cards you can today. Tomorrow again!"
		"lends_today": return "You lent 3 Spirlings today. Tomorrow again!"
		"bad_phrase": return "Pick one of the set phrases."
		"open_first": return "Open the gift first."
		"already": return "You already said thanks."
		"bad_wish": return "That cannot go on your wish list."
		"friend_level": return "Lending opens at friendship level 3."
		"already_lent": return "That Spirling is already lent."
		"friend_has_one": return "Your friend already has a lent Spirling."
		"no_such_loan": return "That loan is over."
		"used": return "That Spirling was already taken into a battle."
		"feature_off": return "This is closed right now."
		"no_spirling": return "That Spirling is not in your journey any more."
		"shop_boosted": return "Spirlings with a Gleam, a Power Core or crystals, and Spirlings from the shop, stay with you."
		"no_save": return "Save your journey first, then try again."
		"under_review": return "Your account is being checked. Lending opens again after the check."
	return error_text(r)
