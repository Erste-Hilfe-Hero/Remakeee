extends MoveEffect
## {"id": "heal_ally", "amount": 0.4} (item 127): heals the most hurt ally beside the user by
## amount x its max Vigor. With no ally on the field it heals the user.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var m: BattleModel = ctx.model
	var best: int = -1
	var low: float = 2.0
	for slot: int in m.standing_slots(ctx.user_side):
		var s: Spirling = m.active_spirling(ctx.user_side, slot)
		if slot != ctx.user_slot and s.hp_fraction() < low:
			low = s.hp_fraction()
			best = slot
	if best < 0:
		best = ctx.user_slot
	var who: Spirling = m.active_spirling(ctx.user_side, best)
	if who == null or who.is_fainted():
		return
	var share: float = float(params.get("amount", 0.0))
	m.heal(ctx.user_side, maxi(1, int(who.max_hp() * (share if share > 0.0 else 0.4))), best)
