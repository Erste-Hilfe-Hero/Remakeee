extends GutTest
## Battle plan (docs/KAMPF_PLAN_1000.md), sections "Barrierefreiheit", "Balance-Werkzeuge und
## Tests" and "Originalität, Recht und Technik": calm bonding, cry captions, art info without a
## long press, the versioned replay format, private fields kept out of shared replays, boss and
## field data checks, the per-trait simulator report and the rules for the battle model code.

var _settings: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_settings = GameState.settings_to_dict()

func after_each() -> void:
	GameState.settings_from_dict(_settings)

func _duel(seed_value: int = 7) -> BattleModel:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 20)]
	var theirs: Array[Spirling] = [BattleFixtures.make("Mossling", 20)]
	return BattleModel.new(mine, theirs, true, seed_value, 1)

# --- Barrierefreiheit ----------------------------------------------------------------------

func _bond_game(calm: bool) -> BondMinigame:
	var g := BondMinigame.new()
	add_child_autofree(g)
	g.calm = calm
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	g.rng = rng
	g._plan = BondEcho.make_plan(rng, null)
	g._all_taps.clear()
	g._start_phase(0)
	g._process(BondEcho.call_duration(g._sequence.size()) + BondEcho.GAP_TIME + 0.01)
	return g

func test_calm_bonding_waits_for_the_echo_as_long_as_it_takes() -> void:
	var g: BondMinigame = _bond_game(true)
	assert_eq(g._phase, BondMinigame.Phase.ECHO)
	for i: int in 10:
		g._process(60.0)
	assert_eq(g._phase, BondMinigame.Phase.ECHO, "no time limit in the calm style")
	for mark: int in g._sequence:
		g._tap(mark)
	assert_ne(g._phase, BondMinigame.Phase.ECHO, "the echo ends once every mark is played")

func test_the_normal_echo_keeps_its_time_limit() -> void:
	var g: BondMinigame = _bond_game(false)
	g._process(BondEcho.ECHO_TIME * 3.0)
	assert_ne(g._phase, BondMinigame.Phase.ECHO)

func test_calm_afterglow_can_be_skipped_with_a_tap_beside_the_marks() -> void:
	var g: BondMinigame = _bond_game(true)
	g._phase = BondMinigame.Phase.AFTER_ECHO
	g._process(60.0)
	assert_eq(g._phase, BondMinigame.Phase.AFTER_ECHO, "the afterglow waits too")
	g._tap(-1)
	assert_eq(g._phase, BondMinigame.Phase.RESULT)

func test_bonding_styles_cycle_load_and_teach_the_echo() -> void:
	assert_eq(MenuHost.next_bond_style("mine"), "echo")
	assert_eq(MenuHost.next_bond_style("echo"), "calm")
	assert_eq(MenuHost.next_bond_style("calm"), "mine")
	GameState.settings_from_dict({"bond_style": "calm"})
	assert_eq(GameState.bond_style, "calm")
	assert_eq(GameState.settings_to_dict().bond_style, "calm")
	GameState.settings_from_dict({"bond_style": "whatever"})
	assert_eq(GameState.bond_style, "mine")
	assert_eq(Tips.bond_how_id("calm"), "bond_echo")

func test_cries_get_a_caption_only_when_captions_are_on() -> void:
	Sound.captions.clear()
	GameState.sound_captions = false
	Sound.cry_caption("Kindlop")
	assert_eq(Sound.captions.size(), 0)
	GameState.sound_captions = true
	Sound.cry_caption("Kindlop")
	assert_eq(Sound.captions, ["[Kindlop cries out]"])
	Sound.captions.clear()

func test_art_info_opens_by_key_and_gamepad_not_only_by_long_press() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_I
	k.pressed = true
	assert_true(CommandMenu.is_info_key(k))
	k.keycode = KEY_F1
	assert_true(CommandMenu.is_info_key(k))
	k.keycode = KEY_A
	assert_false(CommandMenu.is_info_key(k))
	var j := InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_Y
	j.pressed = true
	assert_true(CommandMenu.is_info_key(j))
	j.pressed = false
	assert_false(CommandMenu.is_info_key(j), "only the press counts")

