extends MoveEffect
## {"id": "heal_ally", "amount": share}: the standing ally with the lowest Vigor share mends that
## share of its max Vigor; alone on the field the user mends itself (KAMPF_PLAN_1000 item 365).

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var slot: int = MultiRules.weakest_ally(ctx.model, ctx.user_side, ctx.user_slot)
	if slot < 0:
		slot = ctx.user_slot
	var s: Spirling = ctx.model.active_spirling(ctx.user_side, slot)
	if s != null and s.hp < s.max_hp():
		ctx.model.heal(ctx.user_side, maxi(1, roundi(s.max_hp() * float(params.get("amount", 0.33)))), slot)
