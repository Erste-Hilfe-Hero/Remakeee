class_name PuzzleSpots
extends RefCounted
## Riddles and puzzles spread over the seven regions (1.3.2, "voll viele versteckte Sachen,
## auch Raetsel"): stone tablets and riddlers placed by data/puzzle_spots.json, never by the map
## files. One spot = one puzzle:
##   pick    a riddle with answers to tap
##   type    a riddle answered by typing (the player's language, English and common spellings);
##           after TYPE_CHOICES_AFTER wrong tries the answers can be picked instead
##   order   lanterns, vats or wheels used in the order a clue describes
##   listen  bells or chimes that play a tune to repeat
##   lights  lamp grid: a tap flips a lamp and its neighbours, all lit wins
##   slide   3x3 sliding tiles, numbers 1 to 8
##   push    a small boulder board on the rules of PuzzleRoom (solved by PuzzleSolver)
##   steps   follow the right tracks through a grid, decoy tracks and bare ground lose them
## Chains: spots with "chain" give a clue line when solved; the spot with "needs" opens once all
## of them are solved and asks what the clues describe. A solved spot sets flag "pz_<id>" and
## its reward ("reward": [{"item", "count"} | {"coins"} | {"look"} | {"meet": species, "ring",
## "map"}]) is granted exactly once. A "look" is a lantern flame in data/lantern_colors.json
## (unlock flag "pz_<id>"); a "meet" lets a rare Spirling turn up in that map's wild encounters.
## Wrong tries live in GameState.records["puzzle_tries"], so hints survive a restart.

const PATH: String = "res://data/puzzle_spots.json"
const FLAG_PREFIX: String = "pz_"
const TRIES_RECORD: String = "puzzle_tries"
## Wrong tries before the first and the second hint.
const HINT_1_AFTER: int = 2
const HINT_2_AFTER: int = 4
## Wrong typed answers before the answers are offered to pick.
const TYPE_CHOICES_AFTER: int = 5
## Chance that a wild encounter on a map with an unlocked rare visitor is that visitor.
const MEET_CHANCE: float = 0.1
const KINDS: Array[String] = ["pick", "type", "order", "listen", "lights", "slide", "push", "steps"]
const REGIONS: Array[String] = ["veydal", "ashmere", "corvane", "solenne", "quillmarch", "halcyra", "vellmarch"]
## Button colours of order and listen puzzles. Names are translated via Loc.
const COLORS: Dictionary[String, Color] = {"red": Color("c8483a"), "blue": Color("3f6fc0"), "green": Color("4f9a48"),
	"gold": Color("e0b040"), "white": Color("ece6d6"), "violet": Color("8a5ac0"), "black": Color("2c2630"),
	"yellow": Color("e8d850"), "grey": Color("8c8a86")}
const COLOR_NAMES: Dictionary[String, String] = {"red": "Red", "blue": "Blue", "green": "Green", "gold": "Gold",
	"white": "White", "violet": "Violet", "black": "Black", "yellow": "Yellow", "grey": "Grey"}
