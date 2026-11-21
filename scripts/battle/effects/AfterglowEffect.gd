extends MoveEffect
## {"id": "afterglow"} (item 149): after the hit the target keeps burning: max Vigor / 16 at the
## end of each of the next 3 turns, on whoever stands in its slot then (like a delayed hit).

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	if ctx.damage_dealt <= 0 or not m.is_standing(ctx.target):
		return
	var amount: int = maxi(1, ctx.target.max_hp() / TechniqueRules.AFTERGLOW_DIV)
	for t: int in range(1, TechniqueRules.AFTERGLOW_TURNS + 1):
		m.delayed_hits.append({"side": ctx.target_side, "slot": ctx.target_slot, "amount": amount, "eff": 1.0, "move": ctx.move.move_name, "turns": t})
	TechniqueRules.say(m, ctx.target_side, ctx.target_slot, "%s keeps glowing for %d turns!", [TechniqueRules.AFTERGLOW_TURNS])
