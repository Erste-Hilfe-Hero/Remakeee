class_name BundMenu
extends RefCounted
## The bund menu (plan area 7, items 2817-2821, 2842): found a bund from two words, invite,
## ask to join, roles, leave at any time, dissolve. Opened from Friends when the "bund" flag is on.

const ROLES: Dictionary = {"leader": "Leader", "helper": "Helper", "member": "Member"}
const ERRORS: Dictionary = {
	"feature_off": "Bunds are closed right now.",
	"in_bund": "That Wayfarer is already in a bund.",
	"full": "That bund is full (30 Wayfarers).",
	"not_allowed": "Only the leader or a helper can do that.",
	"no_such_bund": "No bund found with that code.",
	"no_such_invite": "That invitation is gone.",
	"no_such_request": "That request is gone.",
	"no_such_member": "That Wayfarer is no longer in the bund.",
	"bad_name": "Pick two words for the name.",
	"limit_today": "You donated all you can today. More tomorrow.",
	"goal_open": "The week goal is not reached yet.",
	"claimed": "You already took this week's reward.",
	"not_enough": "You do not have that many.",
	"bad_decor": "That does not fit in the bund house yet.",
	"war_closed": "Bund against bund runs on Saturdays and Sundays.",
	"joined": "You already fight for your bund this weekend.",
	"war_full": "Your bund already has its five fighters.",
	"no_war": "Your bund has no rival yet. Five fighters on both sides start the war.",
	"fought": "You already fought your war battle.",
	"no_such_fight": "That war battle is gone.",
}

static func role_text(role: String) -> String:
	return str(ROLES.get(role, "Member"))

static func member_line(m: Dictionary) -> String:
	var line: String = "%s  %s" % [str(m.get("name", "?")), Loc.t(role_text(str(m.get("role", ""))))]
	if bool(m.get("me", false)):
		line += "  " + Loc.t("(you)")
	elif bool(m.get("online", false)):
		line += "  " + Loc.t("online")
	return line

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else FriendsMenu.error_text(r)

