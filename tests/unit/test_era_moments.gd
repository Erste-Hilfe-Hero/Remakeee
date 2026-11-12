extends GutTest
## Era moments (data/era_moments.json, EraMoments, docs/ERA_LOOK_TITLE.md): every era has its
## title, boot card, finale card and save card; all four era changes have their five steps
## with their own staging; every moment can be skipped and has a reduced-motion version.

var _unlocked: int
var _retro: int
var _reduce: bool
var _flags: Dictionary

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter
	_reduce = GameState.reduce_motion
	_flags = GameState.flags.duplicate()
	GameState.reduce_motion = false

func after_each() -> void:
	GameState.reduce_motion = _reduce
	GameState.flags = _flags
	EraManager.unlocked_era = _unlocked
	EraManager.retro_filter = _retro
	Loc.set_language("en")

# --- data ----------------------------------------------------------------------------

func test_data_is_valid() -> void:
	assert_eq(EraMoments.problems(), [] as Array[String])

func test_every_era_has_a_title_config() -> void:
	var kinds: Dictionary = {}
	for e: int in EraMoments.ERAS:
		var t: Dictionary = EraMoments.title(e)
		assert_true(str(t.get("kind", "")) in EraMoments.TITLE_KINDS, "era %d title kind" % e)
		kinds[str(t.kind)] = true
		assert_false(str(EraMoments.era(e).get("subtitle", "")).is_empty(), "era %d subtitle" % e)
		for sp: Variant in t.get("cast", []):
			assert_false(EraManager.art_path_from("spirlings/%s_front.png" % str(sp), e).is_empty(), "era %d cast %s has art" % [e, sp])
	assert_eq(kinds.size(), 5, "every era presents the title its own way")

func test_title_grows_like_the_hardware() -> void:
	assert_eq(str(EraMoments.title(1).kind), "static")
	assert_gt(float(EraMoments.title(1).blink), 0.0, "Era I has the 2-frame blink")
	assert_eq(float(EraMoments.title(1).scroll), 0.0, "nothing scrolls in Era I")
	assert_gt(float(EraMoments.title(2).scroll), 0.0, "Era II scrolls its backdrop")
	assert_false(bool(EraMoments.title(2).shine))
	assert_true(bool(EraMoments.title(3).shine), "Era III: the light on the logo")
	assert_true(bool(EraMoments.title(3).flyer), "Era III: the flying silhouette")
	assert_gte(int(EraMoments.title(4).layers), 4, "Era IV: layered parallax")
	assert_true(bool(EraMoments.title(5).camera), "Era V: the camera moves")
	var legend: String = str(EraMoments.title(5).legend)
	assert_false(EraManager.art_path_from("spirlings/%s_front.png" % legend, 5).is_empty(), "the Era V legend has art")
	for e: int in range(1, 5):
		assert_false(bool(EraMoments.title(e).camera), "era %d has no camera move" % e)
		assert_eq(str(EraMoments.title(e).legend), "")

func test_finale_flags_match_the_era_chain() -> void:
	var unlock: Dictionary = EraManager.unlock_flags()
	for e: int in range(1, 5):
		assert_eq(EraMoments.finale_flag(e), str(unlock.get(str(e + 1), "")), "the finale of era %d opens era %d" % [e, e + 1])
	assert_eq(EraMoments.finale_flag(5), "era5_finale_done")

func test_every_text_has_german() -> void:
	var table: Dictionary = Loc.load_table("de").get("strings", {})
	var keep: Array = Loc.load_table("de").get("keep", [])
	for s: String in EraMoments.all_texts():
		assert_true(table.has(s) or s in keep, "German for: " + s)
	Loc.set_language("de")
	assert_eq(EraMoments.era_label(2), "Ära II: Aquarell")
	assert_eq(EraFinaleCard.lines(1)[0], "Die Karte ist gezeichnet")
	assert_eq(EraFinaleCard.lines(5)[-1], "Ende")
	Loc.set_language("en")
	assert_eq(EraMoments.era_label(4), "Era IV: Panorama")

# --- title ---------------------------------------------------------------------------

