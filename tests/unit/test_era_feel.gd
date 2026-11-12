extends GutTest
## Era feel outside battle (data/era_feel.json, EraFeel, docs/ERA_FEEL_UI.md): every era sets
## every key, later eras never lose a feature, the era-change trigger, and the UI pieces that
## read the table.

var _unlocked: int
var _retro: int
var _flags: Dictionary

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter
	_flags = GameState.flags.duplicate()

func after_each() -> void:
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	GameState.flags = _flags
	for n: Node in get_tree().root.get_children():
		if n is EraUpgrade:
			n.queue_free()

func test_table_is_sound() -> void:
	assert_eq(EraFeel.problems(), [] as Array[String])

func test_every_era_defines_every_key() -> void:
	for e: int in range(1, 6):
		var row: Dictionary = EraFeel.of(e)
		for k: String in EraFeel.KEYS:
			assert_true(row.has(k), "era %d has %s" % [e, k])

func test_later_eras_never_lose_a_feature() -> void:
	for e: int in range(2, 6):
		for k: String in EraFeel.RISING_FLAGS:
			if bool(EraFeel.value(e - 1, k)):
				assert_true(bool(EraFeel.value(e, k)), "era %d keeps %s" % [e, k])
		for k: String in EraFeel.RISING_NUMBERS:
			assert_gte(float(EraFeel.value(e, k)), float(EraFeel.value(e - 1, k)), "era %d keeps %s" % [e, k])

func test_each_era_adds_something() -> void:
	for e: int in range(2, 6):
		var changed: int = 0
		for k: String in EraFeel.KEYS:
			if str(EraFeel.value(e, k)) != str(EraFeel.value(e - 1, k)):
				changed += 1
		assert_gt(changed, 5, "era %d looks different from era %d" % [e, e - 1])

func test_era_one_is_the_old_game() -> void:
	assert_eq(EraFeel.palette(1), UITheme.NORMAL_PALETTE)
	assert_eq(str(EraFeel.value(1, "frame")), "ink")
	assert_eq(str(EraFeel.value(1, "blip")), "blip")
	assert_eq(float(EraFeel.value(1, "text_cps_mult")), 1.0)
	assert_eq(float(EraFeel.value(1, "tilt")), 0.0)
	for k: String in EraFeel.RISING_FLAGS:
		assert_false(bool(EraFeel.value(1, k)), "Era I has no " + k)

func test_handheld_steps_land_in_their_era() -> void:
	assert_true(bool(EraFeel.value(2, "water_shimmer")), "II: animated water")
	assert_true(bool(EraFeel.value(3, "reflections")), "III: reflections")
	assert_true(bool(EraFeel.value(3, "footprints")), "III: footprints")
	assert_eq(int(EraFeel.value(3, "walk_frames")), 3, "III: left and right foot")
	assert_gt(float(EraFeel.value(4, "tilt")), 0.0, "IV: tilted view")
	assert_true(bool(EraFeel.value(5, "season_tint")), "V: seasons")
	assert_gt(float(EraFeel.value(5, "camera_lead")), 0.0, "V: moving camera")

func test_era_palettes_reach_contrast() -> void:
	for e: int in range(1, 6):
		var p: Array[Color] = EraFeel.palette(e)
		assert_gte(UITheme.contrast(p[1], p[0]), 4.5, "era %d ink on paper" % e)
		assert_gte(UITheme.contrast(p[2], p[0]), 4.5, "era %d mid on paper" % e)
		assert_gte(UITheme.contrast(p[1], p[3]), 4.5, "era %d ink on accent" % e)
		assert_gte(UITheme.contrast(p[4], p[0]), 3.0, "era %d greyed rows" % e)

