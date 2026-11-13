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
## A Spirling that stepped in fewer than this many turns ago stays in (no endless swap dance).
const SWAP_SETTLE_TURNS: int = 2
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
const BURN_BONUS_PER_ENERGY: float = 0.1
## Moves scoring at most this (no damage, no useful effect) are not worth the Energy.
const USELESS_SCORE: float = 0.01
const HEAL_BLOCK_BONUS: float = 0.2
## Wayfarer personalities (items 611-615): weights per profile in this file.
const PROFILES_PATH: String = "res://data/ai_profiles.json"
const DEFAULT_PROFILE: String = "balanced"
## A healing art is worth the share of Vigor it gives back, times this, below heal_below.
const HEAL_ART_WEIGHT: float = 1.0
## focus_fire: extra pull toward the most hurt foe (times the share of HP it has lost).
const FOCUS_BONUS: float = 0.3
## status_first: damage counts this much while the target carries no status yet.
const STATUS_FIRST_DAMAGE: float = 0.5
## plan_energy (Tactician): rest when an art it can pay next turn scores this much more.
const PLAN_MARGIN: float = 1.5
## Tag battles (item 628): extra pull toward the foe the player aims at.
const ALLY_FOCUS_BONUS: float = 0.15
## KAMPF_PLAN_1000 (area "Gegner-KI"):
## Tier 2 swaps out once its main attack stat sits at this stage or lower (item 446).
const BAD_STAGE: int = -2
## Tier 2 leaves a replacement below this HP share on the bench while a healthier one is there (449).
const SPARE_HP: float = 0.25
const SPARE_COST: float = 1.0
## Most bag items one side's AI uses in a battle (item 459).
const ITEM_LIMIT: int = 2
## Recoil arts cost this much per share of own max HP they take back, below LOW_HP only (item 461).
const RECOIL_W: float = 1.0
const LOW_HP: float = 0.35
## Arts whose damage also refills the user (weighed by drain_w, item 619).
const DRAIN_EFFECTS: Array[StringName] = [&"drain", &"energy_drain", &"energy_refund"]
## Mottos and battle lines per profile: data/dialogue/<file>.json, keys "<profile>_<kind>".
const LINES_FILE: String = "battle_lines"

static var _profiles: Dictionary = {}

var level: int = 0
## Personality id from data/ai_profiles.json ("balanced" when the Wayfarer names none).
var profile_id: String = DEFAULT_PROFILE
var profile: Dictionary = {}
## Per-Wayfarer weight changes on top of the profile (npc "profile_tune", item 681).
var profile_tune: Dictionary = {}
## Foe slot the player aims at this turn (set for a tag partner, -1 otherwise).
var ally_target: int = -1

func _init(ai_level: int = 0, profile_name: String = "") -> void:
	level = ai_level
	set_profile(profile_name)

## All profiles from data/ai_profiles.json, keyed by id (loaded once).
static func profiles() -> Dictionary:
	if _profiles.is_empty() and FileAccess.file_exists(PROFILES_PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES_PATH))
		if raw is Dictionary:
			for k: String in raw:
				if raw[k] is Dictionary:
					_profiles[k] = raw[k]
	return _profiles

## Picks the personality; an unknown or empty id falls back to "balanced". [param tune] sets
## single numeric weights on top (a Warden's sharper "field_w", item 681).
func set_profile(profile_name: String, tune: Dictionary = {}) -> void:
	var all: Dictionary = profiles()
	profile_id = profile_name if all.has(profile_name) else DEFAULT_PROFILE
	profile = (all.get(profile_id, {}) as Dictionary).duplicate()
	profile_tune = {}
	for k: Variant in tune:
		if tune[k] is float or tune[k] is int:
			profile[str(k)] = float(tune[k])
			profile_tune[str(k)] = float(tune[k])

## The profile's line of [param kind] ("motto", "own_fall", "foe_fall", "last"), or "".
func line(kind: String) -> String:
	var v: Variant = Dialogue.file_data(LINES_FILE).get("%s_%s" % [profile_id, kind])
	return str(v[0]) if v is Array and not (v as Array).is_empty() else ""

## A profile weight; tier 0 (wild, random) ignores personalities (item 625).
func weight(key: String) -> float:
	if level < 1:
		return 1.0
	return float(profile.get(key, 1.0))

## A profile threshold, or [param fallback] when the profile leaves it at null / -1 default.
func _rule(key: String, fallback: float) -> float:
	var v: Variant = profile.get(key)
	if level < 1 or v == null:
		return fallback
	return float(v)

