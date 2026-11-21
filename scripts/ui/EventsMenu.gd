class_name EventsMenu
extends RefCounted
## Online events (Online 100, area 7): the calendar, festivals with their shared goal and tiers,
## rule weeks with the event board, sighting days, rewards and titles after the end, and the
## recap. Opened from Friends when the "events" flag is on.

const ERRORS: Dictionary = {
	"feature_off": "Events are closed right now.",
	"no_such_event": "That event is not open.",
	"event_over": "That event is over.",
	"bad_tier": "That reward does not exist.",
	"not_helped": "You did not take part in this event.",
	"not_reached": "Not reached yet.",
	"claimed": "Already taken.",
	"bad_team": "Your team needs 1 to 6 different Spirlings.",
	"rules": "Your team does not fit this week's rules.",
	"still_running": "The event is still running.",
	"sync_first": "Your journey is not on the server yet. Try again in a moment.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else FriendsMenu.error_text(r)

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

## "3 d" / "5 h" / "12 min" until [param t].
static func span_text(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	if s >= 86400:
		return Loc.t("%d d") % (s / 86400)
	if s >= 3600:
		return Loc.t("%d h") % (s / 3600)
	return Loc.t("%d min") % maxi(1, s / 60)

## One calendar line for [param ev] at [param now].
static func line(ev: Dictionary, now: int) -> String:
	var n: String = OnlineEvents.name_of(ev)
	match OnlineEvents.state_of(ev, now):
		"upcoming": return Loc.t("%s  starts in %s") % [n, span_text(int(ev.starts) - now)]
		"running": return Loc.t("%s  ends in %s") % [n, span_text(int(ev.ends) - now)]
	return Loc.t("%s  over") % n

## Rules of a rule week in words.
static func rules_text(rules: Dictionary) -> String:
	var parts: Array[String] = []
	var els: Array = rules.get("elements", []) if rules.get("elements") is Array else []
	if not els.is_empty():
		var names: Array[String] = []
		for e: Variant in els:
			names.append(Loc.t(str(e).capitalize()))
		parts.append(Loc.t("Only %s Spirlings") % ", ".join(names))
	if rules.has("max_stage") and int(rules.max_stage) == 1:
		parts.append(Loc.t("Only first forms"))
	return ". ".join(parts) if not parts.is_empty() else Loc.t("No special rules")

## The festival's goal with every tier: "[x] 25 %  Tonic".
static func festival_text(ev: Dictionary, tiers: Array) -> String:
	var target: int = maxi(1, int(ev.get("target", 1)))
	var lines: Array[String] = [Loc.t("Everyone together: %d of %d") % [int(ev.total), target], Loc.t("You helped: %d") % int(ev.mine)]
	var rewards: Array = ev.get("rewards", []) if ev.get("rewards") is Array else []
	for i: int in tiers.size():
		var mark: String = "[x]" if OnlineEvents.tier_reached(int(ev.total), target, int(tiers[i])) else "[ ]"
		var item: String = FriendsMenu.item_name(str(rewards[i])) if i < rewards.size() else ""
		lines.append("%s %d %%  %s%s" % [mark, int(tiers[i]), item, "  " + Loc.t("(extra)") if int(tiers[i]) > 100 else ""])
	return "\n".join(lines)

## Tiers (1-based) the player may take now.
static func open_tiers(ev: Dictionary, tiers: Array) -> Array[int]:
	var out: Array[int] = []
	if int(ev.get("mine", 0)) <= 0:
		return out
	for i: int in tiers.size():
		if OnlineEvents.tier_reached(int(ev.total), int(ev.get("target", 1)), int(tiers[i])) and int(ev.get("claimed", 0)) & (1 << i) == 0:
			out.append(i + 1)
	return out

static func run(menu: MenuHost) -> void:
	while true:
		var r: Dictionary = await OnlineEvents.refresh()
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var now: int = int(r.data.get("now", 0))
		var events: Array = r.data.get("events", [])
		var labels: Array[String] = []
		for ev: Dictionary in events:
			labels.append(line(ev, now))
		labels.append("My titles")
		var idx: int = await menu.pick_strings("Event calendar", labels)
		if idx < 0:
			return
		if idx == events.size():
			await run_titles(menu, r.data.get("titles", []))
		else:
			await run_event(menu, events[idx], r.data.get("tiers", []), now)

static func run_titles(menu: MenuHost, titles: Array) -> void:
	var lines: Array[String] = []
	for t: Dictionary in titles:
		lines.append(OnlineEvents.title_text(str(t.title), OnlineEvents.name_of({"name": t.get("name"), "kind": ""})))
	await menu.info("\n".join(lines) if not lines.is_empty() else Loc.t("No titles yet. Take part in an event!"))

static func run_event(menu: MenuHost, ev: Dictionary, tiers: Array, now: int) -> void:
	var state: String = OnlineEvents.state_of(ev, now)
	var kind: String = str(ev.kind)
	if kind == "sighting":
		var names: Array[String] = []
		for s: Variant in ev.get("species", []):
			names.append(str(s))
		await menu.info(line(ev, now) + "\n" + Loc.t("These Spirlings appear %d times as often: %s") % [int(ev.get("boost", 1)), ", ".join(names)])
		return
	var head: String = line(ev, now) + "\n"
	if kind == "festival":
		head += festival_text(ev, tiers)
	else:
		head += rules_text(ev.get("rules", {}) if ev.get("rules") is Dictionary else {})
		head += "\n" + Loc.t("Rift wins since you entered: %d") % int(ev.mine)
	var opts: Array[String] = []
	if kind == "festival" and not open_tiers(ev, tiers).is_empty():
		opts.append("Take the rewards")
	if kind == "board" and state == "running":
		opts.append("Enter with my team" if not bool(ev.get("entered", false)) else "Enter again with my team")
	opts.append("Event board")
	if state == "ended":
		opts.append("Look back")
		if ev.get("award") == null and int(ev.get("mine", 0)) > 0:
			opts.append("Take the final reward")
	var idx: int = await menu.pick_strings(head, opts)
	if idx < 0:
		return
	match opts[idx]:
		"Take the rewards":
			for t: int in open_tiers(ev, tiers):
				var c: Dictionary = await TradeMenu.bag_call("event_claim", {"p_event": str(ev.id), "p_tier": t})
				if not _ok(c):
					await menu.info(error_text(c))
					return
				Sound.sfx("coin")
				await menu.info(Loc.t("%d %% reached! You got: %s") % [int(tiers[t - 1]), FriendsMenu.item_name(str(c.data.item))])
		"Enter with my team", "Enter again with my team":
			var team: Array = []
			for s: Spirling in GameState.party:
				if not team.has(s.data.species_name):
					team.append(s.data.species_name)
			var why: String = OnlineEvents.team_error(team, ev.get("rules", {}) if ev.get("rules") is Dictionary else {})
			if not why.is_empty():
				await menu.info(str(ERRORS[why]))
				return
			var e: Dictionary = await Online.call_fn("event_enter", {"p_event": str(ev.id), "p_team": team})
			await menu.info("You are in! Every Rift you win from now counts." if _ok(e) else error_text(e))
		"Event board": await run_board(menu, ev)
		"Look back": await run_recap(menu, ev)
		"Take the final reward":
			var w: Dictionary = await TradeMenu.bag_call("event_reward", {"p_event": str(ev.id)})
			if not _ok(w):
				await menu.info(error_text(w))
				return
			Sound.sfx("coin")
			var got: String = OnlineEvents.title_text(str(w.data.title), OnlineEvents.name_of(ev))
			if w.data.get("item") != null:
				got += "\n" + Loc.t("You got: %s") % FriendsMenu.item_name(str(w.data.item))
			await menu.info(Loc.t("Place %d of %d.") % [int(w.data.rank), int(w.data.players)] + "\n" + got)

static func run_board(menu: MenuHost, ev: Dictionary) -> void:
	var friends_only: bool = true
	while true:
		var r: Dictionary = await Online.call_fn("event_board", {"p_event": str(ev.id), "p_friends": friends_only})
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var lines: Array[String] = []
		for row: Dictionary in r.data.get("rows", []):
			var n: String = str(row.get("name", ""))
			var you: String = "  " + Loc.t("(you)") if bool(row.get("me", false)) else ""
			lines.append("%d. %s  %d%s" % [int(row.rank), n if not n.is_empty() else "Wanderer", int(row.score), you])
		if lines.is_empty():
			lines.append(Loc.t("Nobody on the board yet."))
		var idx: int = await menu.pick_strings(OnlineEvents.name_of(ev) + "\n" + "\n".join(lines),
			["Show everyone" if friends_only else "Show friends"] as Array[String])
		if idx < 0:
			return
		friends_only = not friends_only

static func run_recap(menu: MenuHost, ev: Dictionary) -> void:
	var r: Dictionary = await Online.call_fn("event_recap", {"p_event": str(ev.id)})
	if not _ok(r):
		await menu.info(error_text(r))
		return
	var d: Dictionary = r.data
	var lines: Array[String] = [OnlineEvents.name_of(ev), Loc.t("Your score: %d (best: %d)") % [int(d.score), int(d.best)]]
	if d.get("rank") != null:
		lines.append(Loc.t("Place %d of %d.") % [int(d.rank), int(d.players)])
	if str(d.kind) == "festival":
		lines.append(Loc.t("Together you reached %d of %d reward tiers.") % [int(d.reached), (OnlineEvents.config().get("tiers", []) as Array).size()])
	if d.get("award") is Dictionary:
		lines.append(OnlineEvents.title_text(str(d.award.title), OnlineEvents.name_of(ev)))
	await menu.info("\n".join(lines))
