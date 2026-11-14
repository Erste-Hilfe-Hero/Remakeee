class_name BossRunner
extends RefCounted
## Rift heart echoes and the heart rush on Examiner Hollis's board (KAMPF_PLAN_1000 items 417,
## 418; rules and values in BossHall.gd). Kept out of Overworld.gd: the board only calls [method open].

static func _pick(ow: Overworld, title: String, items: Array[String]) -> int:
	var m := MenuHost.new()
	ow._ui.add_child(m)
	var i: int = await m.pick_strings(title, items)
	m.queue_free()
	return i

static func _confirm(ow: Overworld, text: String) -> bool:
	var m := MenuHost.new()
	ow._ui.add_child(m)
	var go: bool = await m.confirm(text)
	m.queue_free()
	return go

## The board line, or "" while no heart is open.
static func board_line() -> String:
	return "" if BossHall.open_echoes(GameState.flags).is_empty() else Loc.t("Rift hearts")

static func open(ow: Overworld) -> void:
	var open_hearts: Array[Dictionary] = BossHall.open_echoes(GameState.flags)
	var items: Array[String] = []
	for e: Dictionary in open_hearts:
		var wins: int = int(BossRules.stats(GameState.records, str(e.get("boss", ""))).get("wins", 0))
		items.append(Loc.t("%s (won %d times)") % [Loc.t(str(e.get("name", ""))), wins])
	var rush_on: bool = BossHall.rush_open(GameState.flags)
	if rush_on:
		items.append(Loc.t("Heart rush (best %d of %d)") % [BossHall.rush_best(GameState.records), open_hearts.size()])
	var pick: int = await _pick(ow, Loc.t("Which heart?"), items)
	if pick < 0:
		return
	if pick < open_hearts.size():
		await echo(ow, open_hearts[pick])
	elif rush_on:
		await rush(ow, open_hearts)

static func _fight(ow: Overworld, e: Dictionary) -> BattleModel.Outcome:
	ow.busy = false
	var outcome: BattleModel.Outcome = await ow.start_battle(BossHall.team(e, GameState.rng, GameState.difficulty), false, BossHall.battle_info(e))
	ow.busy = true
	ow.player.frozen = true
	if outcome == BattleModel.Outcome.WIN and ow.last_model != null:
		BossRules.note_win(GameState.records, str(e.get("boss", "")), ow.last_model.turn)
	return outcome

## One heart again (item 417): full rest first, the purse on a win.
static func echo(ow: Overworld, e: Dictionary) -> void:
	if not await _confirm(ow, Loc.t(str(BossHall.data().get("echo_intro", "")))):
		return
	GameState.heal_party()
	await _fight(ow, e)
	SaveManager.save_game()

## Every open heart in a row without rest (item 418); the first full clear gives the rush reward.
static func rush(ow: Overworld, hearts: Array[Dictionary]) -> void:
	if not await _confirm(ow, Loc.t(str(BossHall.data().get("rush_intro", "")))):
		return
	GameState.heal_party()
	var beaten: int = 0
	for e: Dictionary in hearts:
		if beaten > 0:
			await ow.say([Loc.t(str(BossHall.data().get("rush_line", ""))) % [beaten + 1, hearts.size()]] as Array[String])
		if await _fight(ow, e) != BattleModel.Outcome.WIN:
			break
		beaten += 1
	var first: bool = BossHall.note_rush(GameState.records, beaten, hearts.size())
	await ow.say([Loc.t(str(BossHall.data().get("rush_result", ""))) % [beaten, hearts.size()]] as Array[String])
	if first:
		var r: Array = BossHall.rush().get("reward", [])
		GameState.set_flag(str(BossHall.rush().get("flag", "heart_rush_clear")))
		if r.size() >= 2:
			await ow._action_give_item(PackedStringArray([str(r[0]), str(r[1])]), null)
	SaveManager.save_game()
