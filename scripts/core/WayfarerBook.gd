class_name WayfarerBook
extends RefCounted
## The Wayfarer book (KAMPF_PLAN_1000 items 529, 530, 542): every Wayfarer and Warden battle is
## booked per Wayfarer in GameState.records["wayfarer_book"], so the lexicon can show a local
## ranking (most battled, toughest) and the lantern post can list the Wayfarers whose rematch is
## open today. Wild hordes and echo duels are not booked.
## Entry: {"name", "map", "def": {the rematch keys of the Wayfarer}, "wins", "losses", "best_turns"}.

const KEY: String = "wayfarer_book"
## The Wayfarer keys can_rematch needs; nothing else of the map data is copied into the save.
const DEF_KEYS: Array[String] = ["id", "beaten_flag", "rematch_after", "leaves", "no_rematch", "warden"]
## Rows in each ranking.
const TOP: int = 5

static func _book() -> Dictionary:
	return GameState.as_dict(GameState.records.get(KEY, {}))

## Books one battle with [param def] on [param map_id]. [param turns] is the battle's length.
static func note(def: Dictionary, map_id: String, won: bool, turns: int) -> void:
	if not TrainerData.is_trainer(def) or TrainerData.is_wild_horde(def):
		return
	var key: String = TrainerData.beaten_flag(def, map_id)
	var book: Dictionary = _book().duplicate(true)
	var e: Dictionary = GameState.as_dict(book.get(key, {})).duplicate()
	var keep: Dictionary = {"team": []}
	for k: String in DEF_KEYS:
		if def.has(k):
			keep[k] = def[k]
	e["def"] = keep
	e["name"] = str(def.get("trainer", def.get("id", "Wayfarer")))
	e["map"] = map_id
	if won:
		e["wins"] = int(e.get("wins", 0)) + 1
		if turns > 0 and (int(e.get("best_turns", 0)) <= 0 or turns < int(e.best_turns)):
			e["best_turns"] = turns
	else:
		e["losses"] = int(e.get("losses", 0)) + 1
	book[key] = e
	GameState.records[KEY] = book

static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var book: Dictionary = _book()
	for k: Variant in book:
		if book[k] is Dictionary:
			out.append(book[k])
	return out

static func _line(e: Dictionary) -> String:
	var line: String = Loc.t("%s: %d won, %d lost") % [str(e.get("name", "?")), int(e.get("wins", 0)), int(e.get("losses", 0))]
	if int(e.get("best_turns", 0)) > 0:
		line += ", " + Loc.t("best in %d turns") % int(e.best_turns)
	return line

## Most battled first (wins plus losses), then by name.
static func most_battled() -> Array[Dictionary]:
	var l: Array[Dictionary] = entries()
	l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var na: int = int(a.get("wins", 0)) + int(a.get("losses", 0))
		var nb: int = int(b.get("wins", 0)) + int(b.get("losses", 0))
		return na > nb if na != nb else str(a.get("name", "")) < str(b.get("name", "")))
	return l.slice(0, TOP)

## The Wayfarers you lost to most, then by name; only those with a loss.
static func toughest() -> Array[Dictionary]:
	var l: Array[Dictionary] = entries().filter(func(e: Dictionary) -> bool: return int(e.get("losses", 0)) > 0)
	l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.losses) > int(b.losses) if int(a.losses) != int(b.losses) else str(a.get("name", "")) < str(b.get("name", "")))
	return l.slice(0, TOP)

## Names of the Wayfarers whose rematch is open on [param today] (the lantern post, item 529).
static func invitations(today: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in entries():
		var def: Dictionary = GameState.as_dict(e.get("def", {}))
		if TrainerData.can_rematch(def, str(e.get("map", "")), GameState.flags, GameState.records, today):
			out.append(str(e.get("name", "?")))
	out.sort()
	return out

## The page in the lexicon: both rankings and the lantern post.
static func page(today: String) -> String:
	var lines: Array[String] = []
	if entries().is_empty():
		return Loc.t("No Wayfarer battles yet.")
	lines.append(Loc.t("Most battled:"))
	for e: Dictionary in most_battled():
		lines.append("  " + _line(e))
	var tough: Array[Dictionary] = toughest()
	if not tough.is_empty():
		lines.append(Loc.t("Toughest:"))
		for e: Dictionary in tough:
			lines.append("  " + _line(e))
	lines.append(lantern_line(today))
	return "\n".join(lines)

## "Lantern post: Bram and Isa would battle you again today."
static func lantern_line(today: String) -> String:
	var inv: Array[String] = invitations(today)
	if inv.is_empty():
		return Loc.t("Lantern post: no rematch invitations today.")
	return Loc.t("Lantern post: %s would battle you again today.") % ", ".join(inv)
