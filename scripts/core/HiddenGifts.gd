class_name HiddenGifts
extends RefCounted
## Hidden gifts (plan items 4756-4758): every line has one, from data/hidden_gifts.json. The
## informant on Corvane Quay sells the tip that reveals a line's gift (records "gift_tips");
## a stale tip costs only that fee. reveal() is also the hook for any other source (the shop's
## Gift Key of item 4756). A Spirling of a revealed line at the unlock ring may wake the gift
## (Spirling.hidden_gift) and put it back to sleep at any time; nothing is ever taken away.

const DATA_PATH: String = "res://data/hidden_gifts.json"
const TIPS: String = "gift_tips"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

## Effect table of a hidden gift id, or {}.
static func gift(id: String) -> Dictionary:
	return data().get("gifts", {}).get(id, {})

## The hidden gift id of [param sd]'s line.
static func gift_id(sd: SpirlingData) -> String:
	if sd == null:
		return ""
	var by_line: Dictionary = data().get("lines", {})
	if by_line.has(sd.line_id):
		return str(by_line[sd.line_id])
	if sd.elements.is_empty():
		return ""
	return str(data().get("by_element", {}).get(str(Elements.E.find_key(sd.elements[0])), ""))

static func revealed(line_id: String) -> bool:
	return line_id in GameState.records.get(TIPS, [])

static func reveal(line_id: String) -> void:
	var tips: Array = GameState.records.get(TIPS, [])
	if not line_id in tips:
		tips.append(line_id)
	GameState.records[TIPS] = tips

## Buys a tip on [param sd]'s line. Returns {"ok": bool, "stale": bool, "line": String};
## ok is false when the money is short (nothing paid).
static func buy_tip(sd: SpirlingData, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = data()
	var cost: int = int(d.get("tip_cost", 0))
	if GameState.money < cost:
		return {"ok": false, "stale": false, "line": ""}
	GameState.money -= cost
	if rng.randf() < float(d.get("betray_chance", 0.0)):
		return {"ok": true, "stale": true, "line": Loc.t(str(d.get("stale_tip", "")))}
	reveal(sd.line_id)
	var g: Dictionary = gift(gift_id(sd))
	return {"ok": true, "stale": false, "line": Loc.t(str(d.get("true_tip", ""))) % [GameState.first_form(sd).species_name, Loc.t(str(g.get("label", "")))]}

## True when [param s] may wake (or already has) its hidden gift.
static func can_wake(s: Spirling) -> bool:
	return revealed(s.data.line_id) and s.level >= int(data().get("unlock_ring", 20)) and not gift_id(s.data).is_empty()

## Wakes or sleeps the hidden gift of [param s]; returns the new state.
static func toggle(s: Spirling) -> bool:
	if not s.hidden_gift and not can_wake(s):
		return false
	s.hidden_gift = not s.hidden_gift
	return s.hidden_gift
