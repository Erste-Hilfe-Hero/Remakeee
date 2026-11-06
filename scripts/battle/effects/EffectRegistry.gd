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
	&"field_extend": preload("res://scripts/battle/effects/FieldExtendEffect.gd"),
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