func test_ink_title_has_two_frames() -> void:
	var seen: Dictionary = {}
	for i: int in 40:
		seen[EraTitleArt.ink_frame(i * 0.1, 0.6)] = true
	assert_eq(seen.keys().size(), 2, "exactly two frames")
	assert_eq(EraTitleArt.ink_frame(0.0, 0.6), 0)
	assert_eq(EraTitleArt.ink_frame(0.7, 0.6), 1)
	assert_eq(EraTitleArt.ink_frame(1.3, 0.6), 0)
	assert_eq(EraTitleArt.INK_FRAMES.size(), 2)

func test_ink_title_holds_its_frame() -> void:
	var art := EraTitleArt.new()
	add_child_autofree(art)
	art.era = 1
	art.manual = true
	art.clock = 0.2
	art._process(0.0)
	var first: float = art._t
	art.clock = 0.5
	art._process(0.0)
	assert_eq(art._t, first, "the picture does not move inside a frame")
	art.clock = 0.7
	art._process(0.0)
	assert_ne(art._t, first, "the second frame")

func test_title_art_is_still_with_reduced_motion() -> void:
	GameState.reduce_motion = true
	for e: int in [1, 5]:
		var art := EraTitleArt.new()
		art.era = e
		add_child_autofree(art)
		art._process(1.0)
		art._process(1.0)
		assert_true(art.still)
		assert_eq(art.clock, 0.0, "era %d stands still" % e)
		assert_eq(art._t, 0.0)

func test_title_scales_with_the_screen() -> void:
	assert_eq(EraTitleArt.art_height(144), 148, "the Era I layout is unchanged")
	assert_eq(EraTitleArt.art_height(270), 278)
	assert_eq(EraTitleArt.logo_scale(144), TitleArt.LOGO_SCALE, "the same logo size as before at 144 px")
	assert_gt(EraTitleArt.logo_scale(270), EraTitleArt.logo_scale(144))

func test_logo_light_runs_and_rests() -> void:
	assert_lt(EraTitleArt.shine_at(EraTitleArt.SHINE_PERIOD * 0.9), -0.5, "resting")
	var a: float = EraTitleArt.shine_at(0.2)
	var b: float = EraTitleArt.shine_at(0.8)
	assert_gt(b, a, "the light runs left to right")

func test_every_era_scene_draws() -> void:
	for e: int in EraMoments.ERAS:
		var art := EraTitleArt.new()
		art.era = e
		art.manual = true
		art.size = Vector2(270, 278)
		add_child_autofree(art)
		art.clock = 3.0
		art._process(0.0)
		await wait_process_frames(2)
		assert_eq(art.era, e)
	assert_eq(EraBackdrop.flyer_points(Vector2.ZERO, 1.0, 0.5).size(), 3, "body and two wings")
	assert_ne(EraBackdrop.flyer_points(Vector2.ZERO, 1.0, 1.0)[1], EraBackdrop.flyer_points(Vector2.ZERO, 1.0, -1.0)[1], "the wings beat")

# --- boot ----------------------------------------------------------------------------

func test_every_era_has_a_boot_card() -> void:
	var kinds: Dictionary = {}
	for e: int in EraMoments.ERAS:
		kinds[str(EraMoments.boot(e).kind)] = true
		assert_gt(float(EraMoments.boot(e).time), 0.0)
	assert_eq(kinds.size(), 5, "every era has its own boot card")
	assert_eq(str(EraMoments.boot(1).kind), "ink_drop")

func test_ink_drop_falls_in_steps_and_lands() -> void:
	var land: float = 120.0
	assert_lt(EraBoot.drop_y(0.0, land), 40.0, "the drop starts high above the middle")
	assert_eq(EraBoot.drop_y(EraBoot.LAND_AT, land), land)
	assert_eq(EraBoot.drop_y(5.0, land), land, "it stays where it landed")
	assert_eq(EraBoot.drop_y(0.401, land), EraBoot.drop_y(0.419, land), "whole steps, no in-between")
	assert_eq(fmod(land - EraBoot.drop_y(0.2, land), EraBoot.DROP_PX), 0.0)
	assert_eq(EraBoot.blot_radius(EraBoot.LAND_AT - 0.01), 0.0)
	assert_eq(EraBoot.blot_radius(EraBoot.LAND_AT), EraBoot.BLOT_FRAMES[0])
	assert_eq(EraBoot.blot_radius(9.0), EraBoot.BLOT_FRAMES[-1])

