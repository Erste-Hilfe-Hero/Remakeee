extends GutTest
## Halcyra (Era IV, data/region4.json) brings two elements of its own: Gilt and Zenith
## (data/type_chart.json). They wait in the chart for Halcyra's Spirlings, like Rust and Mask.

const NEW: Array[String] = ["GILT", "ZENITH"]

var _types: Dictionary = {}

func before_all() -> void:
	_types = Elements.chart().get("types", {})

func _mult(a: String, d: String) -> float:
	var ad: bool = d in (_types[a].strong as Array)
	var da: bool = a in (_types[d].strong as Array)
	if ad and not da:
		return 2.0
	if da and not ad:
		return 0.5
	return 1.0

func test_halcyra_lists_its_two_era_four_elements() -> void:
	var region: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/region4.json"))
	assert_eq(region.elements, NEW)
	for t: String in NEW:
		assert_eq(int(_types[t].era), 4, t)
		assert_true(Elements.E.has(t), "%s is in the enum (appended after Acid and Frost)" % t)

func test_each_has_two_strengths_and_two_weaknesses() -> void:
	for t: String in NEW:
		var strong: Array[String] = []
		var weak: Array[String] = []
		for o: String in _types:
			if _mult(t, o) > 1.0:
				strong.append(o)
			if _mult(o, t) > 1.0:
				weak.append(o)
		assert_eq(strong.size(), 2, "%s strong vs %s" % [t, strong])
		assert_eq(weak.size(), 2, "%s weak to %s" % [t, weak])

## Gilt and Zenith mirror each other: whatever Gilt beats beats Zenith and the other way round,
## so the older elements keep as many strengths as weaknesses.
func test_gilt_and_zenith_mirror() -> void:
	assert_eq(_mult("GILT", "ZENITH"), 1.0)
	for o: String in _types:
		if o in NEW:
			continue
		if _mult("GILT", o) > 1.0:
			assert_gt(_mult(o, "ZENITH"), 1.0, "%s, beaten by Gilt, beats Zenith" % o)
		if _mult(o, "GILT") > 1.0:
			assert_gt(_mult("ZENITH", o), 1.0, "%s, beating Gilt, is beaten by Zenith" % o)

func test_names_in_english_and_german() -> void:
	assert_eq(str(_types.GILT.name), "Gilt")
	assert_eq(str(_types.ZENITH.name), "Zenith")
	var de: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/halcyra_types.json"))
	assert_eq(str(de.strings.Gilt), "Gold")
	assert_eq(str(de.strings.Zenith), "Zenit")
	assert_eq(Elements.chart_name("RUST"), Loc.t("Rust"))
