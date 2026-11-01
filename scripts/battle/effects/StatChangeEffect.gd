extends MoveEffect
## {"id": "stat_change", "stat": "atk"|"def"|"foc"|"spd", "amount": int, "self": bool, "chance": float}
## Raises or lowers a stat stage on the user (self) or the target.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var chance: float = float(params.get("chance", 1.0))
	if chance < 1.0 and ctx.model.rng.randf() >= chance:
		return
	var side: int = ctx.user_side if bool(params.get("self", true)) else ctx.target_side
	ctx.model.change_stage(side, str(params.get("stat", "atk")), int(params.get("amount", 1)))
