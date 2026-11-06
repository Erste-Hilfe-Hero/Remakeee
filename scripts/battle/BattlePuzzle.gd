class_name BattlePuzzle
extends RefCounted
## Puzzle battles ("Trials", plan area 2, items 696 to 700): a fixed position from data/puzzles.json
## with a goal and a turn limit. Both sides, the field, the Warden rule, the seed and the foe's AI
## are fixed, so every line of play always ends the same way. Trials give no rings, no growth and
## change nothing about the team.

const PATH: String = "res://data/puzzles.json"
## Goal types a puzzle can ask for.
const GOALS: Array[String] = ["win_within"]

static var _cache: Array = []

## Every puzzle definition (cached).
static func all() -> Array:
	if _cache.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if raw is Array:
			_cache = raw
	return _cache

static func by_id(id: String) -> Dictionary:
	for p: Dictionary in all():
		if str(p.get("id", "")) == id:
			return p
	return {}

## The puzzles a Warden offers at its Rift once beaten (item 697), in file order.
static func for_warden(warden: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in all():
		if str(p.get("warden", "")) == warden:
			out.append(p)
	return out

## One fixed Spirling: {"species", "level", "moves", "hp" (share of max Vigor), "energy", "status"}.
static func _spirling(e: Dictionary, rng: RandomNumberGenerator) -> Spirling:
	var sd: SpirlingData = Database.species(str(e.get("species", "")))
	if sd == null:
		return null
	var s := Spirling.new(sd, int(e.get("level", 1)), rng)
	# Fixed sparks: a puzzle must not depend on the roll of the Spirling.
	for key: String in Spirling.STAT_KEYS:
		s.spark[key] = 8
	var names: Array = e.get("moves", [])
	if not names.is_empty():
		s.moves.clear()
		for n: Variant in names:
			var mv: MoveData = Database.move(str(n))
			if mv != null:
				s.moves.append(mv)
	s.hp = maxi(1, roundi(s.max_hp() * float(e.get("hp", 1.0))))
	s.status = str(e.get("status", ""))
	if not s.status.is_empty():
		s.status_turns = int(e.get("status_turns", 3))
	return s

static func _team(list: Array, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for e: Dictionary in list:
		var s: Spirling = _spirling(e, rng)
		if s != null:
			out.append(s)
	return out

## A started model for [param p], energy and statuses as the puzzle sets them.
static func build_model(p: Dictionary) -> BattleModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var mine: Array[Spirling] = _team(p.get("player", []), rng)
	var foes: Array[Spirling] = _team(p.get("foe", []), rng)
	var m := BattleModel.new(mine, foes, false, int(p.get("seed", 1)), int(p.get("ai", 1)))
	m.items_allowed = false
	m.field = str(p.get("field", ""))
	m.foe_rule = str(p.get("rule", ""))
	m.trainer_name = str(p.get("name", ""))
	m.start()
	for side: int in 2:
		var list: Array = p.get("player" if side == 0 else "foe", [])
		var team: Array[Spirling] = m.party(side)
		for i: int in mini(list.size(), team.size()):
			var e: Dictionary = list[i]
			if e.has("energy"):
				team[i].energy = int(e.energy)
			if e.has("status"):
				team[i].status = str(e.status)
	return m

## Tracks one attempt: turns played and reactions the player set off (by element).
class Attempt:
	var model: BattleModel
	var reactions: Dictionary = {}
	var _first_turn: int = 0

	func _init(m: BattleModel) -> void:
		model = m
		_first_turn = m.turn
		m.event_emitted.connect(_on_event)

	## Turns played so far (works the same when the battle screen drives the model).
	func turns() -> int:
		return model.turn - _first_turn

	func _on_event(e: BattleEvent) -> void:
		if e.type == BattleEvent.Type.REACTION and int(e.data.get("side", 0)) == BattleModel.Side.FOE:
			var el: int = int(e.data.get("element", -1))
			reactions[el] = int(reactions.get(el, 0)) + 1

static func start(p: Dictionary) -> Attempt:
	return Attempt.new(build_model(p))

## Plays one player action (a switch when one is due). Returns false once the attempt is over.
static func play(p: Dictionary, at: Attempt, a: BattleAction) -> bool:
	if is_over(p, at):
		return false
	if at.model.needs_player_switch():
		at.model.submit_switch(a.swap_index)
	else:
		at.model.submit_turn(a)
	return not is_over(p, at)

static func is_over(p: Dictionary, at: Attempt) -> bool:
	return at.model.is_finished() or at.turns() >= int(p.get("max_turns", 3))

## True once the attempt meets the goal of [param p].
static func solved(p: Dictionary, at: Attempt) -> bool:
	var goal: Dictionary = p.get("goal", {})
	if at.model.outcome != BattleModel.Outcome.WIN:
		return false
	match str(goal.get("type", "win_within")):
		"win_within":
			if at.turns() > int(goal.get("value", p.get("max_turns", 3))):
				return false
	var need: String = str(goal.get("reaction", ""))
	return need.is_empty() or int(at.reactions.get(int(Elements.E.get(need, -1)), 0)) > 0

## The player's choices in the current position (switches when one is due).
static func choices(at: Attempt) -> Array[BattleAction]:
	if at.model.needs_player_switch():
		var out: Array[BattleAction] = []
		for i: int in at.model.swap_candidates(BattleModel.Side.PLAYER, at.model.switch_slot()):
			out.append(BattleAction.make_swap(BattleModel.Side.PLAYER, i))
		return out
	return at.model.legal_actions(BattleModel.Side.PLAYER)

## Exhaustive search (item 700): plays every line of player choices to the end and returns
## {"lines": leaves, "wins": winning leaves, "share": winning share weighted by branching,
##  "solution": one winning line as a list of action dicts}.
static func search(p: Dictionary) -> Dictionary:
	var out: Dictionary = {"lines": 0, "wins": 0, "share": 0.0, "solution": []}
	_walk(p, [] as Array[BattleAction], 1.0, out)
	return out

static func _replay(p: Dictionary, line: Array[BattleAction]) -> Attempt:
	var at: Attempt = start(p)
	for a: BattleAction in line:
		play(p, at, a)
	return at

static func _walk(p: Dictionary, line: Array[BattleAction], weight: float, out: Dictionary) -> void:
	var at: Attempt = _replay(p, line)
	if is_over(p, at):
		out.lines += 1
		if solved(p, at):
			out.wins += 1
			out.share = float(out.share) + weight
			if (out.solution as Array).is_empty():
				for a: BattleAction in line:
					out.solution.append(BattleReplay.action_to_dict(a))
		return
	var opts: Array[BattleAction] = choices(at)
	for a: BattleAction in opts:
		var next: Array[BattleAction] = line.duplicate()
		next.append(a)
		_walk(p, next, weight / float(opts.size()), out)
