class_name PauseMenu
extends MenuHost
## In-game menu: Goals, Team, Spirlog, Satchel, Shop, Save, Settings, and Storage once the box is unlocked.

const STORAGE_FLAG: String = "storage_remote"

## The map the player is on (for the Spirlog Tracker).
var encounter_table: String = ""
## The map the menu was opened on (fast travel lists the other rest spots).
var current_map: String = ""
## Set when the player picks a fast-travel target; the overworld moves them after the menu closes.
var travel_to: String = ""
## Set by "Save and to title" once the save went through; the overworld goes to the title (item 1879).
var to_title: bool = false
## The pause entry used last; the next opening starts there (item 1873).
static var last_label: String = ""
## Set when the player picks Photo; the overworld opens photo mode after the menu closes.
var photo: bool = false
## Set when the player picks "Watch last battle" in Records.
var watch_replay: bool = false
## A replay picked under Records > Online replays (Online 100 plan point 71); empty = the last battle.
var watch_snap: Dictionary = {}
## Set when the player picks an echo duel under Friends: {"code", "name", "team"}.
var echo_duel: Dictionary = {}
## Set when the player finds a league battle under Leagues: the battle the server set up.
var league_match: Dictionary = {}
## A Raid Rift attempt the server set up (RaidMenu); the overworld plays it after the menu closes.
var raid_attempt: Dictionary = {}
## A live duel to play or watch in the battle screen (LiveDuelMenu): {"id", "watch", "name" or "names"}.
var live_stage: Dictionary = {}
## An entry to open before the list ("Goals" for a chimora://event link, DeepLink.gd).
var open_on: String = ""
## Area 3 item 1012/1014: the map has a puzzle room; "Room" offers undo and reset.
var room_puzzle: bool = false
var can_undo: bool = false
## Set to "undo" or "reset" when the player picks one; the overworld does it after closing.
var room_action: String = ""

## Fixed order, the most used first (item 1869). Travel, Storage and Room only show when
## they can be used; they keep their place. Leagues shows only while leagues are on,
## the Map book once Aldo gave it, the Ledger once it has an entry (clan intrigue, Trust.gd).
const MENU_ORDER: Array[String] = ["Goals", "Map book", "Ledger", "Map", "Room", "Team", "Satchel", "Spirlog", "Travel", "Friends",
	"Leagues", "Records", "Storage", "Save", "Save and to title", "Photo", "Settings"]

static func menu_labels(storage: bool, travel: bool, room: bool, leagues: bool = false,
		map_book: bool = false, ledger: bool = false) -> Array[String]:
	var out: Array[String] = []
	for l: String in MENU_ORDER:
		if (l == "Storage" and not storage) or (l == "Travel" and not travel) or (l == "Room" and not room) \
				or (l == "Leagues" and not leagues) or (l == "Map book" and not map_book) \
				or (l == "Ledger" and not ledger):
			continue
		out.append(l)
	return out

## The Ledger (Schuldbuch): every secret the player shares with someone. Each entry is
## leverage and a risk at once. Trust values themselves stay hidden.
func run_ledger() -> void:
	while true:
		var rows: Array[Dictionary] = Trust.ledger_rows(GameState.flags)
		var entries: Array[Dictionary] = []
		for r: Dictionary in rows:
			var lines: Array[String] = Trust.ledger_text(str(r.ref))
			entries.append({"text": lines[0] if not lines.is_empty() else str(r.id)})
		var idx: int = await pick("Ledger (%d)" % rows.size(), entries)
		if idx < 0:
			return
		var body: Array[String] = Trust.ledger_text(str(rows[idx].ref))
		var shown: PackedStringArray = []
		for l: String in body:
			shown.append(Loc.t(l))
		await info("\n".join(shown))

func run() -> void:
	close_all = false
	if open_on == "Goals":
		open_on = ""
		await run_goals()
	elif open_on == "Invite":
		open_on = ""
		await run_invite_link()
	while true:
		var labels: Array[String] = menu_labels(GameState.has_flag(STORAGE_FLAG),
			not GameState.travel_targets(current_map).is_empty(), room_puzzle, Online.league_on(),
			GameState.has_flag("aldo_gift"), not Trust.ledger_rows(GameState.flags).is_empty())
		labels.insert(labels.find("Satchel") + 1, "Shop (locked)" if Billing.kids_locked() else "Shop")
		# Pocket Rest (shop, pay-to-win step 6, plan point 51): rest anywhere outside battle.
		if ShopEffects.can_rest_anywhere():
			labels.insert(labels.find("Team") + 1, "Rest")
		if "Travel" in labels:
			await tip("travel")
		# The start menu in the era's layout (EraMenus): a plain list in Era I, symbols and the
		# clock from Era II, a grid of big buttons with an info panel in Era IV, pinned
		# shortcuts on top in Era V. "Shortcuts" is there in every era.
		labels.append(EraMenuKit.SHORTCUTS)
		var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "pause")
		var quick: Array[String] = []
		if bool(lay.get("quick_bar", false)):
			quick = EraMenus.quick_list(GameState.flags, labels)
		var entries: Array[Dictionary] = EraMenuKit.pause_entries(labels, Goals.pending() > 0, lay)
		var idx: int = await pick_screen("pause", menu_title(current_map), entries, {"focus": maxi(0, labels.find(last_label)),
			"tabs": quick, "tab": -1, "tab_icons": quick.map(func(l: String) -> Texture2D: return EraMenuKit.icon_for(l, lay)), "header": EraMenuKit.clock_strip() if str(lay.get("header", "none")) == "clock" else null})
		var chosen: String = ""
		if ListPicker.tab_of(idx) >= 0 and ListPicker.tab_of(idx) < quick.size():
			chosen = quick[ListPicker.tab_of(idx)]
		elif idx < 0 or idx >= labels.size():
			return
		else:
			chosen = labels[idx]
			last_label = chosen
		if chosen == EraMenuKit.SHORTCUTS:
			chosen = await run_shortcuts(labels)
			if chosen.is_empty():
				continue
		match chosen:
			"Goals": await run_goals()
			"Map book": await MapBookMenu.run(self)
			"Ledger": await run_ledger()
			"Map": await WorldMapMenu.run(self, current_map)
			"Team": await run_team()
			"Rest":
				if ShopEffects.pocket_rest():
					Sound.sfx("heal")
					await info("Your team is fully rested.")
			"Friends":
				await tip("friends")
				await FriendsMenu.run(self)
				if not echo_duel.is_empty() or not raid_attempt.is_empty() or watch_replay or not live_stage.is_empty():
					return
			"Leagues":
				await LeagueMenu.run(self)
				if not league_match.is_empty():
					return
			"Spirlog": await run_spirlog()
			"Records":
				await run_records()
				if watch_replay:
					return
			"Satchel": await run_bag()
			"Shop": await ShopMenu.run(self)
			"Shop (locked)": await info(ShopMenu.LOCKED_TEXT)
			"Storage": await run_storage()
			"Save":
				if await run_save():
					return
			"Save and to title":
				if await save_and_quit():
					return
			"Settings": await run_settings()
			"Photo":
				# The first time, a line on how photo mode works (item 1880).
				await tip("photo")
				photo = true
				return
			"Travel":
				if await run_travel():
					return
			"Room":
				if await run_room():
					return

## Shortcuts (docs/ERA_FEEL_MENUS.md): the pinned entries open from here in every era; Era V
## also shows them as a bar on top of the start menu. Returns the entry to open, or "".
func run_shortcuts(labels: Array[String]) -> String:
	var can: Array[String] = []
	for l: String in labels:
		if l != EraMenuKit.SHORTCUTS and not l.begins_with("Shop (") and l != "Photo":
			can.append(l)
	var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "pause")
	lay["columns"] = 1
	while true:
		var pinned: Array[String] = EraMenus.quick_list(GameState.flags, can)
		var entries: Array[Dictionary] = EraMenuKit.pause_entries(pinned, false, lay)
		entries.append({"text": "Pin or unpin...", "hint": EraMenuKit.PAUSE_HINTS[EraMenuKit.SHORTCUTS]})
		var idx: int = await pick_screen("pause", Loc.t("Shortcuts (%d/%d)") % [pinned.size(), EraMenus.QUICK_MAX], entries, {"columns": 1})
		if idx < 0:
			return ""
		if idx < pinned.size():
			return pinned[idx]
		while true:
			var rows: Array[Dictionary] = []
			var now: Array[String] = EraMenus.quick_list(GameState.flags, can)
			for l: String in can:
				rows.append({"text": ("[x] " if l in now else "[  ] ") + Loc.t(l), "say": "pinned" if l in now else ""})
			var t: int = await pick(Loc.t("Shortcuts (%d/%d)") % [now.size(), EraMenus.QUICK_MAX], rows)
			if t < 0:
				break
			if not EraMenus.quick_toggle(GameState.flags, can[t], can):
				toast("Four shortcuts are the limit. Unpin one first.", 2.5)
	return ""

## The save screen (docs/ERA_FEEL_MENUS.md): the save card (who, where, how long, how many
## kinds; from Era II the clock and the team) over "Save now" and "Save and to title".
## Returns true when the menu should close and the game go back to the title.
func run_save() -> bool:
	var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "save")
	var rows: Array[Dictionary] = [
		{"text": "Save now", "hint": EraMenuKit.PAUSE_HINTS["Save"]},
		{"text": "Save and to title", "hint": EraMenuKit.PAUSE_HINTS["Save and to title"]}]
	for i: int in rows.size():
		var ic: Texture2D = EraMenuKit.icon_for("Save" if i == 0 else "Save and to title", lay)
		if ic != null:
			rows[i]["icon"] = ic
	var idx: int = await pick_screen("save", "Save", rows, {"focus": 0, "header": EraMenuKit.save_card(lay, current_map)})
	if idx == 0:
		save_now()
	elif idx == 1:
		return await save_and_quit()
	return false

## A chimora://friend/<code> link (Online 100 point 55): asks before the invite sends a request.
func run_invite_link() -> void:
	var code: String = DeepLink.friend_code
	DeepLink.friend_code = ""
	if code.is_empty() or not Online.is_online() or not Online.flag_on("invite"):
		return
	if await confirm(Loc.t("Accept the invite of friend code %s? It sends a friend request.") % Online.pretty_code(code)):
		await FriendsMoreMenu.redeem(self, code)

