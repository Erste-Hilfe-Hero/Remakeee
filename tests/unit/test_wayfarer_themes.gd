extends GutTest
## KAMPF_PLAN_1000 items 521-525: Wayfarer themes (element and tactic), Veteran synergy and the
## field, status and stage tactics (data/wayfarer_themes.json, WayfarerThemes.gd).

const TAMER: int = 1

func before_all() -> void:
	Database.load_all()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _names(s: Spirling) -> Array[String]:
	var out: Array[String] = []
	for mv: MoveData in s.moves:
		out.append(mv.move_name)
	return out

func _has_kind(s: Spirling, kind: String) -> bool:
	for mv: MoveData in s.moves:
		if WayfarerThemes.is_kind(mv, kind):
			return true
	return false

func _team(def: Dictionary, difficulty: int) -> Array[Spirling]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 521
	return TrainerData.build_team(def, "Kindlop", rng, difficulty, 100)

## Item 521.
func test_every_map_wayfarer_has_a_theme() -> void:
	var count: int = 0
	for f: String in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		if not raw is Dictionary:
			continue
		var levels: Array = [raw]
		levels.append_array((raw as Dictionary).get("floors", []))
		for lv: Variant in levels:
			for n: Variant in (lv as Dictionary).get("npcs", []):
				if not n is Dictionary or not TrainerData.is_trainer(n) or TrainerData.is_wild_horde(n):
					continue
				var t: Dictionary = WayfarerThemes.theme(n)
				assert_true(Elements.E.has(str(t.element)), "%s %s element" % [f, n.get("id", "")])
				assert_true(WayfarerThemes.tactics().has(str(t.tactic)), "%s %s tactic" % [f, n.get("id", "")])
				assert_false(WayfarerThemes.label_of(t).is_empty())
				count += 1
	assert_gt(count, 100)

func test_theme_follows_team_and_profile() -> void:
	var def: Dictionary = {"trainer": "T", "team": [{"species": "Kindlop", "level": 9}, {"species": "Cindle", "level": 9}]}
	assert_eq(WayfarerThemes.element_of(def), "EMBER")
	assert_eq(WayfarerThemes.tactic_of(def), "power")
	def["profile"] = "spoiler"
	assert_eq(WayfarerThemes.tactic_of(def), "status")
	def["tactic"] = "stages"
	assert_eq(WayfarerThemes.tactic_of(def), "stages", "own tactic wins over the profile")
	assert_eq(WayfarerThemes.label_of({"element": "EMBER", "tactic": "field"}), "Ember, Field tricks")

func test_wayfarer_book_shows_the_theme() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	WayfarerBook.note(_npc("bellows_deep", "fuse"), "bellows_deep", true, 4)
	assert_string_contains(WayfarerBook.page("2026-11-14"), "Ember, Field tricks")

## Item 522: from Veteran the lead lays the field of the team's element; Tamer stays as it was.
func test_veteran_teams_play_together() -> void:
	var bram: Dictionary = _npc("crowcrest", "bram")
	assert_false(bram.has("tactic"))
	var tamer: Array[Spirling] = _team(bram, TAMER)
	var rng := RandomNumberGenerator.new()
	rng.seed = 521
	var raw: Array[Spirling] = []
	for s: Spirling in tamer:
		raw.append(Spirling.new(s.data, s.level, rng))
	for i: int in tamer.size():
		assert_eq(_names(tamer[i]), _names(raw[i]), "no theme arts on Tamer")
	assert_eq(WayfarerThemes.art_kinds(bram, TAMER), [])
	var vet: Array[Spirling] = _team(bram, GameState.Difficulty.VETERAN)
	var lead: MoveData = null
	for mv: MoveData in vet[0].moves:
		if WayfarerThemes.is_kind(mv, "field"):
			lead = mv
	var el: String = WayfarerThemes.element_of(bram)
	var has_field_art: bool = WayfarerThemes.pick_art("field", vet[0], el) != null
	if has_field_art:
		assert_not_null(lead, "the lead lays the field")
		assert_eq(String(Elements.E.keys()[lead.element]), el, "the field of the team's own element")
	assert_eq(vet[0].moves.size(), Spirling.MAX_MOVES)
	assert_false(WayfarerThemes.line(bram, GameState.Difficulty.VETERAN).is_empty())
	assert_true(WayfarerThemes.line(bram, TAMER).is_empty())