## Picks an action for the Spirling in [param slot] of [param side]. Always returns a legal action.
## Story and Tamer (item 741): no heal_block art against the foe's last standing Spirling.
var spare_last: bool = false
## Veteran (item 742): never rest twice in a row while an art is affordable.
var no_double_rest: bool = false
## Sets spare_last and no_double_rest for a Wayfarer battle on [param difficulty] (items 741, 742).
func set_difficulty(difficulty: int) -> void:
	spare_last = difficulty >= 0 and difficulty <= 1
	no_double_rest = difficulty == 2

## Slots that rested on their last action (for no_double_rest).
var _rested: Dictionary = {}

func choose(model: BattleModel, side: int, slot: int = 0) -> BattleAction:
	var a: BattleAction = _choose(model, side, slot)
	if no_double_rest and a.kind == BattleAction.Kind.REST and bool(_rested.get(slot, false)):
		var arts: Array[BattleAction] = _arts(model, side, slot)
		if not arts.is_empty():
			# The hardest-hitting affordable art stands in for the second rest.
			a = arts[0]
			var me: Spirling = model.active_spirling(side, slot)
			for b: BattleAction in arts:
				if me.moves[b.move_index].power > me.moves[a.move_index].power:
					a = b
			var foes: Array[int] = model.standing_slots(BattleModel.other(side))
			if not foes.is_empty():
				a.target_slot = foes[0]
	_rested[slot] = a.kind == BattleAction.Kind.REST
	return a

## True if [param mv] carries a heal_block effect.
static func blocks_heal(mv: MoveData) -> bool:
	for fx: Dictionary in mv.effects:
		if StringName(fx.get("id", "")) == &"heal_block":
			return true
	return false

## The affordable art actions, without heal_block arts when spare_last holds and the other
## side has one Spirling left (unless nothing else is left).
func _arts(model: BattleModel, side: int, slot: int) -> Array[BattleAction]:
	var moves: Array[BattleAction] = []
	for a: BattleAction in model.legal_actions(side, slot):
		if a.kind == BattleAction.Kind.MOVE:
			moves.append(a)
	if spare_last and not moves.is_empty():
		var left: int = 0
		for s: Spirling in model.parties[BattleModel.other(side)]:
			if not s.is_fainted():
				left += 1
		if left == 1:
			var me: Spirling = model.active_spirling(side, slot)
			var kept: Array[BattleAction] = []
			for a: BattleAction in moves:
				if not blocks_heal(me.moves[a.move_index]):
					kept.append(a)
			if not kept.is_empty():
				moves = kept
	return moves

func _choose(model: BattleModel, side: int, slot: int = 0) -> BattleAction:
	var moves: Array[BattleAction] = _arts(model, side, slot)
	if level >= 2:
		var special: BattleAction = _tier2_special(model, side, slot)
		if special != null:
			return special
	if moves.is_empty():
		return BattleAction.make_rest(side, slot)
	var foes: Array[int] = model.standing_slots(BattleModel.other(side))
	var me_now: Spirling = model.active_spirling(side, slot)
	var rest_below: int = int(_rule("rest_below", -1.0))
	if level >= 1 and rest_below >= 0 and me_now.energy <= rest_below and model.can_rest(true):
		return BattleAction.make_rest(side, slot)
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
	var best_value: float = 0.0
	var second: BattleAction = null
	var second_score: float = -INF
	var me: Spirling = model.active_spirling(side, slot)
	for a: BattleAction in moves:
		var mv: MoveData = me.moves[a.move_index]
		var aims: Array[int] = [-1]
		if not mv.is_area() and not foes.is_empty():
			aims = _unclaimed(model, side, foes) if mv.is_damaging() else foes
		var move_best: float = -INF
		var move_pick: BattleAction = null
		for aim: int in aims:
			var score: float = score_action(model, side, slot, a.move_index, aim)
			best_value = maxf(best_value, score_move(model, side, a.move_index, slot, aim))
			# Equal scores go to the foe with the least Vigor left (item 478).
			if score > move_best or (score == move_best and move_pick != null and _hp_of(model, side, aim) < _hp_of(model, side, move_pick.target_slot)):
				move_best = score
				move_pick = BattleAction.make_move(side, a.move_index, slot, aim)
		# Best and runner-up are kept per art, so the runner-up is a different art.
		if move_best > best_score:
			second = best if best_score > -INF else null
			second_score = best_score
			best_score = move_best
			best = move_pick
		elif move_best > second_score:
			second_score = move_best
			second = move_pick
	# Nothing it can afford does anything useful: catch its breath for a bigger art instead.
	if best_value <= USELESS_SCORE and me.energy < Spirling.MAX_ENERGY and (rest_below < 0 or me.energy <= rest_below) and model.can_rest(true):
		return BattleAction.make_rest(side, slot)
	if _plans_rest(model, side, slot, best_value):
		return BattleAction.make_rest(side, slot)
	_claim_if_sure(model, side, slot, best)
	# Apprentice (item 618): sometimes takes the runner-up; Rift-Born (level 3) never does (626).
	var slip: float = float(profile.get("second_best", 0.0))
	if second != null and slip > 0.0 and level >= 1 and level < 3 and model.rng.randf() < slip:
		return second
	return best

