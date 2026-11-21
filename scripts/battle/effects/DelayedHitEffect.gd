extends MoveEffect
## {"id": "delayed_hit", "turns": 2} (moves.json key "delay", plan item 451): the damage is worked
## out when the art is used, with the stats of that moment, and lands [turns] turns later at the end
## of the turn on the Spirling standing in the target's slot then. See BattleModel.queue_delayed_hit.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.held_damage <= 0:
		return
	var turns: int = maxi(1, int(params.get("turns", 2)))
	ctx.model.queue_delayed_hit(ctx.target_side, ctx.target_slot, ctx.held_damage, ctx.held_eff, ctx.move.move_name, turns)
