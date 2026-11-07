class_name MarkerStones
extends RefCounted
## Cartographer's stones (area 3 items 1084, 1085): twelve old stones with a compass rose, one on
## every outdoor map of Veydal. Looking at one counts it (flag "marker_stone_<n>"); the 4th, 8th
## and 12th stone each give a keepsake that is tucked behind it.

const TOTAL: int = 12
const REWARDS: Dictionary[int, String] = {4: "iron_burr", 8: "keen_lens", 12: "bark_wrap"}

static func flag(n: int) -> String:
	return "marker_stone_%d" % n

static func found(flags: Dictionary) -> int:
	var c: int = 0
	for n: int in range(1, TOTAL + 1):
		if bool(flags.get(flag(n), false)):
			c += 1
	return c

## Counts stone [param n]. Returns {"new": bool, "found": int, "reward": item id or ""}.
static func visit(n: int) -> Dictionary:
	if n < 1 or n > TOTAL or GameState.has_flag(flag(n)):
		return {"new": false, "found": found(GameState.flags), "reward": ""}
	GameState.set_flag(flag(n))
	var c: int = found(GameState.flags)
	var reward: String = REWARDS.get(c, "")
	if not reward.is_empty():
		GameState.add_item(reward)
	return {"new": true, "found": c, "reward": reward}
