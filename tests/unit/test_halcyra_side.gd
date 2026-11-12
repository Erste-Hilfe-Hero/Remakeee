extends GutTest
## Halcyra side goals (tools/art/world/halcyra_side.py, data/quests.json q4_*): twelve errands in the
## Gilt family's region, each with a giver, two steps, a reveal and a betrayer whose defeat ends the goal.
## The betrayer is a trainer on the map or a story duel (data/story_battles.json hs_*).

var _goals: Array = []
var _npcs: Dictionary = {}   # npc id -> [map id, npc]
var _places: Array[String] = []

func before_all() -> void:
	Database.load_all()
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for g: Dictionary in q.side:
		if str(g.id).begins_with("q4_"):
			_goals.append(g)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.region != "halcyra":
			continue
		_places.append(m.display_name)
		for n: Dictionary in m.npcs:
			if str(n.get("id", "")).begins_with("q4_") or str(n.get("id", "")).begins_with("hs_"):
				_npcs[str(n.id)] = [id, n]

## Every action reachable from [param ref] through "else", "next" and choices in the same file.
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
		for c: Dictionary in e.get("choices", []):
			out += str(c.get("action", "")) + ";"
			if c.has("flag"):
				out += "set_flag " + str(c.flag) + ";"
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

func _story(id: String) -> Dictionary:
	var sb: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_battles.json"))
	return sb.get(id, {})

func _top() -> int:
	var top: int = 0
	for r: Dictionary in Region4.data().routes:
		top = maxi(top, int(r.ring[1]))
	return top

func _check_team(team: Array, who: String) -> void:
	var els: Dictionary = {}
	for e: Dictionary in team:
		assert_lte(int(e.level), _top() + 2, who)
		for el: int in Database.species(str(e.species)).elements:
			els[el] = true
	assert_lte(els.size(), 3, "%s stays within three elements" % who)

func test_twelve_goals_in_halcyra() -> void:
	assert_eq(_goals.size(), 12)
	for g: Dictionary in _goals:
		var hit: bool = false
		for p: String in _places:
			hit = hit or str(g.where).contains(p)
		assert_true(hit, "%s is in Halcyra" % g.id)
		assert_eq((g.progress as Array).size(), 4, str(g.id))
		assert_eq((g.stages as Array).size(), 5, str(g.id))
		assert_eq(str(g.progress[3]), str(g.done), "beating the betrayer is the last step")

func test_three_new_places() -> void:
	for id: String in ["fallen_planet", "brine_catacombs", "gilt_cellars"]:
		var m: MapData = MapData.load_map(id)
		assert_not_null(m, id)
		assert_eq(m.region, "halcyra", id)
		assert_gte(m.secrets.size(), 2, "%s hides finds" % id)

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
	var duels: int = 0
	for g: Dictionary in _goals:
		var found: int = 0
		for row: Array in _of(g):
			var n: Dictionary = row[1]
			if n.has("trainer"):
				found += 1
				assert_eq(str(n.show_flag), str(g.progress[2]), "%s turns up after the reveal" % n.id)
				assert_has(n.win_flags, str(g.done))
				assert_true(bool(n.get("no_rematch", false)), "%s keeps the loot talk" % n.id)
				_check_team(n.team, str(n.id))
				for k: String in ["dialogue", "intro", "defeat"]:
					assert_true(Dialogue.exists(str(n[k])), "%s %s" % [n.id, k])
				continue
			var acts: String = _actions(str(n.dialogue))
			var at: int = acts.find("battle hs_")
			if at < 0 or str(n.get("show_flag", "")) != str(g.progress[2]):
				continue
			var bid: String = acts.substr(at + 7).get_slice(";", 0).strip_edges()
			var b: Dictionary = _story(bid)
			if not (b.get("win_flags", []) as Array).has(str(g.done)):
				continue
			found += 1
			duels += 1
			_check_team(b.team, bid)
			assert_true(Dialogue.exists(str(b.defeat)), "%s defeat" % bid)
		assert_eq(found, 1, "%s has one betrayer" % g.id)
	assert_gte(duels, 5, "story duels")

func test_wayfarers_follow_their_road() -> void:
	var rings: Dictionary = {}
	for r: Dictionary in Region4.data().routes:
		rings[str(r.id)] = r.ring
	var count: int = 0
	for id: String in _npcs:
		if not id.begins_with("hs_"):
			continue
		var row: Array = _npcs[id]
		var n: Dictionary = row[1]
		if not n.has("trainer") or not rings.has(str(row[0])):
			continue
		count += 1
		var ring: Array = rings[str(row[0])]
		for e: Dictionary in n.team:
			assert_between(int(e.level), int(ring[0]), int(ring[1]) + 2, "%s on %s" % [id, row[0]])
		_check_team(n.team, id)
	assert_gte(count, 8, "Wayfarers on the roads")

func test_trust_holds_favors_and_betrayals() -> void:
	assert_eq(Trust.validate(), PackedStringArray(), "Trust.validate")
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/clans.json"))
	var favors: int = 0
	var betrayals: int = 0
	for k: String in c.get("favors", {}):
		favors += int(k.begins_with("hs_"))
	for k: String in c.get("betrayals", {}):
		betrayals += int(k.begins_with("hs_"))
	assert_gte(favors, 3, "favors")
	assert_gte(betrayals, 4, "betrayals")

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
