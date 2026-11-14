class_name SoftDefeat
extends RefCounted
## Soft Defeat (docs/KAMPF_PLAN_1000.md item 22): an option on Story. After a lost battle the team
## wakes where it fell with part of its Vigor (data/battle_flow.json soft_defeat_share) instead of
## being carried back to the last spring. Off by default; kept with the journey (GameState.flags).

const FLAG: String = "soft_defeat"
const LINE: String = "Everything goes dark... and then, somehow, it doesn't. Your team stirs right where it fell, bruised but breathing."

static func is_on() -> bool:
	return bool(GameState.flags.get(FLAG, false))

static func set_on(on: bool) -> void:
	GameState.flags[FLAG] = on

## Only on Story, and only while the option is on.
static func applies(difficulty: int, on: bool) -> bool:
	return on and difficulty == GameState.Difficulty.STORY

static func share() -> float:
	return clampf(float(BattleOpening.data().get("soft_defeat_share", 0.5)), 0.05, 1.0)

## Wakes every Spirling of [param party]: no status, Vigor at share() of its max (at least 1).
static func wake(party: Array) -> void:
	for s: Variant in party:
		if s is Spirling:
			(s as Spirling).restore()
			(s as Spirling).hp = maxi(1, ceili((s as Spirling).max_hp() * share()))
