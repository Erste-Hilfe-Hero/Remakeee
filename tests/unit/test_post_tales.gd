extends GutTest
## The four region tales after the story (docs/STORY.md "Region tales",
## tools/art/world/post_tales.py): 5-6 main goals each in data/quests.json "post", figures on the
## region maps, a closing moment on the region's done flag, real duels (Quivermoor: six lantern
## walkers and a final duel in the Era V band), every chain completable from data alone.

const REGIONS: Array[String] = ["vellmarch", "quillmarch", "halcyra", "quivermoor"]
const SHEETS: Dictionary = {"vellmarch": "res://data/region2.json", "quillmarch": "res://data/region3.json",
	"halcyra": "res://data/region4.json", "quivermoor": "res://data/region5.json"}
## The flag that ends each region's chapters (the closing moment waits for it).
const DONE: Dictionary = {"vellmarch": "vellmarch_done", "quillmarch": "quillmarch_done",
	"halcyra": "halcyra_done", "quivermoor": "quivermoor_done"}
## Duel rings per region: the region's Warden band (Era V: wild Ring 92 to 99).
const BAND: Dictionary = {"vellmarch": [52, 60], "quillmarch": [70, 88], "halcyra": [83, 96], "quivermoor": [92, 99]}
const SEEDS: int = 6

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _sheet(region: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(SHEETS[region])))
	return raw if raw is Dictionary else {}

## The region's story flags in play order: each chapter's Rift seal, then the chapter flag.
func _story_flags(region: String) -> Array[String]:
	var seal: Dictionary = {}
	for r: Dictionary in _sheet(region).get("rifts", []):
		seal[str(r.id)] = str(r.flag)
	var out: Array[String] = []
	for c: Dictionary in _sheet(region).get("story", []):
		if seal.has(str(c.get("rift", ""))):
			out.append(str(seal[c.rift]))
		out.append(str(c.sets))
	return out

