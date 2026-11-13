extends GutTest
## docs/KAMPF_PLAN_1000.md, "Tempo, Animation und Praesentation" and "Audio im Kampf" (batch
## k09b): boss size (655), report card and the battle's star (661, 20), photo mode in battle
## (662), effect budget (664), high-contrast effects (669), damage numbers (671, 672), Energy pip
## animation (674), field ambience (684), music dip under battle text (695) and the battle
## themes for night, festival, Weekly Echo, tower and online duels (713-717).

const FOE_TAG: float = 6.0
const PLAYER_TAG: float = 14.0

var _settings: Dictionary
var _hc: bool

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	_hc = UITheme.high_contrast

func after_each() -> void:
	GameState.settings_from_dict(_settings)
	UITheme.set_high_contrast(_hc)
	Sound.duck_music(false)

func _scene() -> BattleScene:
	var b := BattleScene.new()
	b._build()
	b.model = BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Mossling", 10)] as Array[Spirling], false, 5, 1)
	b.model.start()
	return b

func _free(b: BattleScene) -> void:
	b._menu._hold.free()
	b.free()

# --- 655 boss size ---------------------------------------------------------------------------

func test_a_lone_boss_grows_to_its_era_size_from_the_top_right() -> void:
	var slot := Rect2(Vector2(110, 44), Vector2(28, 28))
	var r: Rect2 = BattleShow.boss_rect(slot, 1, 999.0)
	assert_eq(r.size, Vector2(56, 56), "Era I draws the boss at its art's own size")
	assert_eq(r.position.y, slot.position.y, "the top stays under the ledger")
	assert_eq(r.end.x, slot.end.x, "the right edge stays")
	assert_eq(BattleShow.boss_rect(slot, 4, 999.0), slot, "Era IV keeps its stage")
	assert_eq(BattleShow.boss_rect(slot, 1, 60.0), slot, "never smaller than the slot")
	assert_eq(BattleShow.boss_rect(slot, 1, 84.0).size, Vector2(40, 40), "stops at the player's rank")

func test_the_bigger_boss_never_runs_into_the_players_rank() -> void:
	var field := Vector2(144, 110)
	for np: int in range(1, 5):
		var foe: Rect2 = BattleScene.formation_slots(1, BattleModel.Side.FOE, 1, field, FOE_TAG, np, PLAYER_TAG)[0]
		var mine: Array[Rect2] = BattleScene.formation_slots(1, BattleModel.Side.PLAYER, np, field, PLAYER_TAG, 1, FOE_TAG)
		var big: Rect2 = BattleShow.boss_rect(foe, 1, mine[0].position.y - FOE_TAG - 6)
		assert_gte(big.size.x, foe.size.x)
		var tag := Rect2(big.position + Vector2(-1, big.size.y + 2), Vector2(MiniStrip.WIDTH, FOE_TAG))
		for r: Rect2 in mine:
			assert_false(big.intersects(r), "%d of mine" % np)
			assert_false(tag.intersects(r), "tag, %d of mine" % np)

# --- 661 / 20 report card --------------------------------------------------------------------

func test_report_names_the_star_of_the_battle() -> void:
	var r: Dictionary = BattleInfo.new_report()
	var hit := func(amount: int) -> BattleEvent: return BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "amount": amount})
	BattleInfo.count(r, hit.call(12), "Bowl Over", "Kindlop")
	BattleInfo.count(r, hit.call(30), "Cinder Breath", "Puddlet")
	BattleInfo.count(r, hit.call(10), "Bowl Over", "Kindlop")
	BattleInfo.count(r, BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "amount": 99, "status_tick": true}), "Bowl Over", "Kindlop")
	assert_eq(BattleInfo.star_of(r), "Puddlet", "a status tick is no one's hit")
	var lines: Array[String] = BattleShow.outro_lines(r, 4)
	assert_eq(lines[0], Loc.t("Battle report"))
	assert_has(lines, Loc.t("Star of the battle: %s") % "Puddlet")
	assert_eq(BattleInfo.star_of(BattleInfo.new_report()), "")

func test_report_card_time_follows_the_battle_speed() -> void:
	assert_gt(BattleShow.outro_time(1.0), 0.0)
	assert_almost_eq(BattleShow.outro_time(2.0), BattleShow.outro_time(1.0) / 2.0, 0.001)

