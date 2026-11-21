class_name Kinship
extends RefCounted
## Kinship (era function "kinship", opens in Era II): a Spirling grows fond of the Wayfarer.
## It rises by "win" for each won battle it fought in and by "step_gain" every "steps" steps in
## the team, and drops by "faint" when it is knocked out. Some lines unfurl through it (unfold
## rule "kinship" in data/spirlings.json). Tuning in data/era_activities.json "kinship". Nothing
## changes before Era II, so the story plays as before.

const FEATURE: String = "kinship"
const STEP_RECORD: String = "kin_steps"

static func data() -> Dictionary:
	return EraActivities.section("kinship")

static func max_value() -> int:
	return int(data().get("max", 100))

static func add(s: Spirling, delta: int) -> void:
	s.kinship = clampi(s.kinship + delta, 0, max_value())

## After a battle: every own Spirling that fought gains on a win, every knocked-out one loses.
static func after_battle(party: Array, fought: Array, won: bool, era: int = -1) -> void:
	if not EraFeatures.is_unlocked(FEATURE, era):
		return
	for s: Spirling in party:
		if s.is_fainted():
			add(s, -int(data().get("faint", 5)))
		elif won and s in fought:
			add(s, int(data().get("win", 2)))

## One step on the road: every "steps" steps the whole team gains "step_gain".
## [param records] holds the step counter. Returns true on a step that gave kinship.
static func on_step(party: Array, records: Dictionary, era: int = -1) -> bool:
	if not EraFeatures.is_unlocked(FEATURE, era):
		return false
	var n: int = int(records.get(STEP_RECORD, 0)) + 1
	var every: int = maxi(1, int(data().get("steps", 128)))
	records[STEP_RECORD] = n % every
	if n < every:
		return false
	for s: Spirling in party:
		if not s.is_fainted():
			add(s, int(data().get("step_gain", 1)))
	return true

## A word for the Team menu, "Kinship: 42/100".
static func label(s: Spirling) -> String:
	return Loc.t("Kinship: %d/%d") % [s.kinship, max_value()]
