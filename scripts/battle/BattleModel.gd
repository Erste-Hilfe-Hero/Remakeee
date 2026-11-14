class_name BattleModel
extends RefCounted
## Pure battle model: no Nodes, no rendering. Every call returns the BattleEvents it produced.
##
## Sides field one or more Spirlings at once (N against M, set by front_size before start()).
## Each side has field slots; slots[side][slot] is the party index standing there (-1 = empty).
## 1v1 is simply one slot per side. A tag battle adds an ally Wayfarer (set_partner) whose Spirlings
## take extra player slots and act on their own. A Rift boss (foe_boss) grows with the player's
## field and may act more than once per turn.
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
	# KAMPF_PLAN_1000 item 9: the foe named its next Spirling, the player may swap first (submit_shift).
	AWAIT_SHIFT,
}
enum Outcome { NONE, WIN, LOSS, BONDED, FLED }

const ENERGY_PER_TURN: int = 1
## Energy a REST action restores (on top of the per-turn gain).
const REST_ENERGY: int = 2
const FLEE_BASE: float = 0.5
const FLEE_PER_ATTEMPT: float = 0.25
const FLEE_SPEED_WEIGHT: float = 0.5
## XP for a defeated foe = xp_yield * foe level / XP_LEVEL_DIV (x TRAINER_XP_MULT vs Wayfarers).
const XP_LEVEL_DIV: float = 20.0
const TRAINER_XP_MULT: float = 1.5
const MAX_PARTY: int = 5

signal event_emitted(event: BattleEvent)

var parties: Array[Array] = [[], []]
## Field slots per side: party indices of the Spirlings on the field, -1 for an emptied slot.
var slots: Array[Array] = [[0], [0]]
## How many Spirlings each side fields at start() (player's own, foe). Set before start().
var front_size: Array[int] = [1, 1]
## Party index on the field for each side's first slot (read-only view for 1v1 code).
var active: Array[int]:
	get:
		var out: Array[int] = [active_index(Side.PLAYER), active_index(Side.FOE)]
		return out
## Ally Wayfarer in a tag battle. Their Spirlings sit at the end of the player party array from
## partner_start on, fill the player slots from _partner_slot on, and are steered by partner_ai.
var partner_name: String = ""
var partner_start: int = -1
var partner_front: int = 0
var partner_ai: BattleAI
## Personality lines already said this battle (kind -> true).
var _lines_said: Dictionary = {}
## True once the Warden's rule has turned (item 678); _turn_drag waits for the next player send-in.
var rule_turned: bool = false
## Veteran and up: the turning point uses the rule's "full_" keys (set by the caller, kept in replays).
var rule_turn_full: bool = false
var _turn_drag: Dictionary = {}
var _partner_slot: int = -1
## Rift boss id (BattleRules.BOSSES) for the foe in slot 0, or "".
var foe_boss: String = ""
## Extra Energy the foe side gains at the end of the first turn (Rift-Born, item 749).
var foe_turn1_energy: int = 0
## Ink Oath sworn this battle, per side (once per battle each).
var oath_used: Array[bool] = [false, false]
## Energy each side starts without (Tailwind on Story cuts the foe's, item 737).
var start_energy_cut: Array[int] = [0, 0]
## Warden Weakener (shop items 4885, 4889): the foe team starts with this share of its Vigor.
const WARDEN_WEAKEN_SHARE: float = 0.85
var warden_weakened: bool = false
## Share of damage the foe side deals (difficulty, plan area 2 item 728).
var foe_damage_mult: float = 1.0
## Factor on the foe side's critical chance (Story difficulty, KAMPF plan item 497).
var foe_crit_mult: float = 1.0
## Challenge rules (ChallengeRules): no chosen swaps for the player, why no bond can form ("" = it
## can), and bag items the player may not use in this battle.
var swap_locked: bool = false
var bond_block: String = ""
var blocked_items: Array[String] = []
## Factor on a boss's "hp_per_ally" (GameState.BOSS_HP_SCALE: Story bosses are 20 % smaller).
var boss_hp_scale: float = 1.0
## Rule variants in play (data/rule_variants.json, at most BattleRules.MAX_VARIANTS). Set before start().
var variants: Array[String] = []
## The number keys of the variants (BattleRules.VARIANT_KEYS), filled by start().
var rules: Dictionary = BattleRules.VARIANT_KEYS.duplicate()
var _boss_actions: int = 1
## Difficulty the boss rules follow (BattleRules.BOSS_*; -1 keeps the plain boss).
var boss_difficulty: int = -1
## Player slots still waiting for a replacement after faints (phase AWAIT_SWITCH), in order.
var pending_switch: Array[int] = []
var is_wild: bool = true
var trainer_name: String = ""
## The foe Wayfarer's tactic line at the start (WayfarerThemes.line), "" for none.
var foe_theme_line: String = ""
var rng := RandomNumberGenerator.new()
var battle_seed: int = 0
var phase: Phase = Phase.INTRO
var outcome: Outcome = Outcome.NONE
var turn: int = 0
## Raid attempts (plan area 7, item 2849) end after this many rounds, 0 = no limit. The battle then
## ends as FLED: nobody won, the damage dealt so far counts.
var round_limit: int = 0
var items_allowed: bool = true
## The player may put a keepsake from the bag on in battle (KeepsakeKit, KAMPF_PLAN_1000 298).
## Only the overworld turns it on, and only when the real team fights (never with echo copies).
var held_swap: bool = false
var level_cap: int = Spirling.LEVEL_SANITY
## Player bag, item id -> count. Shared by reference with GameState so use is persisted.
var inventory: Dictionary = {}
## Battle-only player items that are not in the bag, item id -> count. The Wayfarer Pass puts a
## free Rift Breath here for Warden battles (plan item 4633); it is used before the bag one and
## never reaches the journey's bag.
var gift_items: Dictionary = {}
## Failed bonds that do not give the wild Spirling its free action (the pass's extra bond try,
## plan item 4634).
var bond_grace: int = 0
## Added to every bond's timing score in wild battles (the shop's Bond Head Start, 0.1 per tier).
var bond_edge: float = 0.0
## Items used this battle per side, for the per-battle limits of shop items ("per_battle" in items.json).
var items_used: Array[Dictionary] = [{}, {}]
## Extra energy above the normal maximum per side, set before start() (the shop's Overcharge
## Core: the whole team starts with 12 of 12, plan item 4495).
var energy_bonus: Array[int] = [0, 0]
## Shop seal tiers per side, [power, guard, speed] (ShopEffects.SEAL_KINDS). Set only for story,
## raids and the Open League (ShopEffects.seals_for); the Fair League keeps zeros.
var seals: Array = [[0, 0, 0], [0, 0, 0]]
## Shop amulet tiers per side, [crit, ward, shield] (ShopEffects.AMULET_KINDS), set like seals.
var amulets: Array = [[0, 0, 0], [0, 0, 0]]
## The Spirling per side whose next hit taken is softened by the Opening Shield (null when used).
var _shield_on: Array = [null, null]
## Trainer bag for AI tier 2.
var foe_items: Dictionary = {}
var ai: BattleAI
## Prize money for beating a Wayfarer (reported in BATTLE_END).
var prize_money: int = 0
## Growth multiplier for the player's side (shop Growth Crystals and the pass, ShopEffects).
var xp_mult: float = 1.0
## Ring-scaled Growth (era function "ring_scaled_growth", Era V): each earner's share is scaled
## by growth_scale() of the foe's ring against its own.
var ring_scaled_growth: bool = false
## Wheel battle (era function "wheel_battles", Era V): with one Spirling at the front, at the end
## of every turn each side's front steps aside for the next standing one of its first
## wheel_size Spirlings, in team order.
var wheel: bool = false
var wheel_size: int = 3
## Opening line for the field instead of the Rift line (weather in battle, WeatherCycle).
var field_intro: String = ""
var flee_attempts: int = 0
## The Spirling bonded this battle, if any.
var bonded: Spirling = null
## Player Spirlings that faced the current foe (share its XP).
var participants: Array[Spirling] = []
## Rift field id (BattleRules.FIELDS) active right now, or "". Set it before start() for the
## place's own field; a Resonance move (set_field) lays another one for a few turns.
var field: String = ""
## The place's own field, restored when a Resonance field runs out (copied from field at start()).
var base_field: String = ""
## Turns left in which Resonance arts can't replace the field (Warden rule Ash Rain).
var field_lock: int = 0
## Turns left on a Resonance field (0 = the field holds for the whole battle).
var field_turns: int = 0
## Time of day of the battle (DayCycle.Phase), or -1 indoors / with the day cycle off. Some
## Resonance fields hold a turn longer at their own time of day (RiftFields.daytime_turns).
var day_phase: int = -1
## Support arts in play per side (MultiRules): kind -> {"turns", "slot", ...}.
var support: Array = [{}, {}]
## True when the foe Wayfarer fights in formation too (map trainer "formation": true, item 399).
var foe_formation: bool = false
## Share of the XP an earner gets that each healthy Spirling on the player's bench also gets
## ("Bench lessons" setting). 0 turns it off.
var bench_share: float = 0.0
## Growth the player's side gained this battle, and the bench's part of it (GrowthRules.after_battle).
var growth_total: int = 0
var bench_growth: int = 0
## Growth per player team index this battle (the after-battle growth line).
var growth_by: Dictionary = {}
## Echo calls the player made this battle (WildRules bond statistics).
var bond_tries: int = 0
## Spark training from battle (GrowthRules.battle_spark): chance per fighter and fallen foe; 0 off.
var battle_spark_chance: float = 0.0
## Accuracy factor of a wild battle under a foggy sky (WildRules.sight_mult); 1 = clear.
var sight_mult: float = 1.0
var _spark_rng: RandomNumberGenerator = null
## True once the Rift boss has entered its second phase.
var boss_phase_done: bool = false
## Late boss phases (BossRules.LATE_PHASES) already reached.
var boss_late_done: int = 0
## Weak point after a phase change (BossRules, item 431): turn it ends on and the stages to give back.
var _boss_weak_until: int = -1
var _boss_weak_back: Dictionary = {}
## Warden rule id (BattleRules.RULES) for the foe side, or "".
var foe_rule: String = ""
## Turns left on each side's Calm Veil (status_veil effect, item 193): no foe status takes hold.
var status_veil: Array[int] = [0, 0]
## Spirlings whose Mirror Scale (held "status_reflect", item 209) was used this battle.
var _reflected: Array[Spirling] = []
## Snares lying on each side (side_snare effect), oldest first. Each is {"move": name, plus
## "hp" (share of max Vigor), "status" or "stage"}. The next Spirling to swap in springs one.
var snares: Array[Array] = [[], []]
## Delayed hits on their way (delayed_hit effect, item 451), oldest first. Each is {"side", "slot"
## (the slot it lands on), "amount", "eff", "move", "turns" (end-of-turn ticks left, the use turn counts)}.
var delayed_hits: Array[Dictionary] = []
## Turn each Spirling last stepped onto the field (by swap or after a faint). The AI uses it to
## stop two sides from swapping back and forth forever.
var entered_turn: Dictionary = {}
## KAMPF_PLAN (Zugablauf, Energie).
## Share of max Vigor a player Spirling mends when it rests (Story, item 52); 0 = none.
var rest_heal_share: float = 0.0
## A lingering status (StatusRules.lingers) stays on the player's Spirlings after this battle
## (item 179). The overworld sets it for world battles off Story; sims and duels leave it false.
var keep_status: bool = false
## Wild ambush from the tall fern (item 16): in the first turn the foe acts before everything.
var ambush: bool = false
## KAMPF_PLAN_1000 items 9, 10 (TurnFlow): in a 1v1 Wayfarer battle the foe names its next
## Spirling after a knock-out (foe_announce), and with shift_offer the player may swap first.
var shift_offer: bool = false
var foe_announce: bool = false
## Party index of the foe's named next Spirling while the phase is AWAIT_SHIFT, else -1.
var shift_next: int = -1
## AiNotes level (items 451, 467): OFF, REASON (replays) or TABLE (developer view).
var explain_ai: int = AiNotes.OFF
## Bosses only (item 21): after this many turns the Rift closes and the fight ends as FLED.
const BOSS_ROUND_LIMIT: int = 30
## Story values for foe_crit_mult (set by ChallengeRules) and rest_heal_share (items 36, 52).
const STORY_FOE_CRIT: float = 0.5
const STORY_REST_HEAL: float = 0.05
## Chance that a wild encounter in tall fern opens with an ambush (item 16).
const AMBUSH_CHANCE: float = 0.06

var _queue: Array[BattleAction] = []
## Battle state of the Kampf plan's gifts and keepsakes (TraitKit): shown gifts, used talismans.
var kit: Dictionary = {}
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

## Party index standing in [param slot] for [param side], or -1.
func active_index(side: int, slot: int = 0) -> int:
	var row: Array = slots[side]
	return int(row[slot]) if slot >= 0 and slot < row.size() else -1

## The Spirling in [param slot] for [param side], or null if the slot is empty.
func active_spirling(side: int, slot: int = 0) -> Spirling:
	var i: int = active_index(side, slot)
	return parties[side][i] if i >= 0 else null

func slot_count(side: int) -> int:
	return (slots[side] as Array).size()

## The field slot holding party index [param index], or -1 if it is on the bench.
func slot_of(side: int, index: int) -> int:
	return (slots[side] as Array).find(index)

## True for a battle with more than one Spirling on either side (uses the formation layout).
func is_multi() -> bool:
	return front_size[Side.PLAYER] + partner_front > 1 or front_size[Side.FOE] > 1

## Still in the fight: not fainted and not just bonded away.
func is_standing(s: Spirling) -> bool:
	return s != null and not s.is_fainted() and s != bonded

## Slots on [param side] whose Spirling is still standing, left to right.
func standing_slots(side: int) -> Array[int]:
	var out: Array[int] = []
	for slot: int in slot_count(side):
		if is_standing(active_spirling(side, slot)):
			out.append(slot)
	return out