func test_boot_clears_in_four_shades() -> void:
	var seen: Dictionary = {}
	for i: int in 200:
		seen[EraBoot.fade_alpha(2.0 + i * 0.002, 2.4)] = true
	assert_eq(seen.keys().size(), EraBoot.FADE_STEPS + 1, "full, then four steps down")
	assert_eq(EraBoot.fade_alpha(0.0, 2.4), 1.0)
	assert_eq(EraBoot.fade_alpha(2.4, 2.4), 0.0)

func test_boot_can_be_skipped_and_ends_by_itself() -> void:
	for e: int in EraMoments.ERAS:
		var b := EraBoot.new()
		b.era = e
		b.manual = true
		add_child(b)
		watch_signals(b)
		b.advance(0.1)
		assert_false(b.is_closed())
		b.press()
		assert_true(b.is_closed(), "a press skips the boot card of era %d" % e)
		assert_signal_emit_count(b, "finished", 1)
	var own := EraBoot.new()
	own.manual = true
	add_child(own)
	own.advance(own.total() + 0.01)
	assert_true(own.is_closed(), "it ends by itself")

func test_boot_is_a_still_card_with_reduced_motion() -> void:
	GameState.reduce_motion = true
	var b := EraBoot.new()
	b.era = 5
	b.manual = true
	add_child(b)
	assert_true(b.reduced)
	assert_eq(b.total(), EraBoot.REDUCED_TIME)
	b.advance(EraBoot.REDUCED_TIME + 0.01)
	assert_true(b.is_closed())

func test_boot_runs_once_and_never_without_a_screen() -> void:
	var was: bool = EraBoot.shown
	EraBoot.shown = false
	assert_null(EraBoot.start(self, 1), "no boot card in headless runs")
	EraBoot.shown = was

# --- era change ----------------------------------------------------------------------

func test_all_four_changes_have_their_steps() -> void:
	for to: int in range(2, 6):
		var ids: Array[String] = []
		for s: Dictionary in EraMoments.steps(to):
			ids.append(str(s.id))
		assert_eq(ids, EraMoments.STEP_IDS, "change into era %d" % to)
		assert_false(str(EraMoments.change(to).headline).is_empty())
	assert_true(EraMoments.steps(1).is_empty(), "nothing changes into Era I")

func test_each_change_has_its_own_staging() -> void:
	for id: String in ["palette", "detail", "frames", "music"]:
		var styles: Dictionary = {}
		for to: int in range(2, 6):
			for s: Dictionary in EraMoments.steps(to):
				if str(s.id) == id:
					styles[str(s.style)] = true
		assert_eq(styles.size(), 4, "four different stagings of the %s step" % id)
	var shader_styles: Dictionary = {}
	for to: int in range(2, 6):
		shader_styles[int(EraChangeScene.params(to - 1, to).style)] = true
	assert_eq(shader_styles.size(), 4)

func test_timeline_runs_in_order() -> void:
	for to: int in range(2, 6):
		var tl: Array[Dictionary] = EraMoments.timeline(to)
		assert_eq(tl.size(), 5)
		var at: float = 0.0
		for s: Dictionary in tl:
			assert_eq(float(s.start), at)
			assert_gt(float(s.end), float(s.start))
			at = float(s.end)
		assert_eq(EraMoments.total_time(to), at)
		assert_eq(EraMoments.skip_time(to), float(tl[4].start), "a skip jumps to the list")

