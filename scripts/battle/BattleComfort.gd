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
		["aim", Loc.t("Auto aim: %s") % Loc.t("On" if GameState.auto_aim else "Off")],
		["motion", Loc.t("Less motion: %s") % Loc.t("On" if GameState.reduce_motion else "Off")],
		["shake", Loc.t("Screen shake: %s") % Loc.t(["Off", "Weak", "Full"][clampi(GameState.screen_shake, 0, 2)])],
		["no_rush", Loc.t("No rush: %s") % Loc.t("On" if GameState.no_rush else "Off")],
		["input_delay", Loc.t("Tap guard: %s") % Loc.t(BattleCalm.delay_name())],
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
		"aim":
			GameState.auto_aim = not GameState.auto_aim
		"motion":
			GameState.reduce_motion = not GameState.reduce_motion
		"shake":
			GameState.screen_shake = (GameState.screen_shake + 1) % 3
		"no_rush":
			GameState.no_rush = not GameState.no_rush
		"input_delay":
			GameState.input_delay = BattleCalm.next_delay(GameState.input_delay)
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

# --- Pause in battle (24) ------------------------------------------------------------------------

## Title of the list Start / Escape opens mid-battle; the Log's More list is the same without Resume.
const PAUSE_TITLE: String = "Battle paused"
const MORE_PAGES: Array[String] = ["Matchups", "Battle rules", "Stat calculator", "Search", "Settings"]

## The pages of the More list; the pause list starts with Resume. [param forfeit]: a Wayfarer
## battle that may be given up ends the list with "Give up" (plan Chimora 100, item 43: no main
## command next to Item; it still asks before the battle counts as lost).
static func more_pages(title: String, forfeit: bool = false) -> Array[String]:
	var out: Array[String] = MORE_PAGES.duplicate()
	if title == PAUSE_TITLE:
		out.push_front("Resume")
	if forfeit:
		out.append("Give up")
	return out

## Start / Escape pauses only a running battle and only when no other list is open.
static func may_pause(finished: bool, busy: bool) -> bool:
	return not finished and not busy

## Auto, auto-advancing text and the next event run only while the app is here and not paused.
static func runs(away: bool, paused: bool) -> bool:
	return not away and not paused

# --- Auto (plan Chimora 100, items 15-22: Ali 2026-11-21 "im Kampf Auto Knopf seitlich") -------

## The Auto setting: off, wild battles only, or every story battle (Wayfarers too; Wardens,
## Rift bosses and rivals always start off and ask once).
enum AutoMode { OFF, WILD, STORY }
const AUTO_MODE_NAMES: Array[String] = ["Off", "Wild only", "All story battles"]
## chosen(REST, AUTO_PICK) from the scene: Auto was switched on while the menu waited.
const AUTO_PICK: int = -5

## Which Auto a battle gets: "wild", "wayfarer", "boss" (Warden, Rift boss, story rival) or
## "off". Real opponents (League, live duels, raids, tourneys, war, Halls, Trials: all
## "friendly") stay off. So do the record runs (Tower, Boss Hall, Weekly Giant, Master tour,
## Masters, Random Rift, weekly echoes, bounties): only battles TrainerData.battle_info marks
## "story" offer Auto, so no best floor or best time is ever set by Auto.
static func auto_kind(wild: bool, trainer: Dictionary) -> String:
	if bool(trainer.get("friendly", false)):
		return "off"
	if wild:
		return "wild"
	if not bool(trainer.get("story", false)):
		return "off"
	if bool(trainer.get("warden", false)) or not str(trainer.get("boss", "")).is_empty() or bool(trainer.get("rival", false)):
		return "boss"
	return "wayfarer"

## True when Auto is on as the battle starts: wild battles from "Wild only", Wayfarers from
## "All story battles"; a boss battle always starts off.
static func auto_starts_on(kind: String, mode: int) -> bool:
	match kind:
		"wild":
			return mode >= AutoMode.WILD
		"wayfarer":
			return mode >= AutoMode.STORY
	return false

## The AI tier Auto fights with: tier 2 against bosses, tier 1 otherwise and on Story difficulty.
static func auto_tier(kind: String, difficulty: int) -> int:
	return 2 if kind == "boss" and difficulty != GameState.Difficulty.STORY else 1

## The new setting after the Auto tab was tapped in a [param kind] battle: a wild battle keeps
## the choice for the next ones (as before), other battles change only themselves.
static func auto_mode_after_tap(kind: String, mode: int, on: bool) -> int:
	if kind != "wild":
		return mode
	if on:
		return maxi(mode, AutoMode.WILD)
	return AutoMode.OFF

## True when Auto should hand the battle back: a wild Spirling of a kind not yet bonded in the
## Spirlog stands and the Echo call is open.
static func auto_yields_bond(m: BattleModel, spirlog: Dictionary) -> bool:
	if m == null or not m.is_wild or m.bonded != null or not m.bond_block.is_empty():
		return false
	for slot: int in m.standing_slots(BattleModel.Side.FOE):
		var s: Spirling = m.active_spirling(BattleModel.Side.FOE, slot)
		if s != null and s.data != null and not bool(GameState.upgrade_spirlog_entry(spirlog.get(s.data.species_name, {})).get("bonded", false)):
			return true
	return false

## "Auto: Wild only" for the settings list.
static func auto_setting_label(mode: int) -> String:
	return Loc.t("Auto: %s") % Loc.t(AUTO_MODE_NAMES[clampi(mode, 0, AUTO_MODE_NAMES.size() - 1)])