## True if party index [param index] on [param side] belongs to the ally Wayfarer.
func is_partner_index(side: int, index: int) -> bool:
	return side == Side.PLAYER and partner_start >= 0 and index >= partner_start

## True if [param slot] on [param side] is steered by the ally Wayfarer.
func is_partner_slot(side: int, slot: int) -> bool:
	return side == Side.PLAYER and _partner_slot >= 0 and slot >= _partner_slot

## Player slots the player picks an action for this turn (own, standing), left to right.
func player_slots() -> Array[int]:
	var out: Array[int] = []
	for slot: int in standing_slots(Side.PLAYER):
		if not is_partner_slot(Side.PLAYER, slot):
			out.append(slot)
	return out

static func other(side: int) -> int:
	return 1 - side

## The first foe of [param side] still standing (slot 0's Spirling if none is).
func opponent(side: int) -> Spirling:
	var st: Array[int] = standing_slots(other(side))
	return active_spirling(other(side), st[0] if not st.is_empty() else 0)

## Foe slot the player's own first art aims at in [param actions], or -1.
func _player_aim(actions: Array[BattleAction]) -> int:
	for a: BattleAction in actions:
		if a != null and a.side == Side.PLAYER and a.kind == BattleAction.Kind.MOVE and not is_partner_slot(Side.PLAYER, a.slot):
			return a.target_slot
	return -1

func alive_count(side: int) -> int:
	var n: int = 0
	for s: Spirling in parties[side]:
		if is_standing(s):
			n += 1
	return n

## Standing Spirlings the player owns (the ally Wayfarer's do not count toward a loss).
func own_alive_count() -> int:
	var n: int = 0
	for i: int in parties[Side.PLAYER].size():
		if not is_partner_index(Side.PLAYER, i) and is_standing(parties[Side.PLAYER][i]):
			n += 1
	return n

## Adds an ally Wayfarer for a tag battle: [param team] fights beside the player, [param front] of
## them at once, steered by an AI of [param ai_level]. Call before start().
func set_partner(p_name: String, team: Array[Spirling], front: int = 1, ai_level: int = 1, profile_name: String = "") -> void:
	if team.is_empty():
		return
	var combined: Array[Spirling] = []
	for s: Spirling in parties[Side.PLAYER]:
		combined.append(s)
	partner_start = combined.size()
	for s: Spirling in team:
		combined.append(s)
	parties[Side.PLAYER] = combined
	partner_name = p_name
	partner_front = clampi(front, 1, BattleRules.MAX_FRONT)
	partner_ai = BattleAI.new(ai_level, profile_name)

func is_finished() -> bool:
	return phase == Phase.FINISHED

func needs_player_switch() -> bool:
	return phase == Phase.AWAIT_SWITCH

## Bench indices that could step into [param slot] for [param side] (same owner as the slot).
func swap_candidates(side: int, slot: int = 0) -> Array[int]:
	var out: Array[int] = []
	var partner_slot: bool = is_partner_slot(side, slot)
	var row: Array = slots[side]
	for i: int in parties[side].size():
		var s: Spirling = parties[side][i]
		if not row.has(i) and is_standing(s) and is_partner_index(side, i) == partner_slot:
			out.append(i)
	return out

## Every legal action for the Spirling in [param slot] of [param side] this turn. REST is always
## legal. Move actions carry target_slot -1 (the first foe standing); callers may aim them.
func legal_actions(side: int, slot: int = 0) -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	var me: Spirling = active_spirling(side, slot)
	if not is_standing(me):
		return out
	var any_move: bool = false
	for i: int in me.moves.size():
		if me.can_afford(me.moves[i]) and not move_locked(me.moves[i]):
			out.append(BattleAction.make_move(side, i, slot))
			any_move = true
	if can_rest(any_move):
		out.append(BattleAction.make_rest(side, slot))
	if (not StatusRules.blocks_swap(me.status) or TraitKit.free_swap(me)) and not (swap_locked and side == Side.PLAYER):
		for i: int in swap_candidates(side, slot):
			out.append(BattleAction.make_swap(side, i, slot))
	if _items_allowed_for(side, slot):
		for id: String in bag_ids(side):
			if _is_battle_item(id) and not (side == Side.PLAYER and id in blocked_items):
				var ia := BattleAction.make_item(side, id, active_index(side, slot), slot)
				# Revive items and spent per-battle limits do not fit the active Spirling.
				if is_legal(ia):
					out.append(ia)
	if side == Side.PLAYER and is_wild and not is_partner_slot(side, slot):
		if bonded == null and bond_block.is_empty():
			out.append(BattleAction.make_bond(side, 0.0, "", slot))
		out.append(BattleAction.make_run(side, slot))
	return out

## Checks a single action against the current state.
func is_legal(a: BattleAction) -> bool:
	var me: Spirling = active_spirling(a.side, a.slot)
	if not is_standing(me):
		return false
	match a.kind:
		BattleAction.Kind.MOVE:
			if a.target_slot >= slot_count(other(a.side)):
				return false
			return a.move_index >= 0 and a.move_index < me.moves.size() and me.can_afford(me.moves[a.move_index]) \
				and not move_locked(me.moves[a.move_index])
		BattleAction.Kind.REST:
			var any_move: bool = false
			for mv: MoveData in me.moves:
				any_move = any_move or (me.can_afford(mv) and not move_locked(mv))
			return can_rest(any_move)
		BattleAction.Kind.SWAP:
			# Trading places with an ally in another slot (item 366) is a Swap too.
			if a.swap_index in MultiRules.shift_targets(self, a.side, a.slot):
				return true
			return (not StatusRules.blocks_swap(me.status) or TraitKit.free_swap(me)) and a.swap_index in swap_candidates(a.side, a.slot) \
				and not (swap_locked and a.side == Side.PLAYER)
		BattleAction.Kind.ITEM:
			if KeepsakeKit.is_swap(a):
				return KeepsakeKit.swap_legal(self, a)
			if not _items_allowed_for(a.side, a.slot) or bag_count(a.side, a.item_id) <= 0 or not _is_battle_item(a.item_id):
				return false
			if a.side == Side.PLAYER and a.item_id in blocked_items:
				return false
			if is_partner_index(a.side, a.item_target):
				return false
			if not item_left_this_battle(a.side, a.item_id):
				return false
			if a.item_target < 0 or a.item_target >= parties[a.side].size():
				return false
			# A revive item (the shop's Rift Breath) wants a defeated Spirling, every other one a standing one.
			return (parties[a.side][a.item_target] as Spirling).is_fainted() == is_revive_item(a.item_id)
		BattleAction.Kind.BOND:
			# The Echo call reaches only wild Spirlings, never a Wayfarer's partner.
			if a.side != Side.PLAYER or not is_wild or bonded != null or is_partner_slot(a.side, a.slot) or not bond_block.is_empty():
				return false
			if a.target_slot >= 0 and not is_standing(active_spirling(Side.FOE, a.target_slot)):
				return false
			return a.item_id.is_empty() or int(inventory.get(a.item_id, 0)) > 0
		BattleAction.Kind.RUN:
			return a.side == Side.PLAYER and is_wild and not is_partner_slot(a.side, a.slot)
		BattleAction.Kind.OATH:
			return can_oath(a.side, a.slot)
	return false

## True while the Spirling in [param slot] may swear the Ink Oath: once per battle and side,
## only against another Wayfarer, never by a partner. Kept out of legal_actions() so the AI and
## the balance runs play as before; the command menu offers it in the Bond button's place.
func can_oath(side: int, slot: int = 0) -> bool:
	return not is_wild and not oath_used[side] and not is_partner_slot(side, slot) \
		and is_standing(active_spirling(side, slot)) and not BattleRules.oath().is_empty()

# --- Commands ----------------------------------------------------------------

## Intro: both sides step out. Returns the intro events.
func start() -> Array[BattleEvent]:
	_events = []
	rules = BattleRules.variant_values(variants)
	if rules.is_empty():
		push_warning("BattleModel: rule variants %s don't go together; playing normal rules" % [variants])
		variants = []
		rules = BattleRules.VARIANT_KEYS.duplicate()
	var hp_scale: float = float(rules.hp_mult)
	for side: int in [Side.PLAYER, Side.FOE]:
		# Warden rule Low Tide (item 54) costs the player's side Energy at the start.
		var cut: int = start_energy_cut[side] + (int(BattleRules.rule_number(foe_rule, "player_energy_cut")) if side == Side.PLAYER else 0)
		for s: Spirling in parties[side]:
			s.energy = maxi(0, mini(int(rules.start_energy), max_energy()) + energy_bonus[side] - cut)
			# An Energy Crystal (item 43) or any gift with "start_energy" adds to the start, up to the cap.
			var head: int = int(BattleRules.add_key(s, "start_energy"))
			if head > 0:
				s.energy = mini(s.energy + head, max_energy_of(side))
			s.energy = mini(s.energy + TraitKit.energy_cap(s), max_energy_of(side) + TraitKit.energy_cap(s))
			if hp_scale != 1.0:
				var share: float = float(s.hp) / float(s.max_hp())
				s.hp_mult *= hp_scale
				s.hp = maxi(1 if share > 0.0 else 0, roundi(s.max_hp() * share))
	if warden_weakened:
		for s: Spirling in parties[Side.FOE]:
			if s.hp > 0:
				s.hp = maxi(1, roundi(s.hp * WARDEN_WEAKEN_SHARE))
	_fill_initial_slots()
	for side: int in [Side.PLAYER, Side.FOE]:
		_shield_on[side] = active_spirling(side) if int(amulets[side][2]) > 0 else null
	base_field = field
	_sync_field_costs()
	field_turns = 0
	field_lock = 0
	snares = [[], []]
	support = [{}, {}]
	delayed_hits = []
	boss_phase_done = false
	boss_late_done = 0
	_boss_weak_until = -1
	_boss_weak_back = {}
	var fielded: int = slot_count(Side.PLAYER)
	if BattleRules.BOSSES.has(foe_boss):
		var boss: Spirling = active_spirling(Side.FOE)
		boss.hp_mult = BattleRules.boss_hp_mult(foe_boss, fielded, boss_hp_scale)
		boss.hp = boss.max_hp()
		boss.boss_guard = true
		_boss_actions = BattleRules.boss_actions_for(foe_boss, fielded, boss_difficulty)
	var foe: Spirling = active_spirling(Side.FOE)
	emit_event(BattleEvent.Type.BATTLE_START, {"wild": is_wild, "trainer": trainer_name, "foe_name": foe.display_name(),
		"prism": foe.prism, "gleam": foe.gleam, "count": slot_count(Side.FOE), "multi": is_multi(), "boss": BattleRules.BOSSES.has(foe_boss)})
	if not is_wild:
		_battle_line("motto")
		# KAMPF_PLAN_1000 items 523-525: the foe Wayfarer names its tactic.
		if not foe_theme_line.is_empty() and not trainer_name.is_empty():
			emit_event(BattleEvent.Type.BATTLE_LINE, {"side": Side.FOE, "name": trainer_name, "kind": "theme", "text": foe_theme_line})
		for slot: int in slot_count(Side.FOE):
			emit_event(BattleEvent.Type.SEND_OUT, _who(Side.FOE, slot))
	for slot: int in slot_count(Side.PLAYER):
		if slot == _partner_slot:
			emit_event(BattleEvent.Type.PARTNER, {"side": Side.PLAYER, "slot": slot, "partner": partner_name})
		emit_event(BattleEvent.Type.SEND_OUT, _who(Side.PLAYER, slot))
	_wild_opening(foe)
	if ambush and is_wild:
		emit_event(BattleEvent.Type.AMBUSH, _who(Side.FOE, 0))
	if BattleRules.BOSSES.has(foe_boss):
		var b: Dictionary = BattleRules.BOSSES[foe_boss]
		emit_event(BattleEvent.Type.BOSS, {"side": Side.FOE, "slot": 0, "boss": foe_boss, "label": str(b.label), "text": str(b.text),
			"actions": _boss_actions, "hp": foe.hp, "max_hp": foe.max_hp()})
	var edge: String = ShopEffects.edge_line(seals[Side.PLAYER], amulets[Side.PLAYER])
	if not edge.is_empty():
		emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.PLAYER, "text": edge})
	if warden_weakened:
		emit_event(BattleEvent.Type.WARDEN_WEAKENED, {"side": Side.FOE, "trainer": trainer_name})
	if BattleRules.FIELDS.has(field):
		emit_event(BattleEvent.Type.FIELD, {"field": field, "text": field_intro if not field_intro.is_empty() else str(BattleRules.FIELDS[field].intro)})
	# Every variant in play gets its own banner with its seal (item 796).
	var all_variants: Dictionary = BattleRules.variants()
	for id: String in variants:
		var v: Dictionary = all_variants[id]
		emit_event(BattleEvent.Type.RULE, {"variant": id, "label": str(v.label), "text": str(v.text), "symbol": str(v.get("symbol", ""))})
	for rule_id: String in BattleRules.split_rules(foe_rule):
		var rule: Dictionary = BattleRules.RULES[rule_id]
		emit_event(BattleEvent.Type.RULE, {"rule": rule_id, "label": str(rule.label), "text": str(rule.text)})
		var opening: Dictionary = rule.get("field_opening", {})
		if not opening.is_empty():
			set_field(str(opening.field), int(opening.get("turns", BattleRules.RESONANCE_TURNS)))
			if bool(opening.get("locked", false)):
				field_lock = field_turns
		var cycle: Dictionary = rule.get("field_cycle", {})
		if not cycle.is_empty():
			# Between the tides there is no field at all, not even the place's own.
			base_field = ""
			set_field(str(cycle.field), int(cycle.get("on", 2)))
		var st: Dictionary = rule.get("player_stage", {})
		var dragged: Array = parties[Side.PLAYER].slice(0, 1) if bool(rule.get("lead_only", false)) else parties[Side.PLAYER]
		for s: Spirling in dragged:
			for stat: String in st:
				s.stages[stat] = clampi(s.stage(stat) + int(st[stat]), BattleRules.STAGE_MIN, BattleRules.STAGE_MAX)
	MultiRules.apply_formation_bonus(self)
	TraitKit.on_start(self)
	participants = []
	for slot: int in player_slots():
		participants.append(active_spirling(Side.PLAYER, slot))
	phase = Phase.CHOOSE_ACTIONS
	return _events

