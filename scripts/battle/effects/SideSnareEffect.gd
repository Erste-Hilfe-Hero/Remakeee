extends MoveEffect
## {"id": "side_snare", "snare": {"hp": 0.1} | {"status": "root"} | {"stage": {"spd": -1}}}:
## lays a snare on the target's side. The next Spirling that swaps in there springs it (a share of
## its max Vigor, a status or a stage), then the snare is gone. See BattleModel.lay_snare.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var snare: Variant = params.get("snare", {})
	if snare is Dictionary:
		ctx.model.lay_snare(ctx.target_side, snare, ctx.move.move_name)
