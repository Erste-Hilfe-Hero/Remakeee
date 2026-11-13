extends MoveEffect
## {"id": "clear_field"} (item 136): ends the field in play, a Resonance field or the place's
## own, for the rest of the battle. A locked field (Warden rule) does not give way.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	if m.field.is_empty():
		TechniqueRules.say(m, ctx.user_side, ctx.user_slot, "%s finds no field to end.")
		return
	var label: String = str(BattleRules.FIELDS.get(m.field, {}).get("label", ""))
	if m.field_lock > 0:
		m.emit_event(BattleEvent.Type.FIELD_EXTENDED, {"field": m.field, "label": label, "locked": true})
		return
	var gone: String = m.field
	m.field = ""
	m.field_turns = 0
	m.base_field = ""
	m.emit_event(BattleEvent.Type.FIELD_END, {"field": gone, "label": label})
