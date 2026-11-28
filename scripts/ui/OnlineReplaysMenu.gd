class_name OnlineReplaysMenu
extends RefCounted
## Records > Online replays (Online 100 plan points 71, 72, 78, 79): the kept online battles,
## sharing one as a code on the clipboard, watching a code from the clipboard, the own win rate
## per Spirling and the Spirlings met most often. Data in ReplayLibrary.

## Returns true when a replay was picked to watch (the pause menu then closes).
static func run(menu: PauseMenu) -> bool:
	while true:
		var lines: Array[String] = []
		for e: Dictionary in ReplayLibrary.entries(GameState.records):
			lines.append(ReplayLibrary.label(e))
		var fixed: Array[String] = ["Watch a code from the clipboard", "Win rate per Spirling", "Met most often"]
		var idx: int = await menu.pick_strings(Loc.t("Online replays (%d)") % lines.size(), lines + fixed)
		if idx < 0:
			return false
		if idx < lines.size():
			if await _one(menu, ReplayLibrary.entries(GameState.records)[idx]):
				return true
			continue
		match fixed[idx - lines.size()]:
			"Watch a code from the clipboard":
				var snap: Dictionary = ReplayLibrary.from_code(DisplayServer.clipboard_get())
				if snap.is_empty():
					await menu.info("The clipboard holds no replay code.")
				elif await _watch(menu, snap):
					return true
			"Win rate per Spirling":
				await _list(menu, ReplayLibrary.win_rate_lines(GameState.records))
			"Met most often":
				await _list(menu, ReplayLibrary.usage_lines(GameState.records))
	return false

static func _one(menu: PauseMenu, e: Dictionary) -> bool:
	var idx: int = await menu.pick_strings(ReplayLibrary.label(e), ["Watch", "Copy share code", "Save a result picture"] as Array[String])
	if idx == 2:
		# Point 76: a picture of the result, drawn by the game.
		await menu.info(await ResultCard.save(menu, ResultCard.facts_of_replay(e.get("snap", {}), Loc.t(ReplayLibrary._kind_name(str(e.get("kind", "")))))))
	if idx == 0:
		return await _watch(menu, e.get("snap", {}))
	if idx == 1:
		DisplayServer.clipboard_set(ReplayLibrary.share_code(e.get("snap", {})))
		await menu.info("The code is on the clipboard. A friend can watch it under Records, Online replays.")
	return false

static func _watch(menu: PauseMenu, snap: Dictionary) -> bool:
	var why: String = BattleReplay.problem(snap)
	if not why.is_empty():
		await menu.info(why)
		return false
	menu.watch_snap = snap
	menu.watch_replay = true
	return true

static func _list(menu: PauseMenu, lines: Array[String]) -> void:
	await menu.info("\n".join(lines) if not lines.is_empty() else Loc.t("No online battles yet."))
