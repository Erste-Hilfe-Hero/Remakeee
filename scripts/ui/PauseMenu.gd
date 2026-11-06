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
## Set when the player picks an echo duel under Friends: {"code", "name", "team"}.
var echo_duel: Dictionary = {}
## Set when the player finds a league battle under Leagues: the battle the server set up.
var league_match: Dictionary = {}
## A Raid Rift attempt the server set up (RaidMenu); the overworld plays it after the menu closes.
var raid_attempt: Dictionary = {}
## Area 3 item 1012/1014: the map has a puzzle room; "Room" offers undo and reset.
var room_puzzle: bool = false
var can_undo: bool = false
## Set to "undo" or "reset" when the player picks one; the overworld does it after closing.
var room_action: String = ""

## Fixed order, the most used first (item 1869). Travel, Storage and Room only show when
## they can be used; they keep their place. Leagues shows only while leagues are on,
## the Map book once Aldo gave it.
const MENU_ORDER: Array[String] = ["Goals", "Map book", "Map", "Room", "Team", "Satchel", "Spirlog", "Travel", "Friends",
	"Leagues", "Records", "Storage", "Save", "Save and to title", "Photo", "Settings"]

static func menu_labels(storage: bool, travel: bool, room: bool, leagues: bool = false,
		map_book: bool = false) -> Array[String]:
	var out: Array[String] = []
	for l: String in MENU_ORDER:
		if (l == "Storage" and not storage) or (l == "Travel" and not travel) or (l == "Room" and not room) \
				or (l == "Leagues" and not leagues) or (l == "Map book" and not map_book):
			continue
		out.append(l)
	return out

func run() -> void:
	while true:
		var labels: Array[String] = menu_labels(GameState.has_flag(STORAGE_FLAG),
			not GameState.travel_targets(current_map).is_empty(), room_puzzle, Online.league_on(),
			GameState.has_flag("aldo_gift"))
		labels.insert(labels.find("Satchel") + 1, "Shop (locked)" if Billing.kids_locked() else "Shop")
		if "Travel" in labels:
			await tip("travel")
		var entries: Array[Dictionary] = []
		for l: String in labels:
			entries.append({"text": l})
		var idx: int = await pick(menu_title(current_map), entries, true, maxi(0, labels.find(last_label)))
		if idx < 0:
			return
		last_label = labels[idx]
		match labels[idx]:
			"Goals": await run_goals()
			"Map book": await MapBookMenu.run(self)
			"Map": await WorldMapMenu.run(self, current_map)
			"Team": await run_team()
			"Friends":
				await tip("friends")
				await FriendsMenu.run(self)
				if not echo_duel.is_empty() or not raid_attempt.is_empty():
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
				save_now()
			"Save and to title":
				if await save_and_quit():
					return
			"Settings": await run_settings()
			"Photo":
				photo = true
				return
			"Travel":
				if await run_travel():
					return
			"Room":
				if await run_room():
					return

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

## The Guide (item 1985): every tip already seen, by topic, to read again.
func run_guide() -> void:
	while true:
		var ids: Array[String] = Tips.seen()
		var names: Array[String] = []
		for id: String in ids:
			names.append(Tips.TOPICS[id])
		var idx: int = await pick_strings("Guide", names)
		if idx < 0:
			return
		var lines: Array[String] = []
		for l: String in Tips.lines_of(ids[idx]):
			lines.append(Loc.t(l))
		await info("\n".join(lines))

## [param daily] replaces today's visitor line (tests).
static func goal_rows(flags: Dictionary, daily: Variant = null) -> Array[Dictionary]:
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
		if not memorial_lines().is_empty():
			lines.append("Memorial book")
		if not Album.stickers().is_empty():
			lines.append("Sticker wall")
		if not Lexicon.collected(GameState.records).is_empty():
			lines.append("Lexicon")
		var last: Dictionary = GameState.records.get("last_battle", {})
		if not last.is_empty():
			lines.append("Watch last battle")
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
			"Memorial book": await info("\n".join(memorial_lines()))
			"Sticker wall": await info("\n".join(Album.wall_lines()))
			"Lexicon": await run_lexicon()
			"Watch last battle":
				if await confirm("Watch the replay? %s" % BattleReplay.label(last)):
					watch_replay = true
					return

