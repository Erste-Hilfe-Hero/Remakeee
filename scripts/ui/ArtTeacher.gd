class_name ArtTeacher
extends RefCounted
## Hesper in the lighthouse digs up arts a Spirling forgot (KAMPF_PLAN_1000 item 138): any art
## it could know at its Ring, for GameState.TEACHER_FEE coins each. The dialogue action "relearn"
## opens it; the Move Memory unlock from the shop does the same anywhere, for free.

## Runs the lesson in [param menu] until the player backs out.
static func run(menu: MenuHost) -> void:
	while true:
		var rows: Array[Dictionary] = []
		for i: int in GameState.party.size():
			rows.append(MenuHost.party_entry(GameState.party[i], i == 0))
		var who: int = await menu.pick(Loc.t("Who forgot an art? %d coins each.") % GameState.TEACHER_FEE, rows)
		if who < 0:
			return
		await _lesson(menu, GameState.party[who])

static func _lesson(menu: MenuHost, s: Spirling) -> void:
	var names: Array[String] = GameState.relearnable(s)
	if names.is_empty():
		await menu.info(Loc.t("Hesper: %s remembers everything it can. Lucky thing.") % s.display_name())
		return
	if GameState.money < GameState.TEACHER_FEE:
		await menu.info(Loc.t("Hesper: %d coins. Forgetting is free, remembering is not.") % GameState.TEACHER_FEE)
		return
	var shown: Array[String] = []
	for n: String in names:
		shown.append(Loc.t(n))
	var pick: int = await menu.pick_strings(Loc.t("Relearn which art for %s?") % s.display_name(), shown)
	if pick < 0:
		return
	var forget: int = -1
	if s.moves.size() >= Spirling.MAX_MOVES:
		forget = await menu.pick(Loc.t("Forget which art for %s?") % shown[pick], PauseMenu.swap_rows(s.moves, Database.move(names[pick])))
		if forget < 0:
			return
	if GameState.relearn_at_teacher(s, names[pick], forget):
		Sound.sfx("level_up")
		await menu.info(Loc.t("%s learned %s!") % [s.display_name(), shown[pick]])
