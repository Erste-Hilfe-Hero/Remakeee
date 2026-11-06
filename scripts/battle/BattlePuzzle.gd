class_name BattlePuzzle
extends RefCounted
## Puzzle battles ("Trials", plan area 2, items 696 to 700): a fixed position from data/puzzles.json
## with a goal and a turn limit. Both sides, the field, the Warden rule, the seed and the foe's AI
## are fixed, so every line of play always ends the same way. Trials give no rings, no growth and
## change nothing about the team.

const PATH: String = "res://data/puzzles.json"
## Goal types a puzzle can ask for (item 705). "goal" is one {"type", "value"} or a list of up to
## MAX_GOALS of them; every goal needs the win as well.
##   win_within N     win within N turns        no_faint          no own Spirling drops
##   exact_rests N    rest exactly N times      keep_status S     status S is never cured
##   use_reaction E   set off a reaction of element E           last_hit_with A   the last own art is A
const GOALS: Array[String] = ["win_within", "no_faint", "exact_rests", "keep_status", "use_reaction", "last_hit_with"]
const MAX_GOALS: int = 2

## The goals of [param p] as a list (a single goal dict counts as one).
static func goals(p: Dictionary) -> Array[Dictionary]:
	var g: Variant = p.get("goal", {})
	var out: Array[Dictionary] = []
	if g is Dictionary:
		out.append(g)
	elif g is Array:
		for v: Variant in g:
			if v is Dictionary:
				out.append(v)
	return out

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
	# Tag Trials (item 704): "front" [player, foe] and an ally {"name", "team", "front", "ai"} the AI plays.
	var front: Array = p.get("front", [1, 1])
	if front.size() == 2:
		m.front_size = [clampi(int(front[0]), 1, BattleRules.MAX_FRONT), clampi(int(front[1]), 1, BattleRules.MAX_FRONT)]
	var ally: Dictionary = p.get("partner", {})
	if not ally.is_empty():
		m.set_partner(str(ally.get("name", "")), _team(ally.get("team", []), rng), int(ally.get("front", 1)), int(ally.get("ai", 1)), str(ally.get("profile", "")))
	# The battle screen plays these instead of starting the model again, which would reset the
	# Energy the puzzle sets (item 708). The metas also drive the banner and the turn limit (711).
	m.set_meta("intro", m.start())
	m.set_meta("puzzle_max", int(p.get("max_turns", 3)))
	m.set_meta("puzzle_first", m.turn)
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
	var rests: int = 0
	var own_faints: int = 0
	var last_move: String = ""
	## Statuses taken off the player's Spirlings during the attempt.
	var cured: Array[String] = []
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
		var mine: bool = int(e.data.get("side", -1)) == BattleModel.Side.PLAYER
		if mine and e.type == BattleEvent.Type.REST:
			rests += 1
		elif mine and e.type == BattleEvent.Type.FAINTED:
			own_faints += 1
		elif mine and e.type == BattleEvent.Type.MOVE_USED:
			last_move = str(e.data.get("move", ""))
		elif mine and e.type == BattleEvent.Type.STATUS_CURED:
			cured.append(str(e.data.get("status", "")))

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
	if at.model.is_finished() or at.turns() >= int(p.get("max_turns", 3)):
		return true
	# With an ally the player can be left with nothing to choose; the Trial ends there.
	return not at.model.needs_player_switch() and at.model.player_slots().is_empty()

## True once the attempt meets the goal of [param p].
static func solved(p: Dictionary, at: Attempt) -> bool:
	if at.model.outcome != BattleModel.Outcome.WIN:
		return false
	for goal: Dictionary in goals(p):
		if not goal_met(p, goal, at):
			return false
	return true

## True if [param at] meets one [param goal] (the win itself is checked by solved()).
static func goal_met(p: Dictionary, goal: Dictionary, at: Attempt) -> bool:
	var v: Variant = goal.get("value")
	# The older form names the reaction beside a win_within goal.
	var need: String = str(goal.get("reaction", ""))
	if not need.is_empty() and int(at.reactions.get(int(Elements.E.get(need, -1)), 0)) <= 0:
		return false
	match str(goal.get("type", "win_within")):
		"win_within":
			return at.turns() <= int(goal.get("value", p.get("max_turns", 3)))
		"no_faint":
			return at.own_faints == 0
		"exact_rests":
			return at.rests == int(v)
		"keep_status":
			return not str(v) in at.cured
		"use_reaction":
			return int(at.reactions.get(int(Elements.E.get(str(v), -1)), 0)) > 0
		"last_hit_with":
			return at.last_move == str(v)
	return false

