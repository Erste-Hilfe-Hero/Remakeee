class_name BattleReplay
extends RefCounted
## Battle replays (item 14). A battle is fully decided by its seed, both starting teams and the
## player's inputs, so a replay stores only those and plays them back through a fresh model.
## The last battle is kept in GameState.records["last_battle"]; watching it changes nothing.

## Version of the replay format (Kampf-Plan: replay format versioned). Raise it when a field is
## added that changes how an old replay plays back; snapshots without "format" are format 1.
## A replay from a newer format is refused with a message instead of playing out wrong.
const FORMAT: int = 1

## Everything needed to rebuild [param model] as it is before start(). Call before the battle.
static func snapshot(model: BattleModel, music: String, backdrop: String) -> Dictionary:
	var snap: Dictionary = _snapshot(model, music, backdrop)
	# Wheel battles (Era V) only add their key when on, so older replays stay the same.
	if model.wheel:
		snap["wheel"] = model.wheel_size
	# Challenge rules and the Story crit factor (KAMPF plan 497, 517, 488) likewise.
	if model.foe_crit_mult != 1.0:
		snap["foe_crit"] = model.foe_crit_mult
	if model.swap_locked:
		snap["swap_locked"] = true
	if not model.bond_block.is_empty():
		snap["bond_block"] = model.bond_block
	if not model.blocked_items.is_empty():
		snap["blocked_items"] = model.blocked_items.duplicate()
	# Story Rest and the tall-grass ambush (KAMPF_PLAN items 16, 52), also only when on.
	if model.rest_heal_share > 0.0:
		snap["rest_heal"] = model.rest_heal_share
	if model.ambush:
		snap["ambush"] = true
	# Raid guardian phase (KAMPF_PLAN_1000 item 419), only when one applies.
	if model.raid_phase > 0:
		snap["raid_phase"] = model.raid_phase
	if model.initiative:
		snap["initiative"] = true
	# The swap offer and the foe's announcement (KAMPF_PLAN_1000 items 9, 10).
	if model.shift_offer:
		snap["shift_offer"] = true
	if model.foe_announce:
		snap["foe_announce"] = true
	return snap

static func _snapshot(model: BattleModel, music: String, backdrop: String) -> Dictionary:
	return {
		"format": FORMAT,
		"seed": model.battle_seed,
		"wild": model.is_wild,
		"ai": model.ai.level,
		"profile": model.ai.profile_id,
		"profile_tune": model.ai.profile_tune.duplicate(),
		"ai_spare_last": model.ai.spare_last,
		"ai_no_double_rest": model.ai.no_double_rest,
		"teams": [_team(model.party(BattleModel.Side.PLAYER)), _team(model.party(BattleModel.Side.FOE))],
		"inventory": model.inventory.duplicate(),
		"items_allowed": model.items_allowed,
		"held_swap": model.held_swap,
		"level_cap": model.level_cap,
		"trainer": model.trainer_name,
		"field": model.field,
		"bench_share": model.bench_share,
		"rule": model.foe_rule,
		"rule_turn_full": model.rule_turn_full,
		"foe_items": model.foe_items.duplicate(),
		"front": [model.front_size[0], model.front_size[1]],
		"partner": _partner(model),
		"boss": model.foe_boss,
		"foe_damage": model.foe_damage_mult,
		"energy_bonus": model.energy_bonus[0],
		"seals": (model.seals[0] as Array).duplicate(),
		"amulets": (model.amulets[0] as Array).duplicate(),
		"foe_energy_cut": model.start_energy_cut[1],
		"foe_turn1_energy": model.foe_turn1_energy,
		"warden_weakened": model.warden_weakened,
		"gifts": model.gift_items.duplicate(),
		"bond_grace": model.bond_grace,
		"bond_edge": model.bond_edge,
		"boss_hp": model.boss_hp_scale,
		"boss_difficulty": model.boss_difficulty,
		"variants": model.variants.duplicate(),
		"round_limit": model.round_limit,
		"music": music,
		"backdrop": backdrop,
		"inputs": [],
	}