## A second press of "=" or Start closes the menu from any level (item 1874).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GameState.MENU_ACTION) and is_visible_in_tree() and (picker.visible or _info_wait):
		get_viewport().set_input_as_handled()
		close_menu()
		return
	super(event)

## Closes every open level of the menu.
func close_menu() -> void:
	close_all = true
	_close_steps = 0
	if _info_wait:
		_page_turn = -2
		_close_info()
	if picker.visible:
		picker.picked.emit(-1)

## Shows a first-time tip in an info window (menus have no text box).
func tip(id: String) -> void:
	var lines: Array[String] = Tips.take(id)
	if not lines.is_empty():
		await info("\n".join(lines))

## Goals as a list (item 1870): the main goal first with a flag mark, then the open side
## goals and today's rare visitor. A row opens its full text.
func run_goals() -> void:
	while true:
		var rows: Array[Dictionary] = goal_rows(GameState.flags)
		rows.append_array(goal_tab_rows())
		var swap: int = -1
		if DailyTasks.can_swap():
			swap = rows.size()
			rows.append({"text": "Swap a daily task", "hint": Loc.t("Once a day, free of charge.")})
		var saving: int = -1
		if Exchange.is_open():
			saving = rows.size()
			var gl: String = Exchange.goal_line()
			rows.append({"text": "Savings goal...", "hint": gl if gl != "" else Loc.t("Pick an offer of Marla's stand to save up for.")})
		if GameState.has_flag(EchoPath.OPEN_FLAG):
			# Plan 3470: which rooms were visited, of what kind, and which are cleared.
			rows.append({"text": "Echo Path map...", "detail": "\n".join(EchoPath.map_lines())})
		var collect: int = -1
		if Goals.pending() > 0:
			collect = rows.size()
			rows.append({"text": "Collect all", "hint": Loc.t("Collect every waiting reward at once."), "icon": Goals.dot()})
		var guide: int = -1
		if not Tips.seen().is_empty():
			guide = rows.size()
			rows.append({"text": "Guide...", "hint": Loc.t("Read the tips again.")})
		var idx: int = await pick("Goals", rows)
		if idx < 0:
			return
		if idx == swap:
			await _swap_daily_task()
			continue
		if idx == collect:
			await info("\n".join(Goals.collect_all()))
			continue
		if idx == saving:
			await _pick_savings_goal()
			continue
		if idx == guide:
			await run_guide()
			continue
		await info(str(rows[idx].get("detail", rows[idx].text)))

## The wider goal tabs (plan area 8, item 3526) after the list: Today, Week and Collection.
## Story is the list itself.
const GOAL_TAB_ROWS: Dictionary = {"Today": "Today...", "Week": "This week...", "Collection": "Collection..."}

static func goal_tab_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tab: String in Goals.TABS:
		if GOAL_TAB_ROWS.has(tab):
			out.append({"text": GOAL_TAB_ROWS[tab], "detail": Goals.tab_text(tab)})
	return out

const RESET_TIPS_ROW: String = "Show tips again"
const RESET_TIPS_DONE: String = "Tips are back. Pretend it's your first day."

## The Guide (item 1985): every tip already seen, by topic, to read again. The last row
## lets every tip show once more (item 1998).
func run_guide() -> void:
	while true:
		var ids: Array[String] = Tips.seen()
		var names: Array[String] = []
		for id: String in ids:
			names.append(Tips.TOPICS[id])
		names.append(RESET_TIPS_ROW)
		var idx: int = await pick_strings("Guide", names)
		if idx < 0:
			return
		if idx == ids.size():
			if await confirm("Show every tip once more, as if you were new?"):
				Tips.reset()
				toast(RESET_TIPS_DONE)
				return
			continue
		var lines: Array[String] = []
		for l: String in Tips.lines_of(ids[idx]):
			lines.append(Loc.t(l))
		await info("\n".join(lines))

## [param daily] replaces today's visitor line, [param newcomer] GameState.is_newcomer() (tests).
static func goal_rows(flags: Dictionary, daily: Variant = null, newcomer: Variant = null) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var g: Dictionary = QuestLog.current(flags)
	if not g.is_empty():
		var where: String = str(g.get("where", ""))
		var lines: PackedStringArray = []
		if not str(g.get("chapter", "")).is_empty():
			lines.append(str(g.chapter))
		lines.append(QuestLog.goal_text(g, flags))
		if not where.is_empty():
			lines.append("Where: %s" % where)
		rows.append({"text": QuestLog.goal_text(g, flags), "icon": goal_mark(),
			"hint": Loc.t("Where: %s" % where) if not where.is_empty() else "",
			"detail": "\n".join(lines)})
	# New players get a self-ticking "First steps" list right under the main goal (item 1995).
	if FirstSteps.shows(flags, GameState.is_newcomer() if newcomer == null else bool(newcomer)):
		rows.append(FirstSteps.row(flags))
	for s: Dictionary in QuestLog.open_side_goals(flags):
		rows.append({"text": QuestLog.side_text(s, flags), "hint": Loc.t("Side goal"),
			"detail": QuestLog.side_text(s, flags)})
	var visitor: String = DailyFind.hint(flags) if daily == null else str(daily)
	if not visitor.is_empty():
		rows.append({"text": "Today's visitor", "hint": Loc.t(visitor), "detail": visitor})
	var tasks: Array[String] = DailyTasks.lines()
	if not tasks.is_empty():
		rows.append({"text": "Daily tasks", "hint": tasks[1] if tasks.size() > 1 else "", "detail": "\n".join(tasks)})
	return rows

static var _goal_mark: ImageTexture

## A small flag in front of the main goal.
static func goal_mark() -> Texture2D:
	if _goal_mark == null:
		var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(1, 0, 1, 9), UITheme.INK)
		img.fill_rect(Rect2i(2, 0, 6, 4), UITheme.INK)
		img.fill_rect(Rect2i(3, 1, 3, 2), UITheme.MID)
		_goal_mark = ImageTexture.create_from_image(img)
	return _goal_mark

## Saves without blocking the menu (item 2130) and says honestly where the save is: "Saved."
## only once the server has it, otherwise that the phone has it and the server follows (1868).
func save_now() -> void:
	# Ticked before saving so the tick is in the save itself.
	FirstSteps.tick(FirstSteps.SAVED)
	var ok: bool = SaveManager.save_game()
	Sound.sfx("save" if ok else "cancel")
	if not ok:
		toast("Saving failed.", 2.5)
		return
	toast("Saving...", 5.0)
	var on_server: bool = await Online.wait_synced(SaveManager.slot)
	if not is_inside_tree():
		return
	toast(SAVED_TEXT if on_server else SAVED_LOCAL_TEXT, 1.5 if on_server else 3.0)

## Saves and, if that worked, ends the session (item 1879). Returns true when the menu
## should close and the game go back to the title.
func save_and_quit() -> bool:
	FirstSteps.tick(FirstSteps.SAVED)
	if not SaveManager.save_game():
		Sound.sfx("cancel")
		toast("Saving failed.", 2.5)
		return false
	Sound.sfx("save")
	toast("Saving...", 5.0)
	var on_server: bool = await Online.wait_synced(SaveManager.slot)
	if not is_inside_tree():
		return false
	if not on_server and not await confirm(Loc.t(SAVED_LOCAL_TEXT) + "\n" + Loc.t("Go to the title anyway?"), "To title", "Stay"):
		return false
	to_title = true
	return true

const SAVED_TEXT: String = "Saved."
const SAVED_LOCAL_TEXT: String = "Saved on this phone. The server follows once the connection is back."

## Goals screen in four tabs (plan 3526): Story, Today, Week, Collection. All tabs in one text.
static func goals_text() -> String:
	return Goals.all_text()

## Plan 3126: pick an offer of Marla's stand as the savings goal.
func _pick_savings_goal() -> void:
	var offers: Array[Dictionary] = Exchange.offers()
	var names: Array[String] = []
	for o: Dictionary in offers:
		names.append(Exchange.label(o))
	var g: int = await pick_strings("Save up for which offer?", names)
	if g < 0:
		return
	Exchange.set_goal(str(offers[g].item))
	await info(Exchange.goal_line())

## Plan 3163: one open daily task a day can be swapped for free.
func _swap_daily_task() -> void:
	var tasks: Array = DailyTasks.today().get("tasks", [])
	var names: Array[String] = []
	var index: Array[int] = []
	for k: int in tasks.size():
		var e: Dictionary = tasks[k]
		if not DailyTasks.is_done(e) and int(e.get("n", 0)) == 0:
			names.append(Loc.t(str(DailyTasks.def(str(e.id)).get("text", e.id))))
			index.append(k)
	var pick: int = await pick_strings("Swap which task? (once a day)", names)
	if pick < 0:
		return
	var got: String = DailyTasks.swap(index[pick])
	if got == "":
		await info("No other task fits today.")
	else:
		await info(Loc.t("New task: %s") % Loc.t(str(DailyTasks.def(got).get("text", got))))

