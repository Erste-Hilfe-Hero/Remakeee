class_name TowerWeek
extends RefCounted
## Tower rules change weekly (plan item 1103): every ISO week the towers use one rule from
## data/ideas200.json "tower_week", the same for everyone.

static func rules() -> Array:
	var d: Dictionary = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/ideas200.json")))
	return (d.get("tower_week", {}) as Dictionary).get("rules", [])

## The rule id of [param week_key] such as "2026-W46".
static func rule(week_key: String) -> String:
	var r: Array = rules()
	return str(r[absi(hash("chimora-tower-" + week_key)) % r.size()]) if not r.is_empty() else ""

static func label(week_key: String) -> String:
	var id: String = rule(week_key)
	return Loc.t(str(BattleRules.RULES[id].label)) if BattleRules.RULES.has(id) else ""
