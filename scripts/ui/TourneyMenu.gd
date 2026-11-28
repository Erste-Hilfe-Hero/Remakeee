class_name TourneyMenu
extends RefCounted
## The weekend tournament (Online 100, points 62, 74, 80): sign up with the fair-league team, 8
## players, knockout; each round is one battle against the rival's team that the server's referee
## checks. Everyone can watch the finals ("Battles of the week"). Opened from Friends when the
## "events" flag is on; a started battle goes to [member PauseMenu.raid_attempt].

const ERRORS: Dictionary = {
	"feature_off": "The tournament is closed right now.",
	"tourney_closed": "The tournament runs on Saturdays and Sundays.",
	"joined": "You already play in a tournament this weekend.",
	"no_tourney": "You have no tournament battle right now.",
	"fought": "You already fought this round.",
	"no_reward": "There is no tournament reward for you right now.",
	"no_such_fight": "That battle can't be shown any more.",
	"under_review": "Your account is being checked. Tournaments open again after the check.",
	"empty_team": "Your team is empty.",
	"not_in_team": "Save your journey first, then try again.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else FriendsMenu.error_text(r)

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

static func player_name(p: Dictionary) -> String:
	if bool(p.get("me", false)):
		return Loc.t("You")
	var n: String = str(p.get("name", ""))
	return n if not n.is_empty() else Loc.t("Wayfarer %d") % int(p.get("place", 0))

## What the tournament screen says.
static func info_text(d: Dictionary, now: int) -> String:
	var lines: Array[String] = [Loc.t("Weekend tournament: %d Wayfarers, knockout. Everyone fights at Ring 50.") % int(d.size)]
	var t: Variant = d.get("tourney")
	if not t is Dictionary:
		lines.append(Loc.t("Sign-up is open.") if bool(d.get("day", false)) else Loc.t("Sign-up opens on Saturday."))
		return "\n".join(lines)
	var total: int = int(d.get("rounds", 3))
	match str(t.state):
		"signup":
			lines.append(Loc.t("Signed up: %d of %d. It starts when all places are taken.") % [(t.players as Array).size(), int(d.size)])
		"running":
			lines.append(Loc.t("%s, %s left") % [Loc.t(TourneyRules.round_name(int(t.round), total)),
				EventsMenu.span_text(int(t.round_ends) - now)])
			if int(t.out_round) > 0:
				lines.append(Loc.t("You went out in the %s.") % Loc.t(TourneyRules.round_name(int(t.out_round), total)))
			elif t.get("foe") is Dictionary:
				lines.append(Loc.t("Your rival: %s with %s") % [player_name(t.foe), ", ".join(t.foe.get("team", []))])
				lines.append({"won": Loc.t("Your battle: won. Waiting for the other battles."),
					"lost": Loc.t("Your battle: lost. Your rival still has to do better."),
					"submitted": Loc.t("Your battle is being checked.")}.get(str(t.get("fight")), Loc.t("Your battle is open.")))
		"done":
			if bool(t.get("won", false)):
				lines.append(Loc.t("You won the tournament!"))
			elif int(t.out_round) > 0:
				lines.append(Loc.t("You went out in the %s.") % Loc.t(TourneyRules.round_name(int(t.out_round), total)))
	for p: Dictionary in t.get("players", []):
		lines.append("%d. %s%s" % [int(p.place), player_name(p), "" if int(p.out_round) == 0 else "  " + Loc.t("out")])
	return "\n".join(lines)

static func actions(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var t: Variant = d.get("tourney")
	if not t is Dictionary or (str(t.state) == "done" and bool(t.claimed)):
		if bool(d.get("day", false)) and (not t is Dictionary or str(t.state) == "done"):
			out.append("Sign up with my team")
	elif str(t.state) == "running" and int(t.out_round) == 0 and t.get("foe") is Dictionary and t.get("fight") == null:
		out.append("Start my battle")
	elif str(t.state) == "done" and not bool(t.claimed):
		out.append("Take the reward")
	out.append("Battles of the week")
	out.append("Rewards")
	return out

static func rewards_text(rewards: Array) -> String:
	var lines: Array[String] = []
	for i: int in mini(rewards.size(), TourneyRules.TIER_TEXT.size()):
		lines.append("%s: %s x%d" % [Loc.t(TourneyRules.TIER_TEXT[i]), FriendsMenu.item_name(str(rewards[i].item)), int(rewards[i].count)])
	return "\n".join(lines)

## "W46  Champion: Kindlop, Puddlet against Mossling  (won, 6 rounds)" for the finals list.
static func final_line(f: Dictionary) -> String:
	var who: String = str(f.get("name", ""))
	if who.is_empty():
		who = Loc.t("Champion") if bool(f.get("champion", false)) else Loc.t("Finalist")
	return Loc.t("%s  %s: %s against %s  (%s, %d rounds)") % [str(f.get("week", "")).get_slice("-", 1), who,
		", ".join(f.teams[0]), ", ".join(f.teams[1]), Loc.t("won") if bool(f.get("won", false)) else Loc.t("lost"), int(f.get("rounds", 0))]

static func run(menu: PauseMenu) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("tourney_info")
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var acts: Array[String] = actions(r.data)
		var idx: int = await menu.pick_strings(info_text(r.data, int(Time.get_unix_time_from_system())), acts)
		if idx < 0:
			return
		match acts[idx]:
			"Sign up with my team":
				await Online.push_team()
				var j: Dictionary = await Online.call_fn("tourney_join", {"p_pick": LeagueMenu.pick_of(GameState.party)})
				if not _ok(j):
					await menu.info(error_text(j))
			"Start my battle":
				await Online.push_team()
				var f: Dictionary = await Online.call_fn("tourney_fight")
				if not _ok(f):
					await menu.info(error_text(f))
					continue
				f.data["kind"] = "tourney"
				f.data["attempt_id"] = f.data.fight_id
				f.data["guardian"] = player_name(r.data.tourney.foe)
				menu.raid_attempt = f.data
				return
			"Take the reward":
				var c: Dictionary = await TradeMenu.bag_call("tourney_reward", {})
				await menu.info(Loc.t("%s: you got %s x%d.") % [Loc.t(TourneyRules.TIER_TEXT[clampi(int(c.data.tier), 0, 3)]),
					FriendsMenu.item_name(str(c.data.item)), int(c.data.count)] if _ok(c) else error_text(c))
			"Rewards":
				await menu.info(rewards_text(r.data.get("rewards", [])))
			"Battles of the week":
				if await finals(menu):
					return

## The finals of the last tournaments (points 74, 80). Returns true when a replay was picked.
static func finals(menu: PauseMenu) -> bool:
	var r: Dictionary = await Online.call_fn("tourney_finals")
	if not _ok(r):
		await menu.info(error_text(r))
		return false
	var rows: Array = r.data.get("rows", [])
	if rows.is_empty():
		await menu.info("No final was played yet. Come back after the weekend.")
		return false
	var labels: Array[String] = []
	for f: Dictionary in rows:
		labels.append(final_line(f))
	var idx: int = await menu.pick_strings("Battles of the week: watch a final", labels)
	if idx < 0:
		return false
	var rep: Dictionary = await Online.call_fn("tourney_replay", {"p_fight": int(rows[idx].fight)})
	if not _ok(rep) or not rep.data.get("replay") is Dictionary:
		await menu.info(error_text(rep))
		return false
	menu.watch_snap = BattleReferee.from_expect(rep.data.replay, rep.data.replay.get("inputs", []))
	menu.watch_replay = true
	return true