## Achievements and personal bests (items 88-90, plan area 8): badge book, lists by category.
func run_records() -> void:
	Achievements.check()
	while true:
		var lines: Array[String] = ["Badge book", "Achievements by category", "Season path", "Personal bests", "What is missing"]
		if not Waymarks.history_lines(1).is_empty():
			lines.append("Waymark history")
		if Masters.open():
			lines.append("Master Wayfarers")
		if GameState.has_flag("rift_cinder_sealed") or GameState.has_flag("rift_tide_sealed"):
			lines.append("Tower map")
		if Vows.can_take() or not (GameState.records.get("vows", {}) as Dictionary).is_empty():
			lines.append("Vows")
		lines.append("Run chronicle")
		lines.append("Era functions")
		lines.append("Finds by region")
		if not memorial_lines().is_empty():
			lines.append("Memorial book")
		if not Album.stickers().is_empty():
			lines.append("Sticker wall")
		if not Lexicon.collected(GameState.records).is_empty():
			lines.append("Lexicon")
		var last: Dictionary = GameState.records.get("last_battle", {})
		if not last.is_empty():
			lines.append("Watch last battle")
		lines.append("Online replays")
		var have: int = Achievements.unlocked().size()
		var idx: int = await pick_strings(Loc.t("Achievements %d/%d") % [have, Achievements.list().size()], lines)
		if idx < 0:
			return
		match lines[idx]:
			"Badge book": await run_badge_book()
			"Achievements by category": await run_achievement_lists()
			"Season path": await pick_strings(SeasonPath.title(), SeasonPath.lines())
			"Personal bests": await info(records_text())
			"What is missing": await info("\n".join(Completion.lines() + Completion.missing_lines()))
			"Waymark history": await info(Loc.t("Waymarks: %d") % GameState.waymarks + "\n" + "\n".join(Waymarks.history_lines()))
			"Master Wayfarers": await run_masters()
			"Tower map": await info("\n".join(RiftTower.card_lines()))
			"Vows": await run_vows()
			"Run chronicle": await info("\n".join(RunChronicle.lines()))
			"Era functions": await run_era_functions()
			"Finds by region": await info("\n".join(RegionStats.lines(GameState.flags)))
			"Memorial book": await info("\n".join(memorial_lines()))
			"Sticker wall": await info("\n".join(Album.wall_lines()))
			"Lexicon": await run_lexicon()
			"Online replays":
				if await OnlineReplaysMenu.run(self):
					return
			"Watch last battle":
				if await confirm("Watch the replay? %s" % BattleReplay.label(last)):
					watch_replay = true
					return

## Era functions (data/era_functions.json): one page per open era with what it brought.
func run_era_functions() -> void:
	while true:
		var titles: Array[String] = EraFeatures.era_titles(EraManager.unlocked_era)
		var i: int = await pick_strings(Loc.t("Era functions"), titles)
		if i < 0:
			return
		await info("\n".join(EraFeatures.page_lines(i + 1)))

## The lexicon (plan area 2, item 680): the collected entries, each opened as a page.
func run_lexicon() -> void:
	var ids: Array[String] = Lexicon.collected(GameState.records)
	# The first page counts the bonus goals met per map (item 767).
	var titles: Array[String] = [Loc.t("Bonus goals")]
	for id: String in ids:
		titles.append(Lexicon.title(id))
	while true:
		var i: int = await pick_strings(Loc.t("Lexicon %d") % ids.size(), titles)
		if i < 0:
			return
		if i == 0:
			await info(BattleGoals.lexicon_text(GameState.records))
		else:
			await info(Loc.t(Lexicon.text(ids[i - 1])))

## Vows (plan 3406-3408): take one before the first Rift is mended, give one up at any time.
func run_vows() -> void:
	while true:
		var i: int = await pick_strings(Loc.t("Vows: each one kept to the end of Act I pays %d Waymarks.") % Vows.KEPT_WAYMARKS, Vows.lines())
		if i < 0:
			return
		var v: Dictionary = Vows.list()[i]
		var id: String = str(v.id)
		var text: String = Loc.t(str(v.name)) + "\n" + Loc.t(str(v.text))
		if Vows.status(id) == "" and Vows.can_take():
			if await confirm(text + "\n\n" + Loc.t("Take this vow?")):
				Vows.take(id)
		elif Vows.is_active(id):
			if await confirm(text + "\n\n" + Loc.t("Give up this vow? You only lose its bonus.")):
				Vows.give_up(id)
		else:
			await info(text)

## Memorial book in the Sanctuary (plan 3397): every Spirling that retired under the Iron Oath.
static func memorial_lines() -> Array[String]:
	var out: Array[String] = []
	var book: Variant = GameState.records.get("memorial", [])
	if not book is Array:
		return out
	for e: Variant in book:
		if not e is Dictionary:
			continue
		var d: Dictionary = e
		var map_id: String = str(d.get("map", ""))
		var place: String = MapData.load_map(map_id).display_name if MapData.exists(map_id) else map_id
		out.append(Loc.t("%s, ring %d, %s, %s") % [str(d.get("name", "?")), int(d.get("level", 1)), Loc.t(place), str(d.get("date", ""))])
	return out

## Master Wayfarer profiles (plan 3290): place, theme and the player's own wins.
func run_masters() -> void:
	while true:
		var i: int = await pick_strings(Loc.t("Master Wayfarers %d/%d") % [Masters.beaten_count(), Masters.list().size()], Masters.lines())
		if i < 0:
			return
		await info(Masters.profile(Masters.list()[i]))

## The badge grid; picking a badge shows its card.
func run_badge_book() -> void:
	var book := BadgeBook.new()
	add_child(book)
	picker.visible = false
	while true:
		var i: int = await book.chosen
		if i < 0:
			break
		book.visible = false
		await info(Achievements.card(Achievements.list()[i]))
		book.visible = true
		book.fill()
	book.queue_free()
	picker.visible = true

## One list per category with progress (k/n) where there is a count (plan 3317).
func run_achievement_lists() -> void:
	while true:
		var cats: Array[String] = []
		for c: String in Achievements.CATEGORIES:
			cats.append(Achievements.CATEGORY_NAMES[c])
		var ci: int = await pick_strings("Achievements", cats)
		if ci < 0:
			return
		var cat: String = Achievements.CATEGORIES[ci]
		while true:
			var shown: Array[Dictionary] = []
			var lines: Array[String] = []
			for a: Dictionary in Achievements.list():
				if str(a.cat) != cat:
					continue
				shown.append(a)
				var p: Array[int] = Achievements.progress(a)
				var done: bool = Achievements.unlocked().has(a.id)
				lines.append("%s %s%s" % ["[x]" if done else "[ ]", Loc.t(str(a.title)), ("  %d/%d" % [p[0], p[1]]) if not p.is_empty() and not done else ""])
			var ai: int = await pick_strings(Loc.t(cats[ci]), lines)
			if ai < 0:
				break
			await info(Achievements.card(shown[ai]))

## Tower best, weekly challenge and the current festival.
static func records_text() -> String:
	var lines: PackedStringArray = []
	lines.append_array(Completion.lines())
	# The badge case: one seal per mended story Rift.
	var seals: int = GameState.STORY_RIFTS.filter(func(r: String) -> bool: return GameState.has_flag("rift_%s_sealed" % r)).size()
	lines.append(Loc.t("Rift seals: %d of %d") % [seals, GameState.STORY_RIFTS.size()])
	lines.append("Lighthouse stair best: floor %d of %d" % [Gauntlet.best(), Gauntlet.FLOORS])
	if GameState.iron_oath:
		lines.append(Loc.t("Under the Iron Oath: floor %d of %d") % [int(GameState.records.get("gauntlet_best_oath", 0)), Gauntlet.FLOORS])
	var rec: Dictionary = GameState.records.get("weekly", {})
	var week: String = WeeklyChallenge.this_week()
	var best: int = int(rec.get("best", 0)) if str(rec.get("week", "")) == week else 0
	lines.append("This week: %d of %d" % [best, WeeklyChallenge.ROUNDS])
	lines.append("Weekly wins: %d" % int(GameState.records.get("weekly_wins", 0)))
	lines.append("Rematches won: %d" % int(GameState.records.get("rematch_wins", 0)))
	lines.append(Collection.progress_text(GameState.spirlog, SpirlogBook.visible_kinds(GameState.flags).size()))
	for c: Dictionary in GameState.echo_cores:
		lines.append(Loc.t("Echo Core of %s: %d/%d wins, %d/%d rests") % [" and ".join(c.parents),
			mini(int(c.wins), GameState.ECHO_CORE_WINS), GameState.ECHO_CORE_WINS,
			mini(int(c.rests), GameState.ECHO_CORE_RESTS), GameState.ECHO_CORE_RESTS])
	var titles: Array[String] = Collection.titles()
	if not titles.is_empty():
		lines.append("Titles: %s" % ", ".join(titles.map(func(t: String) -> String: return Loc.t(t))))
	if GameState.iron_oath:
		lines.append("Iron Oath kept. In the Sanctuary: %d" % GameState.sanctuary.size())
		for s: Spirling in GameState.sanctuary:
			lines.append("  %s R%d" % [s.display_name(), s.level])
	elif GameState.has_flag("oath_broken"):
		lines.append("Iron Oath broken.")
	var f: Dictionary = Season.current()
	if not f.is_empty():
		lines.append("Festival: %s" % f.name)
	return "\n".join(lines)

## Title line: name, coins, and the level cap on Veteran / Rift-Born (item 47).
## Name, coins, waymarks and the place the player stands (item 1875).
static func menu_title(map_id: String = "") -> String:
	var t: String = "%s   %s   %s" % [GameState.tamer_name, Loc.plural(GameState.money, "%d coin", "%d coins"), Waymarks.label()]
	if not map_id.is_empty() and MapData.exists(map_id):
		t += "\n" + Loc.t(MapData.load_map(map_id).display_name)
	if not Festival.active().is_empty():
		t += "   " + Loc.t("Ribbons %d") % Festival.ribbons()
	if GameState.has_ring_limit():
		t += "   Ring limit %d" % GameState.level_cap()
	return t

## Puzzle room tools (area 3 items 1012, 1014). Returns true if an action was picked.
func run_room() -> bool:
	var opts: Array[String] = []
	if can_undo:
		opts.append("Undo last push")
	opts.append("Reset room")
	var idx: int = await pick_strings("Puzzle room", opts)
	if idx < 0:
		return false
	if opts[idx] == "Reset room":
		if not await confirm("Put every boulder back where it started?"):
			return false
		room_action = "reset"
	else:
		room_action = "undo"
	return true

## Fast travel between rest spots already used (item 41). Returns true if a target was picked.
func run_travel() -> bool:
	var ids: Array[String] = GameState.travel_targets(current_map)
	var names: Array[String] = []
	for id: String in ids:
		names.append(MapData.load_map(id).display_name if MapData.exists(id) else id)
	var idx: int = await pick_strings("Travel to a place" if Billing.unlocked("fast_travel") > 0 else "Travel to a rest spot", names)
	if idx < 0:
		return false
	# A mistap must not carry the player somewhere else (item 1878).
	if not await confirm("Travel to %s?" % names[idx], "Travel", "Stay"):
		return false
	travel_to = ids[idx]
	return true

