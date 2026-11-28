extends MoveEffect
## {"id": "force_out"} (item 124): after the hit the target is knocked back to its bench and a
## random bench Spirling steps in. Only in Wayfarer battles, never on a Rift Warden's lead,
## and a Rooted target holds its ground.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	if m.is_wild or not m.is_standing(ctx.target) or ctx.damage_dealt <= 0:
		return
	if ctx.target_side == BattleModel.Side.FOE and not m.foe_boss.is_empty():
		return
	if StatusRules.blocks_swap(ctx.target.status):
		TechniqueRules.say(m, ctx.target_side, ctx.target_slot, "%s is rooted and holds its ground!")
		return
	var c: Array[int] = m.swap_candidates(ctx.target_side, ctx.target_slot)
	if c.is_empty():
		return
	var index: int = c[m.rng.randi_range(0, c.size() - 1)]
	TechniqueRules.say(m, ctx.target_side, ctx.target_slot, "%s is knocked back to its bench!")
	m.emit_event(BattleEvent.Type.SWAP_OUT, m._who(ctx.target_side, ctx.target_slot))
	m._swap_in(ctx.target_side, index, ctx.target_slot)
