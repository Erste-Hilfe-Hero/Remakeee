extends GutTest
## Battle HUD per era (data/era_battle_hud.json, docs/ERA_FEEL_HUD.md).

## Screen size of each era and the sprite size its battles use.
const SCREENS: Dictionary = {1: Vector2(144, 256), 2: Vector2(144, 256), 3: Vector2(180, 320), 4: Vector2(270, 480), 5: Vector2(270, 480)}

var _keep: Array[int] = []
var _settings: Dictionary
var _last_item: String = ""

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	_last_item = EraBattleHud.last_item
	GameState.reduce_motion = false
	EraBattleHud.skin_override = 0

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)
	EraBattleHud.last_item = _last_item
	EraBattleHud.skin_override = -1
	Juice.in_battle = false

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

func _field(era: int) -> Vector2:
	var s: Vector2 = SCREENS[era]
	return Vector2(s.x, s.y - EraBattleHud.text_box_height(era) - EraBattleHud.menu_height(era))

## Sprite rects as BattleScene hands them in: the stage's in Era IV/V, the plain ones before.
func _sprites(era: int, f: Vector2) -> Array[Rect2]:
	var px: float = float(EraManager.BATTLE_SPRITE_SIZE[era])
	if era >= EraManager.STAGE_25D_FROM:
		var cfg: Dictionary = EraManager.stage_config()
		return [Era4Stage.sprite_rect(cfg, "foe", f, px), Era4Stage.sprite_rect(cfg, "player", f, px)]
	return [Rect2(44, 20, px, px), Rect2(f.x - px - 8, f.y - px - 8, px, px)]

func _named_rects(era: int, l: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"foe plate": EraBattleHud.plate_outer(era, l.foe_plate, bool(l.foe_slant_left)),
		"player plate": EraBattleHud.plate_outer(era, l.player_plate, bool(l.player_slant_left)),
		"foe sprite": l.foe_sprite, "player sprite": l.player_sprite,
		"foe team": l.foe_team, "player team": l.player_team, "goal": l.goal,
	}
	for i: int in (l.buttons as Array).size():
		out["button %d" % i] = l.buttons[i]
	return out

func test_table_is_complete_and_only_grows() -> void:
	assert_eq(EraBattleHud.problems(), [] as Array[String])
	for e: int in range(2, EraBattleHud.ERAS + 1):
		assert_gt(EraBattleHud.feature_score(e), EraBattleHud.feature_score(e - 1), "era %d adds to era %d" % [e, e - 1])
	assert_eq(EraBattleHud.for_era(9), EraBattleHud.for_era(5), "eras past V use V")

func test_each_era_has_its_own_look() -> void:
	assert_eq(EraBattleHud.text(1, "menu"), "text")
	assert_eq(EraBattleHud.text(1, "commands"), "grid", "Era I: the four commands as words, two by two")
	assert_eq(EraBattleHud.text(1, "xp"), "static")
	assert_false(EraBattleHud.flag(1, "marks"))
	assert_true(EraBattleHud.flag(2, "marks"), "Era II: bonded-before and Gleam marks")
	assert_true(EraBattleHud.flag(2, "xp_colour"))
	assert_gt(int(EraBattleHud.num(3, "plate_slant")), 0, "Era III: slanted plates")
	assert_true(EraBattleHud.flag(3, "art_fill"), "Era III: element-coloured art buttons")
	assert_eq(EraBattleHud.text(3, "xp"), "fill")
	assert_true(EraBattleHud.flag(4, "art_detail"))
	assert_true(EraBattleHud.flag(4, "item_shortcut"))
	assert_false(EraBattleHud.flag(3, "item_shortcut"))
	assert_eq(EraBattleHud.text(5, "hp_numbers"), "roll")
	assert_true(EraBattleHud.flag(5, "plate_slide"))
	assert_gt(EraBattleHud.num(5, "camera_follow"), 0.0)
	assert_eq(EraBattleHud.text(5, "info_card"), "rich")