## The ally Wayfarer in a tag battle: name, team, how many fight at once, AI tier ({} if none).
static func _partner(model: BattleModel) -> Dictionary:
	if model.partner_start < 0:
		return {}
	var own: Array = model.party(BattleModel.Side.PLAYER).slice(0, model.partner_start)
	var team: Array = model.party(BattleModel.Side.PLAYER).slice(model.partner_start)
	return {"name": model.partner_name, "team": _team(team), "front": model.partner_front,
		"ai": model.partner_ai.level, "profile": model.partner_ai.profile_id, "own": own.size()}

static func _team(team: Array) -> Array:
	var out: Array = []
	for s: Spirling in team:
		var d: Dictionary = s.to_dict()
		d["status"] = s.status
		d["status_turns"] = s.status_turns
		d["energy"] = s.energy
		out.append(d)
	return out

static func _rebuild(team_d: Array) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for v: Variant in team_d:
		var d: Dictionary = v
		var s: Spirling = Spirling.from_dict(d)
		if s == null:
			continue
		s.status = str(d.get("status", ""))
		s.status_turns = int(d.get("status_turns", 0))
		s.energy = int(d.get("energy", Spirling.START_ENERGY))
		out.append(s)
	return out

## A fresh model from [param snap], or null if a species no longer exists.
## Why [param snap] cannot be played back in this version, "" when it can (item 797): a rule
## variant this version doesn't know, or variants that don't go together.
static func problem(snap: Dictionary) -> String:
	if int(snap.get("format", 1)) > FORMAT:
		return Loc.t("This replay comes from a newer version of the game.")
	var ids: Array[String] = []
	for v: Variant in snap.get("variants", []):
		ids.append(str(v))
	var all: Dictionary = BattleRules.variants()
	var unknown: Array[String] = []
	for id: String in ids:
		if not all.has(id):
			unknown.append(id)
	if not unknown.is_empty():
		return Loc.t("This replay uses a rule variant this version doesn't know: %s.") % ", ".join(unknown)
	if not BattleRules.variant_conflict(ids).is_empty():
		return Loc.t("This replay's rule variants don't go together.")
	return ""

## Fields of a Spirling that are the player's own words or habits, not battle facts. They never
## leave the device inside a shared replay (Kampf-Plan: battle logs without personal data).
const PRIVATE_KEYS: Array[String] = ["nickname", "box", "favorite", "met_day"]

## A copy of [param snap] to share: the same battle, without the PRIVATE_KEYS of any Spirling.
static func shareable(snap: Dictionary) -> Dictionary:
	var out: Dictionary = snap.duplicate(true)
	var teams: Array = out.get("teams", [])
	var partner: Dictionary = out.get("partner", {})
	teams = teams + [partner.get("team", [])]
	for team: Variant in teams:
		if team is Array:
			for s: Variant in team:
				if s is Dictionary:
					for k: String in PRIVATE_KEYS:
						(s as Dictionary).erase(k)
	return out

## Seal tiers [power, guard, speed] from a snapshot, clamped to the tiers the data knows.
static func seal_row(v: Variant) -> Array:
	var out: Array = [0, 0, 0]
	if v is Array:
		for i: int in mini((v as Array).size(), 3):
			out[i] = ShopEffects.clamp_tier(ShopEffects.SEAL_KINDS[i], int(v[i]))
	return out

