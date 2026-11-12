class_name ChallengeRules
extends RefCounted
## Selectable challenge rules (plan item 1112), kept in GameState.records["challenges"].
## The checks are pure so the party, bag, shop and Warden code can ask them.

const KEY: String = "challenges"

static var _list: Array = []

static func list() -> Array:
	if _list.is_empty():
		_list = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/ideas200.json"))).get("challenges", [])
	return _list

static func ids() -> Array[String]:
	var out: Array[String] = []
	for c: Variant in list():
		out.append(str((c as Dictionary).id))
	return out

static func active(id: String) -> bool:
	return id in GameState.records.get(KEY, [])

static func toggle(id: String) -> void:
	if not id in ids():
		return
	var cur: Array = (GameState.records.get(KEY, []) as Array).duplicate()
	if id in cur:
		cur.erase(id)
	else:
		cur.append(id)
	GameState.records[KEY] = cur

## One Colour: may [param sd] join, given the starter's species data [param starter]?
static func may_join(sd: SpirlingData, starter: SpirlingData) -> bool:
	if not active("one_element") or starter == null:
		return true
	for e: int in sd.elements:
		if e in starter.elements:
			return true
	return false

static func items_allowed() -> bool:
	return not active("no_items")

static func shop_open() -> bool:
	return not active("no_shop")

## Trust No One: the party index that walks off after a Warden, -1 when the rule is off or one is left.
static func walkout(party_size: int, rng: RandomNumberGenerator) -> int:
	if not active("trust_no_one") or party_size <= 1:
		return -1
	return rng.randi_range(0, party_size - 1)
