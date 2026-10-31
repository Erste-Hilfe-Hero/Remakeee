class_name EffectContext
extends RefCounted
## Everything a move effect needs. Effects change the battle only through BattleModel helpers,
## so every change is reported as a BattleEvent.

var model: BattleModel
var user_side: int
var target_side: int
var user: Spirling
var target: Spirling
var move: MoveData
## Damage the move dealt this use (0 for status moves or misses).
var damage_dealt: int = 0
