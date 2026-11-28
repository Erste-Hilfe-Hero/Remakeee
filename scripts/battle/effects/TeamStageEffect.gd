extends MoveEffect
## {"id": "team_stage", "stat": "def", "amount": 1} (item 128): every Spirling of the user's side
## on the field raises the stat.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var amount: int = int(params.get("amount", 0.0))
	for slot: int in ctx.model.standing_slots(ctx.user_side):
		ctx.model.change_stage(ctx.user_side, str(params.get("stat", "def")), amount if amount != 0 else 1, slot)
