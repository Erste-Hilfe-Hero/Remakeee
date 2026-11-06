class_name PauseMenu
extends MenuHost
## In-game menu: Goals, Team, Spirlog, Satchel, Save, Settings, and Storage once the box is unlocked.

const STORAGE_FLAG: String = "storage_remote"

## The map the player is on (for the Spirlog Tracker).
var encounter_table: String = ""
## The map the menu was opened on (fast travel lists the other rest spots).
var current_map: String = ""
## Set when the player picks a fast-travel target; the overworld moves them after the menu closes.
var travel_to: String = ""
## Set when the player picks Photo; the overworld opens photo mode after the menu closes.
var photo: bool = false
## Set when the player picks "Watch last battle" in Records.
var watch_replay: bool = false
## Set when the player picks an echo duel under Friends: {"code", "name", "team"}.
var echo_duel: Dictionary = {}
## Area 3 item 1012/1014: the map has a puzzle room; "Room" offers undo and reset.
var room_puzzle: bool = false
var can_undo: bool = false
## Set to "undo" or "reset" when the player picks one; the overworld does it after closing.
var room_action: String = ""

func run() -> void:
	while true:
		var labels: Array[String] = ["Goals", "Team", "Friends", "Spirlog", "Records", "Satchel", "Save", "Photo", "Settings"]
		if GameState.has_flag(STORAGE_FLAG):
			labels.insert(labels.find("Save"), "Storage")
		if not GameState.travel_targets(current_map).is_empty():
			labels.insert(1, "Travel")
		if room_puzzle:
			labels.insert(1, "Room")
		var idx: int = await pick_strings(menu_title(), labels)
		if idx < 0:
			return
		match labels[idx]:
			"Goals":
				await info(goals_text())
			"Team": await run_team()
			"Friends":
				await FriendsMenu.run(self)
				if not echo_duel.is_empty():
					return
			"Spirlog": await run_spirlog()
			"Records":
				await run_records()
				if watch_replay:
					return
			"Satchel": await run_bag()
			"Storage": await run_storage()
			"Save":
				save_now()
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

const SAVED_TEXT: String = "Saved."
const SAVED_LOCAL_TEXT: String = "Saved on this phone. The server follows once the connection is back."

## Goals screen: story goals, the find of the day and today's tasks (plan area 8).
static func goals_text() -> String:
	var text: String = Loc.t(QuestLog.summary(GameState.flags))
	var daily: String = DailyFind.hint(GameState.flags)
	if not daily.is_empty():
		text += "\n\n" + Loc.t(daily)
	var tasks: Array[String] = DailyTasks.lines()
	if not tasks.is_empty():
		text += "\n\n" + "\n".join(tasks)
	var next: String = Collection.next_text(GameState.spirlog, SpirlogBook.visible_kinds(GameState.flags).size(), GameState.flags)
	if not next.is_empty():
		text += "\n\n" + Loc.t(next)
	return text

## Achievements and personal bests (items 88-90).
func run_records() -> void:
	Achievements.check()
	while true:
		var lines: Array[String] = Achievements.lines()
		lines.append("Personal bests")
		var last: Dictionary = GameState.records.get("last_battle", {})
		if not last.is_empty():
			lines.append("Watch last battle")
		var have: int = Achievements.unlocked().size()
		var idx: int = await pick_strings("Achievements %d/%d" % [have, Achievements.LIST.size()], lines)
		if idx < 0:
			return
		if lines[idx] == "Watch last battle":
			if await confirm("Watch the replay? %s" % BattleReplay.label(last)):
				watch_replay = true
				return
		elif idx == Achievements.LIST.size():
			await info(records_text())
		else:
			var a: Dictionary = Achievements.LIST[idx]
			var when: String = str(Achievements.unlocked().get(a.id, ""))
			await info("%s\n%s%s" % [a.title, a.text, ("\n\n" + ("Earned %s" % when)) if when != "" else ""])