func test_sounds_exist() -> void:
	for e: int in range(1, 6):
		assert_true(ResourceLoader.exists(Sound.SFX_DIR % str(EraFeel.value(e, "blip"))), "era %d blip" % e)
		assert_eq(Sound.blip_name(e), str(EraFeel.value(e, "blip")))
		if e >= 2:
			assert_true(ResourceLoader.exists(Sound.SFX_DIR % str(EraFeel.value(e, "jingle"))), "era %d jingle" % e)
	assert_eq(Sound.bus_for("blip_e3"), GameState.BUS_VOICE)

func test_captions_have_german() -> void:
	var was: String = Loc.language()
	Loc.set_language("de")
	for e: int in range(1, 6):
		for k: String in ["title", "caption"]:
			var en: String = str(EraFeel.value(e, k))
			if en == "Era IV - Panorama":
				continue
			assert_ne(Loc.t(en), en, "era %d %s in German" % [e, k])
	assert_eq(Loc.t("Replay era change"), "Era-Wechsel nochmal zeigen")
	Loc.set_language(was)

func test_upgrade_due_only_once_for_the_era_on_screen() -> void:
	var none: Callable = func(_f: String) -> bool: return false
	var seen3: Callable = func(f: String) -> bool: return f == EraFeel.SEEN_FLAG % 3
	assert_false(EraFeel.upgrade_due(1, 1, 1, none), "Era I has no sequence")
	assert_true(EraFeel.upgrade_due(2, 2, 2, none))
	assert_false(EraFeel.upgrade_due(3, 2, 2, none), "era not open yet")
	assert_false(EraFeel.upgrade_due(2, 3, 3, none), "an older region under a newer look")
	assert_false(EraFeel.upgrade_due(3, 3, 3, seen3), "shown already")
	assert_false(EraFeel.upgrade_due(3, 1, 3, none), "Retro filter on Era I")

func test_unlock_plays_the_sequence_and_marks_it_seen() -> void:
	GameState.flags.erase(EraFeel.SEEN_FLAG % 2)
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(0)
	EraManager.unlock_era(2)
	assert_true(GameState.has_flag(EraFeel.SEEN_FLAG % 2))
	var seq: EraUpgrade = _sequence()
	if not Juice.reduced():
		assert_not_null(seq, "the sequence runs")
		assert_eq(seq.to_era, 2)
		assert_eq(seq.from_era, 1)

func test_region_entry_plays_owed_sequence_once() -> void:
	EraManager.unlocked_era = 3
	EraManager.set_retro_filter(0)
	GameState.flags.erase(EraFeel.SEEN_FLAG % 3)
	assert_false(EraManager.upgrade_for_region("vellmarch"), "Era II region under the Era III look")
	assert_true(EraManager.upgrade_for_region("quillmarch"))
	assert_true(GameState.has_flag(EraFeel.SEEN_FLAG % 3))
	assert_false(EraManager.upgrade_for_region("quillmarch"), "only once")

func test_replay_needs_an_era_past_one() -> void:
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(0)
	assert_false(EraManager.replay_upgrade())
	assert_eq(MenuHost.era_replay_rows().size(), 0)
	EraManager.unlocked_era = 4
	EraManager.set_retro_filter(0)
	assert_eq(MenuHost.era_replay_rows().size(), 1)
	assert_true(EraManager.replay_upgrade())

func test_sequence_params_follow_the_eras() -> void:
	var p: Dictionary = EraUpgrade.params(1, 2)
	assert_eq(p.style, 1, "Era II spreads colour")
	assert_eq(p.old_levels, 0.0, "Era I is the inks")
	assert_eq(p.old_res, Vector2(EraManager.RESOLUTION[1]))
	assert_eq(EraUpgrade.params(2, 3).style, 2)
	assert_eq(EraUpgrade.params(3, 4).style, 3)
	assert_eq(EraUpgrade.params(4, 5).style, 4)

