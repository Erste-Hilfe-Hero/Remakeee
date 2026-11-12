class_name MasterRifts
extends RefCounted
## Master Rifts (plan item 1104): every Warden hall again in a hard form once its rematch is won.
## The rematch team fights ring_bonus rings higher under base_rule plus the hall's own rule.
## Won once per Warden (flag "master_rift_<warden>"), the first win pays Waymarks.

static func data() -> Dictionary:
	return IdeasC.section("master_rifts")

static func won_flag(entry: Dictionary) -> String:
	return "master_rift_" + str(entry.get("warden", ""))

static func is_open(entry: Dictionary) -> bool:
	return GameState.has_flag(WardenRematch.won_flag(entry))

## The rematch entries whose Master Rift is open.
static func open_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in WardenRematch.entries():
		if e is Dictionary and is_open(e):
			out.append(e)
	return out

static func won_count() -> int:
	var n: int = 0
	for e: Variant in WardenRematch.entries():
		if e is Dictionary and GameState.has_flag(won_flag(e)):
			n += 1
	return n

## "base+hall" rule string for [param entry].
static func rule(entry: Dictionary) -> String:
	var hall: String = str(GameState.as_dict(data().get("hall_rules", {})).get(str(entry.get("warden", "")), ""))
	var base: String = str(data().get("base_rule", ""))
	return base if hall.is_empty() or hall == base else base + "+" + hall

static func team(entry: Dictionary, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for m: Variant in entry.get("team", []):
		var d: Dictionary = GameState.as_dict(m)
		out.append_array(IdeasC.team([d.get("species", "")], int(d.get("level", 1)) + int(data().get("ring_bonus", 0)), rng))
	return out

static func title(entry: Dictionary) -> String:
	return Loc.t(str(data().get("name", "%s"))) % Loc.t(str(entry.get("name", "")))

## Books a win. Returns the reward lines (Waymarks only the first time).
static func win(entry: Dictionary) -> Array[String]:
	var out: Array[String] = [Loc.t(str(data().get("win_line", "")))]
	if GameState.has_flag(won_flag(entry)):
		return out
	GameState.set_flag(won_flag(entry))
	out.append_array(Waymarks.reward_lines(Waymarks.earn(int(data().get("waymarks", 0)), "master")))
	return out