# --- 662 photo mode --------------------------------------------------------------------------

func test_battle_log_offers_the_photo_mode() -> void:
	var b: BattleScene = _scene()
	var button: Button = b._log_panel.find_child("photo_button", true, false)
	assert_not_null(button)
	assert_eq(button.text, "Take a photo")
	_free(b)

func test_photo_mode_over_buttons_takes_every_tap() -> void:
	var p := PhotoMode.new()
	p.capture_gui = true
	add_child_autofree(p)
	assert_eq(p._overlay.mouse_filter, Control.MOUSE_FILTER_STOP)
	var q := PhotoMode.new()
	add_child_autofree(q)
	assert_eq(q._overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the overworld keeps its taps")

# --- 664 effect budget -----------------------------------------------------------------------

func test_effects_redraw_less_often_on_phones_and_in_battery_saver() -> void:
	assert_eq(BattleShow.fx_fps(false, false), 0, "every frame on a desktop")
	assert_gt(BattleShow.fx_fps(true, false), 0)
	assert_eq(BattleShow.fx_fps(false, true), BattleShow.fx_fps(true, false))
	assert_true(BattleShow.fx_redraw(0.01, -1.0, 30), "the first frame draws")
	assert_false(BattleShow.fx_redraw(0.02, 0.01, 30), "same step")
	assert_true(BattleShow.fx_redraw(0.04, 0.01, 30), "next step")
	assert_true(BattleShow.fx_redraw(0.02, 0.01, 0))

func test_effects_keep_their_particles_within_the_budget() -> void:
	var cap: int = int(BattleShow.cfg().fx_budget.max_particles)
	assert_eq(BattleShow.fx_particles(3), 3)
	assert_eq(BattleShow.fx_particles(0), 1)
	assert_eq(BattleShow.fx_particles(999), cap)
	var fx := ElementFx.new()
	fx.amount = 2.0
	assert_lte(fx._n(7), cap, "the strongest art stays inside")
	fx.free()

# --- 669 high contrast -----------------------------------------------------------------------

func test_high_contrast_effects_use_ink_and_accent() -> void:
	UITheme.set_high_contrast(true)
	var fx := ElementFx.new()
	fx.feel = {"colour": true}
	assert_eq(fx._ink(0), UITheme.INK)
	assert_eq(fx._ink(3), UITheme.ACCENT)
	assert_gte(UITheme.contrast(ElementFx.hc_ink(0), UITheme.BG), 15.0)
	UITheme.set_high_contrast(false)
	assert_ne(fx._ink(0), Color.BLACK, "the era colours come back")
	fx.free()

# --- 671 / 672 damage numbers ----------------------------------------------------------------

func test_damage_numbers_are_optional_and_off_by_default() -> void:
	var hit := BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "slot": 0, "amount": 23})
	assert_eq(BattleShow.damage_number(hit, false), "")
	assert_eq(BattleShow.damage_number(hit, true), "23")
	assert_eq(BattleShow.damage_number(BattleEvent.new(BattleEvent.Type.DAMAGE, {"amount": 0}), true), "")
	assert_eq(BattleShow.damage_number(BattleEvent.new(BattleEvent.Type.HEAL, {"amount": 5}), true), "")
	GameState.settings_from_dict({})
	assert_false(GameState.damage_numbers)
	GameState.damage_numbers = true
	assert_true(bool(GameState.settings_to_dict().damage_numbers))

func test_damage_numbers_have_a_settings_row() -> void:
	var keys: Array = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_has(keys, "damage_numbers")
	assert_true(MenuHost.SETTING_HINTS.has("damage_numbers"))

func test_scene_counts_damage_numbers_only_when_on() -> void:
	var b: BattleScene = _scene()
	var hit := BattleEvent.new(BattleEvent.Type.DAMAGE, {"side": 1, "slot": 0, "amount": 9, "status_tick": true})
	GameState.damage_numbers = false
	b._show.on_event(hit)
	assert_eq(b._show.numbers.size(), 0)
	GameState.damage_numbers = true
	b._show.on_event(hit)
	assert_eq(b._show.numbers, ["9"] as Array[String])
	_free(b)

