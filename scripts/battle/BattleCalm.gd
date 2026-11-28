class_name BattleCalm
extends RefCounted
## Battles without a clock (docs/KAMPF_PLAN_1000.md items 632 no time pressure, 908 adjustable
## input delay, 912 pause at any time). BattleScene, CommandMenu, ListPicker and BattlePause only
## ask these rules.

# --- Tap guard (908) ----------------------------------------------------------------------------

## How long a menu ignores taps after it appears, per setting step (GameState.input_delay).
## Step 0 keeps each list's own short double-tap guard.
const INPUT_DELAYS_MS: Array[int] = [0, 200, 400, 700]
const INPUT_DELAY_NAMES: Array[String] = ["Off", "Short", "Medium", "Long"]

static func delay_ms(step: int = GameState.input_delay) -> int:
	return INPUT_DELAYS_MS[clampi(step, 0, INPUT_DELAYS_MS.size() - 1)]

static func next_delay(step: int) -> int:
	return (clampi(step, 0, INPUT_DELAYS_MS.size() - 1) + 1) % INPUT_DELAYS_MS.size()

static func delay_name(step: int = GameState.input_delay) -> String:
	return INPUT_DELAY_NAMES[clampi(step, 0, INPUT_DELAY_NAMES.size() - 1)]

## The guard of a list: its own [param base] or the player's delay, whichever is longer.
static func guard_ms(base: int, step: int = GameState.input_delay) -> int:
	return maxi(base, delay_ms(step))

## True once [param now_ms] is at least the delay after the menu opened at [param opened_ms].
static func input_ready(opened_ms: int, now_ms: int, step: int = GameState.input_delay) -> bool:
	return now_ms - opened_ms >= delay_ms(step)

# --- No time pressure (632) ---------------------------------------------------------------------

## Whether battle text moves on by itself. Auto battle is the player's own choice and keeps its
## pace; fast speed alone does not when "No rush" is on, and nothing moves on while paused or away.
static func text_auto(speed: float, auto_on: bool, away: bool, no_rush: bool = GameState.no_rush) -> bool:
	if away:
		return false
	return auto_on or (speed > 1.0 and not no_rush)

## The bonding style a battle uses: with "No rush" every style becomes the calm echo, which has
## no time limit (Mine is a tug against a clock, Echo times the answer).
static func bond_style(style: String = GameState.bond_style, no_rush: bool = GameState.no_rush) -> String:
	return "calm" if no_rush else style

# --- Pause (912) --------------------------------------------------------------------------------

## True when [param event] opens or closes the battle pause: the menu button (Start, Escape, M)
## always; a tap or confirm only closes it. A tap closes on lifting the finger, so neither half of
## it reaches the art button underneath (touch arrives as an emulated mouse tap).
static func pause_toggle(event: InputEvent, paused: bool) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(GameState.MENU_ACTION):
		return true
	if not paused:
		return false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventMouseButton:
		return not (event as InputEventMouseButton).pressed
	return false

static func pause_lines() -> Array[String]:
	return [Loc.t("Paused"), Loc.t("Nothing moves. Even the foe holds its breath, out of politeness or spite."), Loc.t("Tap to go on")]
