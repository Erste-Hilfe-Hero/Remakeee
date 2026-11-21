class_name DigSite
extends RefCounted
## The Dig site (era function "dig_site", opens in Era IV): once a day, under Paleshore. A field
## of width x height cells hides "finds" buried items and "rocks"; the Wayfarer has "picks"
## swings. Digging an empty cell costs 1, a rock costs rock_cost and gives nothing, a find costs
## 1 and gives its item. The field is the same for everyone on a day (hash of the day).
## Tuning in data/era_activities.json "dig".

const FEATURE: String = "dig_site"
const RECORD: String = "dig_day"

static func data() -> Dictionary:
	return EraActivities.section("dig")

static func width() -> int:
	return int(data().get("width", 6))

static func height() -> int:
	return int(data().get("height", 4))

## The field of [param day]: {"finds": {cell index: item id}, "rocks": [cell index, ...]}.
static func field(day: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dig|" + day)
	var cells: Array[int] = []
	for i: int in width() * height():
		cells.append(i)
	for i: int in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var loot: Array = data().get("loot", ["remedy"])
	var finds: Dictionary = {}
	var n_finds: int = mini(int(data().get("finds", 4)), cells.size())
	for k: int in n_finds:
		finds[cells[k]] = str(loot[rng.randi_range(0, loot.size() - 1)])
	var rocks: Array[int] = []
	for k: int in range(n_finds, mini(n_finds + int(data().get("rocks", 4)), cells.size())):
		rocks.append(cells[k])
	return {"finds": finds, "rocks": rocks}

## A fresh dig: {"day", "picks", "dug": []}.
static func start(day: String) -> Dictionary:
	return {"day": day, "picks": int(data().get("picks", 9)), "dug": []}

## True while today's dig is still open in [param records].
static func open_today(records: Dictionary, day: String) -> bool:
	return str(records.get(RECORD, "")) != day

static func mark_done(records: Dictionary, day: String) -> void:
	records[RECORD] = day

## Swings at [param cell] in [param dig] (changed in place). Returns {"ok", "item", "rock"}.
static func swing(dig: Dictionary, cell: int) -> Dictionary:
	var dug: Array = dig.dug
	if int(dig.picks) <= 0 or cell < 0 or cell >= width() * height() or dug.has(cell):
		return {"ok": false, "item": "", "rock": false}
	var f: Dictionary = field(str(dig.day))
	dug.append(cell)
	if (f.rocks as Array).has(cell):
		dig.picks = maxi(0, int(dig.picks) - int(data().get("rock_cost", 2)))
		return {"ok": true, "item": "", "rock": true}
	dig.picks = int(dig.picks) - 1
	return {"ok": true, "item": str((f.finds as Dictionary).get(cell, "")), "rock": false}

static func cell_name(cell: int) -> String:
	return "%s%d" % [char(65 + cell % width()), cell / width() + 1]

## The field as text rows: "#" untouched, "." empty, "o" rock, "*" find.
static func grid_text(dig: Dictionary) -> String:
	var f: Dictionary = field(str(dig.day))
	var rows: PackedStringArray = ["  " + "".join(range(width()).map(func(x: int) -> String: return char(65 + x)))]
	for y: int in height():
		var line: String = str(y + 1) + " "
		for x: int in width():
			var c: int = y * width() + x
			if not (dig.dug as Array).has(c):
				line += "#"
			elif (f.rocks as Array).has(c):
				line += "o"
			elif (f.finds as Dictionary).has(c):
				line += "*"
			else:
				line += "."
		rows.append(line)
	return "\n".join(rows)

## Cells still untouched, for the pick list.
static func open_cells(dig: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for c: int in width() * height():
		if not (dig.dug as Array).has(c):
			out.append(c)
	return out
