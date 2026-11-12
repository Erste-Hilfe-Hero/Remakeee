extends GutTest
## Battle presentation per era (data/era_battle_feel.json, docs/ERA_FEEL_BATTLE.md).

const LISTS: Dictionary = {
	"intro": "intro_styles", "entrance": "entrance_styles", "idle": "idle_levels",
	"hit": "hit_styles", "faint": "faint_styles", "hp_drain": "hp_drain_styles",
}
const TERRAINS: Array[String] = ["field", "lake", "ridge", "ember", "voice"]

var _keep: Array[int] = []
var _settings: Dictionary

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)
	Juice.in_battle = false

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

func test_config_complete_for_all_five_eras() -> void:
	var keys: Array = EraBattleFeel.for_era(1).keys()
	assert_gt(keys.size(), 20)
	for e: int in range(1, EraBattleFeel.ERAS + 1):
		var d: Dictionary = EraBattleFeel.for_era(e)
		for k: Variant in keys:
			assert_true(d.has(k), "era %d has %s" % [e, k])
		for k: String in LISTS:
			assert_gt(EraBattleFeel.rank(LISTS[k], str(d[k])), -1, "era %d %s '%s' is a known style" % [e, k, d[k]])
		assert_true((EraBattleFeel.cfg().cameras as Dictionary).has(str(d.camera)), "era %d camera" % e)
	assert_eq(EraBattleFeel.for_era(9), EraBattleFeel.for_era(5), "eras past V use V")

func test_each_era_opens_its_own_way() -> void:
	var seen: Dictionary = {}
	for e: int in range(1, 6):
		seen[EraBattleFeel.text(e, "intro")] = true
		assert_true(EraBattleFeel.text(e, "intro") in BattleIntro.STYLES)
	assert_eq(seen.size(), 5, "five different openings")

func test_later_eras_never_have_fewer_features() -> void:
	for e: int in range(2, 6):
		var a: Dictionary = EraBattleFeel.for_era(e - 1)
		var b: Dictionary = EraBattleFeel.for_era(e)
		assert_gte(EraBattleFeel.feature_score(e), EraBattleFeel.feature_score(e - 1), "score era %d" % e)
		for k: String in ["intro", "entrance", "idle", "hit", "faint", "hp_drain"]:
			assert_gte(EraBattleFeel.rank(LISTS[k], str(b[k])), EraBattleFeel.rank(LISTS[k], str(a[k])), "%s era %d" % [k, e])
		assert_gte(int(b.fx_tier), int(a.fx_tier), "fx tier era %d" % e)
		assert_gte(int(b.level_glints), int(a.level_glints))
		assert_gte(float(b.fx_tint), float(a.fx_tint))
		for k: String in ["shadow", "parallax", "fx_colour", "fx_trail", "fx_dust"]:
			assert_true(bool(b[k]) or not bool(a[k]), "%s stays on in era %d" % [k, e])
		assert_true(EraBattleFeel.camera_on(e) or not EraBattleFeel.camera_on(e - 1))
	assert_gt(EraBattleFeel.feature_score(5), EraBattleFeel.feature_score(1))

func test_idle_levels_follow_the_owner_plan() -> void:
	assert_eq(EraBattleFeel.text(1, "idle"), "none")
	assert_eq(EraBattleFeel.text(2, "idle"), "entrance")
	assert_eq(EraBattleFeel.text(3, "idle"), "entrance_flash")
	assert_eq(EraBattleFeel.text(4, "idle"), "breath")
	assert_eq(EraBattleFeel.text(5, "idle"), "loop")
	for e: int in [1, 2, 3]:
		assert_false(EraBattleFeel.idles(e), "era %d stands still" % e)
	assert_true(EraBattleFeel.idles(4))
	assert_true(BattleAnim.enabled_for(5), "Era V loops its strip")
	assert_true(EraBattleFeel.silhouette_hit(3))
	assert_false(EraBattleFeel.silhouette_hit(1))

func test_camera_fixed_until_four_then_pans_then_follows() -> void:
	for e: int in [1, 2, 3]:
		assert_false(EraBattleFeel.camera_on(e))
	var pan: Dictionary = EraBattleFeel.camera(4)
	var dyn: Dictionary = EraBattleFeel.camera(5)
	assert_gt(float(pan.zoom), 1.0)
	assert_gt(float(dyn.zoom), float(pan.zoom), "Era V moves more than Era IV")
	var f: Dictionary = BattleCamera.focus(Vector2(270, 200), Rect2(10, 120, 60, 60), Rect2(200, 20, 60, 60), 4)
	assert_almost_eq(f.scale.x, float(pan.zoom), 0.001)

