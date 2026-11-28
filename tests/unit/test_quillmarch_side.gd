extends GutTest
## Quillmarch side content (tools/art/world/quillmarch_side.py): eight side goals (data/quests.json
## q3_*) that each end in a betrayal, three of them with a trust choice; three landmark halls with a
## story duel each; one more Wayfarer per road; towns that differ from each other.

const HALLS: Dictionary = {"dead_letter_office": "drypoint_lane", "errata_chapel": "gravers_causeway", "debtors_icehouse": "rimeglass_pass"}
const GOAL_COUNT: int = 8
const CHOICE_GOALS: int = 3
const MIN_HOUSES: int = 3

var _goals: Array = []
var _npcs: Dictionary = {}   # npc id -> [map id, npc]
var _d: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_d = Region3.data()
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for g: Dictionary in q.side:
		if str(g.id).begins_with("q3_"):
			_goals.append(g)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.region != "quillmarch":
			continue
		for n: Dictionary in m.npcs:
			if str(n.get("id", "")).begins_with("q3_"):
				_npcs[str(n.id)] = [id, n]

func _wild_top() -> int:
	var top: int = 0
	for r: Dictionary in _d.routes:
		top = maxi(top, int(r.ring[1]))
	return top

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

func _actions(ref: String) -> String:
	var out: String = ""
	for e: Dictionary in _entries(ref):
		out += str(e.get("action", "")) + ";"
		for c: Dictionary in e.get("choices", []):
			out += str(c.get("action", "")) + ";"
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

func test_eight_goals_in_quillmarch() -> void:
	assert_eq(_goals.size(), GOAL_COUNT)
	var places: Array[String] = []
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m.region == "quillmarch":
			places.append(m.display_name)
	for g: Dictionary in _goals:
		assert_eq((g.progress as Array).size(), 4, str(g.id))
		assert_eq((g.stages as Array).size(), 5, str(g.id))
		assert_eq(str(g.progress[3]), str(g.done), "beating the betrayer is the last step")
		for st: Dictionary in g.stages:
			assert_has(places, str(st.where), "%s: %s is a Quillmarch place" % [g.id, st.where])

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
		for n: int in range(1, 5):
			assert_true(acts.contains("quest_stage %s %d" % [g.id, n]), "%s reaches stage %d" % [g.id, n])

func test_betrayers_end_their_goal() -> void:
	var top: int = _wild_top()
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
			for e: Dictionary in n.team:
				assert_lte(int(e.level), top + 2, str(n.id))
				assert_eq(Database.species(str(e.species)).region, "quillmarch", "%s is a Quillmarch kind" % e.species)
			assert_lte(_elements(n.team), 3, str(n.id))
			for k: String in ["dialogue", "intro", "defeat"]:
				assert_true(Dialogue.exists(str(n[k])), "%s %s" % [n.id, k])
		assert_eq(found, 1, "%s has one betrayer" % g.id)

func test_trust_choices_have_consequences() -> void:
	var with_choice: int = 0
	for g: Dictionary in _goals:
		var answers: Array = []
		for row: Array in _of(g):
			for e: Dictionary in _entries(str((row[1] as Dictionary).dialogue)):
				if not (e.get("choices", []) as Array).is_empty():
					answers = e.choices
		if answers.is_empty():
			continue
		with_choice += 1
		assert_eq(answers.size(), 2, str(g.id))
		var rewards: Dictionary = {}
		for c: Dictionary in answers:
			var chose: String = str(c.flag)
			assert_true(chose.begins_with(str(g.id) + "_"), chose)
			assert_true(str(c.action).contains("give_item"), "%s pays" % chose)
			assert_true(str(c.action).contains("quest_stage %s 4" % g.id), "%s closes the goal" % chose)
			rewards[str(c.action)] = true
			var witness: bool = false
			for row: Array in _of(g):
				witness = witness or str((row[1] as Dictionary).get("show_flag", "")) == chose
			assert_true(witness, "%s: someone turns up for it" % chose)
		assert_eq(rewards.size(), 2, "%s: the answers pay differently" % g.id)
	assert_eq(with_choice, CHOICE_GOALS)

