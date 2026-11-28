class_name SpirlogRewards
extends RefCounted
## Spirlog book rewards (Chimora 1.3.2, Ali): the book shows how much of it is done in percent
## (seen, bonded, Gleam) and pays a reward at 25, 50 and 100 % of every kind bonded and at 10,
## 25 and 50 Gleam kinds bonded, each taken once in the book (data/spirlog_rewards.json).
## Items and the cosmetic title only, from the save alone, so it works offline and goes online
## with the save. No Riftglass: the server cannot check bonds it never saw (security review 1.3.2).

const PATH: String = "res://data/spirlog_rewards.json"
const RECORD: String = "spirlog_rewards"

static var _steps: Array[Dictionary] = []

## Every step in book order: {"id", "kind" ("bonded" or "gleam"), "pct" or "n", "item",
## "count", "title"?}.
static func steps() -> Array[Dictionary]:
	if _steps.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		for s: Variant in (raw.get("steps", []) if raw is Dictionary else []):
			if s is Dictionary:
				_steps.append(s)
	return _steps

static func step(id: String) -> Dictionary:
	for s: Dictionary in steps():
		if str(s.id) == id:
			return s
	return {}

## Every kind in the game: the book's 100 %.
static func total() -> int:
	return Database.spirlings.size()

## {"seen", "bonded", "gleam", "total"} over every kind in the game.
static func counts(spirlog: Dictionary) -> Dictionary:
	var out: Dictionary = {"seen": 0, "bonded": 0, "gleam": 0, "total": total()}
	for sd: SpirlingData in Database.spirlings.values():
		var e: Dictionary = SpirlogBook.entry(spirlog, sd.species_name)
		out.seen = int(out.seen) + (1 if bool(e.seen) else 0)
		out.bonded = int(out.bonded) + (1 if bool(e.bonded) else 0)
		out.gleam = int(out.gleam) + (1 if bool(e.gleam_bonded) else 0)
	return out

## How far [param s] is: {"have", "need"} in kinds (a percent step rounded up).
static func progress(s: Dictionary, c: Dictionary) -> Dictionary:
	if str(s.get("kind", "")) == "gleam":
		return {"have": int(c.gleam), "need": int(s.get("n", 0))}
	return {"have": int(c.bonded), "need": ceili(float(int(s.get("pct", 100)) * int(c.total)) / 100.0)}

static func reached(s: Dictionary, c: Dictionary) -> bool:
	var p: Dictionary = progress(s, c)
	return int(c.total) > 0 and int(p.have) >= int(p.need)

## The saved state, repaired: {"claimed": [ids]}.
static func state(records: Dictionary) -> Dictionary:
	var raw: Variant = records.get(RECORD)
	var out: Dictionary = {"claimed": []}
	if raw is Dictionary and (raw as Dictionary).get("claimed") is Array:
		for id: Variant in (raw as Dictionary).claimed:
			if not step(str(id)).is_empty() and not (out.claimed as Array).has(str(id)):
				(out.claimed as Array).append(str(id))
	records[RECORD] = out
	return out

static func is_claimed(records: Dictionary, id: String) -> bool:
	return (state(records).claimed as Array).has(id)

## Steps reached and not yet taken.
static func ready(spirlog: Dictionary, records: Dictionary) -> Array[Dictionary]:
	var c: Dictionary = counts(spirlog)
	var out: Array[Dictionary] = []
	for s: Dictionary in steps():
		if reached(s, c) and not is_claimed(records, str(s.id)):
			out.append(s)
	return out

## Takes step [param id] once: its items and title. Returns the lines to show, empty when it
## cannot be taken (not reached or taken already).
static func claim(id: String, spirlog: Dictionary, records: Dictionary) -> Array[String]:
	var s: Dictionary = step(id)
	if s.is_empty() or is_claimed(records, id) or not reached(s, counts(spirlog)):
		return []
	(state(records).claimed as Array).append(id)
	var lines: Array[String] = [Loc.t("Spirlog reward: %s!") % step_name(s)]
	if not str(s.get("item", "")).is_empty() and int(s.get("count", 0)) > 0:
		GameState.add_item(str(s.item), int(s.count))
		lines.append(Loc.t("You received %s x%d.") % [item_name(str(s.item)), int(s.count)])
	if s.has("title"):
		var t: Array = records.get("titles", []) if records.get("titles") is Array else []
		if not t.has(str(s.title)):
			t.append(str(s.title))
		records["titles"] = t
		lines.append(Loc.t("New title: %s") % Loc.t(str(s.title)))
	return lines

# --- Texts -----------------------------------------------------------------------------------

static func item_name(id: String) -> String:
	return Loc.t(str(Database.item(id).get("name", id)))

## "25% bonded" or "10 Gleam bonded".
static func step_name(s: Dictionary) -> String:
	if str(s.get("kind", "")) == "gleam":
		return Loc.t("%d Gleam bonded") % int(s.get("n", 0))
	return Loc.t("%d%% bonded") % int(s.get("pct", 0))

## What a step gives: "Spring Flask x3" and the title, if any.
static func reward_text(s: Dictionary) -> String:
	var parts: PackedStringArray = []
	if not str(s.get("item", "")).is_empty():
		parts.append("%s x%d" % [item_name(str(s.item)), int(s.get("count", 1))])
	if s.has("title"):
		parts.append(Loc.t("Title: %s") % Loc.t(str(s.title)))
	return ", ".join(parts)

## The book's share lines: seen, bonded and Gleam in percent of every kind.
static func percent_lines(spirlog: Dictionary) -> Array[String]:
	var c: Dictionary = counts(spirlog)
	var t: int = int(c.total)
	return [
		Loc.t("Seen: %d%% (%d/%d)") % [SpirlogBook.percent(int(c.seen), t), int(c.seen), t],
		Loc.t("Bonded: %d%% (%d/%d)") % [SpirlogBook.percent(int(c.bonded), t), int(c.bonded), t],
		GleamRules.STAR + " " + Loc.t("Gleam: %d%% (%d/%d)") % [SpirlogBook.percent(int(c.gleam), t), int(c.gleam), t],
	]

## The row in the Spirlog list: "Book rewards: 12% bonded, Gleam 1%" plus how many are ready.
static func book_row_text(spirlog: Dictionary, records: Dictionary) -> String:
	var c: Dictionary = counts(spirlog)
	var t: int = int(c.total)
	var line: String = Loc.t("Book rewards: %d%% bonded, Gleam %d%%") % [SpirlogBook.percent(int(c.bonded), t), SpirlogBook.percent(int(c.gleam), t)]
	var n: int = ready(spirlog, records).size()
	return line + ("  " + Loc.t("(%d ready)") % n if n > 0 else "")
