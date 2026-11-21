extends MoveEffect
## {"id": "cure_self"}: after the hit (or the status art) the user shakes off its own status.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	if ctx.user == null or ctx.user.is_fainted() or ctx.user.status.is_empty():
		return
	ctx.model.cure(ctx.user_side, ctx.user_slot)
