class_name BattleComfort
extends RefCounted
## Comfort rules of the battle screen (docs/KAMPF_PLAN_1000.md items 604 undo before the turn
## starts, 605 favourite art, 606 art order, 607 quick heal hint, 621 settings in battle,
## 623 big buttons, 629 pause on interruption). BattleScene, CommandMenu and PauseMenu only show them.

## chosen(RUN, UNDO) from the command menu takes back the order of the Spirling before (604).
const UNDO: int = -2
## Pixels each art row and command button grows with Big buttons on (623).
const BIG_EXTRA: int = 3
## Below this share of Vigor a Spirling gets a heal hint after the battle (607).
const HEAL_HINT_BELOW: float = 0.5

# --- Undo (604) -------------------------------------------------------------------------

## Takes the last order out of [param out] (and its swap target out of [param taken]).
## Returns false when there was nothing to take back.
static func undo(out: Array[BattleAction], taken: Array[int]) -> bool:
	if out.is_empty():
		return false
	var a: BattleAction = out.pop_back()
	if a.kind == BattleAction.Kind.SWAP:
		taken.erase(a.swap_index)
	return true

# --- Favourite art and art order (605, 606) ------------------------------------------------

## Row of [param s]'s favourite art, -1 when it has none (or forgot it).
static func favourite_row(s: Spirling) -> int:
	if s == null or s.fav_art.is_empty():
		return -1
	for i: int in s.moves.size():
		if s.moves[i].move_name == s.fav_art:
			return i
	return -1

## Marks the art in [param row] as favourite, or clears it when it already is. Returns the new state.
static func toggle_favourite(s: Spirling, row: int) -> bool:
	if row < 0 or row >= s.moves.size():
		return false
	var name: String = s.moves[row].move_name
	s.fav_art = "" if s.fav_art == name else name
	return not s.fav_art.is_empty()

## Moves the art in [param from] to [param to] (the order shown in battle). False if out of range.
static func move_art(s: Spirling, from: int, to: int) -> bool:
	if from < 0 or to < 0 or from >= s.moves.size() or to >= s.moves.size() or from == to:
		return false
	var mv: MoveData = s.moves[from]
	s.moves.remove_at(from)
	s.moves.insert(to, mv)
	return true

## Row the command menu focuses first: the art used last turn, else the favourite.
static func first_row(last: int, s: Spirling) -> int:
	return last if last >= 0 else favourite_row(s)

## Mark in front of the favourite art, in the team menu and on the battle art rows (item 158).
## "+" like a favourite friend; "*" already stands for focus arts (BattleHelp.KIND_MARK).
const FAV_MARK: String = "+"

## [constant FAV_MARK] when [param mv] is [param s]'s favourite art, else "".
static func fav_mark(s: Spirling, mv: MoveData) -> String:
	return FAV_MARK if s != null and mv != null and not s.fav_art.is_empty() and mv.move_name == s.fav_art else ""

## The art list rows for the team menu: a plus marks the favourite.
static func art_rows(s: Spirling) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mv: MoveData in s.moves:
		var fav: String = fav_mark(s, mv)
		out.append({"text": (fav + " " if not fav.is_empty() else "") + mv.move_name,
			"hint": "%s %s" % [BattleHelp.kind_mark(mv.kind), Loc.t(Elements.element_name(mv.element))]})
	return out

# --- Quick heal hint (607) -------------------------------------------------------------------

## The best heal after a battle: {"item", "name", "target"} for the most hurt Spirling below
## HEAL_HINT_BELOW, using the smallest healing item in [param bag] that mends it fully, else the
## strongest one. {} when nobody needs it or nothing heals.
static func heal_hint(party: Array, bag: Dictionary) -> Dictionary:
	var target: Spirling = null
	for s: Spirling in party:
		if s == null or s.is_fainted() or float(s.hp) >= float(s.max_hp()) * HEAL_HINT_BELOW:
			continue
		if target == null or float(s.hp) / s.max_hp() < float(target.hp) / target.max_hp():
			target = s
	if target == null:
		return {}
	var missing: int = target.max_hp() - target.hp
	var best: String = ""
	var best_heal: int = 0
	for id: Variant in bag:
		if int(bag[id]) <= 0:
			continue
		var heal: int = int(Database.item(str(id)).get("heal", 0))
		if heal <= 0:
			continue
		var fits: bool = heal >= missing
		var best_fits: bool = best_heal >= missing
		if best.is_empty() or (fits and (not best_fits or heal < best_heal)) or (not fits and not best_fits and heal > best_heal):
			best = str(id)
			best_heal = heal
	if best.is_empty():
		return {}
	return {"item": best, "name": str(Database.item(best).get("name", best)), "target": target}

