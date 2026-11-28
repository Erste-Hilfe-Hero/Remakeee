class_name MultiSim
extends RefCounted
## Multi-battle balance in the simulator (docs/KAMPF_PLAN_1000.md, item 383): random 2v2
## mirror matches where one side carries a support art (team heal, ally heal, team guard,
## decoy or cover) in place of its last art. The support side should win neither almost
## always nor almost never: data/multi_rules.json "sim" holds the band. The sides swap every
## battle, so the player-side tiebreak never decides the result.

## The support side's share of wins over [param battles] (draws count half), with the band.
static func support_rate(battles: int, seed_value: int, level: int = 30) -> Dictionary:
	Database.load_all()
	var cfg: Dictionary = MultiRules.data().get("sim", {})
	var arts: Array = cfg.get("arts", [])
	var pool: Array[String] = BalanceSim.valid_species(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "multi"])
	var wins: float = 0.0
	for b: int in battles:
		var names: Array[String] = BalanceSim._pick(pool, 2, rng)
		var bseed: int = rng.randi()
		var support_side: int = b % 2
		var teams: Array = [[], []]
		for side: int in 2:
			var team_rng := RandomNumberGenerator.new()
			team_rng.seed = bseed
			for n: String in names:
				var s := Spirling.new(Database.species(n), level, team_rng)
				if side == support_side and not arts.is_empty():
					var mv: MoveData = Database.move(str(arts[rng.randi_range(0, arts.size() - 1)]))
					if mv != null and s.moves.size() >= 4:
						s.moves[_weakest(s)] = mv
					elif mv != null:
						s.moves.append(mv)
				teams[side].append(s)
		var winner: int = _battle(teams[0], teams[1], bseed, int(cfg.get("ai", 2)))
		if winner == support_side:
			wins += 1.0
		elif winner < 0:
			wins += 0.5
	var band: Array = cfg.get("band", [0.3, 0.7])
	var rate: float = wins / float(maxi(battles, 1))
	return {"rate": snappedf(rate, 0.001), "band": band, "ok": rate >= float(band[0]) and rate <= float(band[1])}

## Index of the art with the least power: the one a support art takes the place of.
static func _weakest(s: Spirling) -> int:
	var at: int = 0
	for i: int in s.moves.size():
		if s.moves[i].power < s.moves[at].power:
			at = i
	return at

## One 2v2 battle, both sides on AI tier [param ai]; returns 0, 1 or -1 for a draw.
static func _battle(a: Array, b: Array, seed_value: int, ai: int) -> int:
	var mine: Array[Spirling] = []
	mine.assign(a)
	var theirs: Array[Spirling] = []
	theirs.assign(b)
	var m := BattleModel.new(mine, theirs, false, seed_value, ai)
	m.items_allowed = false
	m.front_size = [2, 2]
	m.start()
	var brain := BattleAI.new(ai)
	var guard: int = 0
	while not m.is_finished() and guard < BalanceSim.MAX_TURNS * 2:
		guard += 1
		if m.needs_player_switch():
			m.submit_switch(m.swap_candidates(BattleModel.Side.PLAYER, m.switch_slot())[0])
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			acts.append(brain.choose(m, BattleModel.Side.PLAYER, slot))
		m.submit_actions(acts)
	return BalanceSim.sim_winner(m)
