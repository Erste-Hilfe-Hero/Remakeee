extends MoveEffect
## {"id": "energy_give", "amount": float}: the user hands up to that much of its own Energy to the
## ally beside it with the least Energy (several Spirlings in front only). KAMPF_PLAN item 57.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user == null or ctx.user.is_fainted():
		return
	var best: int = -1
	for slot: int in ctx.model.standing_slots(ctx.user_side):
		if slot == ctx.user_slot:
			continue
		if best < 0 or ctx.model.active_spirling(ctx.user_side, slot).energy < ctx.model.active_spirling(ctx.user_side, best).energy:
			best = slot
	if best < 0:
		return
	var ally: Spirling = ctx.model.active_spirling(ctx.user_side, best)
	var room: int = ctx.model.max_energy_of(ctx.user_side) - ally.energy
	var given: int = mini(mini(ctx.user.energy, maxi(1, int(params.get("amount", 1.0)))), room)
	if given <= 0:
		return
	ctx.model.change_energy(ctx.user_side, -given, ctx.user_slot)
	ctx.model.change_energy(ctx.user_side, given, best)
	var d: Dictionary = {"side": ctx.user_side, "slot": ctx.user_slot, "name": ctx.user.display_name(), "amount": given, "to": ally.display_name()}
	ctx.model.emit_event(BattleEvent.Type.ENERGY_SHARED, d)
