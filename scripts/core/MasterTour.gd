class_name MasterTour
extends RefCounted
## Master tour (plan item 1105): all twelve Wardens back to back without healing, each with the
## first team_size Spirlings of its rematch team. Opens once every rematch is won. The best
## run (Wardens beaten in one go) lives in records; the first full clear pays Waymarks.

const BEST_KEY: String = "master_tour_best"
const CLEAR_FLAG: String = "master_tour_clear"

static func data() -> Dictionary:
	return IdeasC.section("master_tour")

static func steps() -> int:
	return WardenRematch.entries().size()

static func is_open() -> bool:
	if steps() == 0:
		return false
	for e: Variant in WardenRematch.entries():
		if not GameState.has_flag(WardenRematch.won_flag(GameState.as_dict(e))):
			return false
	return true

static func entry(step: int) -> Dictionary:
	return GameState.as_dict(WardenRematch.entries()[step]) if step >= 0 and step < steps() else {}

static func team(step: int, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for m: Variant in entry(step).get("team", []):
		if out.size() >= int(data().get("team_size", 3)):
			break
		var d: Dictionary = GameState.as_dict(m)
		out.append_array(IdeasC.team([d.get("species", "")], int(d.get("level", 1)), rng))
	return out

static func best() -> int:
	return int(GameState.records.get(BEST_KEY, 0))

## Books a run that beat [param beaten] Wardens. Returns the reward lines.
static func finish(beaten: int) -> Array[String]:
	var out: Array[String] = []
	GameState.records[BEST_KEY] = maxi(best(), clampi(beaten, 0, steps()))
	if beaten >= steps() and steps() > 0 and not GameState.has_flag(CLEAR_FLAG):
		GameState.set_flag(CLEAR_FLAG)
		out.append(Loc.t(str(data().get("clear_line", ""))))
		out.append_array(Waymarks.reward_lines(Waymarks.earn(int(data().get("waymarks", 0)), "master")))
	return out
