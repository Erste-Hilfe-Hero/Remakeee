class_name Dialogue
extends RefCounted
## Dialogue lookup. A reference "file/key" means data/dialogue/<file>.json -> <key>.
## An entry is a list of lines or a Dictionary with these optional fields:
##   "lines": [String]          what is said
##   "speaker": String          name tag over the text box (else "Name: ..." in a line is used)
##   "action": String           actions to run afterwards, separated by ";"
##   "flag": String             flag set afterwards ("once": true runs the action only the first time)
##   "after_flag": {"flag", "lines"} or a list of them; the LAST variant whose flag is set wins,
##                              so a figure can have new lines in every chapter (plan item 1337)
##   "if": {...}                conditions (see [method check]); a failing entry jumps to "else"
##                              (a key in the same file) or says nothing
##   "choices": [{"text", "flag", "action", "next", "if"}]   2-3 answers after the last line
##   "next": String             key in the same file to continue with afterwards
## A choice or variant can carry its own "if" and only shows when it holds.

const DIR: String = "res://data/dialogue/"
## Conditions understood in "if" (DataValidator rejects anything else).
const CONDITIONS: Array[String] = ["flag", "not_flag", "has_item", "has_species", "has_element",
	"party_size_min", "chapter_min", "var_min", "var_max", "choice", "trust_min", "trust_max"]
## Upper bound for "next" hops in one conversation (stops loops in broken data).
const MAX_HOPS: int = 32

static var _cache: Dictionary[String, Dictionary] = {}

## The whole file data/dialogue/<file>.json ({} if missing).
static func file_data(file: String) -> Dictionary:
	if not _cache.has(file):
		var path: String = DIR + file + ".json"
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_cache[file] = raw if raw is Dictionary else {}
	return _cache[file]

static func get_entry(ref: String) -> Dictionary:
	var parts: PackedStringArray = ref.split("/", false, 1)
	if parts.size() != 2:
		return {"lines": [ref]}
	return normalize(file_data(parts[0]).get(parts[1]))

## True if the reference points at an existing entry.
static func exists(ref: String) -> bool:
	var parts: PackedStringArray = ref.split("/", false, 1)
	return parts.size() == 2 and file_data(parts[0]).has(parts[1])

static func normalize(entry: Variant) -> Dictionary:
	if entry is Array:
		return {"lines": entry}
	if entry is Dictionary:
		return entry
	return {"lines": ["..."]}

## "file/key" for a "next" target: a bare key stays in the file of [param from_ref].
static func resolve_ref(from_ref: String, target: String) -> String:
	if target.contains("/"):
		return target
	return from_ref.get_slice("/", 0) + "/" + target

## The after_flag variants as a list (old entries have a single Dictionary).
static func variants(entry: Dictionary) -> Array:
	var alt: Variant = entry.get("after_flag")
	if alt is Dictionary:
		return [alt]
	if alt is Array:
		return alt
	return []

## The lines to show now, honouring "after_flag" variants (the last one that applies wins).
## While no variant applies, "night_lines" replace the lines at night (plan item 1353) and
## "daily" (a list of line lists) gives one new set per calendar day (plan item 1352).
## [param phase] and [param day] default to the device clock; tests pass them in.
static func lines_for(entry: Dictionary, flags: Dictionary, phase: int = -1, day: int = -1) -> Array[String]:
	var out: Array[String] = []
	var src: Variant = ambient_lines(entry, phase, day)
	for v: Variant in variants(entry):
		if not v is Dictionary:
			continue
		var d: Dictionary = v
		var f: String = str(d.get("flag", ""))
		if (f.is_empty() or bool(flags.get(f, false))) and (not d.has("if") or check(d.get("if"), flags)):
			src = d.get("lines", src)
	for l: Variant in src:
		out.append(str(l))
	return out

## The base lines of [param entry] for this time: "night_lines" at night, else one set
## from "daily" picked by the day number, else "lines".
static func ambient_lines(entry: Dictionary, phase: int = -1, day: int = -1) -> Variant:
	if entry.has("night_lines"):
		var p: int = phase if phase >= 0 else (DayCycle.current() if GameState.day_night else DayCycle.Phase.DAY)
		if p == DayCycle.Phase.NIGHT:
			return entry.night_lines
	var daily: Variant = entry.get("daily")
	if daily is Array and not (daily as Array).is_empty():
		var d: int = day if day >= 0 else day_number()
		var pick: Variant = (daily as Array)[posmod(d, (daily as Array).size())]
		if pick is Array:
			return pick
	return entry.get("lines", [])

