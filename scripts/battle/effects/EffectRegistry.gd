class_name EffectRegistry
extends RefCounted
## Maps effect ids from moves.json to effect scripts. Add a new effect by writing a
## MoveEffect subclass and registering it here.

const SCRIPTS: Dictionary[StringName, Script] = {
	&"inflict_status": preload("res://scripts/battle/effects/InflictStatusEffect.gd"),
	&"drain": preload("res://scripts/battle/effects/DrainEffect.gd"),
	&"recoil": preload("res://scripts/battle/effects/RecoilEffect.gd"),
	&"heal_self": preload("res://scripts/battle/effects/HealSelfEffect.gd"),
	&"energy_drain": preload("res://scripts/battle/effects/EnergyDrainEffect.gd"),
	&"stat_change": preload("res://scripts/battle/effects/StatChangeEffect.gd"),
	&"set_field": preload("res://scripts/battle/effects/SetFieldEffect.gd"),
	&"bonus_vs_status": preload("res://scripts/battle/effects/BonusVsStatusEffect.gd"),
	&"energy_tax": preload("res://scripts/battle/effects/EnergyTaxEffect.gd"),
	&"field_element": preload("res://scripts/battle/effects/FieldElementEffect.gd"),
	&"self_stage_after": preload("res://scripts/battle/effects/SelfStageAfterEffect.gd"),
	&"stage_on_hit": preload("res://scripts/battle/effects/StatChangeEffect.gd"),
	&"cure_self": preload("res://scripts/battle/effects/CureSelfEffect.gd"),
	&"status_shift": preload("res://scripts/battle/effects/StatusShiftEffect.gd"),
	&"side_snare": preload("res://scripts/battle/effects/SideSnareEffect.gd"),
	&"clear_snares": preload("res://scripts/battle/effects/ClearSnaresEffect.gd"),
	&"energy_burn": preload("res://scripts/battle/effects/EnergyBurnEffect.gd"),
	&"heal_block": preload("res://scripts/battle/effects/HealBlockEffect.gd"),
	&"cure_target": preload("res://scripts/battle/effects/CureTargetEffect.gd"),
	&"stage_steal": preload("res://scripts/battle/effects/StageStealEffect.gd"),
	&"delayed_hit": preload("res://scripts/battle/effects/DelayedHitEffect.gd"),
	&"mend": preload("res://scripts/battle/effects/MendEffect.gd"),
	&"field_extend": preload("res://scripts/battle/effects/FieldExtendEffect.gd"),
	&"energy_gain": preload("res://scripts/battle/effects/EnergyGainEffect.gd"),
	&"stage_reset": preload("res://scripts/battle/effects/StageResetEffect.gd"),
	&"cure_team": preload("res://scripts/battle/effects/CureTeamEffect.gd"),
	&"self_cost": preload("res://scripts/battle/effects/SelfCostEffect.gd"),
	&"stage_copy": preload("res://scripts/battle/effects/StageCopyEffect.gd"),
	&"stage_swap": preload("res://scripts/battle/effects/StageSwapEffect.gd"),
	&"status_veil": preload("res://scripts/battle/effects/StatusVeilEffect.gd"),
	# KAMPF_PLAN_1000, "Elemente und Matchups" and "Techniken" (TechniqueRules).
	&"brace": preload("res://scripts/battle/effects/BraceEffect.gd"),
	&"force_out": preload("res://scripts/battle/effects/ForceOutEffect.gd"),
	&"counter": preload("res://scripts/battle/effects/CounterEffect.gd"),
	&"heal_ally": preload("res://scripts/battle/effects/HealAllyEffect.gd"),
	&"team_stage": preload("res://scripts/battle/effects/TeamStageEffect.gd"),
	&"clear_drops": preload("res://scripts/battle/effects/ClearDropsEffect.gd"),
	&"build_up": preload("res://scripts/battle/effects/PassiveEffect.gd"),
	&"payback": preload("res://scripts/battle/effects/PassiveEffect.gd"),
	&"first_strike": preload("res://scripts/battle/effects/PassiveEffect.gd"),
	&"multi_hit": preload("res://scripts/battle/effects/MultiHitEffect.gd"),
	&"clear_field": preload("res://scripts/battle/effects/ClearFieldEffect.gd"),
	&"lure": preload("res://scripts/battle/effects/LureEffect.gd"),
	&"shoulder": preload("res://scripts/battle/effects/ShoulderEffect.gd"),
	&"afterglow": preload("res://scripts/battle/effects/AfterglowEffect.gd"),
	&"mirror_stage": preload("res://scripts/battle/effects/MirrorStageEffect.gd"),
	&"rest_point": preload("res://scripts/battle/effects/RestPointEffect.gd"),
	&"blast_allies": preload("res://scripts/battle/effects/BlastAlliesEffect.gd"),
	&"element_shift": preload("res://scripts/battle/effects/ElementShiftEffect.gd"),
	&"elem_ward": preload("res://scripts/battle/effects/ElementWardEffect.gd"),
}

static var _cache: Dictionary[StringName, MoveEffect] = {}

static func has_effect(id: StringName) -> bool:
	return SCRIPTS.has(id)

static func get_effect(id: StringName) -> MoveEffect:
	if not _cache.has(id):
		if not SCRIPTS.has(id):
			push_error("EffectRegistry: unknown effect '%s'" % id)
			return null
		_cache[id] = SCRIPTS[id].new()
	return _cache[id]