func test_era_skin_switches_ui_and_back() -> void:
	EraManager.unlocked_era = 4
	EraManager.set_retro_filter(0)
	assert_eq(UITheme.frame_kind, "panorama")
	assert_eq(UITheme.BG, EraFeel.palette(4)[0])
	assert_true(UITheme.era_large_font)
	assert_eq(GridWalker.walk_frames, 3)
	EraManager.set_retro_filter(1)
	assert_eq(UITheme.frame_kind, "ink")
	assert_eq(UITheme.BG, UITheme.NORMAL_PALETTE[0])
	assert_false(UITheme.era_large_font)
	assert_eq(GridWalker.walk_frames, 2)

func test_every_frame_kind_builds() -> void:
	for k: String in EraFeel.FRAMES:
		var sb: StyleBox = UITheme.frame_style_of(k)
		assert_not_null(sb, k)
		assert_eq(sb.get_content_margin(SIDE_LEFT), UITheme.panel_style().get_content_margin(SIDE_LEFT))

func test_bar_colours_and_styles_draw() -> void:
	assert_eq(EraFeel.bar_color(0.9), Color("3e9a52"))
	assert_eq(EraFeel.bar_color(0.3), Color("d6a227"))
	assert_eq(EraFeel.bar_color(0.1), Color("c4432f"))
	var c := Control.new()
	add_child_autofree(c)
	var drawn: Array[String] = []
	c.draw.connect(func() -> void:
		for s: String in EraFeel.BARS:
			for r: float in [0.0, 0.5, 1.0]:
				EraFeel.draw_bar(c, Rect2(1, 1, 40, 2), r, UITheme.INK, s)
			drawn.append(s))
	c.queue_redraw()
	await wait_process_frames(2)
	assert_eq(drawn.size(), EraFeel.BARS.size())

func test_camera_leads_only_when_walking() -> void:
	assert_eq(EraFeelLayer.lead_target(false, "left", 10.0), Vector2.ZERO)
	assert_eq(EraFeelLayer.lead_target(true, "left", 0.0), Vector2.ZERO)
	if not Juice.reduced():
		assert_eq(EraFeelLayer.lead_target(true, "left", 10.0), Vector2(-10, 0))

func test_season_tints_differ() -> void:
	var seen: Array[Color] = []
	for m: int in [1, 4, 7, 10]:
		var t: Color = EraFeel.season_tint(m)
		assert_false(t in seen, "month %d" % m)
		seen.append(t)

func test_walker_mirrors_every_other_step_from_era_three() -> void:
	var w := GridWalker.new()
	add_child_autofree(w)
	var keep: int = GridWalker.walk_frames
	GridWalker.walk_frames = 3
	w.place(Vector2i(2, 2), "down")
	w.step("down")
	w._step_frame = 1
	var first: bool = w.mirrored_step()
	w.step("down")
	w._step_frame = 1
	assert_ne(w.mirrored_step(), first, "the other foot")
	GridWalker.walk_frames = 2
	assert_false(w.mirrored_step(), "Era I and II never mirror")
	GridWalker.walk_frames = keep

func _sequence() -> EraUpgrade:
	for n: Node in get_tree().root.get_children():
		if n is EraUpgrade:
			return n
	return null

func test_overworld_runs_every_era() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	for e: int in range(1, 6):
		EraManager.unlocked_era = e
		EraManager.set_retro_filter(0)
		GameState.flags[EraFeel.SEEN_FLAG % e] = true
		ow._era_feel.stepped(ow.player.cell, ow.player.cell + Vector2i.LEFT)
		ow._era_feel.queue_redraw()
		ow.refresh_daylight()
		ow._show_banner("Test")
		await wait_process_frames(3)
		assert_eq(ow._era_feel._tilt_layer.visible, float(EraFeel.value(e, "tilt")) > 0.0 and not Juice.reduced(), "era %d tilt" % e)
	await ow._warp_out(false)
	assert_eq(ow._fade.color.a, 1.0, "the Era V iris ends black")
	await wait_seconds(0.5)
