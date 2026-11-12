class_name LiveDuelSim
extends RefCounted
## Plays a live duel (Online 100, points 1-3, 10, 73) from what the server keeps: the seed, both
## picked teams and each round's two choices. Both phones and every watcher run the same rounds
## and reach the same state. Side 0 (the inviter) is the model's player side. A Spirling that
## drops is followed by the next one that still stands.

var model: BattleModel
## Rounds played so far.
var played: int = 0
## Lines of the round played last.
var last_lines: Array[String] = []
var _start_hp: Array = [[], []]

## The battle of duel state [param d] (live_state or live_watch) after every finished round;
## null when the teams are not there yet or cannot be built.
static func of(d: Dictionary) -> LiveDuelSim:
	var teams: Variant = d.get("teams", [])
	if not teams is Array or (teams as Array).size() != 2:
		return null
	var s := LiveDuelSim.new()
	s.model = BattleReplay.build_model(snap_of(d))
	if s.model == null:
		return null
	s.model.start()
	for side: int in 2:
		for sp: Spirling in s.model.parties[side]:
			(s._start_hp[side] as Array).append(sp.hp)
	s._settle()
	var moves: Dictionary = d.get("moves", {}) if d.get("moves") is Dictionary else {}
	var r: int = 1
	while not s.model.is_finished() and moves.get(str(r)) is Array and (moves[str(r)] as Array).size() == 2 \
			and moves[str(r)][0] is Dictionary and moves[str(r)][1] is Dictionary:
		s.play(moves[str(r)][0], moves[str(r)][1])
		r += 1
	return s

## The battle snapshot of duel state [param d]: the server's seed and both picked teams.
static func snap_of(d: Dictionary) -> Dictionary:
	return BattleReferee.from_expect({"seed": int(d.get("seed", 0)), "teams": d.get("teams", []), "ai": 2})

## The referee's answer for a live duel (point 3): the rounds the server kept, played again.
## [param expect] is {seed, teams, moves}. "finished" false means the duel is not over yet.
static func judge(expect: Dictionary) -> Dictionary:
	var moves: Variant = expect.get("moves", {})
	if not moves is Dictionary or (moves as Dictionary).size() > BattleReferee.MAX_INPUTS:
		return {"verdict": BattleReferee.ERROR, "detail": {"reason": "inputs"}}
	var teams: Variant = expect.get("teams", [])
	if not teams is Array or (teams as Array).size() != 2:
		return {"verdict": BattleReferee.ERROR, "detail": {"reason": "teams"}}
	for t: Variant in teams:
		if not t is Array or (t as Array).is_empty() or (t as Array).size() > BattleReferee.MAX_TEAM:
			return {"verdict": BattleReferee.ERROR, "detail": {"reason": "teams"}}
		for row: Variant in t:
			if not row is Dictionary:
				return {"verdict": BattleReferee.ERROR, "detail": {"reason": "teams"}}
	var s: LiveDuelSim = of(expect)
	if s == null:
		return {"verdict": BattleReferee.ERROR, "detail": {"reason": "rebuild"}}
	return {"verdict": BattleReferee.OK, "detail": {"finished": s.finished(), "winner": s.winner(), "rounds": s.played}}

## A choice as the server keeps it: kind, move and swap index only.
static func input_of(a: BattleAction) -> Dictionary:
	return {"k": int(a.kind), "m": a.move_index, "s": a.swap_index}

func _action(side: int, input: Dictionary) -> BattleAction:
	return action_of(model, side, input)

## The action of [param side] for [param input]; anything the battle cannot take now is a Rest.
static func action_of(model: BattleModel, side: int, input: Dictionary) -> BattleAction:
	var a: BattleAction = BattleReplay.action_from_dict({"k": int(input.get("k", BattleAction.Kind.REST)),
		"m": int(input.get("m", -1)), "s": int(input.get("s", -1))})
	a.side = side
	if not a.kind in [BattleAction.Kind.MOVE, BattleAction.Kind.SWAP, BattleAction.Kind.REST] or not model.is_legal(a):
		a = BattleAction.make_rest(side)
	return a

## A dropped Spirling of side 0 is followed by the next one standing (side 1 is refilled by the model).
func _settle() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	while model.needs_player_switch():
		out.append_array(model.submit_switch(model.swap_candidates(BattleModel.Side.PLAYER, model.switch_slot())[0]))
	return out

## Plays one round from both choices.
func play(input0: Dictionary, input1: Dictionary) -> void:
	if model.is_finished():
		return
	var events: Array[BattleEvent] = model.submit_turn(_action(0, input0), _action(1, input1))
	events.append_array(_settle())
	played += 1
	last_lines = []
	for e: BattleEvent in events:
		var line: String = e.describe()
		if not line.is_empty():
			last_lines.append(line)

func finished() -> bool:
	return model.is_finished()

## 0 or 1 for the side that still stands, -1 while it runs or when nobody stands.
func winner() -> int:
	if not model.is_finished():
		return -1
	var a: int = model.alive_count(0)
	var b: int = model.alive_count(1)
	return 0 if a > 0 and b == 0 else (1 if b > 0 and a == 0 else -1)

## The choices of [param side] this round: [{label, input}].
func choices(side: int) -> Array:
	return choices_of(model, side)

static func choices_of(m: BattleModel, side: int) -> Array:
	var out: Array = []
	var me: Spirling = m.active_spirling(side)
	for a: BattleAction in m.legal_actions(side):
		var label: String
		match a.kind:
			BattleAction.Kind.MOVE: label = Loc.t(me.moves[a.move_index].move_name)
			BattleAction.Kind.SWAP: label = Loc.t("Swap to %s") % (m.parties[side][a.swap_index] as Spirling).display_name()
			BattleAction.Kind.REST: label = Loc.t("Rest")
			_: continue
		out.append({"label": label, "input": input_of(a)})
	return out

## "Kindlop 34/50" for the Spirling of [param side] on the field.
func active_line(side: int) -> String:
	var s: Spirling = model.active_spirling(side)
	return "%s %d/%d" % [s.display_name(), maxi(0, s.hp), s.max_hp()] if s != null else "-"

## The battle summary (point 10): damage taken per Spirling of [param side].
func summary(side: int) -> Array[String]:
	var names: Array = []
	var end_hp: Array = []
	for s: Spirling in model.parties[side]:
		names.append(s.display_name())
		end_hp.append(maxi(0, s.hp))
	return LiveDuel.summary(names, _start_hp[side], end_hp)
