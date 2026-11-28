extends MoveEffect
## {"id": "energy_burn", "amount": float}: the target loses that much Energy and nobody gains it
## (energy_drain hands it to the user instead). A Spirling that lost Energy to a burn is safe from
## the next burn for BattleRules.BURN_GUARD_TURNS turns, so a burn can never lock it out for good.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target.is_fainted():
		return
	if ctx.target.burn_guard > 0:
		if not ctx.move.is_damaging():
			ctx.model.emit_event(BattleEvent.Type.STATUS_FAILED, {"side": ctx.target_side, "slot": ctx.target_slot, "name": ctx.target.display_name()})
		return
	var lost: int = mini(ctx.target.energy, int(params.get("amount", 1.0)))
	if lost > 0:
		ctx.model.change_energy(ctx.target_side, -lost, ctx.target_slot)
		# +1 because the end of this very turn already counts one down.
		ctx.target.burn_guard = BattleRules.BURN_GUARD_TURNS + 1