## Plays one turn of a 1v1 battle. [param foe_action] defaults to the AI's choice.
func submit_turn(player_action: BattleAction, foe_action: BattleAction = null) -> Array[BattleEvent]:
	var acts: Array[BattleAction] = []
	if player_action != null:
		acts.append(player_action)
	if foe_action != null:
		acts.append(foe_action)
	return submit_actions(acts)

## Plays one turn. [param actions] holds at most one action per (side, slot). A player slot
## without a legal action rests; foe and ally slots without one let their AI choose.
func submit_actions(actions: Array[BattleAction]) -> Array[BattleEvent]:
	_events = []
	# A swap offer left open is declined: the named foe steps out first (item 9).
	if phase == Phase.AWAIT_SHIFT:
		_end_shift(-1)
	if phase != Phase.CHOOSE_ACTIONS:
		push_error("BattleModel.submit_actions called in phase %s" % Phase.keys()[phase])
		return _events
	_queue = []
	for side: int in [Side.PLAYER, Side.FOE]:
		for slot: int in slot_count(side):
			if not is_standing(active_spirling(side, slot)):
				continue
			var a: BattleAction = _given(actions, side, slot)
			if a != null and not is_legal(a):
				a = null
			if a == null:
				if side == Side.PLAYER and not is_partner_slot(side, slot):
					a = BattleAction.make_rest(side, slot)
				else:
					if side == Side.PLAYER:
						# Item 628: the partner knows which foe the player goes for this turn.
						partner_ai.ally_target = _player_aim(actions)
					a = (partner_ai if side == Side.PLAYER else ai).choose(self, side, slot)
					if side == Side.FOE and explain_ai > AiNotes.OFF:
						_events.append(AiNotes.note(self, ai, a, explain_ai))
			_queue.append(a)
			if side == Side.FOE and slot == 0 and _boss_actions > 1:
				for i: int in _boss_actions - 1:
					var extra: BattleAction = ai.choose(self, side, slot)
					extra.is_bonus = true
					_queue.append(extra)
	phase = Phase.RESOLVE_ORDER
	_run()
	return _events

## The player slot that the next submit_switch fills (phase AWAIT_SWITCH).
func switch_slot() -> int:
	return pending_switch[0] if not pending_switch.is_empty() else 0

## Picks the player's replacement after a faint (phase AWAIT_SWITCH). With several fainted
## slots, call it once per slot (switch_slot() says which one is next).
func submit_switch(index: int) -> Array[BattleEvent]:
	_events = []
	var slot: int = switch_slot()
	if phase != Phase.AWAIT_SWITCH or not index in swap_candidates(Side.PLAYER, slot):
		push_error("BattleModel.submit_switch: illegal switch to %d" % index)
		return _events
	pending_switch.pop_front()
	_swap_in(Side.PLAYER, index, slot)
	while not pending_switch.is_empty() and swap_candidates(Side.PLAYER, pending_switch[0]).is_empty():
		slots[Side.PLAYER][pending_switch.pop_front()] = -1
	phase = Phase.AWAIT_SWITCH if not pending_switch.is_empty() else Phase.CHOOSE_ACTIONS
	return _events

func needs_shift_choice() -> bool:
	return phase == Phase.AWAIT_SHIFT

## Answers the swap offer (item 9): [param index] is the bench Spirling to send out first, -1 to
## stay. Then the foe's named Spirling steps out.
func submit_shift(index: int) -> Array[BattleEvent]:
	_events = []
	if phase != Phase.AWAIT_SHIFT:
		push_error("BattleModel.submit_shift called in phase %s" % Phase.keys()[phase])
		return _events
	_end_shift(index)
	return _events

## Gives up the battle (item 8): it counts as a loss. Only against a Wayfarer.
func forfeit() -> Array[BattleEvent]:
	_events = []
	if is_finished() or is_wild:
		return _events
	if phase == Phase.AWAIT_SHIFT:
		_end_shift(-1)
		_events = []
	emit_event(BattleEvent.Type.TECHNIQUE, {"side": Side.PLAYER, "text": "You give up. %s doesn't even pretend to be surprised.", "args": [trainer_name if not trainer_name.is_empty() else "The foe"]})
	outcome = Outcome.LOSS
	_phase_rewards()
	return _events

## The player may swap before the foe's next Spirling steps out (item 9).
func _shift_open() -> bool:
	if not shift_offer or not is_standing(active_spirling(Side.PLAYER)) or swap_locked:
		return false
	var me: Spirling = active_spirling(Side.PLAYER)
	if StatusRules.blocks_swap(me.status) and not TraitKit.free_swap(me):
		return false
	return not swap_candidates(Side.PLAYER).is_empty()

## A 1v1 Wayfarer's emptied slot: names the next Spirling (item 10) and, with the swap offer,
## holds it back until submit_shift. True when the slot was handled here.
func _announce_next(slot: int) -> bool:
	if is_wild or is_multi() or trainer_name.is_empty() or not (shift_offer or foe_announce):
		return false
	if is_standing(active_spirling(Side.FOE, slot)):
		return false
	var index: int = ai.choose_replacement(self, Side.FOE, slot)
	if index < 0:
		return false
	if foe_announce:
		emit_event(BattleEvent.Type.BATTLE_LINE, {"side": Side.FOE, "name": trainer_name, "kind": "announce",
			"text": TurnFlow.announce_line((parties[Side.FOE][index] as Spirling).display_name())})
	if _shift_open():
		shift_next = index
	else:
		_swap_in(Side.FOE, index, slot)
	return true

func _end_shift(index: int) -> void:
	if index >= 0 and index in swap_candidates(Side.PLAYER):
		var a := BattleAction.make_swap(Side.PLAYER, index)
		a.actor = active_spirling(Side.PLAYER)
		_do_swap(a)
	if shift_next >= 0:
		_swap_in(Side.FOE, shift_next, 0)
	shift_next = -1
	phase = Phase.CHOOSE_ACTIONS

# --- Helpers used by effects --------------------------------------------------

func emit_event(t: BattleEvent.Type, d: Dictionary = {}) -> void:
	var e := BattleEvent.new(t, d)
	_events.append(e)
	event_emitted.emit(e)
	TechniqueRules.observe(self, e)

## The foe Wayfarer's personality line of [param kind] (items 621, 624): the motto at the start,
## then each fall line at most once per battle. Only for a named trainer with a profile line.
func _battle_line(kind: String) -> void:
	if is_wild or trainer_name.is_empty() or _lines_said.has(kind):
		return
	var text: String = ai.line(kind)
	if text.is_empty():
		return
	_lines_said[kind] = true
	emit_event(BattleEvent.Type.BATTLE_LINE, {"side": Side.FOE, "name": trainer_name, "kind": kind, "text": text})

## The Warden turning point (items 678, 679): its fixed line, a RULE banner marked "turning" and the
## stronger rule for the rest of the battle. Happens once, only for rules with a "turning" block.
func _turn_rules() -> bool:
	if rule_turned or is_wild:
		return false
	for rule_id: String in BattleRules.split_rules(foe_rule):
		var t: Dictionary = BattleRules.turning(rule_id)
		if t.is_empty():
			continue
		rule_turned = true
		if not trainer_name.is_empty():
			emit_event(BattleEvent.Type.BATTLE_LINE, {"side": Side.FOE, "name": trainer_name, "kind": "turning", "text": str(t.line)})
		var text: String = str(t.get("full_text", t.text)) if rule_turn_full else str(t.text)
		emit_event(BattleEvent.Type.RULE, {"rule": rule_id, "label": str(BattleRules.RULES[rule_id].label), "text": text, "turning": true})
		if int(t.get("foe_energy_once", 0)) > 0:
			for fs: int in slot_count(Side.FOE):
				var f: Spirling = active_spirling(Side.FOE, fs)
				if f != null and not f.is_fainted():
					change_energy(Side.FOE, int(t.foe_energy_once), fs)
		var st: Dictionary = t.get("next_in_stage", {})
		for stat: String in st:
			_turn_drag[stat] = int(_turn_drag.get(stat, 0)) + int(st[stat])
	return rule_turned

## Spirlings whose Hold Stone already worked in this battle.
var _endured: Array[Spirling] = []

## Damages the Spirling in [param slot] of [param side]. Emits DAMAGE and, if it drops, FAINTED.
func deal_damage(side: int, amount: int, extra: Dictionary = {}, slot: int = 0) -> int:
	var s: Spirling = active_spirling(side, slot)
	if s == null:
		return 0
	var dealt: int = mini(amount, s.hp)
	# Hold Stone (shop item 4403): once per battle a hit from full Vigor leaves 1 Vigor.
	var endured: bool = false
	if dealt >= s.hp and s.hp > 1 and s.hp >= s.max_hp() and not bool(extra.get("status_tick", false)) \
			and bool(BattleRules.held_info(s.held).get("endure_full", false)) and not _endured.has(s):
		_endured.append(s)
		dealt = s.hp - 1
		endured = true
	s.hp -= dealt
	var d: Dictionary = _who(side, slot)
	d.merge({"amount": dealt, "hp": s.hp, "max_hp": s.max_hp()})
	d.merge(extra)
	emit_event(BattleEvent.Type.DAMAGE, d)
	if endured:
		emit_event(BattleEvent.Type.HELD_ENDURE, _who(side, slot))
	if s.is_fainted():
		emit_event(BattleEvent.Type.FAINTED, _who(side, slot))
		# A wild horde wavers once its leader falls (WildRules.horde_leader, KAMPF_PLAN).
		if side == Side.FOE and is_wild and alive_count(Side.FOE) > 0 and WildRules.horde_leader(parties[Side.FOE]) == s:
			_horde_wavers()
		if side == Side.FOE:
			# A Warden at its turning point says its fixed line instead of the profile's "last" one.
			if not (alive_count(Side.FOE) == 1 and _turn_rules()):
				_battle_line("last" if alive_count(Side.FOE) == 1 else "own_fall")
		elif not is_partner_slot(side, slot):
			_battle_line("foe_fall")
	elif side == Side.FOE and slot == 0 and dealt > 0:
		_check_boss_phase(s)
	if not s.is_fainted():
		eat_pith(side, slot)
	return dealt

## The horde's leader fell: every foe still standing loses one stage of Might.
func _horde_wavers() -> void:
	emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.FOE, "text": WildRules.WAVER_LINE})
	for slot: int in standing_slots(Side.FOE):
		change_stage(Side.FOE, "atk", -1, slot)

## Pith Fruit (era function "pith_fruit", Era II): a held fruit the holder eats by itself, once.
## "pith_heal": at half its Vigor or less it heals that share of its Vigor (also through a heal
## block, like a bag item); "pith_cure": a condition is washed away at once. The fruit is gone
## for good afterwards. Returns true when it ate one.
func eat_pith(side: int, slot: int = 0) -> bool:
	var index: int = active_index(side, slot)
	if index < 0:
		return false
	var s: Spirling = parties[side][index]
	if s.is_fainted() or s.held.is_empty():
		return false
	var h: Dictionary = BattleRules.held_info(s.held)
	var heal_share: float = float(h.get("pith_heal", 0.0))
	var heals: bool = heal_share > 0.0 and s.hp * 2 <= s.max_hp()
	var cures: bool = bool(h.get("pith_cure", false)) and not s.status.is_empty()
	if not heals and not cures:
		return false
	var d: Dictionary = _who(side, slot)
	d["item_name"] = str(Database.item(s.held).get("name", s.held))
	d["item"] = s.held
	s.held = ""
	emit_event(BattleEvent.Type.HELD_FRUIT, d)
	if heals:
		_heal_spirling(side, index, maxi(1, roundi(s.max_hp() * heal_share)))
	else:
		var c: Dictionary = _who(side, slot)
		c["status"] = s.status
		s.status = ""
		s.status_turns = 0
		emit_event(BattleEvent.Type.STATUS_CURED, c)
	return true

## Shows the trait of the Spirling in [param slot] the first time it matters in a battle (TRAIT).
func reveal_trait(side: int, slot: int = 0) -> void:
	var s: Spirling = active_spirling(side, slot)
	if s == null:
		return
	var t: Dictionary = BattleRules.trait_info(s.gift_id())
	if t.is_empty():
		return
	TraitKit.count_gift(self, side, slot, str(t.label))
	if s.has_meta("trait_shown"):
		return
	s.set_meta("trait_shown", true)
	var d: Dictionary = _who(side, slot)
	d.merge({"trait": s.gift_id(), "label": str(t.label), "text": str(t.text)})
	emit_event(BattleEvent.Type.TRAIT, d)

## Lays the Rift field [param id] for [param turns] turns (0 = for good). Emits FIELD.
func set_field(id: String, turns: int = BattleRules.RESONANCE_TURNS) -> bool:
	if not BattleRules.FIELDS.has(id):
		return false
	# A new field pushes the old one out, and the log says so (KAMPF_PLAN_1000 item 344).
	if not field.is_empty() and field != id:
		emit_event(BattleEvent.Type.FIELD_END, {"field": field, "label": str(BattleRules.FIELDS.get(field, {}).get("label", "")), "by": str(BattleRules.FIELDS[id].label)})
	var fresh: bool = field != id
	field = id
	if turns > 0:
		turns += RiftFields.daytime_turns(id, day_phase)
	field_turns = maxi(turns, 0)
	var f: Dictionary = BattleRules.FIELDS[id]
	_sync_field_costs()
	emit_event(BattleEvent.Type.FIELD, {"field": id, "label": str(f.label), "text": str(f.intro), "turns": field_turns})
	if fresh and phase != Phase.INTRO:
		for side: int in [Side.PLAYER, Side.FOE]:
			for slot: int in slot_count(side):
				var s: Spirling = active_spirling(side, slot)
				var gain: int = int(ShopEffects.gift_table(s).get("field_energy", 0)) if is_standing(s) else 0
				if gain > 0:
					reveal_trait(side, slot)
					change_energy(side, gain, slot)
	return true

