extends GutTest
## The cut-scenes at the big story moments (docs/STORY.md "Cut-scenes", data/scenes/cs_*.json):
## they load, reference real actors and hosts, change no outcome, last 15 to 40 seconds, keep
## every box at two lines, can be skipped (Skip or a held press) and play once per save.

## Cut-scene -> [host, map it plays on]. A host "scenes/<id>" is a scene file, any other a
## dialogue entry; both must start the cut-scene with "scene <id>".
const HOSTS: Dictionary = {
	"cs_a1_pages": ["scenes/mirela_lamp", "lighthouse"],
	"cs_a1_oar": ["scenes/act1_finale", "lighthouse"],
	"cs_a1_cast_off": ["scenes/ferry_crossing", "brindlewick"],
	"cs_a2_flock": ["scenes/corvane_arrival", "corvane_quay"],
	"cs_a2_wide_rift": ["scenes/wide_rift_reveal", "wide_rift_edge"],
	"cs_a3_ash": ["scenes/ashmere_arrival", "ashmere_station"],
	"cs_a3_plate": ["ashmere/veit_plate_self", "gravers_hall"],
	"cs_a3_seal": ["scenes/undrawn_enter", "wide_rift_far"],
	"cs_a4_road": ["scenes/a4_ochrewell", "ochrewell"],
	"cs_a4_tower": ["scenes/a4_tower_gate", "tower_rift"],
	"cs_a4_caravan": ["scenes/a4_north", "saltglass"],
	"cs_f_edge": ["scenes/finale_1", "undrawn_3"],
	"cs_f_choir": ["scenes/finale_5", "undrawn_3"],
	"cs_e_guild": ["corvane/ysolde_epilogue", "madderby_guild"],
	"cs_e_home": ["ashmere/mirela_home", "lighthouse"],
	"cs_e_open": ["ashmere/epi_open", "lighthouse"],
}
## Era of each act's panels (docs/ERA_LOOK_TITLE.md).
const ACT_ERA: Dictionary = {"a1": 1, "a2": 2, "a3": 3, "a4": 4, "f": 5, "e": 5}
const LANGS: Array[String] = ["en", "de", "ja", "fr", "it", "es", "ko", "zh_CN", "zh_TW", "pt_BR", "ru", "pl", "tr", "nl"]

func before_each() -> void:
	Database.load_all()
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 0, Database.STARTERS[0], 1)
	GameState.reduce_motion = false

func after_each() -> void:
	GameState.reduce_motion = false
	Loc.set_language("en")

func _act(id: String) -> String:
	return id.trim_prefix("cs_").get_slice("_", 0)

func _steps(id: String) -> Array:
	return ScenePlayer.load_scene(id).get("steps", [])

## Rough playing time: reading time per box, the motion steps at their times.
func _seconds(id: String) -> float:
	var t: float = 0.0
	for s: Dictionary in _steps(id):
		match ScenePlayer.step_kind(s):
			"say":
				for l: Variant in s.say:
					t += 1.5 + str(l).length() / 14.0
			"wait", "shake", "flash":
				t += float(s.get(ScenePlayer.step_kind(s)))
			"iris":
				t += float(s.get("time", ScenePlayer.IRIS_TIME))
			"pan":
				t += float(s.get("time", ScenePlayer.PAN_TIME))
			"fade":
				t += float(s.get("time", 0.4))
			"emote":
				t += ScenePlayer.EMOTE_TIME
	return t

func _overworld() -> Overworld:
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_frames(2)
	return ow

func _player(ow: Overworld) -> ScenePlayer:
	var sp := ScenePlayer.new()
	sp.overworld = ow
	ow.add_child(sp)
	return sp

func test_every_cutscene_loads_and_is_valid() -> void:
	var errors: PackedStringArray = StoryValidator.validate()
	for id: String in HOSTS:
		assert_true(ScenePlayer.exists(id), id)
		var scene: Dictionary = ScenePlayer.load_scene(id)
		assert_true(bool(scene.get("once", false)), "%s plays once per save" % id)
		assert_true(bool(scene.get("skippable", true)), "%s can be skipped" % id)
		assert_eq(int(scene.get("era", 0)), ACT_ERA[_act(id)], "%s wears its act's era" % id)
		for s: Dictionary in _steps(id):
			assert_ne(ScenePlayer.step_kind(s), "", "%s: %s" % [id, s])
			if s.has("panel") and str(s.panel) != "off":
				assert_true(CutscenePanel.known(str(s.panel)), "%s: panel %s" % [id, s.panel])
		for e: String in errors:
			assert_false(e.contains(id), e)

