extends MoveEffect
## {"id": "team_guard" | "decoy" | "cover", "amount": turns (0 = data/multi_rules.json default)}:
## team_guard lowers the damage the user's whole side takes, decoy draws every single-target art of
## the foes onto the user, cover makes the user take the single-target hits meant for its weakest
## ally (KAMPF_PLAN_1000 items 379 to 381). See MultiRules.

## Set by the subclass (TeamGuardEffect, DecoyEffect, CoverEffect).
var kind: String = ""

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var turns: int = int(params.get("amount", 0))
	if turns <= 0:
		turns = MultiRules.support_turns(kind)
	if kind == "cover":
		var ward: int = MultiRules.weakest_ally(ctx.model, ctx.user_side, ctx.user_slot)
		if ward < 0:
			var d: Dictionary = ctx.model._who(ctx.user_side, ctx.user_slot)
			d["kind"] = "no_ally"
			ctx.model.emit_event(BattleEvent.Type.SUPPORT, d)
			return
		MultiRules.raise(ctx.model, ctx.user_side, ctx.user_slot, kind, turns, {"covered": ward})
		return
	MultiRules.raise(ctx.model, ctx.user_side, ctx.user_slot, kind, turns)