static func _call(menu: MenuHost, fn: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = await Online.call_fn(fn, args)
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		return r.data
	await menu.info(error_text(r))
	return {}

static func run(menu: MenuHost) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("bund_info")
		if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
			await menu.info(error_text(r))
			return
		var done: bool
		if r.data.get("bund") is Dictionary:
			done = await _run_bund(menu, r.data.bund)
		else:
			done = await _run_none(menu, r.data.get("invites", []))
		if done:
			return

static func _run_none(menu: MenuHost, invites: Array) -> bool:
	var labels: Array[String] = []
	for i: Dictionary in invites:
		labels.append(Loc.t("Invitation: %s (%d) from %s") % [BundWords.name_of(int(i.name[0]), int(i.name[1])), int(i.size), str(i.by)])
	labels.append_array(["Found a bund...", "Ask to join a bund...", "Find a bund..."] as Array[String])
	var idx: int = await menu.pick_strings("You are not in a bund yet.", labels)
	if idx < 0:
		return true
	if idx < invites.size():
		var i: Dictionary = invites[idx]
		var yes: int = await menu.pick_strings(Loc.t("Join %s?") % BundWords.name_of(int(i.name[0]), int(i.name[1])),
			["Join", "Say no"] as Array[String])
		if yes >= 0:
			var got: Dictionary = await _call(menu, "bund_answer", {"p_bund": int(i.bund), "p_accept": yes == 0})
			if bool(got.get("joined", false)):
				Sound.sfx("confirm")
		return false
	if idx == invites.size():
		await found(menu)
		return false
	if idx == invites.size() + 2:
		await search(menu)
		return false
	var code: String = await CodePrompt.ask(menu, "Friend code of someone in the bund", 8)
	if code.is_empty():
		return false
	var got: Dictionary = await _call(menu, "bund_request", {"p_code": code})
	if not got.is_empty():
		await menu.info("You joined the bund." if bool(got.get("joined", false)) else "Request sent. A leader or helper decides.")
	return false

## Two words make the name: roll until one fits, or choose each word.
static func found(menu: MenuHost) -> void:
	var a: int = randi() % BundWords.FIRST.size()
	var b: int = randi() % BundWords.SECOND.size()
	while true:
		var idx: int = await menu.pick_strings(Loc.t("Name of the bund: %s") % BundWords.name_of(a, b),
			["Found it", "Roll again", "Choose the first word...", "Choose the second word..."] as Array[String])
		match idx:
			-1:
				return
			0:
				var got: Dictionary = await _call(menu, "bund_create", {"p_a": a, "p_b": b})
				if not got.is_empty():
					Sound.sfx("confirm")
					await menu.info(Loc.t("%s is founded. Invite Wayfarers with their friend code.") % BundWords.name_of(a, b))
				return
			1:
				a = randi() % BundWords.FIRST.size()
				b = randi() % BundWords.SECOND.size()
			2:
				var opts: Array[String] = []
				for i: int in BundWords.FIRST.size():
					opts.append(BundWords.name_of(i, b))
				var p: int = await menu.pick_strings("First word", opts)
				a = p if p >= 0 else a
			3:
				var opts: Array[String] = []
				for i: int in BundWords.SECOND.size():
					opts.append(BundWords.name_of(a, i))
				var p: int = await menu.pick_strings("Second word", opts)
				b = p if p >= 0 else b

static func _run_bund(menu: MenuHost, bund: Dictionary) -> bool:
	var role: String = str(bund.role)
	var members: Array = bund.get("members", [])
	var pending: Array = bund.get("pending", [])
	var staff: bool = role in ["leader", "helper"]
	var labels: Array[String] = []
	for m: Dictionary in members:
		labels.append(member_line(m))
	var actions: Array[String] = ["Bund house", "Bund against bund", "Bund rank and week goal", "Donate items...", "Bund board"]
	if role == "leader":
		actions.append("Language and joining...")
	if staff:
		actions.append("Invite a Wayfarer...")
		if not pending.is_empty():
			actions.append(Loc.t("Requests (%d)") % pending.size())
	if role == "leader" and bund.get("dissolve_at") != null:
		actions.append_array(["Confirm dissolving", "Keep the bund"] as Array[String])
	elif role == "leader":
		actions.append("Dissolve the bund...")
	actions.append("Leave the bund...")
	labels.append_array(actions)
	var title: String = "%s  %d/30" % [BundWords.name_of(int(bund.name[0]), int(bund.name[1])), members.size()]
	var idx: int = await menu.pick_strings(title, labels)
	if idx < 0:
		return true
	if idx < members.size():
		await _run_member(menu, role, members[idx])
		return false
	match actions[idx - members.size()]:
		"Invite a Wayfarer...":
			var code: String = await CodePrompt.ask(menu, "Friend code of the Wayfarer", 8)
			if not code.is_empty():
				var got: Dictionary = await _call(menu, "bund_invite", {"p_code": code})
				if not got.is_empty():
					await menu.info("They joined the bund." if bool(got.get("joined", false)) else "Invitation sent.")
		"Dissolve the bund...", "Confirm dissolving":
			if await menu.confirm_danger("Dissolve the bund for everyone?"):
				var got: Dictionary = await _call(menu, "bund_dissolve")
				if bool(got.get("dissolved", false)):
					await menu.info("The bund is dissolved.")
				elif not got.is_empty():
					await menu.info(Loc.t("With 3 or more Wayfarers you confirm again after 24 hours, from %s.")
						% Time.get_datetime_string_from_unix_time(int(got.confirm_from), true))
		"Keep the bund":
			await _call(menu, "bund_keep")
		"Bund house":
			await house(menu)
		"Bund against bund":
			await war(menu)
			if menu is PauseMenu and not (menu as PauseMenu).raid_attempt.is_empty():
				return true
		"Bund rank and week goal":
			await stats(menu)
		"Donate items...":
			await donate(menu)
		"Bund board":
			var got: Dictionary = await _call(menu, "bund_board")
			if not got.is_empty():
				await menu.info(board_text(got.rows))
		"Language and joining...":
			await settings(menu)
		"Leave the bund...":
			if await menu.confirm("Leave the bund? You can join a bund again at any time."):
				await _call(menu, "bund_leave")
		_:
			await _run_requests(menu, pending)
	return false

static func _run_member(menu: MenuHost, role: String, m: Dictionary) -> void:
	if bool(m.get("me", false)):
		await menu.info(member_line(m))
		return
	var theirs: String = str(m.role)
	var opts: Array[String] = []
	if role == "leader":
		opts.append("Make member" if theirs == "helper" else "Make helper")
		opts.append("Hand over leadership")
	if role == "leader" or (role == "helper" and theirs == "member"):
		opts.append("Remove from the bund")
	if opts.is_empty():
		await menu.info(member_line(m))
		return
	var idx: int = await menu.pick_strings(member_line(m), opts)
	if idx < 0:
		return
	match opts[idx]:
		"Make helper": await _call(menu, "bund_role", {"p_code": str(m.code), "p_role": "helper"})
		"Make member": await _call(menu, "bund_role", {"p_code": str(m.code), "p_role": "member"})
		"Hand over leadership":
			if await menu.confirm(Loc.t("Make %s the leader? You become a helper.") % str(m.name)):
				await _call(menu, "bund_role", {"p_code": str(m.code), "p_role": "leader"})
		"Remove from the bund":
			if await menu.confirm(Loc.t("Remove %s from the bund?") % str(m.name)):
				await _call(menu, "bund_kick", {"p_code": str(m.code)})

static func _run_requests(menu: MenuHost, pending: Array) -> void:
	var asks: Array = pending.filter(func(p: Dictionary) -> bool: return p.kind == "request")
	var labels: Array[String] = []
	for p: Dictionary in pending:
		labels.append((Loc.t("%s asks to join") if p.kind == "request" else Loc.t("%s is invited")) % str(p.name))
	var idx: int = await menu.pick_strings("Requests", labels)
	if idx < 0 or pending[idx].kind != "request" or asks.is_empty():
		return
	var yes: int = await menu.pick_strings(labels[idx], ["Let them in", "Say no"] as Array[String])
	if yes >= 0:
		await _call(menu, "bund_admit", {"p_code": str(pending[idx].code), "p_accept": yes == 0})

# --- Online 100, area 4: level, week goal, donations, board, search, open join -------------------

static func stats_text(st: Dictionary) -> String:
	var lines: Array[String] = [Loc.t("Bund rank %d (%d renown)") % [int(st.level), int(st.xp)],
		Loc.t("Week goal: %d / %d items donated") % [mini(int(st.goal), int(st.goal_target)), int(st.goal_target)],
		Loc.t("Donated today: %d / %d") % [int(st.donated_today), int(st.donate_daily)]]
	var perks: Array = st.get("perks", [])
	if not perks.is_empty():
		lines.append(Loc.t("Rank perks:"))
		for p: Dictionary in perks:
			lines.append(("* " if int(p.level) <= int(st.level) else "- ") + BundRules.perk_line(p))
	return "\n".join(lines)

static func stats(menu: MenuHost) -> void:
	var st: Dictionary = await _call(menu, "bund_stats")
	if st.is_empty():
		return
	var opts: Array[String] = []
	if int(st.goal) >= int(st.goal_target) and not bool(st.goal_claimed):
		opts.append("Take the week reward")
	var idx: int = await menu.pick_strings(stats_text(st), opts)
	if idx == 0:
		var r: Dictionary = await TradeMenu.bag_call("bund_goal_claim", {})
		await menu.info(Loc.t("You got: %s") % FriendsMenu.item_name(str(r.data.item)) if _ok(r) else error_text(r))

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

static func donate(menu: MenuHost) -> void:
	var ids: Array[String] = []
	var labels: Array[String] = []
	for id: String in GameState.inventory:
		if int(GameState.inventory[id]) > 0:
			ids.append(id)
			labels.append("%s x%d" % [FriendsMenu.item_name(id), int(GameState.inventory[id])])
	var idx: int = await menu.pick_strings("Donate items...", labels)
	if idx < 0:
		return
	var counts: Array[String] = ["1", "5", "10"]
	var c: int = await menu.pick_strings("How many?", counts)
	if c < 0:
		return
	var r: Dictionary = await TradeMenu.bag_call("bund_donate", {"p_item": ids[idx], "p_count": int(counts[c])})
	await menu.info(Loc.t("Thank you! The bund has %d renown now.") % int(r.data.xp) if _ok(r) else error_text(r))

static func board_text(rows: Array) -> String:
	var lines: Array[String] = []
	for i: int in rows.size():
		var x: Dictionary = rows[i]
		lines.append(Loc.t("%d. %s  Rank %d%s") % [i + 1, BundWords.name_of(int(x.name[0]), int(x.name[1])), int(x.level),
			"  " + Loc.t("(you)") if bool(x.get("mine", false)) else ""])
	return "\n".join(lines) if not lines.is_empty() else Loc.t("No bunds yet.")

static func _pick_lang(menu: MenuHost, title: String) -> Variant:
	var langs: Array = [""]
	langs.append_array(BundRules.config().get("langs", []))
	var labels: Array[String] = []
	for l: Variant in langs:
		labels.append(Loc.t("Any language") if str(l).is_empty() else str(BundRules.LANG_NAMES.get(l, l)))
	var idx: int = await menu.pick_strings(title, labels)
	return str(langs[idx]) if idx >= 0 else null

static func settings(menu: MenuHost) -> void:
	var lang: Variant = await _pick_lang(menu, "Language of the bund")
	if lang == null:
		return
	var open_idx: int = await menu.pick_strings("Who may join?", ["Anyone, at once", "Only after a request"] as Array[String])
	if open_idx < 0:
		return
	if not (await _call(menu, "bund_settings", {"p_lang": lang, "p_open": open_idx == 0})).is_empty():
		await menu.info("Saved.")

static func search(menu: MenuHost) -> void:
	var lang: Variant = await _pick_lang(menu, "Find a bund...")
	if lang == null:
		return
	var got: Dictionary = await _call(menu, "bund_search", {"p_lang": lang})
	if got.is_empty():
		return
	var rows: Array = got.bunds
	var labels: Array[String] = []
	for x: Dictionary in rows:
		labels.append(Loc.t("%s  Rank %d  %d/30, %d active%s") % [BundWords.name_of(int(x.name[0]), int(x.name[1])), int(x.level),
			int(x.size), int(x.active), "  " + Loc.t("open") if bool(x.open) else ""])
	if labels.is_empty():
		await menu.info("No bund found. Found your own!")
		return
	var idx: int = await menu.pick_strings("Find a bund...", labels)
	if idx < 0:
		return
	var r: Dictionary = await _call(menu, "bund_join", {"p_bund": int(rows[idx].bund)})
	if not r.is_empty():
		await menu.info("You joined the bund." if bool(r.get("joined", false)) else "Request sent. A leader or helper decides.")

# --- Online 100, area 4: bund house (35) and bund against bund (37) -----------------------------

static func decor_name(id: String) -> String:
	return Loc.t(str(BundRules.DECOR_NAMES.get(id, id)))

static func house_text(h: Dictionary) -> String:
	var lines: Array[String] = [Loc.t("The house of %s, rank %d") % [BundWords.name_of(int(h.name[0]), int(h.name[1])), int(h.level)]]
	var placed: Array[String] = []
	for d: Variant in h.get("house", []):
		placed.append(decor_name(str(d)))
	lines.append(Loc.t("In the hall: %s") % (", ".join(placed) if not placed.is_empty() else Loc.t("nothing yet")))
	lines.append(Loc.t("Places: %d of %d") % [placed.size(), int(h.slots)])
	if int(h.get("war_wins", 0)) > 0:
		lines.append(Loc.t("Wars won: %d") % int(h.war_wins))
	var here: Array[String] = []
	for m: Dictionary in h.get("members", []):
		if bool(m.get("online", false)) or bool(m.get("me", false)):
			here.append(str(m.name))
	lines.append(Loc.t("In the house now: %s") % ", ".join(here))
	return "\n".join(lines)

## The bund house every member sees (point 35); leader and helpers place the decorations.
static func house(menu: MenuHost) -> void:
	while true:
		var h: Dictionary = await _call(menu, "bund_house")
		if h.is_empty():
			return
		var opts: Array[String] = []
		if bool(h.get("can_edit", false)):
			opts.append("Place or take away...")
		var idx: int = await menu.pick_strings(house_text(h), opts)
		if idx < 0:
			return
		var open: Array = h.get("decor", [])
		var placed: Array = (h.get("house", []) as Array).duplicate()
		var labels: Array[String] = []
		for d: Variant in open:
			labels.append(("[x] " if placed.has(d) else "[ ] ") + decor_name(str(d)))
		var p: int = await menu.pick_strings(Loc.t("Places: %d of %d") % [placed.size(), int(h.slots)], labels)
		if p < 0:
			continue
		if placed.has(open[p]):
			placed.erase(open[p])
		else:
			placed.append(open[p])
		await _call(menu, "bund_house_set", {"p_house": placed})

static func _result_word(r: Variant) -> String:
	match str(r):
		"won": return Loc.t("won")
		"lost": return Loc.t("lost")
		"pending": return Loc.t("being checked")
	return Loc.t("open")

static func war_text(w: Dictionary) -> String:
	var lines: Array[String] = [Loc.t("Bund against bund: %d fighters each, Saturday and Sunday.") % int(w.size)]
	var war: Variant = w.get("war")
	if not war is Dictionary:
		var names: Array[String] = []
		for f: Dictionary in w.get("fighters", []):
			names.append(str(f.name))
		lines.append(Loc.t("Fighters: %d of %d  %s") % [names.size(), int(w.size), ", ".join(names)])
		return "\n".join(lines)
	var foe: Dictionary = war.foe if war.get("foe") is Dictionary else {"name": [0, 0], "level": 1}
	lines.append(Loc.t("Rival: %s (rank %d)") % [BundWords.name_of(int(foe.name[0]), int(foe.name[1])), int(foe.level)])
	lines.append(Loc.t("Score: %d to %d") % [int(war.wins), int(war.foe_wins)])
	for p: Dictionary in war.get("places", []):
		lines.append(Loc.t("%d. %s (%s) against %s (%s)") % [int(p.slot), str(p.get("mine", "?")), _result_word(p.get("mine_result")),
			str(p.get("foe", "?")), _result_word(p.get("foe_result"))])
	if bool(war.settled):
		lines.append({"won": Loc.t("Your bund won the war!"), "lost": Loc.t("The rival bund won this time."),
			"draw": Loc.t("A draw.")}.get(str(war.result), ""))
	return "\n".join(lines)

## Bund against bund (point 37): sign up as a fighter, then fight the team on the same place.
static func war(menu: MenuHost) -> void:
	var w: Dictionary = await _call(menu, "bund_war_info")
	if w.is_empty():
		return
	var opts: Array[String] = []
	if bool(w.get("day", false)) and not bool(w.get("joined", false)) and w.get("war") == null:
		opts.append("Fight for the bund")
	if bool(w.get("day", false)) and bool(w.get("joined", false)) and w.get("war") is Dictionary and not bool(w.war.settled):
		opts.append("Start my war battle")
	var idx: int = await menu.pick_strings(war_text(w), opts)
	if idx < 0:
		return
	await Online.push_team()
	if opts[idx] == "Fight for the bund":
		var j: Dictionary = await _call(menu, "bund_war_join", {"p_pick": LeagueMenu.pick_of(GameState.party)})
		if not j.is_empty():
			await menu.info(war_text(j))
		return
	var f: Dictionary = await _call(menu, "bund_war_fight")
	if f.is_empty() or not menu is PauseMenu:
		return
	f["kind"] = "bund_war"
	f["attempt_id"] = f.fight_id
	f["guardian"] = f.get("foe", "?")
	(menu as PauseMenu).raid_attempt = f