func test_every_move_resolves_to_an_animation_in_every_era() -> void:
	Database.load_all()
	var styles: Array = EraBattleFeel.cfg().move_styles
	var used: Dictionary = {}
	assert_gte(Database.moves.size(), 190)
	for mv: MoveData in Database.moves.values():
		for e: int in range(1, 6):
			var a: Dictionary = EraBattleFeel.move_anim(mv, e)
			assert_true(str(a.style) in styles, "%s era %d style %s" % [mv.move_name, e, a.style])
			assert_between(int(a.element), 0, Elements.E.size() - 1, mv.move_name)
			assert_eq(int(a.tier), int(EraBattleFeel.num(e, "fx_tier")), mv.move_name)
			used[a.style] = true
	assert_gte(used.size(), 9, "the arts spread over most styles")

func test_move_style_words() -> void:
	Database.load_all()
	var expect: Dictionary = {"Salt Spray": "wave", "Glowglass Slash": "slash", "Bloom Burst": "burst",
		"Cinder Nip": "bite", "Arc Bolt": "beam", "Slow Quake": "quake", "Thorn Volley": "volley",
		"Furnace Spiral": "spiral", "Hush": "aura", "Bowl Over": "strike"}
	for n: String in expect:
		var mv: MoveData = Database.move(n)
		assert_not_null(mv, n)
		if mv != null:
			assert_eq(EraBattleFeel.move_style(mv), expect[n], n)

func test_every_style_draws_in_every_tier() -> void:
	var fx := ElementFx.new()
	fx.size = Vector2(144, 120)
	add_child_autofree(fx)
	GameState.battle_speed = 2
	Juice.in_battle = true
	for st: Variant in EraBattleFeel.cfg().move_styles:
		for e: int in [1, 3, 5]:
			fx.feel = {"style": st, "tier": e, "colour": e > 1, "tint": 0.2 if e > 3 else 0.0, "trail": e == 5, "dust": e > 3}
			await fx.play(Elements.E.EMBER, MoveData.Kind.FOCUS, Rect2(90, 70, 40, 40), Rect2(20, 10, 40, 40))
			assert_eq(fx.phase, ElementFx.Phase.NONE, "%s tier %d" % [st, e])
	Juice.in_battle = false
	fx.feel = {}
	assert_eq(fx.get_child_count(), 0)

func test_colour_fx_from_era_two() -> void:
	var fx := ElementFx.new()
	fx.element = Elements.E.TIDE
	assert_eq(fx._ink(2), EraManager.INK_PALETTE[2], "Era I draws in the inks")
	fx.feel = EraBattleFeel.move_anim(null, 2)
	assert_eq(fx._ink(2), Elements.color(Elements.E.TIDE))
	assert_ne(ElementFx.shade(Color.RED, 0), ElementFx.shade(Color.RED, 3))
	fx.free()

func test_intro_patterns_cover_then_clear() -> void:
	var cols: int = 18
	var rows: int = 32
	for st: String in BattleIntro.STYLES:
		var last: int = cols * rows + 1
		for p: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var n: int = 0
			for y: int in rows:
				for x: int in cols:
					n += 1 if BattleIntro.covered(st, p, x, y, cols, rows) else 0
			assert_lte(n, last, "%s never covers again at %.2f" % [st, p])
			if p == 0.0:
				assert_eq(n, cols * rows, st + " starts covered")
			if p == 1.0:
				assert_eq(n, 0, st + " ends clear")
			last = n

func test_spiral_order_is_a_full_sequence() -> void:
	var seen: Dictionary = {}
	for y: int in 9:
		for x: int in 6:
			seen[BattleIntro.spiral_index(x, y, 6, 9)] = true
	assert_eq(seen.size(), 54)
	assert_eq(BattleIntro.spiral_index(0, 0, 6, 9), 0, "the corner clears first")

func test_intro_pulses_stay_under_three_a_second() -> void:
	assert_lte(1.0 / BattleIntro.FLASH_PERIOD, 3.0)
	assert_lte(float(EraBattleFeel.cfg().intro_flash_alpha), 0.5)
	for e: int in range(1, 6):
		assert_lte(int(EraBattleFeel.num(e, "intro_flashes")), 3)

func test_intro_plays_and_frees_itself() -> void:
	_era(3)
	GameState.battle_speed = 2
	Juice.in_battle = true
	var host := Control.new()
	host.size = Vector2(144, 120)
	add_child_autofree(host)
	var c := BattleIntro.new()
	host.add_child(c)
	await c.play(3)
	Juice.in_battle = false
	assert_eq(c.style, "shutter")
	assert_true(c.is_queued_for_deletion())

