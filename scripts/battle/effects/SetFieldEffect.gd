extends MoveEffect
## {"id": "set_field", "field": String}: a Resonance move lays a Rift field (BattleRules.FIELDS)
## for BattleRules.RESONANCE_TURNS turns. Calling the field already in place only renews its turns.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user.is_fainted():
		return
	ctx.model.set_field(str(params.get("field", "")))
