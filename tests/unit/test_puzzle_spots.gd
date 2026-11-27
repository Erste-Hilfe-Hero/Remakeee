extends GutTest
## Riddle stones and puzzle boards of data/puzzle_spots.json (PuzzleSpots, PuzzleBoard, 1.3.2):
## every puzzle can be solved, typed answers match in every language, rewards come once, and
## every stone stands where the player can reach it. docs/PUZZLES.md lists the solutions.

const LANGS: Array[String] = ["en", "de", "fr", "es", "it", "pt_BR", "nl", "pl", "tr", "ru", "ja", "ko", "zh_CN", "zh_TW"]

var _lang: String = "en"
var _flags: Dictionary = {}
var _records: Dictionary = {}
var _inventory: Dictionary = {}
var _new_items: Dictionary = {}
var _money: int = 0

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_lang = Loc.language()
	_flags = GameState.flags.duplicate(true)
	_records = GameState.records.duplicate(true)
	_inventory = GameState.inventory.duplicate(true)
	_new_items = GameState.new_items.duplicate(true)
	_money = GameState.money

func after_each() -> void:
	Loc.set_language(_lang)
	GameState.flags = _flags
	GameState.records = _records
	GameState.inventory = _inventory
	GameState.new_items = _new_items
	GameState.money = _money

func _of_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in PuzzleSpots.all():
		if str(s.kind) == kind:
			out.append(s)
	return out

# --- The set as a whole --------------------------------------------------------------------

func test_about_thirty_puzzles_in_every_region_and_every_kind() -> void:
	var spots: Array[Dictionary] = PuzzleSpots.all()
	assert_gte(spots.size(), 30)
	var ids: Dictionary = {}
	var regions: Dictionary = {}
	var kinds: Dictionary = {}
	for s: Dictionary in spots:
		assert_false(ids.has(s.id), "unique id %s" % s.id)
		ids[s.id] = true
		assert_true(str(s.kind) in PuzzleSpots.KINDS, "%s: known kind" % s.id)
		assert_true(str(s.region) in PuzzleSpots.REGIONS, "%s: known region" % s.id)
		assert_true(str(s.get("at", "tablet")) in ["tablet", "npc"], "%s: tablet or riddler" % s.id)
		for k: String in ["title", "text", "hint_1", "hint_2"]:
			assert_false(str(s.get(k, "")).is_empty(), "%s: has %s" % [s.id, k])
		regions[s.region] = int(regions.get(s.region, 0)) + 1
		kinds[s.kind] = true
	for r: String in PuzzleSpots.REGIONS:
		assert_gte(int(regions.get(r, 0)), 3, "region %s has puzzles" % r)
	for k: String in PuzzleSpots.KINDS:
		assert_true(kinds.has(k), "kind %s is used" % k)

# --- Every puzzle is solvable --------------------------------------------------------------

func test_pick_riddles_have_one_right_answer() -> void:
	for s: Dictionary in _of_kind("pick"):
		var opts: Array = s.options
		assert_between(opts.size(), 2, 4, "%s: 2 to 4 answers (fits the screen)" % s.id)
		assert_true(PuzzleSpots.pick_ok(s, int(s.correct)), "%s: the right answer is accepted" % s.id)
		for i: int in opts.size():
			if i != int(s.correct):
				assert_false(PuzzleSpots.pick_ok(s, i), "%s: %s is wrong" % [s.id, opts[i]])
		var order: Array[int] = PuzzleSpots.option_order(s)
		var sorted: Array[int] = order.duplicate()
		sorted.sort()
		assert_eq(sorted, range(opts.size()) as Array[int], "%s: the shown order lists every answer once" % s.id)
		assert_eq(PuzzleSpots.option_order(s), order, "%s: the same order every time" % s.id)

func test_right_pick_is_not_always_on_top() -> void:
	var top: int = 0
	var picks: Array[Dictionary] = _of_kind("pick")
	for s: Dictionary in picks:
		if PuzzleSpots.option_order(s)[0] == int(s.correct):
			top += 1
	assert_lt(top, picks.size(), "the shuffle moves the right answer")

