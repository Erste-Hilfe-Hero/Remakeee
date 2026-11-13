extends MoveEffect
## {"id": "set_field", "field": String}: a Resonance move lays a Rift field (BattleRules.FIELDS)
## for BattleRules.RESONANCE_TURNS turns. Calling the field already in place only renews its turns.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user.is_fainted():
		return
	if ctx.model.field_lock > 0:
		ctx.model.emit_event(BattleEvent.Type.FIELD_EXTENDED, {"failed": true, "locked": true, "label": str(BattleRules.FIELDS.get(ctx.model.field, {}).get("label", ""))})
		return
	# Echo Soul and Lantern Glass hold the field longer (TraitKit).
	ctx.model.set_field(str(params.get("field", "")), TraitKit.field_turns(ctx.user))
