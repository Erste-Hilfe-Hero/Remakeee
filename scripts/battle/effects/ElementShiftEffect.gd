extends MoveEffect
## {"id": "element_shift", "element": "TIDE"} (item 86): the target counts as one element for 3
## turns. Without "element" it takes the user's first element.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if not ctx.model.is_standing(ctx.target):
		return
	var e: int = Elements.E.get(str(params.get("element", "")), ctx.user.elements()[0])
	ctx.target.element_shift = e
	# +1 because the end of this very turn already counts one down.
	ctx.target.element_shift_turns = TechniqueRules.SHIFT_TURNS + 1
	TechniqueRules.say(ctx.model, ctx.target_side, ctx.target_slot, "%s turns %s for %d turns!", [Elements.element_name(e), TechniqueRules.SHIFT_TURNS])
