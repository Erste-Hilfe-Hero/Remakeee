extends MoveEffect
## {"id": "stat_change", "stat": "atk"|"def"|"foc"|"spd", "amount": int, "self": bool,
##  "chance": float, "stage_chance": float}
## Raises or lowers a stat stage on the user (self) or the target. With "stage_chance" (moves.json
## key of the same name) a damaging move raises its own stage only on some hits ("stage on hit").

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var chance: float = float(params.get("stage_chance", params.get("chance", 1.0)))
	if chance < 1.0 and ctx.model.rng.randf() >= chance:
		return
	var on_self: bool = bool(params.get("self", true))
	var side: int = ctx.user_side if on_self else ctx.target_side
	var slot: int = ctx.user_slot if on_self else ctx.target_slot
	ctx.model.change_stage(side, str(params.get("stat", "atk")), int(params.get("amount", 1)), slot)