## Stretches the Resonance field in play by [param turns]. Fails (FIELD_EXTENDED "failed") when
## there is none, or only the place's own field, which never runs out anyway.
func extend_field(turns: int) -> bool:
	if field.is_empty() or field_turns <= 0:
		emit_event(BattleEvent.Type.FIELD_EXTENDED, {"failed": true})
		return false
	field_turns += turns
	emit_event(BattleEvent.Type.FIELD_EXTENDED, {"field": field, "label": str(BattleRules.FIELDS[field].label), "turns": turns})
	return true

## Counts a Resonance field down at the end of a turn; when it runs out the place's field returns.
func _tick_field() -> void:
	if field_lock > 0:
		field_lock -= 1
	if field_turns <= 0:
		return
	field_turns -= 1
	if field_turns == 1:
		TechniqueRules.field_last_turn(self)
	if field_turns > 0:
		return
	var gone: String = field
	field = ""
	_sync_field_costs()
	emit_event(BattleEvent.Type.FIELD_END, {"field": gone, "label": str(BattleRules.FIELDS.get(gone, {}).get("label", ""))})
	if BattleRules.FIELDS.has(base_field):
		set_field(base_field, 0)

## Counts Energy taxes and cooldowns down for every Spirling (bench too). A tax that runs out
## on the field says so (ENERGY_TAX with 0 turns).
func _tick_timers() -> void:
	for side: int in [Side.PLAYER, Side.FOE]:
		for i: int in parties[side].size():
			var s: Spirling = parties[side][i]
			var taxed: bool = s.energy_tax > 0
			s.tick_timers()
			var slot: int = slot_of(side, i)
			if taxed and slot >= 0 and is_standing(s):
				var d: Dictionary = _who(side, slot)
				d.merge({"turns": maxi(0, s.energy_tax), "cost": BattleRules.ENERGY_TAX_COST})
				emit_event(BattleEvent.Type.ENERGY_TAX, d)

## Second boss phase: once the boss in foe slot 0 drops to the phase threshold, it wakes up once.
## Later phases (BossRules.LATE_PHASES) follow the same way, one per hit at most. While the boss's
## hold field lies, no phase starts (item 430).
func _check_boss_phase(boss: Spirling) -> void:
	if not BattleRules.BOSSES.has(foe_boss) or boss != parties[Side.FOE][active_index(Side.FOE)]:
		return
	if BossRules.held_by(foe_boss, field):
		return
	if not boss_phase_done:
		var p: Dictionary = BattleRules.boss_phase(foe_boss)
		if p.is_empty() or float(boss.hp) > float(boss.max_hp()) * BattleRules.boss_phase_at(foe_boss, boss_difficulty):
			return
		boss_phase_done = true
		if boss_difficulty >= 0 and boss_difficulty < BattleRules.BOSS_PHASE_BONUS.size():
			_boss_actions += BattleRules.BOSS_PHASE_BONUS[boss_difficulty]
		_enter_boss_phase(boss, p)
		return
	var late: Array = BossRules.late_phases(foe_boss)
	if boss_late_done < late.size() and float(boss.hp) <= float(boss.max_hp()) * float(late[boss_late_done].get("at", 0.0)):
		boss_late_done += 1
		_enter_boss_phase(boss, late[boss_late_done - 1])

## Announces phase [param p], applies its stages and field, then opens the weak point (item 431).
func _enter_boss_phase(boss: Spirling, p: Dictionary) -> void:
	# "phase" (2, then 3 and on) lets the scene change the music (item 406).
	emit_event(BattleEvent.Type.BOSS_PHASE, {"side": Side.FOE, "slot": 0, "name": boss.display_name(), "boss": foe_boss, "text": str(p.get("text", "")),
		"phase": 2 + boss_late_done})
	if p.get("guard") is Dictionary:
		BossRules.call_guard(self, boss, p.guard)
	var st: Dictionary = p.get("stage", {})
	for stat: String in st:
		change_stage(Side.FOE, stat, int(st[stat]), 0)
	if BattleRules.FIELDS.has(str(p.get("field", ""))):
		base_field = str(p.field)
		set_field(base_field, 0)
	_boss_weak_back = {}
	for stat: String in BossRules.WEAK_STAGE:
		var before: int = boss.stage(stat)
		change_stage(Side.FOE, stat, BossRules.WEAK_STAGE[stat], 0)
		if boss.stage(stat) != before:
			_boss_weak_back[stat] = before - boss.stage(stat)
	if not _boss_weak_back.is_empty():
		_boss_weak_until = turn + BossRules.WEAK_TURNS
		emit_event(BattleEvent.Type.BOSS_PHASE, {"side": Side.FOE, "slot": 0, "name": boss.display_name(), "boss": foe_boss, "weak": true,
			"text": "%s lies open: its Guard is down for a turn!" % boss.display_name()})

## End of turn for a Rift boss: the weak point closes, and a long fight enrages it (item 432).
func _boss_end_of_turn() -> void:
	if not BattleRules.BOSSES.has(foe_boss) or active_index(Side.FOE) < 0:
		return
	var boss: Spirling = parties[Side.FOE][active_index(Side.FOE)]
	if boss.is_fainted():
		return
	if _boss_weak_until >= 0 and turn >= _boss_weak_until:
		for stat: String in _boss_weak_back:
			change_stage(Side.FOE, stat, int(_boss_weak_back[stat]), 0)
		_boss_weak_back = {}
		_boss_weak_until = -1
	if BossRules.rage_due(turn):
		emit_event(BattleEvent.Type.BOSS_PHASE, {"side": Side.FOE, "slot": 0, "name": boss.display_name(), "boss": foe_boss, "rage": true,
			"text": "%s grows restless: the longer the fight, the harder it strikes!" % boss.display_name()})
		for stat: String in BossRules.RAGE_STAGE:
			change_stage(Side.FOE, stat, BossRules.RAGE_STAGE[stat], 0)

## True for the Rift boss in foe slot 0.
func is_boss_slot(side: int, slot: int) -> bool:
	return side == Side.FOE and slot == 0 and BattleRules.BOSSES.has(foe_boss)

## Heals the Spirling in [param slot] from an art, its gift, the field or a keepsake. A heal
## block stops all of these (bag items heal through _heal_spirling and still work).
func heal(side: int, amount: int, slot: int = 0) -> int:
	var index: int = active_index(side, slot)
	if index < 0:
		return 0
	var s: Spirling = parties[side][index]
	if turn >= BattleRules.WEARY_TURN:
		return 0
	if s.heal_block > 0:
		if s.hp < s.max_hp():
			emit_event(BattleEvent.Type.HEAL_BLOCKED, _who(side, slot))
		return 0
	# Warden rule Dry Well: every heal from arts, gifts and the field shrinks.
	var heal_mult: float = BattleRules.rule_number(foe_rule, "heal_mult")
	if heal_mult != 1.0:
		amount = maxi(1, int(amount * heal_mult))
	return _heal_spirling(side, index, amount)

## Blocks healing for the Spirling in [param slot] for the next [param turns] turns. Emits HEAL_BLOCKED.
func apply_heal_block(side: int, turns: int, slot: int = 0) -> void:
	var s: Spirling = active_spirling(side, slot)
	if s == null or s.is_fainted() or turns <= 0:
		return
	# +1 because the end of this very turn already counts one down.
	s.heal_block = turns + 1
	var d: Dictionary = _who(side, slot)
	d.merge({"turns": turns, "fresh": true})
	emit_event(BattleEvent.Type.HEAL_BLOCKED, d)

## Tries to afflict the Spirling in [param slot] of [param side]. Fails if it already has a status.
## [param from_side] is the side that causes it (-1 = none); a foe's status may meet a Status Ward.
## [param from_slot] is the slot of the Spirling that causes it (a Mirror Scale turns it back there).
func apply_status(side: int, status: String, slot: int = 0, from_side: int = -1, from_slot: int = -1) -> bool:
	var s: Spirling = active_spirling(side, slot)
	if s == null or s.is_fainted() or not StatusRules.exists(status):
		return false
	# A combo (StatusRules.COMBOS, item 169) may land on top of the status it reacts with.
	var combo: Dictionary = StatusRules.combo(s.status, status)
	if not s.status.is_empty() and combo.is_empty():
		return false
	if BattleRules.is_immune(s, status):
		reveal_trait(side, slot)
		var f: Dictionary = _who(side, slot)
		f["status"] = status
		emit_event(BattleEvent.Type.STATUS_FAILED, f)
		return false
	if BattleRules.field_blocks(field, status):
		var fb: Dictionary = _who(side, slot)
		fb.merge({"status": status, "field_label": str(BattleRules.FIELDS[field].label)})
		emit_event(BattleEvent.Type.STATUS_FAILED, fb)
		return false
	if calm_rule_blocks(side, s, status):
		var c: Dictionary = _who(side, slot)
		c.merge({"status": status, "clause": true})
		emit_event(BattleEvent.Type.STATUS_FAILED, c)
		return false
	var block: Dictionary = status_block(side, status, from_side)
	if not block.is_empty():
		var sb: Dictionary = _who(side, slot)
		sb.merge(block)
		sb["status"] = status
		emit_event(BattleEvent.Type.STATUS_FAILED, sb)
		return false
	if from_side >= 0 and from_side != side and bool(BattleRules.held_info(s.held).get("status_reflect", false)) and not s in _reflected:
		_reflected.append(s)
		var rf: Dictionary = _who(side, slot)
		rf.merge({"status": status, "reflect": true, "item_name": str(Database.item(s.held).get("name", s.held))})
		emit_event(BattleEvent.Type.STATUS_FAILED, rf)
		if from_slot >= 0:
			apply_status(from_side, status, from_slot)
		return false
	# Status Ward (pay-to-win step 4): only a foe's status, one roll only when the side owns it.
	var ward: float = ShopEffects.ward_chance(int(amulets[side][1])) if from_side >= 0 and from_side != side else 0.0
	if ward > 0.0 and rng.randf() < ward:
		var w: Dictionary = _who(side, slot)
		w.merge({"status": status, "ward": true})
		emit_event(BattleEvent.Type.STATUS_FAILED, w)
		return false
	s.status = status
	s.status_turns = StatusRules.roll_turns(status, rng)
	if is_boss_slot(side, slot):
		s.status_turns = BossRules.status_turns(s.status_turns)
	else:
		# Hush Core and other kit gifts (TraitKit); a boss slot already halves above.
		s.status_turns = TraitKit.status_turns(s, s.status_turns)
	var cap: int = int(rules.get("status_max_turns", 0))
	if cap > 0:
		s.status_turns = mini(s.status_turns, cap) if s.status_turns > 0 else cap
	if s.boss_guard and s.status_turns <= 0:
		s.status_turns = StatusRules.BOSS_OPEN_TURNS
	elif s.boss_guard and not is_boss_slot(side, slot):
		s.status_turns = StatusRules.boss_turns(s.status_turns)
	s.sure_skip = int(combo.get("sure_skip", 0))
	var d: Dictionary = _who(side, slot)
	d["status"] = status
	if not combo.is_empty():
		d["combo"] = str(combo.text)
	emit_event(BattleEvent.Type.STATUS_APPLIED, d)
	if status == "scorch" and ShopEffects.gift_table(s).has("scorch_atk"):
		reveal_trait(side, slot)
	eat_pith(side, slot)
	return true

## Damage factor of the variants in play: the own-element bonus ("stab") and the reaction
## strength ("reaction_scale" stretches a reaction's factor beyond 1.0).
func _variant_mult(me: Spirling, target: Spirling, mv: MoveData) -> float:
	var f: float = 1.0
	if not mv.neutral and mv.element in me.elements() and float(rules.stab) != DamageCalc.STAB:
		f *= float(rules.stab) / DamageCalc.STAB
	var scale: float = float(rules.reaction_scale)
	if scale != 1.0:
		var r: float = float(BattleRules.reaction(mv, target).get("mult", 1.0))
		if r > 1.0:
			f *= (1.0 + (r - 1.0) * scale) / r
	return f

## Why a status can't reach [param side] right now, as STATUS_FAILED data, or {}: the Warden
## rule Hushed Air (item 210, "no_status") keeps every status off both sides, and a Calm Veil
## (item 193) keeps the foe's statuses off its side.
func status_block(side: int, status: String, from_side: int = -1) -> Dictionary:
	if not StatusRules.exists(status):
		return {}
	for rule_id: String in BattleRules.split_rules(foe_rule):
		if float(BattleRules.RULES[rule_id].get("no_status", 0.0)) > 0.0:
			return {"rule_label": str(BattleRules.RULES[rule_id].label)}
	if from_side >= 0 and from_side != side and status_veil[side] > 0:
		return {"veil": true}
	return {}

## Lays a Calm Veil over [param side] for [param turns] turns. Emits STATUS_VEIL.
func set_status_veil(side: int, turns: int) -> void:
	# +1 because the end of this very turn already counts one down.
	status_veil[side] = maxi(status_veil[side], turns + 1)
	emit_event(BattleEvent.Type.STATUS_VEIL, {"side": side, "turns": turns, "fresh": true})

func _tick_status_veil() -> void:
	for side: int in [Side.PLAYER, Side.FOE]:
		if status_veil[side] <= 0:
			continue
		status_veil[side] -= 1
		if status_veil[side] == 0:
			emit_event(BattleEvent.Type.STATUS_VEIL, {"side": side, "turns": 0})

