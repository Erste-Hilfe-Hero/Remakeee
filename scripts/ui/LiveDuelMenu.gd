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
		var idx: int = await menu.pick_strings("Live duels", labels)
		if idx < 0:
			return
		if idx < duels.size():
			await run_duel(menu, int(duels[idx].id))
		else:
			await invite(menu, friends)

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
		var entries: Array[String] = actions(d)
		var idx: int = await menu.pick_strings(state_text(d, int(Time.get_unix_time_from_system())), entries)
		if idx < 0:
			return
		match entries[idx]:
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
		if not r.is_empty() and not _ok(r):
			await menu.info(error_text(r))

## The choices that fit the duel's state and side.
static func actions(d: Dictionary) -> Array[String]:
	match str(d.state):
		"invited": return ["Accept", "Decline"] as Array[String] if int(d.side) == 1 else [] as Array[String]
		"picking": return (["Give up"] as Array[String]) if bool(d.picked[int(d.side)]) else (["Pick 3", "Give up"] as Array[String])
		"running": return ["Send an emote", "Give up"] as Array[String]
		"done": return ["Rematch"] as Array[String]
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
