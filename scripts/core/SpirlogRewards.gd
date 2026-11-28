class_name SpirlogRewards
extends RefCounted
## Spirlog book rewards (Chimora 1.3.2, Ali): the book shows how much of it is done in percent
## (seen, bonded, Gleam) and pays a reward at 25, 50 and 100 % of every kind bonded and at 10,
## 25 and 50 Gleam kinds bonded, each taken once in the book (data/spirlog_rewards.json).
## Items and the title come at once, also offline, and are kept in the save
## (GameState.records["spirlog_rewards"]). The Riftglass of a step waits in the save until the
## server pays it, once per account (public.spirlog_reward_claim checks the uploaded save).
## Children's accounts get the items and the title, never Riftglass.

const PATH: String = "res://data/spirlog_rewards.json"
const RECORD: String = "spirlog_rewards"
## Server answers that end a waiting Riftglass step for good (paid here, paid on another slot,
## a child's account, a step the server does not know).
const DONE_ERRORS: Array[String] = ["already", "age", "unknown_reward"]

static var _steps: Array[Dictionary] = []
static var _syncing: bool = false

## Every step in book order: {"id", "kind" ("bonded" or "gleam"), "pct" or "n", "riftglass",
## "item", "count", "title"?}.
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

## How far [param s] is: {"have", "need"} in kinds.
static func progress(s: Dictionary, c: Dictionary) -> Dictionary:
	if str(s.get("kind", "")) == "gleam":
		return {"have": int(c.gleam), "need": int(s.get("n", 0))}
	# Rounded up, like the server's have * 100 >= pct * total.
	var t: int = int(c.total)
	return {"have": int(c.bonded), "need": ceili(float(int(s.get("pct", 100)) * t) / 100.0)}

static func reached(s: Dictionary, c: Dictionary) -> bool:
	var p: Dictionary = progress(s, c)
	return int(c.total) > 0 and int(p.have) >= int(p.need)

## The saved state, repaired: {"claimed": [ids], "glass": [ids whose Riftglass waits]}.
static func state(records: Dictionary) -> Dictionary:
	var raw: Variant = records.get(RECORD)
	var out: Dictionary = {"claimed": [], "glass": []}
	if raw is Dictionary:
		for k: String in ["claimed", "glass"]:
			for id: Variant in ((raw as Dictionary).get(k, []) if (raw as Dictionary).get(k) is Array else []):
				if not step(str(id)).is_empty() and not (out[k] as Array).has(str(id)):
					(out[k] as Array).append(str(id))
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

## Takes step [param id] once: items and title now, the Riftglass marked for the server
## ([param glass] false for a child's account). Returns the lines to show, empty when it
## cannot be taken (not reached or taken already).
static func claim(id: String, spirlog: Dictionary, records: Dictionary, glass: bool = true) -> Array[String]:
	var s: Dictionary = step(id)
	if s.is_empty() or is_claimed(records, id) or not reached(s, counts(spirlog)):
		return []
	var st: Dictionary = state(records)
	(st.claimed as Array).append(id)
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
	if glass and int(s.get("riftglass", 0)) > 0:
		(st.glass as Array).append(id)
		lines.append(Loc.t("+%d Riftglass, it comes once you are online.") % int(s.riftglass)
			if not Online.is_online() else Loc.t("+%d Riftglass") % int(s.riftglass))
	return lines

## Riftglass steps still waiting for the server.
static func waiting(records: Dictionary) -> Array:
	return (state(records).glass as Array).duplicate()

## The server's answer [param r] for waiting step [param id]: true when the step is done for
## good (paid, or it never will be), false to try again later (no save on the server yet, the
## save there is older, no connection).
static func take_answer(records: Dictionary, id: String, r: Dictionary) -> bool:
	var d: Dictionary = r.data if r.get("ok", false) and r.get("data") is Dictionary else {}
	var done: bool = bool(d.get("ok", false)) or str(d.get("error", "")) in DONE_ERRORS
	if done:
		(state(records).glass as Array).erase(id)
	return done

## Asks the server for every waiting Riftglass step. Returns the Riftglass added. Safe to call
## any time; does nothing offline or with nothing waiting.
static func sync(slot: int) -> int:
	if _syncing:
		return 0
	_syncing = true
	var added: int = 0
	for id: Variant in waiting(GameState.records):
		if not Online.is_online():
			break
		var r: Dictionary = await Online.call_fn("spirlog_reward_claim", {"p_slot": slot, "p_id": str(id)})
		if not r.ok:
			break
		take_answer(GameState.records, str(id), r)
		if r.data is Dictionary and bool(r.data.get("ok", false)):
			added += int(r.data.get("added", 0))
			if r.data.has("balance") and Billing.state.has("balance"):
				Billing.state["balance"] = int(r.data.balance)
	_syncing = false
	return added

# --- Texts -----------------------------------------------------------------------------------

static func item_name(id: String) -> String:
	return Loc.t(str(Database.item(id).get("name", id)))

## "25% bonded" or "10 Gleam bonded".
static func step_name(s: Dictionary) -> String:
	if str(s.get("kind", "")) == "gleam":
		return Loc.t("%d Gleam bonded") % int(s.get("n", 0))
	return Loc.t("%d%% bonded") % int(s.get("pct", 0))

## What a step gives: "Max Tonic x3, 100 Riftglass" (no Riftglass named for children).
static func reward_text(s: Dictionary, glass: bool = true) -> String:
	var parts: PackedStringArray = []
	if not str(s.get("item", "")).is_empty():
		parts.append("%s x%d" % [item_name(str(s.item)), int(s.get("count", 1))])
	if glass and int(s.get("riftglass", 0)) > 0:
		parts.append(Loc.t("%d Riftglass") % int(s.riftglass))
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