func test_landmark_halls_and_their_duels() -> void:
	var places: Dictionary = WorldValidator.load_layout().maps
	for hall: String in HALLS:
		var road: String = HALLS[hall]
		assert_true(MapData.exists(hall), hall)
		var m: MapData = MapData.load_map(hall)
		assert_eq(m.region, "quillmarch", hall)
		assert_false(m.outdoor, hall)
		assert_eq(str((places.get(hall, {}) as Dictionary).get("inside", "")), road, hall)
		assert_gt(m.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == road).size(), 0, "%s leads back out" % hall)
		assert_gt(MapData.load_map(road).warps.filter(func(w: Dictionary) -> bool: return str(w.to) == hall).size(), 0, "%s has the door" % road)
		assert_eq(m.secrets.size(), 2, hall)
		var id: String = "q3_" + hall
		assert_true(StoryBattles.has(id), id)
		var def: Dictionary = StoryBattles.get_def(id)
		assert_lte(_elements(def.team), 3, id)
		for e: Dictionary in def.team:
			assert_lte(int(e.level), int(Region3.route(road).ring[1]) + 1, id)
		for k: String in ["defeat", "lose"]:
			assert_true(Dialogue.exists(str(def[k])), "%s %s" % [id, k])
		assert_true(_npcs.has(id), id)
		var acts: String = _actions(str((_npcs[id][1] as Dictionary).dialogue))
		assert_true(acts.contains("battle " + id), "%s starts the duel" % id)
		assert_true(acts.contains("give_item"), "%s pays once" % id)

func test_one_more_wayfarer_on_every_road() -> void:
	for r: Dictionary in _d.routes:
		var m: MapData = MapData.load_map(str(r.id))
		var extra: Array = m.npcs.filter(func(n: Dictionary) -> bool:
			return n.has("trainer") and str(n.id).begins_with("q3_") and not n.has("show_flag"))
		assert_eq(extra.size(), 1, str(r.id))
		var species: Array[String] = EncounterTable.species_on(str(r.id))
		for e: Dictionary in extra[0].team:
			assert_between(int(e.level), int(r.ring[0]), int(r.ring[1]), "%s is within the road's ring" % extra[0].id)
			assert_has(species, str(e.species), str(extra[0].id))
		assert_lte(_elements(extra[0].team), 3, str(extra[0].id))
		assert_eq(m.secrets.size(), 5, "%s has five finds" % r.id)

func test_towns_differ_and_have_houses_to_enter() -> void:
	var looks: Dictionary = {}
	for t: Dictionary in _d.towns:
		var m: MapData = MapData.load_map(str(t.id))
		# The middle of the town without its frame (the frame differs by the gates alone).
		var core: String = ""
		for y: int in range(1, m.rows.size() - 1):
			core += str(m.rows[y]).substr(1, str(m.rows[y]).length() - 2).replace("_", ".")
		assert_false(looks.has(core), "%s looks like %s" % [t.id, looks.get(core, "")])
		looks[core] = str(t.id)
		var rooms: Dictionary = {}
		for w: Dictionary in m.warps:
			if str(w.to).begins_with(str(t.id) + "_"):
				rooms[str(w.to)] = true
		assert_gte(rooms.size(), MIN_HOUSES, str(t.id))

func test_side_content_has_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for g: Dictionary in _goals:
		assert_true(de.has(str(g.text)), str(g.id))
		for st: Dictionary in g.stages:
			assert_true(de.has(str(st.text)), "DE missing: %s" % st.text)
	for id: String in _npcs:
		var n: Dictionary = _npcs[id][1]
		if n.has("trainer"):
			assert_true(de.has(str(n.trainer)), "DE missing: %s" % n.trainer)
		for k: String in ["dialogue", "intro", "defeat"]:
			if not n.has(k):
				continue
			for e: Dictionary in _entries(str(n[k])):
				for s: Variant in e.get("lines", []):
					assert_true(de.has(str(s)), "DE missing: %s" % s)
				for c: Dictionary in e.get("choices", []):
					assert_true(de.has(str(c.text)), "DE missing: %s" % c.text)
	for hall: String in HALLS:
		assert_true(de.has(MapData.load_map(hall).display_name), hall)
		assert_true(de.has(str(StoryBattles.get_def("q3_" + hall).trainer)), hall)
