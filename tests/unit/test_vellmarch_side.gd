extends GutTest
## Vellmarch side goals (tools/art/world/vellmarch_side.py, data/quests.json q2_*): twelve errands,
## each with a giver, two steps (some a story duel), a reveal (some with a trust choice) and a
## betrayer whose defeat ends the goal; three places under the roads; Wayfarers by road range.

const GOALS: int = 12
const PLACES: Dictionary = {"smugglers_culvert": "weeping_locks", "slag_tunnels": "smelters_drift", "bell_crypt": "bellrope_marsh"}

var _goals: Array = []
var _npcs: Dictionary = {}   # npc id -> [map id, npc]
var _maps: Dictionary = {}   # map id -> MapData

func before_all() -> void:
	Database.load_all()
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for g: Dictionary in q.side:
		if str(g.id).begins_with("q2_"):
			_goals.append(g)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.region != "vellmarch":
			continue
		_maps[id] = m
		for n: Dictionary in m.npcs:
			if str(n.get("id", "")).begins_with("q2_"):
				_npcs[str(n.id)] = [id, n]

## Every entry reachable from [param ref] through "else", "next" and choices in the same file.
func _entries(ref: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var todo: Array[String] = [ref]
	while not todo.is_empty():
		var r: String = todo.pop_back()
		if seen.has(r) or not Dialogue.exists(r):
			continue
		seen[r] = true
		var e: Dictionary = Dialogue.get_entry(r)
		out.append(e)
		for k: String in ["else", "next"]:
			if e.has(k):
				todo.append(Dialogue.resolve_ref(r, str(e[k])))
		for c: Dictionary in e.get("choices", []):
			if c.has("next"):
				todo.append(Dialogue.resolve_ref(r, str(c.next)))
	return out

## Every flag a talk starting at [param ref] can set: actions, choices and the duels it starts.
func _sets(ref: String) -> String:
	var out: String = ""
	for e: Dictionary in _entries(ref):
		var action: String = str(e.get("action", ""))
		out += action + ";"
		for c: Dictionary in e.get("choices", []):
			out += "set_flag %s;" % str(c.get("flag", ""))
		for part: String in action.split(";"):
			var words: PackedStringArray = part.strip_edges().split(" ")
			if words[0] == "battle":
				var def: Dictionary = StoryBattles.get_def(words[1])
				for f: Variant in def.get("win_flags", []):
					out += "set_flag %s;" % str(f)
				out += _sets(str(def.get("defeat", "")))
	return out

func _of(goal: Dictionary) -> Array:
	var out: Array = []
	for id: String in _npcs:
		if id.begins_with(str(goal.id) + "_"):
			out.append(_npcs[id])
	return out

func _elements(team: Array) -> int:
	var els: Dictionary = {}
	for e: Dictionary in team:
		for el: int in Database.species(str(e.species)).elements:
			els[el] = true
	return els.size()

func _road(map_id: String) -> Dictionary:
	return Region2.route(str(PLACES.get(map_id, map_id)))

func test_twelve_goals_in_vellmarch() -> void:
	assert_eq(_goals.size(), GOALS)
	var places: Array[String] = []
	for id: String in _maps:
		places.append((_maps[id] as MapData).display_name)
	for g: Dictionary in _goals:
		assert_eq((g.progress as Array).size(), 4, str(g.id))
		assert_eq((g.stages as Array).size(), 5, str(g.id))
		assert_eq(str(g.progress[3]), str(g.done), "beating the betrayer is the last step")
		for st: Dictionary in g.stages:
			assert_has(places, str(st.where), "%s: %s is a place in Vellmarch" % [g.id, st.where])

func test_every_step_can_be_reached() -> void:
	for g: Dictionary in _goals:
		var acts: String = ""
		var shown: Dictionary = {}
		for row: Array in _of(g):
			var n: Dictionary = row[1]
			acts += _sets(str(n.dialogue))
			if n.has("show_flag"):
				shown[str(n.show_flag)] = true
		var p: Array = g.progress
		for f: String in [str(g.show), str(p[0]), str(p[1]), str(p[2])]:
			assert_true(acts.contains("set_flag " + f), "%s: %s is set" % [g.id, f])
		for f: String in [str(g.show), str(p[0]), str(p[2])]:
			assert_true(shown.has(f), "%s: someone shows up after %s" % [g.id, f])
		assert_true(acts.contains("give_item"), "%s pays out" % g.id)
		for n: int in [1, 2, 3, 4]:
			assert_true(acts.contains("quest_stage %s %d" % [g.id, n]), "%s reaches stage %d" % [g.id, n])

func test_betrayers_end_their_goal() -> void:
	var seen: Dictionary = {}
	var low: int = 999
	var top: int = 0
	for r: Dictionary in Region2.data().routes:
		low = mini(low, int(r.ring[1]) - 1)
		top = maxi(top, int(r.ring[1]) + 1)
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
			assert_eq((n.team as Array).size(), 3, str(n.id))
			for e: Dictionary in n.team:
				assert_between(int(e.level), low, top, "%s ring by the roads' range" % n.id)
			assert_lte(_elements(n.team), 3, str(n.id))
			for k: String in ["dialogue", "intro", "defeat"]:
				assert_true(Dialogue.exists(str(n[k])), "%s %s" % [n.id, k])
			seen[str(n.trainer)] = true
		assert_eq(found, 1, "%s has one betrayer" % g.id)
	assert_eq(seen.size(), GOALS, "twelve different betrayers")

func test_trust_choices_change_the_pay() -> void:
	var asked: int = 0
	for g: Dictionary in _goals:
		var reveal: Dictionary = Dialogue.get_entry("vellmarch/%s_reveal" % g.id)
		if not reveal.has("choices"):
			continue
		asked += 1
		assert_eq((reveal.choices as Array).size(), 2, str(g.id))
		var flags: Array = []
		for c: Dictionary in reveal.choices:
			flags.append(str(c.flag))
			assert_true(Dialogue.exists("vellmarch/" + str(c.next)), "%s answers" % c.flag)
		var kind: Dictionary = Dialogue.get_entry("vellmarch/%s_reward" % g.id)
		var wary: Dictionary = Dialogue.get_entry("vellmarch/%s_reward_doubt" % g.id)
		assert_has(wary["if"].flag, flags[1], "%s: doubting them is remembered" % g.id)
		assert_has(wary["if"].flag, str(g.done))
		assert_ne(str(kind.action), str(wary.action), "%s pays differently" % g.id)
		for e: Dictionary in [kind, wary]:
			assert_true(str(e.action).contains("give_item"), str(g.id))
	assert_gte(asked, 4, "several givers ask whether you believe them")

func test_story_duels() -> void:
	var duels: int = 0
	for id: String in StoryBattles.data():
		if not id.begins_with("q2_"):
			continue
		duels += 1
		var def: Dictionary = StoryBattles.get_def(id)
		var where: Array = _npcs.get(id, [])
		assert_eq(where.size(), 2, "%s is started by a figure on a map" % id)
		if where.is_empty():
			continue
		assert_true(str(Dialogue.get_entry(str(where[1].dialogue)).action).contains("battle " + id), id)
		var ring: Array = _road(str(where[0])).ring
		for e: Dictionary in def.team:
			assert_between(int(e.level), int(ring[0]), int(ring[1]), "%s ring by its road" % id)
		assert_lte(_elements(def.team), 3, id)
		assert_true(Dialogue.exists(str(def.defeat)), id)
		assert_eq((def.win_flags as Array).size(), 1, id)
	assert_gte(duels, 3)

func test_places_under_the_roads() -> void:
	for id: String in PLACES:
		assert_true(_maps.has(id), "%s is a Vellmarch map" % id)
		if not _maps.has(id):
			continue
		var m: MapData = _maps[id]
		var road: MapData = _maps[str(PLACES[id])]
		assert_eq(EraManager.region_era(m.region), EraManager.Era.WASH, "%s is drawn in Era II" % id)
		var down: Array = road.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == id)
		var up: Array = m.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == str(PLACES[id]))
		assert_eq(down.size(), 1, "%s has stairs down" % PLACES[id])
		assert_eq(up.size(), 1, "%s has stairs up" % id)
		assert_eq(m.secrets.size(), 4, id)
		var wayfarers: int = 0
		for n: Dictionary in m.npcs:
			if n.has("trainer") and not str(n.id).begins_with("q2_"):
				wayfarers += 1
		assert_eq(wayfarers, 3, id)