func test_two_or_three_per_act() -> void:
	var per: Dictionary = {}
	for id: String in HOSTS:
		per[_act(id)] = int(per.get(_act(id), 0)) + 1
	for act: String in ACT_ERA:
		assert_between(int(per.get(act, 0)), 2, 3, "act %s" % act)

func test_each_host_starts_its_cutscene() -> void:
	for id: String in HOSTS:
		var host: String = HOSTS[id][0]
		var call: String = "scene " + id
		if host.begins_with("scenes/"):
			var found: bool = _steps(host.trim_prefix("scenes/")).any(func(s: Dictionary) -> bool: return str(s.get("action", "")) == call)
			assert_true(found, "%s starts %s" % [host, id])
		else:
			assert_eq(str(Dialogue.get_entry(host).get("action", "")), call, "%s starts %s" % [host, id])
	# Both ways through Veit's plate and both epilogue homes play their cut-scene.
	assert_eq(str(Dialogue.get_entry("ashmere/veit_plate_player").get("action", "")), "scene cs_a3_plate")
	assert_eq(str(Dialogue.get_entry("ashmere/mirela_gate_letter").get("action", "")), "scene cs_e_home")

## Figures are the player, figures the scene spawns, or people standing on the host map.
func test_actors_exist() -> void:
	for id: String in HOSTS:
		var map_id: String = HOSTS[id][1]
		assert_true(MapData.exists(map_id), "%s: map %s" % [id, map_id])
		var people: Array[String] = ["player"]
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + map_id + ".json"))
		for n: Variant in (raw as Dictionary).get("npcs", []):
			people.append(str((n as Dictionary).get("id", "")))
		for n: Variant in StoryPlacements.for_map(map_id).get("npcs", []):
			people.append(str((n as Dictionary).get("id", "")))
		for s: Dictionary in _steps(id):
			if s.has("spawn"):
				assert_true(GridWalker.sheet_for(str(s.get("sprite", "villager"))) != null, "%s: sprite %s" % [id, s.get("sprite")])
				people.append(str(s.spawn))
			for k: String in ["move", "face", "emote"]:
				if s.has(k):
					assert_has(people, str(s[k]), "%s: %s %s" % [id, k, s[k]])
			if s.has("iris"):
				assert_has(people, str(s.get("at", "player")), id)

## Cut-scenes only show: no flag, item, battle, story number or action of their own.
func test_outcomes_unchanged() -> void:
	for id: String in HOSTS:
		for s: Dictionary in _steps(id):
			assert_false(ScenePlayer.runs_when_skipped(ScenePlayer.step_kind(s), s), "%s: %s" % [id, s])

func test_length_15_to_40_seconds() -> void:
	for id: String in HOSTS:
		assert_between(_seconds(id), 15.0, 40.0, id)

## Two lines per box in every language the game ships (docs/STORY.md style rule).
func test_two_lines_per_box_in_every_language() -> void:
	var ow: Overworld = await _overworld()
	var box: TextBox = ow.text_box()
	var font: Font = box._label.get_theme_font("font")
	var size: int = box._label.get_theme_font_size("font_size")
	var width: float = box._text_width()
	for lang: String in LANGS:
		Loc.set_language(lang)
		for id: String in HOSTS:
			for s: Dictionary in _steps(id):
				for l: Variant in s.get("say", []):
					var body: String = Dialogue.split_speaker(Loc.t(str(l)))[1]
					if body.is_empty():
						body = Loc.t(str(l))
					var rows: int = TextBox.split_lines(body, width, font, size, 99)[0].split("\n").size()
					assert_lte(rows, 2, "%s %s: %s" % [lang, id, body])

func test_skip_ends_the_whole_cutscene() -> void:
	var ow: Overworld = await _overworld()
	ow.text_box().auto_advance = true
	var sp: ScenePlayer = _player(ow)
	var done: Array[bool] = [false]
	var run := func() -> void:
		await sp.play("cs_a2_wide_rift")
		done[0] = true
	run.call()
	await wait_frames(3)
	assert_not_null(sp.skip_button())
	sp.skip()
	await wait_until(func() -> bool: return done[0], 3.0)
	assert_true(done[0])
	assert_true(GameState.has_flag("scene_cs_a2_wide_rift_seen"))
	assert_null(sp.panel())
	assert_eq(ow.scene_pan, Vector2.ZERO)
	assert_false(ow.scene_panel_on)
	assert_almost_eq(ow.fade_rect().color.a, 0.0, 0.01)
	assert_false(ow.scene_running)
	sp.queue_free()