## Sure knock-outs already planned this turn (items 463, 479): "<side>:<turn>" -> foe slots.
var _claims: Dictionary = {}

## [param foes] without the ones a teammate already knocks out for sure this turn (all of them
## when every foe is claimed).
func _unclaimed(model: BattleModel, side: int, foes: Array[int]) -> Array[int]:
	var claimed: Array = _claims.get("%d:%d" % [side, model.turn], [])
	if level < 1 or claimed.is_empty():
		return foes
	var out: Array[int] = []
	for f: int in foes:
		if not f in claimed:
			out.append(f)
	return foes if out.is_empty() else out

## Notes [param a]'s target when its single-target hit is expected to knock it out.
func _claim_if_sure(model: BattleModel, side: int, slot: int, a: BattleAction) -> void:
	if level < 1 or a.kind != BattleAction.Kind.MOVE or a.target_slot < 0 or model.standing_slots(BattleModel.other(side)).size() < 2:
		return
	var me: Spirling = model.active_spirling(side, slot)
	var mv: MoveData = BattleRules.resolve_move(me.moves[a.move_index], model.field)
	var target: Spirling = model.active_spirling(BattleModel.other(side), a.target_slot)
	if not mv.is_damaging() or mv.is_area() or target == null or mv.accuracy < 1.0:
		return
	if DamageCalc.estimate(me, target, mv) * BattleRules.status_bonus(mv, target) < float(target.hp):
		return
	var key: String = "%d:%d" % [side, model.turn]
	if not _claims.has(key) and _claims.size() > 4:
		_claims = {}
	var row: Array = _claims.get(key, [])
	row.append(a.target_slot)
	_claims[key] = row

## Vigor left on the foe of [param side] in [param slot] (-1 aims at the first one standing).
static func _hp_of(model: BattleModel, side: int, slot: int) -> int:
	var t: Spirling = model.active_spirling(BattleModel.other(side), slot) if slot >= 0 else model.opponent(side)
	return t.hp if t != null else 0

## Energy every Spirling gains per turn under the variants in play (item 800): 1 normally,
## 3 under "No Rest" (the +2 the AI reckons with), 0 under "Full Charge".
static func energy_gain(model: BattleModel) -> int:
	return maxi(0, int(model.rules.get("energy_per_turn", 1)))

## True under "Stage Still" (item 800): stage changes never land.
static func stages_locked(model: BattleModel) -> bool:
	return float(model.rules.get("stages_locked", 0.0)) > 0.0 or BattleRules.rule_number(model.foe_rule, "stages_locked") > 0.0