func run_team() -> void:
	FirstSteps.tick(FirstSteps.TEAM)
	if GameState.party.size() >= 2:
		await tip("team_order")
	while true:
		var rows: Array[Dictionary] = []
		# Team rows in the era's layout (EraMenus): text and the ink bar in Era I, a bobbing
		# sprite from Era II, coloured badges from Era III, drag-to-reorder cards from Era IV.
		var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "party")
		for i: int in GameState.party.size():
			rows.append(EraMenuKit.party_entry(GameState.party[i], i == 0, i, lay))
		# Free slots up to the limit show how much room is left (item 1898).
		for i: int in range(GameState.party.size(), GameState.party_max()):
			rows.append(free_slot_row())
		# The wardrobe for bought looks (item 4287), once there is something in it.
		var wardrobe: int = -1
		if not ShopMenu.owned_looks().is_empty():
			wardrobe = rows.size()
			rows.append({"text": Loc.t("Wardrobe...")})
		# Running shop boosts with the battles left (item 4342).
		var boosts: Array[String] = ShopEffects.boost_lines()
		# Account power: the sum of the bought advantages that work right now.
		var power: int = ShopEffects.account_power()
		if power > 0:
			boosts.push_front(Loc.t("Power %d") % power)
		# What the best next tier would add (plan point 60): adults only, a note, no button.
		var next_power: String = ShopEffects.next_power_line()
		if not next_power.is_empty():
			boosts.append(next_power)
		var title: String = Loc.t("Team") + ("  " + "  ".join(boosts) if not boosts.is_empty() else "")
		var drag: EraPartyDrag = EraPartyDrag.attach(self, GameState.party.size()) if bool(lay.get("drag", false)) else null
		var idx: int = await pick_screen("party", title, rows, {"panel_text": "Drag a row to change the order. Tap one for more."})
		if drag != null:
			drag.queue_free()
		if idx == EraMenus.DRAG_PICKED:
			continue
		if idx >= 0 and idx == wardrobe:
			await ShopMenu.run_wardrobe(self)
			continue
		if idx < 0 or idx >= GameState.party.size():
			return
		var s: Spirling = GameState.party[idx]
		var opts: Array[String] = ["Summary", "Lead the team", "Move to slot...", "Use item", "Keepsake", "Nickname"]
		# Every kind that can unfold shows the option; if it isn't ready yet, it says what it needs.
		if not s.data.unfold.is_empty():
			opts.append("Unfurl")
			await tip("unfurl")
		if s.earlier_form() != null:
			opts.append("Furl back")
		# Move Memory (shop item 4457).
		if Billing.unlocked("move_memory") > 0:
			opts.append("Relearn an art")
		var opt: int = await pick_strings(s.display_name(), opts)
		if opt >= 0 and opts[opt] == "Relearn an art":
			await _relearn(s)
			continue
		if opt >= 0 and opts[opt] == "Nickname":
			await _rename(s)
			continue
		if opt >= 0 and opts[opt] in ["Unfurl", "Furl back"]:
			await _unfurl(s, opts[opt] == "Unfurl")
			continue
		match opt:
			0: await run_summary(s, idx == 0, idx)
			1: GameState.swap_party(0, idx)
			2:
				var slots: Array[String] = []
				for i: int in GameState.party.size():
					slots.append("%d. %s" % [i + 1, GameState.party[i].display_name()])
				var to: int = await pick_strings("Move %s to..." % s.display_name(), slots)
				if to >= 0:
					GameState.move_party(idx, to)
			3: await _use_item_on(s)
			4: await _held_item(s)

## Nickname (item 1899): up to 10 letters, empty gives back the kind's name. The same rules
## as Wayfarer names, since friends can see a team.
const NICK_MAX: int = 10

func _rename(s: Spirling) -> void:
	var n: String = await TextPrompt.ask(self, Loc.t("Nickname for %s") % s.data.species_name, false, NICK_MAX, s.nickname)
	if not set_nickname(s, n):
		await info("That name can't be used. Letters and up to 3 digits, at most 10 characters.")
		return
	Sound.sfx("confirm")

## Sets [param n] as the nickname if it is allowed; empty clears it. Returns false if refused.
static func set_nickname(s: Spirling, n: String) -> bool:
	var clean: String = " ".join(n.strip_edges().split(" ", false))
	if clean.is_empty() or clean == s.data.species_name:
		s.nickname = ""
		return true
	if clean.length() > NICK_MAX or LocalBackend.clean_name(clean, "0000") != clean:
		return false
	s.nickname = clean
	return true

## The summary in the era's layout: two text pages in Era I, three in Era II, the tabbed card
## from Era III on. Every era shows the same four sections (EraMenus.SECTIONS).
## With [param team_i] (the Spirling's team slot), up and down go straight to the previous or
## next team member without the list in between (item 1893).
func run_summary(s: Spirling, leader: bool = false, team_i: int = -1) -> void:
	var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "summary")
	var can_step: bool = team_i >= 0 and GameState.party.size() > 1
	while true:
		screens_shown.append("summary")
		var step: int = 0
		if bool(lay.get("tabs", false)):
			step = await EraSummary.show_for(self, s, leader, can_step)
		else:
			summary_step_ok = can_step
			summary_step = 0
			await info_pages(EraMenus.summary_pages(s, EraManager.active_era(), leader), MiniSprite.of(s.data.species_name, int(lay.get("sprite", 32))))
			summary_step_ok = false
			step = summary_step
		if step == 0 or not can_step or close_all:
			return
		team_i = posmod(team_i + step, GameState.party.size())
		s = GameState.party[team_i]
		leader = team_i == 0
		Sound.sfx("select")

## A grey "free" team row; a tap says where new Spirlings go.
static func free_slot_row() -> Dictionary:
	return {"text": "free", "disabled": true, "why": "New Spirlings you bond with fill this slot."}

## Unfurl into the next form or furl back into the earlier one. Both can be undone later.
func _unfurl(s: Spirling, forward: bool) -> void:
	var old_name: String = s.display_name()
	var target: SpirlingData = s.earlier_form()
	if forward:
		var ready: Array[SpirlingData] = s.unfurl_targets(current_map)
		if ready.is_empty():
			await info("\n".join(s.unfold_hints()))
			return
		target = ready[0]
		if ready.size() > 1:
			var names: Array[String] = []
			for t: SpirlingData in ready:
				names.append(t.species_name)
			var pick: int = await pick_strings("Unfurl into...", names)
			if pick < 0:
				return
			target = ready[pick]
	if target == null:
		return
	var q: String = ("Unfurl %s into %s? You can furl it back later." if forward else "Furl %s back into %s? You can unfurl it again later.") % [old_name, target.species_name]
	if not await confirm(q):
		return
	var old_data: SpirlingData = s.data
	if forward:
		s.evolve(target)
		GameState.mark_seen(s.data.species_name, true)
		var seq := UnfurlSequence.new()
		add_child(seq)
		await seq.play(old_data, s.data)
		seq.queue_free()
	else:
		GameState.furl_back(s)
		Sound.sfx("level_up")
	await info(("%s unfurls into %s!" if forward else "%s furls back into %s.") % [old_name, s.data.species_name])

## Give, swap or take off a keepsake.
func _held_item(s: Spirling) -> void:
	var ids: Array[String] = []
	# Each keepsake shows what it does while focused, before it is put on (item 1900).
	var entries: Array[Dictionary] = []
	if not s.held.is_empty():
		ids.append("")
		entries.append({"text": "Take off %s" % Database.item(s.held).get("name", s.held),
			"hint": Loc.t(str(Database.item(s.held).get("description", "")))})
	for id: Variant in GameState.inventory:
		if GameState.item_count(str(id)) > 0 and BattleRules.is_holdable(str(id)):
			ids.append(str(id))
			var it: Dictionary = Database.item(str(id))
			entries.append({"text": "%s x%d" % [it.get("name", id), GameState.item_count(str(id))],
				"hint": Loc.t(str(it.get("description", "")))})
	if ids.is_empty():
		await info("You have nothing a Spirling can hold.\nKeepsakes are sold in Thornridge.")
		return
	var now: String = "Holding: %s" % (Database.item(s.held).get("name", s.held) if not s.held.is_empty() else "nothing")
	var idx: int = await pick(now, entries)
	if idx < 0:
		return
	GameState.set_held(s, ids[idx])
	Sound.sfx("confirm")

func _use_item_on(s: Spirling) -> void:
	# The list stays open after a use (item 1904) and keeps its place.
	var focus: int = 0
	while true:
		var ids: Array[String] = _usable_items()
		if ids.is_empty():
			await info("Nothing in the satchel can be used here.")
			return
		var entries: Array[Dictionary] = []
		for id: String in ids:
			var row: Dictionary = {"text": "%s x%d" % [Database.item(id).get("name", id), GameState.item_count(id)]}
			var after: String = vigor_preview(Database.item(id), s)
			if not after.is_empty():
				row["hint"] = after
			entries.append(row)
		var idx: int = await pick("Use on %s" % s.display_name(), entries, true, mini(focus, ids.size() - 1))
		if idx < 0:
			return
		focus = idx
		var msg: String = GameState.use_item_outside_battle(ids[idx], s)
		await info(msg if not msg.is_empty() else "That would do nothing right now.")

## "Vigor 12/40 to 32/40" for a healing or reviving item, empty for any other (item 1901).
static func vigor_preview(it: Dictionary, s: Spirling) -> String:
	var to: int = -1
	if float(it.get("revive", 0.0)) > 0.0:
		if s.is_fainted():
			to = maxi(1, int(s.max_hp() * float(it.revive)))
	elif int(it.get("heal", 0)) > 0:
		if not s.is_fainted() and s.hp < s.max_hp():
			to = mini(s.max_hp(), s.hp + int(it.heal))
	if to < 0:
		return ""
	return Loc.t("Vigor %d/%d to %d/%d" % [s.hp, s.max_hp(), to, s.max_hp()])

func _usable_items() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in GameState.inventory:
		var it: Dictionary = Database.item(str(id))
		if GameState.item_count(str(id)) > 0 and (int(it.get("heal", 0)) > 0 or float(it.get("revive", 0.0)) > 0.0 or bool(it.get("evolves", false))
				or int(it.get("rings", 0)) > 0 or int(it.get("rings_to", 0)) > 0 or bool(it.get("spark_all", false))
				or bool(it.get("unfurl_any", false)) or bool(it.get("gift_slot", false))):
			out.append(str(id))
	return out

