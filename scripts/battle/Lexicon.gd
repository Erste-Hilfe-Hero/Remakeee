class_name Lexicon
extends RefCounted
## The lexicon (plan area 2, items 680, 759): short entries the player collects. The ids live in
## GameState.records["lexicon"]; the texts in data/lexicon.json. Bonus goals grant entries
## (BattleGoals "lore"), and a Wayfarer with a "lexicon" key writes one down after its first win.

const PATH: String = "res://data/lexicon.json"

static var _cache: Dictionary = {}

static func all() -> Dictionary:
	if _cache.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if raw is Dictionary:
			for k: String in raw:
				if not k.begins_with("_") and raw[k] is Dictionary:
					_cache[k] = raw[k]
	return _cache

static func has_entry(id: String) -> bool:
	return all().has(id)

static func title(id: String) -> String:
	return str(all().get(id, {}).get("title", id))

static func text(id: String) -> String:
	return str(all().get(id, {}).get("text", ""))

## The collected entry ids in [param records], in the order they were found.
static func collected(records: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in records.get("lexicon", []):
		if has_entry(str(v)):
			out.append(str(v))
	return out

## Writes [param id] into [param records]. Returns false if it was already there or is unknown.
static func add(records: Dictionary, id: String) -> bool:
	if not has_entry(id):
		return false
	var l: Array = (records.get("lexicon", []) as Array).duplicate()
	if l.has(id):
		return false
	l.append(id)
	records["lexicon"] = l
	# A lore page that names matchups teaches them to the Wayfarer (item 90).
	if is_same(records, GameState.records):
		teach_matchups(GameState.known_matchups, id)
	return true

# --- Matchups from lore pages (KAMPF_PLAN_1000 item 90) --------------------------------------------
# lexicon.json "matchups": [element, species] pairs. Writing the page down teaches them as if a hit
# had shown them; the factor always comes from the type chart, so a page can never lie.

## The matchups page [param id] teaches: {"element": int, "species": String, "mult": float}.
static func lessons(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Variant in (all().get(id, {}) as Dictionary).get("matchups", []):
		if not row is Array or (row as Array).size() < 2 or not Elements.E.has(str(row[0])):
			continue
		var sd: SpirlingData = Database.species(str(row[1]))
		if sd == null:
			continue
		var e: int = Elements.E[str(row[0])]
		out.append({"element": e, "species": sd.species_name, "mult": Elements.multiplier(e, sd.elements)})
	return out

## Writes the matchups of page [param id] into [param known] (keys as GameState.known_matchups).
## Returns how many of them were new.
static func teach_matchups(known: Dictionary, id: String) -> int:
	var fresh: int = 0
	for l: Dictionary in lessons(id):
		var key: String = "%d:%s" % [int(l.element), str(l.species)]
		if not known.has(key):
			fresh += 1
		known[key] = float(l.mult)
	return fresh

## Lines under the page text: the matchups it teaches ("Tide into Kindlop x2"); empty without any.
static func lesson_lines(id: String) -> Array[String]:
	var out: Array[String] = []
	for l: Dictionary in lessons(id):
		var tag: String = CommandMenu.matchup_tag(float(l.mult))
		out.append(Loc.t("%s into %s %s") % [Loc.t(Elements.element_name(int(l.element))), Loc.t(str(l.species)), tag if not tag.is_empty() else "x1"])
	if not out.is_empty():
		out.push_front(Loc.t("Matchups this page teaches:"))
	return out

# --- Foe values (KAMPF_PLAN_1000 item 215) --------------------------------------------------------
# After every battle the foes' values go into records["foe_values"]: per species the highest Ring
# seen with its HP, ATK, DEF, FOC and SPD. The lexicon shows them on the "Foe values" page.

const FOE_VALUES: String = "foe_values"

## Notes the values of [param foes] in [param records]. A species keeps its highest-Ring sighting.
static func note_foes(records: Dictionary, foes: Array) -> void:
	var book: Dictionary = (records.get(FOE_VALUES, {}) as Dictionary).duplicate()
	for f: Variant in foes:
		var s: Spirling = f as Spirling
		if s == null or s.data == null:
			continue
		var sp: String = s.data.species_name
		if book.has(sp) and int((book[sp] as Dictionary).get("level", 0)) > s.level:
			continue
		book[sp] = {"level": s.level, "hp": s.max_hp(), "atk": s.atk(), "def": s.def(), "foc": s.foc(), "spd": s.spd()}
	records[FOE_VALUES] = book

## One line per noted species, sorted by name; a hint when nothing is noted yet.
static func foe_lines(records: Dictionary) -> Array[String]:
	var book: Dictionary = records.get(FOE_VALUES, {})
	var out: Array[String] = []
	var names: Array = book.keys()
	names.sort()
	for sp: Variant in names:
		var v: Dictionary = book[sp]
		out.append(Loc.t("%s Ring %d: VIG %d  MGT %d  GRD %d  FOC %d  PCE %d") % [str(sp), int(v.get("level", 0)),
			int(v.get("hp", 0)), int(v.get("atk", 0)), int(v.get("def", 0)), int(v.get("foc", 0)), int(v.get("spd", 0))])
	if out.is_empty():
		out.append(Loc.t("No foe values yet. Every battle writes the foes down here."))
	return out
