class_name LiveDuelMenu
extends RefCounted
## Friends > Live duels (Online 100, area 1): invite a friend, answer invites, pick 3 of 6 (with a
## borrowed Spirling, point 45), then the duel itself runs in the battle screen (LiveDuelStage), as
## does watching a friend. Afterwards: the result, a result picture, rematch and report.

## The duel that ended last in the battle screen; "Your last duel" opens its result.
static var last_id: int = 0

const ERRORS: Dictionary = {
	"feature_off": "Live duels are closed right now.",
	"not_friends": "You can only duel friends.",
	"team_too_small": "Both teams need at least 3 Spirlings.",
	"duel_closed": "This duel is over.",
	"no_such_duel": "This duel is over.",
	"bad_pick": "Pick 3 different Spirlings.",
	"wrong_round": "That round is already over.",
	"already_moved": "You already chose for this round.",
	"bad_input": "That choice does not work.",
	"not_over": "The duel is not over yet.",
	"no_such_loan": "That loan has ended.",
	"used": "You already used a borrowed Spirling here.",
}

static func error_text(r: Dictionary) -> String:
	var code: String = str(r.data.get("error", "")) if r.get("data") is Dictionary else str(r.get("error", ""))
	return ERRORS.get(code, Online.error_text(code))

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

static func run(menu: PauseMenu, friends: Array) -> void:
	while true:
		await Online.push_team()
		var r: Dictionary = await Online.call_fn("live_list")
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var duels: Array = r.data.duels
		var labels: Array[String] = []
		for d: Dictionary in duels:
			labels.append(duel_line(d))
		labels.append("Invite a friend...")
		labels.append("Watch a friend's duel...")
		if last_id > 0:
			labels.append("Your last duel")
		var idx: int = await menu.pick_strings("Live duels", labels)
		if idx < 0:
			return
		if idx < duels.size():
			await run_duel(menu, int(duels[idx].id), str(duels[idx].get("name", "")))
		elif idx == duels.size():
			await invite(menu, friends)
		elif idx == duels.size() + 1:
			await watch(menu)
		else:
			await run_duel(menu, last_id)
		if not menu.live_stage.is_empty():
			return

static func duel_line(d: Dictionary) -> String:
	if d.state == "invited":
		return Loc.t("%s invites you") % str(d.name) if int(d.side) == 1 else Loc.t("Waiting for %s") % str(d.name)
	return Loc.t("Duel with %s") % str(d.name)

static func invite(menu: PauseMenu, friends: Array) -> void:
	var labels: Array[String] = []
	for f: Dictionary in friends:
		labels.append(str(f.get("name", "")))
	var idx: int = await menu.pick_strings("Invite a friend...", labels)
	if idx < 0:
		return
	var r: Dictionary = await Online.call_fn("live_invite", {"p_code": str(friends[idx].code)})
	await menu.info(Loc.t("Invite sent. It stays open for 10 minutes.") if _ok(r) else error_text(r))

static func run_duel(menu: PauseMenu, id: int, friend: String = "") -> void:
	while true:
		var r: Dictionary = await Online.call_fn("live_state", {"p_id": id})
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var d: Dictionary = r.data
		# The duel itself runs in the battle screen, after the menu has closed.
		if str(d.state) == "running":
			menu.live_stage = {"id": id, "name": friend if not friend.is_empty() else Loc.t("Friend")}
			return
		var entries: Array[String] = actions(d)
		if not Online.flag_on("lend"):
			entries.erase("Take a borrowed Spirling along")
		if str(d.state) == "picking" and not bool(d.picked[int(d.side)]):
			entries.push_front("Look again")
		elif str(d.state) == "picking":
			entries = ["Look again", "Give up"] as Array[String]
		var idx: int = await menu.pick_strings(state_text(d, int(Time.get_unix_time_from_system())), entries)
		if idx < 0:
			return
		match entries[idx]:
			"Look again":
				r = {}
			"Accept":
				r = await Online.call_fn("live_answer", {"p_id": id, "p_accept": true})
			"Decline":
				r = await Online.call_fn("live_answer", {"p_id": id, "p_accept": false})
			"Pick 3":
				r = await pick(menu, d)
			"Take a borrowed Spirling along":
				r = await borrow(menu, id)
			"Give up":
				if await menu.confirm("Really give up this duel?"):
					r = await Online.call_fn("live_forfeit", {"p_id": id})
			"Rematch":
				r = await Online.call_fn("live_rematch", {"p_id": id})
				if _ok(r):
					await menu.info("Rematch invite sent.")
					return
			"Save a result picture":
				var me: int = int(d.side)
				var other: String = friend if not friend.is_empty() else Loc.t("Friend")
				await menu.info(await ResultCard.save(menu, ResultCard.facts_of_duel(d, [Loc.t("You"), other] if me == 0 else [other, Loc.t("You")])))
				r = {}
			"Report the rival...":
				await SafetyMenu.report(menu, "duel", id)
				r = {}
		if not r.is_empty() and not _ok(r):
			await menu.info(error_text(r))

## The unused Spirlings friends lent to the player: lend_list rows.
static func loans() -> Array:
	var r: Dictionary = await Online.call_fn("lend_list")
	var out: Array = []
	if _ok(r):
		for l: Dictionary in r.data.get("borrowed", []):
			if str(l.get("state", "")) == "lent":
				out.append(l)
	return out

static func loan_line(l: Dictionary) -> String:
	var mon: Dictionary = l.get("mon", {})
	return Loc.t("%s Ring %d (from %s)") % [str(mon.get("species", "?")), int(mon.get("level", 1)), str(l.get("name")) if l.get("name") != null else Loc.t("Friend")]

