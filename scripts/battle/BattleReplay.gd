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
		"teams": [_team(model.party(BattleModel.Side.PLAYER)), _team(model.party(BattleModel.Side.FOE))],
		"inventory": model.inventory.duplicate(),
		"items_allowed": model.items_allowed,
		"level_cap": model.level_cap,
		"trainer": model.trainer_name,
		"field": model.field,
		"rule": model.foe_rule,
		"foe_items": model.foe_items.duplicate(),
		"music": music,
		"backdrop": backdrop,
		"inputs": [],
	}

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
	var mine: Array[Spirling] = _rebuild(teams[0])
	var foes: Array[Spirling] = _rebuild(teams[1])
	if mine.size() != (teams[0] as Array).size() or foes.size() != (teams[1] as Array).size() or foes.is_empty():
		return null
	var m := BattleModel.new(mine, foes, bool(snap.get("wild", true)), int(snap.get("seed", 0)), int(snap.get("ai", 0)))
	m.inventory = (snap.get("inventory", {}) as Dictionary).duplicate()
	m.items_allowed = bool(snap.get("items_allowed", true))
	m.level_cap = int(snap.get("level_cap", Spirling.MAX_LEVEL))
	m.trainer_name = str(snap.get("trainer", ""))
	m.field = str(snap.get("field", ""))
	m.foe_rule = str(snap.get("rule", ""))
	m.foe_items = (snap.get("foe_items", {}) as Dictionary).duplicate()
	return m

static func action_to_dict(a: BattleAction) -> Dictionary:
	return {"t": "turn", "k": int(a.kind), "m": a.move_index, "s": a.swap_index, "i": a.item_id,
		"g": a.item_target, "b": a.timing_score}

static func action_from_dict(d: Dictionary) -> BattleAction:
	var a := BattleAction.new()
	a.side = BattleModel.Side.PLAYER
	a.kind = clampi(int(d.get("k", 0)), 0, BattleAction.Kind.size() - 1) as BattleAction.Kind
	a.move_index = int(d.get("m", -1))
	a.swap_index = int(d.get("s", -1))
	a.item_id = str(d.get("i", ""))
	a.item_target = int(d.get("g", -1))
	a.timing_score = float(d.get("b", 0.0))
	return a

static func switch_to_dict(index: int) -> Dictionary:
	return {"t": "switch", "i": index}

## Plays [param snap] to the end without a screen. Returns the outcome (used by tests).
static func simulate(snap: Dictionary) -> BattleModel.Outcome:
	var m: BattleModel = build_model(snap)
	if m == null:
		return BattleModel.Outcome.NONE
	m.start()
	for v: Variant in snap.get("inputs", []):
		if m.is_finished():
			break
		var d: Dictionary = v
		if str(d.get("t", "")) == "switch":
			m.submit_switch(int(d.get("i", 0)))
		else:
			m.submit_turn(action_from_dict(d))
	return m.outcome

## "Seed 1a2b3c4d" label for the Records screen.
static func label(snap: Dictionary) -> String:
	var who: String = str(snap.get("trainer", ""))
	if who.is_empty():
		var teams: Array = snap.get("teams", [[], [{}]])
		var foes: Array = teams[1]
		who = "wild %s" % str((foes[0] as Dictionary).get("species", "?")) if not foes.is_empty() else "?"
	return "%s, seed %08x" % [who, int(snap.get("seed", 0)) & 0xFFFFFFFF]
