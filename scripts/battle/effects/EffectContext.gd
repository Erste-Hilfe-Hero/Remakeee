class_name EffectContext
extends RefCounted
## Everything a move effect needs. Effects change the battle only through BattleModel helpers,
## so every change is reported as a BattleEvent.

var model: BattleModel
var user_side: int
var target_side: int
## Field slots of the user and the target (0 in 1v1).
var user_slot: int = 0
var target_slot: int = 0
var user: Spirling
var target: Spirling
var move: MoveData
## Damage the move dealt this use (0 for status moves or misses).
var damage_dealt: int = 0
## A delayed hit (delayed_hit effect): the damage worked out now, dealt later, and its element factor.
var held_damage: int = 0
var held_eff: float = 1.0