func test_art_buttons_carry_the_info_card_for_screen_readers() -> void:
	var m: BattleModel = _duel()
	m.start()
	var cm := CommandMenu.new()
	add_child_autofree(cm)
	cm.refresh(m)
	var me: Spirling = m.active_spirling(BattleModel.Side.PLAYER)
	var b: Button = cm._move_buttons[0]
	assert_eq(b.accessibility_description, CommandMenu.move_info(me.moves[0], m))
	assert_string_contains(b.accessibility_description, me.moves[0].move_name)
	cm.toggle_info(0)
	assert_true(cm.is_info_open())
	cm.toggle_info(0)
	assert_false(cm.is_info_open())

func test_bench_lessons_and_damage_preview_stay_on_for_old_settings() -> void:
	GameState.settings_from_dict({"text_speed": 1, "volume": 0.5})
	assert_true(GameState.bench_xp, "Lager-Lernen is on by default")
	assert_true(GameState.damage_preview)
	assert_eq(GameState.bond_style, "mine")

# --- Replay format and data -----------------------------------------------------------------

func test_replays_carry_their_format_and_newer_ones_are_refused() -> void:
	var m: BattleModel = _duel(31)
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	assert_eq(int(snap.format), BattleReplay.FORMAT)
	var newer: Dictionary = snap.duplicate(true)
	newer.format = BattleReplay.FORMAT + 1
	assert_false(BattleReplay.problem(newer).is_empty())
	assert_null(BattleReplay.build_model(newer))
	var old: Dictionary = snap.duplicate(true)
	old.erase("format")
	assert_eq(BattleReplay.problem(old), "", "replays from before the format field still play")
	assert_eq(BattleReplay.simulate(old), BattleReplay.simulate(snap))

func test_shared_replays_hold_no_nicknames_or_box_marks() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 20)]
	mine[0].nickname = "Grandma Rosi"
	mine[0].favorite = true
	var theirs: Array[Spirling] = [BattleFixtures.make("Mossling", 20)]
	var m := BattleModel.new(mine, theirs, true, 5, 1)
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	var shared: Dictionary = BattleReplay.shareable(snap)
	var text: String = JSON.stringify(shared)
	assert_false(text.contains("Grandma Rosi"))
	assert_false(text.contains("\"%s\"" % GameState.tamer_name), "the Wayfarer's own name is not in it")
	for k: String in BattleReplay.PRIVATE_KEYS:
		assert_false(((shared.teams as Array)[0][0] as Dictionary).has(k), k)
	assert_true(JSON.stringify(snap).contains("Grandma Rosi"), "the own copy keeps the nickname")
	var back: Dictionary = ReplayLibrary.from_code(ReplayLibrary.share_code(snap))
	assert_false(JSON.stringify(back).contains("Grandma Rosi"))
	assert_eq(BattleReplay.simulate(back), BattleReplay.simulate(snap), "the shared battle plays the same")

func test_boss_and_field_tables_are_valid_and_errors_are_caught() -> void:
	assert_eq(KampfChecks.field_errors(), PackedStringArray())
	assert_eq(KampfChecks.boss_errors(), PackedStringArray())
	assert_true(KampfChecks.boss_refs().size() >= 3, "the Rift maps name their bosses")
	var bosses: Dictionary = BattleRules.BOSSES.duplicate(true)
	var b: Dictionary = bosses["ashen_heart"]
	b.phase.at = 1.5
	b.phase.field = "nowhere"
	b.phase.stage = {"luck": 1}
	b.max_actions = 0
	var errs: String = "\n".join(KampfChecks.boss_errors(bosses))
	for bit: String in ["'at'", "nowhere", "luck", "max_actions"]:
		assert_string_contains(errs, bit)
	var fields: Dictionary = BattleRules.FIELDS.duplicate(true)
	fields["ash_storm"].boost = "PLASMA"
	fields["high_tide"].blocks = ["sunburn"]
	var ferrs: String = "\n".join(KampfChecks.field_errors(fields))
	assert_string_contains(ferrs, "PLASMA")
	assert_string_contains(ferrs, "sunburn")
	assert_eq(DataValidator.validate().size(), 0, "the real data stays clean with the new checks")

