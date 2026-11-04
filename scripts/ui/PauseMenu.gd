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

func run() -> void:
	while true:
		var labels: Array[String] = ["Goals", "Team", "Spirlog", "Records", "Satchel", "Save", "Photo", "Settings"]
		if GameState.has_flag(STORAGE_FLAG):
			labels.insert(5, "Storage")
		if not GameState.travel_targets(current_map).is_empty():
			labels.insert(1, "Travel")
		var idx: int = await pick_strings(menu_title(), labels)
		if idx < 0:
			return
		match labels[idx]:
			"Goals":
				var daily: String = DailyFind.hint(GameState.flags)
				await info(QuestLog.summary(GameState.flags) + ("\n\n" + daily if not daily.is_empty() else ""))
			"Team": await run_team()
			"Spirlog": await run_spirlog()
			"Records":
				await run_records()
				if watch_replay:
					return
			"Satchel": await run_bag()
			"Storage": await run_storage()
			"Save":
				var ok: bool = SaveManager.save_game()
				Sound.sfx("save" if ok else "cancel")
				await info("Game saved." if ok else "Saving failed.")
			"Settings": await run_settings()
			"Photo":
				photo = true
				return
			"Travel":
				if await run_travel():
					return

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
	lines.append(Collection.progress_text(GameState.spirlog, Database.spirlings.size()))
	if GameState.iron_oath:
		lines.append("Iron Oath kept. In the Sanctuary: %d" % GameState.sanctuary.size())
		for s: Spirling in GameState.sanctuary:
			lines.append("  %s Lv%d" % [s.display_name(), s.level])
	elif GameState.has_flag("oath_broken"):
		lines.append("Iron Oath broken.")
	var f: Dictionary = Season.current()
	if not f.is_empty():
		lines.append("Festival: %s" % f.name)
	return "\n".join(lines)

## Title line: name, coins, and the level cap on Veteran / Rift-Born (item 47).
static func menu_title() -> String:
	var t: String = "%s   %d coins" % [GameState.tamer_name, GameState.money]
	if GameState.level_cap() < Spirling.MAX_LEVEL:
		t += "   Cap Lv%d" % GameState.level_cap()
	return t

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
		if s.can_unfurl(current_map):
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
	var target: SpirlingData = s.data.evolves_to if forward else s.earlier_form()
	if target == null:
		return
	var q: String = ("Unfurl %s into %s? You can furl it back later." if forward else "Furl %s back into %s? You can unfurl it again later.") % [old_name, target.species_name]
	if not await confirm(q):
		return
	if forward:
		s.evolve()
		GameState.mark_seen(s.data.species_name, true)
	else:
		s.furl_back()
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
		else:
			await info("%s\n%s" % [it.get("name", ""), it.get("description", "")])

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
		var forget: int = await pick_strings("Forget which move for %s?" % mv.move_name, known)
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
			var mark: String = "*" if is_bonded else ("+" if is_seen else " ")
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
				lines.append("Trait: %s" % tr.label)
			if not sd.lore.is_empty():
				lines.append("")
				lines.append(sd.lore)
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
			names.append("%s Lv%d" % [s.display_name(), s.level])
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
