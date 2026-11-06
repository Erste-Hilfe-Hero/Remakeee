extends MoveEffect
## {"id": "clear_snares"}: blows every snare off the user's own side.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	ctx.model.clear_snares(ctx.user_side)
