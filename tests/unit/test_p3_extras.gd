extends GutTest
## P3 items: temperament (37), Iron Oath (15), collection goals (49), rematches (13),
## controller bindings (63), one-hand layout (79), photo mode (94), replays (14), era lines (48).

var _saved: Dictionary
var _settings: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()
	_settings = GameState.settings_to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Juno", 0, "Kindlop")

func after_each() -> void:
	GameState.from_dict(_saved)
	GameState.settings_from_dict(_settings)
	VirtualPad.apply_settings()

# --- Temperament ---------------------------------------------------------------------

func test_temperament_is_stable_and_boosts_one_stat() -> void:
	var counts: Dictionary = {}
	for i: int in 300:
		var uid: String = "%08x%08x" % [i * 7919, i * 104729]
		var t: int = Spirling.temperament_index(uid)
		assert_eq(t, Spirling.temperament_index(uid), "same uid, same temperament")
		counts[t] = int(counts.get(t, 0)) + 1
	assert_eq(counts.size(), Spirling.TEMPERAMENTS.size(), "every temperament occurs")
	var s := Spirling.new(Database.species("Kindlop"), 40)
	var round_trip: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(round_trip.temperament().id, s.temperament().id, "survives a save")
	assert_eq(round_trip.atk(), s.atk())
	assert_eq(round_trip.max_hp(), s.max_hp())

func test_temperament_bonus_applies_to_its_stat_only() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 50)
	var plain := Spirling.new(Database.species("Kindlop"), 50)
	plain.spark = s.spark.duplicate()
	plain.uid = ""  # "Even": no bonus
	assert_eq(plain.temperament().id, "even")
	var stat: String = str(s.temperament().stat)
	var getters: Dictionary = {"atk": "atk", "def": "def", "foc": "foc", "spd": "spd", "hp": "max_hp"}
	for key: String in getters:
		var mine: int = s.call(getters[key])
		var base: int = plain.call(getters[key])
		if key == stat:
			assert_gt(mine, base, "%s gets the lean" % key)
		else:
			assert_eq(mine, base, "%s unchanged" % key)
	assert_string_contains(MenuHost.summary(s), "Temperament: ")

# --- Iron Oath -----------------------------------------------------------------------

func test_iron_oath_retires_fainted_and_saves() -> void:
	GameState.iron_oath = true
	GameState.receive_spirling(Spirling.new(Database.species("Puddlet"), 5))
	GameState.party[1].hp = 0
	var names: Array[String] = GameState.retire_fainted()
	assert_eq(names, ["Puddlet"] as Array[String])
	assert_eq(GameState.party.size(), 1)
	assert_eq(GameState.sanctuary.size(), 1)
	var d: Dictionary = GameState.to_dict()
	GameState.from_dict(d)
	assert_true(GameState.iron_oath)
	assert_eq(GameState.sanctuary.size(), 1)
	assert_eq(GameState.sanctuary[0].data.species_name, "Puddlet")

func test_iron_oath_off_retires_nobody() -> void:
	GameState.party[0].hp = 0
	assert_true(GameState.retire_fainted().is_empty())
	assert_eq(GameState.party.size(), 1)

func test_iron_oath_refills_from_storage_then_breaks() -> void:
	GameState.iron_oath = true
	GameState.storage.append(Spirling.new(Database.species("Mossling"), 6))
	GameState.party[0].hp = 0
	var lines: Array[String] = Overworld.oath_lines(GameState.retire_fainted())
	assert_eq(GameState.party.size(), 1, "storage stepped up")
	assert_eq(GameState.party[0].data.species_name, "Mossling")
	assert_true(GameState.iron_oath)
	assert_eq(lines.size(), 2)
	GameState.party[0].hp = 0
	lines = Overworld.oath_lines(GameState.retire_fainted())
	assert_false(GameState.iron_oath, "nobody left: the oath ends")
	assert_true(GameState.has_flag("oath_broken"))
	assert_eq(GameState.party.size(), 2, "both come back from the Sanctuary")
	assert_true(GameState.sanctuary.is_empty())
	assert_eq(GameState.first_healthy_index(), 0, "and they are rested")

# --- Collection goals ----------------------------------------------------------------

func test_collection_goals_pay_once() -> void:
	var names: Array[String] = ["Puddlet", "Mossling", "Zippit", "Zephlet", "Kelpup"]
	for n: String in names:
		GameState.mark_seen(n, true)
	var before: int = GameState.item_count("strong_tonic")
	var lines: Array[String] = Collection.claim()
	assert_eq(lines.size(), 2, "3 and 5 kinds reached (6 with the starter)")
	assert_eq(GameState.item_count("strong_tonic"), before + 2)
	assert_eq(GameState.item_count("revival_leaf"), 1)
	assert_true(Collection.claim().is_empty(), "no double pay")
	assert_string_contains(Collection.progress_text(GameState.spirlog, Database.spirlings.size()), "Next gift at 8")

