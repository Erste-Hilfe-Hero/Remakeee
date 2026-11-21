class_name MarkerStones
extends RefCounted
## Cartographer's stones (area 3 items 1084, 1085; Corvane: item 1312): twelve old stones with a
## compass rose per region. Veydal has one on every outdoor map, Corvane spreads its twelve over
## its towns, routes and two Rift hollows. Looking at one counts it (flag "marker_stone_<n>" in
## Veydal, "marker_stone_<region>_<n>" elsewhere); the 4th, 8th and 12th stone of a region each
## give a keepsake that is tucked behind it.

const TOTAL: int = 12
const REWARDS: Dictionary[int, String] = {4: "iron_burr", 8: "keen_lens", 12: "bark_wrap"}
## Keepsakes for the other regions' stones.
const REGION_REWARDS: Dictionary[String, Dictionary] = {
	"corvane": {4: "swift_feather", 8: "spark_coil", 12: "keen_lens"},
}

static func flag(n: int, region: String = "veydal") -> String:
	return "marker_stone_%d" % n if region == "veydal" else "marker_stone_%s_%d" % [region, n]

static func found(flags: Dictionary, region: String = "veydal") -> int:
	var c: int = 0
	for n: int in range(1, TOTAL + 1):
		if bool(flags.get(flag(n, region), false)):
			c += 1
	return c

static func rewards(region: String = "veydal") -> Dictionary:
	return REWARDS if region == "veydal" else REGION_REWARDS.get(region, {})

## Counts stone [param n] of [param region]. Returns {"new": bool, "found": int, "reward": item id or ""}.
static func visit(n: int, region: String = "veydal") -> Dictionary:
	if n < 1 or n > TOTAL or GameState.has_flag(flag(n, region)):
		return {"new": false, "found": found(GameState.flags, region), "reward": ""}
	GameState.set_flag(flag(n, region))
	var c: int = found(GameState.flags, region)
	var reward: String = str(rewards(region).get(c, ""))
	if not reward.is_empty():
		GameState.add_item(reward)
	return {"new": true, "found": c, "reward": reward}