# --- 674 Energy pips -------------------------------------------------------------------------

func test_gained_pips_pop_and_spent_pips_fade() -> void:
	assert_eq(int(InfoStrip.pip_look(3, 4, 3, 0.9).grow), 1, "a new pip pops")
	assert_eq(int(InfoStrip.pip_look(3, 4, 3, 0.3).grow), 0, "and settles")
	assert_eq(int(InfoStrip.pip_look(1, 4, 3, 0.9).grow), 0, "old pips stay still")
	var spent: Dictionary = InfoStrip.pip_look(5, 4, 7, 0.5)
	assert_true(bool(spent.fill))
	assert_almost_eq(float(spent.alpha), 0.5, 0.001)
	assert_false(bool(InfoStrip.pip_look(5, 4, 7, 0.0).fill), "gone once the fade ends")
	assert_false(bool(InfoStrip.pip_look(8, 4, 7, 0.5).fill), "never more than it had")

# --- 684 field ambience ----------------------------------------------------------------------

func test_every_field_lays_an_ambience_that_exists() -> void:
	for f: String in BattleRules.FIELDS:
		var loop: String = BattleShow.field_ambience(f)
		assert_false(loop.is_empty(), f)
		assert_true(ResourceLoader.exists(Sound.AMBIENCE_DIR % loop), "%s: %s" % [f, loop])
	assert_eq(BattleShow.field_ambience("nonsense"), "")

func test_scene_field_ambience_comes_and_goes() -> void:
	var b: BattleScene = _scene()
	var before: String = Sound.current_ambience
	var f: String = BattleRules.FIELDS.keys()[0]
	b._show.on_event(BattleEvent.new(BattleEvent.Type.FIELD, {"field": f}))
	assert_eq(Sound.current_ambience, BattleShow.field_ambience(f))
	assert_true(Sound.ambience_ducked, "kept low under the battle")
	b._show.on_event(BattleEvent.new(BattleEvent.Type.FIELD_END, {"field": f}))
	assert_eq(Sound.current_ambience, before)
	_free(b)
	Sound.ambience(before)

# --- 695 music dip ---------------------------------------------------------------------------

func test_music_dips_while_battle_text_shows() -> void:
	assert_lt(BattleAudio.text_duck_db(true), 0.0)
	assert_eq(BattleAudio.text_duck_db(false), 0.0)
	Sound.duck_music(true)
	assert_eq(Sound.music_duck_db, BattleAudio.text_duck_db(true))
	Sound.duck_music(false)
	assert_eq(Sound.music_duck_db, 0.0)
	var b: BattleScene = _scene()
	assert_true(b._text.duck_music, "the battle's text box dips the music")
	_free(b)
	var box := TextBox.new()
	assert_false(box.duck_music, "talk in the world does not")
	box.free()

# --- 713-717 battle themes -------------------------------------------------------------------

func test_battle_themes_by_time_and_place() -> void:
	assert_eq(BattleAudio.theme("", true, true, true), "warden", "a Warden keeps its own")
	assert_eq(BattleAudio.theme("echo", false, true, true), "battle_echo")
	assert_eq(BattleAudio.theme("tower", false, false, false), "battle_tower")
	assert_eq(BattleAudio.theme("duel", false, false, true), "battle_duel")
	assert_eq(BattleAudio.theme("", false, true, true), "battle_fest", "the festival before the night")
	assert_eq(BattleAudio.theme("", false, false, true), "battle_night")
	assert_eq(BattleAudio.theme("", false, false, false), "battle")
	assert_eq(BattleAudio.theme("nonsense", false, false, false), "battle")

func test_every_theme_exists_and_counts_as_battle_music() -> void:
	var listed: Array[String] = []
	for v: Variant in (BattleAudio.cfg().themes as Dictionary).values():
		listed.append(str(v))
	listed.sort()
	var known: Array[String] = BattleAudio.THEMES.duplicate()
	known.sort()
	assert_eq(listed, known)
	for t: String in known:
		assert_true(ResourceLoader.exists(Sound.MUSIC_DIR % t), t)
		assert_true(MusicDirector.is_battle_track(t), t)
		assert_eq(BattleScene.pinch_track(null, t), t)
