class_name MoveData
extends Resource
## Static move data loaded from data/moves.json. Never mutated at runtime.

enum Kind { PHYSICAL, FOCUS, STATUS }

@export var move_name: String
@export var element: int
@export var kind: Kind = Kind.PHYSICAL
@export var power: int = 40
@export var accuracy: float = 1.0
@export var energy_cost: int = 2
@export var priority: int = 0
@export var status_effect: String = ""
@export var status_chance: float = 0.0
## Data-driven effects, each {"id": StringName, ...params}. See EffectRegistry.
@export var effects: Array[Dictionary] = []
## Overcharge: spends all leftover Energy after the cost; each point adds power (BattleRules).
@export var overcharge: bool = false
## Who the move reaches: "single" (one foe, picked by the player) or "foes" (every foe on the
## field at once, a sweep). In 1v1 both hit the one foe the same way.
@export var target: String = "single"
## Turns the move stays locked after each use (moves.json "cooldown", 0 = never locked).
@export var cooldown: int = 0
## The user's Daze does not lower this move's accuracy (moves.json "ignore_daze").
@export var ignore_daze: bool = false
## The target's raised Guard and Focus stages do not count against this move ("ignore_stages").
@export var ignore_stages: bool = false

const TARGETS: Array[String] = ["single", "foes"]

## True for moves that sweep every foe on the field.
func is_area() -> bool:
	return target == "foes"

## True if the move deals direct damage.
func is_damaging() -> bool:
	return kind != Kind.STATUS and power > 0
