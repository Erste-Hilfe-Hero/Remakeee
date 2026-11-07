class_name Tailwind
extends RefCounted
## "Tailwind" (plan area 2, items 737-739): after losing the same Wayfarer battle a few times,
## the game openly offers help before the next try. The player must say yes; it is never used
## quietly, and every use is counted in GameState.records["tailwind_used"].
##   Story   from 2 losses: the team is fully healed and the foe starts with 2 Energy less.
##   Tamer   from 3 losses: only the full heal.
##   Veteran and Rift-Born: never offered.

const LOSSES_NEEDED: Dictionary = {0: 2, 1: 3}
const FOE_ENERGY_CUT: Dictionary = {0: 2, 1: 0}

## True if Tailwind is offered on [param difficulty] after [param losses] lost tries.
static func offered(difficulty: int, losses: int) -> bool:
	return LOSSES_NEEDED.has(difficulty) and losses >= int(LOSSES_NEEDED[difficulty])

## Energy the foe side starts without when Tailwind is taken.
static func energy_cut(difficulty: int) -> int:
	return int(FOE_ENERGY_CUT.get(difficulty, 0))

## Lost tries against the Wayfarer battle [param key] (its beaten flag).
static func losses(records: Dictionary, key: String) -> int:
	return int((records.get("wayfarer_losses", {}) as Dictionary).get(key, 0))

## Counts the battle's outcome: a loss adds one, a win clears the count.
static func note_outcome(records: Dictionary, key: String, won: bool) -> void:
	var all: Dictionary = (records.get("wayfarer_losses", {}) as Dictionary).duplicate()
	if won:
		all.erase(key)
	else:
		all[key] = int(all.get(key, 0)) + 1
	records["wayfarer_losses"] = all

## Counts one use and returns the new total.
static func note_use(records: Dictionary) -> int:
	var n: int = int(records.get("tailwind_used", 0)) + 1
	records["tailwind_used"] = n
	return n

## The question before the battle.
static func question(difficulty: int) -> String:
	if energy_cut(difficulty) > 0:
		return Loc.t("This battle has beaten you a few times. Take Tailwind? Your team is fully healed and the foe starts with %d Energy less.") % energy_cut(difficulty)
	return Loc.t("This battle has beaten you a few times. Take Tailwind? Your team is fully healed.")
