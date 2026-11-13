class_name BattleReport
extends RefCounted
## The end-of-battle report (docs/KAMPF_PLAN_1000.md, items 335 and 393): what each of your
## Spirlings dealt and knocked out, and the Rift fields the battle was fought in. It is built
## from the played events alone, so the model needs no extra bookkeeping. The lines go into the
## battle log; after a won battle with several Spirlings the best one is also named.

## Per player Spirling (by party index, in the order they first hit): {"name", "damage", "kos"}.
var rows: Dictionary = {}
## The fields in play, in the order they came up (no repeats).
var fields: Array[String] = []
## Items your side used up, by name (item 296): bag items and eaten held fruit.
var items: Dictionary = {}
var _actor: Dictionary = {}

## Starts with the field already in place when the battle opens ("" for none).
func begin(start_field: String) -> void:
	rows.clear()
	fields.clear()
	items.clear()
	_actor = {}
	_note_field(start_field)

## Takes one played event.
func add(e: BattleEvent) -> void:
	match e.type:
		BattleEvent.Type.MOVE_USED:
			_actor = {"side": int(e.data.get("side", -1)), "index": int(e.data.get("index", -1)), "name": str(e.data.get("name", ""))}
		BattleEvent.Type.DAMAGE:
			# Only hits from an art count, and only those on the other side of whoever used it.
			if _credited(e) and e.data.has("move"):
				_row().damage += int(e.data.get("amount", 0))
		BattleEvent.Type.FAINTED:
			if _credited(e):
				_row().kos += 1
		BattleEvent.Type.FIELD:
			_note_field(str(e.data.get("field", "")))
		BattleEvent.Type.ITEM_USED, BattleEvent.Type.HELD_FRUIT:
			if int(e.data.get("side", -1)) == BattleModel.Side.PLAYER:
				var n: String = str(e.data.get("item_name", ""))
				items[n] = int(items.get(n, 0)) + 1

func _credited(e: BattleEvent) -> bool:
	return int(_actor.get("side", -1)) == BattleModel.Side.PLAYER and not str(_actor.get("name", "")).is_empty() \
		and int(e.data.get("side", -1)) == BattleModel.Side.FOE

func _row() -> Dictionary:
	var k: int = int(_actor.get("index", -1))
	if not rows.has(k):
		rows[k] = {"name": str(_actor.name), "damage": 0, "kos": 0}
	return rows[k]

func _note_field(id: String) -> void:
	if BattleRules.FIELDS.has(id) and not fields.has(id):
		fields.append(id)

## The line for the Spirling at party index [param k].
func spirling_line(k: int) -> String:
	var r: Dictionary = rows.get(k, {"name": "", "damage": 0, "kos": 0})
	if int(r.kos) > 0:
		return "%s: %d damage, %d knocked out" % [str(r.name), int(r.damage), int(r.kos)]
	return "%s: %d damage" % [str(r.name), int(r.damage)]

## "Rift fields: High Tide, Static Veil", or "" when no field came up.
func field_line() -> String:
	if fields.is_empty():
		return ""
	var names: PackedStringArray = []
	for f: String in fields:
		names.append(str(BattleRules.FIELDS[f].label))
	return "Rift fields: %s" % ", ".join(names)

## "Items used: Max Tonic x2, Ember Pith x1", or "" when none was used (item 296).
func item_line() -> String:
	if items.is_empty():
		return ""
	var parts: PackedStringArray = []
	for n: String in items:
		parts.append("%s x%d" % [n, int(items[n])])
	return "Items used: %s" % ", ".join(parts)

## Party index of the Spirling that dealt the most (knock-outs break a tie), -1 when nobody hit.
func best() -> int:
	var top: int = -1
	for k: int in rows:
		var r: Dictionary = rows[k]
		if int(r.damage) <= 0:
			continue
		if top < 0 or int(r.damage) > int(rows[top].damage) \
				or (int(r.damage) == int(rows[top].damage) and int(r.kos) > int(rows[top].kos)):
			top = k
	return top

## "Best of the battle: Zippit, 120 damage", or "" when nobody hit.
func best_line() -> String:
	var k: int = best()
	return "" if k < 0 else "Best of the battle: %s, %d damage" % [str(rows[k].name), int(rows[k].damage)]

## All report lines for the log: a header, one line per Spirling, then the fields.
func lines() -> Array[String]:
	var out: Array[String] = ["Battle report"]
	for k: int in rows:
		out.append(spirling_line(k))
	var f: String = field_line()
	if not f.is_empty():
		out.append(f)
	var it: String = item_line()
	if not it.is_empty():
		out.append(it)
	return out if out.size() > 1 else []