func test_collection_completion_gives_money() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		GameState.mark_seen(sd.species_name, true)
	var money: int = GameState.money
	Collection.claim()
	assert_eq(GameState.money, money + 5000)
	assert_true(Collection.next_goal(GameState.spirlog, Database.spirlings.size()).is_empty())
	for g: Dictionary in Collection.GOALS:
		if str(g.item) != "":
			assert_false(Database.item(str(g.item)).is_empty(), "gift %s exists" % g.item)

# --- Rematches -----------------------------------------------------------------------

func test_rematch_once_per_day_and_scaled() -> void:
	var def: Dictionary = {"id": "bram", "trainer": "Ridgewalker Bram", "team": [{"species": "Puddlet", "level": 7}, {"species": "Mossling", "level": 9}]}
	var flags: Dictionary = {}
	assert_false(TrainerData.can_rematch(def, "crowcrest", flags, {}, "2026-11-01"), "not beaten yet")
	flags[TrainerData.beaten_flag(def, "crowcrest")] = true
	var records: Dictionary = {"rematch": {TrainerData.beaten_flag(def, "crowcrest"): "2026-11-01"}}
	assert_false(TrainerData.can_rematch(def, "crowcrest", flags, records, "2026-11-01"), "already today")
	assert_true(TrainerData.can_rematch(def, "crowcrest", flags, records, "2026-11-02"), "next day")
	var leaving: Dictionary = def.duplicate()
	leaving["leaves"] = true
	assert_false(TrainerData.can_rematch(leaving, "crowcrest", flags, {}, "2026-11-02"))
	var rng := RandomNumberGenerator.new()
	var team: Array[Spirling] = TrainerData.rematch_team(def, "Kindlop", rng, 25, 100)
	assert_eq([team[0].level, team[1].level], [23, 25], "shape kept, top matches party")
	team = TrainerData.rematch_team(def, "Kindlop", rng, 25, 18)
	assert_eq(team[1].level, 18, "level cap respected")
	team = TrainerData.rematch_team(def, "Kindlop", rng, 4, 100)
	assert_eq(team[1].level, 9, "never weaker than the first fight")

# --- Controller and one-hand layout --------------------------------------------------

func _has_button(action: StringName, button: int) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false

func test_gamepad_buttons_are_bound() -> void:
	assert_true(_has_button(&"ui_accept", JOY_BUTTON_A))
	assert_true(_has_button(&"ui_cancel", JOY_BUTTON_B))
	assert_true(_has_button(GameState.MENU_ACTION, JOY_BUTTON_START))
	assert_true(_has_button(GameState.SPEED_ACTION, JOY_BUTTON_RIGHT_SHOULDER))
	assert_true(_has_button(GameState.AUTO_ACTION, JOY_BUTTON_Y))
	var count: int = InputMap.action_get_events(&"ui_accept").size()
	GameState._register_actions()
	assert_eq(InputMap.action_get_events(&"ui_accept").size(), count, "registering twice adds nothing")

func _pad_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b: TouchScreenButton in VirtualPad._buttons:
		out.append(Rect2(b.position, (b.shape as RectangleShape2D).size))
	return out

func test_one_hand_layout_fits_and_never_overlaps() -> void:
	var vp: Rect2 = VirtualPad.get_viewport().get_visible_rect()
	for left: bool in [false, true]:
		for size: int in GameState.PAD_SIZE_NAMES.size():
			GameState.one_hand = true
			GameState.left_handed = left
			GameState.pad_size = size
			VirtualPad.apply_settings()
			var rects: Array[Rect2] = _pad_rects()
			for i: int in rects.size():
				assert_true(vp.encloses(rects[i]), "button %d on screen (left=%s size=%d)" % [i, left, size])
				for j: int in range(i + 1, rects.size()):
					assert_false(rects[i].intersects(rects[j]), "buttons %d and %d overlap" % [i, j])
				var mid: float = vp.size.x / 2.0
				if left:
					assert_lt(rects[i].position.x, mid, "left-handed: everything on the left")
				else:
					assert_gt(rects[i].end.x, mid, "everything on the right")

# --- Photo mode ----------------------------------------------------------------------

