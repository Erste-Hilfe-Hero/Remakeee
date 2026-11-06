class_name BattleAI
extends RefCounted
## Foe decision making. Works only through the BattleModel API.
##   Tier 0: random legal move (wild Spirlings).
##   Tier 1: greedy: expected damage x accuracy (effectiveness included), plus KO and status bonuses.
##   Tier 2: tier 1 with a one-ply lookahead, swaps out of bad matchups, heals under an HP threshold.
##   Tier 3 ("Master", Rift-Born): tier 2, plus it never wastes a status on a foe that can't take it,
##          sets up stat stages only while the foe can't punish it hard, finishes weakened foes
##          first, and calls Resonance fields that favour its own side.
## With several Spirlings per side the AI also picks a target: each move is scored against every
## foe it can aim at, and a sweep is scored as the sum over all foes it reaches.

const KO_BONUS: float = 1.0
const STATUS_BONUS: float = 0.3
const STAGE_BONUS: float = 0.25
## Weight of the opponent's best reply in the tier-2 lookahead.
const REPLY_WEIGHT: float = 0.5
## Tier 2 swaps when the opponent's best hit is at least this effective and a resisting ally exists.
const BAD_MATCHUP_EFF: float = 2.0
const RESIST_EFF: float = 0.5
const SWAP_MIN_HP: float = 0.5
## Tier 2 heals below this HP fraction if it carries a healing item.
const HEAL_THRESHOLD: float = 0.3
## Score for a Resonance field per side it helps (any AI tier above 0).
const FIELD_BONUS: float = 0.35
## Tier 3: no stage setup while the foe's best hit takes at least this share of our HP.
const SETUP_THREAT: float = 0.4
const SETUP_SAFE_MULT: float = 1.5
## Tier 3: extra pull toward weakened foes (times the share of HP the target has lost).
const FINISH_BONUS: float = 0.2
## Fixed scores for the newer move blocks (docs/plan5000/02_kampf.md, item 563):
## Energy tax per taxed turn, a side snare per foe on the bench, a delayed hit as a share of its
## expected damage, and a small cost per own stage a self_stage_after hit gives up.
## A cooldown costs nothing on the turn it is used.
const TAX_BONUS_PER_TURN: float = 0.15
const SNARE_BONUS_PER_BENCH: float = 0.25
const DELAYED_SHARE: float = 0.8
const SELF_DROP_COST: float = 0.1

var level: int = 0

func _init(ai_level: int = 0) -> void:
	level = ai_level

## Picks an action for the Spirling in [param slot] of [param side]. Always returns a legal action.
func choose(model: BattleModel, side: int, slot: int = 0) -> BattleAction:
	var moves: Array[BattleAction] = []
	for a: BattleAction in model.legal_actions(side, slot):
		if a.kind == BattleAction.Kind.MOVE:
			moves.append(a)
	if level >= 2:
		var special: BattleAction = _tier2_special(model, side, slot)
		if special != null:
			return special
	if moves.is_empty():
		return BattleAction.make_rest(side, slot)
	var foes: Array[int] = model.standing_slots(BattleModel.other(side))
	if level <= 0:
		var pick: BattleAction = moves[model.rng.randi_range(0, moves.size() - 1)]
		# Only roll for a target when there is a choice, so 1v1 battles keep their RNG sequence.
		if foes.size() > 1:
			pick.target_slot = foes[model.rng.randi_range(0, foes.size() - 1)]
		elif foes.size() == 1:
			pick.target_slot = foes[0]
		return pick
	var best: BattleAction = moves[0]
	var best_score: float = -INF
	for a: BattleAction in moves:
		var mv: MoveData = model.active_spirling(side, slot).moves[a.move_index]
		var aims: Array[int] = [-1]
		if not mv.is_area() and not foes.is_empty():
			aims = foes
		for aim: int in aims:
			var score: float = score_action(model, side, slot, a.move_index, aim)
			if score > best_score:
				best_score = score
				best = BattleAction.make_move(side, a.move_index, slot, aim)
	return best

## Score of using [param move_index] aimed at foe slot [param aim] (-1 for a sweep or the first foe):
## the greedy score per foe reached (sweeps scaled by the spread share), minus the tier-2 reply.
func score_action(model: BattleModel, side: int, slot: int, move_index: int, aim: int) -> float:
	var me: Spirling = model.active_spirling(side, slot)
	var mv: MoveData = me.moves[move_index]
	var reached: Array[int] = model.move_targets(side, mv, aim)
	var share: float = BattleRules.SPREAD_MULT if reached.size() > 1 else 1.0
	var score: float = 0.0
	for t: int in reached:
		score += score_move(model, side, move_index, slot, t) * share
	if reached.is_empty():
		score = score_move(model, side, move_index, slot)
	if level >= 2:
		score -= REPLY_WEIGHT * _best_reply_score(model, side, move_index, slot, reached[0] if not reached.is_empty() else -1)
	return score