## Notes of listen buttons (pitch per button index).
const PITCHES: Array[float] = [0.8, 1.0, 1.2, 1.5, 1.8]
const SLIDE_DIRS: Dictionary[String, Vector2i] = {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

static var _spots: Array[Dictionary] = []

static func all() -> Array[Dictionary]:
	if _spots.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if d is Dictionary and (d as Dictionary).get("spots") is Array:
			for s: Variant in d.spots:
				if s is Dictionary:
					_spots.append(s)
	return _spots

static func by_id(id: String) -> Dictionary:
	for s: Dictionary in all():
		if str(s.id) == id:
			return s
	return {}

static func on_map(map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in all():
		if str(s.map) == map_id:
			out.append(s)
	return out

static func cell_of(s: Dictionary) -> Vector2i:
	return Vector2i(int(s.x), int(s.y))

## The spot standing on [param cell] of [param map_id], or {}.
static func at(map_id: String, cell: Vector2i) -> Dictionary:
	for s: Dictionary in on_map(map_id):
		if cell_of(s) == cell:
			return s
	return {}

## NPC definitions for the overworld: tablets ("at": "tablet") and riddlers ("at": "npc").
static func npc_defs(map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in on_map(map_id):
		out.append({"id": "puzzle_" + str(s.id), "x": int(s.x), "y": int(s.y), "facing": str(s.get("facing", "down")),
			"sprite": str(s.get("sprite", "elder")), "color": "8c8a86", "puzzle": str(s.id), "tablet": str(s.get("at", "tablet")) == "tablet"})
	return out

static func flag(id: String) -> String:
	return FLAG_PREFIX + id

static func solved(id: String, flags: Dictionary = GameState.flags) -> bool:
	return bool(flags.get(flag(id), false))

# --- Tries and hints -----------------------------------------------------------------------

static func tries(id: String, records: Dictionary = GameState.records) -> int:
	var t: Variant = records.get(TRIES_RECORD, {})
	return int((t as Dictionary).get(id, 0)) if t is Dictionary else 0

static func add_try(id: String, records: Dictionary = GameState.records) -> int:
	var t: Variant = records.get(TRIES_RECORD, {})
	var d: Dictionary = t if t is Dictionary else {}
	d[id] = int(d.get(id, 0)) + 1
	records[TRIES_RECORD] = d
	return int(d[id])

## English hints unlocked after [param n] wrong tries (0, 1 or 2 of them).
static func hints(s: Dictionary, n: int) -> Array[String]:
	var out: Array[String] = []
	if n >= HINT_1_AFTER and s.has("hint_1"):
		out.append(str(s.hint_1))
	if n >= HINT_2_AFTER and s.has("hint_2"):
		out.append(str(s.hint_2))
	return out

# --- Chains --------------------------------------------------------------------------------

## Spots this one needs solved first (a chain's last stone).
static func needs(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in s.get("needs", []):
		out.append(str(v))
	return out

static func needs_done(s: Dictionary, flags: Dictionary = GameState.flags) -> int:
	var n: int = 0
	for id: String in needs(s):
		if solved(id, flags):
			n += 1
	return n

static func open(s: Dictionary, flags: Dictionary = GameState.flags) -> bool:
	return needs_done(s, flags) == needs(s).size()

## English clue lines of the solved parts that [param s] needs.
static func clues_for(s: Dictionary, flags: Dictionary = GameState.flags) -> Array[String]:
	var out: Array[String] = []
	for id: String in needs(s):
		var part: Dictionary = by_id(id)
		if solved(id, flags) and part.has("clue"):
			out.append(str(part.clue))
	return out

# --- Answers -------------------------------------------------------------------------------

const ARTICLES: Array[String] = ["a", "an", "the", "der", "die", "das", "ein", "eine", "einen", "le", "la", "les",
	"un", "une", "des", "du", "el", "los", "las", "una", "il", "lo", "gli", "uno", "o", "os", "um", "uma",
	"de", "het", "een", "bir", "l"]
const FOLD: Dictionary[String, String] = {"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "ą": "a",
	"ç": "c", "ć": "c", "è": "e", "é": "e", "ê": "e", "ë": "e", "ę": "e", "ì": "i", "í": "i", "î": "i", "ï": "i",
	"ı": "i", "ñ": "n", "ń": "n", "ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ù": "u", "ú": "u", "û": "u",
	"ü": "u", "ý": "y", "ÿ": "y", "ß": "ss", "ł": "l", "ś": "s", "ş": "s", "ź": "z", "ż": "z", "ğ": "g", "ё": "е", "œ": "oe"}
## Also the invisible joiners Loc puts between Hangul syllables.
const DROP: String = " -'’.,!?¡¿\"«»・、。！？「」　~\u2060\u200b"

## Lower case, no accents, no articles, spaces or punctuation; full-width letters made
## half-width and katakana made hiragana, so "L'Écho!", "the echo" and "ＥＣＨＯ" all match.
static func normalize(text: String) -> String:
	var t: String = text.replace("\u00a0", " ").strip_edges().to_lower()
	var words: PackedStringArray = t.replace("'", " ").replace("’", " ").split(" ", false)
	if words.size() > 1 and words[0] in ARTICLES:
		words.remove_at(0)
	t = " ".join(words)
	var out: String = ""
	for i: int in t.length():
		var ch: String = t[i]
		var code: int = t.unicode_at(i)
		if DROP.contains(ch):
			continue
		if code >= 0xFF01 and code <= 0xFF5E:
			ch = String.chr(code - 0xFEE0).to_lower()
		elif code >= 0x30A1 and code <= 0x30F6:
			ch = String.chr(code - 0x60)
		out += FOLD.get(ch, ch)
	return out

## Every accepted answer of a typed riddle in [param lang] (normalized): that language's list,
## English, and the translated right choice.
static func accepted(s: Dictionary, lang: String) -> Array[String]:
	var out: Array[String] = []
	var ans: Dictionary = s.get("answers", {})
	for code: String in [lang, "en"]:
		for a: Variant in ans.get(code, []):
			var n: String = normalize(str(a))
			if not n.is_empty() and not n in out:
				out.append(n)
	var opts: Array = s.get("options", [])
	var right: int = int(s.get("correct", 0))
	if right >= 0 and right < opts.size():
		var n2: String = normalize(Loc.t(str(opts[right])))
		if not n2.is_empty() and not n2 in out:
			out.append(n2)
	return out

static func answer_ok(s: Dictionary, text: String, lang: String = Loc.language()) -> bool:
	var n: String = normalize(text)
	return not n.is_empty() and n in accepted(s, lang)

## The order the answers of [param s] are shown in: shuffled the same way every time, so the
## right one is not always on top. Entry k is the index in "options" shown at row k.
static func option_order(s: Dictionary) -> Array[int]:
	var keys: Array = []
	for i: int in (s.get("options", []) as Array).size():
		keys.append([("%s:%d" % [s.id, i]).md5_text(), i])
	keys.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	var out: Array[int] = []
	for k: Array in keys:
		out.append(int(k[1]))
	return out

static func pick_ok(s: Dictionary, index: int) -> bool:
	return index == int(s.get("correct", -1))

# --- Order and listen ----------------------------------------------------------------------

static func sequence(s: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in s.get("solution", []):
		out.append(int(v))
	return out

## Result of pressing [param button] after [param done] right presses: -1 wrong, otherwise the
## new count of right presses (the sequence is solved when it reaches its length).
static func press(s: Dictionary, done: int, button: int) -> int:
	var seq: Array[int] = sequence(s)
	if done < 0 or done >= seq.size() or seq[done] != button:
		return -1
	return done + 1

# --- Lights --------------------------------------------------------------------------------

## The lamp grid from "start" rows ("x" lit, "." dark).
static func lights_start(s: Dictionary) -> Array[bool]:
	var out: Array[bool] = []
	for row: Variant in s.get("start", []):
		for ch: String in str(row):
			out.append(ch == "x")
	return out

static func lights_size(s: Dictionary) -> int:
	return (s.get("start", []) as Array).size()

static func lights_tap(grid: Array[bool], n: int, cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c: Vector2i = cell + d
		if c.x >= 0 and c.y >= 0 and c.x < n and c.y < n:
			grid[c.y * n + c.x] = not grid[c.y * n + c.x]

static func lights_done(grid: Array[bool]) -> bool:
	return not grid.is_empty() and not grid.has(false)

## Taps that light every lamp, found by trying every set (grids up to 4x4), or null.
static func lights_solve(s: Dictionary) -> Variant:
	var n: int = lights_size(s)
	var start: Array[bool] = lights_start(s)
	if n == 0 or n > 4:
		return null
	for mask: int in 1 << (n * n):
		var g: Array[bool] = start.duplicate()
		var taps: Array = []
		for i: int in n * n:
			if mask & (1 << i):
				lights_tap(g, n, Vector2i(i % n, i / n))
				taps.append([i % n, i / n])
		if lights_done(g):
			return taps
	return null

# --- Slide ---------------------------------------------------------------------------------

## Tiles of a solved 3x3 board: 1..8 and 0 for the gap in the bottom right.
static func slide_solved() -> Array[int]:
	return [1, 2, 3, 4, 5, 6, 7, 8, 0]

## Moves the gap one cell along [param dir]; false (no change) at the edge.
static func slide_gap(tiles: Array[int], dir: Vector2i) -> bool:
	var g: int = tiles.find(0)
	var to := Vector2i(g % 3, g / 3) + dir
	if to.x < 0 or to.y < 0 or to.x > 2 or to.y > 2:
		return false
	tiles[g] = tiles[to.y * 3 + to.x]
	tiles[to.y * 3 + to.x] = 0
	return true

## Slides the tile at [param cell] into the gap if they are neighbours.
static func slide_tap(tiles: Array[int], cell: Vector2i) -> bool:
	var g: int = tiles.find(0)
	var d: Vector2i = cell - Vector2i(g % 3, g / 3)
	return absi(d.x) + absi(d.y) == 1 and slide_gap(tiles, d)

static func slide_start(s: Dictionary) -> Array[int]:
	var t: Array[int] = slide_solved()
	for mv: Variant in s.get("scramble", []):
		slide_gap(t, SLIDE_DIRS.get(str(mv), Vector2i.ZERO))
	return t

## The scramble played backwards: a sure way back to 1..8.
static func slide_solution(s: Dictionary) -> Array[String]:
	var back: Dictionary[String, String] = {"up": "down", "down": "up", "left": "right", "right": "left"}
	var out: Array[String] = []
	for mv: Variant in s.get("scramble", []):
		out.push_front(back.get(str(mv), ""))
	return out

# --- Push ----------------------------------------------------------------------------------

## The boulder board of a push spot as a MapData (rows use the map letters W f B P).
static func push_map(s: Dictionary) -> MapData:
	return MapData.from_dict("pz_" + str(s.id), {"name": "", "rows": s.get("rows", []),
		"puzzles": [{"id": "pz", "flag": flag(str(s.id))}], "warps": []})

static func push_start(s: Dictionary) -> Vector2i:
	var st: Array = s.get("start", [1, 1])
	return Vector2i(int(st[0]), int(st[1]))

static func push_done(m: MapData) -> bool:
	return PuzzleRoom.pressed(m, m.puzzles[0])

# --- Steps ---------------------------------------------------------------------------------

## What stepping on [param cell] of a steps grid means: "ok" (right tracks), "end", "decoy"
## (other tracks), "lost" (bare ground) or "edge".
static func step_kind(s: Dictionary, cell: Vector2i) -> String:
	var rows: Array = s.get("grid", [])
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= str(rows[cell.y]).length():
		return "edge"
	match str(rows[cell.y])[cell.x]:
		"o", "S":
			return "ok"
		"E":
			return "end"
		"x":
			return "decoy"
	return "lost"

static func step_find(s: Dictionary, ch: String) -> Vector2i:
	var rows: Array = s.get("grid", [])
	for y: int in rows.size():
		var x: int = str(rows[y]).find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

## Shortest move list from S to E on the right tracks, or null.
static func steps_solve(s: Dictionary) -> Variant:
	var start: Vector2i = step_find(s, "S")
	var came: Dictionary = {start: null}
	var q: Array[Vector2i] = [start]
	var h: int = 0
	while h < q.size():
		var c: Vector2i = q[h]
		h += 1
		if step_kind(s, c) == "end":
			var out: Array[String] = []
			while came[c] != null:
				out.push_front(str(came[c][1]))
				c = came[c][0]
			return out
		for name: String in SLIDE_DIRS:
			var n: Vector2i = c + SLIDE_DIRS[name]
			if not came.has(n) and step_kind(s, n) in ["ok", "end"]:
				came[n] = [c, name]
				q.append(n)
	return null

# --- Solving and rewards -------------------------------------------------------------------

static func rewards(s: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r: Variant = s.get("reward", [])
	for v: Variant in (r if r is Array else [r]):
		if v is Dictionary:
			out.append(v)
	return out

## Marks [param id] solved and grants its rewards, once. Returns the reward lines (translated),
## or [] when it was solved before.
static func solve(id: String) -> Array[String]:
	var s: Dictionary = by_id(id)
	if s.is_empty() or solved(id):
		return []
	GameState.set_flag(flag(id))
	var lines: Array[String] = []
	for r: Dictionary in rewards(s):
		if r.has("item"):
			var count: int = int(r.get("count", 1))
			GameState.add_item(str(r.item), count)
			lines.append(Loc.t("You got %s x%d!") % [Loc.t(str(Database.item(str(r.item)).get("name", r.item))), count])
		elif r.has("coins"):
			GameState.money += int(r.coins)
			lines.append(Loc.t("You got %d coins!") % int(r.coins))
		elif r.has("look"):
			var c: Dictionary = LanternColors.by_id(str(r.look))
			lines.append(Loc.t("A new lantern flame: %s. Choose it with the Storm Lantern.") % Loc.t(str(c.get("name", r.look))))
		elif r.has("meet"):
			var place: MapData = MapData.load_map(meet_map(s, r))
			lines.append(Loc.t("Rare visitor unlocked: %s (%s).") % [str(r.meet), Loc.t(place.display_name if place != null else meet_map(s, r))])
	return lines

static func meet_map(s: Dictionary, r: Dictionary) -> String:
	return str(r.get("map", s.map))

## Rare visitors unlocked on [param map_id]: [{"species", "ring"}].
static func meets_on(map_id: String, flags: Dictionary = GameState.flags) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in all():
		if not solved(str(s.id), flags):
			continue
		for r: Dictionary in rewards(s):
			if r.has("meet") and meet_map(s, r) == map_id:
				out.append({"species": str(r.meet), "ring": int(r.get("ring", 10))})
	return out

## Now and then (MEET_CHANCE) a wild encounter on [param map_id] is one of its unlocked rare
## visitors instead; null otherwise.
static func rare_wild(map_id: String, flags: Dictionary, rng: RandomNumberGenerator) -> Spirling:
	var list: Array[Dictionary] = meets_on(map_id, flags)
	if list.is_empty() or rng.randf() >= MEET_CHANCE:
		return null
	var pick: Dictionary = list[rng.randi_range(0, list.size() - 1)]
	var sd: SpirlingData = Database.species(str(pick.species))
	if sd == null:
		return null
	return Spirling.new(sd, int(pick.ring), rng)
