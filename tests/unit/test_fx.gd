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

# --- Misses and effectiveness (items 2375, 2376) ---------------------------------------

func test_missed_art_flies_past_without_impact() -> void:
	var P := ElementFx.Phase
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, false, true), [P.CHARGE, P.TRAVEL] as Array[ElementFx.Phase])
	assert_eq(ElementFx.phases_for(MoveData.Kind.PHYSICAL, false, true), [P.CHARGE] as Array[ElementFx.Phase])
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, true, true), [] as Array[ElementFx.Phase])
	var fx := ElementFx.new()
	fx.size = Vector2(144, 120)
	add_child_autofree(fx)
	GameState.battle_speed = 2
	Juice.in_battle = true
	await fx.play(Elements.E.EMBER, MoveData.Kind.FOCUS, Rect2(90, 70, 40, 40), Rect2(20, 10, 40, 40), true)
	Juice.in_battle = false
	assert_false(fx.played.has(P.IMPACT), "no impact on a miss")
	var end: Vector2 = fx._to
	assert_true(end.x < 0 or end.y < 0 or end.x > fx.size.x or end.y > fx.size.y, "the path leaves the screen")
	# Same direction as towards the target.
	assert_gt((end - Vector2(110, 90)).normalized().dot((Vector2(40, 30) - Vector2(110, 90)).normalized()), 0.99)

func test_impact_size_follows_effectiveness() -> void:
	assert_eq(ElementFx.impact_scale(2.0), 1.5)
	assert_eq(ElementFx.impact_scale(1.0), 1.0)
	assert_eq(ElementFx.impact_scale(0.5), 0.5)

func test_art_outcome_reads_the_first_result() -> void:
	var T := BattleEvent.Type
	var ev := func(t: int, data: Dictionary = {}) -> BattleEvent:
		var e := BattleEvent.new()
		e.type = t
		e.data = data
		return e
	var list: Array[BattleEvent] = [ev.call(T.MOVE_USED), ev.call(T.MISSED), ev.call(T.MOVE_USED), ev.call(T.DAMAGE, {"eff": 2.0})]
	assert_true(BattleScene.art_outcome(list, 0).miss)
	assert_false(BattleScene.art_outcome(list, 2).miss)
	assert_eq(BattleScene.art_outcome(list, 2).eff, 2.0)
	var ticks: Array[BattleEvent] = [ev.call(T.MOVE_USED), ev.call(T.DAMAGE, {"status_tick": true, "eff": 0.5}), ev.call(T.MOVE_USED), ev.call(T.DAMAGE, {"eff": 0.5})]
	assert_eq(BattleScene.art_outcome(ticks, 0).eff, 1.0, "a status tick is not the art's hit, and the next art is not looked at")

# --- Power, timing and every art (items 2368, 2378, 2381, 2382) --------------------------

func test_particle_amount_follows_power() -> void:
	assert_eq(ElementFx.particles_for_power(40), 1.0)
	assert_eq(ElementFx.particles_for_power(50), 1.0)
	assert_eq(ElementFx.particles_for_power(70), 1.5)
	assert_eq(ElementFx.particles_for_power(90), 1.5)
	assert_eq(ElementFx.particles_for_power(120), 2.0)
	var fx := ElementFx.new()
	fx.amount = 2.0
	assert_eq(fx._n(5), 10)
	fx.amount = 1.5
	assert_eq(fx._n(3), 5)
	fx.free()
	assert_eq(ElementFx._spread(0, 3, 4.0), -4.0)
	assert_eq(ElementFx._spread(2, 3, 4.0), 4.0)

