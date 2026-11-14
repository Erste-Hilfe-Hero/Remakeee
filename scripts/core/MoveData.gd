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
## Grows with the Energy its user has paid for arts this battle (moves.json "spent_scale", EnergyKit).
@export var spent_scale: bool = false
## Who the move reaches: "single" (one foe, picked by the player) or "foes" (every foe on the
## field at once, a sweep). In 1v1 both hit the one foe the same way.
@export var target: String = "single"
## Turns the move stays locked after each use (moves.json "cooldown", 0 = never locked).
@export var cooldown: int = 0
## The user's Daze does not lower this move's accuracy (moves.json "ignore_daze").
@export var ignore_daze: bool = false
## The target's raised Guard and Focus stages do not count against this move ("ignore_stages").
@export var ignore_stages: bool = false
## The era that brings the art into the game (moves.json "era", 1 to 5). Later-era arts sit on
## later-era Spirlings and teachers (docs/CONTENT_GAPS.md).
@export var era: int = 1
## One line of flavour for the art (moves.json "desc", English key for Loc).
@export var description: String = ""
## A neutral art (moves.json "neutral", KAMPF_PLAN_1000 item 89) has no element: x1 into every
## foe, no own-element bonus, and no field, prism or reaction touches it. "element" stays only
## for the look of the hit.
@export var neutral: bool = false

const TARGETS: Array[String] = ["single", "foes"]

## True for moves that sweep every foe on the field.
func is_area() -> bool:
	return target == "foes"

## True if one of the move's effects has [param id] (for example &"delayed_hit").
func has_effect(id: StringName) -> bool:
	for fx: Dictionary in effects:
		if StringName(fx.get("id", "")) == id:
			return true
	return false

## The element name shown on the art, "Neutral" for a neutral art.
func element_label() -> String:
	return "Neutral" if neutral else Elements.element_name(element)

## True if the move deals direct damage.
func is_damaging() -> bool:
	return kind != Kind.STATUS and power > 0
