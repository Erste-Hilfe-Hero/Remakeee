extends MoveEffect
## {"id": "energy_swap"}: the user and the target trade their Energy (each up to its own side's
## cap). KAMPF_PLAN item 58.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	if ctx.user == null or ctx.target == null or ctx.user.is_fainted() or ctx.target.is_fainted():
		return
	var mine: int = ctx.user.energy
	var theirs: int = ctx.target.energy
	if mine == theirs:
		return
	ctx.model.change_energy(ctx.user_side, theirs - mine, ctx.user_slot)
	ctx.model.change_energy(ctx.target_side, mine - theirs, ctx.target_slot)
	var d: Dictionary = {"side": ctx.user_side, "slot": ctx.user_slot, "name": ctx.user.display_name(), "other": ctx.target.display_name()}
	ctx.model.emit_event(BattleEvent.Type.ENERGY_SWAPPED, d)