func test_hp_drain_steps_then_eases() -> void:
	assert_almost_eq(EraBattleFeel.hp_drain_time(1, 1.0, 0.5, 0.4), 0.5 * EraBattleFeel.num(1, "hp_step_time"), 0.001)
	assert_gt(EraBattleFeel.hp_drain_time(1, 1.0, 0.0, 0.4), EraBattleFeel.hp_drain_time(1, 1.0, 0.8, 0.4), "a bigger hit drains longer")
	assert_eq(EraBattleFeel.hp_drain_time(4, 1.0, 0.0, 0.4), 0.4)
	assert_true(EraBattleFeel.hp_steps(1))
	assert_false(EraBattleFeel.hp_steps(3))

func test_backdrop_colours_per_terrain() -> void:
	for e: int in [2, 3]:
		for t: String in TERRAINS:
			var c: Dictionary = EraBattleFeel.backdrop_colours(e, t)
			for k: String in ["bg", "sky", "ink", "mid", "accent"]:
				assert_true(c.has(k), "era %d %s %s" % [e, t, k])
	assert_true(EraBattleFeel.backdrop_colours(3, "field").has("sky_low"), "Era III sky has two tones")
	assert_true(EraBattleFeel.backdrop_colours(1, "field").is_empty(), "Era I keeps the inks")

func test_backdrop_takes_era_colours() -> void:
	_era(2)
	var b := BattleBackdrop.new()
	b.set_scene("lake", Rect2(), Rect2())
	assert_eq(b._mid, Color(str(EraBattleFeel.backdrop_colours(2, "lake").mid)))
	_era(1)
	b.set_scene("lake", Rect2(), Rect2())
	assert_eq(b._mid, UITheme.MID)
	b.free()

func test_stage_takes_terrain_colours() -> void:
	var lake: Dictionary = EraManager.stage_colors("", "lake")
	assert_eq(str(lake.floor_near), str(EraBattleFeel.stage_terrain("lake").floor_near))
	assert_eq(str(EraManager.stage_colors("", "field").floor_near), str(EraManager.stage_config().colors.floor_near))
	assert_eq(str(EraManager.stage_colors("halcyra", "lake").sky_low), str(EraManager.stage_colors("halcyra").sky_low), "the region look stays on top")

func test_breath_scale_two_steps() -> void:
	assert_eq(SpirlingSprite.breath_scale(0.1, 1.6, 0.04), Vector2.ONE)
	assert_eq(SpirlingSprite.breath_scale(1.0, 1.6, 0.04), Vector2(1.04, 0.96))
	assert_eq(SpirlingSprite.breath_scale(1.0, 1.6, 0.0), Vector2.ONE)

func _sprite() -> SpirlingSprite:
	var sp := SpirlingSprite.new()
	sp.size = Vector2(56, 56)
	sp.position = Vector2(40, 20)
	add_child_autofree(sp)
	sp.setup(Spirling.new(Database.species("Mossling"), 10), "front")
	return sp

func test_entrance_and_faint_land_home_in_every_era() -> void:
	GameState.battle_speed = 2
	Juice.in_battle = true
	for e: int in range(1, 6):
		_era(e)
		var sp := _sprite()
		await sp.step_out(false)
		assert_eq(sp.position, Vector2(40, 20), "era %d entrance lands home" % e)
		assert_eq(sp.draw_scale, Vector2.ONE, "era %d ends at full size" % e)
		assert_eq(sp.flash_amount, 0.0)
		await sp.faint()
		assert_false(sp.visible, "era %d faint hides" % e)
		assert_eq(sp.position, Vector2(40, 20))
	Juice.in_battle = false

func test_hit_flash_ends_clean_in_every_era() -> void:
	GameState.battle_speed = 2
	Juice.in_battle = true
	for e: int in range(1, 5):
		_era(e)
		var sp := _sprite()
		await sp.hit_flash()
		assert_true(sp.visible)
		assert_eq(sp.flash_amount, 0.0, "era %d" % e)
	Juice.in_battle = false

func test_silhouette_is_flat_white() -> void:
	var path: String = EraManager.sprite_path("Mossling")
	if path.is_empty():
		pass_test("no sprite art")
		return
	var img: Image = SpirlingSprite.silhouette_texture(path).get_image()
	var col := Color(str(BattleAnim.config().flash_color))
	var found: bool = false
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a >= 1.0:
				assert_true(Color(p, 1.0).is_equal_approx(col))
				found = true
				return
	assert_true(found)

