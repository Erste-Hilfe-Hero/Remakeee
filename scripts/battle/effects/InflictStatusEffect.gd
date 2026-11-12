extends MoveEffect
## {"id": "inflict_status", "status": String, "chance": float}: may afflict the target.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target.is_fainted():
		return
	var chance: float = float(params.get("chance", 1.0))
	var is_status_move: bool = not ctx.move.is_damaging()
	if chance < 1.0 and ctx.model.rng.randf() >= chance:
		return
	var applied: bool = ctx.model.apply_status(ctx.target_side, str(params.get("status", "")), ctx.target_slot, ctx.user_side)
	if not applied and is_status_move:
		ctx.model.emit_event(BattleEvent.Type.STATUS_FAILED, {"side": ctx.target_side, "slot": ctx.target_slot, "name": ctx.target.display_name()})