## Lantern rating of an attempt (item 706): 0 lost, 1 won, 2 goal met, 3 goal met in the fewest
## turns the solver found ("best_turns" in the puzzle, checked by test_puzzles).
const MAX_LANTERNS: int = 3

static func lanterns(p: Dictionary, at: Attempt) -> int:
	if at.model.outcome != BattleModel.Outcome.WIN:
		return 0
	if not solved(p, at):
		return 1
	var best: int = int(p.get("best_turns", 0))
	return MAX_LANTERNS if best > 0 and at.turns() <= best else 2

## The player's choices in the current position (switches when one is due).
static func choices(at: Attempt) -> Array[BattleAction]:
	if at.model.needs_player_switch():
		var out: Array[BattleAction] = []
		for i: int in at.model.swap_candidates(BattleModel.Side.PLAYER, at.model.switch_slot()):
			out.append(BattleAction.make_swap(BattleModel.Side.PLAYER, i))
		return out
	var m: BattleModel = at.model
	var acts: Array[BattleAction] = []
	var foes: Array[int] = m.standing_slots(BattleModel.Side.FOE)
	for slot: int in m.player_slots().slice(0, 1):
		for a: BattleAction in m.legal_actions(BattleModel.Side.PLAYER, slot):
			var mv: MoveData = m.active_spirling(BattleModel.Side.PLAYER, slot).moves[a.move_index] if a.kind == BattleAction.Kind.MOVE else null
			# Against several foes a single-target art is one choice per foe (item 704).
			if mv != null and foes.size() > 1 and not mv.is_area() and (mv.is_damaging() or not mv.status_effect.is_empty()):
				for t: int in foes:
					acts.append(BattleAction.make_move(BattleModel.Side.PLAYER, a.move_index, slot, t))
			else:
				acts.append(a)
	return acts

## Exhaustive search (item 700): plays every line of player choices to the end and returns
## {"lines": leaves, "wins": winning leaves, "share": winning share weighted by branching,
##  "solution": one winning line as a list of action dicts, "best_turns": fewest turns of a win}.
static func search(p: Dictionary) -> Dictionary:
	var out: Dictionary = {"lines": 0, "wins": 0, "share": 0.0, "solution": [], "best_turns": 0}
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
			if int(out.best_turns) == 0 or at.turns() < int(out.best_turns):
				out.best_turns = at.turns()
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

## Turns left for a puzzle model (item 711), or -1 for any other battle.
static func turns_left(m: BattleModel) -> int:
	if not m.has_meta("puzzle_max"):
		return -1
	return maxi(0, int(m.get_meta("puzzle_max")) - (m.turn - int(m.get_meta("puzzle_first", 0))))

## True once a puzzle model has used up its turns; the battle screen stops there.
static func out_of_turns(m: BattleModel) -> bool:
	return turns_left(m) == 0

## The goal as a sentence (item 711), translated: each goal of [param p] in turn.
static func goal_text(p: Dictionary) -> String:
	var parts: Array[String] = []
	for goal: Dictionary in goals(p):
		var v: Variant = goal.get("value")
		match str(goal.get("type", "win_within")):
			"win_within":
				parts.append(Loc.t("Win within %d turns.") % int(goal.get("value", p.get("max_turns", 3))))
			"no_faint":
				parts.append(Loc.t("Win without losing a Spirling."))
			"exact_rests":
				parts.append(Loc.t("Rest exactly %d times.") % int(v) if int(v) != 1 else Loc.t("Rest exactly once."))
			"keep_status":
				parts.append(Loc.t("Never cure the %s.") % Loc.t(str(v).capitalize()))
			"use_reaction":
				parts.append(Loc.t("Set off a %s reaction.") % Loc.t(str(v).capitalize()))
			"last_hit_with":
				parts.append(Loc.t("Land the last blow with %s.") % Loc.t(str(v)))
		var need: String = str(goal.get("reaction", ""))
		if not need.is_empty():
			parts.append(Loc.t("Set off a %s reaction.") % Loc.t(need.capitalize()))
	return " ".join(parts)

