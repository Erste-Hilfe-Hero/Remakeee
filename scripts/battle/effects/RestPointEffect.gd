extends MoveEffect
## {"id": "rest_point"} (item 151): heals half of the user's Vigor, then it dozes off (Drowse) for
## one turn. A gift or the Calm rule that keeps it awake lets it keep the heal for free.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	if ctx.user.is_fainted():
		return
	m.heal(ctx.user_side, maxi(1, int(ctx.user.max_hp() * TechniqueRules.REST_POINT_HEAL)), ctx.user_slot)
	if ctx.user.status.is_empty() and m.apply_status(ctx.user_side, "drowse", ctx.user_slot):
		ctx.user.status_turns = 1