## plan_energy (item 617): true when an art it can't pay now, but can after resting this turn,
## beats everything affordable by PLAN_MARGIN.
func _plans_rest(model: BattleModel, side: int, slot: int, best_now: float) -> bool:
	if level < 1 or int(profile.get("plan_energy", 0)) <= 0 or not model.can_rest(true):
		return false
	var me: Spirling = model.active_spirling(side, slot)
	var next: int = mini(me.energy + model.rest_gain() + energy_gain(model), model.max_energy())
	for i: int in me.moves.size():
		var mv: MoveData = me.moves[i]
		if not mv.is_damaging() or me.can_afford(mv) or me.cooldown_left(mv) > 1 or me.move_cost(mv) > next:
			continue
		if score_move(model, side, i, slot) >= maxf(best_now, USELESS_SCORE) * PLAN_MARGIN:
			return true
	return false

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
	if ally_target >= 0 and aim == ally_target and mv.is_damaging() and level >= 1 and weight("focus_fire") > 0.0:
		score += ALLY_FOCUS_BONUS
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
	# Overcharge counts only where the leftover Energy turns the hit into a knock-out (item 460).
	if mv.overcharge and level >= 1 and expected < float(target.hp):
		var extra: int = clampi(me.energy - me.move_cost(mv), 0, BattleRules.OVERCHARGE_MAX_EXTRA)
		var charged: float = expected * (1.0 + BattleRules.OVERCHARGE_PER_ENERGY * extra)
		if charged >= float(target.hp):
			expected = charged
	var delayed: bool = false
	for fx: Dictionary in mv.effects:
		delayed = delayed or StringName(fx.get("id", "")) == &"delayed_hit"
	var damage_w: float = weight("damage_w")
	if weight("status_first") > 0.0 and target.status.is_empty() and level >= 1:
		damage_w *= STATUS_FIRST_DAMAGE
	if delayed:
		# Lands later: worth a share of the hit now, and never counted as a KO this turn.
		return damage_w * DELAYED_SHARE * minf(expected, float(target.hp)) / float(maxi(target.max_hp(), 1)) * acc
	var hit: float = minf(expected, float(target.hp)) / float(maxi(target.max_hp(), 1)) * acc
	if mv.is_damaging() and expected >= float(target.hp):
		hit += KO_BONUS * acc
	if level >= 3 and mv.is_damaging():
		hit += FINISH_BONUS * (1.0 - target.hp_fraction()) * acc
	if mv.is_damaging() and weight("focus_fire") > 0.0 and level >= 1:
		hit += FOCUS_BONUS * (1.0 - target.hp_fraction()) * acc
	for fx: Dictionary in mv.effects:
		if StringName(fx.get("id", "")) in DRAIN_EFFECTS:
			hit *= weight("drain_w")
			break
	# Parts of the score each personality weighs differently (items 611-615).
	var spoil: float = 0.0
	var setup: float = 0.0
	var fld: float = 0.0
	var score: float = 0.0
	for fx: Dictionary in mv.effects:
		var fx_id: StringName = StringName(fx.get("id", ""))
		if fx_id == &"stat_change" and stages_locked(model):
			# "Stage Still" (item 800): no stage ever moves, so the stage part is worth nothing.
			continue
		elif fx_id == &"stat_change":
			var on_self: bool = bool(fx.get("self", true))
			var who: Spirling = me if on_self else target
			var stage: int = who.stage(str(fx.get("stat", "")))
			var amt: int = int(fx.get("amount", 1))
			# Worth it only while the stage still has room and early-ish in the fight.
			if (amt > 0 and stage < 2) or (amt < 0 and stage > -2):
				var bonus: float = STAGE_BONUS * float(fx.get("chance", 1.0)) * acc * me.hp_fraction()
				if level >= 3 and on_self and amt > 0:
					bonus *= 0.0 if threat_to(model, side, slot) >= SETUP_THREAT else SETUP_SAFE_MULT
				if on_self and amt > 0:
					var only: Array = profile.get("setup_stats", [])
					if only.is_empty() or str(fx.get("stat", "")) in only:
						setup += bonus
					else:
						score += bonus
				else:
					spoil += bonus
		elif fx_id == &"set_field" and level >= 1 and model.field_lock <= 0:
			var fid: String = str(fx.get("field", ""))
			# field_renew (item 616): its own field with one turn left is worth laying again.
			var renew: bool = int(profile.get("field_renew", 0)) > 0 and model.field == fid and model.field_turns == 1
			fld += FIELD_BONUS * maxf(0.0, field_value(model, side, fid, renew))
		elif fx_id == &"mend" and level >= 1 and me.mend_turns <= 0 and me.hp_fraction() < _rule("heal_below", HEAL_THRESHOLD):
			score += HEAL_ART_WEIGHT * float(fx.get("turns", BattleRules.MEND_TURNS)) / float(BattleRules.MEND_DIV) * acc
		elif fx_id == &"heal_self" and level >= 1 and me.hp_fraction() < _rule("heal_below", HEAL_THRESHOLD):
			var back: float = minf(float(fx.get("amount", 0.5)), 1.0 - me.hp_fraction())
			score += HEAL_ART_WEIGHT * back * acc
		elif fx_id == &"energy_tax" and target.energy_tax <= 1 and target.energy >= _cheapest_hit(target):
			# Only worth it while the foe has the Energy to strike; a drained foe is no target.
			var turns: int = int(fx.get("amount", 0))
			spoil += TAX_BONUS_PER_TURN * float(turns if turns > 0 else BattleRules.ENERGY_TAX_TURNS) * acc
		elif fx_id == &"status_shift":
			if not me.status.is_empty() and target.status.is_empty() and not BattleRules.is_immune(target, me.status):
				spoil += STATUS_BONUS * 2.0 * acc
		elif fx_id == &"energy_burn" and target.burn_guard <= 0:
			# Burnt Energy comes back faster when everyone gains more per turn ("No Rest", item 800).
			spoil += BURN_BONUS_PER_ENERGY * float(mini(target.energy, int(fx.get("amount", 1)))) * acc / float(maxi(1, energy_gain(model)))
		elif fx_id == &"heal_block" and target.heal_block <= 1:
			spoil += HEAL_BLOCK_BONUS * (1.0 if _can_heal(model, target) else 0.25) * acc
		elif fx_id == &"stage_steal":
			# Worth a stat art's bonus while the stolen stage still has room on our side.
			for st_name: String in BattleRules.STAGE_STATS:
				if target.stage(st_name) > 0 and me.stage(st_name) < 2:
					setup += STAGE_BONUS * acc * me.hp_fraction()
					break
		elif fx_id == &"cure_self" and not me.status.is_empty():
			score += STATUS_BONUS * acc
		elif fx_id == &"energy_gain" and me.energy < model.max_energy_of(side):
			score += BURN_BONUS_PER_ENERGY * float(mini(model.max_energy_of(side) - me.energy, int(fx.get("amount", 1)))) * acc
		elif fx_id == &"stage_reset":
			# Worth it when the foe's raised stages outweigh our own.
			var net: int = 0
			for st_name: String in BattleRules.STAGE_STATS:
				net += maxi(0, target.stage(st_name)) - maxi(0, me.stage(st_name))
			spoil += STAGE_BONUS * float(maxi(0, net)) * acc
		elif fx_id == &"cure_team":
			for mate: Spirling in model.party(side):
				if mate != null and not mate.is_fainted() and not mate.status.is_empty():
					score += STATUS_BONUS * acc
		elif fx_id == &"self_cost":
			score -= SELF_DROP_COST * float(fx.get("amount", 0.25)) * 4.0
		elif fx_id == &"recoil" and level >= 1 and me.hp_fraction() < LOW_HP:
			# Low on Vigor it shuns arts that hit back at itself (item 461), most of all a fatal one.
			var back: float = minf(expected, float(target.hp)) * float(fx.get("amount", 0.25)) * acc
			score -= KO_BONUS if back >= float(me.hp) else RECOIL_W * back / float(maxi(me.max_hp(), 1))
		elif fx_id == &"clear_snares":
			score += SNARE_BONUS_PER_BENCH * float((model.snares[side] as Array).size())
		elif fx_id == &"side_snare":
			# Each snare already lying there makes one more worth less; a full side is worth nothing.
			var lying: int = (model.snares[BattleModel.other(side)] as Array).size()
			var room: float = maxf(0.0, 1.0 - float(lying) / float(BattleRules.MAX_SNARES))
			spoil += SNARE_BONUS_PER_BENCH * float(model.swap_candidates(BattleModel.other(side), maxi(target_slot, 0)).size()) * room * room * acc
		elif fx_id == &"self_stage_after" and expected < float(target.hp) and not stages_locked(model):
			var st: Dictionary = fx.get("stages", {})
			for k: String in st:
				score -= SELF_DROP_COST * float(maxi(0, -int(st[k])))
	if target.status.is_empty():
		for fx: Dictionary in mv.effects:
			if StringName(fx.get("id", "")) == &"inflict_status":
				var st: String = str(fx.get("status", ""))
				if level >= 3 and (BattleRules.is_immune(target, st) or model.calm_rule_blocks(BattleModel.other(side), target, st)):
					continue
				spoil += STATUS_BONUS * float(fx.get("chance", 1.0)) * acc
	return score + hit * damage_w + spoil * weight("status_w") + setup * weight("setup_w") + fld * weight("field_w")

