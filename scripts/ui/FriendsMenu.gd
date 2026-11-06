class_name FriendsMenu
extends RefCounted
## Menu > Friends: friend code, friends with Tamer cards, requests, Lantern Mail (greetings and
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
		labels.append("World goal of the week")
		labels.append("Weekly board")
		labels.append("Blocked Wayfarers")
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
			3: await run_goal(menu)
			4: await run_board(menu)
			5: await run_blocked(menu, data.get("blocked", []))

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

## "● Mara  Lv3  Brindlewick": online dot, friendship level, where they are.
static func friend_line(f: Dictionary) -> String:
	var dot: String = "*" if bool(f.get("online", false)) else "-"
	var where: String = str(f.get("place", "")) if bool(f.get("online", false)) else Loc.t(last_seen_text(int(f.get("last_seen", 0))))
	return "%s %s  Bond %d  %s" % [dot, str(f.get("name", "")), int(f.get("level", 1)), where]

static func last_seen_text(unix: int) -> String:
	var ago: int = maxi(0, Online.unix_now() - unix)
	if ago < 3600:
		return "seen %d min ago" % maxi(1, ago / 60)
	if ago < 86400:
		return "seen %d h ago" % (ago / 3600)
	return "seen %d days ago" % (ago / 86400)

## The Tamer card (item 24).
static func card_text(f: Dictionary) -> String:
	var c: Dictionary = f.get("card", {}) if f.get("card") is Dictionary else {}
	var lines: Array[String] = [
		"%s   Code %s" % [str(f.get("name", "")), Online.pretty_code(str(f.get("code", "")))],
		"Favourite: %s" % (str(f.favorite) if not str(f.get("favorite", "")).is_empty() else "-"),
		"Rifts sealed: %d" % int(c.get("seals", 0)),
		"Spirlog: %d seen, %d bonded" % [int(c.get("seen", 0)), int(c.get("bonded", 0))],
		"Play time: %d h" % int(c.get("hours", 0)),
		"Friendship %d (%d points)" % [int(f.get("level", 1)), int(f.get("points", 0))],
	]
	return Loc.t("\n".join(lines))

## One friend. Returns true when the menu should close (echo duel picked).
static func run_friend(menu: PauseMenu, f: Dictionary) -> bool:
	var code: String = str(f.code)
	while true:
		var gift: String = "Gift sent today" if bool(f.get("gift_sent", false)) else "Send today's gift"
		var entries: Array[String] = ["Wayfarer card", gift, "Send a greeting...", "Wave", "Echo duel", "Remove friend", "Block", "Report..."]
		var idx: int = await menu.pick_strings(str(f.name), entries)
		match idx:
			-1:
				return false
			0:
				await menu.info(card_text(f))
			1:
				if bool(f.get("gift_sent", false)):
					await menu.info("You already sent %s a gift today. Tomorrow you can send another." % str(f.name))
					continue
				var r: Dictionary = await Online.call_fn("gift_send", {"p_code": code})
				if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
					f["gift_sent"] = true
					Sound.sfx("confirm")
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
				if await menu.confirm("Echo duel with %s's team? Everyone fights at Ring %d. Nothing is lost, your team is rested after." % [str(f.name), EchoTeam.DUEL_LEVEL]):
					var t: Dictionary = await Online.call_fn("friend_team", {"p_code": code})
					if t.ok and t.data is Dictionary and bool(t.data.get("ok", false)):
						menu.echo_duel = {"code": code, "name": str(t.data.name), "team": t.data.team}
						return true
					await menu.info(error_text(t))
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
	return false

static func _send(menu: MenuHost, code: String, kind: String, phrase: int) -> void:
	var r: Dictionary = await Online.call_fn("mail_send", {"p_code": code, "p_kind": kind, "p_phrase": phrase})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		Sound.sfx("confirm")
		await menu.info("Sent!")
	else:
		await menu.info(error_text(r))

static func report(menu: MenuHost, code: String, name: String) -> void:
	var reason: int = await menu.pick_strings("Why do you report %s?" % name, REPORT_REASONS)
	if reason < 0:
		return
	var r: Dictionary = await Online.call_fn("report", {"p_code": code, "p_reason": reason})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		await menu.info("Thank you. We will look at it. You can also block %s." % name)
	else:
		await menu.info(error_text(r))

static func add_friend(menu: MenuHost) -> void:
	await menu.info("Your friend code is %s. Share it only with people you know. Never share your real name or address." % Online.pretty_code(Online.friend_code()))
	var code: String = await TextPrompt.ask(menu, "Friend code of your friend", false, 9)
	if code.is_empty():
		return
	var r: Dictionary = await Online.call_fn("friend_request", {"p_code": code})
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		if str(r.data.get("status", "")) == "accepted":
			Sound.sfx("confirm")
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
				Sound.sfx("confirm")
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
					await menu.info("%s sent you %s!" % [str(m.name), item_name(item)])
				else:
					await menu.info("%s sent you %s from %s!" % [str(m.name), item_name(item), where])
			else:
				await menu.info(error_text(r))
			continue
		if not bool(m.opened):
			await Online.call_fn("mail_open", {"p_id": m.id})
			m.opened = true
		if str(m.kind) in ["phrase", "wave", "gift"]:
			if await menu.confirm(mail_line(m) + "\n\n" + Loc.t("Say thanks?")):
				await _send(menu, str(m.code), "thanks", 1)
		else:
			await menu.info(mail_line(m))

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
			lines.append("%d. %s  %d%s" % [int(row.rank), n if not n.is_empty() else "Tamer", int(row.score), you])
		if lines.is_empty():
			lines.append("No runs yet this week. Try the weekly challenge!")
		var title: String = "Weekly board, friends" if friends_only else "Weekly board, everyone"
		var idx: int = await menu.pick_strings(title + "\n" + "\n".join(lines), ["Show everyone" if friends_only else "Show friends"] as Array[String])
		if idx < 0:
			return
		friends_only = not friends_only

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