func test_order_and_listen_sequences_can_be_pressed() -> void:
	var list: Array[Dictionary] = _of_kind("order")
	list.append_array(_of_kind("listen"))
	for s: Dictionary in list:
		var buttons: Array = s.buttons
		var seq: Array[int] = PuzzleSpots.sequence(s)
		assert_between(buttons.size(), 3, 5, "%s: 3 to 5 buttons" % s.id)
		assert_gte(seq.size(), buttons.size(), "%s: every button can matter" % s.id)
		for b: Variant in buttons:
			assert_true(PuzzleSpots.COLORS.has(str(b)), "%s: colour %s" % [s.id, b])
		var done: int = 0
		for b: int in seq:
			assert_between(b, 0, buttons.size() - 1, "%s: button index" % s.id)
			var wrong: int = (b + 1) % buttons.size()
			assert_eq(PuzzleSpots.press(s, done, wrong), -1, "%s: a wrong button resets" % s.id)
			done = PuzzleSpots.press(s, done, b)
		assert_eq(done, seq.size(), "%s: the solution reaches the end" % s.id)
		assert_eq(PuzzleSpots.press(s, done, seq[0]), -1, "%s: nothing after the end" % s.id)
	for s: Dictionary in _of_kind("listen"):
		assert_lte((s.buttons as Array).size(), PuzzleSpots.PITCHES.size(), "%s: one note per chime" % s.id)

func test_lights_boards_are_solved_by_their_solution() -> void:
	for s: Dictionary in _of_kind("lights"):
		var n: int = PuzzleSpots.lights_size(s)
		assert_between(n, 3, 4, "%s: 3x3 or 4x4" % s.id)
		var g: Array[bool] = PuzzleSpots.lights_start(s)
		assert_eq(g.size(), n * n, "%s: square grid" % s.id)
		assert_false(PuzzleSpots.lights_done(g), "%s: not solved at the start" % s.id)
		for t: Variant in s.solution:
			PuzzleSpots.lights_tap(g, n, Vector2i(int(t[0]), int(t[1])))
		assert_true(PuzzleSpots.lights_done(g), "%s: the stored taps light every lamp" % s.id)
		assert_not_null(PuzzleSpots.lights_solve(s), "%s: the solver finds a way too" % s.id)

func test_slide_boards_come_back_to_one_to_eight() -> void:
	for s: Dictionary in _of_kind("slide"):
		var t: Array[int] = PuzzleSpots.slide_start(s)
		assert_ne(t, PuzzleSpots.slide_solved(), "%s: mixed up at the start" % s.id)
		for mv: String in PuzzleSpots.slide_solution(s):
			assert_true(PuzzleSpots.slide_gap(t, PuzzleSpots.SLIDE_DIRS[mv]), "%s: legal move %s" % [s.id, mv])
		assert_eq(t, PuzzleSpots.slide_solved(), "%s: solved" % s.id)

func test_slide_taps_only_move_neighbours_of_the_gap() -> void:
	var t: Array[int] = PuzzleSpots.slide_solved()
	assert_false(PuzzleSpots.slide_tap(t, Vector2i(0, 0)), "far tile")
	assert_true(PuzzleSpots.slide_tap(t, Vector2i(2, 1)), "tile above the gap")
	assert_eq(t, [1, 2, 3, 4, 5, 0, 7, 8, 6] as Array[int])

func test_push_boards_are_solvable_and_the_stored_moves_work() -> void:
	for s: Dictionary in _of_kind("push"):
		var m: MapData = PuzzleSpots.push_map(s)
		var start: Vector2i = PuzzleSpots.push_start(s)
		assert_true(m.is_walkable(start), "%s: start on floor" % s.id)
		assert_eq(PuzzleRoom.boulders(m).size(), PuzzleRoom.plates(m, m.puzzles[0]).size(), "%s: one block per mark" % s.id)
		assert_false(PuzzleSpots.push_done(m), "%s: not solved at the start" % s.id)
		assert_not_null(PuzzleSolver.solve(m, m.puzzles[0], start, []), "%s: the solver finds a way" % s.id)
		var end: Dictionary = PuzzleSolver.replay(m, start, s.solution, [])
		assert_true(PuzzleSpots.push_done(end.map), "%s: the stored moves cover every mark" % s.id)