## Calm rule: in Wayfarer battles a side may have only one Spirling sleeping (Drowse) at a time.
func calm_rule_blocks(side: int, s: Spirling, status: String) -> bool:
	if is_wild or not StatusRules.sleeps(status):
		return false
	for other_s: Spirling in parties[side]:
		if other_s != s and not other_s.is_fainted() and StatusRules.sleeps(other_s.status):
			return true
	return false

## Moves a stat stage on the Spirling in [param slot] of [param side]. Emits STAT_CHANGED (or a "won't go" note).
func change_stage(side: int, stat: String, delta: int, slot: int = 0) -> void:
	var s: Spirling = active_spirling(side, slot)
	if s == null or s.is_fainted() or delta == 0 or not stat in BattleRules.STAGE_STATS:
		return
	if float(rules.get("stages_locked", 0.0)) > 0.0 or BattleRules.rule_number(foe_rule, "stages_locked") > 0.0:
		return
	if is_boss_slot(side, slot):
		delta = BossRules.stage_delta(delta)
	var before: int = s.stage(stat)
	var after: int = clampi(before + delta, BattleRules.STAGE_MIN, BattleRules.STAGE_MAX)
	var d: Dictionary = _who(side, slot)
	d.merge({"stat": stat, "delta": after - before, "stage": after, "tried": delta})
	# Item 227: a foe whose Might climbs to +2 gets a warning line.
	if side == Side.FOE and stat == "atk" and before < BattleRules.STAGE_WARN and after >= BattleRules.STAGE_WARN:
		d["warn"] = true
	s.stages[stat] = after
	emit_event(BattleEvent.Type.STAT_CHANGED, d)

## Puts an Energy tax on the Spirling in [param slot]: its moves cost more for the next
## [param turns] turns. Emits ENERGY_TAX.
func apply_energy_tax(side: int, turns: int, slot: int = 0) -> void:
	var s: Spirling = active_spirling(side, slot)
	if s == null or s.is_fainted() or turns <= 0:
		return
	# +1 because the end of this very turn already counts one down.
	s.energy_tax = turns + 1
	var d: Dictionary = _who(side, slot)
	d.merge({"turns": turns, "cost": BattleRules.ENERGY_TAX_COST, "fresh": true})
	emit_event(BattleEvent.Type.ENERGY_TAX, d)

func change_energy(side: int, delta: int, slot: int = 0) -> void:
	var s: Spirling = active_spirling(side, slot)
	if s == null:
		return
	var before: int = s.energy
	s.energy = clampi(s.energy + delta, 0, max_energy_of(side) + TraitKit.energy_cap(s))
	if s.energy != before:
		var d: Dictionary = _who(side, slot)
		d["energy"] = s.energy
		emit_event(BattleEvent.Type.ENERGY_CHANGED, d)

# --- Phases ------------------------------------------------------------------

func _run() -> void:
	while _handlers.has(phase):
		_handlers[phase].call()

func _phase_resolve_order() -> void:
	for a: BattleAction in _queue:
		a.actor = active_spirling(a.side, a.slot)
	# Shuffle first with the battle RNG so equal keys get a seeded tiebreak, then stable-sort.
	var tiebreak: Dictionary[BattleAction, float] = {}
	for a: BattleAction in _queue:
		tiebreak[a] = rng.randf()
	_queue.sort_custom(func(x: BattleAction, y: BattleAction) -> bool:
		return _sort_key(x, tiebreak[x]) > _sort_key(y, tiebreak[y]))
	_note_speed_ties()
	phase = Phase.EXECUTE_ACTION

## Item 4: when two arts of different sides meet with the same class, priority and Pace, the
## seeded coin decided; the log says so (SPEED_TIE names the one that won). Not in the dark
## (Warden rule Night Dark), where nobody sees the Pace anyway.
func _note_speed_ties() -> void:
	if BattleRules.rule_number(foe_rule, "hidden_order") > 0.0:
		return
	for i: int in _queue.size() - 1:
		var x: BattleAction = _queue[i]
		var y: BattleAction = _queue[i + 1]
		if x.side == y.side or x.kind != BattleAction.Kind.MOVE or y.kind != BattleAction.Kind.MOVE:
			continue
		var kx: Vector4 = _sort_key(x, 0.0)
		if kx == _sort_key(y, 0.0) and not x.is_bonus and not y.is_bonus:
			var d: Dictionary = _who(x.side, x.slot)
			d["other"] = y.actor.display_name() if y.actor != null else ""
			emit_event(BattleEvent.Type.SPEED_TIE, d)

## Larger key acts first: lower action class, then higher priority, then higher SPD, then RNG.
func _sort_key(a: BattleAction, tie: float) -> Vector4:
	var prio: int = 0
	if a.kind == BattleAction.Kind.MOVE and a.actor != null and a.move_index < a.actor.moves.size():
		prio = a.actor.moves[a.move_index].priority + TraitKit.priority_bonus(self, a)
	var spd: int = int(a.actor.effective_spd() * ShopEffects.seal_speed_mult(int(seals[a.side][2]))) if a.actor != null else 0
	# Warden rule Night Dark: Pace stays hidden in the dark, the seeded tiebreak decides.
	if BattleRules.rule_number(foe_rule, "hidden_order") > 0.0:
		spd = 0
	var cls: float = -a.order_class()
	# An ambush (item 16): in the first turn the wild foe moves before any action of the player.
	if ambush and turn == 0 and a.side == Side.FOE:
		cls = 1.0
	return Vector4(cls, prio, spd, tie)

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
	if not is_standing(a.actor) or a.actor != active_spirling(a.side, a.slot):
		return
	if a.is_free:
		emit_event(BattleEvent.Type.FREE_ACTION, _who(a.side, a.slot))
	elif a.is_bonus:
		# A boss's extra action is marked as its reverb (item 11).
		emit_event(BattleEvent.Type.BONUS_ACTION, _who(a.side, a.slot))
	match a.kind:
		BattleAction.Kind.MOVE: _do_move(a)
		BattleAction.Kind.REST: _do_rest(a)
		BattleAction.Kind.SWAP: _do_swap(a)
		BattleAction.Kind.ITEM: _do_item(a)
		BattleAction.Kind.BOND: _do_bond(a)
		BattleAction.Kind.RUN: _do_run(a)
		BattleAction.Kind.OATH: _do_oath(a)
	TechniqueRules.note_acted(self, a)

func _phase_end_of_turn() -> void:
	for side: int in [Side.PLAYER, Side.FOE]:
		for slot: int in slot_count(side):
			_end_of_turn_for(side, slot)
	_vine_heal()
	_sand_chip()
	_tick_timers()
	_tick_status_veil()
	_tick_field()
	MultiRules.tick(self)
	_tick_field_swirl()
	_tick_field_cycle()
	_tick_delayed_hits()
	_boss_end_of_turn()
	_turn_wheel()
	if turn == BattleRules.WEARY_TURN:
		emit_event(BattleEvent.Type.WEARY, {"turn": turn})
	_weary_chip()
	turn += 1
	phase = Phase.FAINT_CHECK

## The next wheel member after the front of [param side], or -1 (none standing, or no wheel).
func wheel_next(side: int) -> int:
	if not wheel or is_multi() or slot_count(side) != 1:
		return -1
	var cur: int = active_index(side)
	var team: Array = parties[side]
	var size: int = mini(wheel_size, team.size())
	if cur < 0 or cur >= size or (team[cur] as Spirling).is_fainted():
		return -1
	for step: int in range(1, size):
		var i: int = (cur + step) % size
		if not (team[i] as Spirling).is_fainted():
			return i
	return -1

func _turn_wheel() -> void:
	if not wheel or is_finished():
		return
	var moved: bool = false
	for side: int in [Side.PLAYER, Side.FOE]:
		var nxt: int = wheel_next(side)
		if nxt < 0:
			continue
		if not moved:
			emit_event(BattleEvent.Type.WHEEL_TURN, {})
			moved = true
		emit_event(BattleEvent.Type.SWAP_OUT, _who(side, 0))
		_swap_in(side, nxt, 0)

## True when the variants in play take [param mv] off the menu (stage-only arts under "stages_locked").
func move_locked(mv: MoveData) -> bool:
	return float(rules.get("stages_locked", 0.0)) > 0.0 and BattleRules.stage_only(mv)

## Whether Rest is on offer; under "rest_only_as_pass" only when no art can be paid ([param any_move] false).
func can_rest(any_move: bool) -> bool:
	return float(rules.get("rest_only_as_pass", 0.0)) <= 0.0 or not any_move

## Most Energy a Spirling can hold under the variants in play.
## The energy maximum of [param side]'s Spirlings, with an Overcharge Core.
func max_energy_of(side: int) -> int:
	return max_energy() + energy_bonus[side]

func max_energy() -> int:
	return mini(int(rules.get("max_energy", Spirling.MAX_ENERGY)), Spirling.MAX_ENERGY)

## Share of max Vigor every Spirling in front loses each turn once the fight is weary.
const WEARY_CHIP_DIV: int = 8

## From BattleRules.WEARY_TURN on, the long fight costs every Spirling in front 1/8 of its Vigor
## each turn, so even two walls that barely scratch each other finish within a few turns.
func _weary_chip() -> void:
	var from: int = BattleRules.WEARY_TURN
	if int(rules.get("chip_from_turn", 0)) > 0:
		from = mini(from, int(rules.chip_from_turn))
	if turn < from:
		return
	for side: int in [Side.PLAYER, Side.FOE]:
		for slot: int in standing_slots(side):
			var s: Spirling = active_spirling(side, slot)
			deal_damage(side, maxi(1, ceili(float(s.max_hp()) / float(WEARY_CHIP_DIV))), {"weary": true}, slot)

## Warden rule Vine Tangle: after each round the vines mend the standing Spirling in front with
## the lowest share of Vigor, on either side (the first one found wins a tie).
func _vine_heal() -> void:
	var div: int = int(BattleRules.rule_number(foe_rule, "vine_heal_div"))
	if div <= 0:
		return
	var best_side: int = -1
	var best_slot: int = -1
	var best: float = 1.0
	for side: int in [Side.PLAYER, Side.FOE]:
		for slot: int in standing_slots(side):
			var s: Spirling = active_spirling(side, slot)
			var share: float = float(s.hp) / float(maxi(1, s.max_hp()))
			if share < best:
				best = share
				best_side = side
				best_slot = slot
	if best_side >= 0:
		heal(best_side, maxi(1, active_spirling(best_side, best_slot).max_hp() / div), best_slot)

## Warden rule Sandstorm: after each round every standing Spirling in front that is not Stone
## loses max Vigor / div.
func _sand_chip() -> void:
	var div: int = int(BattleRules.rule_number(foe_rule, "sand_chip_div"))
	if div <= 0:
		return
	for side: int in [Side.PLAYER, Side.FOE]:
		for slot: int in standing_slots(side):
			var s: Spirling = active_spirling(side, slot)
			if Elements.E.STONE in s.elements():
				continue
			deal_damage(side, maxi(1, s.max_hp() / div), {"sand": true}, slot)

func _end_of_turn_for(side: int, slot: int) -> void:
	var s: Spirling = active_spirling(side, slot)
	if not is_standing(s):
		return
	var div: int = StatusRules.tick_div(s.status)
	if div > 0:
		var d: Dictionary = _who(side, slot)
		d["status"] = s.status
		emit_event(BattleEvent.Type.STATUS_TICK, d)
		deal_damage(side, maxi(1, s.max_hp() / div), {"status_tick": true}, slot)
	if s.is_fainted():
		return
	if s.status_turns > 0 and not StatusRules.sleeps(s.status):
		s.status_turns -= 1
		if s.status_turns == 0:
			_cure(side, slot)
	var regen: int = int(ShopEffects.gift_table(s).get("regen_div", 0))
	var held_regen: int = int(BattleRules.held_info(s.held).get("regen_div", 0))
	var fdata: Dictionary = BattleRules.FIELDS.get(field, {})
	var field_regen: int = 0
	if Elements.E.get(str(fdata.get("regen_element", "")), -1) in s.elements():
		field_regen = int(fdata.get("regen_div", 0))
	if regen > 0 and s.hp < s.max_hp():
		reveal_trait(side, slot)
	for rdiv: int in [regen, held_regen, field_regen]:
		if rdiv > 0 and s.hp < s.max_hp():
			heal(side, maxi(1, s.max_hp() / rdiv), slot)
	_oath_tick(side, slot, s)
	TraitKit.end_of_turn(self, side, slot)
	if s.mend_turns > 0:
		s.mend_turns -= 1
		if s.hp < s.max_hp():
			heal(side, maxi(1, s.max_hp() / BattleRules.MEND_DIV), slot)
	if int(ShopEffects.gift_table(s).get("energy_per_turn", 0)) > 0 and s.energy < Spirling.MAX_ENERGY:
		reveal_trait(side, slot)
	var gain: int = int(rules.get("energy_per_turn", ENERGY_PER_TURN)) + int(BattleRules.add_key(s, "energy_per_turn"))
	if s.energy_surge > 0:
		s.energy_surge -= 1
		gain += 1
	if side == Side.FOE:
		for rule_id: String in BattleRules.split_rules(foe_rule):
			var rule: Dictionary = BattleRules.RULES[rule_id]
			if turn % maxi(1, int(rule.get("foe_energy_every", 1))) == 0:
				gain += int(rule.get("foe_energy", 0))
			if rule_turned and rule_turn_full:
				gain += int(BattleRules.turning(rule_id).get("full_foe_energy", 0))
		# The turn counter moves on after this, so 0 is the end of the first turn.
		if turn == 0:
			gain += foe_turn1_energy
	gain += RiftFields.energy_bonus(field, s)
	gain = StatusRules.energy_gain(s.status, gain, turn)
	# An Energy lock (item 47) holds back the whole turn's gain.
	if s.energy_lock > 0 and gain > 0:
		emit_event(BattleEvent.Type.ENERGY_LOCKED, _who(side, slot))
		return
	change_energy(side, gain, slot)