func test_nothing_overlaps_on_any_era_screen() -> void:
	for era: int in range(1, 6):
		var f: Vector2 = _field(era)
		assert_gt(f.y, 100.0, "era %d keeps a field" % era)
		var sp: Array[Rect2] = _sprites(era, f)
		var rects: Dictionary = _named_rects(era, EraBattleHud.single_layout(era, f, sp[0], sp[1], 7))
		var names: Array = rects.keys()
		var screen := Rect2(Vector2.ZERO, f)
		for i: int in names.size():
			var a: Rect2 = rects[names[i]]
			assert_true(screen.encloses(a), "era %d: %s %s inside the field %s" % [era, names[i], a, f])
			for j: int in range(i + 1, names.size()):
				# The two Spirlings are the stage's business; everything else is the HUD's.
				if str(names[i]).ends_with("sprite") and str(names[j]).ends_with("sprite"):
					continue
				assert_false(a.intersects(rects[names[j]]), "era %d: %s %s and %s %s overlap" % [era, names[i], a, names[j], rects[names[j]]])

func test_formation_band_stays_above_the_foes() -> void:
	for era: int in range(1, 6):
		var w: float = (SCREENS[era] as Vector2).x
		var l: Dictionary = EraBattleHud.formation_layout(era, w, 7)
		var rects: Dictionary = {"ledger": EraBattleHud.plate_outer(era, l.ledger, false), "player team": l.player_team,
			"foe team": l.foe_team, "goal": l.goal}
		for i: int in (l.buttons as Array).size():
			rects["button %d" % i] = l.buttons[i]
		var names: Array = rects.keys()
		for i: int in names.size():
			var a: Rect2 = rects[names[i]]
			assert_true(a.position.x >= 0.0 and a.end.x <= w, "era %d: %s inside the screen" % [era, names[i]])
			assert_lte(a.end.y, float(EraBattleHud.FORMATION_TOP), "era %d: %s ends above the foes' rank" % [era, names[i]])
			for j: int in range(i + 1, names.size()):
				assert_false(a.intersects(rects[names[j]]), "era %d: %s and %s overlap" % [era, names[i], names[j]])

func test_menu_fits_the_phone_screen() -> void:
	for era: int in range(1, 6):
		var e: Dictionary = EraBattleHud.for_era(era)
		assert_lte(EraBattleHud.menu_height(era) + EraBattleHud.text_box_height(era), (SCREENS[era] as Vector2).y * 0.55, "era %d" % era)
		var lines: int = 2 if bool(e.art_detail) else 1
		assert_gte(int(e.art_h), lines * EraBattleHud.line_h(era) + 2, "era %d art row holds its text" % era)
	assert_lte(EraBattleHud.menu_height(1), CommandMenu.PANEL_HEIGHT, "Era I never takes more of the field than before")
	assert_gt(int(EraBattleHud.num(4, "art_h")), int(EraBattleHud.num(3, "art_h")) * 2 - 1, "Era IV: large touch rows")

func test_plate_rows_never_share_pixels() -> void:
	for era: int in range(1, 6):
		var r: Dictionary = EraBattleHud.plate_rows(era)
		assert_gt(int(r.bar_y), int(r.asc), "bar under the name")
		assert_gte(int(r.row3_y), int(r.bar_y) + int(r.bar_h) + 2, "Energy row under the bar")
		# The status tag stands from one pixel above the bar to just above the Energy row.
		assert_lte(int(r.bar_y) - 1 + int(r.asc) + 1, int(r.row3_y), "era %d status tag clear of the Energy row" % era)
		assert_gte(int(r.row4) - int(r.asc), int(r.row3_y) + int(r.row3_h), "numbers under the Energy row")
		assert_eq(EraBattleHud.plate_height(era, true), int(r.h_extra))

func test_stage_arrows_are_left_out_not_drawn_over() -> void:
	var entries: Array = [[5.0, 2], [5.0, -1], [5.0, 1]]
	assert_eq(InfoStrip.stages_that_fit(100.0, entries), 3)
	assert_eq(InfoStrip.stages_that_fit(27.0, entries), 2)
	assert_eq(InfoStrip.stages_that_fit(14.0, entries), 0)
	assert_eq(InfoStrip.stages_that_fit(0.0, entries), 0)

