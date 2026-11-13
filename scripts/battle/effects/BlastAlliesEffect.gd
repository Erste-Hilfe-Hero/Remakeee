extends MoveEffect
## {"id": "blast_allies"} (item 152): a risk art that sweeps the foes and also strikes every ally
## beside the user, once per use.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	var st: Dictionary = TechniqueRules.state(m)
	if int((st.blast as Dictionary).get(ctx.user, -1)) == m.turn or ctx.user.is_fainted():
		return
	st.blast[ctx.user] = m.turn
	for slot: int in m.standing_slots(ctx.user_side):
		var ally: Spirling = m.active_spirling(ctx.user_side, slot)
		if ally == ctx.user:
			continue
		var mult: float = BattleRules.SPREAD_MULT * TechniqueRules.BLAST_ALLY_SHARE * BattleRules.damage_mult(ctx.user, ally, ctx.move, m.field)
		var r: Dictionary = DamageCalc.compute(ctx.user, ally, ctx.move, m.rng, mult)
		m.deal_damage(ctx.user_side, int(r.damage), {"eff": r.eff, "crit": r.crit, "move": ctx.move.move_name}, slot)
