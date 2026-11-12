class_name NewGamePlus
extends RefCounted
## New Game Plus (plan item 1111): after the finale the story can start again with stronger foes.
## Each cycle adds ring_bonus rings to every foe, up to max_cycles. The cycle lives in records.

const KEY: String = "ng_plus_cycle"

static func data() -> Dictionary:
	return GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/ideas200.json"))).get("ng_plus", {})

static func cycle() -> int:
	return int(GameState.records.get(KEY, 0))

## A foe's ring in the current cycle.
static func foe_ring(base: int) -> int:
	return clampi(base + cycle() * int(data().get("ring_bonus", 0)), 1, Spirling.MAX_LEVEL)

static func can_start(finale_done: bool) -> bool:
	return finale_done and cycle() < int(data().get("max_cycles", 1))

## The save parts that carry over into the next cycle.
static func kept() -> Array:
	return data().get("keep", [])

## Raises the cycle; the caller restarts the story. Returns the new cycle.
static func advance() -> int:
	GameState.records[KEY] = cycle() + 1
	return cycle()