func test_shake_grows_with_the_era() -> void:
	for e: int in range(2, 6):
		assert_gte(EraBattleFeel.shake(e), EraBattleFeel.shake(e - 1))
	_era(1)
	assert_lt(BattleScene.era_trauma(1.0), 1.0, "Era I shakes less")

func test_era_manager_helper() -> void:
	_era(4)
	assert_eq(str(EraManager.battle_feel("intro")), "iris")
	assert_eq(EraManager.battle_feel("nope", 7), 7)

# --- Slice 2: later-era elements, unfurl, status badges, Era V idle for every Spirling ----

func test_every_element_has_its_own_drawing_and_ends_clean() -> void:
	var fx := ElementFx.new()
	fx.size = Vector2(270, 200)
	add_child_autofree(fx)
	GameState.battle_speed = 2
	Juice.in_battle = true
	for e: int in Elements.E.size():
		for tier: int in [1, 5]:
			fx.feel = EraBattleFeel.move_anim(null, tier)
			for kind: int in [MoveData.Kind.PHYSICAL, MoveData.Kind.FOCUS]:
				await fx.play(e, kind, Rect2(180, 120, 60, 60), Rect2(30, 20, 60, 60))
				assert_eq(fx.phase, ElementFx.Phase.NONE, "%s tier %d" % [Elements.E.keys()[e], tier])
	Juice.in_battle = false
	assert_eq(fx.get_child_count(), 0)

func test_later_elements_no_longer_borrow() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/ElementFx.gd")
	for n: String in ["ink", "echo", "rust", "mask", "acid", "frost", "gilt", "zenith"]:
		assert_true(("func _draw_%s()" % n) in src, n)
		assert_true(("Elements.E.%s: _draw_%s()" % [n.to_upper(), n]) in src, n)

func test_unfurl_style_per_era_grows() -> void:
	for e: int in range(1, 6):
		assert_gt(EraBattleFeel.rank("unfurl_styles", EraBattleFeel.text(e, "unfurl")), -1, "era %d" % e)
		if e > 1:
			assert_gt(EraBattleFeel.rank("unfurl_styles", EraBattleFeel.text(e, "unfurl")), EraBattleFeel.rank("unfurl_styles", EraBattleFeel.text(e - 1, "unfurl")))
			assert_gte(UnfurlSequence.sprite_size(e), UnfurlSequence.sprite_size(e - 1))
	assert_eq(UnfurlSequence.sprite_size(1), UnfurlSequence.SPRITE_SIZE)

func test_unfurl_plays_in_every_era() -> void:
	Database.load_all()
	GameState.reduce_motion = true
	for e: int in range(1, 6):
		_era(e)
		var u := UnfurlSequence.new()
		add_child_autofree(u)
		assert_eq(u.style, EraBattleFeel.text(e, "unfurl"))
		await u.play(Database.species("Kindlop"), Database.species("Kindlop"))
		assert_true(u.showing_new(), "era %d" % e)

func test_glow_silhouette_from_era_two() -> void:
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(1, 1, 2, 2), Color("6a4256"))
	var tex := ImageTexture.create_from_image(img)
	var white: Image = UnfurlSequence.silhouette_of(tex, Color.WHITE).get_image()
	var ink: Image = UnfurlSequence.silhouette_of(tex).get_image()
	assert_true(white.get_pixel(1, 1).is_equal_approx(Color.WHITE))
	assert_true(ink.get_pixel(1, 1).is_equal_approx(UITheme.INK), "different colours keep separate caches")

func test_status_badge_from_era_two() -> void:
	assert_eq(EraBattleFeel.status_badge(1, "scorch"), Color.TRANSPARENT, "Era I plain letters")
	assert_eq(EraBattleFeel.status_badge(2, ""), Color.TRANSPARENT)
	for st: String in StatusRules.RULES:
		assert_gt(EraBattleFeel.status_badge(3, st).a, 0.0, st)
		assert_true((EraBattleFeel.cfg().status_colours as Dictionary).has(st), st)

func test_era_five_animates_spirlings_of_every_origin_era() -> void:
	Database.load_all()
	_era(5)
	var by_era: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if not by_era.has(sd.era) and not EraManager.sprite_path(sd.species_name).is_empty():
			by_era[sd.era] = sd
	assert_gte(by_era.size(), 2)
	for e: Variant in by_era:
		var sp := SpirlingSprite.new()
		sp.size = Vector2(96, 96)
		add_child_autofree(sp)
		sp.setup(Spirling.new(by_era[e], 10), "front")
		assert_eq(sp._strips.size(), BattleAnim.KINDS.size(), "origin era %d moves in Era V" % int(e))
		assert_eq(sp.anim_kind, "idle")
