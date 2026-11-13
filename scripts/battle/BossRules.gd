class_name BossRules
extends RefCounted
## Rift boss mechanics of docs/KAMPF_PLAN_1000.md, area "Bosse und Wardens". BattleModel reads
## these tables; the second phase itself stays in BattleRules.BOSSES[id].phase.
##   late phases (item 402):  more phases after the second one, each once, by HP share
##   hold field (item 430):   while this field lies, the boss can't change phase
##   weak point (item 431):   right after a phase change the boss lies open (Guard -1) for one turn
##   rage (item 432):         a fight that drags on makes the boss stronger every few turns
##   status and stages (421, 422): timed statuses on a boss last half as long, stage drops are halved

## Phases after the second one, in order (highest "at" first). Keys as in BattleRules.BOSSES.phase.
const LATE_PHASES: Dictionary[String, Array] = {
	"ashen_heart": [{"at": 0.25, "stage": {"foc": 1},
		"text": "The Ashen Heart splits open. Its core burns white!"}],
	"drowned_heart": [{"at": 0.25, "stage": {"atk": 1},
		"text": "The Drowned Heart sinks its weight into one last surge!"}],
	"mist_heart": [{"at": 0.25, "stage": {"def": 1},
		"text": "The Mist Heart pulls the fog tight around its core!"}],
}

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
