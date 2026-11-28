extends MoveEffect
## {"id": "reset_target"} (KAMPF_PLAN_1000 item 130): every raised or lowered stage of the target
## goes back to 0; the user keeps its own.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	if ctx.target == null or ctx.target.is_fainted():
		return
	for stat: String in BattleRules.STAGE_STATS:
		if ctx.target.stage(stat) != 0:
			ctx.model.change_stage(ctx.target_side, stat, -ctx.target.stage(stat), ctx.target_slot)
