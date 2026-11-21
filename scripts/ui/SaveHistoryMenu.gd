class_name SaveHistoryMenu
extends RefCounted
## Settings > Account > Earlier saves (plan area 7, item 3009): the server keeps the last 5
## versions of each slot. Each shows its date, place and play time and can be brought back; the
## version it replaces stays in the list, so bringing one back can be undone.

static func date_text(unix: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix + Time.get_time_zone_from_system().get("bias", 0) * 60)
	return "%02d.%02d. %02d:%02d" % [int(d.day), int(d.month), int(d.hour), int(d.minute)]

static func entry_line(h: Dictionary) -> String:
	return "%s  %s" % [date_text(int(h.saved_at)), str(h.summary)]

## Returns true when the game went back to the title (the running journey was replaced).
static func run(menu: MenuHost) -> bool:
	var slots: Array[String] = []
	for n: int in [1, 2, 3]:
		slots.append(Loc.t("Slot %d") % n + "  " + SaveManager.slot_summary(n))
	var si: int = await menu.pick_strings("Earlier saves of which slot?", slots)
	if si < 0:
		return false
	var slot: int = si + 1
	var r: Dictionary = await Online.call_fn("save_history_list", {"p_slot": slot})
	if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
		await menu.info(Online.error_text(str(r.get("error", ""))))
		return false
	var saves: Array = r.data.get("saves", [])
	if saves.is_empty():
		await menu.info("There are no earlier saves of this slot yet.")
		return false
	var labels: Array[String] = []
	for h: Dictionary in saves:
		labels.append(entry_line(h))
	var hi: int = await menu.pick_strings("Earlier saves (the server keeps the last 5)", labels)
	if hi < 0:
		return false
	if not await menu.confirm(Loc.t("Bring back the save from %s? The current one stays in this list.") % date_text(int(saves[hi].saved_at))):
		return false
	var playing: bool = GameState.in_game and SaveManager.slot == slot
	if playing:
		SaveManager.save_game()
		await Online.push(slot)
	var res: Dictionary = await Online.call_fn("save_restore", {"p_slot": slot, "p_id": int(saves[hi].id)})
	if not res.ok or not res.data is Dictionary or not bool(res.data.get("ok", false)):
		await menu.info(Online.error_text(str(res.get("error", ""))))
		return false
	Online.dirty.erase(slot)
	await Online.pull(slot)
	if playing:
		await menu.info("The earlier save is back. The game returns to the title, then continue from there.")
		GameState.in_game = false
		menu.get_tree().change_scene_to_file(AccountMenu.TITLE_SCENE)
		return true
	await menu.info("The earlier save is back.")
	return false
