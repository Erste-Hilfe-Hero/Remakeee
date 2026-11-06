extends MoveEffect
## {"id": "status_shift"}: the user hands its own status to the target and is free of it.
## Fails when the user has none, or the target already has one or can't take it.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var st: String = ctx.user.status
	var fail: Dictionary = {"side": ctx.target_side, "slot": ctx.target_slot, "name": ctx.target.display_name()}
	if st.is_empty() or ctx.target.is_fainted() or not ctx.target.status.is_empty():
		ctx.model.emit_event(BattleEvent.Type.STATUS_FAILED, fail)
		return
	# apply_status reports its own failure (immunity, field, Calm rule).
	if ctx.model.apply_status(ctx.target_side, st, ctx.target_slot):
		ctx.model.cure(ctx.user_side, ctx.user_slot)
