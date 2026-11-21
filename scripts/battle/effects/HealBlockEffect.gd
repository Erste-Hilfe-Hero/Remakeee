extends MoveEffect
## {"id": "heal_block", "amount": turns}: for the next [amount] turns (default 3) the target
## can't heal from arts, its gift, the field or a held keepsake (items from the bag still work).

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target.is_fainted():
		return
	var turns: int = int(params.get("amount", 0))
	ctx.model.apply_heal_block(ctx.target_side, turns if turns > 0 else BattleRules.HEAL_BLOCK_TURNS, ctx.target_slot)
