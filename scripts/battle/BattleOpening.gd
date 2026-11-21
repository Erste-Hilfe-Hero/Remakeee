class_name BattleOpening
extends RefCounted
## How a battle opens (docs/KAMPF_PLAN_1000.md items 15 and 29). Tuning in data/battle_flow.json.
## 15: walking up to a Wayfarer from behind gives the player's side the first move.
## 29: at 2x or 4x battle speed the opening line is the short one.

const PATH: String = "res://data/battle_flow.json"
const INITIATIVE_LINE: String = "You caught %s from behind! Your side moves first."

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data

# --- Initiative (15) ---------------------------------------------------------------------------

## True when [param player] stands right behind a Wayfarer at [param npc] that looks along
## [param npc_dir], so the Wayfarer never saw the player coming.
static func from_behind(npc: Vector2i, npc_dir: Vector2i, player: Vector2i) -> bool:
	return npc_dir != Vector2i.ZERO and player == npc - npc_dir

## Wardens and Rift bosses always see you coming: only plain Wayfarers can be caught.
static func may_catch(def: Dictionary) -> bool:
	return not def.has("warden") and str(def.get("boss", "")).is_empty()

static func initiative_turns() -> int:
	return int(data().get("initiative_turns", 1))

## True while the player's side moves before everyone (first turns of a battle with initiative).
static func player_first(m: BattleModel, side: int) -> bool:
	return m.initiative and not m.is_wild and side == BattleModel.Side.PLAYER and m.turn < initiative_turns()

## The line at the start of a battle with initiative.
static func initiative_event(m: BattleModel) -> Dictionary:
	return {"side": BattleModel.Side.FOE, "slot": 0, "name": m.trainer_name, "text": INITIATIVE_LINE, "args": [m.trainer_name]}

# --- Short opening line (29) -------------------------------------------------------------------

## The opening line of BATTLE_START event [param e] at battle speed [param speed]: from
## short_start_speed on a few words, slower the full line. Odd colours always get the full line.
static func start_line(e: BattleEvent, speed: float) -> String:
	if speed < float(data().get("short_start_speed", 2)) or bool(e.data.get("prism", false)) or bool(e.data.get("gleam", false)):
		return e.describe()
	if bool(e.data.get("wild", false)):
		if int(e.data.get("count", 1)) > 1:
			return "A swarm of %d!" % int(e.data.get("count", 1))
		return "A hushed %s!" % e.data.get("foe_name", "")
	if bool(e.data.get("boss", false)):
		return "%s rises!" % e.data.get("trainer", "")
	return "Duel with %s!" % e.data.get("trainer", "A Wayfarer")
