extends GutTest
## Spanish, French, Italian and Japanese cover every text of the German reference table and
## keep its placeholders (tools/i18n/check_lang.py --strict es fr it ja checks the same).

const CODES: Array[String] = ["es", "fr", "it", "ja"]

var de_keys: Array = []

func before_all() -> void:
	de_keys = (Loc.load_table("de").get("strings", {}) as Dictionary).keys()

func test_reference_table_loads() -> void:
	assert_gt(de_keys.size(), 10000)

func test_no_missing_keys() -> void:
	for code: String in CODES:
		var strings: Dictionary = Loc.load_table(code).get("strings", {})
		var missing: Array[String] = []
		for k: String in de_keys:
			if not strings.has(k):
				missing.append(k)
		assert_eq(missing.size(), 0, "%s misses %d keys, first: %s (tools/i18n/check_lang.py --missing %s)" % [code, missing.size(), str(missing.slice(0, 5)), code])

func test_placeholders_match() -> void:
	for code: String in CODES:
		var strings: Dictionary = Loc.load_table(code).get("strings", {})
		var bad: Array[String] = []
		for k: String in strings.keys():
			var v: String = str(strings[k])
			var ns: int = k.count("%s")
			var nd: int = k.count("%d")
			if v.contains("{0}"):
				for i: int in ns + nd:
					if not v.contains("{%d}" % i):
						bad.append(k)
						break
			elif v.count("%s") != ns or v.count("%d") != nd:
				bad.append(k)
		assert_eq(bad, [] as Array[String], code + " placeholders")
