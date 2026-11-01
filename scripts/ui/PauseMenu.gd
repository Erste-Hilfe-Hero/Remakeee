class_name PauseMenu
extends MenuHost
## In-game menu: Goals, Team, Spirlog, Bag, Save, Settings, and Storage once the box is unlocked.

const STORAGE_FLAG: String = "pc_unlocked"

## The map the player is on (for the Spirlog Tracker).
var encounter_table: String = ""

func run() -> void:
	while true:
		var labels: Array[String] = ["Goals", "Team", "Spirlog", "Bag", "Save", "Settings"]
		if GameState.has_flag(STORAGE_FLAG):
			labels.insert(4, "Storage")
		var idx: int = await pick_strings("%s   %d coins" % [GameState.tamer_name, GameState.money], labels)
		if idx < 0:
			return
		match labels[idx]:
			"Goals":
				var daily: String = DailyFind.hint(GameState.flags)
				await info(QuestLog.summary(GameState.flags) + ("\n\n" + daily if not daily.is_empty() else ""))
			"Team": await run_team()
			"Spirlog": await run_spirlog()
			"Bag": await run_bag()
			"Storage": await run_storage()
			"Save":
				var ok: bool = SaveManager.save_game()
				Sound.sfx("save" if ok else "cancel")
				await info("Game saved." if ok else "Saving failed.")
			"Settings": await run_settings()

func run_team() -> void:
	while true:
		var names: Array[String] = []
		for s: Spirling in GameState.party:
			names.append(MenuHost.party_line(s))
		var idx: int = await pick_strings("Team", names)
		if idx < 0:
			return
		var s: Spirling = GameState.party[idx]
		var opt: int = await pick_strings(s.display_name(), ["Summary", "Lead the team", "Use item"] as Array[String])
		match opt:
			0: await info(MenuHost.summary(s))
			1: GameState.swap_party(0, idx)
			2: await _use_item_on(s)

func _use_item_on(s: Spirling) -> void:
	var ids: Array[String] = _usable_items()
	if ids.is_empty():
		await info("Nothing in the bag can be used here.")
		return
	var entries: Array[String] = []
	for id: String in ids:
		entries.append("%s x%d" % [Database.item(id).get("name", id), GameState.item_count(id)])
	var idx: int = await pick_strings("Use on %s" % s.display_name(), entries)
	if idx < 0:
		return
	var msg: String = GameState.use_item_outside_battle(ids[idx], s)
	await info(msg if not msg.is_empty() else "It won't have any effect.")

func _usable_items() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in GameState.inventory:
		var it: Dictionary = Database.item(str(id))
		if GameState.item_count(str(id)) > 0 and (int(it.get("heal", 0)) > 0 or float(it.get("revive", 0.0)) > 0.0):
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
			await info("The bag is empty.")
			return
		var idx: int = await pick_strings("Bag", entries)
		if idx < 0:
			return
		var it: Dictionary = Database.item(ids[idx])
		if ids[idx] in _usable_items():
			var names: Array[String] = []
			for s: Spirling in GameState.party:
				names.append(MenuHost.party_line(s))
			var who: int = await pick_strings("Use %s on?" % it.get("name", ""), names)
			if who >= 0:
				var msg: String = GameState.use_item_outside_battle(ids[idx], GameState.party[who])
				await info(msg if not msg.is_empty() else "It won't have any effect.")
		else:
			await info("%s\n%s" % [it.get("name", ""), it.get("description", "")])

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
		await info("%s\n%s\nFound on: %s\n\n* bonded  + seen" % [sd.species_name, "/".join(els), ", ".join(where) if not where.is_empty() else "unknown"])

func _tracker_text() -> String:
	var lines: PackedStringArray = ["Spirlog Tracker", ""]
	for sp: String in EncounterTable.species_on(encounter_table):
		var e: Dictionary = GameState.spirlog.get(sp, {})
		var mark: String = "bonded" if bool(e.get("bonded", false)) else ("seen" if bool(e.get("seen", false)) else "not seen")
		lines.append("%s: %s" % [sp if bool(e.get("seen", false)) else "???", mark])
	return "\n".join(lines)

## Storage box: deposit and withdraw.
func run_storage() -> void:
	while true:
		var idx: int = await pick_strings("Storage (%d stored)" % GameState.storage.size(), ["Withdraw", "Deposit"] as Array[String])
		if idx < 0:
			return
		if idx == 0:
			if GameState.storage.is_empty():
				await info("The box is empty.")
				continue
			var names: Array[String] = []
			for s: Spirling in GameState.storage:
				names.append("%s Lv%d" % [s.display_name(), s.level])
			var w: int = await pick_strings("Withdraw", names)
			if w >= 0 and not GameState.withdraw(w):
				await info("Your team is full.")
		else:
			var names2: Array[String] = []
			for s: Spirling in GameState.party:
				names2.append(MenuHost.party_line(s))
			var d: int = await pick_strings("Deposit", names2)
			if d >= 0 and not GameState.deposit(d):
				await info("You need at least one healthy Spirling with you.")
