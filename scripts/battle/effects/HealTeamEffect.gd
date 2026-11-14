extends MoveEffect
## {"id": "heal_team", "amount": share}: the user and every standing ally on the field mend that
## share of their max Vigor (KAMPF_PLAN_1000 item 382).

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var share: float = float(params.get("amount", 0.2))
	for slot: int in ctx.model.standing_slots(ctx.user_side):
		var s: Spirling = ctx.model.active_spirling(ctx.user_side, slot)
		if s.hp < s.max_hp():
			ctx.model.heal(ctx.user_side, maxi(1, roundi(s.max_hp() * share)), slot)
