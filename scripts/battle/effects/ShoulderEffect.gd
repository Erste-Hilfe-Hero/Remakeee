extends MoveEffect
## {"id": "shoulder"} (item 148): the user shields the most hurt ally beside it; that ally takes
## half damage for the rest of the turn. Needs an ally on the field.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	var best: int = -1
	var low: float = 2.0
	for slot: int in m.standing_slots(ctx.user_side):
		var s: Spirling = m.active_spirling(ctx.user_side, slot)
		if slot != ctx.user_slot and s.hp_fraction() < low:
			low = s.hp_fraction()
			best = slot
	if best < 0:
		TechniqueRules.say(m, ctx.user_side, ctx.user_slot, "%s has nobody to shield.")
		return
	TechniqueRules.state(m).shoulder[m.active_spirling(ctx.user_side, best)] = m.turn
	TechniqueRules.say(m, ctx.user_side, best, "%s is shielded by an ally this turn!")
