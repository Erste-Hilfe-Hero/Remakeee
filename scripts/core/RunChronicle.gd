class_name RunChronicle
extends RefCounted
## Run chronicle (plan area 8, items 3401-3403 and 3411): every run that reaches the end of
## Act I (GameState.ACT1_END_FLAG) is written once into an account-wide file next to the save
## slots, with starter, difficulty, play time, the Iron Oath and the vows kept. The file is not
## part of a slot, so deleting a slot keeps its old runs (3402). A run with each of the three
## starters earns the badge "Three Ways" (3403). The Oath and kept vows have their own glyph (3411).
## Entry: {"name", "starter", "difficulty", "play_time", "oath", "vows": [ids], "date"}.

const DEFAULT_PATH: String = "user://chronicle.json"
## At most this many runs are kept, oldest dropped first.
const MAX_RUNS: int = 50
## A small knot (PixelFont U+E005) marks a run with kept vows; the chain is SaveManager.OATH_GLYPH.
const VOW_GLYPH: String = ""

## Tests point this at their own file.
static var path: String = DEFAULT_PATH

static func runs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary and (d as Dictionary).get("runs") is Array:
		for r: Variant in (d as Dictionary).runs:
			if r is Dictionary:
				out.append(r)
	return out

static func _write(list: Array[Dictionary]) -> void:
	while list.size() > MAX_RUNS:
		list.pop_front()
	SaveManager.write_atomic(path, JSON.stringify({"runs": list}, "\t"))

## The entry for the run now being played.
static func entry() -> Dictionary:
	var kept: Array[String] = []
	for v: Dictionary in Vows.list():
		if Vows.status(str(v.id)) == "kept":
			kept.append(str(v.id))
	return {"name": GameState.tamer_name, "starter": GameState.starter, "difficulty": ChallengeRules.ranked_difficulty(),
		"challenges": ChallengeRules.active_ids(),
		"play_time": int(GameState.play_time), "oath": GameState.iron_oath, "vows": kept, "lowered": GameState.difficulty_lowered(),
		"date": Time.get_date_string_from_unix_time(Online.unix_now())}

## Books the run once it reaches the end of Act I. Returns the lines to show.
static func note() -> Array[String]:
	if not GameState.has_flag(GameState.ACT1_END_FLAG) or bool(GameState.records.get("chronicled", false)):
		return []
	GameState.records["chronicled"] = true
	var list: Array[Dictionary] = runs()
	list.append(entry())
	_write(list)
	var e: Dictionary = list[-1]
	var rules: String = ChallengeRules.names()
	# The victory note names the difficulty and the rules kept (KAMPF plan item 505).
	return [Loc.t("This journey is now in the run chronicle: %s.") % (difficulty_name(int(e.difficulty))
		+ (", " + rules if not rules.is_empty() else ""))]

## Starters with a finished run, over every slot.
static func starters_done() -> int:
	var seen: Dictionary = {}
	for r: Dictionary in runs():
		var sp: String = str(r.get("starter", ""))
		if sp in Database.STARTERS:
			seen[sp] = true
	return seen.size()

static func difficulty_name(d: int) -> String:
	return Loc.t(MenuHost.DIFFICULTY_TEXT[d]) if d >= 0 and d < MenuHost.DIFFICULTY_TEXT.size() else "?"

## One line per run, newest first: glyphs, name, starter, difficulty, time.
static func line(r: Dictionary) -> String:
	var mark: String = ""
	if bool(r.get("oath", false)):
		mark += SaveManager.OATH_GLYPH
	if r.get("vows") is Array and not (r.vows as Array).is_empty():
		mark += VOW_GLYPH
	var sd: SpirlingData = Database.species(str(r.get("starter", "")))
	var secs: int = int(r.get("play_time", 0))
	var text: String = Loc.t("%s with %s, %s, %d:%02d") % [str(r.get("name", "")),
		sd.species_name if sd != null else "?", difficulty_name(int(r.get("difficulty", 0))) + (" " + Loc.t("(lowered)") if bool(r.get("lowered", false)) else ""), secs / 3600, (secs / 60) % 60]
	if r.get("vows") is Array and not (r.vows as Array).is_empty():
		text += "  " + Loc.t("Vows kept: %d") % (r.vows as Array).size()
	if r.get("challenges") is Array and not (r.challenges as Array).is_empty():
		text += "  " + Loc.t("Challenge rules: %d") % (r.challenges as Array).size()
	return (mark + " " if not mark.is_empty() else "") + text + "  " + str(r.get("date", ""))

static func lines() -> Array[String]:
	var out: Array[String] = []
	var list: Array[Dictionary] = runs()
	list.reverse()
	for r: Dictionary in list:
		out.append(line(r))
	if out.is_empty():
		out.append(Loc.t("No journey has reached the end of Act I yet."))
	out.append(Loc.t("%s Iron Oath  %s vows kept. Starters done: %d of %d.") % [SaveManager.OATH_GLYPH, VOW_GLYPH,
		starters_done(), Database.STARTERS.size()])
	return out