## Greedy score of a move: expected fraction of the target's HP removed, plus bonuses.
## [param target_slot] -1 scores it against the first foe still standing.
func score_move(model: BattleModel, side: int, move_index: int, slot: int = 0, target_slot: int = -1) -> float:
	var me: Spirling = model.active_spirling(side, slot)
	var target: Spirling = model.active_spirling(BattleModel.other(side), target_slot) if target_slot >= 0 else model.opponent(side)
	var mv: MoveData = BattleRules.resolve_move(me.moves[move_index], model.field)
	var acc: float = mv.accuracy * StatusRules.acc_mult(me.status)
	var expected: float = DamageCalc.estimate(me, target, mv) * BattleRules.status_bonus(mv, target)
	var delayed: bool = false
	for fx: Dictionary in mv.effects:
		delayed = delayed or StringName(fx.get("id", "")) == &"delayed_hit"
	if delayed:
		# Lands later: worth a share of the hit now, and never counted as a KO this turn.
		return DELAYED_SHARE * minf(expected, float(target.hp)) / float(maxi(target.max_hp(), 1)) * acc
	var score: float = minf(expected, float(target.hp)) / float(maxi(target.max_hp(), 1)) * acc
	if mv.is_damaging() and expected >= float(target.hp):
		score += KO_BONUS * acc
	if level >= 3 and mv.is_damaging():
		score += FINISH_BONUS * (1.0 - target.hp_fraction()) * acc
	for fx: Dictionary in mv.effects:
		var fx_id: StringName = StringName(fx.get("id", ""))
		if fx_id == &"stat_change":
			var on_self: bool = bool(fx.get("self", true))
			var who: Spirling = me if on_self else target
			var stage: int = who.stage(str(fx.get("stat", "")))
			var amt: int = int(fx.get("amount", 1))
			# Worth it only while the stage still has room and early-ish in the fight.
			if (amt > 0 and stage < 2) or (amt < 0 and stage > -2):
				var bonus: float = STAGE_BONUS * float(fx.get("chance", 1.0)) * acc * me.hp_fraction()
				if level >= 3 and on_self and amt > 0:
					bonus *= 0.0 if threat_to(model, side, slot) >= SETUP_THREAT else SETUP_SAFE_MULT
				score += bonus
		elif fx_id == &"set_field" and level >= 1:
			score += FIELD_BONUS * maxf(0.0, field_value(model, side, str(fx.get("field", ""))))
		elif fx_id == &"energy_tax" and target.energy_tax <= 1:
			var turns: int = int(fx.get("amount", 0))
			score += TAX_BONUS_PER_TURN * float(turns if turns > 0 else BattleRules.ENERGY_TAX_TURNS) * acc
		elif fx_id == &"side_snare":
			score += SNARE_BONUS_PER_BENCH * float(model.swap_candidates(BattleModel.other(side), maxi(target_slot, 0)).size()) * acc
		elif fx_id == &"self_stage_after" and expected < float(target.hp):
			var st: Dictionary = fx.get("stages", {})
			for k: String in st:
				score -= SELF_DROP_COST * float(maxi(0, -int(st[k])))
	if target.status.is_empty():
		for fx: Dictionary in mv.effects:
			if StringName(fx.get("id", "")) == &"inflict_status":
				var st: String = str(fx.get("status", ""))
				if level >= 3 and (BattleRules.is_immune(target, st) or model.calm_rule_blocks(BattleModel.other(side), target, st)):
					continue
				score += STATUS_BONUS * float(fx.get("chance", 1.0)) * acc
	return score

## How much laying field [param id] helps [param side]: +1 if one of its standing Spirlings has a
## move of the boosted element, -1 if a foe has one, half that for the weakened element.
## 0 when the field is already in place.
func field_value(model: BattleModel, side: int, id: String) -> float:
	var f: Dictionary = BattleRules.FIELDS.get(id, {})
	if f.is_empty() or model.field == id:
		return 0.0
	var boost: int = Elements.E.get(str(f.boost), -1)
	var weaken: int = Elements.E.get(str(f.weaken), -1)
	var v: float = 0.0
	for s_side: int in [side, BattleModel.other(side)]:
		var weight: float = 1.0 if s_side == side else -1.0
		var has_boost: bool = false
		var has_weak: bool = false
		for slot: int in model.standing_slots(s_side):
			for mv: MoveData in model.active_spirling(s_side, slot).moves:
				if mv.is_damaging():
					has_boost = has_boost or mv.element == boost
					has_weak = has_weak or mv.element == weaken
		v += weight * ((1.0 if has_boost else 0.0) - (0.5 if has_weak else 0.0))
	return v

