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

## True if the move deals direct damage.
func is_damaging() -> bool:
	return kind != Kind.STATUS and power > 0
