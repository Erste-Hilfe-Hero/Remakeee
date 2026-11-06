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
		if GameState.has_flag("aldo_gift"):
			labels.insert(labels.find("Goals") + 1, "Map book")
		if room_puzzle:
			labels.insert(1, "Room")
		var idx: int = await pick_strings(menu_title(), labels)
		if idx < 0:
			return
		match labels[idx]:
			"Goals":
				await info(goals_text())
			"Map book": await MapBookMenu.run(self)
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
	var post: Array[String] = Postgame.lines()
	if not post.is_empty():
		text += "\n\n" + "\n".join(post)
	return text

## Achievements and personal bests (items 88-90, plan area 8): badge book, lists by category.
func run_records() -> void:
	Achievements.check()
	while true:
		var lines: Array[String] = ["Badge book", "Achievements by category", "Season path", "Personal bests"]
		if Masters.open():
			lines.append("Master Wayfarers")
		if not memorial_lines().is_empty():
			lines.append("Memorial book")
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
			"Master Wayfarers": await run_masters()
			"Memorial book": await info("\n".join(memorial_lines()))
			"Watch last battle":
				if await confirm("Watch the replay? %s" % BattleReplay.label(last)):
					watch_replay = true
					return

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
	var rec: Dictionary = GameState.records.get("weekly", {})
	var week: String = WeeklyChallenge.this_week()
	var best: int = int(rec.get("best", 0)) if str(rec.get("week", "")) == week else 0
	lines.append("This week: %d of %d" % [best, WeeklyChallenge.ROUNDS])
	lines.append("Weekly wins: %d" % int(GameState.records.get("weekly_wins", 0)))
	lines.append("Rematches won: %d" % int(GameState.records.get("rematch_wins", 0)))
	lines.append(Collection.progress_text(GameState.spirlog, Database.spirlings.size()))
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

## Spirlog: every species with seen/bonded marks, plus the Tracker for the current area.
func run_spirlog() -> void:
	while true:
		var all: Array[SpirlingData] = []
		for sd: SpirlingData in Database.spirlings.values():
			all.append(sd)
		all.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
		var seen: int = 0
		var bonded: int = 0
		var entries: Array[Dictionary] = []
		if not encounter_table.is_empty():
			entries.append({"text": "Tracker: this area"})
		for sd: SpirlingData in all:
			var e: Dictionary = GameState.spirlog.get(sd.species_name, {})
			var is_seen: bool = bool(e.get("seen", false))
			var is_bonded: bool = bool(e.get("bonded", false))
			seen += 1 if is_seen else 0
			bonded += 1 if is_bonded else 0
			var mark: String = (Collection.STAR if Collection.starred(sd.species_name) else "*") if is_bonded else ("+" if is_seen else " ")
			entries.append({"text": "%02d %s %s" % [sd.dex_id, mark, sd.species_name if is_seen else "???"], "species": sd.species_name, "seen": is_seen})
		var idx: int = await pick("Spirlog  seen %d  bonded %d" % [seen, bonded], entries)
		if idx < 0:
			return
		if not encounter_table.is_empty() and idx == 0:
			await info(_tracker_text())
			continue
		var entry: Dictionary = entries[idx]
		if not bool(entry.get("seen", false)):
			await info("Not seen yet.")
			continue
		var sd: SpirlingData = Database.species(str(entry.species))
		var els: PackedStringArray = []
		for el: int in sd.elements:
			els.append(Elements.element_name(el))
		var where: PackedStringArray = []
		for table: String in EncounterTable.table_ids():
			if sd.species_name in EncounterTable.species_on(table):
				where.append(table.replace("_", " ").capitalize())
		var lines: PackedStringArray = ["#%02d %s   %s" % [sd.dex_id, sd.species_name, "/".join(els)]]
		if not sd.height.is_empty():
			lines.append("Height %s" % sd.height)
		if not sd.habitat.is_empty():
			lines.append("Lives in: %s" % sd.habitat)
		lines.append("Found on: %s" % (", ".join(where) if not where.is_empty() else "unknown"))
		var log_entry: Dictionary = GameState.spirlog.get(sd.species_name, {})
		if bool(log_entry.get("bonded", false)):
			var tr: Dictionary = BattleRules.trait_info(sd.trait_id)
			if not tr.is_empty():
				lines.append("Gift: %s" % tr.label)
			if not sd.lore.is_empty():
				lines.append("")
				lines.append(sd.lore)
			var rift_lore: String = SpirlogLore.line(sd.species_name)
			if not rift_lore.is_empty():
				lines.append(rift_lore)
		else:
			lines.append("")
			lines.append("Bond with one to learn more.")
		await info("\n".join(lines))

func _tracker_text() -> String:
	var lines: PackedStringArray = ["Spirlog Tracker", ""]
	for sp: String in EncounterTable.species_on(encounter_table):
		var e: Dictionary = GameState.spirlog.get(sp, {})
		var mark: String = "bonded" if bool(e.get("bonded", false)) else ("seen" if bool(e.get("seen", false)) else "not seen")
		lines.append("%s: %s" % [sp if bool(e.get("seen", false)) else "???", mark])
	return "\n".join(lines)

var _storage_sort: int = 0
var _storage_element: int = -1

## Withdraw list with sort and element filter rows on top (item 57).
func _withdraw() -> void:
	while true:
		var view: Array[int] = GameState.storage_view(_storage_sort, _storage_element)
		var names: Array[String] = [
			"Sort: %s" % GameState.STORAGE_SORTS[_storage_sort],
			"Show: %s" % ("all" if _storage_element < 0 else Elements.element_name(_storage_element)),
		]
		for i: int in view:
			var s: Spirling = GameState.storage[i]
			names.append("%s R%d" % [s.display_name(), s.level])
		var w: int = await pick_strings("Call back (%d)" % view.size(), names)
		if w < 0:
			return
		if w == 0:
			_storage_sort = (_storage_sort + 1) % GameState.STORAGE_SORTS.size()
		elif w == 1:
			_storage_element += 1
			if _storage_element >= Elements.E.size():
				_storage_element = -1
		elif not GameState.withdraw(view[w - 2]):
			await info("Your team is full.")
		else:
			return

## Storage box: deposit and withdraw.
func run_storage() -> void:
	while true:
		var idx: int = await pick_strings("Storage (%d resting)" % GameState.storage.size(), ["Call back", "Send to rest"] as Array[String])
		if idx < 0:
			return
		if idx == 0:
			if GameState.storage.is_empty():
				await info("The box is empty.")
				continue
			await _withdraw()
		else:
			var names2: Array[String] = []
			for s: Spirling in GameState.party:
				names2.append(MenuHost.party_line(s))
			var d: int = await pick_strings("Send to rest", names2)
			if d >= 0 and not GameState.deposit(d):
				await info("You need at least one healthy Spirling with you.")