func test_steps_trails_lead_from_start_to_end() -> void:
	for s: Dictionary in _of_kind("steps"):
		assert_ne(PuzzleSpots.step_find(s, "S"), Vector2i(-1, -1), "%s: has a start" % s.id)
		assert_ne(PuzzleSpots.step_find(s, "E"), Vector2i(-1, -1), "%s: has an end" % s.id)
		assert_true(str(s.ground) in ["mud", "sand"], "%s: ground" % s.id)
		var path: Variant = PuzzleSpots.steps_solve(s)
		assert_not_null(path, "%s: the trail reaches the end" % s.id)
		var c: Vector2i = PuzzleSpots.step_find(s, "S")
		for mv: Variant in path:
			c += PuzzleSpots.SLIDE_DIRS[str(mv)]
		assert_eq(PuzzleSpots.step_kind(s, c), "end", "%s: the path ends on E" % s.id)
		var decoys: bool = false
		for row: Variant in s.grid:
			decoys = decoys or str(row).contains("x")
		assert_true(decoys, "%s: has decoy tracks" % s.id)

func test_step_kinds() -> void:
	var s: Dictionary = {"grid": ["Sx", ".E"]}
	assert_eq(PuzzleSpots.step_kind(s, Vector2i(0, 0)), "ok")
	assert_eq(PuzzleSpots.step_kind(s, Vector2i(1, 0)), "decoy")
	assert_eq(PuzzleSpots.step_kind(s, Vector2i(0, 1)), "lost")
	assert_eq(PuzzleSpots.step_kind(s, Vector2i(1, 1)), "end")
	assert_eq(PuzzleSpots.step_kind(s, Vector2i(2, 0)), "edge")
	assert_null(PuzzleSpots.steps_solve(s), "no right tracks to E")

# --- Typed answers in every language -------------------------------------------------------

func test_normalize_folds_case_accents_articles_and_kana() -> void:
	assert_eq(PuzzleSpots.normalize("  The Lighthouse! "), "lighthouse")
	assert_eq(PuzzleSpots.normalize("L'Étoile"), "etoile")
	assert_eq(PuzzleSpots.normalize("Ein Leuchtturm"), "leuchtturm")
	assert_eq(PuzzleSpots.normalize("Leuchttürme"), "leuchtturme")
	assert_eq(PuzzleSpots.normalize("ＳＴＡＲ"), "star")
	assert_eq(PuzzleSpots.normalize("ガラス"), "がらす")
	assert_eq(PuzzleSpots.normalize("light-house"), "lighthouse")
	assert_eq(PuzzleSpots.normalize("Ёлка"), PuzzleSpots.normalize("елка"))
	assert_eq(PuzzleSpots.normalize("A"), "a", "a lone article stays")

func test_typed_answers_match_in_every_language() -> void:
	for s: Dictionary in _of_kind("type"):
		var ans: Dictionary = s.answers
		var opts: Array = s.options
		assert_eq(int(s.correct), 0, "%s: options[0] is the answer" % s.id)
		for lang: String in LANGS:
			assert_false((ans.get(lang, []) as Array).is_empty(), "%s: answers in %s" % [s.id, lang])
			Loc.set_language(lang)
			for a: Variant in ans.get(lang, []):
				assert_true(PuzzleSpots.answer_ok(s, str(a), lang), "%s/%s: %s" % [s.id, lang, a])
				assert_true(PuzzleSpots.answer_ok(s, "  " + str(a).to_upper() + "!", lang), "%s/%s: loud %s" % [s.id, lang, a])
			for a: Variant in ans.en:
				assert_true(PuzzleSpots.answer_ok(s, str(a), lang), "%s/%s: English %s works too" % [s.id, lang, a])
			var right: String = Loc.t(str(opts[0]))
			assert_true(PuzzleSpots.answer_ok(s, right, lang), "%s/%s: the shown answer %s" % [s.id, lang, right])
			var own: Array[String] = []
			for a: Variant in ans.get(lang, []):
				own.append(PuzzleSpots.normalize(str(a)))
			assert_true(PuzzleSpots.normalize(right) in own, "%s/%s: the translated answer %s is in the list" % [s.id, lang, right])
			for i: int in range(1, opts.size()):
				var wrong: String = Loc.t(str(opts[i]))
				assert_false(PuzzleSpots.answer_ok(s, wrong, lang), "%s/%s: %s is wrong" % [s.id, lang, wrong])
			assert_false(PuzzleSpots.answer_ok(s, "", lang), "%s/%s: empty" % [s.id, lang])
			assert_false(PuzzleSpots.answer_ok(s, "???", lang), "%s/%s: punctuation only" % [s.id, lang])

