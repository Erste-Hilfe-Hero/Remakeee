class_name BossRules
extends RefCounted
## Rift boss mechanics of docs/KAMPF_PLAN_1000.md, area "Bosse und Wardens". BattleModel reads
## these tables; the second phase itself stays in BattleRules.BOSSES[id].phase.
##   late phases (item 402):  more phases after the second one, each once, by HP share
##   hold field (item 430):   while this field lies, the boss can't change phase
##   weak point (item 431):   right after a phase change the boss lies open (Guard -1) for one turn
##   rage (item 432):         a fight that drags on makes the boss stronger every few turns
##   status and stages (421, 422): timed statuses on a boss last half as long, stage drops are halved
##   guard (item 404):        a phase with "guard" calls a fresh guard into a fallen foe slot
##   phase music (item 406):  the music changes with each phase (PHASE_MUSIC)

## Phases after the second one, in order (highest "at" first). Keys as in BattleRules.BOSSES.phase.
const LATE_PHASES: Dictionary[String, Array] = {
	"ashen_heart": [{"at": 0.25, "stage": {"foc": 1},
		"text": "The Ashen Heart splits open. Its core burns white!"}],
	"drowned_heart": [{"at": 0.25, "stage": {"atk": 1},
		"text": "The Drowned Heart sinks its weight into one last surge!"}],
	"mist_heart": [{"at": 0.25, "stage": {"def": 1},
		"text": "The Mist Heart pulls the fog tight around its core!"}],
}

## Music from each phase on (item 406): phase 2 is the first wake-up, 3 and on the late phases.
## Sound.battle_music picks the era version of each track.
const PHASE_MUSIC: Dictionary[int, String] = {2: "warden", 3: "battle_heart"}

## The field that keeps each boss from changing phase while it lies (the player can call it).
const HOLD_FIELD: Dictionary[String, String] = {
	"ashen_heart": "high_tide",
	"drowned_heart": "static_veil",
	"mist_heart": "dawn_glow",
}

## Weak point after each phase change: these stages for WEAK_TURNS turns, then they are given back.
const WEAK_STAGE: Dictionary[String, int] = {"def": -1}
const WEAK_TURNS: int = 1

## Rage: from turn RAGE_TURN on, every RAGE_EVERY turns, the boss gains RAGE_STAGE.
const RAGE_TURN: int = 15
const RAGE_EVERY: int = 5
const RAGE_STAGE: Dictionary[String, int] = {"atk": 1, "foc": 1}

## Lexicon entry a boss writes down after the first win (items 413, 438).
const LEXICON: Dictionary[String, String] = {
	"ashen_heart": "boss_ashen_heart",
	"drowned_heart": "boss_drowned_heart",
	"mist_heart": "boss_mist_heart",
}

## Every phase after the second one for [param boss_id] (empty when none).
static func late_phases(boss_id: String) -> Array:
	return LATE_PHASES.get(boss_id, [])

## True while [param field] holds [param boss_id] in its current phase.
static func held_by(boss_id: String, field: String) -> bool:
	return not field.is_empty() and str(HOLD_FIELD.get(boss_id, "")) == field

## A timed status on a boss lasts half as long, rounded up; a lasting one (0) stays.
static func status_turns(turns: int) -> int:
	return turns if turns <= 0 else ceili(turns / 2.0)

## A stage drop on a boss is halved, rounded up: -1 stays -1, -2 becomes -1, -3 becomes -2.
static func stage_delta(delta: int) -> int:
	return delta if delta >= 0 else -ceili(-delta / 2.0)

## True when the boss gains its rage stages at the end of [param turn].
static func rage_due(turn: int) -> bool:
	return turn >= RAGE_TURN and (turn - RAGE_TURN) % RAGE_EVERY == 0

## Per-boss statistics in [param records]["boss_stats"] (item 414): wins, fewest turns, last turns.
static func note_win(records: Dictionary, boss_id: String, turns: int) -> Dictionary:
	var all: Dictionary = (records.get("boss_stats", {}) as Dictionary).duplicate(true)
	var s: Dictionary = all.get(boss_id, {"wins": 0, "best_turns": 0, "last_turns": 0})
	s["wins"] = int(s.get("wins", 0)) + 1
	s["last_turns"] = turns
	if int(s.get("best_turns", 0)) <= 0 or turns < int(s.best_turns):
		s["best_turns"] = turns
	all[boss_id] = s
	records["boss_stats"] = all
	return s

## The statistics of [param boss_id], or {}.
static func stats(records: Dictionary, boss_id: String) -> Dictionary:
	return (records.get("boss_stats", {}) as Dictionary).get(boss_id, {})

