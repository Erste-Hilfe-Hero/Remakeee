class_name SafetyRules
extends RefCounted
## Safety and fairness (Online 100, area 9: points 83, 85, 86, 88), shared by the game and
## LocalBackend. The server does the same in 20261113000010_safety.sql from server_config.safety
## (data/safety.json).

const CONFIG_PATH: String = "res://data/safety.json"
const DEFAULTS: Dictionary = {"parent_keys": ["live_duel", "raid", "bund", "league_open", "league_fair", "suggest"],
	"young_band": 16, "young_off": ["league_open", "bund", "suggest"], "pair_rated_daily": 3, "sandbag_limit": 3,
	"sandbag_days": 7, "reports_per_hour": 10}
## What each parent switch is called in Settings, Account, For parents.
const KEY_TEXT: Dictionary = {
	"live_duel": "Live duels",
	"raid": "Raid Rifts",
	"bund": "Bunds",
	"league_open": "Open league",
	"league_fair": "Fair league",
	"suggest": "Suggestions from league battles",
}

static var _cached: Dictionary = {}

static func config() -> Dictionary:
	if _cached.is_empty():
		var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var v: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_cached = DEFAULTS.duplicate(true)
		if v is Dictionary:
			_cached.merge(v, true)
	return _cached

## The switched-off keys (points 85, 86): a parent's own list wins, else the default by age band
## (null = age not asked yet, counts as grown-up like the server).
static func off_list(cfg: Dictionary, custom: Variant, band: Variant) -> Array:
	if custom is Array:
		return (custom as Array).duplicate()
	if band != null and int(band) < int(cfg.get("young_band", 16)):
		return (cfg.get("young_off", []) as Array).duplicate()
	return []

## True when [param list] is a list of known parent keys.
static func keys_ok(cfg: Dictionary, list: Variant) -> bool:
	if not list is Array:
		return false
	for k: Variant in list:
		if not (cfg.get("parent_keys", []) as Array).has(k):
			return false
	return true

## A rated loss without any damage to the rival counts as sandbagged (point 88).
static func sandbagged(detail: Variant) -> bool:
	return detail is Dictionary and str(detail.get("winner", "")) != "player" and detail.has("foe_damage") \
		and int(detail.foe_damage) == 0

static func key_text(key: String) -> String:
	return str(KEY_TEXT.get(key, key))
