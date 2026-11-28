class_name WayfarerRewards
extends RefCounted
## Varying Wayfarer rewards (KAMPF_PLAN_1000 item 531): on the first win a Wayfarer adds one item
## from data/wayfarer_rewards.json, from the tier of its highest ring. The pick depends only on the
## map and the Wayfarer, so it is the same on every journey; each Wayfarer gives it once.

const PATH: String = "res://data/wayfarer_rewards.json"
const KEY: String = "wayfarer_gifts"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {"tiers": []}
	return _data

## True for a Wayfarer that gives a first-win gift (no Warden, Rift boss or wild horde).
static func gives(def: Dictionary) -> bool:
	return TrainerData.is_trainer(def) and not def.has("warden") and not def.has("boss") and not TrainerData.is_wild_horde(def)

## The highest ring in the Wayfarer's team as written in the map.
static func top_ring(def: Dictionary, starter: String) -> int:
	var top: int = 0
	for e: Variant in TrainerData.team_entries(def, starter):
		if e is Dictionary:
			top = maxi(top, int((e as Dictionary).get("level", 5)))
	return top

## The item this Wayfarer gives, or "" when it gives none.
static func pick(def: Dictionary, map_id: String, ring: int) -> String:
	if not gives(def):
		return ""
	var tiers: Array = data().get("tiers", [])
	for t: Variant in tiers:
		if t is Dictionary and ring <= int((t as Dictionary).get("max_ring", 0)):
			var items: Array = (t as Dictionary).get("items", [])
			if items.is_empty():
				return ""
			return str(items[absi(("%s/%s" % [map_id, str(def.get("id", ""))]).hash()) % items.size()])
	return ""

## Gives the first-win item once and returns its id, or "" (none, or already given).
static func grant(def: Dictionary, map_id: String, starter: String) -> String:
	var given: Dictionary = GameState.records.get(KEY, {})
	var key: String = TrainerData.beaten_flag(def, map_id)
	if given.has(key):
		return ""
	var item: String = pick(def, map_id, top_ring(def, starter))
	if item.is_empty():
		return ""
	given = given.duplicate()
	given[key] = item
	GameState.records[KEY] = given
	GameState.add_item(item)
	return item

## "Ridgewalker Bram also gives you a Tonic."
static func line(def: Dictionary, item: String) -> String:
	var item_name: String = Loc.t(str(Database.item(item).get("name", item)))
	return Loc.t("%s also gives you: %s.") % [Loc.t(str(def.get("trainer", ""))), item_name]