## The lexicon (plan area 2, item 680): the collected entries, each opened as a page.
func run_lexicon() -> void:
	var ids: Array[String] = Lexicon.collected(GameState.records)
	var titles: Array[String] = []
	for id: String in ids:
		titles.append(Lexicon.title(id))
	while true:
		var i: int = await pick_strings(Loc.t("Lexicon %d") % ids.size(), titles)
		if i < 0:
			return
		await info(Loc.t(Lexicon.text(ids[i])))

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
	if GameState.level_cap() < Spirling.MAX_LEVEL:
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
	var idx: int = await pick_strings("Travel to a rest spot", names)
	if idx < 0:
		return false
	# A mistap must not carry the player somewhere else (item 1878).
	if not await confirm("Travel to %s?" % names[idx], "Travel", "Stay"):
		return false
	travel_to = ids[idx]
	return true

func run_team() -> void:
	if GameState.party.size() >= 2:
		await tip("team_order")
	while true:
		var rows: Array[Dictionary] = []
		for i: int in GameState.party.size():
			rows.append(MenuHost.party_entry(GameState.party[i], i == 0))
		# Free slots up to the limit show how much room is left (item 1898).
		for i: int in range(GameState.party.size(), GameState.party_max()):
			rows.append(free_slot_row())
		# Running shop boosts with the battles left (item 4342).
		var boosts: Array[String] = ShopEffects.boost_lines()
		var title: String = Loc.t("Team") + ("  " + "  ".join(boosts) if not boosts.is_empty() else "")
		var idx: int = await pick(title, rows)
		if idx < 0 or idx >= GameState.party.size():
			return
		var s: Spirling = GameState.party[idx]
		var opts: Array[String] = ["Summary", "Lead the team", "Move to slot...", "Use item", "Keepsake"]
		# Every kind that can unfold shows the option; if it isn't ready yet, it says what it needs.
		if not s.data.unfold.is_empty():
			opts.append("Unfurl")
			await tip("unfurl")
		if s.earlier_form() != null:
			opts.append("Furl back")
		var opt: int = await pick_strings(s.display_name(), opts)
		if opt >= 5:
			await _unfurl(s, opts[opt] == "Unfurl")
			continue
		match opt:
			0: await info_pages(MenuHost.summary_pages(s), MiniSprite.of(s.data.species_name, 32))
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
	var entries: Array[String] = []
	if not s.held.is_empty():
		ids.append("")
		entries.append("Take off %s" % Database.item(s.held).get("name", s.held))
	for id: Variant in GameState.inventory:
		if GameState.item_count(str(id)) > 0 and BattleRules.is_holdable(str(id)):
			ids.append(str(id))
			entries.append("%s x%d" % [Database.item(str(id)).get("name", id), GameState.item_count(str(id))])
	if ids.is_empty():
		await info("You have nothing a Spirling can hold.\nKeepsakes are sold in Thornridge.")
		return
	var now: String = "Holding: %s" % (Database.item(s.held).get("name", s.held) if not s.held.is_empty() else "nothing")
	var idx: int = await pick_strings(now, entries)
	if idx < 0:
		return
	GameState.set_held(s, ids[idx])
	Sound.sfx("confirm")

func _use_item_on(s: Spirling) -> void:
	var ids: Array[String] = _usable_items()
	if ids.is_empty():
		await info("Nothing in the satchel can be used here.")
		return
	var entries: Array[String] = []
	for id: String in ids:
		entries.append("%s x%d" % [Database.item(id).get("name", id), GameState.item_count(id)])
	var idx: int = await pick_strings("Use on %s" % s.display_name(), entries)
	if idx < 0:
		return
	var msg: String = GameState.use_item_outside_battle(ids[idx], s)
	await info(msg if not msg.is_empty() else "That would do nothing right now.")

func _usable_items() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in GameState.inventory:
		var it: Dictionary = Database.item(str(id))
		if GameState.item_count(str(id)) > 0 and (int(it.get("heal", 0)) > 0 or float(it.get("revive", 0.0)) > 0.0 or bool(it.get("evolves", false))
				or int(it.get("rings", 0)) > 0 or bool(it.get("spark_all", false))):
			out.append(str(id))
	return out

## Satchel tabs (item 1914) and which tab an item belongs to.
const BAG_TABS: Array[String] = ["Care", "Keepsakes", "Crystals", "Gear", "Special"]

static func bag_tab(it: Dictionary) -> int:
	if bool(it.get("gear", false)):
		return 3
	if it.has("teaches"):
		return 2
	if bool(it.get("held", false)) or it.has("held"):
		return 1
	for k: String in ["heal", "cure", "revive", "energy", "stage", "battle"]:
		if it.has(k) and it[k]:
			return 0
	return 4

