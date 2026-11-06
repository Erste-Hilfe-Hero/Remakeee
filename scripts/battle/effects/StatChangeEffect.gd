extends MoveEffect
## {"id": "stat_change", "stat": "atk"|"def"|"foc"|"spd", "amount": int, "self": bool,
##  "chance": float, "stage_chance": float, "full_hp_amount": int}
## Raises or lowers a stat stage on the user (self) or the target. With "stage_chance" (moves.json
## key of the same name) a damaging move raises its own stage only on some hits ("stage on hit").
## "full_hp_amount" (moves.json "stages_full_hp"): the stages a self move gives at full Vigor.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var chance: float = float(params.get("stage_chance", params.get("chance", 1.0)))
	if chance < 1.0 and ctx.model.rng.randf() >= chance:
		return
	var on_self: bool = bool(params.get("self", true))
	var side: int = ctx.user_side if on_self else ctx.target_side
	var slot: int = ctx.user_slot if on_self else ctx.target_slot
	var amount: int = int(params.get("amount", 1))
	var full: int = int(params.get("full_hp_amount", 0))
	if on_self and full != 0 and ctx.user.hp >= ctx.user.max_hp():
		amount = full
	ctx.model.change_stage(side, str(params.get("stat", "atk")), amount, slot)
