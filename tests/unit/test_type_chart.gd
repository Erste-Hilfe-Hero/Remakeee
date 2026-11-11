extends GutTest
## data/type_chart.json rules (docs/BALANCE.md, Type balance). The win-rate band is checked by
## tools/balance/type_sim.py in CI.

var _types: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_types = Elements.chart().get("types", {})

func _mult(a: String, d: String) -> float:
	if d in (_types[a].strong as Array):
		return 2.0
	if a in (_types[d].strong as Array):
		return 0.5
	return 1.0

func test_every_element_has_two_strengths_and_two_weaknesses() -> void:
	assert_gte(_types.size(), 10)
	for t: String in _types:
		var weak: int = 0
		for o: String in _types:
			if t in (_types[o].strong as Array):
				weak += 1
		assert_gte((_types[t].strong as Array).size(), 2, "%s strengths" % t)
		assert_gte(weak, 2, "%s weaknesses" % t)

func test_no_mutual_pair_and_no_strict_dominance() -> void:
	for a: String in _types:
		for b: String in _types:
			if a == b:
				continue
			assert_false(b in (_types[a].strong as Array) and a in (_types[b].strong as Array), "%s and %s beat each other" % [a, b])
			var all_ge: bool = true
			var any_gt: bool = false
			for x: String in _types:
				var off: float = _mult(a, x) - _mult(b, x)
				var dfn: float = _mult(x, b) - _mult(x, a)
				all_ge = all_ge and off >= 0.0 and dfn >= 0.0
				any_gt = any_gt or off > 0.0 or dfn > 0.0
			assert_false(all_ge and any_gt, "%s strictly dominates %s" % [a, b])

func test_era_two_elements_sit_on_no_spirling() -> void:
	assert_true(_types.has("INK") and _types.has("ECHO"))
	for t: String in ["INK", "ECHO"]:
		assert_eq(int(_types[t].era), 2)
		assert_false(Elements.E.has(t), "%s stays out of the Era I enum" % t)

func test_era_one_strong_matches_the_chart() -> void:
	for e: int in Elements.E.values():
		var el: String = Elements.E.keys()[e]
		for t: Variant in _types[el].strong:
			if Elements.E.has(str(t)):
				assert_eq(Elements.single(e, Elements.E[str(t)]), 2.0, "%s -> %s" % [el, t])
