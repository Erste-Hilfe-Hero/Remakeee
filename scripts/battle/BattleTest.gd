extends Node
## Headless sanity battle: Kindlop vs Mossling, auto-played by two greedy AIs, printed to output.

const SEED: int = 12345

func _ready() -> void:
	Database.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 8, rng)]
	var theirs: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 8, rng)]
	var model := BattleModel.new(mine, theirs, true, SEED, 1)
	var player_ai := BattleAI.new(1)
	_print(model.start())
	while not model.is_finished() and model.turn < 50:
		_print(model.submit_turn(player_ai.choose(model, BattleModel.Side.PLAYER)))
	print("Bond chance at full HP, perfect timing: %.2f" % BondCalc.chance(theirs[0], 1.0))

func _print(events: Array[BattleEvent]) -> void:
	for e: BattleEvent in events:
		var line: String = e.describe()
		if not line.is_empty():
			print(line)
