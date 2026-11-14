class_name BundRules
extends RefCounted
## Bund extras (Online 100, points 33, 34, 36, 38, 39, 40), shared by the game and LocalBackend.
## The server does the same in 20261111000060_bund_more.sql from server_config.bund_rules.

const CONFIG_PATH: String = "res://data/bund_rules.json"
const LANG_NAMES: Dictionary = {"de": "Deutsch", "en": "English", "tr": "Türkçe", "pl": "Polski", "nl": "Nederlands",
	"fr": "Français", "es": "Español", "it": "Italiano"}

static func config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

## Bund level 1 to level_max from its xp (point 34).
static func level(cfg: Dictionary, xp: int) -> int:
	return mini(int(cfg.get("level_max", 20)), 1 + xp / maxi(1, int(cfg.get("xp_per_level", 500))))

## Xp for donating [param count] items (point 36).
static func donate_xp(cfg: Dictionary, count: int) -> int:
	return count * int(cfg.get("xp_per_item", 10))

static func lang_ok(cfg: Dictionary, lang: String) -> bool:
	return lang.is_empty() or (cfg.get("langs", []) as Array).has(lang)

# --- Perks, bund house, bund against bund (points 34, 35, 37; 20261113000020_raid_bund_more.sql) ---

## Names of the decorations in the bund house (ids in bund_rules.decor).
const DECOR_NAMES: Dictionary = {"lantern": "Lantern", "banner": "Bund banner", "bench": "Long bench", "map_table": "Map table",
	"fountain": "Fountain", "trophy_shelf": "Trophy shelf", "star_window": "Star window", "great_hearth": "Great hearth"}
const PERK_TEXT: Dictionary = {"house_slots": "+%d places in the bund house", "donate_more": "+%d donations a day",
	"goal_more": "+%d items from the week goal"}

## Sum of perk [param key] for bund [param lvl]: every perk up to the rank counts.
static func perk(cfg: Dictionary, lvl: int, key: String) -> int:
	var n: int = 0
	for p: Dictionary in cfg.get("perks", []):
		if str(p.key) == key and int(p.level) <= lvl:
			n += int(p.value)
	return n

static func house_slots(cfg: Dictionary, lvl: int) -> int:
	return int(cfg.get("house_slots", 3)) + perk(cfg, lvl, "house_slots")

## Decoration ids open at bund rank [param lvl].
static func decor_open(cfg: Dictionary, lvl: int) -> Array:
	var out: Array = []
	for d: Dictionary in cfg.get("decor", []):
		if int(d.get("level", 1)) <= lvl:
			out.append(str(d.id))
	return out

## A house list is fine when it fits the slots, repeats nothing and uses only open decorations.
static func house_ok(cfg: Dictionary, lvl: int, house: Variant) -> bool:
	if not house is Array or (house as Array).size() > house_slots(cfg, lvl):
		return false
	var open: Array = decor_open(cfg, lvl)
	var seen: Dictionary = {}
	for v: Variant in house:
		if not v is String or not open.has(v) or seen.has(v):
			return false
		seen[v] = true
	return true

## True on a war day (ISO weekday 1 = Monday ... 7 = Sunday, UTC).
static func war_day(cfg: Dictionary, unix: int) -> bool:
	var wd: int = int(Time.get_datetime_dict_from_unix_time(unix).weekday)
	return (cfg.get("war_days", [6, 7]) as Array).has(7 if wd == 0 else wd)

static func perk_line(p: Dictionary) -> String:
	return Loc.t("Rank %d: %s") % [int(p.level), Loc.t(str(PERK_TEXT.get(str(p.key), str(p.key)))) % int(p.value)]
