class_name EchoTower
extends RefCounted
## The echo tower as 100 floors (plan items 1101, 1102): the 30 floors of the lighthouse stair
## plus the endless stretch count as one tower. Endless floor k (0-based) is tower floor
## Gauntlet.FLOORS + k + 1; reaching top_floor the first time pays a crown reward once.
## Every warden_every-th tower floor is a Warden echo: the Wardens of data/warden_rematch.json
## take turns, each with the first warden_team Spirlings of its rematch team at the floor's ring.

const TOP_FLAG: String = "echo_tower_top"

static func data() -> Dictionary:
	return IdeasC.section("echo_tower")

static func top_floor() -> int:
	return int(data().get("top_floor", 100))

static func tower_floor(endless_k: int) -> int:
	return Gauntlet.FLOORS + endless_k + 1

static func is_top(floor_no: int) -> bool:
	return floor_no == top_floor()

static func is_warden_floor(floor_no: int) -> bool:
	var every: int = int(data().get("warden_every", 10))
	return floor_no > 0 and every > 0 and floor_no % every == 0

## The rematch entry whose echo guards [param floor_no], or {} when it is no Warden floor.
static func warden_entry(floor_no: int) -> Dictionary:
	var all: Array = WardenRematch.entries()
	if not is_warden_floor(floor_no) or all.is_empty():
		return {}
	return GameState.as_dict(all[(floor_no / int(data().get("warden_every", 10)) - 1) % all.size()])

static func warden_name(floor_no: int) -> String:
	var e: Dictionary = warden_entry(floor_no)
	return Loc.t(str(data().get("warden_name", "%s"))) % Loc.t(str(e.get("name", ""))) if not e.is_empty() else ""

static func warden_team(floor_no: int, ring: int, rng: RandomNumberGenerator) -> Array[Spirling]:
	var names: Array = []
	for m: Variant in warden_entry(floor_no).get("team", []):
		if names.size() < int(data().get("warden_team", 3)):
			names.append(str(GameState.as_dict(m).get("species", "")))
	return IdeasC.team(names, ring, rng)

static func warden_line(floor_no: int) -> String:
	var e: Dictionary = warden_entry(floor_no)
	return Loc.t(str(data().get("warden_line", ""))) % [floor_no, Loc.t(str(e.get("name", "")))] if not e.is_empty() else ""

## Pays the top floor once. Returns the reward lines, or [] when already paid or not the top.
static func pay_top(floor_no: int) -> Array[String]:
	var out: Array[String] = []
	if not is_top(floor_no) or GameState.has_flag(TOP_FLAG):
		return out
	GameState.set_flag(TOP_FLAG)
	out.append(Loc.t(str(data().get("top_line", ""))))
	out.append_array(Waymarks.reward_lines(Waymarks.earn(int(data().get("top_waymarks", 0)), "tower")))
	return out