static func build_model(snap: Dictionary) -> BattleModel:
	if not problem(snap).is_empty():
		return null
	var teams: Array = snap.get("teams", [[], []])
	var partner: Dictionary = snap.get("partner", {})
	if not partner.is_empty():
		# The snapshot's player team already holds the ally's Spirlings after the player's own.
		teams = [(teams[0] as Array).slice(0, int(partner.get("own", 0))), teams[1]]
	var mine: Array[Spirling] = _rebuild(teams[0])
	var foes: Array[Spirling] = _rebuild(teams[1])
	if mine.size() != (teams[0] as Array).size() or foes.size() != (teams[1] as Array).size() or foes.is_empty():
		return null
	var m := BattleModel.new(mine, foes, bool(snap.get("wild", true)), int(snap.get("seed", 0)), int(snap.get("ai", 0)))
	m.inventory = (snap.get("inventory", {}) as Dictionary).duplicate()
	m.items_allowed = bool(snap.get("items_allowed", true))
	m.held_swap = bool(snap.get("held_swap", false))
	m.level_cap = int(snap.get("level_cap", Spirling.LEVEL_SANITY))
	m.trainer_name = str(snap.get("trainer", ""))
	var tune: Variant = snap.get("profile_tune", {})
	m.ai.set_profile(str(snap.get("profile", "")), tune if tune is Dictionary else {})
	m.ai.spare_last = bool(snap.get("ai_spare_last", false))
	m.ai.no_double_rest = bool(snap.get("ai_no_double_rest", false))
	m.field = str(snap.get("field", ""))
	m.bench_share = float(snap.get("bench_share", 0.0))
	m.foe_rule = str(snap.get("rule", ""))
	m.rule_turn_full = bool(snap.get("rule_turn_full", false))
	m.foe_items = (snap.get("foe_items", {}) as Dictionary).duplicate()
	var front: Array = snap.get("front", [1, 1])
	m.front_size = [int(front[0]), int(front[1])]
	m.foe_boss = str(snap.get("boss", ""))
	m.wheel = snap.has("wheel")
	m.wheel_size = clampi(int(snap.get("wheel", 3)), 2, BattleModel.MAX_PARTY)
	m.foe_damage_mult = float(snap.get("foe_damage", 1.0))
	m.foe_crit_mult = clampf(float(snap.get("foe_crit", 1.0)), 0.0, 1.0)
	m.swap_locked = bool(snap.get("swap_locked", false))
	m.bond_block = str(snap.get("bond_block", ""))
	var blocked: Variant = snap.get("blocked_items", [])
	if blocked is Array:
		m.blocked_items.assign((blocked as Array).map(func(x: Variant) -> String: return str(x)))
	m.energy_bonus = [clampi(int(snap.get("energy_bonus", 0)), 0, ShopEffects.MAX_ENERGY_BONUS), 0]
	m.seals = [seal_row(snap.get("seals", [])), [0, 0, 0]]
	m.amulets = [ShopEffects.amulet_row(snap.get("amulets", [])), [0, 0, 0]]
	m.start_energy_cut = [0, clampi(int(snap.get("foe_energy_cut", 0)), 0, Tailwind.energy_cut(0) + BattleRules.foe_start_cut(0))]
	m.foe_turn1_energy = clampi(int(snap.get("foe_turn1_energy", 0)), 0, 1)
	m.warden_weakened = bool(snap.get("warden_weakened", false))
	# Only the pass's one Rift Breath can be a gift (item 4633).
	var gifts: Variant = snap.get("gifts", {})
	if gifts is Dictionary and int((gifts as Dictionary).get(ShopEffects.PASS_REVIVE, 0)) > 0:
		m.gift_items = {ShopEffects.PASS_REVIVE: 1}
	m.bond_grace = clampi(int(snap.get("bond_grace", 0)), 0, 1)
	m.bond_edge = clampf(float(snap.get("bond_edge", 0.0)), 0.0, ShopEffects.seal_percent("bond_edge", ShopEffects.seal_max("bond_edge")) / 100.0)
	m.boss_hp_scale = float(snap.get("boss_hp", 1.0))
	m.boss_difficulty = clampi(int(snap.get("boss_difficulty", -1)), -1, BattleRules.BOSS_PHASE_AT.size() - 1)
	m.variants.assign(snap.get("variants", []))
	m.round_limit = maxi(0, int(snap.get("round_limit", 0)))
	m.rest_heal_share = clampf(float(snap.get("rest_heal", 0.0)), 0.0, BattleModel.STORY_REST_HEAL)
	m.ambush = bool(snap.get("ambush", false)) and m.is_wild
	m.raid_phase = clampi(int(snap.get("raid_phase", 0)), 0, 9)
	m.initiative = bool(snap.get("initiative", false)) and not m.is_wild
	m.shift_offer = bool(snap.get("shift_offer", false)) and not m.is_wild
	m.foe_announce = bool(snap.get("foe_announce", false)) and not m.is_wild
	if not partner.is_empty():
		var ally: Array[Spirling] = _rebuild(partner.get("team", []))
		if ally.size() != (partner.get("team", []) as Array).size():
			return null
		m.set_partner(str(partner.get("name", "")), ally, int(partner.get("front", 1)), int(partner.get("ai", 1)), str(partner.get("profile", "")))
	return m

