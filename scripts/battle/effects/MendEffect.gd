extends MoveEffect
## {"id": "mend", "turns": int} (moves.json "mend"): after the art's own heal the user mends
## 1/BattleRules.MEND_DIV of its max Vigor at the end of each of the next [turns] turns. A heal
## block or the Weary phase stops the mending like any other heal.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user.is_fainted():
		return
	ctx.user.mend_turns = maxi(ctx.user.mend_turns, int(params.get("turns", BattleRules.MEND_TURNS)))