func test_slant_is_a_clean_stair() -> void:
	assert_eq(EraBattleHud.slant_inset(0, 30, 0), 0)
	assert_eq(EraBattleHud.slant_inset(0, 30, 6), 6)
	assert_eq(EraBattleHud.slant_inset(29, 30, 6), 0)
	var last: int = 6
	for y: int in 30:
		var v: int = EraBattleHud.slant_inset(y, 30, 6)
		assert_true(v <= last and last - v <= 1, "row %d steps by at most one pixel" % y)
		last = v
	assert_eq(EraBattleHud.plate_pad(4, true)[0] - EraBattleHud.plate_pad(4, false)[0], 6, "room for the leaning side")

func test_frames_per_era_and_shop_frame_wins() -> void:
	var seen: Dictionary = {}
	for era: int in range(1, 6):
		var img: Image = EraBattleHud.frame_image(EraBattleHud.text(era, "frame"), UITheme.BG, EraBattleHud.colours(era))
		assert_eq(img.get_size(), Vector2i(EraBattleHud.FRAME_SIZE, EraBattleHud.FRAME_SIZE))
		seen[img.get_data()] = true
		assert_eq(img.get_pixel(5, 5), UITheme.BG, "paper in the middle")
		assert_not_null(EraBattleHud.frame_style(era))
	assert_eq(seen.size(), 5, "five different frames")
	assert_true(EraBattleHud.frames_text_box(""))
	assert_false(EraBattleHud.frames_text_box("vine"), "a worn shop frame keeps its look")
	EraBattleHud.skin_override = 1
	assert_false(EraBattleHud.frames_text_box(""), "the menu skin frames the box itself")
	assert_gte(EraBattleHud.text_box_height(4), 3 * EraBattleHud.line_h(4) + 10)
	assert_eq(EraBattleHud.text_box_height(1), BattleScene.TEXT_BOX_HEIGHT)

func test_colours_keep_contrast() -> void:
	for era: int in range(1, 6):
		var c: Dictionary = EraBattleHud.colours(era)
		if EraBattleHud.flag(era, "plate_header"):
			assert_gte(UITheme.contrast(c.paper, c.accent), 4.5, "era %d name band" % era)
	for el: int in Elements.E.values():
		assert_gte(UITheme.contrast(UITheme.INK, EraBattleHud.art_fill(el)), 4.5, "ink on the %s button" % Elements.element_name(el))
	for st: String in ["scorch", "jolt", "chill", "daze"]:
		var badge: Color = EraBattleFeel.status_badge(3, st)
		assert_gte(UITheme.contrast(InfoStrip.badge_text(badge), badge), 3.0, st)
	assert_eq(InfoStrip.badge_text(Color.TRANSPARENT), UITheme.INK, "Era I: plain ink letters")
	UITheme.set_high_contrast(true)
	assert_eq(EraBattleHud.colours(4).accent, UITheme.MID, "high contrast wins over the era colours")
	UITheme.set_high_contrast(false)

func test_effect_hint_only_for_known_matchups_from_era_four() -> void:
	assert_eq(EraBattleHud.effect_hint(3, 2.0), "")
	assert_eq(EraBattleHud.effect_hint(4, 2.0), "Strong")
	assert_eq(EraBattleHud.effect_hint(4, 0.5), "Weak")
	assert_eq(EraBattleHud.effect_hint(5, 0.0), "No effect")
	assert_eq(EraBattleHud.effect_hint(5, 1.0), "")
	assert_eq(EraBattleHud.effect_hint(5, -1.0), "", "unknown foe: no hint")

