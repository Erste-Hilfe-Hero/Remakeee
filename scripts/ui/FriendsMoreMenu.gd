class_name FriendsMoreMenu
extends RefCounted
## Friends and the shared world (Online 100, area 6) inside Menu > Friends: favourite friends
## (59), the friendship rewards of levels 6-10 (56), the joint task of the day (57), the league
## rank on the Wanderer card (53), suggested Wayfarers from recent league battles (60) and the
## invite link (55). Server side: 20261112230020_friends_more.sql.

const ERRORS: Dictionary = {
	"favorites_full": "You already have 10 favourites. Remove one first.",
	"friend_level": "Your friendship is not at that level yet.",
	"already": "You already took that.",
	"not_done": "You both have to do the task first.",
	"nothing": "Nothing to take yet. Rewards come once your invited friend is your friend.",
	"too_late": "Invite links only work in the first 7 days of a new journey.",
	"feature_off": "This is closed right now.",
	"no_save": "Save your journey first, then try again.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else TradeMenu.error_text(r)

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

## True when a friendship reward or a finished joint task waits for this friend.
static func has_ready(f: Dictionary) -> bool:
	var t: Variant = f.get("task")
	var task_ready: bool = t is Dictionary and bool(t.get("mine", false)) and bool(t.get("theirs", false)) \
		and not bool(t.get("claimed", false))
	return task_ready or not (f.get("level_ready", []) as Array).is_empty()

## "League rank: Captain" for the Wanderer card (point 53).
static func rank_line(f: Dictionary) -> String:
	var r: int = int(f.get("rank", -1))
	var name: String = Loc.t(LeagueRules.rank_name(LeagueRules.ranks_config(), r)) if r >= 0 else "-"
	return Loc.t("League rank: %s") % name

## "Task of the day: Wave to each other\nYou: done   Ben: not yet" (point 57).
static func task_text(f: Dictionary) -> String:
	var t: Dictionary = f.get("task", {}) if f.get("task") is Dictionary else {}
	var head: String = Loc.t("Task of the day: %s") % Loc.t(FriendRules.task_text(str(t.get("kind", ""))))
	var mine: String = Loc.t("done") if bool(t.get("mine", false)) else Loc.t("not yet")
	var theirs: String = Loc.t("done") if bool(t.get("theirs", false)) else Loc.t("not yet")
	return head + "\n" + Loc.t("You: %s   %s: %s") % [mine, str(f.get("name", "")), theirs]

## Extra rows for one friend in run_friend.
static func friend_entries(f: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append("Remove from favourites" if bool(f.get("fav", false)) else "Add to favourites")
	out.append("Task of the day")
	for lvl: Variant in f.get("level_ready", []):
		out.append(Loc.t("Friendship reward (level %d)") % int(lvl))
	return out

## Runs an extra row picked in run_friend. Returns false when [param label] is not one of them.
static func run_entry(menu: MenuHost, f: Dictionary, label: String) -> bool:
	var code: String = str(f.code)
	if label == "Add to favourites" or label == "Remove from favourites":
		var on: bool = label == "Add to favourites"
		var r: Dictionary = await Online.call_fn("friend_favorite", {"p_code": code, "p_on": on})
		if _ok(r):
			f["fav"] = on
			menu.toast("Added to favourites." if on else "Removed from favourites.")
		else:
			await menu.info(error_text(r))
		return true
	if label == "Task of the day":
		await run_task(menu, f)
		return true
	for lvl: Variant in (f.get("level_ready", []) as Array).duplicate():
		if label == Loc.t("Friendship reward (level %d)") % int(lvl):
			var r: Dictionary = await TradeMenu.bag_call("friend_level_claim", {"p_code": code, "p_level": int(lvl)})
			if _ok(r):
				(f.level_ready as Array).erase(lvl)
				Sound.sfx("coin")
				await menu.info(Loc.t("You got: %s") % reward_text(r.data))
			else:
				await menu.info(error_text(r))
			return true
	return false

static func reward_text(d: Dictionary) -> String:
	var n: int = int(d.get("count", 1))
	var item: String = TradeMenu.item_name(str(d.get("item", "")))
	return item if n == 1 else "%s x%d" % [item, n]

static func run_task(menu: MenuHost, f: Dictionary) -> void:
	var t: Dictionary = f.get("task", {}) if f.get("task") is Dictionary else {}
	if bool(t.get("claimed", false)):
		await menu.info(task_text(f) + "\n" + Loc.t("You took today's reward. A new task comes tomorrow."))
		return
	if not (bool(t.get("mine", false)) and bool(t.get("theirs", false))):
		await menu.info(task_text(f) + "\n" + Loc.t("When you both did it, you each get a reward and more friendship."))
		return
	var idx: int = await menu.pick_strings(task_text(f), ["Take the reward"] as Array[String])
	if idx < 0:
		return
	var r: Dictionary = await TradeMenu.bag_call("pair_task_claim", {"p_code": str(f.code)})
	if _ok(r):
		t["claimed"] = true
		Sound.sfx("coin")
		await menu.info(Loc.t("You got: %s") % reward_text(r.data))
	else:
		await menu.info(error_text(r))

## "League battle 3 days ago, Captain" (point 60): no name, no code.
static func suggestion_line(row: Dictionary) -> String:
	var days: int = maxi(0, (Online.unix_now() - int(row.get("at", 0))) / 86400)
	var when: String = Loc.t("today") if days == 0 else Loc.t("%d days ago") % days
	var r: int = int(row.get("rank", -1))
	var rank: String = Loc.t(LeagueRules.rank_name(LeagueRules.ranks_config(), r)) if r >= 0 else Loc.t("no rank yet")
	return Loc.t("League battle %s, %s") % [when, rank]

## Opponents of recent league battles; picking one sends a friend request without seeing a code.
static func run_suggestions(menu: MenuHost) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("friend_suggestions")
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var rows: Array = r.data.get("rows", [])
		if rows.is_empty():
			await menu.info("No suggestions right now. Wayfarers you met in league battles show up here.")
			return
		var labels: Array[String] = []
		for row: Dictionary in rows:
			labels.append(suggestion_line(row))
		var idx: int = await menu.pick_strings("Suggested Wayfarers", labels)
		if idx < 0:
			return
		if not await menu.confirm("Send a friend request? They see your name and decide."):
			continue
		var q: Dictionary = await Online.call_fn("friend_suggest_request", {"p_match": int(rows[idx].ref)})
		if _ok(q):
			Sound.sfx("confirm")
			await menu.info("Request sent. You are friends once they accept.")
		else:
			await menu.info(FriendsMenu.error_text(q))

## The invite link with its reward (point 55).
static func run_invite(menu: MenuHost) -> void:
	while true:
		var st: Dictionary = await Online.call_fn("invite_state")
		if not _ok(st):
			await menu.info(error_text(st))
			return
		var d: Dictionary = st.data
		var reward: String = reward_text(d.get("reward", {}) if d.get("reward") is Dictionary else {})
		var title: String = Loc.t("Invite a friend: you both get %s once you are friends.") % reward + "\n" \
			+ Loc.t("Invited: %d   Rewards taken: %d of %d") % [int(d.get("invited", 0)), int(d.get("paid", 0)), int(d.get("max", 10))]
		var labels: Array[String] = ["Copy my invite link"]
		if int(d.get("ready", 0)) > 0:
			labels.append(Loc.t("Take rewards (%d)") % int(d.ready))
		if bool(d.get("can_redeem", false)):
			labels.append("I was invited...")
		var idx: int = await menu.pick_strings(title, labels)
		if idx < 0:
			return
		var picked: String = labels[idx]
		if picked == "Copy my invite link":
			DisplayServer.clipboard_set(FriendRules.invite_link(str(d.get("code", ""))))
			Sound.sfx("confirm")
			menu.toast("Copied.")
		elif picked == "I was invited...":
			var code: String = await CodePrompt.ask(menu, "Friend code of your friend", 8)
			if not code.is_empty():
				await redeem(menu, code)
		else:
			var r: Dictionary = await TradeMenu.bag_call("invite_claim", {})
			if _ok(r):
				Sound.sfx("coin")
				await menu.info(Loc.t("You got: %s") % reward_text(r.data))
			else:
				await menu.info(error_text(r))

## Redeems the friend code of an invite link (also from a chimora://friend/<code> link).
static func redeem(menu: MenuHost, code: String) -> void:
	var r: Dictionary = await Online.call_fn("invite_redeem", {"p_code": code})
	if _ok(r):
		Sound.sfx("friend")
		await menu.info("Request sent. Once you are friends, you both take the invite reward under Friends, Invite a friend.")
	elif r.ok and r.data is Dictionary and str(r.data.get("error", "")) == "already":
		await menu.info("You already used an invite link.")
	else:
		await menu.info(error_text(r))