func _phase_faint_check() -> void:
	# Every foe that dropped this turn pays out once (several can drop at once in a sweep).
	for foe: Spirling in parties[Side.FOE]:
		if foe.is_fainted() and not foe.has_meta("xp_paid"):
			foe.set_meta("xp_paid", true)
			_award_xp(foe)
	phase = Phase.VICTORY_CHECK

func _phase_victory_check() -> void:
	if alive_count(Side.FOE) == 0:
		if outcome == Outcome.NONE:
			outcome = Outcome.WIN
		phase = Phase.REWARDS
	elif own_alive_count() == 0 and _last_stand():
		phase = Phase.SWITCH_IN
	elif own_alive_count() == 0:
		outcome = Outcome.LOSS
		phase = Phase.REWARDS
	elif round_limit > 0 and turn >= round_limit:
		if not foe_boss.is_empty():
			emit_event(BattleEvent.Type.ROUND_LIMIT, {"turns": round_limit, "boss": foe_boss})
		outcome = Outcome.FLED
		phase = Phase.REWARDS
	else:
		phase = Phase.SWITCH_IN

func _phase_switch_in() -> void:
	for slot: int in slot_count(Side.FOE):
		if not _announce_next(slot):
			_refill_slot(Side.FOE, slot, ai)
	if _partner_slot >= 0:
		for slot: int in range(_partner_slot, slot_count(Side.PLAYER)):
			_refill_slot(Side.PLAYER, slot, partner_ai)
	pending_switch.clear()
	for slot: int in slot_count(Side.PLAYER):
		if is_partner_slot(Side.PLAYER, slot) or active_index(Side.PLAYER, slot) < 0:
			continue
		if is_standing(active_spirling(Side.PLAYER, slot)):
			continue
		if swap_candidates(Side.PLAYER, slot).is_empty():
			slots[Side.PLAYER][slot] = -1
		else:
			pending_switch.append(slot)
	phase = Phase.AWAIT_SWITCH if not pending_switch.is_empty() else Phase.CHOOSE_ACTIONS
	if shift_next >= 0:
		phase = Phase.AWAIT_SHIFT

## An AI-steered slot whose Spirling dropped (or was bonded away) takes a bench Spirling, if any.
func _refill_slot(side: int, slot: int, brain: BattleAI) -> void:
	if is_standing(active_spirling(side, slot)):
		return
	var index: int = brain.choose_replacement(self, side, slot)
	if index >= 0:
		_swap_in(side, index, slot)
	else:
		slots[side][slot] = -1

func _phase_rewards() -> void:
	var hp_scale: float = float(rules.get("hp_mult", 1.0))
	for s: Spirling in parties[Side.PLAYER]:
		if hp_scale != 1.0 and hp_scale > 0.0:
			# The variant's Vigor was for this battle only: keep the share, drop the factor.
			var share: float = float(s.hp) / float(s.max_hp())
			s.hp_mult /= hp_scale
			s.hp = 0 if s.hp <= 0 else maxi(1, roundi(s.max_hp() * share))
		s.end_battle(keep_status)
	for side: int in [Side.PLAYER, Side.FOE]:
		for s: Spirling in parties[side]:
			if s.has_meta("trait_shown"):
				s.remove_meta("trait_shown")
	if bonded != null and bonded.has_meta("trait_shown"):
		bonded.remove_meta("trait_shown")
	for s: Spirling in parties[Side.FOE]:
		if s.has_meta("xp_paid"):
			s.remove_meta("xp_paid")
		s.hp_mult = 1.0
		# A boss that outlived the fight keeps its Vigor inside the normal bounds again.
		s.hp = mini(s.hp, s.max_hp())
	if bonded != null:
		bonded.end_battle()
	var money: int = prize_money if outcome == Outcome.WIN and not is_wild else 0
	emit_event(BattleEvent.Type.BATTLE_END, {"outcome": outcome, "outcome_name": Outcome.keys()[outcome], "money": money})
	phase = Phase.FINISHED

# --- Actions -------------------------------------------------------------------

## Foe slots a move reaches: every standing foe for a sweep, else the aimed slot (or the first
## foe still standing if the aimed one dropped meanwhile).
func move_targets(side: int, mv: MoveData, target_slot: int = -1) -> Array[int]:
	var standing: Array[int] = standing_slots(other(side))
	if standing.is_empty() or mv.is_area():
		return standing
	target_slot = TechniqueRules.lured_slot(self, side, target_slot)
	var out: Array[int] = [MultiRules.redirect(self, other(side), target_slot if target_slot in standing else standing[0])]
	return out

## Effects that act on the user once per move, not once per foe a sweep reaches.
static func _is_self_effect(fx: Dictionary) -> bool:
	var id: StringName = StringName(fx.get("id", ""))
	return id in [&"heal_self", &"self_stage_after", &"energy_gain", &"self_cost", &"cure_team", &"status_veil", &"energy_give"] or (id == &"stat_change" and bool(fx.get("self", true)))

func _do_move(a: BattleAction) -> void:
	var side: int = a.side
	var slot: int = a.slot
	var me: Spirling = a.actor
	var mv: MoveData = me.moves[a.move_index]
	if StatusRules.sleeps(me.status):
		if me.status_turns > 0:
			me.status_turns -= 1
			var d: Dictionary = _who(side, slot)
			d["status"] = me.status
			emit_event(BattleEvent.Type.STATUS_PREVENTED, d)
			return
		_cure(side, slot)
	var skip: float = StatusRules.skip_chance(me.status)
	if me.sure_skip > 0 and not me.status.is_empty():
		me.sure_skip -= 1
		skip = 1.0
	if skip > 0.0 and rng.randf() < skip:
		var d2: Dictionary = _who(side, slot)
		d2["status"] = me.status
		emit_event(BattleEvent.Type.STATUS_PREVENTED, d2)
		return
	if not me.can_afford(mv):
		emit_event(BattleEvent.Type.NOT_ENOUGH_ENERGY, _who(side, slot))
		return
	# Overflow (item 49) counts the Energy before the art is paid.
	var brimming: bool = me.energy >= max_energy_of(side)
	change_energy(side, -me.move_cost(mv), slot)
	if mv.cooldown > 0:
		# +1 because the end of this very turn already counts one down.
		me.cooldowns[mv.move_name] = mv.cooldown + 1
	# A field_element move lands in the active field's element (a cached copy, never the data).
	mv = BattleRules.resolve_move(mv, field)
	var power_mult: float = 1.0
	var extra: int = 0
	if mv.overcharge:
		extra = mini(me.energy, BattleRules.OVERCHARGE_MAX_EXTRA)
		# Two Overcharge arts in two turns in a row chain for a bonus (item 59).
		var chained: bool = turn > 0 and me.overcharge_turn == turn - 1
		power_mult = BattleRules.overcharge_mult(extra, chained) + TraitKit.overcharge_bonus(me) * extra
		if extra > 0:
			change_energy(side, -extra, slot)
		if chained:
			emit_event(BattleEvent.Type.OVERCHARGE_CHAIN, _who(side, slot))
		me.overcharge_turn = turn
	var target_side: int = other(side)
	var aim: int = a.target_slot
	var muddled: bool = false
	if StatusRules.random_target(me.status) and not mv.is_area():
		var foes: Array[int] = standing_slots(target_side)
		if foes.size() > 1:
			aim = foes[rng.randi_range(0, foes.size() - 1)]
			muddled = true
	var targets: Array[int] = move_targets(side, mv, aim)
	var used: Dictionary = _who(side, slot)
	used.merge({"move": mv.move_name, "element": mv.element, "neutral": mv.neutral, "kind": mv.kind, "area": mv.is_area() and targets.size() > 1, "targets": targets})
	if extra > 0:
		# The presenter pitches the Overcharge swell by the Energy poured in (plan 687).
		used["overcharge"] = extra
	if muddled:
		used["muddled"] = true
	emit_event(BattleEvent.Type.MOVE_USED, used)
	TechniqueRules.note_move(self, side, me, mv, slot)
	if targets.is_empty():
		emit_event(BattleEvent.Type.NO_TARGET, {})
		return
	var spread: float = BattleRules.SPREAD_MULT if targets.size() > 1 else 1.0
	var self_done: bool = false
	for t_slot: int in targets:
		var target: Spirling = active_spirling(target_side, t_slot)
		if me.is_fainted():
			break
		if not is_standing(target):
			continue
		if TechniqueRules.blocks_hit(self, target_side, t_slot, target, mv):
			continue
		TraitKit.on_aim(self, side, slot, me, mv)
		var acc: float = hit_chance(me, mv, target)
		var marked: bool = mv.is_damaging() and StatusRules.sure_hit(target.status)
		if acc < 1.0 and rng.randf() >= acc:
			var miss: Dictionary = _who(side, slot)
			miss["target_slot"] = t_slot
			emit_event(BattleEvent.Type.MISSED, miss)
			continue
		var ctx := EffectContext.new()
		ctx.model = self
		ctx.user_side = side
		ctx.target_side = target_side
		ctx.user_slot = slot
		ctx.target_slot = t_slot
		ctx.user = me
		ctx.target = target
		ctx.move = mv
		var react: Dictionary = BattleRules.reaction(mv, target)
		if not react.is_empty():
			var rd: Dictionary = _who(target_side, t_slot)
			rd.merge({"text": str(react.text), "element": mv.element, "status": str(react.status)})
			emit_event(BattleEvent.Type.REACTION, rd)
		if mv.is_damaging():
			if mv.kind == MoveData.Kind.PHYSICAL and ShopEffects.gift_table(target).has("phys_taken"):
				reveal_trait(target_side, t_slot)
			if ShopEffects.gift_table(me).has("low_hp_boost") and mv.element in me.elements() and me.hp * 3 < me.max_hp():
				reveal_trait(side, slot)
			var mult: float = power_mult * spread * BattleRules.damage_mult(me, target, mv, field) * _variant_mult(me, target, mv)
			if brimming:
				mult *= float(ShopEffects.gift_table(me).get("full_energy_mult", 1.0))
			if side == Side.FOE:
				mult *= foe_damage_mult
			# Warden rule High Noon: Lumen arts on both sides hit harder.
			if mv.element == Elements.E.LUMEN:
				mult *= BattleRules.rule_number(foe_rule, "lumen_mult")
			mult *= ShopEffects.seal_damage_mult(int(seals[side][0]), int(seals[target_side][1]))
			mult *= TechniqueRules.hit_mult(self, side, slot, me, target_side, t_slot, target, mv)
			mult *= TraitKit.hit_mult(self, side, slot, target_side, t_slot, mv)
			mult *= MultiRules.guard_mult(self, target_side) * MultiRules.row_mult(self, side, slot, target_side, t_slot, mv)
			var combo: Dictionary = MultiRules.combo(self, side, slot, target_side, t_slot, mv.element)
			if not combo.is_empty():
				mult *= MultiRules.combo_mult()
				var cd: Dictionary = _who(target_side, t_slot)
				cd.merge({"kind": "combo", "label": str(combo.label)})
				emit_event(BattleEvent.Type.SUPPORT, cd)
			var shielded: bool = _shield_on[target_side] == target
			if shielded:
				mult *= ShopEffects.shield_mult(int(amulets[target_side][2]))
			var r: Dictionary = DamageCalc.compute(me, target, mv, rng, mult,
				ShopEffects.crit_mult(BattleRules.mult_key(me, "crit_mult"), int(amulets[side][0])) * (foe_crit_mult if side == Side.FOE else 1.0))
			if shielded and int(r.damage) > 0:
				_shield_on[target_side] = null
			if mv.has_effect(&"delayed_hit"):
				# Worked out now with today's stats; the delayed_hit effect sends it on its way.
				ctx.held_damage = int(r.damage)
				ctx.held_eff = float(r.eff)
			else:
				ctx.damage_dealt = deal_damage(target_side, int(r.damage), {"eff": r.eff, "crit": r.crit, "move": mv.move_name}, t_slot)
				TraitKit.after_hit(self, side, slot, target_side, t_slot, mv, ctx.damage_dealt)
			if bool(react.get("cure", false)) and is_standing(target):
				_cure(target_side, t_slot)
			if react.has("inflict") and is_standing(target):
				apply_status(target_side, str(react.inflict), t_slot, side)
			if marked and is_standing(target) and StatusRules.sure_hit(target.status):
				_cure(target_side, t_slot)
			if mv.kind == MoveData.Kind.PHYSICAL and is_standing(me):
				_contact_status(target_side, t_slot, side, slot)
			if is_standing(target):
				var rs: Dictionary = react.get("stage", {})
				for st: String in rs:
					change_stage(target_side, st, int(rs[st]), t_slot)
		for fx: Dictionary in mv.effects:
			if self_done and _is_self_effect(fx):
				continue
			var effect: MoveEffect = EffectRegistry.get_effect(StringName(fx.get("id", "")))
			if effect != null:
				effect.apply(ctx, fx)
		self_done = true

func _do_oath(a: BattleAction) -> void:
	if not can_oath(a.side, a.slot):
		return
	var o: Dictionary = BattleRules.oath()
	oath_used[a.side] = true
	# +1 because the end of this very turn already counts one down.
	a.actor.oath_turns = int(o.get("turns", 3)) + 1
	emit_event(BattleEvent.Type.OATH, _who(a.side, a.slot))
	for stat: String in o.get("stages", {}):
		change_stage(a.side, stat, int(o.stages[stat]), a.slot)
	change_energy(a.side, int(o.get("energy", 0)), a.slot)

func _oath_tick(side: int, slot: int, s: Spirling) -> void:
	if s.oath_turns <= 0:
		return
	s.oath_turns -= 1
	if s.oath_turns > 0:
		return
	var d: Dictionary = _who(side, slot)
	d["due"] = true
	emit_event(BattleEvent.Type.OATH, d)
	var debt: Dictionary = BattleRules.oath().get("debt", {})
	for stat: String in debt:
		change_stage(side, stat, int(debt[stat]), slot)

