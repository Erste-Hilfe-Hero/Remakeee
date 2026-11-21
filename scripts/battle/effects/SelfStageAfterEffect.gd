extends MoveEffect
## {"id": "self_stage_after", "stages": {"foc": -1, ...}}: after the hit the user's own stages
## move by these amounts, even when the target dropped from it (a strong hit that costs focus).

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var st: Variant = params.get("stages", {})
	if not st is Dictionary:
		return
	for stat: String in st:
		ctx.model.change_stage(ctx.user_side, stat, int(st[stat]), ctx.user_slot)
