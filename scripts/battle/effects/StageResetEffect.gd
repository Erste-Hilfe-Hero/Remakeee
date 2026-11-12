extends MoveEffect
## {"id": "stage_reset"}: every raised or lowered stage on the user and the target goes back to 0.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	for pair: Array in [[ctx.user_side, ctx.user_slot, ctx.user], [ctx.target_side, ctx.target_slot, ctx.target]]:
		var s: Spirling = pair[2]
		if s == null or s.is_fainted():
			continue
		for stat: String in BattleRules.STAGE_STATS:
			if s.stage(stat) != 0:
				ctx.model.change_stage(int(pair[0]), stat, -s.stage(stat), int(pair[1]))