func _do_rest(a: BattleAction) -> void:
	emit_event(BattleEvent.Type.REST, _who(a.side, a.slot))
	change_energy(a.side, rest_gain() + TraitKit.rest_energy(a.actor), a.slot)
	# Story (item 52): resting also mends a little Vigor, only for the player's own Spirlings.
	if a.side == Side.PLAYER and rest_heal_share > 0.0 and not is_partner_slot(a.side, a.slot):
		var me: Spirling = active_spirling(a.side, a.slot)
		if me != null and me.hp < me.max_hp():
			heal(a.side, maxi(1, roundi(me.max_hp() * rest_heal_share)), a.slot)

## Chance that [param mv] of [param me] lands on [param target]: its accuracy with Daze and the
## Warden rule's accuracy factor; a Marked target is always hit. The same for both sides: no side
## gets kinder rolls (KAMPF_PLAN item 35). The art card shows it as a miss chance (item 14).
func hit_chance(me: Spirling, mv: MoveData, target: Spirling = null) -> float:
	if target != null and mv.is_damaging() and StatusRules.sure_hit(target.status):
		return 1.0
	# Storm Lantern (KAMPF_PLAN_1000 item 279): fog and blurring conditions leave its aim alone.
	var steady: bool = TraitKit.steady_aim(me)
	return clampf(mv.accuracy * (1.0 if mv.ignore_daze or steady else StatusRules.acc_mult(me.status)) * BattleRules.rule_number(foe_rule, "accuracy_mult")
		* (sight_mult if is_wild and not steady else 1.0), 0.0, 1.0)

## Tells every Spirling of both teams which element the place's own field makes cheaper (item 75).
## Only the place's own field counts (a storm overhead, a map's field): a field called by an art
## or a boss phase never cuts costs, it already brings its Energy gift.
func _sync_field_costs() -> void:
	var cheap: int = -1
	if not field.is_empty() and field == base_field:
		cheap = Elements.E.get(str(BattleRules.FIELDS.get(field, {}).get("cheap_element", "")), -1)
	for team: Array in parties:
		for s: Spirling in team:
			s.cheap_element = cheap

## Energy one Rest gives right now: the rule's amount plus the field's "rest_bonus" (item 42), minus
## the Warden rule Ebb's "rest_cut".
func rest_gain() -> int:
	return maxi(0, int(rules.get("rest_energy", REST_ENERGY)) + int(BattleRules.FIELDS.get(field, {}).get("rest_bonus", 0)) \
			- int(BattleRules.rule_number(foe_rule, "rest_cut")))

## Gift "contact_status" (Glimmer Skin, item 194): a physical hit on the Spirling in
## [param slot] may pass its status on to the attacker.
func _contact_status(side: int, slot: int, hitter_side: int, hitter_slot: int) -> void:
	var s: Spirling = active_spirling(side, slot)
	var gift: Dictionary = ShopEffects.gift_table(s)
	var st: String = str(gift.get("contact_status", ""))
	if st.is_empty() or s.is_fainted() or rng.randf() >= float(gift.get("contact_chance", 0.3)):
		return
	if apply_status(hitter_side, st, hitter_slot, side, slot):
		reveal_trait(side, slot)

func _do_swap(a: BattleAction) -> void:
	if MultiRules.shift(self, a):
		return
	var free: bool = TraitKit.free_swap(a.actor)
	if StatusRules.blocks_swap(a.actor.status) and not free:
		emit_event(BattleEvent.Type.SWAP_BLOCKED, _who(a.side, a.slot))
		return
	if not a.swap_index in swap_candidates(a.side, a.slot):
		return
	# Gift "cure_on_swap" (Unruffled, item 195): its status falls away as it steps back.
	if bool(ShopEffects.gift_table(a.actor).get("cure_on_swap", false)) and not a.actor.status.is_empty():
		reveal_trait(a.side, a.slot)
		_cure(a.side, a.slot)
	TraitKit.on_leave(self, a.side, a.slot)
	emit_event(BattleEvent.Type.SWAP_OUT, _who(a.side, a.slot))
	_swap_in(a.side, a.swap_index, a.slot)
	if int(rules.get("swap_energy_cost", 0)) > 0 and not free:
		change_energy(a.side, -int(rules.swap_energy_cost), a.slot)

func _do_item(a: BattleAction) -> void:
	if KeepsakeKit.is_swap(a):
		if KeepsakeKit.swap_legal(self, a):
			KeepsakeKit.do_swap(self, a)
		return
	if bag_count(a.side, a.item_id) <= 0 or not _items_allowed_for(a.side):
		return
	var target: Spirling = parties[a.side][a.item_target]
	if target.is_fainted() != is_revive_item(a.item_id) or not item_left_this_battle(a.side, a.item_id):
		return
	var it: Dictionary = Database.item(a.item_id)
	_take_item(a.side, a.item_id)
	items_used[a.side][a.item_id] = int(items_used[a.side].get(a.item_id, 0)) + 1
	var d: Dictionary = {"side": a.side, "index": a.item_target, "name": target.display_name(), "item": a.item_id, "item_name": str(it.get("name", a.item_id))}
	emit_event(BattleEvent.Type.ITEM_USED, d)
	if is_revive_item(a.item_id):
		_revive(a.side, a.item_target, float(it.battle_revive), bool(it.get("revive_energy", false)))
		return
	if float(it.get("heal_frac", 0.0)) > 0.0:
		_heal_spirling(a.side, a.item_target, ceili(target.max_hp() * float(it.heal_frac)))
	if int(it.get("heal", 0)) > 0:
		_heal_spirling(a.side, a.item_target, int(it.heal))
	var cure: Variant = it.get("cure", false)
	var cures: bool = (cure is bool and cure) or (cure is String and cure == target.status)
	var t_slot: int = slot_of(a.side, a.item_target)
	if cures and not target.status.is_empty():
		if t_slot >= 0:
			_cure(a.side, t_slot)
		else:
			target.status = ""
			target.status_turns = 0
	if int(it.get("energy", 0)) > 0 and t_slot >= 0:
		change_energy(a.side, int(it.energy), t_slot)
	elif int(it.get("energy", 0)) > 0 and bool(it.get("energy_bench", false)):
		# The Rest Candle (KAMPF_PLAN item 78) also reaches a Spirling waiting on the bench.
		target.energy = mini(target.energy + int(it.energy), max_energy_of(a.side))
	if int(it.get("energy_surge", 0)) > 0 and t_slot >= 0:
		change_energy(a.side, max_energy_of(a.side), t_slot)
		target.energy_surge = int(it.energy_surge)
	var st: Variant = it.get("stage", {})
	if st is Dictionary and t_slot >= 0:
		for stat: String in st:
			change_stage(a.side, stat, int(st[stat]), t_slot)

func _do_bond(a: BattleAction) -> void:
	var standing: Array[int] = standing_slots(Side.FOE)
	if standing.is_empty():
		emit_event(BattleEvent.Type.NO_TARGET, {})
		return
	var t_slot: int = a.target_slot if a.target_slot in standing else standing[0]
	var target: Spirling = active_spirling(Side.FOE, t_slot)
	var bonus: float = 0.0
	var sure: bool = false
	var retry: bool = false
	var wish: bool = false
	if not a.item_id.is_empty() and int(inventory.get(a.item_id, 0)) > 0:
		inventory[a.item_id] = int(inventory[a.item_id]) - 1
		bonus = float(Database.item(a.item_id).get("bond_bonus", 0.0))
		# The shop's Bond Seal (plan area 10) makes this one bond certain.
		sure = bool(Database.item(a.item_id).get("bond_sure", false))
		# The shop's Second Try Charm: a failed bond is tried once more at once.
		retry = bool(Database.item(a.item_id).get("bond_retry", false))
		# The shop's Wish Charm (pay-to-win step 6, plan point 30): the top Spark on a bond that works.
		wish = bool(Database.item(a.item_id).get("bond_wish", false))
	var who: Dictionary = _who(Side.FOE, t_slot)
	who["timing"] = a.timing_score
	emit_event(BattleEvent.Type.BOND_ATTEMPT, who)
	bonus += TraitKit.bond_bonus(self)
	var timing: float = minf(1.0, a.timing_score + clampf(bond_edge, 0.0, 1.0))
	# Some fields make a bond a little likelier (Dawn Glow, KAMPF_PLAN_1000 item 349).
	bonus += float(BattleRules.FIELDS.get(field, {}).get("bond_bonus", 0.0))
	# A field calms wild Spirlings of its element (WildRules, data/wild_rules.json); never shown.
	bonus += WildRules.field_bond_bonus(field, target)
	bond_tries += 1
	var success: bool = rng.randf() < BondCalc.chance(target, timing, bonus) or sure
	if not success and retry:
		success = rng.randf() < BondCalc.chance(target, timing, bonus)
	var res: Dictionary = _who(Side.FOE, t_slot)
	res["success"] = success
	var steadied: bool = not success and bond_grace > 0
	if steadied:
		bond_grace -= 1
		res["steadied"] = true
	emit_event(BattleEvent.Type.BOND_RESULT, res)
	if success:
		bonded = target
		if wish:
			for key: String in Spirling.STAT_KEYS:
				target.spark[key] = Spirling.SPARK_MAX
		# In a horde the rest of the swarm fights on; the battle ends once none is left.
		if not is_multi() or alive_count(Side.FOE) == 0:
			outcome = Outcome.BONDED
		return
	if steadied:
		return
	# A failed bond gives the wild Spirling one free action, right now.
	var free: BattleAction = ai.choose(self, Side.FOE, t_slot)
	free.actor = target
	free.is_free = true
	_queue.push_front(free)

func _do_run(a: BattleAction) -> void:
	var mine: float = float(a.actor.effective_spd())
	var fastest: int = 0
	for slot: int in standing_slots(Side.FOE):
		fastest = maxi(fastest, active_spirling(Side.FOE, slot).effective_spd())
	var theirs: float = maxf(float(fastest), 1.0)
	var chance: float = clampf(FLEE_BASE + FLEE_PER_ATTEMPT * flee_attempts + (mine / theirs - 1.0) * FLEE_SPEED_WEIGHT, 0.0, 1.0)
	flee_attempts += 1
	var success: bool = rng.randf() < chance
	emit_event(BattleEvent.Type.FLEE_RESULT, {"success": success})
	if success:
		outcome = Outcome.FLED

# --- Internals ------------------------------------------------------------------

func _who(side: int, slot: int = 0) -> Dictionary:
	var s: Spirling = active_spirling(side, slot)
	if s == null:
		return {"side": side, "slot": slot, "index": -1, "name": "", "species": ""}
	return {"side": side, "slot": slot, "index": active_index(side, slot), "name": s.display_name(), "species": s.data.species_name}

func _given(actions: Array[BattleAction], side: int, slot: int) -> BattleAction:
	for a: BattleAction in actions:
		if a != null and a.side == side and a.slot == slot:
			return a
	return null

func _first_alive(side: int) -> int:
	for i: int in parties[side].size():
		if not (parties[side][i] as Spirling).is_fainted():
			return i
	return 0

## The first [param count] standing party indices on [param side] owned by the player (or by the ally).
func _first_standing(side: int, count: int, partner: bool) -> Array[int]:
	var out: Array[int] = []
	for i: int in parties[side].size():
		if out.size() >= count:
			break
		if is_partner_index(side, i) == partner and is_standing(parties[side][i]):
			out.append(i)
	return out

func _fill_initial_slots() -> void:
	var mine: Array[int] = _first_standing(Side.PLAYER, clampi(front_size[Side.PLAYER], 1, BattleRules.MAX_FRONT), false)
	if mine.is_empty():
		mine = [_first_alive(Side.PLAYER)]
	_partner_slot = -1
	if partner_start >= 0:
		var theirs: Array[int] = _first_standing(Side.PLAYER, partner_front, true)
		if not theirs.is_empty():
			_partner_slot = mine.size()
			mine.append_array(theirs)
	slots[Side.PLAYER] = mine
	var foes: Array[int] = _first_standing(Side.FOE, clampi(front_size[Side.FOE], 1, BattleRules.MAX_FRONT), false)
	if foes.is_empty():
		foes = [_first_alive(Side.FOE)]
	slots[Side.FOE] = foes

func _swap_in(side: int, index: int, slot: int = 0) -> void:
	slots[side][slot] = index
	var s: Spirling = active_spirling(side, slot)
	entered_turn[s] = turn
	var d: Dictionary = _who(side, slot)
	d.merge({"hp": s.hp, "max_hp": s.max_hp(), "level": s.level, "energy": s.energy})
	emit_event(BattleEvent.Type.SWAP_IN, d)
	_spring_snare(side, slot)
	TraitKit.on_enter(self, side, slot)
	if side == Side.PLAYER:
		if not participants.has(s) and not is_partner_index(side, index):
			participants.append(s)
		if not _turn_drag.is_empty() and not is_partner_index(side, index):
			var drag: Dictionary = _turn_drag
			_turn_drag = {}
			for stat: String in drag:
				change_stage(side, stat, int(drag[stat]), slot)
	elif not is_multi():
		participants = [active_spirling(Side.PLAYER)]

## Cures the status of the Spirling in [param slot] (used by effects). Emits STATUS_CURED.
func cure(side: int, slot: int = 0) -> void:
	_cure(side, slot)

## Lays [param snare] on [param side] (at most BattleRules.MAX_SNARES at once). Emits SNARE_SET.
func lay_snare(side: int, snare: Dictionary, move_name: String = "") -> bool:
	var row: Array = snares[side]
	if row.size() >= BattleRules.MAX_SNARES:
		emit_event(BattleEvent.Type.SNARE_SET, {"side": side, "full": true})
		return false
	var s: Dictionary = snare.duplicate(true)
	s["move"] = move_name
	row.append(s)
	emit_event(BattleEvent.Type.SNARE_SET, {"side": side, "move": move_name, "count": row.size(), "tag": BattleRules.snare_tag(s)})
	return true