func test_no_synergy_for_wardens_hordes_or_own_blocks() -> void:
	var def: Dictionary = {"trainer": "T", "team": [{"species": "Cindle", "level": 20}]}
	assert_ne(WayfarerThemes.art_kinds(def, GameState.Difficulty.VETERAN), [])
	for key: String in ["warden", "boss", "wild"]:
		var d: Dictionary = def.duplicate(true)
		d[key] = true if key == "wild" else "x"
		assert_eq(WayfarerThemes.art_kinds(d, GameState.Difficulty.VETERAN), [], key)
	var own: Dictionary = def.duplicate(true)
	own["teams_by_difficulty"] = {"veteran": [{"species": "Cindle", "level": 20}]}
	assert_eq(WayfarerThemes.art_kinds(own, GameState.Difficulty.VETERAN), [], "an own Veteran team stays as written")

## Item 523: the field tactic lays the Resonance field of its element and the AI keeps it up.
func test_field_tactic() -> void:
	var fuse: Dictionary = _npc("bellows_deep", "fuse")
	assert_eq(str(fuse.get("tactic", "")), "field")
	var team: Array[Spirling] = _team(fuse, TAMER)
	assert_true(_names(team[0]).has("Ash Call"), str(_names(team[0])))
	var info: Dictionary = TrainerData.battle_info(fuse, team, 1, TAMER)
	assert_eq(float(info.profile_tune.field_w), 2.0)
	assert_eq(str(info.theme_line), "The ground here owes me money. Watch it pay up.")
	var wick: Dictionary = _npc("clinker_heath", "wick")
	assert_true(_names(_team(wick, TAMER)[0]).has("Gale Call"))

## Item 524: the status tactic carries status arts and opens with them.
func test_status_tactic() -> void:
	for id: String in ["mattie", "clem"]:
		var def: Dictionary = _npc("clinker_heath", id)
		assert_eq(str(def.get("tactic", "")), "status")
		var team: Array[Spirling] = _team(def, TAMER)
		assert_true(_has_kind(team[0], "status") and _has_kind(team[1], "status"), id)
		var tune: Dictionary = TrainerData.battle_info(def, team, 1, TAMER).profile_tune
		assert_gt(float(tune.status_w), 1.0)
		assert_eq(float(tune.status_first), 1.0)

## Item 525: the stage tactic carries a raising art; on Veteran two Spirlings do.
func test_stage_tactic() -> void:
	for key: Array in [["bellows_deep", "weighman"], ["clinker_heath", "dunstan"]]:
		var def: Dictionary = _npc(key[0], key[1])
		assert_eq(str(def.get("tactic", "")), "stages")
		assert_true(_has_kind(_team(def, TAMER)[0], "stages"), key[1])
		assert_gt(float(TrainerData.battle_info(def, [] as Array[Spirling], 1, TAMER).profile_tune.setup_w), 1.0)
	var dunstan: Array[Spirling] = _team(_npc("clinker_heath", "dunstan"), GameState.Difficulty.VETERAN)
	assert_true(_has_kind(dunstan[0], "field"), "Veteran: the lead lays the field")
	assert_true(_has_kind(dunstan[1], "stages") and _has_kind(dunstan[2], "stages"))

func test_battle_names_the_tactic() -> void:
	var fuse: Dictionary = _npc("bellows_deep", "fuse")
	var foes: Array[Spirling] = _team(fuse, TAMER)
	var mine: Array[Spirling] = [BattleFixtures.make("Puddlet", 40)]
	var m := BattleModel.new(mine, foes, false, 7, 1)
	m.trainer_name = "Fuse Girl Senna"
	m.foe_theme_line = str(TrainerData.battle_info(fuse, foes, 1, TAMER).theme_line)
	var said: bool = false
	for e: BattleEvent in m.start():
		said = said or (e.type == BattleEvent.Type.BATTLE_LINE and str(e.data.kind) == "theme")
	assert_true(said)

## The tactic Wayfarers stay off the act route, so the pinned act bands do not move.
func test_tactic_wayfarers_are_not_on_the_act_route() -> void:
	var route: Dictionary = ActSim.route()
	for act: Dictionary in route.acts:
		for step: Dictionary in act.steps:
			for k: String in ["fight", "boss"]:
				if step.has(k):
					var foe: Dictionary = ActSim.resolve(str(step[k]))
					if not foe.is_empty():
						assert_false((foe.def as Dictionary).has("tactic"), str(step[k]))
						assert_eq(WayfarerThemes.art_kinds(foe.def, TAMER), [], str(step[k]))

func test_rematch_keeps_the_theme_arts() -> void:
	var fuse: Dictionary = _npc("bellows_deep", "fuse")
	var rng := RandomNumberGenerator.new()
	var up: Array[Spirling] = TrainerData.rematch_team(fuse, "", rng, 60, 100, TAMER)
	assert_true(_names(up[0]).has("Ash Call"))
