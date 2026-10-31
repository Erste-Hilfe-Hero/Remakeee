extends Node
## Global player state. Saving and loading go through SaveManager (M4).

## Unbound-style difficulty, picked at new game.
enum Difficulty { STORY, TAMER, VETERAN, RIFT_BORN }
## Level cap per Rift sealed (Veteran + Rift-Born only).
const LEVEL_CAPS: Array[int] = [12, 18, 23, 28, 32, 36, 40, 44, 50]
const AI_LEVELS: Array[int] = [0, 1, 2, 2]
const MAX_PARTY: int = 6
enum TextSpeed { SLOW, NORMAL, FAST }
const TEXT_CPS: Array[float] = [30.0, 60.0, 140.0]

var party: Array[Spirling] = []
var region: String = "veydal"
var rifts_sealed: Array[String] = []
var difficulty: Difficulty = Difficulty.TAMER
## Item id -> count.
var inventory: Dictionary = {}
var money: int = 0

## Settings (also saved).
var text_speed: TextSpeed = TextSpeed.NORMAL
var fast_forward: bool = false
var volume: float = 0.8

func level_cap() -> int:
	if difficulty < Difficulty.VETERAN:
		return Spirling.MAX_LEVEL
	return LEVEL_CAPS[mini(rifts_sealed.size(), LEVEL_CAPS.size() - 1)]

func items_allowed_in_battle() -> bool:
	return difficulty != Difficulty.RIFT_BORN

## Trainer AI tier for the current difficulty: 0 random, 1 greedy, 2 lookahead.
func ai_level() -> int:
	return AI_LEVELS[difficulty]

func text_cps() -> float:
	return TEXT_CPS[text_speed]

func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))