func test_full_art_takes_point_six_seconds_at_1x() -> void:
	var total: float = 0.0
	for p: ElementFx.Phase in ElementFx.phases_for(MoveData.Kind.FOCUS, false):
		total += ElementFx.phase_time(p, false)
	assert_almost_eq(total, 0.6, 0.001)
	var fx := ElementFx.new()
	fx.size = Vector2(144, 120)
	add_child_autofree(fx)
	GameState.battle_speed = 1
	Juice.in_battle = true
	var start: int = Time.get_ticks_msec()
	await fx.play(Elements.E.TIDE, MoveData.Kind.FOCUS, Rect2(90, 70, 40, 40), Rect2(20, 10, 40, 40))
	Juice.in_battle = false
	var took: float = (Time.get_ticks_msec() - start) / 1000.0
	assert_gt(GameState.battle_speed_scale(), 1.0)
	assert_almost_eq(took, 0.6 / GameState.battle_speed_scale(), 0.12, "shortened by the battle speed")

func test_every_art_in_the_data_plays_and_leaves_no_nodes() -> void:
	var fx := ElementFx.new()
	fx.size = Vector2(144, 120)
	add_child_autofree(fx)
	GameState.battle_speed = 2
	Juice.in_battle = true
	var played: int = 0
	Database.load_all()
	for mv: MoveData in Database.moves.values():
		await fx.play(mv.element, mv.kind, Rect2(90, 70, 40, 40), Rect2(20, 10, 40, 40), false, 1.0,
			ElementFx.particles_for_power(mv.power))
		assert_eq(fx.phase, ElementFx.Phase.NONE, mv.move_name)
		played += 1
	Juice.in_battle = false
	assert_gte(played, 58)
	assert_eq(fx.get_child_count(), 0, "effects draw, they leave no nodes behind")

# --- Follow-ups: heal, drain, energy drain, recoil, field (items 2370 to 2374) ----------

func test_after_phase_per_effect() -> void:
	var P := ElementFx.Phase
	assert_eq(ElementFx.phases_for(MoveData.Kind.STATUS, false, false, "heal"), [P.CHARGE, P.AFTER] as Array[ElementFx.Phase], "heal: no impact")
	assert_eq(ElementFx.phases_for(MoveData.Kind.STATUS, true, false, "heal"), [P.AFTER] as Array[ElementFx.Phase])
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, false, false, "drain"), [P.CHARGE, P.TRAVEL, P.IMPACT, P.AFTER] as Array[ElementFx.Phase])
	assert_eq(ElementFx.phases_for(MoveData.Kind.PHYSICAL, false, false, "recoil"), [P.CHARGE, P.IMPACT, P.AFTER] as Array[ElementFx.Phase])
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, false, true, "drain"), [P.CHARGE, P.TRAVEL] as Array[ElementFx.Phase], "a miss drains nothing")
	assert_eq(ElementFx.phases_for(MoveData.Kind.FOCUS, true, false, "drain"), [P.IMPACT] as Array[ElementFx.Phase])

func test_after_comes_from_the_moves_effects() -> void:
	Database.load_all()
	var seen: Dictionary = {}
	for mv: MoveData in Database.moves.values():
		var a: String = ElementFx.after_for(mv)
		if not a.is_empty():
			seen[a] = true
		if mv.has_effect(&"heal_self"):
			assert_eq(a, "heal", mv.move_name)
	for a: String in ["heal", "drain", "energy_drain", "recoil"]:
		assert_true(seen.has(a), "some art shows " + a)
	assert_eq(ElementFx.after_for(null), "")

func test_every_after_plays_for_every_element() -> void:
	var fx := ElementFx.new()
	fx.size = Vector2(144, 120)
	add_child_autofree(fx)
	GameState.battle_speed = 2
	Juice.in_battle = true
	for a: String in ElementFx.AFTERS:
		for e: int in Elements.E.values():
			await fx.play(e, MoveData.Kind.FOCUS, Rect2(90, 70, 40, 40), Rect2(20, 10, 40, 40), false, 1.0, 1.0, a)
			assert_true(fx.played.has(ElementFx.Phase.AFTER), a)
			assert_eq(fx.phase, ElementFx.Phase.NONE)
	Juice.in_battle = false
	assert_eq(fx.get_child_count(), 0)