func test_photo_saves_scaled_png() -> void:
	var img := Image.create(144, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var photos: int = int(GameState.records.get("photos", 0))
	var path: String = PhotoMode.save_photo(img)
	assert_ne(path, "")
	var back := Image.load_from_file(path)
	assert_eq(back.get_size(), Vector2i(144 * PhotoMode.SCALE, 256 * PhotoMode.SCALE))
	assert_eq(int(GameState.records.photos), photos + 1)
	var second: String = PhotoMode.save_photo(img)
	assert_ne(second, path, "never overwrites")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(second)
	assert_eq(PhotoMode.save_photo(null), "")
	assert_eq(PhotoMode.clamp_offset(Vector2(999, -999)), Vector2(PhotoMode.PAN_LIMIT, -PhotoMode.PAN_LIMIT))

# --- Replays -------------------------------------------------------------------------

func test_replay_reproduces_the_battle() -> void:
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 14), Spirling.new(Database.species("Puddlet"), 12)]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 13), Spirling.new(Database.species("Zippit"), 13)]
	var model := BattleModel.new(mine, foes, false, 4242, 1)
	model.trainer_name = "Test Wayfarer"
	var snap: Dictionary = BattleReplay.snapshot(model, "battle", "field")
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 200:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			snap.inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var a: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(a))
		model.submit_turn(a)
	assert_true(model.is_finished())
	# Through JSON, as it is stored in the save.
	var stored: Dictionary = JSON.parse_string(JSON.stringify(snap))
	assert_eq(BattleReplay.simulate(stored), model.outcome, "same outcome")
	var again: BattleModel = BattleReplay.build_model(stored)
	again.start()
	for d: Variant in stored.inputs:
		if str((d as Dictionary).t) == "switch":
			again.submit_switch(int(d.i))
		else:
			again.submit_turn(BattleReplay.action_from_dict(d))
	for side: int in [0, 1]:
		for i: int in model.party(side).size():
			assert_eq((again.party(side)[i] as Spirling).hp, (model.party(side)[i] as Spirling).hp, "hp side %d #%d" % [side, i])
	assert_string_contains(BattleReplay.label(stored), "Test Wayfarer")

func test_replay_of_missing_species_is_refused() -> void:
	var snap: Dictionary = {"teams": [[{"species": "Nobody"}], [{"species": "Puddlet", "level": 3}]]}
	assert_null(BattleReplay.build_model(snap))

# --- Era transition ------------------------------------------------------------------

func test_every_new_era_has_a_line() -> void:
	for e: int in [EraManager.Era.WASH, EraManager.Era.ETCHED, EraManager.Era.PANORAMA]:
		assert_true(EraManager.ERA_LINES.has(e))

# --- Day and night -------------------------------------------------------------------

func test_day_phases_follow_the_clock() -> void:
	assert_eq(DayCycle.phase_for_hour(4), DayCycle.Phase.NIGHT)
	assert_eq(DayCycle.phase_for_hour(5), DayCycle.Phase.DAWN)
	assert_eq(DayCycle.phase_for_hour(7), DayCycle.Phase.DAY)
	assert_eq(DayCycle.phase_for_hour(17), DayCycle.Phase.DAY)
	assert_eq(DayCycle.phase_for_hour(18), DayCycle.Phase.DUSK)
	assert_eq(DayCycle.phase_for_hour(20), DayCycle.Phase.NIGHT)
	assert_eq(DayCycle.phase_for_hour(23), DayCycle.Phase.NIGHT)
	assert_eq(DayCycle.phase_for_hour(0), DayCycle.Phase.NIGHT)

func test_day_night_only_outdoors_and_when_on() -> void:
	var white := Color(1, 1, 1)
	assert_eq(DayCycle.tint(false, DayCycle.Phase.NIGHT, true), white, "rooms stay lit")
	assert_eq(DayCycle.tint(true, DayCycle.Phase.NIGHT, false), white, "option off")
	assert_ne(DayCycle.tint(true, DayCycle.Phase.NIGHT, true), white)
	assert_eq(DayCycle.tint(true, DayCycle.Phase.DAY, true), white)
	var fest: Array[int] = [Elements.E.UMBRA, Elements.E.BLOOM]
	var night: Array[int] = DayCycle.encounter_boost(fest, true, DayCycle.Phase.NIGHT, true)
	assert_eq(night, [Elements.E.UMBRA, Elements.E.BLOOM, Elements.E.LUMEN] as Array[int], "union, no duplicates")
	assert_eq(DayCycle.encounter_boost(fest, false, DayCycle.Phase.NIGHT, true), fest, "indoors: festival only")
	assert_eq(fest.size(), 2, "festival list not changed")

func test_outdoor_maps_are_marked() -> void:
	assert_true(MapData.load_map("fernstair").outdoor)
	assert_false(MapData.load_map("lighthouse").outdoor)
	assert_false(MapData.load_map("murk_hollow").outdoor)