## Energy cost of the cheapest damage art [param s] knows (99 if none).
func _cheapest_hit(s: Spirling) -> int:
	var c: int = 99
	for mv: MoveData in s.moves:
		if mv.is_damaging():
			c = mini(c, mv.energy_cost)
	return c

## True if [param s] has a way to heal in battle: a healing art, a regenerating gift or keepsake.
func _can_heal(model: BattleModel, s: Spirling) -> bool:
	if BattleRules.add_key(s, "regen_div") > 0.0:
		return true
	if not str(BattleRules.FIELDS.get(model.field, {}).get("regen_element", "")).is_empty():
		return true
	for mv: MoveData in s.moves:
		for fx: Dictionary in mv.effects:
			if StringName(fx.get("id", "")) in [&"heal_self", &"drain"]:
				return true
	return false

## How much laying field [param id] helps [param side]: +1 if one of its standing Spirlings has a
## move of the boosted element, -1 if a foe has one, half that for the weakened element.
## 0 when the field is already in place (unless [param even_if_current], for renewing it).
func field_value(model: BattleModel, side: int, id: String, even_if_current: bool = false) -> float:
	var f: Dictionary = BattleRules.FIELDS.get(id, {})
	if f.is_empty() or (model.field == id and not even_if_current):
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
	var healthy: bool = false
	for i: int in candidates:
		healthy = healthy or model.party(side)[i].hp_fraction() >= SPARE_HP
	for i: int in candidates:
		var score: float = _matchup(model.party(side)[i], model.opponent(side))
		# Tier 2 keeps a badly hurt Spirling for later while a healthier one can go (item 449).
		if level >= 2 and healthy and model.party(side)[i].hp_fraction() < SPARE_HP:
			score -= SPARE_COST
		if score > best_score:
			best_score = score
			best = i
	return best

