class_name SpirlingData
extends Resource
## Static species data, one .tres per Spirling.
@export var dex_id: int
@export var species_name: String
@export var elements: Array[int] = []
@export var base_hp: int
@export var base_atk: int
@export var base_def: int
@export var base_foc: int
@export var base_spd: int
@export var evolves_to: SpirlingData
@export var evolve_level: int = 0
@export var bond_rate: float = 0.45
@export var learnset: Dictionary = {}  # level -> MoveData
## One sprite set per art era (era1..era4)
@export var sprites: Dictionary = {}