## Tower best, weekly challenge and the current festival.
static func records_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Lighthouse climb best: %d of %d" % [int(GameState.records.get("gauntlet_best", 0)), Gauntlet.ROUNDS])
	var rec: Dictionary = GameState.records.get("weekly", {})
	var week: String = WeeklyChallenge.this_week()
	var best: int = int(rec.get("best", 0)) if str(rec.get("week", "")) == week else 0
	lines.append("This week: %d of %d" % [best, WeeklyChallenge.ROUNDS])
	lines.append("Weekly wins: %d" % int(GameState.records.get("weekly_wins", 0)))
	lines.append("Rematches won: %d" % int(GameState.records.get("rematch_wins", 0)))
	lines.append(Collection.progress_text(GameState.spirlog, SpirlogBook.visible_kinds(GameState.flags).size()))
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
static func menu_title() -> String:
	var t: String = "%s   %d coins   %s" % [GameState.tamer_name, GameState.money, Waymarks.label()]
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
	travel_to = ids[idx]
	return true

func run_team() -> void:
	while true:
		var names: Array[String] = []
		for s: Spirling in GameState.party:
			names.append(MenuHost.party_line(s))
		var idx: int = await pick_strings("Team", names)
		if idx < 0:
			return
		var s: Spirling = GameState.party[idx]
		var opts: Array[String] = ["Summary", "Lead the team", "Move to slot...", "Use item", "Keepsake"]
		# Every kind that can unfold shows the option; if it isn't ready yet, it says what it needs.
		if not s.data.unfold.is_empty():
			opts.append("Unfurl")
		if s.earlier_form() != null:
			opts.append("Furl back")
		var opt: int = await pick_strings(s.display_name(), opts)
		if opt >= 5:
			await _unfurl(s, opts[opt] == "Unfurl")
			continue
		match opt:
			0: await info(MenuHost.summary(s))
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
	if forward:
		s.evolve(target)
		GameState.mark_seen(s.data.species_name, true)
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
		if GameState.item_count(str(id)) > 0 and (int(it.get("heal", 0)) > 0 or float(it.get("revive", 0.0)) > 0.0 or bool(it.get("evolves", false))):
			out.append(str(id))
	return out

func run_bag() -> void:
	while true:
		var ids: Array[String] = []
		var entries: Array[String] = []
		for id: Variant in GameState.inventory:
			if GameState.item_count(str(id)) <= 0:
				continue
			ids.append(str(id))
			entries.append("%s x%d" % [Database.item(str(id)).get("name", id), GameState.item_count(str(id))])
		if ids.is_empty():
			await info("The satchel is empty.")
			return
		var idx: int = await pick_strings("Satchel", entries)
		if idx < 0:
			return
		var it: Dictionary = Database.item(ids[idx])
		if it.has("teaches"):
			await _teach_echo(ids[idx])
		elif int(it.get("spark", 0)) > 0:
			await _use_spark_charm(ids[idx])
		elif ids[idx] in _usable_items():
			var names: Array[String] = []
			for s: Spirling in GameState.party:
				names.append(MenuHost.party_line(s))
			var who: int = await pick_strings("Use %s on?" % it.get("name", ""), names)
			if who >= 0:
				var msg: String = GameState.use_item_outside_battle(ids[idx], GameState.party[who])
				await info(msg if not msg.is_empty() else "That would do nothing right now.")
		elif bool(it.get("gear", false)):
			await info(gear_page(ids[idx]), gear_picture(ids[idx]))
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
		var first_kind: int = entries.size()
		for sd: SpirlingData in kinds:
			entries.append({"text": SpirlogBook.list_line(sd, GameState.spirlog)})
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
			"kind":
				var sd: SpirlingData = kinds[idx - first_kind]
				if not SpirlogBook.is_seen(GameState.spirlog, sd.species_name):
					await info("#%02d  Not seen yet." % sd.dex_id)
					continue
				await SpirlogPage.show_pages(self, kinds, idx - first_kind)

func _tracker_text() -> String:
	var lines: PackedStringArray = ["Spirlog Tracker", ""]
	for sp: String in EncounterTable.species_on(encounter_table):
		var e: Dictionary = GameState.spirlog.get(sp, {})
		var mark: String = "bonded" if bool(e.get("bonded", false)) else ("seen" if bool(e.get("seen", false)) else "not seen")
		lines.append("%s: %s" % [sp if bool(e.get("seen", false)) else "???", mark])
	return "\n".join(lines)

var _storage_sort: int = 0
var _storage_element: int = -1

## Storage (plan area 1, items 375-382): named boxes of 30, favourites, multi-move, team
## presets, release, keepsakes and a detail card for each Spirling.
func run_storage() -> void:
	GameState.ensure_boxes()
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
