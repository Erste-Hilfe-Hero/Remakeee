extends MoveEffect
## {"id": "field_extend", "amount": turns}: the Resonance field in play lasts [amount] turns
## longer (default BattleRules.FIELD_EXTEND_TURNS). A place's own field (it never runs out) or
## no field at all: the art fails with its own line.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user.is_fainted():
		return
	var turns: int = int(params.get("amount", 0))
	ctx.model.extend_field(turns if turns > 0 else BattleRules.FIELD_EXTEND_TURNS)
