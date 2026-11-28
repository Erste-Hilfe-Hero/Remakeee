extends MoveEffect
## {"id": "field_element", "power_bonus": int}: while a Rift field is active, the move takes the
## element that field boosts and gains power_bonus power (BattleRules.resolve_move does the
## swap before the hit). Without a field it keeps its own element.

func apply(_ctx: EffectContext, _params: Dictionary) -> void:
	pass