static func action_to_dict(a: BattleAction) -> Dictionary:
	return {"t": "turn", "k": int(a.kind), "m": a.move_index, "s": a.swap_index, "i": a.item_id,
		"g": a.item_target, "b": a.timing_score, "sl": a.slot, "tg": a.target_slot}

## One turn of a battle with several player slots: every action the player picked.
static func actions_to_dict(actions: Array[BattleAction]) -> Dictionary:
	var list: Array = []
	for a: BattleAction in actions:
		list.append(action_to_dict(a))
	return {"t": "turns", "a": list}

static func actions_from_dict(d: Dictionary) -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	for v: Variant in d.get("a", []):
		out.append(action_from_dict(v))
	return out

static func action_from_dict(d: Dictionary) -> BattleAction:
	var a := BattleAction.new()
	a.side = BattleModel.Side.PLAYER
	a.kind = clampi(int(d.get("k", 0)), 0, BattleAction.Kind.size() - 1) as BattleAction.Kind
	a.move_index = int(d.get("m", -1))
	a.swap_index = int(d.get("s", -1))
	a.item_id = str(d.get("i", ""))
	a.item_target = int(d.get("g", -1))
	a.timing_score = float(d.get("b", 0.0))
	a.slot = int(d.get("sl", 0))
	a.target_slot = int(d.get("tg", -1))
	return a

static func switch_to_dict(index: int) -> Dictionary:
	return {"t": "switch", "i": index}

## Giving up (KAMPF_PLAN_1000 item 8) and the answer to the swap offer (item 9, -1 stays).
static func forfeit_to_dict() -> Dictionary:
	return {"t": "forfeit"}

static func shift_to_dict(index: int) -> Dictionary:
	return {"t": "shift", "i": index}

## Plays a "forfeit" or "shift" input on [param m] and returns its events; null for any other
## input. A "shift" outside the swap offer is skipped (an empty list).
static func play_extra(m: BattleModel, d: Dictionary) -> Variant:
	match str(d.get("t", "")):
		"forfeit":
			return m.forfeit()
		"shift":
			if not m.needs_shift_choice():
				return [] as Array[BattleEvent]
			return m.submit_shift(int(d.get("i", -1)))
	return null

## Plays [param snap] to the end without a screen. Returns the outcome (used by tests).
static func simulate(snap: Dictionary) -> BattleModel.Outcome:
	var m: BattleModel = run(snap)
	return m.outcome if m != null else BattleModel.Outcome.NONE

## Plays [param snap] through a fresh model and returns it (null if it cannot be rebuilt).
## The battle referee on the server uses this (BattleReferee).
static func run(snap: Dictionary) -> BattleModel:
	var m: BattleModel = build_model(snap)
	if m == null:
		return null
	m.start()
	for v: Variant in snap.get("inputs", []):
		if m.is_finished():
			break
		var d: Dictionary = v
		if play_extra(m, d) != null:
			continue
		if str(d.get("t", "")) == "switch":
			m.submit_switch(int(d.get("i", 0)))
		elif str(d.get("t", "")) == "turns":
			m.submit_actions(actions_from_dict(d))
		else:
			m.submit_turn(action_from_dict(d))
	return m

## "Seed 1a2b3c4d" label for the Records screen.
static func label(snap: Dictionary) -> String:
	var who: String = str(snap.get("trainer", ""))
	if who.is_empty():
		var teams: Array = snap.get("teams", [[], [{}]])
		var foes: Array = teams[1]
		who = "wild %s" % str((foes[0] as Dictionary).get("species", "?")) if not foes.is_empty() else "?"
	return "%s, seed %08x" % [who, int(snap.get("seed", 0)) & 0xFFFFFFFF]
