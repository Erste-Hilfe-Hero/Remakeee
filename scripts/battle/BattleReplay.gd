class_name BattleReplay
extends RefCounted
## Battle replays (item 14). A battle is fully decided by its seed, both starting teams and the
## player's inputs, so a replay stores only those and plays them back through a fresh model.
## The last battle is kept in GameState.records["last_battle"]; watching it changes nothing.

## Everything needed to rebuild [param model] as it is before start(). Call before the battle.
static func snapshot(model: BattleModel, music: String, backdrop: String) -> Dictionary:
	return {
		"seed": model.battle_seed,
		"wild": model.is_wild,
		"ai": model.ai.level,
		"profile": model.ai.profile_id,
		"teams": [_team(model.party(BattleModel.Side.PLAYER)), _team(model.party(BattleModel.Side.FOE))],
		"inventory": model.inventory.duplicate(),
		"items_allowed": model.items_allowed,
		"level_cap": model.level_cap,
		"trainer": model.trainer_name,
		"field": model.field,
		"bench_share": model.bench_share,
		"rule": model.foe_rule,
		"foe_items": model.foe_items.duplicate(),
		"front": [model.front_size[0], model.front_size[1]],
		"partner": _partner(model),
		"boss": model.foe_boss,
		"foe_damage": model.foe_damage_mult,
		"energy_bonus": model.energy_bonus[0],
		"boss_hp": model.boss_hp_scale,
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
static func build_model(snap: Dictionary) -> BattleModel:
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
	m.level_cap = int(snap.get("level_cap", Spirling.MAX_LEVEL))
	m.trainer_name = str(snap.get("trainer", ""))
	m.ai.set_profile(str(snap.get("profile", "")))
	m.field = str(snap.get("field", ""))
	m.bench_share = float(snap.get("bench_share", 0.0))
	m.foe_rule = str(snap.get("rule", ""))
	m.foe_items = (snap.get("foe_items", {}) as Dictionary).duplicate()
	var front: Array = snap.get("front", [1, 1])
	m.front_size = [int(front[0]), int(front[1])]
	m.foe_boss = str(snap.get("boss", ""))
	m.foe_damage_mult = float(snap.get("foe_damage", 1.0))
	m.energy_bonus = [clampi(int(snap.get("energy_bonus", 0)), 0, ShopEffects.OVERCHARGE), 0]
	m.boss_hp_scale = float(snap.get("boss_hp", 1.0))
	m.variants.assign(snap.get("variants", []))
	m.round_limit = maxi(0, int(snap.get("round_limit", 0)))
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