# --- Simulator reports ----------------------------------------------------------------------

func test_trait_report_pools_the_species_rows() -> void:
	var with_trait: Array[String] = []
	var without: Array[String] = []
	for sd: SpirlingData in Database.spirlings.values():
		if sd.trait_id.is_empty():
			without.append(sd.species_name)
		else:
			with_trait.append(sd.species_name)
	with_trait.sort()
	assert_true(with_trait.size() >= 2)
	var a: String = with_trait[0]
	var b: String = with_trait[1]
	var result: Dictionary = {"species": {
		a: {"wins": 6, "losses": 4, "draws": 0},
		b: {"wins": 1, "losses": 9, "draws": 0}}}
	var groups: Dictionary = BalanceGroups.by_trait(result)
	var ta: String = Database.species(a).trait_id
	assert_true(groups.has(ta))
	assert_has(groups[ta].kinds, a)
	var text: String = BalanceGroups.report(result)
	assert_string_contains(text, "## Traits")
	assert_string_contains(text, "## Elements (pooled)")
	assert_string_contains(text, "| %s |" % ta)
	if Database.species(a).trait_id != Database.species(b).trait_id:
		assert_string_contains(text, "too weak", "10 % sits below the band")
	var el: Dictionary = BalanceGroups.by_element(result)
	var games: int = 0
	for k: String in el:
		games += int(el[k].wins) + int(el[k].losses)
	assert_true(games >= 20, "dual kinds count for both elements")

# --- Battle code rules ----------------------------------------------------------------------

const MODEL_DIRS: Array[String] = ["res://scripts/battle", "res://scripts/battle/effects"]
## The one headless sanity scene in scripts/battle (scenes/battle/BattleTest.tscn).
const DEV_SCENE: String = "BattleTest.gd"

func _sources(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	for f: String in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out[f] = FileAccess.get_file_as_string(dir_path.path_join(f))
	return out

func test_battle_model_stays_a_pure_model_without_nodes() -> void:
	var n: int = 0
	for dir_path: String in MODEL_DIRS:
		var src: Dictionary = _sources(dir_path)
		for f: String in src:
			if f == DEV_SCENE:
				continue
			n += 1
			var text: String = src[f]
			for bad: String in ["extends Node", "extends Control", "extends CanvasItem", "get_tree()", "add_child("]:
				assert_false(text.contains(bad), "%s/%s uses %s" % [dir_path, f, bad])
	assert_true(n > 30)

func test_battle_code_prints_nothing_in_release() -> void:
	var re := RegEx.create_from_string("(^|[^_a-zA-Z.])(print|prints|printt|print_debug|print_rich)\\(")
	for dir_path: String in MODEL_DIRS + ["res://scripts/battle/presenter"]:
		var src: Dictionary = _sources(dir_path)
		for f: String in src:
			if f == DEV_SCENE:
				continue
			for line: String in (src[f] as String).split("\n"):
				if line.strip_edges().begins_with("#"):
					continue
				assert_null(re.search(line), "%s/%s prints: %s" % [dir_path, f, line.strip_edges()])

func test_engine_stays_on_godot_4_7() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://project.godot"), OK)
	var features: PackedStringArray = cfg.get_value("application", "config/features", PackedStringArray())
	assert_has(features, "4.7")
	assert_eq(Engine.get_version_info().major, 4)
	assert_eq(Engine.get_version_info().minor, 7)
