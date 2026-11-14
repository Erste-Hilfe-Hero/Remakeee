extends MoveEffect
## {"id": "bonus_vs_status", "vs_status": String, "vs_mult": float}: the move hits harder
## (power x vs_mult) when the target carries that status. "*" means any status, "stage_down"
## means at least one lowered stat stage. The multiplier itself lives in
## BattleRules.status_bonus, so the damage, the preview and the AI all read the same rule.

func apply(_ctx: EffectContext, _params: Dictionary) -> void:
	pass