# --- Tier 2 ---------------------------------------------------------------------

func _tier2_special(model: BattleModel, side: int, slot: int = 0) -> BattleAction:
	var me: Spirling = model.active_spirling(side, slot)
	var foe: Spirling = model.opponent(side)
	# Heal when low, if the bag allows it.
	if me.hp_fraction() < _rule("heal_below", HEAL_THRESHOLD) and items_spent(model, side) < ITEM_LIMIT:
		for a: BattleAction in model.legal_actions(side, slot):
			if a.kind == BattleAction.Kind.ITEM and int(Database.item(a.item_id).get("heal", 0)) > 0:
				return a
	# Swap out of a bad matchup into an ally that resists the foe's elements.
	var settled: bool = model.turn - int(model.entered_turn.get(me, -SWAP_SETTLE_TURNS)) >= SWAP_SETTLE_TURNS
	var swap_below: float = _rule("swap_below", INF)
	if swap_below < 0.0:
		return null  # This personality never swaps by choice.
	if settled and main_stage(me) <= BAD_STAGE:
		var pick: BattleAction = _healthiest_swap(model, side, slot, foe)
		if pick != null:
			return pick
	var bad: bool = _threat_eff(foe, me) >= BAD_MATCHUP_EFF
	if swap_below != INF:
		bad = _threat_eff(me, foe) - _threat_eff(foe, me) + me.hp_fraction() < swap_below
	if settled and bad:
		for a: BattleAction in model.legal_actions(side, slot):
			if a.kind != BattleAction.Kind.SWAP:
				continue
			var ally: Spirling = model.party(side)[a.swap_index]
			if ally.hp_fraction() >= SWAP_MIN_HP and _threat_eff(foe, ally) <= RESIST_EFF:
				return a
	return null

## Bag items [param side] used so far in this battle.
static func items_spent(model: BattleModel, side: int) -> int:
	var n: int = 0
	for id: Variant in model.items_used[side]:
		n += int(model.items_used[side][id])
	return n

## The stage of the stat [param s]'s damaging arts mostly use (Might or Focus).
static func main_stage(s: Spirling) -> int:
	var phys: int = 0
	var foc: int = 0
	for mv: MoveData in s.moves:
		if mv.is_damaging():
			if mv.kind == MoveData.Kind.FOCUS:
				foc += 1
			else:
				phys += 1
	return s.stage("foc") if foc > phys else s.stage("atk")

## A swap to the ally with the most HP share that does not walk into a bad matchup, or null.
func _healthiest_swap(model: BattleModel, side: int, slot: int, foe: Spirling) -> BattleAction:
	var pick: BattleAction = null
	var best: float = SWAP_MIN_HP
	for a: BattleAction in model.legal_actions(side, slot):
		if a.kind != BattleAction.Kind.SWAP:
			continue
		var ally: Spirling = model.party(side)[a.swap_index]
		if ally.hp_fraction() >= best and _threat_eff(foe, ally) < BAD_MATCHUP_EFF:
			best = ally.hp_fraction()
			pick = a
	return pick

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
