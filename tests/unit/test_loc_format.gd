extends GutTest
## Texts with values ("%s sent you %s from %s!") must fill in every language. Some translations
## order the values by position ({0}, {1}: ja, ko, tr, zh), which Loc.t(key) % args cannot fill
## (format error at runtime, the text stays "{1}の{0}"). Loc.f fills both forms.

const SAMPLE_S: String = "Kindlop"
const SAMPLE_D: int = 7

var _lang: String

func before_all() -> void:
	_lang = Loc.language()

func after_all() -> void:
	Loc.set_language(_lang)

## Sample values for the %s and %d of [param key], in order.
static func samples(key: String) -> Array:
	var out: Array = []
	var i: int = 0
	while i < key.length() - 1:
		if key[i] == "%":
			var c: String = key[i + 1]
			if c == "s":
				out.append(SAMPLE_S)
			elif c == "d":
				out.append(SAMPLE_D)
			i += 2
			continue
		i += 1
	return out

## Every key that some language translates with {0}/{1}.
static func positional_keys() -> Array[String]:
	var keys: Dictionary = {}
	for lang: String in Loc.LANGUAGES:
		var table: Dictionary = Loc.load_table(lang).get("strings", {}) if lang != "en" else {}
		for k: Variant in table:
			if str(table[k]).contains("{0}") and (str(k).contains("%s") or str(k).contains("%d")):
				keys[str(k)] = true
	var out: Array[String] = []
	out.assign(keys.keys())
	return out

func test_positional_keys_fill_in_every_language() -> void:
	var keys: Array[String] = positional_keys()
	assert_gt(keys.size(), 0, "some translations use {0}")
	var bad: Array[String] = []
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for k: String in keys:
			var t: String = Loc.f(k, samples(k))
			if t.contains("{0}") or t.contains("{1}") or t.contains("%s") or t.contains("%d"):
				bad.append("%s: %s -> %s" % [lang, k, t])
	assert_eq(bad, [] as Array[String])

## No code fills a translated text with "%" when some language writes that text with {0}.
func test_no_percent_fill_after_translation_of_positional_keys() -> void:
	var keys: Array[String] = positional_keys()
	var re := RegEx.create_from_string("Loc\\.t\\((\"(?:[^\"\\\\]|\\\\.)*\")\\)\\s*%")
	var bad: Array[String] = []
	for path: String in _scripts("res://scripts"):
		var src: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(src):
			var key: Variant = JSON.parse_string(m.get_string(1))
			if key is String and key in keys:
				bad.append("%s: %s" % [path.get_file(), key])
	assert_eq(bad, [] as Array[String])

static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
