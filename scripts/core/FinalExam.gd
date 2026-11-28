class_name FinalExam
extends RefCounted
## The Cartographer's exam (plan item 1110): the last battle of the game. Examiner Hollis waits
## in Kestra's map house once every Master Rift is won and fields six of the strongest
## Spirlings at ring 60. The win sets the exam flag and pays Waymarks once.

static func data() -> Dictionary:
	return IdeasC.section("final_exam")

static func flag() -> String:
	return str(data().get("flag", "cartographer_exam"))

static func is_open() -> bool:
	var all: int = WardenRematch.entries().size()
	return all > 0 and MasterRifts.won_count() >= all

static func passed() -> bool:
	return GameState.has_flag(flag())

static func team(rng: RandomNumberGenerator) -> Array[Spirling]:
	return IdeasC.team(data().get("team", []), int(data().get("ring", 60)), rng)

static func lines(key: String) -> Array[String]:
	var v: Variant = data().get(key, [])
	var out: Array[String] = []
	for s: Variant in (v if v is Array else [v]):
		out.append(Loc.t(str(s)))
	return out

## Books the pass. Returns the reward lines (Waymarks only the first time).
static func pass_exam() -> Array[String]:
	var out: Array[String] = lines("win_line")
	if passed():
		return out
	GameState.set_flag(flag())
	out.append_array(Waymarks.reward_lines(Waymarks.earn(int(data().get("waymarks", 0)), "master")))
	return out
