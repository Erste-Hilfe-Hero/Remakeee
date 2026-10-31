class_name Spirling
extends RefCounted
## A Spirling instance owned by a Tamer or met in the wild.
var data: SpirlingData
var level: int
var spark := {}        # hidden 0-15 per stat
var hp: int
var energy := 10
var status := ""
var moves: Array[MoveData] = []

func _init(d: SpirlingData, lvl: int) -> void:
	data = d
	level = lvl
	for s in ["hp", "atk", "def", "foc", "spd"]:
		spark[s] = randi_range(0, 15)
	hp = max_hp()

func _stat(base: int, key: String) -> int:
	return int(floor((base * 2 + spark[key]) * level / 100.0)) + 5

func max_hp() -> int: return _stat(data.base_hp, "hp") + level + 10
func atk() -> int: return _stat(data.base_atk, "atk")
func def() -> int: return _stat(data.base_def, "def")
func foc() -> int: return _stat(data.base_foc, "foc")
func spd() -> int:
	var s := _stat(data.base_spd, "spd")
	return s / 2 if status == "soak" else s