## Satchel tabs (item 1914) and which tab an item belongs to.
const BAG_TABS: Array[String] = ["Care", "Keepsakes", "Crystals", "Gear", "Special"]
## Satchel orders (item 1917); the choice is kept in GameState.bag_sort.
const BAG_SORTS: Array[String] = ["New", "Name", "Kind"]
## What a list returns when its sort switch in the title row is tapped.
const SORT_PICKED: int = -50

## [param ids] in satchel order [param mode]: newest first (the bag keeps the order things
## came in, and a used-up entry goes away), by shown name, or by kind as the item list has them.
static func sort_bag(ids: Array, mode: int) -> Array:
	var out: Array = ids.duplicate()
	match mode:
		0:
			out.reverse()
		1:
			out.sort_custom(func(a: Variant, b: Variant) -> bool:
				return Loc.t(str(Database.item(str(a)).get("name", a))).naturalnocasecmp_to(Loc.t(str(Database.item(str(b)).get("name", b)))) < 0)
		2:
			var order: Array = Database.items.keys()
			out.sort_custom(func(a: Variant, b: Variant) -> bool:
				return order.find(a) < order.find(b))
	return out

## What a list returns when its filter switch in the title row is tapped (item 1945).
const FILTER_PICKED: int = -51

## The "Sort: New" switch in the satchel's title row; a tap closes the list with SORT_PICKED.
func sort_toggle() -> Button:
	return title_toggle("sort_toggle", Loc.t("Sort: %s") % Loc.t(BAG_SORTS[clampi(GameState.bag_sort, 0, BAG_SORTS.size() - 1)]), SORT_PICKED)

## A switch for a list's title row: a tap closes the list with [param code].
func title_toggle(id: String, text: String, code: int) -> Button:
	var b := Button.new()
	b.name = id
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = text
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sound.sfx("select")
		picker.picked.emit(code))
	return b

static func bag_tab(it: Dictionary) -> int:
	if bool(it.get("gear", false)):
		return 3
	if it.has("teaches"):
		return 2
	# "held" is true or a table of what the keepsake does; bool() of a table is an error.
	if it.has("held"):
		return 1
	for k: String in ["heal", "cure", "revive", "energy", "stage", "battle"]:
		if it.has(k) and it[k]:
			return 0
	return 4

func run_bag() -> void:
	await tip("satchel")
	var tab: int = -1
	# The item used last keeps the focus when the list comes back (item 1927).
	var last_id: String = ""
	var last_idx: int = -1
	while true:
		var by_tab: Array[Array] = [[], [], [], [], []]
		for id: Variant in GameState.inventory:
			if GameState.item_count(str(id)) > 0:
				by_tab[bag_tab(Database.item(str(id)))].append(str(id))
		var tabs: Array[String] = []
		var tab_ids: Array[int] = []
		for t: int in BAG_TABS.size():
			if not by_tab[t].is_empty():
				tabs.append(BAG_TABS[t])
				tab_ids.append(t)
		if tabs.is_empty():
			await info("The satchel is empty.")
			return
		tab = clampi(tab, 0, tabs.size() - 1) if tab >= 0 else 0
		var ids: Array = by_tab[tab_ids[tab]]
		# The satchel in the era's layout (EraMenus): Era I one list in pocket order, pockets
		# as tabs with a symbol per thing from Era II, the pocket's picture from Era III.
		var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "bag")
		var flat: bool = str(lay.get("pockets", "tabs")) == "flat"
		if flat:
			ids = []
			for t: int in tab_ids:
				ids.append_array(by_tab[t])
		ids = sort_bag(ids, GameState.bag_sort)
		var entries: Array[Dictionary] = []
		for id: String in ids:
			var it0: Dictionary = Database.item(id)
			# The description stands in the line under the list (item 1915).
			var hint: String = Loc.t(str(it0.get("description", "")))
			if battle_only(it0):
				hint = Loc.t(BATTLE_ONLY) + " " + hint
			elif bool(it0.get("gear", false)):
				hint = gear_hint(id)
			var row: Dictionary = {"text": "%s x%d" % [it0.get("name", id), GameState.item_count(id)], "hint": hint}
			var pic: Texture2D = EraMenuKit.icon_for("pocket%d" % bag_tab(it0), lay)
			if pic != null:
				row["icon"] = pic
			entries.append(row)
		# If it was used up, the row that took its place gets the focus.
		var focus: int = ids.find(last_id)
		if focus < 0 and last_idx >= 0:
			focus = mini(last_idx, ids.size() - 1)
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_END
		if not flat:
			var pocket: Control = EraMenuKit.pocket_header(tab_ids[tab], BAG_TABS[tab_ids[tab]], ids.size(), lay)
			pocket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(pocket)
		head.add_child(sort_toggle())
		var idx: int = await pick_screen("bag", "Satchel", entries, {"focus": focus, "tabs": ([] as Array[String]) if flat else tabs, "tab": tab, "header": head,
			"tab_icons": EraMenuKit.pocket_tab_icons(tab_ids, lay)})
		if ListPicker.tab_of(idx) >= 0:
			tab = ListPicker.tab_of(idx)
			last_idx = -1
			continue
		if idx == SORT_PICKED:
			GameState.bag_sort = (GameState.bag_sort + 1) % BAG_SORTS.size()
			SaveManager.save_settings()
			continue
		if idx < 0:
			return
		var item_id: String = ids[idx]
		last_id = item_id
		last_idx = idx
		var it: Dictionary = Database.item(item_id)
		if it.has("teaches"):
			await _teach_echo(item_id)
		elif int(it.get("spark", 0)) > 0:
			await _use_spark_charm(item_id)
		elif int(it.get("crystal", 0)) > 0:
			await _use_stat_crystal(item_id)
		elif bool(it.get("temper_shift", false)):
			await _use_temper_shift(item_id)
		elif bool(it.get("temper_core", false)):
			await _use_power_core(item_id)
		elif bool(it.get("gleam", false)):
			await _use_gleam_prism(item_id)
		elif it.has("boost"):
			if await confirm("%s\n%s" % [Loc.t(str(it.get("name", ""))), Loc.t(str(it.get("description", "")))], "Use", "Not now"):
				await info(ShopEffects.start_boost(item_id))
		elif item_id in _usable_items():
			await _use_on_party(item_id)
		elif item_id == TideChart.ITEM:
			await info("\n".join(TideChart.lines()))
		elif bool(it.get("gear", false)):
			await info(gear_page(item_id), gear_picture(item_id))
		else:
			await info("%s\n%s" % [it.get("name", ""), it.get("description", "")])

## Picks who gets [param item_id]. Healing items ask again for the same Spirling after
## each use, until Back or the last one is gone (item 1919).
func _use_on_party(item_id: String) -> void:
	var it: Dictionary = Database.item(item_id)
	var again: bool = int(it.get("heal", 0)) > 0 or float(it.get("revive", 0.0)) > 0.0
	var focus: int = -1
	while GameState.item_count(item_id) > 0:
		var rows: Array[Dictionary] = []
		for s: Spirling in GameState.party:
			var row: Dictionary = {"text": MenuHost.party_line(s)}
			var after: String = vigor_preview(it, s)
			if not after.is_empty():
				row["hint"] = after
			rows.append(row)
		var title: String = "Use %s on?" % it.get("name", "")
		if again:
			title += "  x%d" % GameState.item_count(item_id)
		var who: int = await pick(title, rows, true, focus)
		if who < 0:
			return
		focus = who
		if bool(it.get("spark_all", false)):
			# The Spark Forge shows the values it will set before it is used.
			var sp: Spirling = GameState.party[who]
			if not await confirm("%s\n%s" % [GameState.spark_reading(sp), Loc.t("Afterwards every spark is at the top (12).")], "Use", "Not now"):
				return
		var msg: String = GameState.use_item_outside_battle(item_id, GameState.party[who])
		await info(msg if not msg.is_empty() else "That would do nothing right now.")
		if not again:
			return

const BATTLE_ONLY: String = "Only in battle."

## Items that only work in a battle (item 1924): marked in the Satchel.
static func battle_only(it: Dictionary) -> bool:
	if not bool(it.get("battle", false)):
		return false
	for k: String in ["heal", "revive", "evolves", "rings", "spark_all", "boost", "teaches", "gear"]:
		if it.has(k) and it[k]:
			return false
	return true

## What each "works_on" entry of a gear item means (area 3 item 1050).
const GEAR_PLACES: Dictionary[String, String] = {
	"~": "narrow water with a post on the far side", "^": "low cliffs", "v": "vine walls (v)",
	"w": "shallow water (w)", "Y": "gaps with a chalk mark (Y)", "dark": "pitch-dark passages",
	"wheel": "sluice wheels, mine carts and grates", "shaft": "marked edges above a shaft",
	"look": "open ground ahead (hidden finds up to 6 steps away)",
	"tide": "the tides of sea caves",
	"rubbing": "weathered stones on old burial mounds",
}

## Satchel page for a piece of Wayfarer Gear: name, short text and where it works.
static func gear_page(id: String) -> String:
	var it: Dictionary = Database.item(id)
	var lines: PackedStringArray = [Loc.t(str(it.get("name", id))), Loc.t(str(it.get("description", "")))]
	var places: PackedStringArray = []
	for w: Variant in it.get("works_on", []):
		places.append(Loc.t(GEAR_PLACES.get(str(w), str(w))))
	if not places.is_empty():
		lines.append(Loc.t("Works on: %s") % ", ".join(places))
	lines.append(Loc.t("Always on foot: you walk, wade and climb yourself."))
	return "\n".join(lines)

## One sentence on where and how a gear item is used, for the Satchel row (item 1925).
static func gear_hint(id: String) -> String:
	var places: PackedStringArray = []
	for w: Variant in Database.item(id).get("works_on", []):
		places.append(Loc.t(GEAR_PLACES.get(str(w), str(w))))
	if places.is_empty():
		return Loc.t(str(Database.item(id).get("description", "")))
	return Loc.t("Use it at %s: face the spot and tap it.") % ", ".join(places)

