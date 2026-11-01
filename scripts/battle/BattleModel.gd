class_name BattleModel
extends RefCounted
## Pure battle model: no Nodes, no rendering. Every call returns the BattleEvents it produced.
##
## Flow (a state machine over Phase):
##   INTRO -> CHOOSE_ACTIONS -> RESOLVE_ORDER -> EXECUTE_ACTION (loop) -> END_OF_TURN
##   -> FAINT_CHECK -> VICTORY_CHECK -> SWITCH_IN -> CHOOSE_ACTIONS | AWAIT_SWITCH
##   ... -> REWARDS -> FINISHED
## The model stops and waits for input in CHOOSE_ACTIONS (submit_turn) and AWAIT_SWITCH (submit_switch).
## One seeded RandomNumberGenerator drives every roll, so a seed reproduces a battle exactly.

enum Side { PLAYER = 0, FOE = 1 }
enum Phase {
	INTRO, CHOOSE_ACTIONS, RESOLVE_ORDER, EXECUTE_ACTION, END_OF_TURN,
	FAINT_CHECK, VICTORY_CHECK, SWITCH_IN, AWAIT_SWITCH, REWARDS, FINISHED,
}
enum Outcome { NONE, WIN, LOSS, BONDED, FLED }

const ENERGY_PER_TURN: int = 1
## Energy a REST action restores (on top of the per-turn gain).
const REST_ENERGY: int = 2
const FLEE_BASE: float = 0.5
const FLEE_PER_ATTEMPT: float = 0.25
const FLEE_SPEED_WEIGHT: float = 0.5
## XP for a defeated foe = xp_yield * foe level / XP_LEVEL_DIV (x TRAINER_XP_MULT vs Tamers).
const XP_LEVEL_DIV: float = 20.0
const TRAINER_XP_MULT: float = 1.5
const MAX_PARTY: int = 6

signal event_emitted(event: BattleEvent)

var parties: Array[Array] = [[], []]
var active: Array[int] = [0, 0]
var is_wild: bool = true
var trainer_name: String = ""
var rng := RandomNumberGenerator.new()
var battle_seed: int = 0
var phase: Phase = Phase.INTRO
var outcome: Outcome = Outcome.NONE
var turn: int = 0
var items_allowed: bool = true
var level_cap: int = Spirling.MAX_LEVEL
## Player bag, item id -> count. Shared by reference with GameState so use is persisted.
var inventory: Dictionary = {}
## Trainer bag for AI tier 2.
var foe_items: Dictionary = {}
var ai: BattleAI
## Prize money for beating a Tamer (reported in BATTLE_END).
var prize_money: int = 0
var flee_attempts: int = 0
## The Spirling bonded this battle, if any.
var bonded: Spirling = null
## Player Spirlings that faced the current foe (share its XP).
var participants: Array[Spirling] = []
## Rift field id (BattleRules.FIELDS) active for the whole battle, or "".
var field: String = ""
## Warden rule id (BattleRules.RULES) for the foe side, or "".
var foe_rule: String = ""

var _queue: Array[BattleAction] = []
var _events: Array[BattleEvent] = []
var _handlers: Dictionary[Phase, Callable] = {}

## [param ai_level] is the foe's AI tier (0 random, 1 greedy, 2 lookahead).
func _init(player_party: Array[Spirling], foe_party: Array[Spirling], wild: bool, seed_value: int, ai_level: int = 0) -> void:
	parties = [player_party, foe_party]
	is_wild = wild
	battle_seed = seed_value
	rng.seed = seed_value
	ai = BattleAI.new(ai_level)
	_handlers = {
		Phase.RESOLVE_ORDER: _phase_resolve_order,
		Phase.EXECUTE_ACTION: _phase_execute_action,
		Phase.END_OF_TURN: _phase_end_of_turn,
		Phase.FAINT_CHECK: _phase_faint_check,
		Phase.VICTORY_CHECK: _phase_victory_check,
		Phase.SWITCH_IN: _phase_switch_in,
		Phase.REWARDS: _phase_rewards,
	}

