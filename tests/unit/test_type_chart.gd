extends GutTest
## data/type_chart.json rules (docs/BALANCE.md, Type balance). The win-rate band is checked by
## tools/balance/type_sim.py in CI.

var _types: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_types = Elements.chart().get("types", {})

## A mutual pair (Lumen and Umbra) is neutral both ways, like Elements.single().
func _mult(a: String, d: String) -> float:
	var ad: bool = d in (_types[a].strong as Array)
	var da: bool = a in (_types[d].strong as Array)
	if ad and not da:
		return 2.0
	if da and not ad:
		return 0.5
	return 1.0

func test_every_element_has_two_strengths_and_two_weaknesses() -> void:
	assert_gte(_types.size(), 10)
	for t: String in _types:
		var strong: int = 0
		var weak: int = 0
		for o: String in _types:
			if _mult(t, o) > 1.0:
				strong += 1
			if _mult(o, t) > 1.0:
				weak += 1
		assert_gte(strong, 2, "%s real strengths" % t)
		assert_gte(weak, 2, "%s weaknesses" % t)

func test_no_strict_dominance() -> void:
	for a: String in _types:
		for b: String in _types:
			if a == b:
				continue
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
				assert_eq(Elements.single(e, Elements.E[str(t)]), _mult(el, str(t)), "%s -> %s" % [el, t])
