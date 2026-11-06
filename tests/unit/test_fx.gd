extends GutTest
## Plan area 6, third part: element effects, wind-ups, motion profiles, unfurl sequence.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.battle_speed = 0
	get_tree().paused = false

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_fx_shapes_exist_for_every_shade() -> void:
	for s: String in ["spark", "drop", "leaf", "zag", "rock", "streak", "glint", "shade"]:
		for k: int in 4:
			var tex: Texture2D = ElementFx.shape(s, k)
			assert_not_null(tex, "%s_%d" % [s, k])
			if tex != null:
				assert_eq(tex.get_size(), Vector2(8, 8))

func test_phases_per_kind() -> void:
	assert_eq(ElementFx.phases_for(MoveData.Kind.PHYSICAL, false), [ElementFx.Phase.CHARGE, ElementFx.Phase.IMPACT] as Array[ElementFx.Phase])
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, false).size(), 3)
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, true), [ElementFx.Phase.IMPACT] as Array[ElementFx.Phase])
	assert_almost_eq(ElementFx.phase_time(ElementFx.Phase.CHARGE, false), 0.15, 0.001)
	assert_almost_eq(ElementFx.phase_time(ElementFx.Phase.TRAVEL, false), 0.2, 0.001)
	assert_almost_eq(ElementFx.phase_time(ElementFx.Phase.IMPACT, false), 0.25, 0.001)
	assert_lte(ElementFx.phase_time(ElementFx.Phase.IMPACT, true), Juice.REDUCED_MAX_TIME)

func test_every_element_plays_and_ends_clean() -> void:
	var fx := ElementFx.new()
	fx.size = Vector2(144, 120)
	add_child_autofree(fx)
	var user := Control.new()
	user.position = Vector2(90, 70)
	add_child_autofree(user)
	fx.user_sprite = user
	GameState.battle_speed = 2
	Juice.in_battle = true
	for e: int in Elements.E.values():
		await fx.play(e, MoveData.Kind.FOCUS, Rect2(90, 70, 40, 40), Rect2(20, 10, 40, 40))
		assert_eq(fx.phase, ElementFx.Phase.NONE)
		assert_eq(fx.played.size(), 3, Elements.element_name(e))
		assert_eq(user.position, Vector2(90, 70), "user back home")
	Juice.in_battle = false

func test_lumen_never_flashes() -> void:
	assert_lte(ElementFx.LUMEN_MAX_ALPHA, 0.6)

func test_art_sounds_exist() -> void:
	for k: int in [MoveData.Kind.PHYSICAL, MoveData.Kind.FOCUS, MoveData.Kind.STATUS]:
		assert_true(ResourceLoader.exists(Sound.SFX_DIR % BattleScene.charge_sound(k)))
	for e: int in Elements.E.values():
		assert_true(ResourceLoader.exists(Sound.SFX_DIR % BattleScene.travel_sound(e)), BattleScene.travel_sound(e))

func test_every_spirling_has_a_motion_profile() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SpirlingSprite.MOTION_PATH))
	for sd: SpirlingData in Database.spirlings.values():
		var m: String = SpirlingSprite.motion_of(sd.species_name, sd.elements)
		assert_has(SpirlingSprite.MOTIONS, m, sd.species_name)
	for m: Variant in (raw.species as Dictionary).values():
		assert_has(SpirlingSprite.MOTIONS, str(m))
	assert_eq(SpirlingSprite.motion_of("Nobody", [Elements.E.STONE] as Array[int]), "stomp")

func test_windups_return_home() -> void:
	var sp := SpirlingSprite.new()
	sp.position = Vector2(30, 30)
	add_child_autofree(sp)
	sp._home = sp.position
	for k: int in [MoveData.Kind.PHYSICAL, MoveData.Kind.FOCUS, MoveData.Kind.STATUS]:
		await sp.windup(k, Vector2(-8, -4))
		assert_eq(sp.position, Vector2(30, 30))

func test_step_out_profiles_land_home() -> void:
	Database.load_all()
	for species: String in ["Kindlop", "Smoldrake", "Mossling", "Riptail", "Glimmerax"]:
		var sp := SpirlingSprite.new()
		sp.position = Vector2(50, 40)
		sp.size = Vector2(56, 56)
		add_child_autofree(sp)
		sp.setup(Spirling.new(Database.species(species), 5), "front")
		await sp.step_out(true)
		assert_eq(sp.position, Vector2(50, 40), species)
		assert_almost_eq(sp.modulate.a, 1.0, 0.01)

func test_unfurl_schedule() -> void:
	var iv: Array[float] = UnfurlSequence.intervals()
	var total: float = 0.0
	for d: float in iv:
		total += d
		assert_between(d, 0.0, 0.4001)
	assert_almost_eq(total, 2.4, 0.01)
	assert_almost_eq(iv[0], 0.4, 0.001)
	assert_almost_eq(iv[iv.size() - 1], 0.05, 0.02)
	for i: int in range(1, iv.size()):
		assert_lte(iv[i], iv[i - 1] + 0.0001)

func test_unfurl_reduced_is_short_and_ends_on_new_form() -> void:
	Database.load_all()
	GameState.reduce_motion = true
	var u := UnfurlSequence.new()
	add_child_autofree(u)
	var t0: int = Time.get_ticks_msec()
	await u.play(Database.species("Kindlop"), Database.species("Smoldrake"))
	assert_lt(Time.get_ticks_msec() - t0, 400)
	assert_true(u.showing_new())

func test_silhouette_is_flat_ink() -> void:
	Database.load_all()
	var tex: Texture2D = UnfurlSequence._tex(Database.species("Kindlop"))
	assert_not_null(tex)
	var img: Image = UnfurlSequence.silhouette_of(tex).get_image()
	for y: int in range(0, img.get_height(), 3):
		for x: int in range(0, img.get_width(), 3):
			var c: Color = img.get_pixel(x, y)
			assert_true(c.a == 0.0 or c.is_equal_approx(UITheme.INK))