func test_pick_answers_stay_distinct_in_every_language() -> void:
	var list: Array[Dictionary] = _of_kind("pick")
	list.append_array(_of_kind("type"))
	for lang: String in LANGS:
		Loc.set_language(lang)
		for s: Dictionary in list:
			var seen: Dictionary = {}
			for o: Variant in s.options:
				var n: String = PuzzleSpots.normalize(Loc.t(str(o)))
				assert_false(seen.has(n), "%s/%s: %s differs from the other answers" % [s.id, lang, o])
				seen[n] = true

func test_every_text_is_translated() -> void:
	var keys: Array[String] = []
	for s: Dictionary in PuzzleSpots.all():
		for k: String in ["title", "text", "hint_1", "hint_2", "clue"]:
			if s.has(k):
				keys.append(str(s[k]))
		for o: Variant in s.get("options", []):
			keys.append(str(o))
		for r: Dictionary in PuzzleSpots.rewards(s):
			if r.has("look"):
				var c: Dictionary = LanternColors.by_id(str(r.look))
				keys.append(str(c.name))
				keys.append(str(c.hint))
	for b: String in PuzzleSpots.COLOR_NAMES.values():
		keys.append(b)
	for lang: String in LANGS:
		if lang == "en":
			continue
		var table: Dictionary = Loc.load_table(lang).get("strings", {})
		for k: String in keys:
			assert_true(table.has(k) and not str(table[k]).is_empty(), "%s: %s" % [lang, k])

# --- Hints and chains ----------------------------------------------------------------------

func test_hints_come_after_wrong_tries() -> void:
	var s: Dictionary = PuzzleSpots.by_id("cor_rain")
	GameState.records = {}
	assert_eq(PuzzleSpots.hints(s, PuzzleSpots.tries("cor_rain")).size(), 0)
	for i: int in PuzzleSpots.HINT_1_AFTER:
		PuzzleSpots.add_try("cor_rain")
	assert_eq(PuzzleSpots.hints(s, PuzzleSpots.tries("cor_rain")), [str(s.hint_1)] as Array[String])
	for i: int in PuzzleSpots.HINT_2_AFTER - PuzzleSpots.HINT_1_AFTER:
		PuzzleSpots.add_try("cor_rain")
	assert_eq(PuzzleSpots.hints(s, PuzzleSpots.tries("cor_rain")).size(), 2)
	assert_lt(PuzzleSpots.HINT_2_AFTER, PuzzleSpots.TYPE_CHOICES_AFTER + 1, "both hints before the pick list")

func test_chains_open_when_every_part_is_solved() -> void:
	var finals: int = 0
	for s: Dictionary in PuzzleSpots.all():
		if not s.has("needs"):
			continue
		finals += 1
		var flags: Dictionary = {}
		assert_false(PuzzleSpots.open(s, flags), "%s: closed at first" % s.id)
		var maps: Dictionary = {}
		for id: String in PuzzleSpots.needs(s):
			var part: Dictionary = PuzzleSpots.by_id(id)
			assert_false(part.is_empty(), "%s: part %s exists" % [s.id, id])
			assert_true(part.has("clue"), "%s: part %s gives a clue" % [s.id, id])
			maps[part.map] = true
			flags[PuzzleSpots.flag(id)] = true
		assert_true(PuzzleSpots.open(s, flags), "%s: open with every part" % s.id)
		assert_eq(PuzzleSpots.clues_for(s, flags).size(), PuzzleSpots.needs(s).size(), "%s: every clue shown" % s.id)
		assert_gte(maps.size(), 2, "%s: clues spread over several maps" % s.id)
		assert_false(maps.has(s.map), "%s: the last stone stands on its own map" % s.id)
	assert_gte(finals, 3, "a few riddle chains")

