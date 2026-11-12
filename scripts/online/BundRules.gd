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
