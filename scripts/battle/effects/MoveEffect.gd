class_name MoveEffect
extends RefCounted
## Base class for data-driven move effects. A move's "effect" id in moves.json maps to a
## subclass through EffectRegistry. Override apply().

## Applies the effect. [param params] is the effect entry from MoveData.effects.
func apply(_ctx: EffectContext, _params: Dictionary) -> void:
	pass