# --- Rewards -------------------------------------------------------------------------------

func test_rewards_exist_and_are_never_riftglass() -> void:
	for s: Dictionary in PuzzleSpots.all():
		var rw: Array[Dictionary] = PuzzleSpots.rewards(s)
		assert_false(rw.is_empty(), "%s: has a reward" % s.id)
		for r: Dictionary in rw:
			assert_true(r.has("item") or r.has("coins") or r.has("look") or r.has("meet"), "%s: known reward" % s.id)
			if r.has("item"):
				assert_false(Database.item(str(r.item)).is_empty(), "%s: item %s exists" % [s.id, r.item])
				assert_false(str(r.item).begins_with("rg_"), "%s: no shop item" % s.id)
			if r.has("coins"):
				assert_between(int(r.coins), 100, 1000, "%s: coins" % s.id)
			if r.has("look"):
				var c: Dictionary = LanternColors.by_id(str(r.look))
				assert_eq(str(c.get("id", "")), str(r.look), "%s: flame %s exists" % [s.id, r.look])
				assert_eq(str((c.get("unlock", {}) as Dictionary).get("flag", "")), PuzzleSpots.flag(str(s.id)), "%s: flame opens with the stone" % s.id)
			for k: Variant in r:
				assert_false(str(k).contains("riftglass") or str(r[k]).to_lower().contains("riftglass"), "%s: never Riftglass" % s.id)

func test_rewards_are_granted_only_once() -> void:
	for s: Dictionary in PuzzleSpots.all():
		var id: String = str(s.id)
		GameState.flags.erase(PuzzleSpots.flag(id))
		var money: int = GameState.money
		var counts: Dictionary = {}
		for r: Dictionary in PuzzleSpots.rewards(s):
			if r.has("item"):
				counts[r.item] = GameState.item_count(str(r.item))
		var lines: Array[String] = PuzzleSpots.solve(id)
		assert_eq(lines.size(), PuzzleSpots.rewards(s).size(), "%s: one line per reward" % id)
		assert_true(PuzzleSpots.solved(id), "%s: solved" % id)
		var gained: int = 0
		for r: Dictionary in PuzzleSpots.rewards(s):
			if r.has("coins"):
				gained += int(r.coins)
			if r.has("item"):
				assert_eq(GameState.item_count(str(r.item)), int(counts[r.item]) + int(r.get("count", 1)), "%s: got %s" % [id, r.item])
		assert_eq(GameState.money, money + gained, "%s: coins" % id)
		var money2: int = GameState.money
		var counts2: Dictionary = GameState.inventory.duplicate()
		assert_eq(PuzzleSpots.solve(id), [] as Array[String], "%s: nothing the second time" % id)
		assert_eq(GameState.money, money2, "%s: no coins twice" % id)
		assert_eq(GameState.inventory, counts2, "%s: no items twice" % id)

func test_looks_unlock_with_the_stone() -> void:
	GameState.flags.erase("pz_hal_orrery")
	var before: int = LanternColors.unlocked().size()
	PuzzleSpots.solve("hal_orrery")
	assert_eq(LanternColors.unlocked().size(), before + 1, "the star silver flame is lit")

func test_rare_visitors_need_the_stone_and_a_wild_table() -> void:
	var rng := RandomNumberGenerator.new()
	for s: Dictionary in PuzzleSpots.all():
		for r: Dictionary in PuzzleSpots.rewards(s):
			if not r.has("meet"):
				continue
			var map_id: String = PuzzleSpots.meet_map(s, r)
			assert_not_null(Database.species(str(r.meet)), "%s: species %s" % [s.id, r.meet])
			assert_between(int(r.ring), 2, 100, "%s: ring" % s.id)
			var m: MapData = MapData.load_map(map_id)
			assert_not_null(m, "%s: map %s" % [s.id, map_id])
			if m == null:
				continue
			assert_false(m.encounter_table.is_empty(), "%s: %s has wild Spirlings" % [s.id, map_id])
			var grass: bool = false
			for y: int in m.height:
				for x: int in m.rows[y].length():
					grass = grass or m.kind_at(Vector2i(x, y)) in TilesetFactory.ENCOUNTER_KINDS
			assert_true(grass, "%s: %s has grass or reeds" % [s.id, map_id])
			assert_eq(PuzzleSpots.meets_on(map_id, {}).size(), 0, "%s: locked before the stone" % s.id)
			var flags: Dictionary = {PuzzleSpots.flag(str(s.id)): true}
			assert_eq(PuzzleSpots.meets_on(map_id, flags).size(), 1, "%s: unlocked by the stone" % s.id)
			var hits: int = 0
			rng.seed = 7
			for i: int in 400:
				var w: Spirling = PuzzleSpots.rare_wild(map_id, flags, rng)
				if w != null:
					hits += 1
					assert_eq(w.level, int(r.ring), "%s: ring" % s.id)
			assert_between(hits, 10, 80, "%s: about one in ten" % s.id)
			assert_null(PuzzleSpots.rare_wild(map_id, {}, rng), "%s: never without the stone" % s.id)