## Point 45: one borrowed Spirling joins the Spirlings to pick from. The loan is used up by it.
static func borrow(menu: PauseMenu, id: int) -> Dictionary:
	var rows: Array = await loans()
	if rows.is_empty():
		await menu.info("No friend has lent you a Spirling right now.")
		return {}
	var labels: Array[String] = []
	for l: Dictionary in rows:
		labels.append(loan_line(l))
	var idx: int = await menu.pick_strings("It joins this one duel. After that the loan is used up.", labels)
	if idx < 0:
		return {}
	return await Online.call_fn("live_borrow", {"p_id": id, "p_loan": int(rows[idx].id)})

## The choices that fit the duel's state and side.
static func actions(d: Dictionary) -> Array[String]:
	match str(d.state):
		"invited": return ["Accept", "Decline"] as Array[String] if int(d.side) == 1 else [] as Array[String]
		"picking":
			if bool(d.picked[int(d.side)]):
				return ["Give up"] as Array[String]
			var has_loan: bool = (d.get("show", [[], []])[int(d.side)] as Array).any(func(x: Dictionary) -> bool: return x.has("loan"))
			return (["Pick 3", "Give up"] as Array[String]) if has_loan else (["Pick 3", "Take a borrowed Spirling along", "Give up"] as Array[String])
		"running": return ["Enter the duel"] as Array[String]
		"done": return ["Rematch", "Save a result picture", "Report the rival..."] as Array[String]
	return [] as Array[String]

static func state_text(d: Dictionary, now: int) -> String:
	var lines: Array[String] = []
	match str(d.state):
		"invited": lines.append(Loc.t("Waiting for an answer."))
		"picking":
			lines.append(Loc.t("Both see 6 and pick 3."))
			var foe: Array = d.show[1 - int(d.side)]
			lines.append(Loc.t("Their team: %s") % ", ".join(foe.map(func(x: Dictionary) -> String: return str(x.species))))
		"running":
			lines.append(Loc.t("Round %d") % int(d.round))
			lines.append(Loc.t("Time left: %d s") % LiveDuel.seconds_left(int(d.deadline), now))
		"done", "expired":
			lines.append(LiveDuel.result_text(int(d.side), int(d.winner), str(d.reason)))
	for e: Dictionary in (d.emotes as Array).slice(-3):
		lines.append(("%s: %s" % [Loc.t("You") if int(e.side) == int(d.side) else Loc.t("Friend"), LiveDuel.emote_text(int(e.emote))]))
	return "\n".join(lines)

static func pick(menu: PauseMenu, d: Dictionary) -> Dictionary:
	var mine: Array = d.show[int(d.side)]
	var chosen: Array = []
	while chosen.size() < 3:
		var labels: Array[String] = []
		for i: int in mine.size():
			labels.append(("%s Ring %d" % [str(mine[i].species), int(mine[i].get("level", 1))])
				+ (" " + Loc.t("(borrowed)") if (mine[i] as Dictionary).has("loan") else "") + (" *" if chosen.has(i) else ""))
		var idx: int = await menu.pick_strings(Loc.t("Pick 3 (%d chosen)") % chosen.size(), labels)
		if idx < 0:
			return {}
		if not chosen.has(idx):
			chosen.append(idx)
	return await Online.call_fn("live_pick", {"p_id": int(d.id), "p_pick": chosen})

# --- Playing the rounds (points 1-3, 10) and watching a friend (73) ---------------------------------

## What happened last round, who stands where, and at the end the damage per Spirling (point 10).
## [param side] -1 = a watcher.
static func battle_lines(sim: LiveDuelSim, side: int) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(sim.last_lines.slice(-6))
	var mine: int = maxi(side, 0)
	lines.append(Loc.t("%s  against  %s") % [sim.active_line(mine), sim.active_line(1 - mine)])
	if sim.finished():
		lines.append_array(sim.summary(mine))
		lines.append_array(sim.summary(1 - mine))
	return lines

## Running duels of friends, one finished round behind.
static func watch(menu: PauseMenu) -> void:
	var r: Dictionary = await Online.call_fn("live_watch_list")
	if not _ok(r):
		await menu.info(error_text(r))
		return
	var duels: Array = r.data.get("duels", [])
	if duels.is_empty():
		await menu.info("None of your friends is in a live duel right now.")
		return
	var labels: Array[String] = []
	for d: Dictionary in duels:
		labels.append(Loc.t("%s against %s, round %d") % [str(d.names[0]), str(d.names[1]), int(d.round)])
	var idx: int = await menu.pick_strings("Watch a friend's duel...", labels)
	if idx < 0:
		return
	var w: Dictionary = await Online.call_fn("live_watch", {"p_id": int(duels[idx].id)})
	if not _ok(w):
		await menu.info(error_text(w))
		return
	menu.live_stage = {"id": int(duels[idx].id), "watch": true, "names": duels[idx].names}

## A duel in a few lines, for a place without the battle screen.
static func watch_text(d: Dictionary) -> String:
	var lines: Array[String] = [Loc.t("%s against %s") % [str(d.names[0]), str(d.names[1])]]
	var sim: LiveDuelSim = LiveDuelSim.of(d)
	if str(d.state) == "done":
		lines.append(Loc.t("The duel is over."))
		if int(d.winner) >= 0:
			lines.append(Loc.t("%s wins!") % str(d.names[int(d.winner)]))
		elif str(d.get("reason", "")) == "played":
			lines.append(Loc.t("Draw"))
	else:
		lines.append(Loc.t("Round %d (you see it one move later)") % maxi(1, int(d.round) - 1))
	if sim != null:
		lines.append_array(battle_lines(sim, -1))
	return "\n".join(lines)
