class_name TurnFlow
extends RefCounted
## Turn flow rules of docs/KAMPF_PLAN_1000.md: turn clock in echo duels (item 6), giving up a
## Wayfarer battle (8), the swap offer after a foe's knock-out (9), the foe naming its next
## Spirling (10) and "All rest" in a formation (12). Tuning in data/turn_flow.json.
## BattleModel holds the rules (forfeit, AWAIT_SHIFT); BattleScene only shows them.

const PATH: String = "res://data/turn_flow.json"
## Model meta with the seconds per turn (set for echo duels).
const CLOCK_META: String = "turn_seconds"
## Model meta of friendly battles (echo duels, halls, league, raids, training): no giving up.
const NO_FORFEIT_META: String = "no_forfeit"
## chosen(REST, ...) indices of the command menu: the turn clock ran out, "All rest" was picked.
const TIMED_OUT: int = -3
const ALL_REST: int = -4
## GameState.flags keys of the two options (both on unless switched off).
const SHIFT_OFF_FLAG: String = "shift_offer_off"
const ANNOUNCE_OFF_FLAG: String = "foe_announce_off"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data

# --- Turn clock (6) -----------------------------------------------------------------------

static func echo_seconds() -> int:
	return maxi(1, int(data().get("echo_turn_seconds", 60)))

## Whole seconds left before [param deadline_ms] at [param now_ms], never below 0.
static func seconds_left(deadline_ms: int, now_ms: int) -> int:
	return maxi(0, ceili(float(deadline_ms - now_ms) / 1000.0))

## True once the prompt should warn that the clock runs out.
static func warn_now(left: int) -> bool:
	return left <= int(data().get("warn_seconds", 10))

# --- Rest for everyone left (6, 12) -------------------------------------------------------

## [param out] plus a Rest for every player slot (not a partner's) that has no order yet.
static func fill_rest(model: BattleModel, out: Array[BattleAction]) -> Array[BattleAction]:
	var done: Array[int] = []
	for a: BattleAction in out:
		done.append(a.slot)
	var full: Array[BattleAction] = out.duplicate()
	for slot: int in model.player_slots():
		if not slot in done:
			full.append(BattleAction.make_rest(BattleModel.Side.PLAYER, slot))
	return full

## "All rest" shows in a formation with two or more of the player's own Spirlings standing.
static func all_rest_shown(model: BattleModel) -> bool:
	return model.is_multi() and model.player_slots().size() >= 2

# --- Giving up (8) --------------------------------------------------------------------------

## Only against a Wayfarer, never in a battle the server checks, a Trial or one already over.
static func can_forfeit(model: BattleModel) -> bool:
	return not model.is_wild and not model.is_finished() and not model.has_meta(NO_FORFEIT_META) \
		and not model.has_meta("puzzle_max")

# --- Swap offer and announcement (9, 10) -----------------------------------------------------

## Whether the swap offer is on at [param difficulty]: Story and Wayfarer always, Veteran
## unless [param switched_off], Rift-Born never.
static func shift_offer_on(difficulty: int, switched_off: bool) -> bool:
	var per: Array = data().get("shift_offer", [])
	var mode: String = str(per[difficulty]) if difficulty >= 0 and difficulty < per.size() else "off"
	return mode == "on" or (mode == "setting" and not switched_off)

## Whether the Veteran switch is offered at all at [param difficulty] (the settings row).
static func shift_setting_shown(difficulty: int) -> bool:
	var per: Array = data().get("shift_offer", [])
	return difficulty >= 0 and difficulty < per.size() and str(per[difficulty]) == "setting"

static func shift_on() -> bool:
	return shift_offer_on(GameState.difficulty, bool(GameState.flags.get(SHIFT_OFF_FLAG, false)))

static func announce_on() -> bool:
	return not bool(GameState.flags.get(ANNOUNCE_OFF_FLAG, false))

## The Wayfarer's line as it names its next Spirling (English; the text box translates it).
static func announce_line(next_name: String) -> String:
	return str(data().get("announce_line", "%s, you're up.")) % next_name

## The question before the swap offer.
static func shift_question(next_name: String) -> String:
	return Loc.t("%s is about to step out. Swap first?") % next_name
