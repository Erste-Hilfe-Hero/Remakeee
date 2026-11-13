extends MoveEffect
## {"id": "multi_hit"} (item 135): the art strikes 2 to 4 times. TechniqueRules.hit_mult rolls the
## hits and scales the damage (the art's power is the mean of 3 hits); this says how many.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var hits: int = TechniqueRules.hits_of(ctx.model, ctx.user)
	if hits > 0 and ctx.damage_dealt > 0:
		TechniqueRules.say(ctx.model, ctx.target_side, ctx.target_slot, "%s is struck %d times!", [hits])
