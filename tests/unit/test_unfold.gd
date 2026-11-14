extends GutTest
## Plan area 1, items 3, 100, 101-106: the unfold list and every unfold rule.

var _saved: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_saved)

func _kind(paths: Array[Dictionary]) -> SpirlingData:
	var sd := SpirlingData.new()
	sd.species_name = "Testling"
	sd.base_hp = 50
	sd.unfold = paths
	return sd

func _to(name: String) -> SpirlingData:
	return Database.species(name)

## Item 100: the ring rule keeps every old unfold exactly as it was.
func test_old_kinds_unfold_as_before() -> void:
	var expect: Dictionary = {
		"Kindlop": ["Smoldrake", 14], "Smoldrake": ["Calderox", 31], "Puddlet": ["Riptail", 18],
		"Riptail": ["Leviarch", 33], "Mossling": ["Thornback", 17], "Thornback": ["Verdantusk", 35],
		"Zippit": ["Glimmerax", 24], "Shalebat": ["Obsidroth", 26], "Zephlet": ["Tempestrel", 28],
		"Wickit": ["Lumenewt", 22], "Mirkmole": ["Duskdigger", 22],
	}
	for name: String in expect:
		var sd: SpirlingData = _to(name)
		assert_eq(sd.unfold.size(), 1, name)
		assert_eq(str(sd.unfold[0].rule), "ring", name)
		assert_eq(sd.evolves_to.species_name, expect[name][0], name)
		assert_eq(sd.evolve_level, expect[name][1], name)
		var map_id: String = "murk_hollow" if name == "Mirkmole" else ""
		assert_false(Spirling.new(sd, int(expect[name][1]) - 1).can_unfurl(map_id), "%s not before its ring" % name)
		assert_true(Spirling.new(sd, int(expect[name][1])).can_unfurl(map_id), "%s at its ring" % name)
	assert_false(Spirling.new(_to("Mirkmole"), 30).can_unfurl("crowcrest"), "Mirkmole only in Murk Hollow")
	var k := Spirling.new(_to("Kelpup"), 40)
	assert_false(k.can_unfurl(), "the Tide Pearl kind waits for its item")
	assert_true(k.can_evolve_with("tide_pearl"))
	for sd: SpirlingData in Database.spirlings.values():
		if sd.unfold.is_empty():
			assert_null(sd.evolves_to, "%s is a last form" % sd.species_name)

func test_evolves_to_is_still_read_as_a_fallback() -> void:
	var old: Dictionary = {"name": "X", "evolves_to": "Smoldrake", "evolve_level": 9}
	var paths: Array[Dictionary] = Database.unfold_paths(old)
	assert_eq(paths.size(), 1)
	assert_eq(str(paths[0].rule), "ring")
	assert_eq(int(paths[0].value), 9)
	var item: Array[Dictionary] = Database.unfold_paths({"evolves_to": "Kelphound", "evolve_item": "tide_pearl"})
	assert_eq(str(item[0].rule), "item")

func test_map_pages_rule() -> void:
	var s := Spirling.new(_kind([{"to": _to("Smoldrake"), "rule": "map_pages", "value": 6, "map": ""}]), 5)
	assert_false(s.unfold_ready(s.data.unfold[0], {"pages": 5}))
	assert_true(s.unfold_ready(s.data.unfold[0], {"pages": 6}))
	for i: int in range(1, 7):
		GameState.set_flag("page_%d" % i)
	assert_true(s.can_unfurl(), "reads the pages from GameState")

func test_mended_rule_follows_where_it_was_bonded() -> void:
	var s := Spirling.new(_kind([{"to": _to("Smoldrake"), "rule": "mended", "value": "origin", "map": ""}]), 5)
	s.origin_map = "saltmarsh"
	assert_eq(s.mend_rift("origin"), "tide")
	assert_false(s.unfold_ready(s.data.unfold[0], {"mended": ["cinder"]}))
	assert_true(s.unfold_ready(s.data.unfold[0], {"mended": ["tide"]}))
	s.origin_map = "cinder_rift"
	assert_eq(s.mend_rift("origin"), "cinder")
	var fixed := Spirling.new(_kind([{"to": _to("Smoldrake"), "rule": "mended", "value": "cinder", "map": ""}]), 5)
	GameState.rifts_sealed.assign(["cinder"])
	assert_true(fixed.can_unfurl())

func test_time_rule_needs_the_phase_and_the_place() -> void:
	var s := Spirling.new(_kind([{"to": _to("Smoldrake"), "rule": "time", "value": "dusk", "map": "saltmarsh"}]), 5)
	var p: Dictionary = s.data.unfold[0]
	assert_true(s.unfold_ready(p, {"phase": "dusk", "map": "saltmarsh"}))
	assert_false(s.unfold_ready(p, {"phase": "night", "map": "saltmarsh"}))
	assert_false(s.unfold_ready(p, {"phase": "dusk", "map": "fernstair"}))
	assert_eq(s.unfold_hint(p), "Needs: Dusk in Saltmarsh")

func test_echo_streak_rule() -> void:
	var s := Spirling.new(_kind([{"to": _to("Smoldrake"), "rule": "echo_streak", "value": 10, "map": ""}]), 5)
	s.echo_streak = 9
	assert_false(s.can_unfurl())
	s.echo_streak = 10
	assert_true(s.can_unfurl())
	var real := Spirling.new(_to("Kindlop"), 5)
	real.echo_streak = 10
	assert_eq(Spirling.from_dict(real.to_dict()).echo_streak, 10, "the streak is saved")

func test_two_paths_unfold_into_the_ready_one() -> void:
	var s := Spirling.new(_kind([
		{"to": _to("Smoldrake"), "rule": "ring", "value": 50, "map": ""},
		{"to": _to("Riptail"), "rule": "echo_streak", "value": 2, "map": ""},
	]), 10)
	assert_false(s.can_unfurl())
	s.echo_streak = 2
	assert_eq(s.unfurl_targets(), [_to("Riptail")] as Array[SpirlingData])
	s.evolve()
	assert_eq(s.data, _to("Riptail"))

func test_hints_name_what_is_missing() -> void:
	assert_eq(Spirling.new(_to("Kindlop"), 5).unfold_hints(), ["Needs: Ring 14"] as Array[String])
	assert_eq(Spirling.new(_to("Mirkmole"), 5).unfold_hints(), ["Needs: Ring 22 and a battle in Murk Hollow"] as Array[String])
	assert_eq(Spirling.new(_to("Kelpup"), 5).unfold_hints()[0], "Needs: Tide Shell")
