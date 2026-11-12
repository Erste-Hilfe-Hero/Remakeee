class_name FineTraining
extends RefCounted
## Fine training for values (plan item 1114): Coach Varro raises one spark of a Spirling by 1
## for coins. Each spark point costs more. Sometimes he just takes the money (scam_chance).

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Dictionary = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/ideas200.json")))
		_data = d.get("fine_training", {})
	return _data

static func cost(s: Spirling, stat: String) -> int:
	return int(data().get("base_cost", 200)) + int(data().get("cost_step", 100)) * int(s.spark.get(stat, 0))

static func can_train(s: Spirling, stat: String) -> bool:
	return stat in Spirling.STAT_KEYS and int(s.spark.get(stat, 0)) < Spirling.SPARK_MAX and GameState.money >= cost(s, stat)

## Pays and trains. Returns {"ok": bool, "scammed": bool, "line": String}.
static func train(s: Spirling, stat: String, rng: RandomNumberGenerator) -> Dictionary:
	if not can_train(s, stat):
		return {"ok": false, "scammed": false, "line": ""}
	GameState.money -= cost(s, stat)
	if rng.randf() < float(data().get("scam_chance", 0.0)):
		return {"ok": true, "scammed": true, "line": Loc.t(str(data().get("scam_line", "")))}
	s.spark[stat] = int(s.spark.get(stat, 0)) + 1
	return {"ok": true, "scammed": false, "line": Loc.t(str(data().get("done_line", ""))) % s.display_name()}
