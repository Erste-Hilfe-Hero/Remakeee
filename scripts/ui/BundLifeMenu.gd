class_name BundLifeMenu
extends RefCounted
## Bund life (Online 100, area 4): the bund goal of the week, level and rewards, donations, the bund
## board, the leader's language and joining setting, and finding a bund. Opened from BundMenu.

const ERRORS: Dictionary = {
	"no_bund": "You are not in a bund.",
	"not_helped": "Help with the bund goal first.",
	"not_reached": "The bund has not reached its goal yet.",
	"claimed": "You already took this week's bund reward.",
	"bad_amount": "That amount does not work.",
	"not_donatable": "That item cannot be given.",
	"limit_today": "That is all you can give today.",
	"not_enough": "You do not have that much.",
	"bad_lang": "Pick a language from the list.",
	"sync_first": "Your journey is not on the server yet. Try again in a moment.",
}

static func error_text(r: Dictionary) -> String:
	var e: String = str(r.data.get("error", "")) if r.ok and r.data is Dictionary else str(r.get("error", ""))
	return str(ERRORS[e]) if ERRORS.has(e) else BundMenu.error_text(r)

static func _ok(r: Dictionary) -> bool:
	return r.ok and r.data is Dictionary and bool(r.data.get("ok", false))

## The bund's level line: "Level 3  xp 260/450".
static func level_text(life: Dictionary) -> String:
	if life.get("next") == null:
		return Loc.t("Level %d  xp %d (highest level)") % [int(life.level), int(life.xp)]
	return Loc.t("Level %d  xp %d/%d") % [int(life.level), int(life.xp), int(life.next)]

static func reward_text(rw: Dictionary) -> String:
	return "%s x%d" % [FriendsMenu.item_name(str(rw.get("item", ""))), int(rw.get("count", 1))]

static func run(menu: MenuHost, role: String) -> void:
	while true:
		var r: Dictionary = await Online.call_fn("bund_life")
		if not _ok(r):
			await menu.info(error_text(r))
			return
		var life: Dictionary = r.data
		var goal: Dictionary = life.goal
		var head: Array[String] = [level_text(life), Loc.t("Goal of the week: %s") % BundLife.goal_text(goal),
			Loc.t("You helped: %d") % int(goal.mine), Loc.t("Reward: %s") % reward_text(life.reward)]
		var opts: Array[String] = []
		if bool(goal.done) and not bool(goal.claimed) and int(goal.mine) > 0:
			opts.append("Take the bund reward")
		opts.append_array(["Give to the bund...", "Bund board", "Rewards by level"] as Array[String])
		if role == "leader":
			opts.append("Language and joining...")
		var idx: int = await menu.pick_strings("\n".join(head), opts)
		if idx < 0:
			return
		match opts[idx]:
			"Take the bund reward":
				var c: Dictionary = await TradeMenu.bag_call("bund_goal_claim", {})
				if _ok(c):
					Sound.sfx("coin")
					await menu.info(Loc.t("You got: %s") % reward_text(c.data))
				else:
					await menu.info(error_text(c))
			"Give to the bund...": await donate(menu, life.donate)
			"Bund board": await run_board(menu)
			"Rewards by level":
				var lines: Array[String] = []
				for band: Dictionary in life.get("rewards", []):
					lines.append(Loc.t("From level %d: %s") % [int(band.from), reward_text(band)])
				await menu.info(Loc.t("When the bund goal is reached, everyone who helped gets:") + "\n" + "\n".join(lines))
			"Language and joining...": await settings(menu, life)