func test_rolling_digits() -> void:
	var d: Array[Dictionary] = EraBattleHud.roll_digits(27.0, 3)
	assert_eq([int(d[0].digit), int(d[1].digit), int(d[2].digit)], [0, 2, 7])
	assert_eq(float(d[2].shift), 0.0)
	d = EraBattleHud.roll_digits(27.5, 3)
	assert_almost_eq(float(d[2].shift), 0.5, 0.001)
	assert_eq(int(d[2].next), 8)
	assert_eq(float(d[1].shift), 0.0, "the tens wait until the ones pass 9")
	d = EraBattleHud.roll_digits(29.5, 3)
	assert_almost_eq(float(d[1].shift), 0.5, 0.001, "tens turn with the ones from 9 to 0")
	assert_eq(int(d[1].next), 3)
	assert_eq(float(d[0].shift), 0.0)
	assert_eq(int(EraBattleHud.roll_digits(-4.0, 2)[1].digit), 0)

func test_growth_bar_jumps_early_and_runs_later() -> void:
	assert_false(InfoStrip.xp_animates(1, false), "Era I: no Growth bar animation")
	assert_false(InfoStrip.xp_animates(2, false))
	assert_true(InfoStrip.xp_animates(3, false))
	assert_false(InfoStrip.xp_animates(5, true), "reduced motion")
	assert_eq(InfoStrip.xp_target(9, 10, 0.3), 1.0, "fills up before the ring rise")
	assert_eq(InfoStrip.xp_target(10, 10, 0.3), 0.3)
	_era(1)
	var strip := InfoStrip.new()
	strip.show_xp = true
	add_child_autofree(strip)
	var s: Spirling = BattleFixtures.make("Mossling", 10)
	s.xp = Spirling.xp_for_level(10)
	strip.set_spirling(s)
	s.xp += (Spirling.xp_for_level(11) - Spirling.xp_for_level(10)) / 2
	strip.set_xp(s)
	assert_almost_eq(strip.xp_shown, strip.xp_frac, 0.001, "Era I jumps")
	_era(4)
	strip.set_spirling(s)
	s.xp = Spirling.xp_for_level(11) - 1
	strip.set_xp(s)
	assert_lt(strip.xp_shown, strip.xp_frac, "Era IV runs there")
	GameState.reduce_motion = true
	strip.set_xp(s)
	assert_almost_eq(strip.xp_shown, strip.xp_frac, 0.001, "reduced motion jumps")

func test_reduced_motion_stills_the_hud() -> void:
	assert_true(InfoStrip.slides(5, false))
	assert_false(InfoStrip.slides(5, true))
	assert_false(InfoStrip.slides(4, false))
	assert_true(LevelPanel.counts(4, false))
	assert_false(LevelPanel.counts(4, true))
	assert_false(LevelPanel.counts(3, false))
	assert_gt(InfoStrip.slide_from(100.0, true), 0.0, "a plate on the right glides in from the right")
	assert_lt(InfoStrip.slide_from(100.0, false), 0.0)

func test_plates_lean_after_the_camera() -> void:
	assert_eq(EraBattleHud.camera_shift(Vector2(100, 100), Vector2.ONE, Vector2(200, 50), 0.35), Vector2.ZERO)
	assert_eq(EraBattleHud.camera_shift(Vector2(100, 100), Vector2(1.2, 1.2), Vector2(200, 50), 0.0), Vector2.ZERO)
	var shift: Vector2 = EraBattleHud.camera_shift(Vector2(100, 100), Vector2(1.2, 1.2), Vector2(200, 50), 0.35)
	assert_eq(shift, Vector2(7, -4), "a share of the way the field moved there, in whole pixels")