## Every tale figure of [param region]: {map, npc}.
func _figures(region: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mid: Variant in StoryPlacements.data():
		for n: Variant in StoryPlacements.for_map(str(mid)).get("npcs", []):
			if n is Dictionary and str(n.id).begins_with("tale_") and str(n.dialogue).begins_with(region + "_tale/"):
				out.append({"map": str(mid), "npc": n})
	return out

## The entry a talk plays, following "if"/"else" like Overworld.play_entry.
func _resolve(ref: String, flags: Dictionary) -> String:
	for i: int in 10:
		var e: Dictionary = Dialogue.get_entry(ref)
		if e.has("if") and not Dialogue.check(e.get("if"), flags):
			ref = Dialogue.resolve_ref(ref, str(e.get("else", "")))
			continue
		return ref
	return ref

func _tale_duels(region: String) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in StoryBattles.data():
		if str(id).begins_with("tale_") and StoryBattles.has(str(id)):
			for f: Dictionary in _figures(region):
				if _mentions_battle(str(f.npc.dialogue), str(id)):
					out.append(str(id))
					break
	return out

func _mentions_battle(ref: String, id: String) -> bool:
	var file: Dictionary = Dialogue.file_data(ref.get_slice("/", 0))
	for v: Variant in file.values():
		if v is Dictionary and str((v as Dictionary).get("action", "")) == "battle " + id:
			return true
	return false

## Talks to every visible figure until nothing changes; mends the region's Rifts one by one
## when the tale waits for them. Returns the goal ids in the order they came up.
func _play(region: String) -> Array:
	var flags: Dictionary = {str(QuestLog.tale_goals(region)[0].opens): true}
	var story: Array[String] = _story_flags(region)
	var seen: Array = []
	for step: int in 200:
		var g: Dictionary = QuestLog.tale_goal(region, flags)
		if g.is_empty():
			break
		if seen.is_empty() or seen[-1] != g.id:
			seen.append(g.id)
		var moved: bool = false
		for f: Dictionary in _figures(region):
			var n: Dictionary = f.npc
			if not bool(flags.get(str(n.show_flag), false)) or bool(flags.get(str(n.get("hide_flag", "-")), false)):
				continue
			var action: String = str(Dialogue.get_entry(_resolve(str(n.dialogue), flags)).get("action", ""))
			var parts: PackedStringArray = action.split(" ")
			if parts.size() == 2 and parts[0] == "set_flag" and not flags.has(parts[1]):
				flags[parts[1]] = true
				moved = true
			elif parts.size() == 2 and parts[0] == "battle":
				for wf: Variant in StoryBattles.get_def(parts[1]).get("win_flags", []):
					moved = moved or not flags.has(str(wf))
					flags[str(wf)] = true
			if moved:
				break
		if not moved:
			assert_false(story.is_empty(), "%s is stuck at %s" % [region, g.id])
			if story.is_empty():
				break
			flags[story.pop_front()] = true
	assert_true(QuestLog.tale_done(region, flags), region + " tale can be finished")
	assert_true(bool(flags.get(str(DONE[region]), false)), region + ": the closing moment waits for the region's end")
	return seen

func test_each_region_has_its_own_tale_of_five_or_six_goals() -> void:
	assert_eq(QuestLog.tale_regions(), REGIONS)
	for r: String in REGIONS:
		var goals: Array = QuestLog.tale_goals(r)
		assert_between(goals.size(), 5, 6, r)
		for g: Dictionary in goals:
			assert_eq(str(g.opens), str(_sheet(r).unlock_flag), "%s opens with the region" % g.id)
			assert_true(str(g.act).begins_with(str(_sheet(r).name) + ": "), str(g.id))
			assert_false(str(g.where).is_empty(), str(g.id))
			assert_false((g.done as Array).is_empty(), str(g.id))
		assert_eq((goals[-1] as Dictionary).region, r)

func test_every_tale_chain_can_be_played_to_its_end_in_order() -> void:
	for r: String in REGIONS:
		var ids: Array = QuestLog.tale_goals(r).map(func(g: Dictionary) -> String: return str(g.id))
		assert_eq(_play(r), ids, r)

func test_tale_goals_show_one_region_at_a_time() -> void:
	var flags: Dictionary = {"story_complete": true}
	assert_eq(str(QuestLog.tale_current(flags).id), "v2t_roses")
	assert_string_contains(QuestLog.summary(flags), "Vellmarch: The Drowned Quarter")
	assert_string_contains(QuestLog.summary(flags), "Where: Hookwick")
	var rows: Array[Dictionary] = PauseMenu.goal_rows(flags, "", false)
	assert_true(rows.any(func(row: Dictionary) -> bool: return str(row.text) == "Find out who chalks roses on the Hookwick locks."))
	flags["v2t_done"] = true
	assert_true(QuestLog.tale_current(flags).is_empty(), "Quillmarch's tale waits for its region")
	flags["era2_finale_done"] = true
	assert_eq(str(QuestLog.tale_current(flags).region), "quillmarch")
	assert_true(QuestLog.tale_current({}).is_empty(), "nothing before the story is over")

func test_the_main_story_goals_are_untouched() -> void:
	var ids: Array = QuestLog.main_goals().map(func(g: Dictionary) -> String: return str(g.id))
	assert_eq(ids.slice(-5), ["far_end", "finale", "epi_guild", "epi_home", "epi_open"])
	var tale: Array = QuestLog.tale_goals().map(func(g: Dictionary) -> String: return str(g.id))
	for id: Variant in ids:
		assert_false(id in tale, str(id))

func test_figures_stand_on_free_cells_of_their_maps() -> void:
	var maps: Dictionary = {}
	for r: String in REGIONS:
		for f: Dictionary in _figures(r):
			var m: MapData = MapData.load_map(str(f.map))
			assert_eq(m.region, r, str(f.npc.id))
			var cell := Vector2i(int(f.npc.x), int(f.npc.y))
			assert_true(m.is_walkable(cell), "%s stands on a walkable cell" % f.npc.id)
			assert_true(m.warp_at(cell).is_empty(), str(f.npc.id))
			var key: String = "%s %s" % [f.map, cell]
			assert_false(maps.has(key), "%s shares a cell" % f.npc.id)
			maps[key] = true
			for other: Dictionary in m.npcs:
				if str(other.id) != str(f.npc.id) and not str(other.id).begins_with("tale_"):
					assert_ne(Vector2i(int(other.x), int(other.y)), cell, "%s stands on %s" % [f.npc.id, other.id])

func test_tale_duels_exist_in_the_region_band() -> void:
	for r: String in REGIONS:
		var duels: Array[String] = _tale_duels(r)
		assert_gte(duels.size(), 1, r)
		for id: String in duels:
			var def: Dictionary = StoryBattles.get_def(id)
			assert_true(Dialogue.exists(str(def.defeat)) and Dialogue.exists(str(def.lose)), id)
			assert_gte((def.team as Array).size(), 3, id)
			for e: Variant in def.team:
				assert_not_null(Database.species(str(e.species)), "%s: %s" % [id, e.species])
				assert_between(int(e.level), int(BAND[r][0]), int(BAND[r][1]), id)
	# Quivermoor: six lantern walkers and the elder's final duel, the strongest of them.
	var walk: Array[String] = _tale_duels("quivermoor")
	assert_gte(walk.size(), 7)
	var top: Dictionary = {}
	for id: String in walk:
		var t: int = 0
		for e: Variant in StoryBattles.get_def(id).team:
			t = maxi(t, int(e.level))
		top[id] = t
	for id: String in walk:
		if id != "tale_aslak":
			assert_lt(int(top[id]), int(top.tale_aslak), id)
	assert_eq((StoryBattles.get_def("tale_aslak").team as Array).size(), 5)

func test_tale_duels_are_winnable_with_a_team_of_the_region() -> void:
	# A team of the region's own Warden kinds at the duel's top ring, as a player who got there.
	for r: String in REGIONS:
		var kinds: Array[String] = []
		for w: Dictionary in _sheet(r).wardens:
			for e: Dictionary in w.team:
				if e.get("species") != null and not str(e.species) in kinds:
					kinds.append(str(e.species))
		for id: String in _tale_duels(r):
			var def: Dictionary = StoryBattles.get_def(id)
			var top: int = 0
			for e: Variant in def.team:
				top = maxi(top, int(e.level))
			var wins: int = 0
			for s: int in SEEDS:
				var mine: Array[Spirling] = []
				for k: String in kinds.slice(kinds.size() - 5):
					mine.append(BattleFixtures.make(k, top))
				wins += 1 if ActSim.trainer_battle(mine, {"def": def}, 100 + s) == 0 else 0
			gut.p("%s: %d/%d" % [id, wins, SEEDS])
			assert_gte(wins, SEEDS / 2, "%s can be won" % id)

func test_story_check_is_clean_and_act_hours_counts_the_tales() -> void:
	var mine: Array = Array(StoryValidator.validate()).filter(func(e: String) -> bool: return e.contains("_tale"))
	assert_eq(mine, [])
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/playtime.json"))
	for r: String in REGIONS:
		assert_eq(cfg.regions[r].get("dialogue", []), [r + "_tale"], r)
		assert_true(FileAccess.file_exists("res://data/dialogue/%s_tale.json" % r), r)

func test_every_tale_line_keeps_the_two_line_rule() -> void:
	for r: String in REGIONS:
		for v: Variant in Dialogue.file_data(r + "_tale").values():
			var lines: Array = v if v is Array else (v as Dictionary).get("lines", [])
			for l: Variant in lines:
				assert_lte(str(l).replace("{name}", "").length(), 62, str(l))
