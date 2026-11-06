class_name BattleReferee
extends RefCounted
## The battle referee (plan area 7, items 2687-2690). A battle is fully decided by its seed, both
## starting teams and the player's inputs (BattleReplay), so the server can play it again and
## compare the result with what the game claimed: the winner, the Vigor left of every Spirling on
## both sides and the number of rounds. Any difference is a "mismatch".
## Runs on the server in server/referee/ and, with the same code, inside LocalBackend.

const OK: String = "ok"
const MISMATCH: String = "mismatch"
const ERROR: String = "error"
## Limits against oversized or broken uploads.
const MAX_INPUTS: int = 400
const MAX_TEAM: int = 6

## What the game claims about a finished battle: winner, Vigor left per side, rounds.
static func claim_of(model: BattleModel) -> Dictionary:
	return {"winner": winner_word(model.outcome), "hp": [_hp(model, BattleModel.Side.PLAYER), _hp(model, BattleModel.Side.FOE)],
		"rounds": model.turn}

static func winner_word(o: BattleModel.Outcome) -> String:
	match o:
		BattleModel.Outcome.WIN:
			return "player"
		BattleModel.Outcome.LOSS:
			return "foe"
		BattleModel.Outcome.FLED:
			return "fled"
		BattleModel.Outcome.BONDED:
			return "bonded"
	return "none"

static func _hp(model: BattleModel, side: int) -> Array:
	var out: Array = []
	for s: Spirling in model.party(side):
		out.append(s.hp)
	return out

## Checks [param replay] (a BattleReplay snapshot with inputs) against [param claim].
## Returns {"verdict": "ok" | "mismatch" | "error", "detail": {...}}.
static func check(replay: Variant, claim: Variant) -> Dictionary:
	var why: String = _shape_error(replay, claim)
	if not why.is_empty():
		return {"verdict": ERROR, "detail": {"reason": why}}
	var m: BattleModel = BattleReplay.build_model(replay)
	if m == null:
		return {"verdict": ERROR, "detail": {"reason": "rebuild"}}
	m.start()
	var inputs: Array = (replay as Dictionary).get("inputs", [])
	for i: int in inputs.size():
		if m.is_finished():
			break
		var d: Dictionary = inputs[i]
		# An input the battle could not have taken at this point means the replay does not fit.
		if str(d.get("t", "")) == "switch":
			if not m.needs_player_switch() or not int(d.get("i", -1)) in m.swap_candidates(BattleModel.Side.PLAYER, m.switch_slot()):
				return {"verdict": MISMATCH, "detail": {"field": "input", "index": i}}
			m.submit_switch(int(d.get("i", 0)))
		else:
			if m.needs_player_switch():
				return {"verdict": MISMATCH, "detail": {"field": "input", "index": i}}
			if str(d.get("t", "")) == "turns":
				m.submit_actions(BattleReplay.actions_from_dict(d))
			else:
				m.submit_turn(BattleReplay.action_from_dict(d))
	if not m.is_finished():
		return {"verdict": MISMATCH, "detail": {"field": "unfinished", "rounds": m.turn}}
	var real: Dictionary = claim_of(m)
	return compare(real, claim)

## Compares the referee's own result with the claim, field by field.
static func compare(real: Dictionary, claim: Dictionary) -> Dictionary:
	if str(claim.get("winner", "")) != str(real.winner):
		return {"verdict": MISMATCH, "detail": {"field": "winner", "real": real.winner, "claimed": claim.get("winner")}}
	if _num(claim.get("rounds")) != int(real.rounds):
		return {"verdict": MISMATCH, "detail": {"field": "rounds", "real": real.rounds, "claimed": claim.get("rounds")}}
	var hp: Variant = claim.get("hp")
	if not hp is Array or (hp as Array).size() != 2:
		return {"verdict": MISMATCH, "detail": {"field": "hp"}}
	for side: int in 2:
		var mine: Array = real.hp[side]
		var told: Variant = hp[side]
		if not told is Array or (told as Array).size() != mine.size():
			return {"verdict": MISMATCH, "detail": {"field": "hp", "side": side}}
		for i: int in mine.size():
			if _num(told[i]) != int(mine[i]):
				return {"verdict": MISMATCH, "detail": {"field": "hp", "side": side, "index": i, "real": mine[i], "claimed": told[i]}}
	return {"verdict": OK, "detail": {"rounds": real.rounds, "winner": real.winner}}

## JSON numbers arrive as floats; anything else never matches.
static func _num(v: Variant) -> int:
	if v is int:
		return v
	if v is float and float(v) == floorf(float(v)):
		return int(v)
	return -999999

static func _shape_error(replay: Variant, claim: Variant) -> String:
	if not replay is Dictionary or not claim is Dictionary:
		return "shape"
	var teams: Variant = (replay as Dictionary).get("teams")
	if not teams is Array or (teams as Array).size() != 2:
		return "teams"
	for t: Variant in teams:
		if not t is Array or (t as Array).is_empty() or (t as Array).size() > MAX_TEAM:
			return "teams"
		for s: Variant in t:
			if not s is Dictionary:
				return "teams"
	var inputs: Variant = (replay as Dictionary).get("inputs", [])
	if not inputs is Array or (inputs as Array).size() > MAX_INPUTS:
		return "inputs"
	for d: Variant in inputs:
		if not d is Dictionary:
			return "inputs"
		if str((d as Dictionary).get("t", "")) == "turns":
			var acts: Variant = (d as Dictionary).get("a", [])
			if not acts is Array:
				return "inputs"
			for act: Variant in acts:
				if not act is Dictionary:
					return "inputs"
	for key: String in ["partner", "inventory", "foe_items"]:
		if (replay as Dictionary).has(key) and not (replay as Dictionary)[key] is Dictionary:
			return key
	if (replay as Dictionary).has("front"):
		var front: Variant = (replay as Dictionary).front
		if not front is Array or (front as Array).size() != 2:
			return "front"
	return ""
