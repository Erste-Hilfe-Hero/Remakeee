class_name MoveData
extends Resource
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
