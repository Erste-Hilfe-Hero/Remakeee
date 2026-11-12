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

## As many real strengths as weaknesses, for Era I alone and for all eras (tools/balance/type_sim.py
## chart sim: no element is ahead on the chart alone).
func test_strengths_equal_weaknesses_per_era() -> void:
	for era_max: int in [1, 2, 3]:
		for t: String in _types:
			if int(_types[t].era) > era_max:
				continue
			var strong: int = 0
			var weak: int = 0
			for o: String in _types:
				if int(_types[o].era) > era_max:
					continue
				if _mult(t, o) > 1.0:
					strong += 1
				if _mult(o, t) > 1.0:
					weak += 1
			assert_eq(strong, weak, "%s up to Era %d" % [t, era_max])

## Rust and Mask (Vellmarch, data/region2.json) are Era II and sit in the chart before the enum.
func test_rust_and_mask_are_era_two_chart_entries() -> void:
	for t: String in ["RUST", "MASK"]:
		assert_true(_types.has(t), t)
		assert_eq(int(_types[t].era), 2, t)
	assert_eq(_mult("RUST", "MASK"), 2.0)

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

func test_era_two_elements_stay_rare() -> void:
	assert_true(_types.has("INK") and _types.has("ECHO"))
	for t: String in ["INK", "ECHO"]:
		assert_eq(int(_types[t].era), 2)
		assert_true(Elements.E.has(t), "%s is in the enum so legendaries can use it" % t)
	# Owner rule: Era II elements on legendaries, and sparingly on act kinds (tools/balance/type_sim.py).
	for t: String in ["INK", "ECHO"]:
		var n: int = 0
		for sd: SpirlingData in Database.spirlings.values():
			n += 1 if sd.rarity != "ancient" and sd.elements.has(Elements.E[t]) else 0
		assert_between(n, 1, 6, "%s on act kinds" % t)

func test_era_one_strong_matches_the_chart() -> void:
	for e: int in Elements.E.values():
		var el: String = Elements.E.keys()[e]
		for t: Variant in _types[el].strong:
			if Elements.E.has(str(t)):
				assert_eq(Elements.single(e, Elements.E[str(t)]), _mult(el, str(t)), "%s -> %s" % [el, t])
