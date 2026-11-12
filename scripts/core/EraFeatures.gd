class_name EraFeatures
extends RefCounted
## Which game functions each era opens (data/era_functions.json, docs/ERA_FUNCTIONS.md). The world
## gets more modern era by era, like the handheld generations 1 to 5: functions of kind "base" are
## there from Era I on, "new" and "upgrade" functions open with their era. Nothing a save already
## has is ever taken away: unlocked_era only rises (EraManager.unlock_era).

const PATH: String = "res://data/era_functions.json"
const KINDS: Array[String] = ["base", "new", "upgrade"]
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V"]

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

static func features() -> Array:
	return data().get("features", [])

## The entry of [param id], or {}.
static func feature(id: String) -> Dictionary:
	for f: Dictionary in features():
		if str(f.id) == id:
			return f
	return {}

## Era that opens [param id] (0 for an unknown id).
static func era_of(id: String) -> int:
	return int(feature(id).get("era", 0))

## True once [param id] is open in [param era] (default: the save's unlocked era). Unknown ids
## are never open, so a typo can't switch a function on.
static func is_unlocked(id: String, era: int = -1) -> bool:
	var need: int = era_of(id)
	if need <= 0:
		return false
	if era < 0:
		era = EraManager.unlocked_era
	return era >= need

## New and upgraded functions that open with [param era], in data order (English, for Loc.t).
static func new_in(era: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in features():
		if int(f.era) == era and str(f.kind) != "base":
			out.append(f)
	return out

## Every function open in [param era], oldest era first.
static func open_in(era: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: int in range(1, era + 1):
		for f: Dictionary in features():
			if int(f.era) == e:
				out.append(f)
	return out

## One translated line per function: "Name: text".
static func line(f: Dictionary) -> String:
	return "%s: %s" % [Loc.t(str(f.name)), Loc.t(str(f.text))]

## Translated lines for the era change, one per new or upgraded function:
## "New in Era III: Weather in battle. Outdoors, ...".
static func new_in_lines(era: int) -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in new_in(era):
		out.append(Loc.t("New in Era %s: %s. %s") % [ROMAN[clampi(era, 0, 5)], Loc.t(str(f.name)), Loc.t(str(f.text))])
	return out

## Records page for [param era]: what opened in that era (base functions under Era I).
static func page_lines(era: int) -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in features():
		if int(f.era) != era:
			continue
		var mark: String = Loc.t("upgraded") if str(f.kind) == "upgrade" else ""
		out.append(line(f) + ("" if mark.is_empty() else " (%s)" % mark))
	return out

## Menu titles "Era I" .. up to [param era].
static func era_titles(era: int) -> Array[String]:
	var out: Array[String] = []
	for e: int in range(1, clampi(era, 1, 5) + 1):
		out.append(Loc.t("Era %s") % ROMAN[e])
	return out

## Data problems, for the data check (empty when fine).
static func validate() -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for f: Dictionary in features():
		var id: String = str(f.get("id", ""))
		if id.is_empty() or seen.has(id):
			out.append("era function id missing or twice: %s" % id)
		seen[id] = true
		var e: int = int(f.get("era", 0))
		if e < 1 or e > 5:
			out.append("%s: era %d out of 1..5" % [id, e])
		if not str(f.get("kind", "")) in KINDS:
			out.append("%s: unknown kind %s" % [id, f.get("kind", "")])
		if str(f.get("kind", "")) == "base" and e != 1:
			out.append("%s: base functions open in Era I" % id)
		if str(f.get("kind", "")) != "base" and e == 1:
			out.append("%s: Era I functions are base" % id)
		var step: int = int(f.get("step", 0))
		if step < 1 or step > 5:
			out.append("%s: step %d out of 1..5" % [id, step])
		if str(f.get("name", "")).is_empty() or str(f.get("text", "")).is_empty():
			out.append("%s: name or text missing" % id)
	return out
