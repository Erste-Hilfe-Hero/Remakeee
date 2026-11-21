extends GutTest
## Save fuzzer (plan item 3711): changes the fixture saves at random 2000 times (drops fields,
## swaps types, flips numbers, cuts the text) and loads each one. Loading must never raise an
## engine or script error; it either loads or reports the save as unreadable.

const FIXTURES: String = "res://tests/fixtures/saves/"
const ROUNDS: int = 2000
const SEED: int = 3711

var _rng := RandomNumberGenerator.new()
var _bases: Array[Dictionary] = []

func before_all() -> void:
	Database.load_all()
	_rng.seed = SEED
	for f: String in DirAccess.get_files_at(FIXTURES):
		if f.ends_with(".json"):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + f))
			if d is Dictionary:
				_bases.append(d)
	var current: Dictionary = SaveManager.build_save()
	_bases.append(JSON.parse_string(JSON.stringify(current)))

func after_all() -> void:
	GameState.reset()

func _odd_value() -> Variant:
	match _rng.randi_range(0, 9):
		0: return null
		1: return "x".repeat(_rng.randi_range(0, 300))
		2: return -9223372036854775807
		3: return 1e300
		4: return []
		5: return {}
		6: return [null, "a", 3]
		7: return {"0": {"1": [2]}}
		8: return true
	return _rng.randi_range(-1000000, 1000000)

## Changes one random value somewhere inside [param v] and returns the result.
func _mutate(v: Variant, depth: int = 0) -> Variant:
	if depth > 4 or _rng.randf() < 0.25:
		return _odd_value()
	if v is Dictionary and not (v as Dictionary).is_empty():
		var d: Dictionary = v
		var key: Variant = d.keys()[_rng.randi_range(0, d.size() - 1)]
		var roll: float = _rng.randf()
		if roll < 0.2:
			d.erase(key)
		elif roll < 0.3:
			d["fuzz_%d" % _rng.randi()] = _odd_value()
		else:
			d[key] = _mutate(d[key], depth + 1)
		return d
	if v is Array and not (v as Array).is_empty():
		var a: Array = v
		var i: int = _rng.randi_range(0, a.size() - 1)
		if _rng.randf() < 0.2:
			a.remove_at(i)
		else:
			a[i] = _mutate(a[i], depth + 1)
		return a
	if v is int or v is float:
		# Stay inside what a double can hold: JSON warns on numbers past 1e308.
		return -v if _rng.randf() < 0.5 or absf(float(v)) > 1e12 else v * 1000003
	return _odd_value()

func test_mutated_saves_never_crash_the_loader() -> void:
	assert_gt(_bases.size(), 1, "fixtures found")
	var loaded: int = 0
	for i: int in range(ROUNDS):
		var d: Variant = JSON.parse_string(JSON.stringify(_bases[i % _bases.size()]))
		for _n: int in range(_rng.randi_range(1, 4)):
			d = _mutate(d)
		var text: String = JSON.stringify(d, "\t")
		if _rng.randf() < 0.1:
			text = text.left(_rng.randi_range(0, text.length()))
		var parsed: Variant = SaveManager.parse_save(text)
		if parsed is Dictionary:
			SaveManager.apply_save(parsed)
			SaveManager.summary_line(parsed)
			loaded += 1
	assert_gt(loaded, ROUNDS / 2, "most mutated saves still load")
