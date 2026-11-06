class_name Vows
extends RefCounted
## Vows (plan area 8, items 3406-3409): small optional promises for a run, taken before the
## first Rift is mended and kept until the end of Act I (GameState.ACT1_END_FLAG). Each kept vow
## pays KEPT_WAYMARKS once. A vow can be given up at any time; that only loses the bonus. They
## change no battle rule, so they never double the challenge rules of the battle plan.
## State: GameState.records["vows"] = {id: "active" | "broken" | "given_up" | "kept"}.

const DATA_PATH: String = "res://data/endgame.json"
const KEPT_WAYMARKS: int = 100

static var _list: Array[Dictionary] = []

static func list() -> Array[Dictionary]:
	if _list.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for v: Variant in (d as Dictionary).get("vows", []):
					if v is Dictionary:
						_list.append(v)
	return _list

static func find(id: String) -> Dictionary:
	for v: Dictionary in list():
		if str(v.id) == id:
			return v
	return {}

static func _state() -> Dictionary:
	var st: Variant = GameState.records.get("vows", {})
	return st if st is Dictionary else {}

static func status(id: String) -> String:
	return str(_state().get(id, ""))

static func is_active(id: String) -> bool:
	return status(id) == "active"

## Vows can be taken while no Rift is mended yet.
static func can_take() -> bool:
	return GameState.rifts_sealed.is_empty() and not GameState.has_flag(GameState.ACT1_END_FLAG)

static func _put(id: String, value: String) -> void:
	var st: Dictionary = _state().duplicate()
	st[id] = value
	GameState.records["vows"] = st

static func take(id: String) -> bool:
	if find(id).is_empty() or not can_take() or status(id) != "":
		return false
	_put(id, "active")
	return true

static func give_up(id: String) -> bool:
	if not is_active(id):
		return false
	_put(id, "given_up")
	return true

## Marks vow [param id] as broken if it is active (shop, keepsake and storage hooks).
static func broke(id: String) -> void:
	if is_active(id):
		_put(id, "broken")

## The first partner's line (starter and every form it unfolds into).
static func starter_line() -> Array[String]:
	var line: Array[String] = []
	var sd: SpirlingData = Database.species(GameState.starter) if GameState.starter != "" else null
	while sd != null and not sd.species_name in line:
		line.append(sd.species_name)
		sd = sd.evolves_to
	return line

## Checks "starter_stays" after the team changed.
static func check_team() -> void:
	var line: Array[String] = starter_line()
	if line.is_empty():
		return
	if not GameState.party.any(func(s: Spirling) -> bool: return s.data.species_name in line):
		broke("starter_stays")

## At the end of Act I every active vow is kept and pays. Returns the reward lines.
static func settle() -> Array[String]:
	var lines: Array[String] = []
	if not GameState.has_flag(GameState.ACT1_END_FLAG):
		return lines
	for v: Dictionary in list():
		if is_active(str(v.id)):
			_put(str(v.id), "kept")
			lines.append(Loc.t("Vow kept: %s") % Loc.t(str(v.name)))
			lines.append_array(Waymarks.reward_lines(Waymarks.earn(KEPT_WAYMARKS, "vow")))
	return lines

## Menu lines: name and state.
static func lines() -> Array[String]:
	var names: Dictionary = {"": "not taken", "active": "active", "broken": "broken", "given_up": "given up", "kept": "kept"}
	var out: Array[String] = []
	for v: Dictionary in list():
		out.append("%s: %s" % [Loc.t(str(v.name)), Loc.t(str(names.get(status(str(v.id)), "")))])
	return out