# --- Queries -----------------------------------------------------------------

func party(side: int) -> Array:
	return parties[side]

func active_spirling(side: int) -> Spirling:
	return parties[side][active[side]]

static func other(side: int) -> int:
	return 1 - side

func opponent(side: int) -> Spirling:
	return active_spirling(other(side))

func alive_count(side: int) -> int:
	var n: int = 0
	for s: Spirling in parties[side]:
		if not s.is_fainted():
			n += 1
	return n

func is_finished() -> bool:
	return phase == Phase.FINISHED

func needs_player_switch() -> bool:
	return phase == Phase.AWAIT_SWITCH

## Indices of party members that could swap in for [param side].
func swap_candidates(side: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in parties[side].size():
		var s: Spirling = parties[side][i]
		if i != active[side] and not s.is_fainted():
			out.append(i)
	return out

## Every legal action for [param side] this turn. REST is always legal.
func legal_actions(side: int) -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	var me: Spirling = active_spirling(side)
	for i: int in me.moves.size():
		if me.can_afford(me.moves[i]):
			out.append(BattleAction.make_move(side, i))
	out.append(BattleAction.make_rest(side))
	if not StatusRules.blocks_swap(me.status):
		for i: int in swap_candidates(side):
			out.append(BattleAction.make_swap(side, i))
	var bag: Dictionary = _bag(side)
	if _items_allowed_for(side):
		for id: Variant in bag:
			if int(bag[id]) > 0 and _is_battle_item(str(id)):
				out.append(BattleAction.make_item(side, str(id), active[side]))
	if side == Side.PLAYER and is_wild:
		out.append(BattleAction.make_bond(side, 0.0))
		out.append(BattleAction.make_run(side))
	return out

## Checks a single action against the current state.
func is_legal(a: BattleAction) -> bool:
	var me: Spirling = active_spirling(a.side)
	match a.kind:
		BattleAction.Kind.MOVE:
			return a.move_index >= 0 and a.move_index < me.moves.size() and me.can_afford(me.moves[a.move_index])
		BattleAction.Kind.REST:
			return true
		BattleAction.Kind.SWAP:
			return not StatusRules.blocks_swap(me.status) and a.swap_index in swap_candidates(a.side)
		BattleAction.Kind.ITEM:
			if not _items_allowed_for(a.side) or int(_bag(a.side).get(a.item_id, 0)) <= 0 or not _is_battle_item(a.item_id):
				return false
			return a.item_target >= 0 and a.item_target < parties[a.side].size() and not (parties[a.side][a.item_target] as Spirling).is_fainted()
		BattleAction.Kind.BOND:
			if a.side != Side.PLAYER or not is_wild:
				return false
			return a.item_id.is_empty() or int(inventory.get(a.item_id, 0)) > 0
		BattleAction.Kind.RUN:
			return a.side == Side.PLAYER and is_wild
	return false

# --- Commands ----------------------------------------------------------------

## Intro: both sides step out. Returns the intro events.
func start() -> Array[BattleEvent]:
	_events = []
	for side: int in [Side.PLAYER, Side.FOE]:
		for s: Spirling in parties[side]:
			s.energy = Spirling.START_ENERGY
		active[side] = _first_alive(side)
	var foe: Spirling = active_spirling(Side.FOE)
	emit_event(BattleEvent.Type.BATTLE_START, {"wild": is_wild, "trainer": trainer_name, "foe_name": foe.display_name()})
	if not is_wild:
		emit_event(BattleEvent.Type.SEND_OUT, _who(Side.FOE))
	emit_event(BattleEvent.Type.SEND_OUT, _who(Side.PLAYER))
	if BattleRules.FIELDS.has(field):
		emit_event(BattleEvent.Type.FIELD, {"field": field, "text": str(BattleRules.FIELDS[field].intro)})
	if BattleRules.RULES.has(foe_rule):
		var rule: Dictionary = BattleRules.RULES[foe_rule]
		emit_event(BattleEvent.Type.RULE, {"rule": foe_rule, "label": str(rule.label), "text": str(rule.text)})
		var st: Dictionary = rule.get("player_stage", {})
		for s: Spirling in parties[Side.PLAYER]:
			for stat: String in st:
				s.stages[stat] = clampi(s.stage(stat) + int(st[stat]), BattleRules.STAGE_MIN, BattleRules.STAGE_MAX)
	participants = [active_spirling(Side.PLAYER)]
	phase = Phase.CHOOSE_ACTIONS
	return _events

## Plays one turn. [param foe_action] defaults to the AI's choice.
func submit_turn(player_action: BattleAction, foe_action: BattleAction = null) -> Array[BattleEvent]:
	_events = []
	if phase != Phase.CHOOSE_ACTIONS:
		push_error("BattleModel.submit_turn called in phase %s" % Phase.keys()[phase])
		return _events
	if player_action == null or not is_legal(player_action):
		player_action = BattleAction.make_rest(Side.PLAYER)
	if foe_action == null or not is_legal(foe_action):
		foe_action = ai.choose(self, Side.FOE)
	_queue = [player_action, foe_action]
	phase = Phase.RESOLVE_ORDER
	_run()
	return _events

## Picks the player's replacement after a faint (phase AWAIT_SWITCH).
func submit_switch(index: int) -> Array[BattleEvent]:
	_events = []
	if phase != Phase.AWAIT_SWITCH or not index in swap_candidates(Side.PLAYER):
		push_error("BattleModel.submit_switch: illegal switch to %d" % index)
		return _events
	_swap_in(Side.PLAYER, index)
	phase = Phase.CHOOSE_ACTIONS
	return _events

# --- Helpers used by effects --------------------------------------------------

func emit_event(t: BattleEvent.Type, d: Dictionary = {}) -> void:
	var e := BattleEvent.new(t, d)
	_events.append(e)
	event_emitted.emit(e)

## Damages the active Spirling on [param side]. Emits DAMAGE and, if it drops, FAINTED.
func deal_damage(side: int, amount: int, extra: Dictionary = {}) -> int:
	var s: Spirling = active_spirling(side)
	var dealt: int = mini(amount, s.hp)
	s.hp -= dealt
	var d: Dictionary = _who(side)
	d.merge({"amount": dealt, "hp": s.hp, "max_hp": s.max_hp()})
	d.merge(extra)
	emit_event(BattleEvent.Type.DAMAGE, d)
	if s.is_fainted():
		emit_event(BattleEvent.Type.FAINTED, _who(side))
	return dealt

func heal(side: int, amount: int) -> int:
	return _heal_spirling(side, active[side], amount)

## Tries to afflict the active Spirling on [param side]. Fails if it already has a status.
func apply_status(side: int, status: String) -> bool:
	var s: Spirling = active_spirling(side)
	if s.is_fainted() or not s.status.is_empty() or not StatusRules.exists(status):
		return false
	if BattleRules.is_immune(s, status):
		var f: Dictionary = _who(side)
		f["status"] = status
		emit_event(BattleEvent.Type.STATUS_FAILED, f)
		return false
	s.status = status
	s.status_turns = StatusRules.roll_turns(status, rng)
	var d: Dictionary = _who(side)
	d["status"] = status
	emit_event(BattleEvent.Type.STATUS_APPLIED, d)
	return true

## Moves a stat stage on the active Spirling of [param side]. Emits STAT_CHANGED (or a "won't go" note).
func change_stage(side: int, stat: String, delta: int) -> void:
	var s: Spirling = active_spirling(side)
	if s.is_fainted() or delta == 0 or not stat in BattleRules.STAGE_STATS:
		return
	var before: int = s.stage(stat)
	var after: int = clampi(before + delta, BattleRules.STAGE_MIN, BattleRules.STAGE_MAX)
	var d: Dictionary = _who(side)
	d.merge({"stat": stat, "delta": after - before, "stage": after, "tried": delta})
	s.stages[stat] = after
	emit_event(BattleEvent.Type.STAT_CHANGED, d)

func change_energy(side: int, delta: int) -> void:
	var s: Spirling = active_spirling(side)
	var before: int = s.energy
	s.energy = clampi(s.energy + delta, 0, Spirling.MAX_ENERGY)
	if s.energy != before:
		var d: Dictionary = _who(side)
		d["energy"] = s.energy
		emit_event(BattleEvent.Type.ENERGY_CHANGED, d)

# --- Phases ------------------------------------------------------------------

func _run() -> void:
	while _handlers.has(phase):
		_handlers[phase].call()

func _phase_resolve_order() -> void:
	for a: BattleAction in _queue:
		a.actor = active_spirling(a.side)
	# Shuffle first with the battle RNG so equal keys get a seeded tiebreak, then stable-sort.
	var tiebreak: Dictionary[BattleAction, float] = {}
	for a: BattleAction in _queue:
		tiebreak[a] = rng.randf()
	_queue.sort_custom(func(x: BattleAction, y: BattleAction) -> bool:
		return _sort_key(x, tiebreak[x]) > _sort_key(y, tiebreak[y]))
	phase = Phase.EXECUTE_ACTION

## Larger key acts first: lower action class, then higher priority, then higher SPD, then RNG.
func _sort_key(a: BattleAction, tie: float) -> Vector4:
	var prio: int = 0
	if a.kind == BattleAction.Kind.MOVE and a.actor != null and a.move_index < a.actor.moves.size():
		prio = a.actor.moves[a.move_index].priority
	var spd: int = a.actor.effective_spd() if a.actor != null else 0
	return Vector4(-a.order_class(), prio, spd, tie)

func _phase_execute_action() -> void:
	if outcome != Outcome.NONE:
		_queue.clear()
		phase = Phase.REWARDS
		return
	if _queue.is_empty():
		phase = Phase.END_OF_TURN
		return
	var a: BattleAction = _queue.pop_front()
	# Re-check validity: the actor may have fainted or been swapped out since choosing.
	if a.actor == null or a.actor.is_fainted() or a.actor != active_spirling(a.side):
		return
	if a.is_free:
		emit_event(BattleEvent.Type.FREE_ACTION, _who(a.side))
	match a.kind:
		BattleAction.Kind.MOVE: _do_move(a)
		BattleAction.Kind.REST: _do_rest(a)
		BattleAction.Kind.SWAP: _do_swap(a)
		BattleAction.Kind.ITEM: _do_item(a)
		BattleAction.Kind.BOND: _do_bond(a)
		BattleAction.Kind.RUN: _do_run(a)

func _phase_end_of_turn() -> void:
	for side: int in [Side.PLAYER, Side.FOE]:
		var s: Spirling = active_spirling(side)
		if s.is_fainted():
			continue
		var div: int = StatusRules.tick_div(s.status)
		if div > 0:
			var d: Dictionary = _who(side)
			d["status"] = s.status
			emit_event(BattleEvent.Type.STATUS_TICK, d)
			deal_damage(side, maxi(1, s.max_hp() / div), {"status_tick": true})
		if s.is_fainted():
			continue
		if s.status_turns > 0 and not StatusRules.sleeps(s.status):
			s.status_turns -= 1
			if s.status_turns == 0:
				_cure(side)
		var regen: int = int(BattleRules.trait_info(s.data.trait_id).get("regen_div", 0))
		var held_regen: int = int(BattleRules.held_info(s.held).get("regen_div", 0))
		for rdiv: int in [regen, held_regen]:
			if rdiv > 0 and s.hp < s.max_hp():
				heal(side, maxi(1, s.max_hp() / rdiv))
		var gain: int = ENERGY_PER_TURN + int(BattleRules.add_key(s, "energy_per_turn"))
		if side == Side.FOE:
			gain += int(BattleRules.RULES.get(foe_rule, {}).get("foe_energy", 0))
		change_energy(side, gain)
	turn += 1
	phase = Phase.FAINT_CHECK

func _phase_faint_check() -> void:
	var foe: Spirling = active_spirling(Side.FOE)
	if foe.is_fainted() and not foe.has_meta("xp_paid"):
		foe.set_meta("xp_paid", true)
		_award_xp(foe)
	phase = Phase.VICTORY_CHECK

func _phase_victory_check() -> void:
	if alive_count(Side.FOE) == 0:
		outcome = Outcome.WIN
		phase = Phase.REWARDS
	elif alive_count(Side.PLAYER) == 0:
		outcome = Outcome.LOSS
		phase = Phase.REWARDS
	else:
		phase = Phase.SWITCH_IN

func _phase_switch_in() -> void:
	if active_spirling(Side.FOE).is_fainted():
		_swap_in(Side.FOE, ai.choose_replacement(self, Side.FOE))
	if active_spirling(Side.PLAYER).is_fainted():
		phase = Phase.AWAIT_SWITCH
	else:
		phase = Phase.CHOOSE_ACTIONS

func _phase_rewards() -> void:
	for s: Spirling in parties[Side.PLAYER]:
		s.end_battle()
	for s: Spirling in parties[Side.FOE]:
		if s.has_meta("xp_paid"):
			s.remove_meta("xp_paid")
	if bonded != null:
		bonded.end_battle()
	var money: int = prize_money if outcome == Outcome.WIN and not is_wild else 0
	emit_event(BattleEvent.Type.BATTLE_END, {"outcome": outcome, "outcome_name": Outcome.keys()[outcome], "money": money})
	phase = Phase.FINISHED

# --- Actions -------------------------------------------------------------------

func _do_move(a: BattleAction) -> void:
	var side: int = a.side
	var me: Spirling = a.actor
	var mv: MoveData = me.moves[a.move_index]
	if StatusRules.sleeps(me.status):
		if me.status_turns > 0:
			me.status_turns -= 1
			var d: Dictionary = _who(side)
			d["status"] = me.status
			emit_event(BattleEvent.Type.STATUS_PREVENTED, d)
			return
		_cure(side)
	var skip: float = StatusRules.skip_chance(me.status)
	if skip > 0.0 and rng.randf() < skip:
		var d2: Dictionary = _who(side)
		d2["status"] = me.status
		emit_event(BattleEvent.Type.STATUS_PREVENTED, d2)
		return
	if not me.can_afford(mv):
		emit_event(BattleEvent.Type.NOT_ENOUGH_ENERGY, _who(side))
		return
	change_energy(side, -mv.energy_cost)
	var power_mult: float = 1.0
	if mv.overcharge and me.energy > 0:
		var extra: int = me.energy
		power_mult += BattleRules.OVERCHARGE_PER_ENERGY * extra
		change_energy(side, -extra)
	var used: Dictionary = _who(side)
	used.merge({"move": mv.move_name, "element": mv.element, "kind": mv.kind})
	emit_event(BattleEvent.Type.MOVE_USED, used)
	var target_side: int = other(side)
	var target: Spirling = active_spirling(target_side)
	if target.is_fainted():
		emit_event(BattleEvent.Type.NO_TARGET, {})
		return
	var acc: float = mv.accuracy * StatusRules.acc_mult(me.status)
	if acc < 1.0 and rng.randf() >= acc:
		emit_event(BattleEvent.Type.MISSED, _who(side))
		return
	var ctx := EffectContext.new()
	ctx.model = self
	ctx.user_side = side
	ctx.target_side = target_side
	ctx.user = me
	ctx.target = target
	ctx.move = mv
	if mv.is_damaging():
		var mult: float = power_mult * BattleRules.damage_mult(me, target, mv, field)
		var r: Dictionary = DamageCalc.compute(me, target, mv, rng, mult, BattleRules.mult_key(me, "crit_mult"))
		ctx.damage_dealt = deal_damage(target_side, int(r.damage), {"eff": r.eff, "crit": r.crit, "move": mv.move_name})
	for fx: Dictionary in mv.effects:
		var effect: MoveEffect = EffectRegistry.get_effect(StringName(fx.get("id", "")))
		if effect != null:
			effect.apply(ctx, fx)

func _do_rest(a: BattleAction) -> void:
	emit_event(BattleEvent.Type.REST, _who(a.side))
	change_energy(a.side, REST_ENERGY)

func _do_swap(a: BattleAction) -> void:
	if StatusRules.blocks_swap(a.actor.status):
		emit_event(BattleEvent.Type.SWAP_BLOCKED, _who(a.side))
		return
	if not a.swap_index in swap_candidates(a.side):
		return
	emit_event(BattleEvent.Type.SWAP_OUT, _who(a.side))
	_swap_in(a.side, a.swap_index)

func _do_item(a: BattleAction) -> void:
	var bag: Dictionary = _bag(a.side)
	if int(bag.get(a.item_id, 0)) <= 0 or not _items_allowed_for(a.side):
		return
	var target: Spirling = parties[a.side][a.item_target]
	if target.is_fainted():
		return
	var it: Dictionary = Database.item(a.item_id)
	bag[a.item_id] = int(bag[a.item_id]) - 1
	var d: Dictionary = {"side": a.side, "index": a.item_target, "name": target.display_name(), "item": a.item_id, "item_name": str(it.get("name", a.item_id))}
	emit_event(BattleEvent.Type.ITEM_USED, d)
	if int(it.get("heal", 0)) > 0:
		_heal_spirling(a.side, a.item_target, int(it.heal))
	if bool(it.get("cure", false)) and not target.status.is_empty():
		var was_active: bool = a.item_target == active[a.side]
		if was_active:
			_cure(a.side)
		else:
			target.status = ""
			target.status_turns = 0
	if int(it.get("energy", 0)) > 0 and a.item_target == active[a.side]:
		change_energy(a.side, int(it.energy))

func _do_bond(a: BattleAction) -> void:
	var target: Spirling = active_spirling(Side.FOE)
	if target.is_fainted():
		emit_event(BattleEvent.Type.NO_TARGET, {})
		return
	var bonus: float = 0.0
	if not a.item_id.is_empty() and int(inventory.get(a.item_id, 0)) > 0:
		inventory[a.item_id] = int(inventory[a.item_id]) - 1
		bonus = float(Database.item(a.item_id).get("bond_bonus", 0.0))
	var who: Dictionary = _who(Side.FOE)
	who["timing"] = a.timing_score
	emit_event(BattleEvent.Type.BOND_ATTEMPT, who)
	var success: bool = rng.randf() < BondCalc.chance(target, a.timing_score, bonus)
	var res: Dictionary = _who(Side.FOE)
	res["success"] = success
	emit_event(BattleEvent.Type.BOND_RESULT, res)
	if success:
		bonded = target
		outcome = Outcome.BONDED
		return
	# A failed bond gives the wild Spirling one free action, right now.
	var free: BattleAction = ai.choose(self, Side.FOE)
	free.actor = active_spirling(Side.FOE)
	free.is_free = true
	_queue.push_front(free)

func _do_run(a: BattleAction) -> void:
	var mine: float = float(a.actor.effective_spd())
	var theirs: float = maxf(float(active_spirling(Side.FOE).effective_spd()), 1.0)
	var chance: float = clampf(FLEE_BASE + FLEE_PER_ATTEMPT * flee_attempts + (mine / theirs - 1.0) * FLEE_SPEED_WEIGHT, 0.0, 1.0)
	flee_attempts += 1
	var success: bool = rng.randf() < chance
	emit_event(BattleEvent.Type.FLEE_RESULT, {"success": success})
	if success:
		outcome = Outcome.FLED

# --- Internals ------------------------------------------------------------------

func _who(side: int) -> Dictionary:
	var s: Spirling = active_spirling(side)
	return {"side": side, "index": active[side], "name": s.display_name(), "species": s.data.species_name}

func _first_alive(side: int) -> int:
	for i: int in parties[side].size():
		if not (parties[side][i] as Spirling).is_fainted():
			return i
	return 0

func _swap_in(side: int, index: int) -> void:
	active[side] = index
	var s: Spirling = active_spirling(side)
	var d: Dictionary = _who(side)
	d.merge({"hp": s.hp, "max_hp": s.max_hp(), "level": s.level, "energy": s.energy})
	emit_event(BattleEvent.Type.SWAP_IN, d)
	if side == Side.PLAYER:
		if not participants.has(s):
			participants.append(s)
	else:
		participants = [active_spirling(Side.PLAYER)]

func _cure(side: int) -> void:
	var s: Spirling = active_spirling(side)
	if s.status.is_empty():
		return
	var d: Dictionary = _who(side)
	d["status"] = s.status
	s.status = ""
	s.status_turns = 0
	emit_event(BattleEvent.Type.STATUS_CURED, d)

func _heal_spirling(side: int, index: int, amount: int) -> int:
	var s: Spirling = parties[side][index]
	var healed: int = mini(amount, s.max_hp() - s.hp)
	if healed <= 0:
		return 0
	s.hp += healed
	emit_event(BattleEvent.Type.HEAL, {"side": side, "index": index, "name": s.display_name(), "amount": healed, "hp": s.hp, "max_hp": s.max_hp()})
	return healed

func _bag(side: int) -> Dictionary:
	return inventory if side == Side.PLAYER else foe_items

func _items_allowed_for(side: int) -> bool:
	return items_allowed if side == Side.PLAYER else true

func _is_battle_item(id: String) -> bool:
	return bool(Database.item(id).get("battle", false))

func _award_xp(foe: Spirling) -> void:
	var total: float = float(foe.data.xp_yield) * float(foe.level) / XP_LEVEL_DIV
	if not is_wild:
		total *= TRAINER_XP_MULT
	var earners: Array[Spirling] = []
	for s: Spirling in participants:
		if not s.is_fainted() and parties[Side.PLAYER].has(s):
			earners.append(s)
	if earners.is_empty():
		return
	var share: int = maxi(1, int(total / earners.size()))
	for s: Spirling in earners:
		var index: int = parties[Side.PLAYER].find(s)
		var cap_xp: int = Spirling.xp_for_level(mini(level_cap, Spirling.MAX_LEVEL))
		var gained: int = clampi(share, 0, maxi(0, cap_xp - s.xp)) if s.level < level_cap else 0
		s.xp += gained
		emit_event(BattleEvent.Type.XP_GAINED, {"side": Side.PLAYER, "index": index, "name": s.display_name(), "amount": gained})
		while s.level < mini(level_cap, Spirling.MAX_LEVEL) and s.xp >= Spirling.xp_for_level(s.level + 1):
			var learned: Array[MoveData] = s.level_up()
			emit_event(BattleEvent.Type.LEVEL_UP, {"side": Side.PLAYER, "index": index, "name": s.display_name(), "level": s.level, "hp": s.hp, "max_hp": s.max_hp()})
			for mv: MoveData in learned:
				emit_event(BattleEvent.Type.MOVE_LEARNED, {"side": Side.PLAYER, "index": index, "name": s.display_name(), "move": mv.move_name})
