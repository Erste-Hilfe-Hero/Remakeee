class_name PatternTranslation
extends Translation
## A Translation keyed by the English text. Besides exact keys it understands patterns:
## a key such as "%s took %d damage." matches "Kindlop took 12 damage." and carries the values
## into the translated text ("%s erleidet %d Schaden."). Values that are themselves known
## texts (status names, item names) are translated too. Lines are translated one by one, and a
## line with no match is split into sentences. Godot calls this for every Label and Button,
## so menus need no tr() calls of their own.

## English key -> translated text, for keys without placeholders.
var exact: Dictionary[String, String] = {}
## [{"re": RegEx, "out": String}] sorted so the most specific pattern wins.
var patterns: Array[Dictionary] = []
var _cache: Dictionary[String, String] = {}
var _sentence: RegEx

func _init() -> void:
	_sentence = RegEx.create_from_string("(?<=[.!?])\\s+")

## Fills the table from {english: translated}.
func load_strings(table: Dictionary) -> void:
	exact.clear()
	patterns.clear()
	_cache.clear()
	for k: Variant in table.keys():
		var key: String = str(k)
		var out: String = str(table[k])
		if key.contains("%s") or key.contains("%d"):
			patterns.append({"re": RegEx.create_from_string(_pattern_regex(key)), "out": out, "weight": _literal_length(key)})
			# A format key is looked up before "%" fills it in, so "%%" must stay (item 866).
			exact[key] = out
		else:
			exact[key] = out.replace("%%", "%") if key.contains("%%") else out
	patterns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.weight) > int(b.weight))

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s: String = String(src_message)
	var t: String = lookup(s)
	return StringName(t) if t != "" else &""

## The translation of [param s], or "" if nothing matched.
func lookup(s: String) -> String:
	if s.is_empty():
		return ""
	if _cache.has(s):
		return _cache[s]
	var result: String = _lookup_line(s)
	if result == "" and s.contains("\n"):
		var parts: PackedStringArray = s.split("\n")
		var any: bool = false
		for i: int in parts.size():
			var t: String = _lookup_line(parts[i])
			if t != "":
				parts[i] = t
				any = true
		if any:
			result = "\n".join(parts)
	_cache[s] = result
	return result

func _lookup_line(s: String) -> String:
	if s.strip_edges().is_empty():
		return ""
	if exact.has(s):
		return exact[s]
	# Leading spaces or a list dash ("- ") stay as they are; the rest is looked up.
	var body: String = s.lstrip(" -")
	var lead: String = s.substr(0, s.length() - body.length())
	if lead != "" and body != "":
		var inner: String = _lookup_line(body)
		if inner != "":
			return lead + inner
		return ""
	var p: String = _match_pattern(s)
	if p != "":
		return p
	var sentences: PackedStringArray = _split_sentences(s)
	if sentences.size() < 2:
		return ""
	var any: bool = false
	for i: int in sentences.size():
		var t: String = exact.get(sentences[i], "")
		if t == "":
			t = _match_pattern(sentences[i])
		if t != "":
			sentences[i] = t
			any = true
	return " ".join(sentences) if any else ""

func _match_pattern(s: String) -> String:
	for p: Dictionary in patterns:
		var m: RegExMatch = (p.re as RegEx).search(s)
		if m == null:
			continue
		var values: Array[String] = []
		for g: int in range(1, m.get_group_count() + 1):
			var v: String = m.get_string(g)
			values.append(exact.get(v, v))
		return _fill(str(p.out), values)
	return ""

func _split_sentences(s: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var start: int = 0
	for m: RegExMatch in _sentence.search_all(s):
		out.append(s.substr(start, m.get_start() - start))
		start = m.get_end()
	out.append(s.substr(start))
	return out

## Puts [param values] into [param out]: {0}, {1}... by position, otherwise %s / %d in order.
static func _fill(out: String, values: Array[String]) -> String:
	if out.contains("{0}"):
		var r: String = out
		for i: int in values.size():
			r = r.replace("{%d}" % i, values[i])
		return r.replace("%%", "%")
	var r2: String = ""
	var vi: int = 0
	var i2: int = 0
	while i2 < out.length():
		if out[i2] == "%" and i2 + 1 < out.length():
			var c: String = out[i2 + 1]
			if (c == "s" or c == "d") and vi < values.size():
				r2 += values[vi]
				vi += 1
				i2 += 2
				continue
			if c == "%":
				r2 += "%"
				i2 += 2
				continue
		r2 += out[i2]
		i2 += 1
	return r2

static func _pattern_regex(key: String) -> String:
	var r: String = "^"
	var i: int = 0
	while i < key.length():
		var c: String = key[i]
		if c == "%" and i + 1 < key.length():
			var n: String = key[i + 1]
			if n == "s":
				r += "(.+?)"
				i += 2
				continue
			if n == "d":
				r += "(-?\\d+)"
				i += 2
				continue
			if n == "%":
				r += "%"
				i += 2
				continue
		r += _escape(c)
		i += 1
	return r + "$"

static func _escape(c: String) -> String:
	return "\\" + c if "\\^$.|?*+()[]{}".contains(c) else c

static func _literal_length(key: String) -> int:
	return key.replace("%s", "").replace("%d", "").length()