func test_marks_and_plate_on_a_strip() -> void:
	_era(2)
	var keep: Dictionary = GameState.spirlog.duplicate(true)
	var foe: Spirling = BattleFixtures.make("Zippit", 7)
	GameState.spirlog[foe.data.species_name] = {"seen": true, "bonded": true}
	foe.gleam = true
	var strip := InfoStrip.new()
	strip.size = Vector2(72, EraBattleHud.plate_height(2, false))
	add_child_autofree(strip)
	strip.set_spirling(foe)
	assert_true(strip.caught, "bonded before")
	assert_true(strip.spark)
	assert_false(strip.icons_by_name(), "narrow plate: symbols move to the Energy row")
	strip.show_xp = true
	strip.set_spirling(foe)
	assert_false(strip.caught, "never on the player's own plate")
	GameState.spirlog = keep
	strip.size.x = 120
	assert_true(strip.icons_by_name())
	for era: int in range(1, 6):
		_era(era)
		strip.set_spirling(foe)
		strip.status = "jolt"
		strip.stages = {"atk": 2, "spd": -1} as Dictionary[String, int]
		strip.tax = 2
		strip.show_numbers = true
		strip.queue_redraw()
		await get_tree().process_frame
		assert_eq(strip.era, era)
		assert_true(strip.plate_rect().encloses(Rect2(strip.position, strip.size)))

func test_team_row_states() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 9)
	assert_eq(EraBattleHud.team_state(s), "fit")
	s.hp = s.max_hp() / 2
	assert_eq(EraBattleHud.team_state(s), "hurt")
	s.status = "scorch"
	assert_eq(EraBattleHud.team_state(s), "status")
	s.hp = 0
	assert_eq(EraBattleHud.team_state(s), "down")
	assert_eq(EraBattleHud.team_state(null), "down")
	assert_eq(EraBattleHud.team_colour(1, "hurt"), UITheme.INK, "Era I: ink only")
	assert_ne(EraBattleHud.team_colour(2, "fit"), EraBattleHud.team_colour(2, "hurt"))
	assert_eq(EraBattleHud.team_colour(2, "status", "scorch"), EraBattleHud.team_colour(2, "hurt"), "Era II: no status colour yet")
	assert_eq(EraBattleHud.team_colour(3, "status", "scorch"), EraBattleFeel.status_badge(3, "scorch"))
	assert_true(BattleHud.shows_team(true, BattleModel.Side.PLAYER, 3))
	assert_false(BattleHud.shows_team(true, BattleModel.Side.FOE, 3), "wild Spirlings show no team row")
	assert_true(BattleHud.shows_team(false, BattleModel.Side.FOE, 3))
	assert_false(BattleHud.shows_team(false, BattleModel.Side.PLAYER, 1))
	for era: int in range(1, 6):
		_era(era)
		var row := TeamRow.new()
		row.era = era
		add_child_autofree(row)
		var fit: Spirling = BattleFixtures.make("Puddlet", 9)
		row.set_party([fit, s])
		assert_eq(row.standing(), 1)
		assert_string_contains(row.screen_reader_text(), "1")
		assert_ne(EraBattleHud.text(era, "team_shape"), "circle", "never a round mark (LEGAL.md)")
		assert_eq(EraBattleHud.team_row_size(era, 2).y, float(row.mark_size()))
		await get_tree().process_frame

func test_ring_rise_rows() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 14)
	var rows: Array[Dictionary] = EraBattleHud.stat_rows(s, 13, 14)
	assert_eq(s.level, 14, "the Spirling is left as it was")
	assert_eq(rows.size(), 5)
	assert_eq(str(rows[0].label), "Vigor")
	assert_eq(int(rows[0]["new"]), s.max_hp())
	assert_eq(int(rows[1]["new"]), s.atk())
	for r: Dictionary in rows:
		assert_gte(int(r.gain), 0)
		assert_eq(int(r.old) + int(r.gain), int(r["new"]))
	for era: int in range(1, 6):
		_era(era)
		GameState.reduce_motion = true
		var panel := LevelPanel.new()
		add_child_autofree(panel)
		panel.max_width = (SCREENS[era] as Vector2).x - 6
		panel.show_rise(s, 13, 14)
		assert_eq(panel.progress, 1.0)
		assert_lte(panel.size.y, float(EraBattleHud.menu_height(era)) - 6.0, "era %d: fits the command panel" % era)
		assert_lte(panel.size.x, panel.max_width)
		assert_string_contains(panel.screen_reader_text(), "R13 > R14")
		var spot: Vector2 = BattleHud.level_spot(Rect2(3, 200, 138, 72), panel.size)
		assert_true(Rect2(3, 200, 138, 72).encloses(Rect2(spot, panel.size)) or panel.size.y > 72.0)
		await get_tree().process_frame

