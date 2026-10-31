extends Node
## Global player state + JSON save in user://
const SAVE_PATH := "user://save.json"
var party: Array = []
var region := "veydal"
var rifts_sealed: Array[String] = []

## Unbound-style difficulty, picked at new game.
enum Difficulty { STORY, TAMER, VETERAN, RIFT_BORN }
var difficulty: Difficulty = Difficulty.TAMER
## Level cap per Rift sealed (Veteran + Rift-Born only).
const LEVEL_CAPS := [12, 18, 23, 28, 32, 36, 40, 44, 50]

func level_cap() -> int:
	if difficulty < Difficulty.VETERAN:
		return 100
	return LEVEL_CAPS[min(rifts_sealed.size(), LEVEL_CAPS.size() - 1)]

func items_allowed_in_battle() -> bool:
	return difficulty != Difficulty.RIFT_BORN

## Enemy AI depth: 0 = random, 1 = picks super-effective, 2 = predicts swaps.
func ai_level() -> int:
	return [0, 1, 2, 2][difficulty]

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"region": region, "rifts": rifts_sealed, "difficulty": difficulty}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d:
		region = d.get("region", "veydal")
		rifts_sealed.assign(d.get("rifts", []))
		difficulty = int(d.get("difficulty", Difficulty.TAMER))