## The largest share of our Spirling's current HP one standing foe can take with its best hit.
func threat_to(model: BattleModel, side: int, slot: int) -> float:
	var me: Spirling = model.active_spirling(side, slot)
	var best: float = 0.0
	for f_slot: int in model.standing_slots(BattleModel.other(side)):
		var foe: Spirling = model.active_spirling(BattleModel.other(side), f_slot)
		for mv: MoveData in foe.moves:
			if mv.is_damaging() and foe.can_afford(mv):
				best = maxf(best, DamageCalc.estimate(foe, me, mv) * mv.accuracy / float(maxi(me.hp, 1)))
	return best

## Picks who steps into [param slot] after a faint: the healthy ally with the best matchup.
## Returns -1 when nobody is left on the bench.
func choose_replacement(model: BattleModel, side: int, slot: int = 0) -> int:
	var candidates: Array[int] = model.swap_candidates(side, slot)
	if candidates.is_empty():
		return -1
	if level <= 0:
		return candidates[0]
	var best: int = candidates[0]
	var best_score: float = -INF
	for i: int in candidates:
		var score: float = _matchup(model.party(side)[i], model.opponent(side))
		if score > best_score:
			best_score = score
			best = i
	return best

# --- Tier 2 ---------------------------------------------------------------------

func _tier2_special(model: BattleModel, side: int, slot: int = 0) -> BattleAction:
	var me: Spirling = model.active_spirling(side, slot)
	var foe: Spirling = model.opponent(side)
	# Heal when low, if the bag allows it.
	if me.hp_fraction() < HEAL_THRESHOLD:
		for a: BattleAction in model.legal_actions(side, slot):
			if a.kind == BattleAction.Kind.ITEM and int(Database.item(a.item_id).get("heal", 0)) > 0:
				return a
	# Swap out of a bad matchup into an ally that resists the foe's elements.
	if _threat_eff(foe, me) >= BAD_MATCHUP_EFF:
		for a: BattleAction in model.legal_actions(side, slot):
			if a.kind != BattleAction.Kind.SWAP:
				continue
			var ally: Spirling = model.party(side)[a.swap_index]
			if ally.hp_fraction() >= SWAP_MIN_HP and _threat_eff(foe, ally) <= RESIST_EFF:
				return a
	return null

## Highest effectiveness among [param attacker]'s damaging moves (or its elements) into [param defender].
func _threat_eff(attacker: Spirling, defender: Spirling) -> float:
	var best: float = 0.0
	for mv: MoveData in attacker.moves:
		if mv.is_damaging():
			best = maxf(best, Elements.multiplier(mv.element, defender.elements()))
	if best == 0.0:
		for e: int in attacker.elements():
			best = maxf(best, Elements.multiplier(e, defender.elements()))
	return best

## The opponent's best greedy score against us if we use [param move_index] first.
## Looks one ply ahead: if our move is expected to KO and we act first, there is no reply.
func _best_reply_score(model: BattleModel, side: int, move_index: int, slot: int = 0, target_slot: int = -1) -> float:
	var me: Spirling = model.active_spirling(side, slot)
	var foe: Spirling = model.active_spirling(BattleModel.other(side), target_slot) if target_slot >= 0 else model.opponent(side)
	var mv: MoveData = me.moves[move_index]
	var we_first: bool = mv.priority > 0 or me.effective_spd() > foe.effective_spd()
	if we_first and mv.is_damaging() and DamageCalc.estimate(me, foe, mv) >= float(foe.hp):
		return 0.0
	var best: float = 0.0
	for reply: MoveData in foe.moves:
		if not foe.can_afford(reply) or not reply.is_damaging():
			continue
		var dmg: float = DamageCalc.estimate(foe, me, reply)
		best = maxf(best, minf(dmg, float(me.hp)) / float(maxi(me.max_hp(), 1)) * reply.accuracy)
	return best

func _matchup(mine: Spirling, theirs: Spirling) -> float:
	return _threat_eff(mine, theirs) - _threat_eff(theirs, mine) + mine.hp_fraction()