## Coins in steps, or one tradeable item at a time. It becomes bund xp; nothing comes back.
static func donate(menu: MenuHost, d: Dictionary) -> void:
	var step: int = int(d.get("coin_step", 100))
	var opts: Array[String] = []
	var amounts: Array[int] = []
	for n: int in [step, step * 5, step * 10]:
		if n <= int(d.get("coins_left", 0)) and n <= GameState.money:
			opts.append(Loc.t("%d coins") % n)
			amounts.append(n)
	var items: Array[String] = []
	if int(d.get("items_left", 0)) > 0:
		for id: Variant in GameState.inventory:
			if Database.items.has(str(id)) and bool(Database.items[str(id)].get("tradeable", false)) and GameState.item_count(str(id)) > 0:
				items.append(str(id))
	for id: String in items:
		opts.append(Loc.t("1 %s (you have %d)") % [FriendsMenu.item_name(id), GameState.item_count(id)])
	if opts.is_empty():
		await menu.info("Nothing to give right now.")
		return
	var title: String = Loc.t("Give to the bund. Today you can still give %d coins and %d items.") % [int(d.coins_left), int(d.items_left)]
	var idx: int = await menu.pick_strings(title, opts)
	if idx < 0:
		return
	var coins: int = amounts[idx] if idx < amounts.size() else 0
	var bag: Dictionary = {} if idx < amounts.size() else {items[idx - amounts.size()]: 1}
	var r: Dictionary = await TradeMenu.bag_call("bund_donate", {"p_coins": coins, "p_items": bag})
	if not _ok(r):
		await menu.info(error_text(r))
		return
	GameState.money = maxi(0, GameState.money + int(r.data.get("money", 0)))
	SaveManager.save_game()
	Sound.sfx("coin")
	await menu.info(Loc.t("Thank you! The bund got %d xp.") % int(r.data.xp))

static func run_board(menu: MenuHost) -> void:
	var r: Dictionary = await Online.call_fn("bund_board")
	if not _ok(r):
		await menu.info(error_text(r))
		return
	var lines: Array[String] = []
	for row: Dictionary in r.data.get("rows", []):
		var you: String = "  " + Loc.t("(you)") if bool(row.get("me", false)) else ""
		lines.append(Loc.t("%d. %s  level %d  %d xp") % [int(row.rank), BundWords.name_of(int(row.name[0]), int(row.name[1])),
			int(row.level), int(row.xp)] + you)
	if lines.is_empty():
		lines.append(Loc.t("No bund has xp this week yet."))
	await menu.info(Loc.t("Bund board of the week") + "\n" + "\n".join(lines))

static func settings(menu: MenuHost, life: Dictionary) -> void:
	var langs: Array = life.get("langs", [])
	var opts: Array[String] = []
	for code: Variant in langs:
		opts.append(BundLife.lang_name(str(code)))
	var idx: int = await menu.pick_strings(Loc.t("Language of the bund (now: %s)") % BundLife.lang_name(str(life.lang)), opts)
	if idx < 0:
		return
	var open: int = await menu.pick_strings("Who may join?", ["Anyone, at once", "Only after a request"] as Array[String])
	if open < 0:
		return
	var r: Dictionary = await Online.call_fn("bund_settings", {"p_lang": str(langs[idx]), "p_open": open == 0})
	await menu.info("Saved." if _ok(r) else error_text(r))

## Search by language, most active bunds first; join an open one at once or send a request.
static func find(menu: MenuHost) -> void:
	var r: Dictionary = await Online.call_fn("bund_search", {"p_lang": Loc.language()})
	if not _ok(r):
		await menu.info(error_text(r))
		return
	var bunds: Array = r.data.get("bunds", [])
	if bunds.is_empty():
		await menu.info("No bund with room found. Found your own!")
		return
	var labels: Array[String] = []
	for x: Dictionary in bunds:
		labels.append(Loc.t("%s  level %d  %d/30  %d active  %s") % [BundWords.name_of(int(x.name[0]), int(x.name[1])),
			int(x.level), int(x.size), int(x.active), Loc.t("open") if bool(x.open) else Loc.t("on request")])
	var idx: int = await menu.pick_strings("Bunds with room", labels)
	if idx < 0:
		return
	var j: Dictionary = await Online.call_fn("bund_join", {"p_bund": int(bunds[idx].id)})
	if _ok(j):
		await menu.info("You joined the bund." if bool(j.data.get("joined", false)) else "Request sent. A leader or helper decides.")
	else:
		await menu.info(error_text(j))
