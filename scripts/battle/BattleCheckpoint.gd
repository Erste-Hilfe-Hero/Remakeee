class_name BattleCheckpoint
extends RefCounted
## Saving around battles (docs/KAMPF_PLAN_1000.md): the boss save point (items 30 and 416) and a
## wild battle picked up after the app was closed (item 31). A battle is decided by its seed, both
## starting teams and the player's inputs (BattleReplay), so an open battle is kept as its replay
## snapshot plus the inputs list, which grows every turn and goes into every save while it runs.

## Key of the open battle in GameState.records.
const OPEN_KEY: String = "open_battle"
## Trainer keys a wild battle may carry and still be picked up. Any other key means a caller waits
## for the result (a fixed meeting, a hall run, an echo duel) and that caller is gone after a restart.
const RESUMABLE_KEYS: Array[String] = ["ambush", "model", "resume"]

# --- Boss save point (30, 416) ------------------------------------------------------------------

## True when the journey is saved right before this battle: a boss or a Warden, never a friendly one.
static func save_point_due(trainer: Dictionary) -> bool:
	if bool(trainer.get("friendly", false)):
		return false
	return not str(trainer.get("boss", "")).is_empty() or bool(trainer.get("warden", false))

static func save_point_line(ok: bool) -> String:
	return Loc.t("Saved before the boss. If it goes badly, at least the paperwork survives.") if ok \
		else Loc.t("Saving before the boss did not work this time.")

# --- Picking a battle up (31) -------------------------------------------------------------------

## True when this battle is kept so it can go on after a restart: wild, no caller waiting for it,
## and not on Rift-Born, where closing the app mid-battle counts as a loss (item 630).
static func resumable(wild: bool, trainer: Dictionary, difficulty: int) -> bool:
	if not wild or difficulty == GameState.Difficulty.RIFT_BORN:
		return false
	for k: Variant in trainer:
		if not str(k) in RESUMABLE_KEYS:
			return false
	return true

## Keeps [param snap] (BattleReplay.snapshot) in [param records] with [param inputs], the battle
## screen's own list, so every turn the player orders is in the next save. The model's growth
## settings that the snapshot leaves out go along, so a picked-up battle grows the team the same.
static func open(records: Dictionary, snap: Dictionary, inputs: Array, model: BattleModel) -> void:
	var d: Dictionary = snap.duplicate()
	d["inputs"] = inputs
	d["extra"] = {"xp_mult": model.xp_mult, "ring_growth": model.ring_scaled_growth,
		"spark": model.battle_spark_chance, "sight": model.sight_mult, "day": model.day_phase}
	records[OPEN_KEY] = d

static func close(records: Dictionary) -> void:
	records.erase(OPEN_KEY)

static func is_open(records: Dictionary) -> bool:
	return records.get(OPEN_KEY) is Dictionary

## Takes the open battle out of [param records]: the record to pick up, or {} when there is none,
## the journey is on Rift-Born, or the battle can no longer be rebuilt.
static func take(records: Dictionary, difficulty: int) -> Dictionary:
	var v: Variant = records.get(OPEN_KEY)
	records.erase(OPEN_KEY)
	if not v is Dictionary or difficulty == GameState.Difficulty.RIFT_BORN:
		return {}
	var d: Dictionary = v
	if not d.get("inputs", []) is Array or not BattleReplay.problem(d).is_empty():
		return {}
	return d

## Rebuilds the battle of [param rec]. [param party] and [param inventory] (the journey's own) get
## their state from before the battle back and become the model's, so the inputs, played again on
## screen, change them exactly as the first time. Null when the battle cannot be rebuilt.
static func restore(rec: Dictionary, party: Array[Spirling], inventory: Dictionary) -> BattleModel:
	var m: BattleModel = BattleReplay.build_model(rec)
	if m == null or not (rec.get("partner", {}) as Dictionary).is_empty():
		return null
	party.assign(m.parties[0])
	m.parties[0] = party
	inventory.clear()
	inventory.merge(m.inventory)
	m.inventory = inventory
	var extra: Dictionary = rec.get("extra", {}) if rec.get("extra", {}) is Dictionary else {}
	m.xp_mult = float(extra.get("xp_mult", 1.0))
	m.ring_scaled_growth = bool(extra.get("ring_growth", false))
	m.battle_spark_chance = float(extra.get("spark", 0.0))
	m.sight_mult = float(extra.get("sight", 1.0))
	m.day_phase = int(extra.get("day", -1))
	return m

static func resume_line() -> String:
	return Loc.t("The wild Spirling is still here. It waited, and it has not forgiven you for leaving.")