## The tile a gear item works on, drawn at twice its size, or null.
static func gear_picture(id: String) -> Texture2D:
	var kinds: Dictionary = {"~": TilesetFactory.Kind.WATER, "^": TilesetFactory.Kind.CLIFF, "v": TilesetFactory.Kind.VINES,
		"w": TilesetFactory.Kind.WADE, "Y": TilesetFactory.Kind.PLANK, "dark": TilesetFactory.Kind.ROCK,
		"wheel": TilesetFactory.Kind.ROCK, "shaft": TilesetFactory.Kind.PLANK}
	var on: Array = Database.item(id).get("works_on", [])
	var atlas: String = TilesetFactory.atlas_path()
	if on.is_empty() or atlas.is_empty():
		return null
	var img: Image = (load(atlas) as Texture2D).get_image()
	var k: int = int(kinds.get(str(on[0]), TilesetFactory.Kind.GRASS))
	var tile: Image = img.get_region(Rect2i(k * TilesetFactory.TILE, 0, TilesetFactory.TILE, TilesetFactory.TILE))
	tile.resize(TilesetFactory.TILE * 2, TilesetFactory.TILE * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(tile)

## Echo Crystal: pick a Spirling of the right element, then (if it knows 4 moves) one to forget.
func _teach_echo(id: String) -> void:
	var it: Dictionary = Database.item(id)
	var mv: MoveData = Database.move(str(it.teaches))
	# Who can't learn it stands grey with the reason (item 1921).
	var rows: Array[Dictionary] = []
	for s: Spirling in GameState.party:
		var why: String = echo_reason(s, id)
		rows.append({"text": MenuHost.party_line(s), "disabled": not why.is_empty(), "why": why})
	var who: int = await pick("Teach %s to?" % mv.move_name, rows)
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	if not GameState.can_learn_echo(s, id):
		await info("%s can't learn %s." % [s.display_name(), mv.move_name])
		return
	var forget: int = -1
	if s.moves.size() >= Spirling.MAX_MOVES:
		forget = await pick("Forget which art for %s?" % mv.move_name, art_rows(s.moves))
		if forget < 0:
			return
	if not GameState.learn_from_item(s, id, forget):
		return
	Sound.sfx("level_up")
	await info("%s learned %s!" % [s.display_name(), mv.move_name])

## Why [param s] can't learn the art of Echo Crystal [param item_id]; empty if it can.
static func echo_reason(s: Spirling, item_id: String) -> String:
	if GameState.can_learn_echo(s, item_id):
		return ""
	var mv: MoveData = Database.move(str(Database.item(item_id).get("teaches", "")))
	if mv != null and s.moves.has(mv):
		return "Already knows this art."
	return "Wrong element."

## Known arts as rows: the name, and element, power and energy in the line below (item 1923).
static func art_rows(moves: Array[MoveData]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: MoveData in moves:
		var power: String = "-" if m.power <= 0 else str(m.power)
		out.append({"text": m.move_name, "hint": "%s  %s  %s" % [Loc.t(Elements.element_name(m.element)),
			Loc.t("Power %s" % power), Loc.t("Energy %d" % m.energy_cost)]})
	return out

## Move Memory (item 4457): any art the Spirling could know at its Ring, at any time.
func _relearn(s: Spirling) -> void:
	var names: Array[String] = GameState.relearnable(s)
	if names.is_empty():
		await info(Loc.t("%s knows every art it can learn right now.") % s.display_name())
		return
	var shown: Array[String] = []
	for n: String in names:
		shown.append(Loc.t(n))
	var pick: int = await pick_strings(Loc.t("Relearn which art for %s?") % s.display_name(), shown)
	if pick < 0:
		return
	var forget: int = -1
	if s.moves.size() >= Spirling.MAX_MOVES:
		forget = await pick(Loc.t("Forget which art for %s?") % shown[pick], art_rows(s.moves))
		if forget < 0:
			return
	if GameState.relearn(s, names[pick], forget):
		Sound.sfx("level_up")
		await info(Loc.t("%s learned %s!") % [s.display_name(), shown[pick]])

## Temper Shift (item 4743): pick a Spirling, then the temperament it gets.
func _use_temper_shift(id: String) -> void:
	var who: int = await _pick_member("Use the Temper Shift on?")
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	var names: Array[String] = []
	for t: Dictionary in Spirling.TEMPERAMENTS:
		var line: String = "%s: %s" % [Loc.t(str(t.label)), Loc.t(str(t.text))]
		names.append(("> " if t.id == s.temperament().id else "") + line)
	var pick: int = await pick_strings(Loc.t("New temperament for %s?") % s.display_name(), names)
	if pick < 0:
		return
	var t: Dictionary = Spirling.TEMPERAMENTS[pick]
	if not GameState.shift_temper(s, str(t.id), id):
		await info(Loc.t("%s already has that temperament.") % s.display_name())
		return
	Sound.sfx("level_up")
	await info(Loc.t("%s is %s now.") % [s.display_name(), Loc.t(str(t.label))])

## Power Core (item 4750): doubles the lean of one Spirling's temperament.
func _use_power_core(id: String) -> void:
	var who: int = await _pick_member("Use the Power Core on?")
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	if not GameState.use_power_core(s, id):
		await info(Loc.t("That would do nothing: %s has no lean to strengthen, or already has a Power Core.") % s.display_name())
		return
	Sound.sfx("level_up")
	await info(Loc.t("%s's temperament grows stronger: +10%% instead of +5%%.") % s.display_name())

## Gleam Prism (items 4791, 4793): the player picks exactly which Spirling gleams.
func _use_gleam_prism(id: String) -> void:
	var who: int = await _pick_member("Use the Gleam Prism on?")
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	if s.gleam_boost:
		await info(Loc.t("%s already gleams.") % s.display_name())
		return
	if not await confirm(Loc.t("Turn %s into its Gleam form? +10%% on all values, for good.") % s.display_name(), "Gleam", "Not now"):
		return
	if GameState.use_gleam_prism(s, id):
		Sound.sfx("level_up")
		await info(Loc.t("%s gleams with Riftglass light!") % s.display_name())

func _pick_member(question: String) -> int:
	var names: Array[String] = []
	for s: Spirling in GameState.party:
		names.append(MenuHost.party_line(s))
	return await pick_strings(question, names)

## Spark Charm: pick a Spirling, then the stat to brighten.
func _use_spark_charm(id: String) -> void:
	var names: Array[String] = []
	for s: Spirling in GameState.party:
		names.append(MenuHost.party_line(s))
	var who: int = await pick_strings("Use the Spark Charm on?", names)
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	var stats: Array[String] = []
	for key: String in Spirling.STAT_KEYS:
		stats.append("%s: %s" % [key.to_upper(), GameState.spark_word(int(s.spark.get(key, 0)))])
	var pick: int = await pick_strings("Brighten which spark?", stats)
	if pick < 0:
		return
	if not GameState.train_spark(s, Spirling.STAT_KEYS[pick], int(Database.item(id).spark)):
		await info("That spark is already as bright as it gets.")
		return
	GameState.inventory[id] = GameState.item_count(id) - 1
	if GameState.item_count(id) <= 0:
		GameState.inventory.erase(id)
	Sound.sfx("level_up")
	await info("%s's %s spark grew brighter!" % [s.display_name(), Spirling.STAT_KEYS[pick].to_upper()])

## Stat Crystal from the shop: adds its points to one stat of one Spirling, up to twice the
## free Spark cap per stat.
func _use_stat_crystal(id: String) -> void:
	var names: Array[String] = []
	for s: Spirling in GameState.party:
		names.append(MenuHost.party_line(s))
	var who: int = await pick_strings("Use the Stat Crystal on?", names)
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	var stats: Array[String] = []
	for key: String in Spirling.STAT_KEYS:
		stats.append("%s: +%d / %d" % [key.to_upper(), int(s.crystal.get(key, 0)), ShopEffects.crystal_cap()])
	var pick: int = await pick_strings("Which value?", stats)
	if pick < 0:
		return
	var key: String = Spirling.STAT_KEYS[pick]
	var added: int = ShopEffects.add_crystal(s, key, int(Database.item(id).crystal))
	if added <= 0:
		await info("That value already holds all the crystal it can.")
		return
	GameState.take_item(id)
	Sound.sfx("level_up")
	await info(Loc.t("%s's %s rose by %d.") % [s.display_name(), key.to_upper(), added])

## Spirlog filters (item 249), kept while the menu is open.
var _log_search: String = ""
var _log_element: int = -1
var _log_role: int = -1
var _log_status: int = SpirlogBook.STATUS_ALL
var _log_region: int = -1
## Season page of the Spirlog: only kinds of the season's elements.
var _log_season: bool = false

## Spirlog: chapters per open region with their progress, search and filters, then the kinds.
## A seen kind opens its map-book page (SpirlogPage); unseen ones show as "???".
func run_spirlog() -> void:
	FirstSteps.tick(FirstSteps.SPIRLOG)
	while true:
		var regions: Array[String] = SpirlogBook.open_regions(GameState.flags)
		var region: String = regions[_log_region] if _log_region >= 0 and _log_region < regions.size() else ""
		var role: String = SpirlingData.ROLES[_log_role] if _log_role >= 0 else ""
		var kinds: Array[SpirlingData] = SpirlogBook.filtered(GameState.spirlog, GameState.flags,
			_log_search, _log_element, role, _log_status, region)
		# The Spirlog in the era's layout (EraMenus): a number list with a small sprite in
		# Era I, the area map from Era II, search on top from Era IV, chapters and the season
		# page as tabs in Era V. Every filter is there in every era.
		var lay: Dictionary = EraMenus.layout(EraManager.active_era(), "dex")
		var month: int = int(Online.date_now().get("month", 1))
		var season: String = EraMenus.season_name(month)
		if _log_season:
			var in_season: Array[int] = EraMenus.season_elements(month, Season.boosted(Season.current()))
			var seasonal: Array[SpirlingData] = []
			for k: SpirlingData in kinds:
				if EraMenus.in_season(k, in_season):
					seasonal.append(k)
			kinds = seasonal
		var region_tabs: bool = bool(lay.get("region_tabs", false))
		var entries: Array[Dictionary] = []
		var actions: Array[String] = []
		# Two progress bars on top (item 1940).
		for row: Dictionary in spirlog_progress_rows():
			entries.append(row)
			actions.append("progress")
		if bool(lay.get("search_bar", false)):
			entries.append({"text": "Search: %s" % (_log_search if not _log_search.is_empty() else "-"), "icon": EraMenuKit.icon_for("search", lay),
				"hint": "Search the Spirlog by name."})
			actions.append("search")
		for r: String in regions:
			entries.append({"text": SpirlogBook.chapter_line(r, GameState.spirlog)})
			actions.append("chapter")
		entries.append({"text": SpirlogBook.gleam_line(GameState.spirlog)})
		actions.append("gleam")
		if not region_tabs:
			entries.append({"text": "Chapter: %s" % (region.capitalize() if not region.is_empty() else "all")})
			actions.append("region")
			entries.append({"text": Loc.t("Season: %s") % Loc.t(season if _log_season else "all")})
			actions.append("season")
		if not bool(lay.get("search_bar", false)):
			entries.append({"text": "Search: %s" % (_log_search if not _log_search.is_empty() else "-")})
			actions.append("search")
		entries.append({"text": "Element: %s" % ("all" if _log_element < 0 else Elements.element_name(_log_element))})
		actions.append("element")
		entries.append({"text": "Role: %s" % ("all" if role.is_empty() else role.capitalize())})
		actions.append("role")
		entries.append({"text": "Show: %s" % SpirlogBook.STATUS_NAMES[_log_status]})
		actions.append("status")
		if not encounter_table.is_empty():
			entries.append({"text": "Tracker: this area"})
			actions.append("tracker")
		entries.append({"text": Collection.art_book_lines()[0]})
		actions.append("arts")
		if not Collection.prism_kinds().is_empty():
			entries.append({"text": Collection.prism_lines()[0]})
			actions.append("prism")
		if GameState.has_flag(EchoPath.OPEN_FLAG):
			# Plan 3354: the Echo Path's wild kinds of the week, so missing ones can be planned.
			entries.append({"text": EchoPath.spirlog_hint()})
			actions.append("echo")
		var first_kind: int = entries.size()
		for sd: SpirlingData in kinds:
			# Own marks beside the line (item 1934): an eye for seen, a band for bonded.
			var mark: Texture2D = SpirlogMarks.bonded() if SpirlogBook.is_bonded(GameState.spirlog, sd.species_name) \
				else (SpirlogMarks.seen() if SpirlogBook.is_seen(GameState.spirlog, sd.species_name) else SpirlogMarks.none())
			var row: Dictionary = {"text": SpirlogBook.list_line(sd, GameState.spirlog)}
			# Era I is a plain number list: the line's own "+" and "*" say seen and bonded.
			if bool(lay.get("icons", false)):
				row["icon"] = mark
			if str(lay.get("panel", "none")) != "none" and SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
				row["hint"] = Loc.t("Found on: %s" % SpirlogBook.found_line(sd, GameState.spirlog))
			entries.append(row)
			actions.append("kind")
		var preview := EraDexViews.Preview.new()
		preview.px = int(lay.get("preview", 24))
		preview.with_map = str(lay.get("area", "text")) == "map"
		var on_focus: Callable = func(i: int) -> void:
			if is_instance_valid(preview):
				preview.show_kind(kinds[i - first_kind] if i >= first_kind and i - first_kind < kinds.size() else null)
		picker.row_focused.connect(on_focus)
		var tabs: Array[String] = []
		var tab: int = 0
		if region_tabs:
			tabs.append("All")
			for r: String in regions:
				tabs.append(r.capitalize())
			tabs.append(season)
			tab = regions.size() + 1 if _log_season else _log_region + 1
		var idx: int = await pick_screen("dex", "Spirlog (%d)" % kinds.size(), entries, {"focus": first_kind if not kinds.is_empty() else -1,
			"header": preview, "tabs": tabs, "tab": tab, "panel_text": "Tap a kind to open its page."})
		picker.row_focused.disconnect(on_focus)
		if ListPicker.tab_of(idx) >= 0:
			var t: int = ListPicker.tab_of(idx)
			_log_season = t == regions.size() + 1
			_log_region = -1 if _log_season or t == 0 else t - 1
			continue
		if idx < 0:
			return
		match actions[idx]:
			"chapter", "region":
				_log_region = _log_region + 1 if _log_region + 1 < regions.size() else -1
			"season":
				_log_season = not _log_season
			"search":
				_log_search = await TextPrompt.ask(self, "Search by name", false, 16, _log_search)
			"element":
				_log_element = _log_element + 1 if _log_element + 1 < Elements.E.size() else -1
			"role":
				_log_role = _log_role + 1 if _log_role + 1 < SpirlingData.ROLES.size() else -1
			"status":
				_log_status = (_log_status + 1) % SpirlogBook.STATUS_NAMES.size()
			"tracker":
				await info(_tracker_text())
			"gleam":
				var names: PackedStringArray = SpirlogBook.gleam_bonded_kinds(GameState.spirlog)
				await info(SpirlogBook.gleam_line(GameState.spirlog) + "\n\n" + (", ".join(names) if not names.is_empty() else Loc.t("No Gleam has joined you yet.")))
			"arts":
				await info("\n".join(Collection.art_book_lines()))
			"prism":
				await info("\n".join(Collection.prism_lines()))
			"echo":
				await info(EchoPath.spirlog_hint() + "\n" + Loc.t("They wait in the wild rooms of the Echo Path behind the Cinder Rift. A new set comes every week."))
			"kind":
				var sd: SpirlingData = kinds[idx - first_kind]
				if not SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
					var look: String = unseen_hint(sd.species_name)
					await info(Loc.t("#%02d  Not seen yet." % sd.dex_id) + ("\n" + look if not look.is_empty() else ""))
					continue
				await SpirlogPage.show_pages(self, kinds, idx - first_kind)

## "Seen 12/21" and "Bonded 8/21" as rows with a bar each (item 1940).
static func spirlog_progress_rows() -> Array[Dictionary]:
	var kinds: Array[SpirlingData] = SpirlogBook.visible_kinds(GameState.flags)
	var seen: int = 0
	var bonded: int = 0
	for sd: SpirlingData in kinds:
		if SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
			seen += 1
		if SpirlogBook.is_bonded(GameState.spirlog, sd.species_name):
			bonded += 1
	var total: int = kinds.size()
	var out: Array[Dictionary] = []
	for pair: Array in [["Seen %d/%d", seen], ["Bonded %d/%d", bonded]]:
		var n: int = int(pair[1])
		var ratio: float = float(n) / maxf(1.0, float(total))
		out.append({"text": Loc.t(str(pair[0]) % [n, total]),
			"decorate": func(b: Button) -> void: _draw_progress(b, ratio)})
	return out

const PROGRESS_W: int = 48

static func _draw_progress(b: Button, ratio: float) -> void:
	var ink: Color = b.get_theme_color("font_focus_color" if b.has_focus() else "font_color", "Button")
	var x0: float = b.size.x - PROGRESS_W - 6
	var y: float = b.size.y - 4
	b.draw_rect(Rect2(x0, y, PROGRESS_W, 2), UITheme.DISABLED)
	if ratio > 0.0:
		b.draw_rect(Rect2(x0, y, maxf(1.0, roundf(PROGRESS_W * ratio)), 2), ink)

## Where to look for a kind not seen yet: maps it lives on that the player has entered
## (item 1948). Empty while none of them was entered.
static func unseen_hint(species: String) -> String:
	var where: PackedStringArray = []
	for table: String in EncounterTable.table_ids():
		if not species in EncounterTable.species_on(table):
			continue
		for map_id: String in _maps_with_table(table):
			if not GameState.visited_maps.has(map_id):
				continue
			var m: MapData = MapData.load_map(map_id)
			var name: String = m.display_name if m != null and not m.display_name.is_empty() else map_id
			if not name in where:
				where.append(name)
	if where.is_empty():
		return ""
	return Loc.t("Look in: %s") % ", ".join(where)

## Real map names where a kind lives (item 1935), not reshaped table ids.
static func found_on(species: String) -> PackedStringArray:
	var where: PackedStringArray = []
	for table: String in EncounterTable.table_ids():
		if not species in EncounterTable.species_on(table):
			continue
		var name: String = ""
		for map_id: String in _maps_with_table(table):
			var m: MapData = MapData.load_map(map_id)
			if m != null and not m.display_name.is_empty():
				name = m.display_name
				break
		if name.is_empty():
			name = table.replace("_", " ").capitalize()
		if not name in where:
			where.append(name)
	return where

static var _table_maps: Dictionary[String, Array] = {}

static func _maps_with_table(table: String) -> Array:
	if _table_maps.is_empty():
		for f: String in DirAccess.get_files_at("res://data/maps"):
			if not f.ends_with(".json"):
				continue
			var id: String = f.get_basename()
			var m: MapData = MapData.load_map(id) if MapData.exists(id) else null
			if m == null:
				continue
			var t: String = m.encounter_table
			if not t.is_empty():
				if not _table_maps.has(t):
					_table_maps[t] = []
				_table_maps[t].append(id)
	return _table_maps.get(table, [])

func _tracker_text() -> String:
	var lines: PackedStringArray = ["Spirlog Tracker", ""]
	var listed: Dictionary = {}
	for sp: String in EncounterTable.species_on(encounter_table):
		if listed.has(sp):
			continue
		listed[sp] = true
		var e: Dictionary = GameState.spirlog.get(sp, {})
		var mark: String = "bonded" if bool(e.get("bonded", false)) else ("seen" if bool(e.get("seen", false)) else "not seen")
		var line: String = "%s: %s" % [sp if bool(e.get("seen", false)) else "???", Loc.t(mark)]
		# Area 3 item 1115: which ground it steps out of.
		var grounds: PackedStringArray = []
		for g: String in EncounterTable.grounds_for(encounter_table, sp):
			grounds.append(Loc.t(GROUND_LABELS.get(g, g)))
		if not grounds.is_empty():
			line += " (%s)" % ", ".join(grounds)
		lines.append(line)
	# Area 3 item 1079: hidden finds on this map.
	if MapData.exists(current_map):
		var found: Vector2i = MapData.load_map(current_map).secrets_found(GameState.flags)
		if found.y > 0:
			lines.append("")
			lines.append(Loc.t("Hidden finds here: %d/%d") % [found.x, found.y])
	return "\n".join(lines)

const GROUND_LABELS: Dictionary[String, String] = {"fern": "ferns", "reeds": "reeds", "scree": "scree", "water": "shallow water", "cave": "cave"}

var _storage_sort: int = 0
var _storage_element: int = -1

## Storage (plan area 1, items 375-382): named boxes of 30, favourites, multi-move, team
## presets, release, keepsakes and a detail card for each Spirling.
func run_storage() -> void:
	GameState.ensure_boxes()
	await tip("storage")
	while true:
		var title: String = "Storage (%d/%d)" % [GameState.storage.size(), GameState.storage_capacity()]
		var idx: int = await pick_strings(title, ["Boxes", "Send to rest", "Team presets"] as Array[String])
		match idx:
			-1:
				return
			0:
				await _run_boxes()
			1:
				await _send_to_rest()
			2:
				await _run_presets()

func _box_names() -> Array[String]:
	var fill: Array[int] = GameState.box_fill()
	var names: Array[String] = []
	for i: int in GameState.storage_boxes.size():
		names.append("%s (%d/%d)" % [GameState.storage_boxes[i].name, fill[i] if i < fill.size() else 0, GameState.BOX_SIZE])
	return names

func _run_boxes() -> void:
	while true:
		var b: int = await pick_strings("Boxes", _box_names())
		if b < 0:
			return
		await _run_box(b)

func _box_view(box: int) -> Array[int]:
	var view: Array[int] = GameState.storage_view(_storage_sort, _storage_element)
	return view.filter(func(i: int) -> bool: return GameState.storage[i].box == box)

func _run_box(box: int) -> void:
	while true:
		var view: Array[int] = _box_view(box)
		var bx: Dictionary = GameState.storage_boxes[box]
		# Sort and element filter are two switches in the title row, not list rows (item 1945).
		var names: Array[String] = [
			"Move several...",
			"Rename box",
			"Colour: %s" % Loc.t(str(bx.color).capitalize()),
		]
		for i: int in view:
			names.append(MenuHost.storage_line(GameState.storage[i]))
		picker.set_header(storage_toggles())
		var w: int = await pick_strings("%s (%d)" % [bx.name, view.size()], names)
		if is_instance_valid(picker):
			picker.set_header(null)
		match w:
			SORT_PICKED:
				_storage_sort = (_storage_sort + 1) % GameState.STORAGE_SORTS.size()
			FILTER_PICKED:
				_storage_element += 1
				if _storage_element >= Elements.E.size():
					_storage_element = -1
			-1:
				return
			0:
				await _move_several(view)
			1:
				var n: String = await TextPrompt.ask(self, "Box name", false, GameState.BOX_NAME_MAX, str(bx.name))
				GameState.rename_box(box, n)
			2:
				GameState.recolor_box(box)
			_:
				if w >= STORAGE_ROWS:
					await _run_stored(view[w - STORAGE_ROWS])

## Rows above the Spirlings in a box: Move several, Rename, Colour.
const STORAGE_ROWS: int = 3

## The box's title row: "Sort: Caught" and "Show: all", each a switch.
func storage_toggles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(title_toggle("sort_toggle", Loc.t("Sort: %s") % Loc.t(GameState.STORAGE_SORTS[_storage_sort]), SORT_PICKED))
	row.add_child(title_toggle("filter_toggle", Loc.t("Show: %s") % Loc.t("all" if _storage_element < 0 else Elements.element_name(_storage_element)), FILTER_PICKED))
	return row

## Mark up to ten Spirlings, then pick the box they move to (item 376). Favourites stay put.
func _move_several(view: Array[int]) -> void:
	var marked: Array[int] = []
	while true:
		var names: Array[String] = ["Move marked (%d)" % marked.size()]
		for i: int in view:
			var s: Spirling = GameState.storage[i]
			var tag: String = "[x] " if marked.has(i) else ("(fav) " if s.favorite else "[ ] ")
			names.append(tag + MenuHost.storage_line(s))
		var w: int = await pick_strings("Mark up to %d" % GameState.MULTI_MOVE_MAX, names)
		if w < 0:
			return
		if w == 0:
			if marked.is_empty():
				continue
			var to: int = await pick_strings("Move to which box?", _box_names())
			if to >= 0:
				var moved: int = GameState.move_to_box(marked, to)
				await info("%d moved." % moved)
			return
		var i: int = view[w - 1]
		if GameState.storage[i].favorite:
			await info("Favourites stay where they are. Move them one by one.")
		elif marked.has(i):
			marked.erase(i)
		elif marked.size() < GameState.MULTI_MOVE_MAX:
			marked.append(i)

## One stored Spirling: details, call back, move, favourite, keepsake, release.
func _run_stored(index: int) -> void:
	var s: Spirling = GameState.storage[index]
	while true:
		var opts: Array[String] = ["Details", "Call back", "Swap with team...", "Move to box...", "Unmark favourite" if s.favorite else "Mark as favourite"]
		if not s.held.is_empty():
			opts.append("Take off keepsake")
		opts.append("Release")
		var c: int = await pick_strings(MenuHost.storage_line(s), opts)
		var i: int = GameState.storage.find(s)
		if c < 0 or i < 0:
			return
		match opts[c]:
			"Details":
				await info(MenuHost.storage_card(s))
			"Call back":
				if Expeditions.is_away(s.uid):
					await info("This Spirling is away on a trip. Aldo will tell you when it's back.")
					continue
				if GameState.withdraw(i):
					return
				await info("Your team is full.")
			"Swap with team...":
				# Item 1946: one step instead of sending one to rest and calling the other back.
				var names3: Array[String] = []
				for m: Spirling in GameState.party:
					names3.append(MenuHost.party_line(m))
				var d: int = await pick_strings(Loc.t("Swap %s with whom?") % s.display_name(), names3)
				if d < 0:
					continue
				var why: String = swap_with_team(i, d)
				if why.is_empty():
					Sound.sfx("confirm")
					return
				await info(why)
			"Move to box...":
				var to: int = await pick_strings("Move to which box?", _box_names())
				if to >= 0:
					GameState.move_to_box([i] as Array[int], to, true)
			"Mark as favourite", "Unmark favourite":
				GameState.toggle_favorite(s)
			"Take off keepsake":
				GameState.add_item(s.held)
				s.held = ""
			"Release":
				if s.favorite:
					await info("Favourites are never released.")
				elif await confirm_danger("Release %s?" % s.display_name()) \
						and await confirm_danger("It goes home for good. Really release it?"):
					await info(GameState.release(i))
					# A farewell letter follows (plan 1136).
					await info("\n".join(Released.letter(s)))
					return

## Swaps storage Spirling [param store_i] with team member [param party_i] (item 1946): the
## stored one takes the team slot, the team one goes into the stored one's box. Returns why it
## can't, or "" when done.
static func swap_with_team(store_i: int, party_i: int) -> String:
	if store_i < 0 or store_i >= GameState.storage.size() or party_i < 0 or party_i >= GameState.party.size():
		return "Nothing to swap."
	var incoming: Spirling = GameState.storage[store_i]
	if Expeditions.is_away(incoming.uid):
		return "This Spirling is away on a trip. Aldo will tell you when it's back."
	var outgoing: Spirling = GameState.party[party_i]
	GameState.storage.remove_at(store_i)
	GameState.party[party_i] = incoming
	outgoing.restore()
	outgoing.box = incoming.box
	GameState.storage.append(outgoing)
	Vows.check_team()
	return ""

## Party -> storage, asking whether the keepsake stays in the satchel (item 356).
func _send_to_rest() -> void:
	var names2: Array[String] = []
	for s: Spirling in GameState.party:
		names2.append(MenuHost.party_line(s))
	var d: int = await pick_strings("Send to rest", names2)
	if d < 0:
		return
	if GameState.storage.size() >= GameState.storage_capacity():
		await info("Storage is full.")
		return
	var keep: bool = false
	if not GameState.party[d].held.is_empty():
		keep = await confirm("Keep the keepsake?")
	if not GameState.deposit(d, keep):
		await info("You need at least one healthy Spirling with you.")

## Saved teams of up to five, loaded with one tap (item 378).
func _run_presets() -> void:
	while true:
		var names: Array[String] = []
		for i: int in GameState.TEAM_PRESETS:
			names.append(_preset_line(i))
		var p: int = await pick_strings("Team presets", names)
		if p < 0:
			return
		var has: bool = not GameState.preset_team(p).is_empty()
		var opts: Array[String] = ["Load this team", "Save current team here"] if has else ["Save current team here"]
		var c: int = await pick_strings(names[p], opts)
		if c < 0:
			continue
		if opts[c] == "Load this team":
			if GameState.load_preset(p):
				await info("Your team is ready.")
			else:
				await info("That team can't travel right now.")
		else:
			GameState.save_preset(p)
			await info("Team saved.")

func _preset_line(i: int) -> String:
	var team: Array[Spirling] = GameState.preset_team(i)
	if team.is_empty():
		return "Team %d: empty" % (i + 1)
	var names: PackedStringArray = []
	for s: Spirling in team:
		names.append(s.display_name())
	return "%s: %s" % [GameState.team_presets[i].name, ", ".join(names)]

## "Sing together" at an Echo spring (Nachhall, items 183-184): pick two Spirlings from the
## team or storage; their shared call forms an Echo Core that wakes later into a Hallkind.
func run_sing_together() -> void:
	var all: Array[Spirling] = GameState.party + GameState.storage
	var names: Array[String] = []
	for s: Spirling in all:
		names.append("%s R%d" % [s.display_name(), s.level])
	var a: int = await pick_strings("Who sings first?", names)
	if a < 0:
		return
	var b: int = await pick_strings("Who sings with %s?" % all[a].display_name(), names)
	if b < 0:
		return
	var problem: String = GameState.sing_problem(all[a], all[b])
	if not problem.is_empty():
		await info(problem)
		return
	var core: Dictionary = GameState.sing_together(all[a], all[b])
	await info("%s and %s sing together. Their call gathers into a floating Echo Core.\nCarry it along: it wakes after a few rests at a spring or many won battles." % [all[a].display_name(), all[b].display_name()])
	if core.is_empty():
		return