func run_bag() -> void:
	await tip("satchel")
	var tab: int = -1
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
		var entries: Array[Dictionary] = []
		for id: String in ids:
			var it0: Dictionary = Database.item(id)
			# The description stands in the line under the list (item 1915).
			entries.append({"text": "%s x%d" % [it0.get("name", id), GameState.item_count(id)],
				"hint": str(it0.get("description", ""))})
		var idx: int = await pick("Satchel", entries, true, -1, ListPicker.TAP_GUARD_MS, tabs, tab)
		if ListPicker.tab_of(idx) >= 0:
			tab = ListPicker.tab_of(idx)
			continue
		if idx < 0:
			return
		var item_id: String = ids[idx]
		var it: Dictionary = Database.item(item_id)
		if it.has("teaches"):
			await _teach_echo(item_id)
		elif int(it.get("spark", 0)) > 0:
			await _use_spark_charm(item_id)
		elif it.has("boost"):
			if await confirm("%s\n%s" % [Loc.t(str(it.get("name", ""))), Loc.t(str(it.get("description", "")))], "Use", "Not now"):
				await info(ShopEffects.start_boost(item_id))
		elif item_id in _usable_items():
			var names: Array[String] = []
			for s: Spirling in GameState.party:
				names.append(MenuHost.party_line(s))
			var who: int = await pick_strings("Use %s on?" % it.get("name", ""), names)
			if who >= 0 and bool(it.get("spark_all", false)):
				# The Spark Forge shows the values it will set before it is used.
				var s: Spirling = GameState.party[who]
				if not await confirm("%s\n%s" % [GameState.spark_reading(s), Loc.t("Afterwards every spark is at the top (12).")], "Use", "Not now"):
					who = -1
			if who >= 0:
				var msg: String = GameState.use_item_outside_battle(item_id, GameState.party[who])
				await info(msg if not msg.is_empty() else "That would do nothing right now.")
		elif bool(it.get("gear", false)):
			await info(gear_page(item_id), gear_picture(item_id))
		else:
			await info("%s\n%s" % [it.get("name", ""), it.get("description", "")])