func test_state_walks_through_the_steps() -> void:
	var tl: Array[Dictionary] = EraMoments.timeline(2)
	var st: Dictionary = EraMoments.state_at(2, 0.0)
	assert_eq(str(st.id), "palette")
	assert_eq(float(st.palette), 0.0)
	assert_eq(float(st.detail), 0.0)
	st = EraMoments.state_at(2, (float(tl[1].start) + float(tl[1].end)) / 2.0)
	assert_eq(str(st.id), "detail")
	assert_eq(float(st.palette), 1.0, "the palette is in before the detail steps up")
	assert_almost_eq(float(st.detail), 0.5, 0.01)
	assert_eq(float(st.frames), 0.0, "the frame is still the old one")
	st = EraMoments.state_at(2, float(tl[3].start) + 0.01)
	assert_eq(str(st.id), "music")
	assert_eq(float(st.frames), 1.0)
	st = EraMoments.state_at(2, EraMoments.total_time(2) + 1.0)
	assert_eq(str(st.id), "list")
	assert_true(bool(st.done))
	for id: String in EraMoments.STEP_IDS:
		assert_eq(float(st[id]), 1.0, id + " is finished")

func test_list_is_new_in_this_era() -> void:
	for to: int in range(2, 6):
		var lines: Array[String] = EraMoments.list_lines(to)
		assert_eq(lines.size(), EraFeatures.new_in(to).size())
		assert_gt(lines.size(), 0, "era %d lists what is new" % to)
		assert_eq(lines[0], Loc.t(str(EraFeatures.new_in(to)[0].name)))
		assert_eq(EraMoments.list_rows_shown(to, 0.0), 1, "rows come one by one")
		assert_eq(EraMoments.list_rows_shown(to, 1.0), lines.size())
		assert_eq(EraMoments.list_rows_shown(to, 0.0, true), lines.size(), "all at once with reduced motion")

func test_reduced_motion_is_a_plain_fade_and_the_list() -> void:
	for to: int in range(2, 6):
		var ids: Array[String] = []
		for s: Dictionary in EraMoments.timeline(to, true):
			ids.append(str(s.id))
		assert_eq(ids, ["fade", "list"] as Array[String])
		var st: Dictionary = EraMoments.state_at(to, 0.1, true)
		assert_eq(str(st.id), "fade")
		assert_eq(float(st.palette), 1.0, "no staged sweep: the new look fades in whole")
		assert_eq(float(st.detail), 1.0)
		assert_lt(EraMoments.total_time(to, true), EraMoments.total_time(to))

func test_change_scene_can_be_skipped() -> void:
	for to: int in range(2, 6):
		var s := EraChangeScene.new()
		s.from_era = to - 1
		s.to_era = to
		s.manual = true
		add_child(s)
		watch_signals(s)
		s.advance(0.3)
		assert_eq(str(s.state.id), "palette")
		assert_eq(s._hint.text, EraMoments.text("skip"))
		s.press()
		assert_false(s.is_closed(), "the first press jumps to the list")
		assert_eq(str(s.state.id), "list")
		assert_true(bool(s.state.done))
		assert_eq(s._list.text.count("\n"), EraFeatures.new_in(to).size(), "the whole list is on screen")
		assert_eq(s._hint.text, EraMoments.text("continue"))
		s.press()
		assert_true(s.is_closed(), "the second press closes the change into era %d" % to)
		assert_signal_emit_count(s, "finished", 1)

func test_change_scene_plays_through_and_waits() -> void:
	var s := EraChangeScene.new()
	s.from_era = 2
	s.to_era = 3
	s.manual = true
	add_child_autofree(s)
	var mat: ShaderMaterial = s._pic.material
	s.advance(1.0)
	assert_gt(float(mat.get_shader_parameter("palette_p")), 0.0)
	assert_eq(float(mat.get_shader_parameter("detail_p")), 0.0)
	assert_false(s._music_done)
	s.advance(EraMoments.total_time(3))
	assert_true(s._music_done, "the music step swapped the sound")
	assert_eq(float(mat.get_shader_parameter("detail_p")), 1.0)
	assert_false(s.is_closed(), "the list stays until the player presses")

