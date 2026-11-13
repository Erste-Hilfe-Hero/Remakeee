extends MoveEffect
## {"id": "stage_swap"} (KAMPF_PLAN_1000 item 225): the user and the target trade all their
## stages. Fails with a line when both carry the same stages.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	if ctx.target.is_fainted():
		return
	var mine: Dictionary[String, int] = ctx.user.stages.duplicate()
	var theirs: Dictionary[String, int] = ctx.target.stages.duplicate()
	var moved: bool = false
	for stat: String in BattleRules.STAGE_STATS:
		var a: int = int(mine.get(stat, 0))
		var b: int = int(theirs.get(stat, 0))
		if a == b:
			continue
		moved = true
		ctx.model.change_stage(ctx.user_side, stat, b - a, ctx.user_slot)
		ctx.model.change_stage(ctx.target_side, stat, a - b, ctx.target_slot)
	if not moved:
		ctx.model.emit_event(BattleEvent.Type.STATUS_FAILED, {"side": ctx.target_side, "slot": ctx.target_slot, "name": ctx.target.display_name()})
