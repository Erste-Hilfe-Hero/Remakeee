class_name RaidMenu
extends RefCounted
## Raid Rifts (plan area 7, items 2847-2851, 2871): 2 to 4 friends or bund members weaken one
## strong guardian together. Each attempt is a normal battle on the own screen, at most 10 rounds,
## free of cost. The damage counts once the server's referee checked the battle. Opened from
## Friends when the "raid" flag is on; a started attempt goes to [member PauseMenu.raid_attempt].

const ERRORS: Dictionary = {
	"feature_off": "Raid Rifts are closed right now.",
	"bad_party": "Pick 1 to 3 Wayfarers to go with you.",
	"no_such_code": "You can only open a Rift with friends or members of your bund.",
	"no_such_raid": "That Rift is gone.",
	"raid_closed": "That Rift is closed.",
	"no_tries": "No attempts left today. Tomorrow you have new ones.",
	"no_reward": "You need at least 5 percent of the damage for the reward.",
	"claimed": "You already took this reward.",
	"under_review": "Your account is being checked. Raids open again after the check.",
	"empty_team": "Your team is empty.",
	"not_in_team": "Save your journey first, then try again.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else FriendsMenu.error_text(r)

## "Leviarch  640/1200  open, 31 h left" for the list.
static func raid_line(r: Dictionary, now_s: int) -> String:
	var state: String
	if bool(r.get("won", false)):
		state = Loc.t("sealed")
	elif bool(r.get("open", false)):
		state = Loc.t("%d h left") % maxi(0, (int(r.closes_at) - now_s) / 3600)
	else:
		state = Loc.t("closed")
	return "%s  %d/%d  %s" % [str(r.guardian), int(r.hp_left), int(r.hp_total), state]

## The open reward table (item 2851): every item with its chance in percent.
static func rewards_text(rewards: Array, share_min: int) -> String:
	var total: int = 0
	for x: Dictionary in rewards:
		total += int(x.get("w", 0))
	var lines: Array[String] = [Loc.t("Everyone with at least %d percent of the damage gets the same reward:") % share_min]
	for x: Dictionary in rewards:
		var it: Dictionary = Database.item(str(x.item))
		var name: String = str(it.get("name", x.item)) if not it.is_empty() else str(x.item)
		lines.append("%s x%d  %d%%" % [Loc.t(name), int(x.get("count", 1)), roundi(100.0 * int(x.get("w", 0)) / maxf(1.0, total))])
	return "\n".join(lines)

static func run(menu: PauseMenu) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("raid_list")
		if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
			await menu.info(error_text(r))
			return
		var raids: Array = r.data.get("raids", [])
		var now_s: int = int(Time.get_unix_time_from_system())
		var labels: Array[String] = []
		for x: Dictionary in raids:
			labels.append(raid_line(x, now_s))
		labels.append_array(["Open a Raid Rift...", "Rewards", "Fastest Rifts"] as Array[String])
		var idx: int = await menu.pick_strings("Raid Rifts", labels)
		if idx < 0:
			return
		if idx < raids.size():
			await _run_raid(menu, raids[idx], r.data)
			if not menu.raid_attempt.is_empty():
				return
		elif idx == raids.size():
			await open(menu)
		elif idx == raids.size() + 2:
			var b: Dictionary = await Online.call_fn("raid_board")
			await menu.info(board_text(b.data.get("rows", [])) if b.ok and b.data is Dictionary else error_text(b))
		else:
			await menu.info(rewards_text(r.data.get("rewards", []), int(r.data.get("share_min", 5))))

static func _run_raid(menu: PauseMenu, x: Dictionary, list: Dictionary) -> void:
	var lines: Array[String] = [Loc.t("Guardian: %s, Ring %d") % [str(x.guardian), int(x.level)],
		Loc.t("Strength left: %d of %d") % [int(x.hp_left), int(x.hp_total)]]
	for m: Dictionary in x.get("members", []):
		lines.append("%s  %d" % [str(m.name), int(m.damage)])
	var opts: Array[String] = []
	if bool(x.get("open", false)) and int(x.tries_left) > 0:
		opts.append(Loc.t("Fight (%d attempts left today)") % int(x.tries_left))
	if x.get("reward") is Dictionary and not bool(x.get("claimed", false)):
		opts.append("Take the reward")
	if opts.is_empty():
		await menu.info("\n".join(lines))
		return
	var idx: int = await menu.pick_strings("\n".join(lines), opts)
	if idx < 0:
		return
	if opts[idx] == "Take the reward":
		var c: Dictionary = await Online.call_fn("raid_claim", {"p_raid": int(x.id)})
		if c.ok and c.data is Dictionary and bool(c.data.get("ok", false)):
			GameState.add_item(str(c.data.item), int(c.data.get("count", 1)))
			Sound.sfx("confirm")
			var it: Dictionary = Database.item(str(c.data.item))
			await menu.info(Loc.t("You got %s x%d.") % [Loc.t(str(it.get("name", c.data.item))), int(c.data.get("count", 1))])
		else:
			await menu.info(error_text(c))
		return
	if not await menu.confirm(Loc.t("At most %d rounds. Attempts cost nothing and your team is healed afterwards. Fight now?") % int(list.get("rounds", 10))):
		return
	await Online.push_team()
	var s: Dictionary = await Online.call_fn("raid_start", {"p_raid": int(x.id), "p_pick": LeagueMenu.pick_of(GameState.party)})
	if not s.ok or not s.data is Dictionary or not bool(s.data.get("ok", false)):
		await menu.info(error_text(s))
		return
	s.data["guardian"] = x.guardian
	menu.raid_attempt = s.data

## Pick 1 to 3 friends or bund members, then open the Rift.
static func open(menu: PauseMenu) -> void:
	var people: Array = []
	var seen: Dictionary = {}
	var f: Dictionary = await Online.call_fn("friends_list")
	if f.ok and f.data is Dictionary:
		for x: Dictionary in f.data.get("friends", []):
			people.append({"name": str(x.name), "code": str(x.code)})
			seen[str(x.code)] = true
	if Online.flag_on("bund"):
		var b: Dictionary = await Online.call_fn("bund_info")
		if b.ok and b.data is Dictionary and b.data.get("bund") is Dictionary:
			for m: Dictionary in b.data.bund.get("members", []):
				if not bool(m.get("me", false)) and not seen.has(str(m.code)):
					people.append({"name": str(m.name), "code": str(m.code)})
	if people.is_empty():
		await menu.info("Raid Rifts are for friends and bund members. Add a friend first.")
		return
	var chosen: Array = []
	while true:
		var labels: Array[String] = []
		for p: Dictionary in people:
			labels.append(("[x] " if chosen.has(p.code) else "[ ] ") + str(p.name))
		labels.append(Loc.t("Open the Rift (%d Wayfarers)") % (chosen.size() + 1))
		var idx: int = await menu.pick_strings("Who comes along? (1 to 3)", labels)
		if idx < 0:
			return
		if idx < people.size():
			var code: String = people[idx].code
			if chosen.has(code):
				chosen.erase(code)
			elif chosen.size() < 3:
				chosen.append(code)
			continue
		if chosen.is_empty():
			await menu.info("Pick 1 to 3 Wayfarers to go with you.")
			continue
		var tier: int = await menu.pick_strings("How hard?", RaidRules.TIER_NAMES)
		if tier < 0:
			continue
		var r: Dictionary = await Online.call_fn("raid_open", {"p_codes": chosen, "p_tier": tier})
		if r.ok and r.data is Dictionary and bool(r.data.get("legendary", false)):
			await menu.info(Loc.t("A legendary guardian waits in this Rift: %s") % str(r.data.guardian))
		if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
			Sound.sfx("confirm")
			await menu.info("The Raid Rift is open for 48 hours. Everyone has 3 attempts a day.")
		else:
			await menu.info(error_text(r))
		return

## The fastest won Rifts (point 29), without names.
static func board_text(rows: Array) -> String:
	if rows.is_empty():
		return Loc.t("No Rift was won yet.")
	var lines: Array[String] = []
	for i: int in rows.size():
		var x: Dictionary = rows[i]
		lines.append(Loc.t("%d. %s (%s, %d Wayfarers) %d min") % [i + 1, str(x.guardian),
			Loc.t(RaidRules.TIER_NAMES[clampi(int(x.tier), 0, 2)]), int(x.players), int(x.seconds) / 60])
	return "\n".join(lines)