## What each "works_on" entry of a gear item means (area 3 item 1050).
const GEAR_PLACES: Dictionary[String, String] = {
	"~": "narrow water with a post on the far side", "^": "low cliffs", "v": "vine walls (v)",
	"w": "shallow water (w)", "Y": "gaps with a chalk mark (Y)", "dark": "pitch-dark passages",
	"wheel": "sluice wheels, mine carts and grates", "shaft": "marked edges above a shaft",
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

## The tile a gear item works on, drawn at twice its size, or null.
static func gear_picture(id: String) -> Texture2D:
	var kinds: Dictionary = {"~": TilesetFactory.Kind.WATER, "^": TilesetFactory.Kind.CLIFF, "v": TilesetFactory.Kind.VINES,
		"w": TilesetFactory.Kind.WADE, "Y": TilesetFactory.Kind.PLANK, "dark": TilesetFactory.Kind.ROCK,
		"wheel": TilesetFactory.Kind.ROCK, "shaft": TilesetFactory.Kind.PLANK}
	var on: Array = Database.item(id).get("works_on", [])
	if on.is_empty() or not ResourceLoader.exists(TilesetFactory.ATLAS_PATH):
		return null
	var img: Image = (load(TilesetFactory.ATLAS_PATH) as Texture2D).get_image()
	var k: int = int(kinds.get(str(on[0]), TilesetFactory.Kind.GRASS))
	var tile: Image = img.get_region(Rect2i(k * TilesetFactory.TILE, 0, TilesetFactory.TILE, TilesetFactory.TILE))
	tile.resize(TilesetFactory.TILE * 2, TilesetFactory.TILE * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(tile)

## Echo Crystal: pick a Spirling of the right element, then (if it knows 4 moves) one to forget.
func _teach_echo(id: String) -> void:
	var it: Dictionary = Database.item(id)
	var mv: MoveData = Database.move(str(it.teaches))
	var names: Array[String] = []
	for s: Spirling in GameState.party:
		names.append("%s%s" % [MenuHost.party_line(s), "" if GameState.can_learn_echo(s, id) else "  (can't)"])
	var who: int = await pick_strings("Teach %s to?" % mv.move_name, names)
	if who < 0:
		return
	var s: Spirling = GameState.party[who]
	if not GameState.can_learn_echo(s, id):
		await info("%s can't learn %s." % [s.display_name(), mv.move_name])
		return
	if s.moves.size() < Spirling.MAX_MOVES:
		s.moves.append(mv)
	else:
		var known: Array[String] = []
		for m: MoveData in s.moves:
			known.append(m.move_name)
		var forget: int = await pick_strings("Forget which art for %s?" % mv.move_name, known)
		if forget < 0:
			return
		s.moves[forget] = mv
	Sound.sfx("level_up")
	await info("%s learned %s!" % [s.display_name(), mv.move_name])

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

## Spirlog filters (item 249), kept while the menu is open.
var _log_search: String = ""
var _log_element: int = -1
var _log_role: int = -1
var _log_status: int = SpirlogBook.STATUS_ALL
var _log_region: int = -1

## Spirlog: chapters per open region with their progress, search and filters, then the kinds.
## A seen kind opens its map-book page (SpirlogPage); unseen ones show as "???".
func run_spirlog() -> void:
	while true:
		var regions: Array[String] = SpirlogBook.open_regions(GameState.flags)
		var region: String = regions[_log_region] if _log_region >= 0 and _log_region < regions.size() else ""
		var role: String = SpirlingData.ROLES[_log_role] if _log_role >= 0 else ""
		var kinds: Array[SpirlingData] = SpirlogBook.filtered(GameState.spirlog, GameState.flags,
			_log_search, _log_element, role, _log_status, region)
		var entries: Array[Dictionary] = []
		var actions: Array[String] = []
		for r: String in regions:
			entries.append({"text": SpirlogBook.chapter_line(r, GameState.spirlog)})
			actions.append("chapter")
		entries.append({"text": "Chapter: %s" % (region.capitalize() if not region.is_empty() else "all")})
		actions.append("region")
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
		if GameState.has_flag(EchoPath.OPEN_FLAG):
			# Plan 3354: the Echo Path's wild kinds of the week, so missing ones can be planned.
			entries.append({"text": EchoPath.spirlog_hint()})
			actions.append("echo")
		var first_kind: int = entries.size()
		for sd: SpirlingData in kinds:
			# Own marks beside the line (item 1934): an eye for seen, a band for bonded.
			var mark: Texture2D = SpirlogMarks.bonded() if SpirlogBook.is_bonded(GameState.spirlog, sd.species_name) \
				else (SpirlogMarks.seen() if SpirlogBook.is_seen(GameState.spirlog, sd.species_name) else SpirlogMarks.none())
			entries.append({"text": SpirlogBook.list_line(sd, GameState.spirlog), "icon": mark})
			actions.append("kind")
		var idx: int = await pick("Spirlog (%d)" % kinds.size(), entries, true, first_kind if not kinds.is_empty() else -1)
		if idx < 0:
			return
		match actions[idx]:
			"chapter", "region":
				_log_region = _log_region + 1 if _log_region + 1 < regions.size() else -1
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
			"echo":
				await info(EchoPath.spirlog_hint() + "\n" + Loc.t("They wait in the wild rooms of the Echo Path behind the Cinder Rift. A new set comes every week."))
			"kind":
				var sd: SpirlingData = kinds[idx - first_kind]
				if not SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
					await info("#%02d  Not seen yet." % sd.dex_id)
					continue
				await SpirlogPage.show_pages(self, kinds, idx - first_kind)

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
		var names: Array[String] = [
			"Sort: %s" % GameState.STORAGE_SORTS[_storage_sort],
			"Show: %s" % ("all" if _storage_element < 0 else Elements.element_name(_storage_element)),
			"Move several...",
			"Rename box",
			"Colour: %s" % Loc.t(str(bx.color).capitalize()),
		]
		for i: int in view:
			names.append(MenuHost.storage_line(GameState.storage[i]))
		var w: int = await pick_strings("%s (%d)" % [bx.name, view.size()], names)
		match w:
			-1:
				return
			0:
				_storage_sort = (_storage_sort + 1) % GameState.STORAGE_SORTS.size()
			1:
				_storage_element += 1
				if _storage_element >= Elements.E.size():
					_storage_element = -1
			2:
				await _move_several(view)
			3:
				var n: String = await TextPrompt.ask(self, "Box name", false, GameState.BOX_NAME_MAX, str(bx.name))
				GameState.rename_box(box, n)
			4:
				GameState.recolor_box(box)
			_:
				await _run_stored(view[w - 5])

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
		var opts: Array[String] = ["Details", "Call back", "Move to box...", "Unmark favourite" if s.favorite else "Mark as favourite"]
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
					return

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