func test_holding_a_press_skips() -> void:
	var ow: Overworld = await _overworld()
	var sp: ScenePlayer = _player(ow)
	var done: Array[bool] = [false]
	var run := func() -> void:
		await sp.play("cs_a3_ash")
		done[0] = true
	run.call()
	await wait_frames(3)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	sp._input(press)
	sp._hold_ms = Time.get_ticks_msec() - ScenePlayer.HOLD_SKIP_MS - 1
	await wait_until(func() -> bool: return done[0], 3.0)
	assert_true(sp.skipping)
	assert_true(GameState.has_flag("scene_cs_a3_ash_seen"))
	sp.queue_free()

## A nested cut-scene skipped on its own lets the host scene play on.
func test_skipping_a_nested_cutscene_keeps_the_host_playing() -> void:
	var ow: Overworld = await _overworld()
	ow.text_box().auto_advance = true
	var sp: ScenePlayer = _player(ow)
	sp.play("host", {"skippable": false, "steps": [{"action": "scene cs_a3_ash"}, {"wait": 0.1}]})
	await wait_until(func() -> bool: return ScenePlayer.current != null and ScenePlayer.current != sp, 2.0)
	ScenePlayer.current.skip()
	await wait_until(func() -> bool: return ScenePlayer.current == sp, 3.0)
	assert_false(ow.scene_skipping)
	assert_false(sp.skipping)
	await wait_until(func() -> bool: return not ow.scene_running, 3.0)
	assert_true(GameState.has_flag("scene_host_seen"))
	sp.queue_free()

func test_plays_once_per_save() -> void:
	var ow: Overworld = await _overworld()
	var sp: ScenePlayer = _player(ow)
	sp.skipping = true
	await sp.play("cs_e_open")
	assert_true(GameState.has_flag("scene_cs_e_open_seen"))
	sp.queue_free()
	var again: ScenePlayer = _player(ow)
	var before: int = Time.get_ticks_msec()
	await again.play("cs_e_open")
	assert_null(again.skip_button(), "a seen cut-scene does not start again")
	assert_lt(Time.get_ticks_msec() - before, 50)
	assert_false(ow.scene_running)
	again.queue_free()

func test_reduced_motion_stands_still() -> void:
	GameState.reduce_motion = true
	var p := CutscenePanel.new(3, "plate")
	assert_true(p.still)
	assert_eq(p.progress(), 1.0, "the motif stands finished")
	var iris := SceneIris.new()
	assert_true(iris.plain_fade)
	p.free()
	iris.free()
	var ow: Overworld = await _overworld()
	var sp: ScenePlayer = _player(ow)
	sp.play("pan", {"steps": [{"pan": [2, 0], "time": 5.0}, {"wait": 5.0}]})
	await wait_frames(2)
	assert_eq(ow.scene_pan, Vector2(2 * GridWalker.TILE, 0), "the camera jumps")
	sp.skip()
	await wait_frames(3)
	sp.queue_free()

func test_era_one_moves_in_hard_steps() -> void:
	var p := CutscenePanel.new(1, "pages")
	p.t = 0.7
	assert_eq(p._clock(), 0.5, "Era I redraws twice a second")
	p.era = 4
	assert_eq(p._clock(), 0.7)
	p.free()
	var iris := SceneIris.new()
	iris.plain_fade = false
	iris.era = 1
	iris.open = 0.6
	assert_eq(iris.shown_open(), 0.5)
	iris.free()

func test_every_motif_draws_in_every_era() -> void:
	for m: String in CutscenePanel.MOTIFS:
		var probe := CutscenePanel.new(1, m)
		assert_true(probe.has_method("_m_" + m), m)
		probe.free()
	var holder := Control.new()
	holder.size = Vector2(144, 256)
	add_child_autofree(holder)
	for e: int in range(1, 6):
		for m: String in CutscenePanel.MOTIFS:
			var p := CutscenePanel.new(e, m)
			holder.add_child(p)
			p.t = 1.3
			p.queue_redraw()
	await wait_frames(2)
	assert_eq(holder.get_child_count(), 5 * CutscenePanel.MOTIFS.size())
