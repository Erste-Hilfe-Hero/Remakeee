class_name BossHall
extends RefCounted
## Rift hearts outside the story fight (docs/KAMPF_PLAN_1000.md, area "Bosse und Wardens"):
##   rewards per difficulty (item 415): money factor and items for a story heart win
##   heart echoes (item 417):           every mended heart can be fought again after Act I
##   heart rush (item 418):             every open heart in a row, no rest, best run kept
## Values in data/boss_hall.json; the runs themselves live in BossRunner.gd.

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_hall.json"))
		_data = v if v is Dictionary else {}
	return _data

## The reward row of [param difficulty] (Story 0 to Rift-Born 3), clamped into the table.
static func reward_row(difficulty: int) -> Dictionary:
	var rows: Array = data().get("rewards", [])
	if rows.is_empty():
		return {}
	return GameState.as_dict(rows[clampi(difficulty, 0, rows.size() - 1)])

## Factor on a heart's purse on [param difficulty].
static func money_mult(difficulty: int) -> float:
	return float(reward_row(difficulty).get("money_mult", 1.0))

## [[item_id, count], ...] a story heart win gives on [param difficulty].
static func reward_items(difficulty: int) -> Array:
	return reward_row(difficulty).get("items", [])

static func echoes() -> Array:
	return data().get("echo", [])

## The heart echoes open under [param flags] (GameState.flags): after Act I, each once its Rift
## heart is mended.
static func open_echoes(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not bool(flags.get(GameState.ACT1_END_FLAG, false)):
		return out
	for e: Variant in echoes():
		if e is Dictionary and bool(flags.get(str(e.get("flag", "")), false)):
			out.append(e)
	return out

## The trainer info start_battle takes for [param entry] (a Rift boss with its front and purse;
## the overworld puts money_mult on the purse of every boss).
static func battle_info(entry: Dictionary) -> Dictionary:
	return {"name": Loc.t(str(entry.get("name", ""))), "boss": str(entry.get("boss", "")), "front": entry.get("front", [4, 1]),
		"ai": 3, "money": int(entry.get("money", 0))}

## The heart's team, tuned to [param difficulty] like a Wayfarer team.
static func team(entry: Dictionary, rng: RandomNumberGenerator, difficulty: int) -> Array[Spirling]:
	return TrainerData.build_team(entry, "", rng, difficulty)

static func rush() -> Dictionary:
	return GameState.as_dict(data().get("rush", {}))

## True when enough hearts are open for the rush.
static func rush_open(flags: Dictionary) -> bool:
	return open_echoes(flags).size() >= int(rush().get("min_hearts", 3))

## Books a rush of [param beaten] hearts out of [param total] in [param records]["heart_rush"].
## Returns true for the first full clear (the rush reward is given once).
static func note_rush(records: Dictionary, beaten: int, total: int) -> bool:
	var r: Dictionary = GameState.as_dict(records.get("heart_rush", {})).duplicate()
	r["best"] = maxi(int(r.get("best", 0)), beaten)
	r["runs"] = int(r.get("runs", 0)) + 1
	var first: bool = beaten >= total and total > 0 and int(r.get("clears", 0)) == 0
	if beaten >= total and total > 0:
		r["clears"] = int(r.get("clears", 0)) + 1
	records["heart_rush"] = r
	return first

static func rush_best(records: Dictionary) -> int:
	return int(GameState.as_dict(records.get("heart_rush", {})).get("best", 0))
