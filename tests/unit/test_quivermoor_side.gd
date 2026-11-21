extends GutTest
## Quivermoor side goals (tools/art/world/quivermoor_side.py, data/quests.json q5_*): eight errands,
## each with a giver, two steps, a reveal and a betrayer whose defeat ends the goal.

var _goals: Array = []
var _npcs: Dictionary = {}   # npc id -> [map id, npc]

func before_all() -> void:
	Database.load_all()
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for g: Dictionary in q.side:
		if str(g.id).begins_with("q5_"):
			_goals.append(g)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.region != "quivermoor":
			continue
		for n: Dictionary in m.npcs:
			if str(n.get("id", "")).begins_with("q5_"):
				_npcs[str(n.id)] = [id, n]

## Every action reachable from [param ref] through "else" and "next" in the same file.
func _actions(ref: String) -> String:
	var out: String = ""
	var seen: Dictionary = {}
	var todo: Array[String] = [ref]
	while not todo.is_empty():
		var r: String = todo.pop_back()
		if seen.has(r) or not Dialogue.exists(r):
			continue
		seen[r] = true
		var e: Dictionary = Dialogue.get_entry(r)
		out += str(e.get("action", "")) + ";"
		for k: String in ["else", "next"]:
			if e.has(k):
				todo.append(Dialogue.resolve_ref(r, str(e[k])))
	return out

func _of(goal: Dictionary) -> Array:
	var out: Array = []
	for id: String in _npcs:
		if id.begins_with(str(goal.id) + "_"):
			out.append(_npcs[id])
	return out

func test_eight_goals_in_quivermoor() -> void:
	assert_eq(_goals.size(), 8)
	var places: Array[String] = []
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.region == "quivermoor":
			places.append(m.display_name)
	for g: Dictionary in _goals:
		var hit: bool = false
		for p: String in places:
			hit = hit or str(g.where).contains(p)
		assert_true(hit, "%s is in Quivermoor" % g.id)
		assert_eq((g.progress as Array).size(), 4, str(g.id))
		assert_eq((g.stages as Array).size(), 5, str(g.id))
		assert_eq(str(g.progress[3]), str(g.done), "beating the betrayer is the last step")

func test_every_step_can_be_reached() -> void:
	for g: Dictionary in _goals:
		var acts: String = ""
		var shown: Dictionary = {}
		for row: Array in _of(g):
			var n: Dictionary = row[1]
			acts += _actions(str(n.dialogue))
			if n.has("show_flag"):
				shown[str(n.show_flag)] = true
		var p: Array = g.progress
		for f: String in [str(g.show), str(p[0]), str(p[1]), str(p[2])]:
			assert_true(acts.contains("set_flag " + f), "%s: %s is set" % [g.id, f])
		for f: String in [str(g.show), str(p[0]), str(p[2])]:
			assert_true(shown.has(f), "%s: someone shows up after %s" % [g.id, f])
		assert_true(acts.contains("give_item"), "%s pays out" % g.id)
		assert_true(acts.contains("quest_stage %s 3" % g.id), str(g.id))

func test_betrayers_end_their_goal() -> void:
	var wild_top: int = 0
	for r: Dictionary in Region5.data().routes:
		wild_top = maxi(wild_top, int(r.ring[1]))
	for g: Dictionary in _goals:
		var found: int = 0
		for row: Array in _of(g):
			var n: Dictionary = row[1]
			if not n.has("trainer"):
				continue
			found += 1
			assert_eq(str(n.show_flag), str(g.progress[2]), "%s turns up after the reveal" % n.id)
			assert_has(n.win_flags, str(g.done))
			assert_true(bool(n.get("no_rematch", false)), "%s keeps the loot talk" % n.id)
			var els: Dictionary = {}
			for e: Dictionary in n.team:
				assert_lte(int(e.level), wild_top + 2, str(n.id))
				for el: int in Database.species(str(e.species)).elements:
					els[el] = true
			assert_lte(els.size(), 3, str(n.id))
			for k: String in ["dialogue", "intro", "defeat"]:
				assert_true(Dialogue.exists(str(n[k])), "%s %s" % [n.id, k])
		assert_eq(found, 1, "%s has one betrayer" % g.id)

func test_goals_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for g: Dictionary in _goals:
		assert_true(de.has(str(g.text)), str(g.id))
		for st: Dictionary in g.stages:
			assert_true(de.has(str(st.text)), "DE missing: %s" % st.text)
		for row: Array in _of(g):
			var n: Dictionary = row[1]
			for k: String in ["dialogue", "intro", "defeat"]:
				if not n.has(k):
					continue
				for s: Variant in Dialogue.get_entry(str(n[k])).get("lines", []):
					assert_true(de.has(str(s)), "DE missing: %s" % s)