func test_item_shortcut() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 9)] as Array[Spirling], [BattleFixtures.make("Zippit", 7)] as Array[Spirling], true, 3)
	m.inventory = {"tonic": 2}
	assert_eq(CommandMenu.shortcut_item(m, ""), "")
	assert_eq(CommandMenu.shortcut_item(m, "tonic"), "tonic")
	assert_eq(CommandMenu.shortcut_item(m, "remedy"), "", "not in the bag")
	assert_eq(CommandMenu.shortcut_item(null, "tonic"), "")
	EraBattleHud.last_item = ""
	BattleHud.note_item("tonic")
	assert_eq(EraBattleHud.last_item, "tonic")
	BattleHud.note_item("no_such_item")
	assert_eq(EraBattleHud.last_item, "tonic", "only items usable in battle are remembered")

func test_command_menu_builds_in_every_era() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 9)] as Array[Spirling], [BattleFixtures.make("Zippit", 7)] as Array[Spirling], true, 3)
	m.inventory = {"tonic": 2}
	m.start()
	EraBattleHud.last_item = "tonic"
	for era: int in range(1, 6):
		_era(era)
		var menu := CommandMenu.new()
		add_child_autofree(menu)
		menu.size = Vector2((SCREENS[era] as Vector2).x, 0)
		menu.refresh(m, 0)
		await get_tree().process_frame
		assert_eq(menu.era, era)
		assert_eq(menu.mode, EraBattleHud.text(era, "menu"))
		assert_eq(menu.custom_minimum_size.y, float(EraBattleHud.menu_height(era)))
		assert_eq(menu._move_buttons.size(), Spirling.MAX_MOVES, "one column of arts, never a grid")
		assert_true(menu._move_buttons[0].get_parent() is VBoxContainer)
		assert_eq(menu._swap.get_parent() is GridContainer, era == 1, "only Era I sets the commands two by two")
		assert_eq(menu._shortcut != null, era >= 4)
		if era >= 4:
			assert_false(menu._shortcut.disabled)
			assert_string_contains(menu._shortcut.text, "x2")
			assert_string_contains(menu._move_buttons[0].text, "\n", "Era IV on: the element's name under the art")
		assert_lte(menu.get_combined_minimum_size().x, (SCREENS[era] as Vector2).x, "era %d: never wider than the screen" % era)
		menu.open_info(0)
		assert_true(menu.is_info_open())
		assert_eq(menu._info_head.visible, era == 5, "Era V: the richer info card")
		menu.close_info()
		menu._hold.free()

func test_bond_screen_keeps_the_rules_out() -> void:
	for era: int in range(1, 6):
		var g := BondMinigame.new()
		add_child_autofree(g)
		g.era = era
		g.size = SCREENS[era]
		assert_gte(g.mark_size(), BondMinigame.MARK_SIZE, "era %d marks never smaller" % era)
		# Three marks side by side with room between them.
		assert_lt(g.mark_size() * 1.5, g.size.x / float(BondEcho.MARKS + 1) * 2.0)
		assert_eq(g._mark_at_point(g._mark_center(1)), 1)
	assert_eq(BondMinigame.mark_fill(1, 0, true), UITheme.INK, "Era I: ink")
	assert_ne(BondMinigame.mark_fill(2, 0, true), BondMinigame.mark_fill(2, 1, true), "Era II: each mark its own colour")
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/BondMinigame.gd")
	for word: String in ["percent", "odds_", "chance_"]:
		assert_false(src.contains(word), "no odds on the Echo call screen")

func test_german_hud_words() -> void:
	var de: PatternTranslation = Loc.load_translation("de")
	for key: String in ["Strong", "Weak", "No effect", "Again: -", "Your team", "Foe's team"]:
		assert_ne(de.lookup(key), "", key)
	assert_eq(de.lookup("Again: %s x%d" % ["Tonic", 3]).count("x3"), 1)