# --- Placement -----------------------------------------------------------------------------

## Cells reachable on foot from the map's warps, not entering [param blocked].
func _reach(m: MapData, blocked: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var q: Array[Vector2i] = []
	for w: Dictionary in m.warps:
		var c := Vector2i(int(w.x), int(w.y))
		if not seen.has(c):
			seen[c] = true
			q.append(c)
	var h: int = 0
	while h < q.size():
		var c: Vector2i = q[h]
		h += 1
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not seen.has(n) and m.is_walkable(n) and not blocked.has(n):
				seen[n] = true
				q.append(n)
	return seen

func test_every_spot_stands_where_it_can_be_reached() -> void:
	for s: Dictionary in PuzzleSpots.all():
		var m: MapData = MapData.load_map(str(s.map))
		assert_not_null(m, "%s: map %s exists" % [s.id, s.map])
		if m == null:
			continue
		assert_eq(m.region, str(s.region), "%s: %s lies in %s" % [s.id, s.map, s.region])
		var cell: Vector2i = PuzzleSpots.cell_of(s)
		assert_true(m.in_bounds(cell), "%s: inside the map" % s.id)
		assert_true(m.warp_at(cell).is_empty(), "%s: not on a warp" % s.id)
		assert_true(m.sign_at(cell).is_empty(), "%s: not on a sign" % s.id)
		var blocked: Dictionary = {}
		for n: Dictionary in m.npcs:
			var nc := Vector2i(int(n.get("x", -1)), int(n.get("y", -1)))
			assert_ne(nc, cell, "%s: not on NPC %s" % [s.id, n.get("id", "")])
			blocked[nc] = true
		for other: Dictionary in PuzzleSpots.on_map(str(s.map)):
			if other.id != s.id:
				assert_ne(PuzzleSpots.cell_of(other), cell, "%s: own cell" % s.id)
				blocked[PuzzleSpots.cell_of(other)] = true
		var reach: Dictionary = _reach(m, blocked)
		var touch: bool = false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			touch = touch or (reach.has(cell + d) and m.is_walkable(cell + d))
		assert_true(touch, "%s: a reachable cell next to %s on %s" % [s.id, cell, s.map])
		if m.is_walkable(cell):
			# A riddler or stone on a floor cell must not cut the map in two.
			var with_spot: Dictionary = blocked.duplicate()
			with_spot[cell] = true
			var after: Dictionary = _reach(m, with_spot)
			var lost: Array[Vector2i] = []
			for c: Vector2i in reach:
				if c != cell and not after.has(c):
					lost.append(c)
			assert_eq(lost.size(), 0, "%s: blocks no path on %s" % [s.id, s.map])

func test_npc_defs_mark_tablets_and_riddlers() -> void:
	var s: Dictionary = PuzzleSpots.by_id("ash_station")
	var defs: Array[Dictionary] = PuzzleSpots.npc_defs(str(s.map))
	var found: Dictionary = {}
	for d: Dictionary in defs:
		if d.puzzle == "ash_station":
			found = d
	assert_false(found.is_empty())
	assert_false(bool(found.tablet), "a riddler is a person")
	assert_eq(PuzzleSpots.at(str(s.map), PuzzleSpots.cell_of(s)).get("id"), "ash_station")
	assert_true(PuzzleSpots.at(str(s.map), Vector2i(-5, -5)).is_empty())
