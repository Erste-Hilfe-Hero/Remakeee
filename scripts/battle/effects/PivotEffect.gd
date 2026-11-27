extends MoveEffect
## {"id": "pivot"} (200 list item 49): after a hit that lands, the user falls back to the bench and
## the teammate with the best matchup steps in (BattleAI.choose_replacement). A Rooted user stays.
## Nothing happens without a teammate who can step in.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	if ctx.damage_dealt <= 0 or not m.is_standing(ctx.user) or m.standing_slots(m.other(ctx.user_side)).is_empty():
		return
	if StatusRules.blocks_swap(ctx.user.status):
		TechniqueRules.say(m, ctx.user_side, ctx.user_slot, "%s is rooted and cannot fall back!")
		return
	if m.swap_candidates(ctx.user_side, ctx.user_slot).is_empty():
		return
	var index: int = BattleAI.new(1).choose_replacement(m, ctx.user_side, ctx.user_slot)
	if index < 0:
		return
	TechniqueRules.say(m, ctx.user_side, ctx.user_slot, "%s falls back to its bench!")
	m.emit_event(BattleEvent.Type.SWAP_OUT, m._who(ctx.user_side, ctx.user_slot))
	m._swap_in(ctx.user_side, index, ctx.user_slot)
