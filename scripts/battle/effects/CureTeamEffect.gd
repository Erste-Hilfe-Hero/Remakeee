extends MoveEffect
## {"id": "cure_team"}: the user and every Spirling of its team shake off their status.
## The ones on the field are cured with a line; the bench is cured quietly.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	for slot: int in ctx.model.slot_count(ctx.user_side):
		var s: Spirling = ctx.model.active_spirling(ctx.user_side, slot)
		if s != null and not s.is_fainted() and not s.status.is_empty():
			ctx.model.cure(ctx.user_side, slot)
	for s: Spirling in ctx.model.party(ctx.user_side):
		if s != null and not s.is_fainted() and not s.status.is_empty():
			s.status = ""
			s.status_turns = 0