static func heal_line(hint: Dictionary) -> String:
	if hint.is_empty():
		return ""
	var s: Spirling = hint.target
	return Loc.t("Tip: a %s would mend %s (%d/%d). Use it from the satchel.") % [Loc.t(str(hint.name)), s.display_name(), s.hp, s.max_hp()]

# --- Settings in battle (621) ------------------------------------------------------------------

## Rows of the in-battle settings list: [key, label]. Only settings that make sense mid-battle.
static func option_rows() -> Array[Array]:
	var rows: Array[Array] = [
		["speed", Loc.t("Battle speed: %dx") % int(GameState.battle_speed_scale())],
		["text", Loc.t("Text speed: %s") % Loc.t(GameState.TextSpeed.keys()[GameState.text_speed].capitalize())],
		["big", Loc.t("Big buttons: %s") % Loc.t("On" if GameState.big_buttons else "Off")],
		["motion", Loc.t("Less motion: %s") % Loc.t("On" if GameState.reduce_motion else "Off")],
		["shake", Loc.t("Screen shake: %s") % Loc.t(["Off", "Weak", "Full"][clampi(GameState.screen_shake, 0, 2)])],
	]
	if ShopEffects.owns_setting("damage_preview"):
		rows.insert(1, ["preview", Loc.t("Damage preview: %s") % Loc.t("On" if GameState.damage_preview else "Off")])
	return rows

## Changes the setting behind [param key] one step. Returns false for an unknown key.
static func toggle_option(key: String) -> bool:
	match key:
		"speed":
			GameState.cycle_battle_speed()
		"preview":
			GameState.damage_preview = not GameState.damage_preview
		"text":
			GameState.text_speed = MenuHost.next_text_speed(GameState.text_speed)
		"big":
			GameState.big_buttons = not GameState.big_buttons
		"motion":
			GameState.reduce_motion = not GameState.reduce_motion
		"shake":
			GameState.screen_shake = (GameState.screen_shake + 1) % 3
		_:
			return false
	return true

# --- Big buttons (623) ---------------------------------------------------------------------------

static func big_extra(on: bool = GameState.big_buttons) -> int:
	return BIG_EXTRA if on else 0

## Button sizes (896): with Big buttons every art row and command grows by BIG_EXTRA and is at
## least as tall as data/battle_ui.json "big_button_min" says, so Era I's small rows reach a
## finger-sized target too.
static func big_min(kind: String) -> int:
	return int((HpBarStyle.cfg().get("big_button_min", {}) as Dictionary).get(kind, 0))

## Height of an art row in [param era].
static func art_h(era: int, on: bool = GameState.big_buttons) -> int:
	var base: int = int(EraBattleHud.num(era, "art_h", 13))
	return maxi(base + BIG_EXTRA, big_min("art")) if on else base

## Height of a command button (Swap, Item, Bond, Leave) in [param era].
static func command_h(era: int, on: bool = GameState.big_buttons) -> int:
	var base: int = int(EraBattleHud.num(era, "command_h", 16))
	return maxi(base + BIG_EXTRA, big_min("command")) if on else base

## Height of the command panel: the era's own, plus what the art rows and commands grew by.
static func menu_height(era: int, on: bool = GameState.big_buttons) -> int:
	var base: int = EraBattleHud.menu_height(era)
	if not on:
		return base
	var art_grow: int = art_h(era, true) - art_h(era, false)
	var cmd_grow: int = command_h(era, true) - command_h(era, false)
	var arts: int = Spirling.MAX_MOVES * art_h(era, false) + Spirling.MAX_MOVES - 1
	var commands: String = EraBattleHud.text(era, "commands", "row")
	if commands == "column":
		var col: int = EraBattleHud.command_column_height(era)
		return base - maxi(arts, col) + maxi(arts + Spirling.MAX_MOVES * art_grow, col + 4 * cmd_grow)
	var rows: int = 2 if commands == "grid" else 1
	return base + Spirling.MAX_MOVES * art_grow + rows * cmd_grow

# --- Interruption (629) --------------------------------------------------------------------------

## +1 when [param what] means the app lost the player (call, home button, other window), -1 when
## it is back, 0 for anything else. While away, Auto and the auto-advancing text wait.
static func interruption(what: int) -> int:
	if what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		return 1
	if what in [Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_APPLICATION_FOCUS_IN]:
		return -1
	return 0