func test_change_scene_with_reduced_motion() -> void:
	GameState.reduce_motion = true
	var s := EraChangeScene.new()
	s.from_era = 4
	s.to_era = 5
	s.manual = true
	add_child_autofree(s)
	assert_true(s.reduced)
	assert_true(s._art.still, "the picture stands still")
	s.advance(0.1)
	var mat: ShaderMaterial = s._pic.material
	assert_eq(float(mat.get_shader_parameter("palette_p")), 1.0)
	assert_lt(s._pic.modulate.a, 1.0, "a plain fade")
	s.advance(EraMoments.total_time(5, true))
	assert_eq(s._pic.modulate.a, 1.0)
	assert_eq(s._list.text.count("\n"), EraFeatures.new_in(5).size())

func test_shader_steps_from_the_old_look() -> void:
	var p: Dictionary = EraChangeScene.params(1, 2)
	assert_eq(float(p.old_levels), 0.0, "Era I is the four inks")
	assert_eq(p.old_res, p.new_res, "Era II keeps the resolution, its tiles get colours")
	p = EraChangeScene.params(2, 3)
	assert_lt((p.old_res as Vector2).x, (p.new_res as Vector2).x, "the resolution steps up")
	for e: int in range(1, 5):
		assert_lt(EraChangeScene.LEVELS[e], EraChangeScene.LEVELS[e + 1], "colour depth grows")
		assert_lt(EraChangeScene.VOICES[e], EraChangeScene.VOICES[e + 1], "more voices")

func test_music_plan_swaps_old_for_new() -> void:
	var plan: Dictionary = EraMoments.music_plan(3, 4)
	assert_eq(int(plan.before_fx), 3)
	assert_eq(int(plan.after_fx), 4)
	assert_eq(Sound.era_track(str(plan.track), 4, func(_t: String) -> bool: return true), "title_era4")

# --- finale card ---------------------------------------------------------------------

func test_every_era_has_a_finale_card() -> void:
	var kinds: Dictionary = {}
	for e: int in EraMoments.ERAS:
		kinds[str(EraMoments.finale(e).kind)] = true
		var ls: Array[String] = EraFinaleCard.lines(e)
		assert_gte(ls.size(), 5)
		assert_gt(EraFinaleCard.full_time(e), EraFinaleCard.START)
	assert_eq(kinds.size(), 5, "every era brings its lines its own way")
	assert_eq(EraFinaleCard.lines(5)[-1], "The End")
	assert_eq(EraFinaleCard.lines(1)[-1], "The map goes on", "Era I is not the end")

func test_finale_lines_arrive_per_era() -> void:
	var typed: Dictionary = EraFinaleCard.line_state("type", 0, EraFinaleCard.START + 0.25)
	assert_eq(int(typed.chars), int(0.25 * EraFinaleCard.TYPE_CPS), "typed letter by letter")
	assert_eq(float(EraFinaleCard.line_state("type", 1, EraFinaleCard.START + 0.25, 30).a), 0.0, "the next line waits")
	var sc: Dictionary = EraFinaleCard.line_state("scroll", 2, EraFinaleCard.START)
	assert_gt(float(sc.dy), 0.0)
	assert_eq(float(sc.dy), floorf(float(sc.dy)), "scrolls in whole pixels")
	assert_eq(float(EraFinaleCard.line_state("scroll", 2, 60.0).dy), 0.0)
	assert_eq(float(EraFinaleCard.line_state("shine", 3, EraFinaleCard.START).a), 0.0)
	assert_eq(float(EraFinaleCard.line_state("shine", 3, 60.0).a), 1.0)
	assert_gt(float(EraFinaleCard.line_state("camera", 0, EraFinaleCard.START + 0.1).dy), 0.0, "lines rise in")

func test_finale_card_can_be_skipped() -> void:
	for e: int in EraMoments.ERAS:
		var c := EraFinaleCard.new()
		c.era = e
		c.manual = true
		add_child(c)
		watch_signals(c)
		c.advance(0.2)
		c.press()
		assert_false(c.is_closed(), "the first press shows every line")
		assert_gte(c.t, EraFinaleCard.full_time(e))
		c.press()
		assert_true(c.is_closed())
		assert_signal_emit_count(c, "finished", 1)

