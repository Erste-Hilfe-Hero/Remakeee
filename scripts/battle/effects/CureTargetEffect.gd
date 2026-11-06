extends MoveEffect
## {"id": "cure_target", "status": String}: after the hit the target loses that status (for
## example an art that jolts a drowsing foe awake). "" cures any status.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target.is_fainted() or ctx.target.status.is_empty():
		return
	var want: String = str(params.get("status", ""))
	if want.is_empty() or want == ctx.target.status:
		ctx.model.cure(ctx.target_side, ctx.target_slot)
