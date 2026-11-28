extends MoveEffect
## {"id": "status_veil", "amount": turns} (KAMPF_PLAN_1000 item 193): a Calm Veil over the
## user's whole side. While it lasts no status from the other side takes hold (5 turns unless
## "effect_amount" says otherwise).

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var turns: int = int(params.get("amount", 0.0))
	ctx.model.set_status_veil(ctx.user_side, turns if turns > 0 else BattleRules.STATUS_VEIL_TURNS)