func test_wayfarers_follow_their_road() -> void:
	for id: String in _maps:
		var road_id: String = str(PLACES.get(id, id))
		if Region2.route(road_id).is_empty():
			continue
		var ring: Array = Region2.route(road_id).ring
		var on_road: int = 0
		for n: Dictionary in (_maps[id] as MapData).npcs:
			if not n.has("trainer") or str(n.id).begins_with("q2_"):
				continue
			on_road += 1
			for e: Dictionary in n.team:
				assert_between(int(e.level), int(ring[0]), int(ring[1]), "%s on %s" % [n.id, id])
			assert_lte(_elements(n.team), 3, str(n.id))
		if not PLACES.has(id):
			assert_gte(on_road, 2, "%s has a second Wayfarer" % id)

func test_nobody_stands_in_the_way() -> void:
	for id: String in _maps:
		var m: MapData = _maps[id]
		var cells: Dictionary = {}
		for n: Dictionary in m.npcs:
			var c: Vector2i = Vector2i(int(n.x), int(n.y))
			assert_false(cells.has(c), "%s: two figures at %s" % [id, c])
			cells[c] = true
		for w: Dictionary in m.warps:
			assert_false(cells.has(Vector2i(int(w.x), int(w.y))), "%s: a figure on a way out" % id)

func test_goals_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for g: Dictionary in _goals:
		for st: Dictionary in g.stages:
			assert_true(de.has(str(st.text)), "DE missing: %s" % st.text)
		for row: Array in _of(g):
			var n: Dictionary = row[1]
			for k: String in ["dialogue", "intro", "defeat"]:
				if not n.has(k):
					continue
				for e: Dictionary in _entries(str(n[k])):
					for s: Variant in e.get("lines", []):
						assert_true(de.has(str(s)), "DE missing: %s" % s)
					for c: Dictionary in e.get("choices", []):
						assert_true(de.has(str(c.text)), "DE missing: %s" % c.text)