## Clears every snare on [param side]. Emits SNARE_CLEARED when there were any.
func clear_snares(side: int) -> void:
	if (snares[side] as Array).is_empty():
		return
	snares[side] = []
	emit_event(BattleEvent.Type.SNARE_CLEARED, {"side": side})

## The field the swirl lays next (field_swirl_every), picked a turn early so it can be announced.
var _swirl_next: String = ""

## Warden rule "field_cycle" (Tide Turn, item 676): the field holds "on" turns, then "off" turns of
## the place's own field, then comes back; FIELD_NEXT announces it at the end of the turn before.
func _tick_field_cycle() -> void:
	for rule_id: String in BattleRules.split_rules(foe_rule):
		var cycle: Dictionary = BattleRules.RULES[rule_id].get("field_cycle", {})
		if cycle.is_empty():
			continue
		var period: int = int(cycle.get("on", 2)) + int(cycle.get("off", 2))
		var done: int = turn + 1
		var fid: String = str(cycle.field)
		if done % period == period - 1:
			emit_event(BattleEvent.Type.FIELD_NEXT, {"field": fid, "label": str(BattleRules.FIELDS[fid].label)})
		elif done % period == 0:
			set_field(fid, int(cycle.get("on", 2)))

## "field_swirl_every" = N: at the end of every N-th turn a random field (from the battle seed) takes
## over for N turns; one turn earlier FIELD_NEXT tells both sides which one is coming.
func _tick_field_swirl() -> void:
	var every: int = int(rules.get("field_swirl_every", 0))
	if every <= 0:
		return
	if (turn + 1) % every == 0:
		var ids: Array = BattleRules.FIELDS.keys()
		ids.sort()
		_swirl_next = str(ids[rng.randi_range(0, ids.size() - 1)])
		emit_event(BattleEvent.Type.FIELD_NEXT, {"field": _swirl_next, "label": str(BattleRules.FIELDS[_swirl_next].label)})
	elif turn % every == 0 and not _swirl_next.is_empty():
		set_field(_swirl_next, every)
		_swirl_next = ""

## Sends a delayed hit of [param amount] at [param slot] of [param side]: it lands at the end of
## the turn [param turns] turns from now on whoever stands there then. Emits DELAYED_SET.
func queue_delayed_hit(side: int, slot: int, amount: int, eff: float, move_name: String, turns: int) -> void:
	delayed_hits.append({"side": side, "slot": slot, "amount": amount, "eff": eff, "move": move_name, "turns": turns + 1})
	emit_event(BattleEvent.Type.DELAYED_SET, {"side": side, "move": move_name, "turns": turns})

## End of turn: every delayed hit moves one turn closer and the due ones land. A slot that is
## empty by then (its side has nobody left to send) lets the hit fade.
func _tick_delayed_hits() -> void:
	var left: Array[Dictionary] = []
	var due: Array[Dictionary] = []
	for h: Dictionary in delayed_hits:
		h.turns = int(h.turns) - 1
		if int(h.turns) <= 0:
			due.append(h)
		else:
			left.append(h)
	delayed_hits = left
	for h: Dictionary in due:
		var side: int = int(h.side)
		var slot: int = int(h.slot)
		var s: Spirling = active_spirling(side, slot) if slot < slot_count(side) else null
		if not is_standing(s):
			emit_event(BattleEvent.Type.DELAYED_HIT, {"side": side, "move": str(h.move), "faded": true})
			continue
		var d: Dictionary = _who(side, slot)
		d["move"] = str(h.move)
		emit_event(BattleEvent.Type.DELAYED_HIT, d)
		deal_damage(side, int(h.amount), {"eff": float(h.eff), "crit": false, "move": str(h.move), "delayed": true}, slot)

## The Spirling that just swapped into [param slot] springs the oldest snare on its side.
func _spring_snare(side: int, slot: int) -> void:
	var row: Array = snares[side]
	var s: Spirling = active_spirling(side, slot)
	if row.is_empty() or not is_standing(s):
		return
	var snare: Dictionary = row.pop_front()
	var d: Dictionary = _who(side, slot)
	d.merge({"move": str(snare.get("move", "")), "tag": BattleRules.snare_tag(snare)})
	emit_event(BattleEvent.Type.SNARE_HIT, d)
	if float(snare.get("hp", 0.0)) > 0.0:
		deal_damage(side, maxi(1, int(s.max_hp() * float(snare.hp))), {"snare": true}, slot)
	if not str(snare.get("status", "")).is_empty():
		apply_status(side, str(snare.status), slot, 1 - side)
	var st: Variant = snare.get("stage", {})
	if st is Dictionary:
		for stat: String in st:
			change_stage(side, stat, int(st[stat]), slot)

func _cure(side: int, slot: int = 0) -> void:
	var s: Spirling = active_spirling(side, slot)
	if s == null or s.status.is_empty():
		return
	var d: Dictionary = _who(side, slot)
	d["status"] = s.status
	s.status = ""
	s.status_turns = 0
	s.sure_skip = 0
	emit_event(BattleEvent.Type.STATUS_CURED, d)

## The shop's Will to Win (plan item 4499): once per battle, when the whole team is down, the
## Spirling that fell last comes back with 30 % Vigor. Never against Rift Wardens.
const LAST_STAND: String = "rg_last_stand"

func _last_stand() -> bool:
	if not foe_boss.is_empty() or not _items_allowed_for(Side.PLAYER) or int(inventory.get(LAST_STAND, 0)) <= 0:
		return false
	if not item_left_this_battle(Side.PLAYER, LAST_STAND):
		return false
	var index: int = active_index(Side.PLAYER, 0)
	if index < 0 or is_partner_index(Side.PLAYER, index) or not (parties[Side.PLAYER][index] as Spirling).is_fainted():
		return false
	inventory[LAST_STAND] = int(inventory[LAST_STAND]) - 1
	items_used[Side.PLAYER][LAST_STAND] = int(items_used[Side.PLAYER].get(LAST_STAND, 0)) + 1
	var s: Spirling = parties[Side.PLAYER][index]
	emit_event(BattleEvent.Type.ITEM_USED, {"side": Side.PLAYER, "index": index, "name": s.display_name(), "item": LAST_STAND,
		"item_name": str(Database.item(LAST_STAND).get("name", LAST_STAND))})
	_revive(Side.PLAYER, index, float(Database.item(LAST_STAND).get("last_stand", 0.3)), false)
	return true

## True for items that bring a defeated Spirling back in battle (the shop's Rift Breath).
static func is_revive_item(id: String) -> bool:
	return float(Database.item(id).get("battle_revive", 0.0)) > 0.0

## False once [param side] used [param id] as often as its "per_battle" limit allows (plan item 4512).
func item_left_this_battle(side: int, id: String) -> bool:
	var limit: int = int(Database.item(id).get("per_battle", 0))
	return limit <= 0 or int(items_used[side].get(id, 0)) < limit

## Brings the defeated Spirling at [param index] back with [param frac] of its Vigor, on the bench.
func _revive(side: int, index: int, frac: float, full_energy: bool) -> void:
	var s: Spirling = parties[side][index]
	s.hp = 0
	s.status = ""
	s.status_turns = 0
	if full_energy:
		s.energy = max_energy_of(side)
	_heal_spirling(side, index, maxi(1, ceili(s.max_hp() * frac)))

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

## How many of item [param id] [param side] can use: the bag plus the player's battle-only gifts.
func bag_count(side: int, id: String) -> int:
	var n: int = int(_bag(side).get(id, 0))
	if side == Side.PLAYER:
		n += int(gift_items.get(id, 0))
	return n

## Item ids [param side] holds at least one of, gifts included, in a stable order.
func bag_ids(side: int) -> Array[String]:
	var out: Array[String] = []
	var bag: Dictionary = _bag(side)
	for id: Variant in bag:
		if int(bag[id]) > 0:
			out.append(str(id))
	if side == Side.PLAYER:
		for id: Variant in gift_items:
			if int(gift_items[id]) > 0 and not out.has(str(id)):
				out.append(str(id))
	return out

## Uses up one [param id]: a battle-only gift first, then the bag.
func _take_item(side: int, id: String) -> void:
	if side == Side.PLAYER and int(gift_items.get(id, 0)) > 0:
		gift_items[id] = int(gift_items[id]) - 1
		return
	var bag: Dictionary = _bag(side)
	bag[id] = int(bag[id]) - 1

func _items_allowed_for(side: int, slot: int = 0) -> bool:
	if is_partner_slot(side, slot):
		return false
	return items_allowed if side == Side.PLAYER else true

func _is_battle_item(id: String) -> bool:
	return bool(Database.item(id).get("battle", false))

## Opening lines of a wild battle: an elder, fog (WildRules).
func _wild_opening(foe: Spirling) -> void:
	if not is_wild or foe == null:
		return
	if WildRules.is_elder(foe):
		emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.FOE, "text": WildRules.ELDER_LINE % foe.display_name()})
	if sight_mult < 1.0:
		emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.FOE, "text": WildRules.FOG_LINE})

func _award_xp(foe: Spirling) -> void:
	var total: float = float(foe.data.xp_yield) * float(foe.level) / XP_LEVEL_DIV
	if not is_wild:
		total *= TRAINER_XP_MULT
	total *= xp_mult
	var earners: Array[Spirling] = []
	for s: Spirling in participants:
		var i: int = parties[Side.PLAYER].find(s)
		if not s.is_fainted() and i >= 0 and not is_partner_index(Side.PLAYER, i):
			earners.append(s)
	if earners.is_empty():
		return
	var share: int = maxi(1, int(total / earners.size()))
	for s: Spirling in earners:
		_give_xp(s, _scaled(share, foe, s))
	if battle_spark_chance > 0.0 and total > 0.0:
		if _spark_rng == null:
			_spark_rng = RandomNumberGenerator.new()
			_spark_rng.seed = battle_seed ^ 0x59a2
		for s: Spirling in earners:
			var line: String = GrowthRules.battle_spark(s, foe, battle_spark_chance * TechniqueRules.spark_field_mult(self, s), _spark_rng)
			if not line.is_empty():
				emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.PLAYER, "text": line})
	if bench_share <= 0.0:
		return
	# Bench lessons: every healthy own Spirling that did not fight still learns a part.
	var bench_xp: int = maxi(1, int(share * bench_share))
	for i: int in parties[Side.PLAYER].size():
		var s: Spirling = parties[Side.PLAYER][i]
		if s in earners or s in participants or is_partner_index(Side.PLAYER, i) or not is_standing(s):
			continue
		_give_xp(s, _scaled(bench_xp, foe, s), true)

func _scaled(amount: int, foe: Spirling, s: Spirling) -> int:
	return maxi(1, roundi(amount * growth_scale(foe.level, s.level))) if ring_scaled_growth else amount

const GROWTH_SCALE_POW: float = 2.5
const GROWTH_SCALE_MIN: float = 0.25
const GROWTH_SCALE_MAX: float = 4.0

## Growth factor for beating a foe of ring [param foe_ring] with a Spirling of ring [param own_ring]:
## ((2 * foe + 10) / (foe + own + 10)) ^ 2.5, so an even fight gives 1.0, a stronger foe more and a
## weaker foe less, kept within GROWTH_SCALE_MIN..GROWTH_SCALE_MAX.
static func growth_scale(foe_ring: int, own_ring: int) -> float:
	var f: float = pow((2.0 * foe_ring + 10.0) / float(foe_ring + own_ring + 10), GROWTH_SCALE_POW)
	return clampf(f, GROWTH_SCALE_MIN, GROWTH_SCALE_MAX)

## Adds XP up to the level cap and plays out level-ups and new moves.
func _give_xp(s: Spirling, amount: int, bench: bool = false) -> void:
	var index: int = parties[Side.PLAYER].find(s)
	# Growth Charm keepsake and high kinship (GrowthRules, data/growth_rules.json).
	var own_mult: float = GrowthRules.spirling_mult(s)
	if own_mult != 1.0:
		amount = maxi(1, roundi(amount * own_mult))
	var from_ring: int = s.level
	var cap_xp: int = Spirling.xp_for_level(mini(level_cap, Spirling.LEVEL_SANITY))
	var gained: int = clampi(amount, 0, maxi(0, cap_xp - s.xp)) if s.level < level_cap else 0
	if bench and gained <= 0:
		return
	s.xp += gained
	var xd: Dictionary = {"side": Side.PLAYER, "index": index, "name": s.display_name(), "amount": gained, "bench": bench}
	# Item 252: growth lost to the ring limit says so.
	if gained < amount and level_cap < Spirling.LEVEL_SANITY:
		xd["cap"] = level_cap
	emit_event(BattleEvent.Type.XP_GAINED, xd)
	while s.level < mini(level_cap, Spirling.LEVEL_SANITY) and s.xp >= Spirling.xp_for_level(s.level + 1):
		var learned: Array[MoveData] = s.level_up()
		emit_event(BattleEvent.Type.LEVEL_UP, {"side": Side.PLAYER, "index": index, "name": s.display_name(), "level": s.level, "hp": s.hp, "max_hp": s.max_hp()})
		for mv: MoveData in learned:
			emit_event(BattleEvent.Type.MOVE_LEARNED, {"side": Side.PLAYER, "index": index, "name": s.display_name(), "move": mv.move_name})
		# A full move list never stops the battle for a choice: one line, the art waits for later.
		for missed: String in GrowthRules.missed_arts(s, learned):
			emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.PLAYER, "text": GrowthRules.missed_line(s.display_name(), missed)})
	growth_total += gained
	growth_by[index] = int(growth_by.get(index, 0)) + gained
	if bench:
		bench_growth += gained
	# Several rings at once get one summary line (KAMPF_PLAN item "Level-Aufstieg-Zusammenfassung").
	var summary: String = GrowthRules.summary_line(s.display_name(), from_ring, s.level)
	if not summary.is_empty():
		emit_event(BattleEvent.Type.SHOP_EDGE, {"side": Side.PLAYER, "text": summary})