## Local calendar day count since 1970, so "daily" lines change at midnight.
static func day_number() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return int(floor(float(now + bias) / 86400.0))

## The speaker of an entry or variant, "" if none is given.
static func speaker_for(entry: Dictionary) -> String:
	return str(entry.get("speaker", ""))

## The choices whose "if" holds now.
static func choices_for(entry: Dictionary, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Variant in entry.get("choices", []):
		if c is Dictionary and (not (c as Dictionary).has("if") or check((c as Dictionary).get("if"), flags)):
			out.append(c)
	return out

## Splits a legacy line "Aldo: text" into ["Aldo", "text"]; lines without a short name
## before ": " come back as ["", line].
const NOT_SPEAKERS: Array[String] = ["Tip", "Tips", "Hint", "Note"]

static func split_speaker(line: String) -> PackedStringArray:
	var i: int = line.find(": ")
	if i <= 0 or i > 24:
		return PackedStringArray(["", line])
	var who: String = line.substr(0, i)
	# A name is one or two capitalised words ("Aldo", "Warden Senna"), no sentence punctuation.
	if not who[0] == who[0].to_upper() or who.contains(".") or who.contains(",") or who.contains("'") or who.count(" ") > 2:
		return PackedStringArray(["", line])
	# "Tip: ..." is a hint, not a speaker; as a name tag it covered the Vigor bar in battle (owner, 9 Nov).
	for word: String in NOT_SPEAKERS:
		if who == word or who == Loc.t(word):
			return PackedStringArray(["", line])
	return PackedStringArray([who, line.substr(i + 2)])

static func _as_list(v: Variant) -> Array:
	return v if v is Array else [v]

## True if every condition in [param cond] holds. Unknown conditions fail (and the validator
## reports them). Uses GameState for team, satchel, story numbers and choices.
static func check(cond: Variant, flags: Dictionary) -> bool:
	if not cond is Dictionary:
		return true
	var c: Dictionary = cond
	for k: Variant in c:
		var v: Variant = c[k]
		match str(k):
			"flag":
				for f: Variant in _as_list(v):
					if not bool(flags.get(str(f), false)):
						return false
			"not_flag":
				for f: Variant in _as_list(v):
					if bool(flags.get(str(f), false)):
						return false
			"has_item":
				for it: Variant in _as_list(v):
					if GameState.item_count(str(it)) <= 0:
						return false
			"has_species":
				for sp: Variant in _as_list(v):
					if not _party_has(func(s: Spirling) -> bool: return s.data.species_name == str(sp)):
						return false
			"has_element":
				for e: Variant in _as_list(v):
					var want: int = int(Elements.E.get(str(e).to_upper(), -1))
					if not _party_has(func(s: Spirling) -> bool: return want in s.data.elements):
						return false
			"party_size_min":
				if GameState.party.size() < int(v):
					return false
			"chapter_min":
				if QuestLog.current_index(flags) < int(v):
					return false
			"var_min":
				for name: Variant in (v as Dictionary if v is Dictionary else {}):
					if GameState.story_var(str(name)) < int(v[name]):
						return false
			"var_max":
				for name: Variant in (v as Dictionary if v is Dictionary else {}):
					if GameState.story_var(str(name)) > int(v[name]):
						return false
			"trust_min", "trust_max":
				# Hidden clan trust (Trust.gd): {"marlo": 40}.
				for id: Variant in (v as Dictionary if v is Dictionary else {}):
					var t: int = Trust.trust(str(id))
					if (t < int(v[id])) if str(k) == "trust_min" else (t > int(v[id])):
						return false
			"choice":
				for name: Variant in (v as Dictionary if v is Dictionary else {}):
					if str(GameState.story_choices.get(str(name), "")) != str(v[name]):
						return false
			_:
				return false
	return true

static func _party_has(pred: Callable) -> bool:
	for s: Spirling in GameState.party:
		if pred.call(s):
			return true
	return false