## The track from phase [param phase] on (the highest PHASE_MUSIC key up to it), or "".
static func phase_music(phase: int) -> String:
	var best: int = -1
	for k: int in PHASE_MUSIC:
		if k <= phase and k > best:
			best = k
	return PHASE_MUSIC.get(best, "")

## Lowest difficulty (BattleModel.boss_difficulty) on which a phase calls its guard: Veteran.
const GUARD_FROM: int = 2

## First foe slot beside the boss whose Spirling has fallen or is gone, or -1 (item 404).
static func guard_slot(model: BattleModel) -> int:
	for slot: int in range(1, model.slot_count(BattleModel.Side.FOE)):
		if not model.is_standing(model.active_spirling(BattleModel.Side.FOE, slot)):
			return slot
	return -1

## A phase's "guard" ({"species", "below": levels under the boss, "from": lowest difficulty,
## Veteran by default}) joins the foe side in a free slot beside the boss. Story and Tamer hearts
## keep their tuned fight (tools/balance/act_route.json measures them on Tamer).
## Returns the new Spirling, or null when no slot is free or the difficulty is too low.
static func call_guard(model: BattleModel, boss: Spirling, guard: Dictionary) -> Spirling:
	var sd: SpirlingData = Database.species(str(guard.get("species", "")))
	var slot: int = guard_slot(model)
	if sd == null or slot < 0 or model.boss_difficulty < int(guard.get("from", GUARD_FROM)):
		return null
	var s := Spirling.new(sd, maxi(1, boss.level - int(guard.get("below", 2))), model.rng)
	model.parties[BattleModel.Side.FOE].append(s)
	model.emit_event(BattleEvent.Type.BOSS_PHASE, {"side": BattleModel.Side.FOE, "slot": 0, "name": boss.display_name(), "boss": model.foe_boss,
		"text": "%s calls %s to its side. Nobody asked the guard." % [boss.display_name(), s.display_name()]})
	model._swap_in(BattleModel.Side.FOE, model.parties[BattleModel.Side.FOE].size() - 1, slot)
	return s

## How a Rift boss's AI plays its phases (item 462), by BossRules.ai_phase:
##   held:  the player's hold field keeps it from its next phase, so an art that lays any other
##          field is worth "field_break" more (it wants to wake up)
##   open:  its weak point lies open; building stages now is wasted ("setup_w" 0)
##   final: every phase is reached, nothing is held back: no stage setup, hits count "damage_w"
const AI_PHASE: Dictionary[String, Dictionary] = {
	"held": {"field_break": 0.6},
	"open": {"setup_w": 0.0},
	"final": {"setup_w": 0.0, "damage_w": 1.3},
}

## The phase mode of the boss in [param side]/[param slot] of [param model] ("" when it is no boss
## or nothing special holds): "open", "held" or "final".
static func ai_phase(model: BattleModel, side: int, slot: int) -> String:
	if not model.is_boss_slot(side, slot):
		return ""
	if model._boss_weak_until >= 0:
		return "open"
	if model.boss_phase_done and model.boss_late_done >= late_phases(model.foe_boss).size():
		return "final"
	if held_by(model.foe_boss, model.field):
		return "held"
	return ""

## The weights of [method ai_phase] for that boss, or {}.
static func ai_tune(model: BattleModel, side: int, slot: int) -> Dictionary:
	return AI_PHASE.get(ai_phase(model, side, slot), {})

## Boss replays (item 440): the replay of the fastest win against each boss is kept in
## records["boss_replays"][boss_id] = {"turns", "replay"}. Returns true when [param snap] was kept.
static func keep_replay(records: Dictionary, boss_id: String, turns: int, snap: Dictionary) -> bool:
	if boss_id.is_empty() or snap.is_empty():
		return false
	var all: Dictionary = (records.get("boss_replays", {}) as Dictionary).duplicate()
	var old: Dictionary = all.get(boss_id, {})
	if not old.is_empty() and int(old.get("turns", 0)) <= turns:
		return false
	all[boss_id] = {"turns": turns, "replay": snap.duplicate(true)}
	records["boss_replays"] = all
	return true

## Kept boss replays as [{"boss", "label", "turns", "replay"}], in BOSSES order.
static func replays(records: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Dictionary = records.get("boss_replays", {})
	for id: String in BattleRules.BOSSES:
		var r: Variant = all.get(id)
		if r is Dictionary and (r as Dictionary).get("replay") is Dictionary:
			out.append({"boss": id, "label": str(BattleRules.BOSSES[id].label), "turns": int(r.get("turns", 0)), "replay": r.replay})
	return out
