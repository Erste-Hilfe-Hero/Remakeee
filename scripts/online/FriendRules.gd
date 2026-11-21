class_name FriendRules
extends RefCounted
## Friends and the shared world (Online 100, area 6: points 53, 55, 56, 57, 59, 60), shared by the
## game and LocalBackend. The server does the same in 20261112230020_friends_more.sql from
## server_config.friends_more (data/friends_more.json).

const CONFIG_PATH: String = "res://data/friends_more.json"
const DEFAULT_LEVELS: Array = [0, 10, 30, 60, 100, 150, 220, 300, 400, 520]
## Mail kinds a joint task can ask for, with the text the menu shows.
const TASK_TEXT: Dictionary = {
	"wave": "Wave to each other",
	"phrase": "Send each other a greeting",
	"gift": "Send each other a gift",
}

static var _cached: Dictionary = {}

static func config() -> Dictionary:
	if _cached.is_empty():
		var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var v: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_cached = v if v is Dictionary else {"levels": DEFAULT_LEVELS}
	return _cached

## Friendship level 1-10 from points (point 56; like public._level).
static func level(cfg: Dictionary, points: int) -> int:
	var n: int = 0
	for floor_pts: Variant in cfg.get("levels", DEFAULT_LEVELS):
		if points >= int(floor_pts):
			n += 1
	return maxi(1, n)

static func top_level(cfg: Dictionary) -> int:
	return (cfg.get("levels", DEFAULT_LEVELS) as Array).size()

## {"item", "count"} for reaching [param lvl], or {} when that level has no reward.
static func level_reward(cfg: Dictionary, lvl: int) -> Dictionary:
	var r: Variant = (cfg.get("level_rewards", {}) as Dictionary).get(str(lvl))
	return r if r is Dictionary else {}

## Today's joint task kind (point 57; like public._pair_kind): the same for everyone, by UTC day.
static func pair_kind(cfg: Dictionary, unix: int) -> String:
	var kinds: Array = cfg.get("pair_tasks", ["wave"])
	return str(kinds[(unix / 86400) % maxi(1, kinds.size())]) if not kinds.is_empty() else "wave"

static func task_text(kind: String) -> String:
	return str(TASK_TEXT.get(kind, kind))

## The invite link for a friend code (point 55): chimora://friend/<code>, opened by DeepLink.
static func invite_link(code: String) -> String:
	return "%s://friend/%s" % [DeepLink.SCHEME, code]