func test_finale_card_with_reduced_motion_closes_at_once() -> void:
	GameState.reduce_motion = true
	var c := EraFinaleCard.new()
	c.era = 4
	c.manual = true
	add_child(c)
	assert_true(c._art.still)
	c.press()
	assert_true(c.is_closed(), "everything was on screen already")

func test_card_is_owed_once_after_the_finale() -> void:
	var flags: Dictionary = {}
	var has: Callable = func(f: String) -> bool: return bool(flags.get(f, false))
	assert_false(EraMoments.card_owed(1, has))
	flags["story_complete"] = true
	assert_true(EraMoments.card_owed(1, has))
	assert_false(EraMoments.card_owed(2, has))
	flags[EraMoments.CARD_FLAG % 1] = true
	assert_false(EraMoments.card_owed(1, has), "shown once")

# --- save card -----------------------------------------------------------------------

func test_save_era_follows_the_save() -> void:
	assert_eq(EraMoments.save_era({}), 1, "an old save without era data is Era I")
	assert_eq(EraMoments.save_era({"era": {"unlocked_era": 3, "retro_filter": 0}}), 3)
	assert_eq(EraMoments.save_era({"era": {"unlocked_era": 4, "retro_filter": 2}}), 2, "the Retro filter look")
	assert_eq(EraMoments.save_unlocked({"era": {"unlocked_era": 4, "retro_filter": 2}}), 4)
	assert_eq(EraMoments.save_era({"era": {"unlocked_era": 9}}), 5)
	assert_eq(EraMoments.save_era({"era": "broken"}), 1)

func test_save_card_wears_the_saves_era() -> void:
	var card := EraSaveCard.new()
	add_child_autofree(card)
	assert_false(card.visible, "no card for an empty slot")
	card.show_save(3, "Quillmarch  41:07")
	assert_true(card.visible)
	assert_eq(card._name.text, "Era III: Etching")
	assert_eq(card._line.text, "Quillmarch  41:07")
	card.show_save(0, "")
	assert_false(card.visible)
	var frames: Dictionary = {}
	for e: int in EraMoments.ERAS:
		frames[EraMoments.frame(e)] = true
	assert_eq(frames.size(), 5, "five frame styles")

func test_era_badges_differ() -> void:
	var seen: Dictionary = {}
	for e: int in EraMoments.ERAS:
		var b: ImageTexture = EraSaveCard.badge(e)
		assert_eq(b.get_size(), Vector2(10, 10))
		seen[b.get_image().get_data()] = true
	assert_eq(seen.size(), 5)

func test_save_file_era_is_read_from_disk() -> void:
	var old_path: String = SaveManager.slot_path
	var path: String = "user://test_era_moments_save.json"
	SaveManager.slot_path = path
	SaveManager.delete_save()
	assert_true(EraMoments.save_dict(path).is_empty(), "no file, no save")
	EraManager.unlocked_era = 4
	EraManager.retro_filter = 0
	assert_true(SaveManager.save_game())
	var d: Dictionary = EraMoments.save_dict(path)
	assert_eq(EraMoments.save_era(d), 4)
	assert_eq(EraMoments.save_unlocked(d), 4)
	SaveManager.delete_save()
	SaveManager.slot_path = old_path
	assert_gte(EraMoments.title_era(), 1)
	assert_lte(EraMoments.title_era(), 5)

# --- frames --------------------------------------------------------------------------

func test_frames_draw_in_every_style() -> void:
	var c := Control.new()
	c.size = Vector2(120, 40)
	c.draw.connect(func() -> void:
		for e: int in EraMoments.ERAS:
			EraBackdrop.draw_frame(c, Rect2(2, 2, 100, 30), e)
			EraBackdrop.draw_frame(c, Rect2(2, 2, 100, 30), e, 0.4)
			EraBackdrop.paint(c, Rect2(0, 0, 34, 20), e, 0.0, true))
	add_child_autofree(c)
	await wait_process_frames(2)
	assert_eq(EraMomentLayer.ui_scale(144), 1)
	assert_eq(EraMomentLayer.ui_scale(180), 1)
	assert_eq(EraMomentLayer.ui_scale(270), 2)
