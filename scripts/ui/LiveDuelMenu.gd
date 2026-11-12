class_name LiveDuelMenu
extends RefCounted
## Friends > Live duels (Online 100, area 1): invite a friend, answer invites, pick 3 of 6,
## send set emotes, give up (with a second question), see the result and ask for a rematch.

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
		var idx: int = await menu.pick_strings("Live duels", labels)
		if idx < 0:
			return
		if idx < duels.size():
			await run_duel(menu, int(duels[idx].id))
		elif idx == duels.size():
			await invite(menu, friends)
		else:
			await watch(menu)

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

static func run_duel(menu: PauseMenu, id: int) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("live_state", {"p_id": id})
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var d: Dictionary = r.data
		var sim: LiveDuelSim = LiveDuelSim.of(d) if str(d.state) in ["running", "done"] else null
		var side: int = int(d.side)
		# Both phones play the same rounds; when the battle is over each tells the server who won.
		if sim != null and sim.finished() and str(d.state) == "running":
			r = await Online.call_fn("live_finish", {"p_id": id, "p_winner": sim.winner()})
			if _ok(r) and str(r.data.state) == "running":
				await menu.info("\n".join(battle_lines(sim, side) + ([Loc.t("Waiting for your friend's result.")] as Array[String])))
				return
			continue
		var entries: Array[String] = actions(d)
		var moved: bool = sim != null and str(d.state) == "running" and (d.moves as Dictionary).get(str(int(d.round))) is Array \
			and d.moves[str(int(d.round))][side] != null
		if moved:
			entries.erase("Choose your move")
			entries.push_front("Look again")
		var text: String = state_text(d, int(Time.get_unix_time_from_system()))
		if sim != null:
			text += "\n" + "\n".join(battle_lines(sim, side))
			if moved:
				text += "\n" + Loc.t("You chose. Waiting for your friend.")
		var idx: int = await menu.pick_strings(text, entries)
		if idx < 0:
			return
		match entries[idx]:
			"Look again":
				r = {}
			"Choose your move":
				var options: Array = sim.choices(side)
				var labels: Array[String] = []
				for o: Dictionary in options:
					labels.append(str(o.label))
				var c: int = await menu.pick_strings(Loc.t("Round %d: what will %s do?") % [int(d.round), sim.active_line(side)], labels)
				r = await Online.call_fn("live_move", {"p_id": id, "p_round": int(d.round), "p_input": options[c].input}) if c >= 0 else {}
			"Accept":
				r = await Online.call_fn("live_answer", {"p_id": id, "p_accept": true})
			"Decline":
				r = await Online.call_fn("live_answer", {"p_id": id, "p_accept": false})
			"Pick 3":
				r = await pick(menu, d)
			"Send an emote":
				var e: int = await menu.pick_strings("Send an emote", LiveDuel.EMOTES)
				if e >= 0:
					r = await Online.call_fn("live_emote", {"p_id": id, "p_emote": e})
			"Give up":
				if await menu.confirm("Really give up this duel?"):
					r = await Online.call_fn("live_forfeit", {"p_id": id})
			"Rematch":
				r = await Online.call_fn("live_rematch", {"p_id": id})
				if _ok(r):
					await menu.info("Rematch invite sent.")
					return
			"Report the rival...":
				await SafetyMenu.report(menu, "duel", id)
				r = {}
		if not r.is_empty() and not _ok(r):
			await menu.info(error_text(r))

## The choices that fit the duel's state and side.
static func actions(d: Dictionary) -> Array[String]:
	match str(d.state):
		"invited": return ["Accept", "Decline"] as Array[String] if int(d.side) == 1 else [] as Array[String]
		"picking": return (["Give up"] as Array[String]) if bool(d.picked[int(d.side)]) else (["Pick 3", "Give up"] as Array[String])
		"running": return ["Choose your move", "Send an emote", "Give up"] as Array[String]
		"done": return ["Rematch", "Report the rival..."] as Array[String]
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
			labels.append(("%s Ring %d" % [str(mine[i].species), int(mine[i].get("level", 1))]) + (" *" if chosen.has(i) else ""))
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
	while true:
		var w: Dictionary = await Online.call_fn("live_watch", {"p_id": int(duels[idx].id)})
		if not _ok(w):
			await menu.info(error_text(w))
			return
		if await menu.pick_strings(watch_text(w.data), ["Look again"] as Array[String]) < 0:
			return

static func watch_text(d: Dictionary) -> String:
	var lines: Array[String] = [Loc.t("%s against %s") % [str(d.names[0]), str(d.names[1])]]
	var sim: LiveDuelSim = LiveDuelSim.of(d)
	if str(d.state) == "done":
		lines.append(Loc.t("The duel is over."))
		if int(d.winner) >= 0:
			lines.append(Loc.t("%s wins!") % str(d.names[int(d.winner)]))
	else:
		lines.append(Loc.t("Round %d (you see it one move later)") % maxi(1, int(d.round) - 1))
	if sim != null:
		lines.append_array(battle_lines(sim, -1))
	return "\n".join(lines)