## A model for a fresh attempt (items 708, 711): built from the file, the goal sentence set.
## [param quick] leaves out every text before the fight, for an instant restart.
static func start_attempt(p: Dictionary, quick: bool = false) -> Attempt:
	var at: Attempt = start(p)
	at.model.set_meta("puzzle_goal", goal_text(p))
	if quick:
		at.model.set_meta("quick", true)
	return at

## The intro events of a prepared model; a quick restart drops the spoken lines.
static func intro_events(m: BattleModel) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	for e: BattleEvent in m.get_meta("intro", []):
		if m.has_meta("quick") and e.type == BattleEvent.Type.BATTLE_LINE:
			continue
		out.append(e)
	return out

# --- Hints, results and rewards (items 707, 710, 712) ------------------------------

## A hint after this many failed tries: hint_1 from 2, hint_2 from 4 (item 707).
const HINT_1_FAILS: int = 2
const HINT_2_FAILS: int = 4

## The hint for [param fails] failed tries, translated, or "" before the first one is due.
static func hint(p: Dictionary, fails: int) -> String:
	var key: String = "hint_2" if fails >= HINT_2_FAILS else ("hint_1" if fails >= HINT_1_FAILS else "")
	if key.is_empty() or str(p.get(key, "")).is_empty():
		return ""
	return Loc.t(str(p.get(key)))

## Puzzle results by id (item 712): {"lanterns", "turns" (fewest of a solved try, 0 for none),
## "fails"}. Older saves kept lanterns (or true) in records["trials"]; those count here without
## being removed, so nothing is lost.
static func results(records: Dictionary) -> Dictionary:
	var out: Dictionary = (records.get("puzzles", {}) as Dictionary).duplicate(true)
	var old: Dictionary = records.get("trials", {})
	for id: Variant in old:
		var lit: int = _legacy_lanterns(old[id])
		var e: Dictionary = out.get(str(id), {"lanterns": 0, "turns": 0, "fails": 0})
		e["lanterns"] = maxi(int(e.get("lanterns", 0)), lit)
		out[str(id)] = e
	return out

static func _legacy_lanterns(v: Variant) -> int:
	if v is bool:
		return 2 if v else 0
	return clampi(int(v), 0, MAX_LANTERNS)

## Best lanterns stored for puzzle [param id].
static func best_lanterns(records: Dictionary, id: String) -> int:
	return int((results(records).get(id, {}) as Dictionary).get("lanterns", 0))

## Writes one finished attempt into records["puzzles"] and returns its entry.
static func note_result(records: Dictionary, p: Dictionary, at: Attempt) -> Dictionary:
	var all_res: Dictionary = results(records)
	var id: String = str(p.get("id", ""))
	var e: Dictionary = all_res.get(id, {"lanterns": 0, "turns": 0, "fails": 0})
	e["lanterns"] = maxi(int(e.get("lanterns", 0)), lanterns(p, at))
	if solved(p, at):
		var t: int = at.turns()
		e["turns"] = t if int(e.get("turns", 0)) <= 0 else mini(int(e.turns), t)
	else:
		e["fails"] = int(e.get("fails", 0)) + 1
	all_res[id] = e
	records["puzzles"] = all_res
	return e

## Echo Crystal for 3 lanterns on every Trial of a Warden (item 710).
const WARDEN_REWARD: Dictionary = {"cinder": "echo_furnace_heart", "tide": "echo_fathom_crush"}

## The reward item now due for [param warden], or "" (none, not earned or already given).
static func reward_due(records: Dictionary, warden: String) -> String:
	var item: String = str(WARDEN_REWARD.get(warden, ""))
	if item.is_empty() or item in (records.get("puzzle_rewards", []) as Array):
		return ""
	var trials: Array[Dictionary] = for_warden(warden)
	if trials.is_empty():
		return ""
	for p: Dictionary in trials:
		if best_lanterns(records, str(p.get("id", ""))) < MAX_LANTERNS:
			return ""
	return item

## Notes that the reward of [param warden] was given, so it comes only once.
static func mark_reward(records: Dictionary, warden: String) -> void:
	var given: Array = (records.get("puzzle_rewards", []) as Array).duplicate()
	given.append(str(WARDEN_REWARD.get(warden, "")))
	records["puzzle_rewards"] = given
