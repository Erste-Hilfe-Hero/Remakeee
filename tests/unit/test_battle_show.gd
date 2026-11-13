extends GutTest
## docs/KAMPF_PLAN_1000.md, "Tempo, Animation und Praesentation" and "Audio im Kampf":
## BattleShow (banners, phase zoom, night tint, short rematch intro, winners' pose),
## SpirlingAura (status motes, stage aura, lantern light) and BattleAudio (battle sounds).

var _motion: bool
var _records: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_motion = GameState.reduce_motion
	_records = GameState.records.duplicate(true)

func after_each() -> void:
	GameState.reduce_motion = _motion
	GameState.records = _records

func _sfx_exists(sound: String) -> bool:
	return FileAccess.file_exists("res://audio/sfx/%s.wav" % sound)

# --- BattleAudio -----------------------------------------------------------------------------

func test_every_status_has_its_own_sound_file() -> void:
	var seen: Dictionary = {}
	for st: String in StatusRules.RULES:
		var s: String = BattleAudio.status_sound(st)
		assert_ne(s, "status", "%s has its own sound" % st)
		assert_true(_sfx_exists(s), s)
		assert_false(seen.has(s), "%s shares its sound" % st)
		seen[s] = true
	assert_eq(BattleAudio.status_sound("nonsense"), "status")

func test_stage_notes_climb_with_the_stage_and_stop_at_the_cap() -> void:
	assert_eq(BattleAudio.stage_sound(1), "stage_up")
	assert_eq(BattleAudio.stage_sound(-2), "stage_down")
	assert_eq(BattleAudio.stage_sound(0), "")
	assert_almost_eq(BattleAudio.stage_pitch(1), 1.0, 0.001)
	assert_gt(BattleAudio.stage_pitch(2), BattleAudio.stage_pitch(1))
	assert_gt(BattleAudio.stage_pitch(-3), BattleAudio.stage_pitch(-2), "falling stages climb too, by size")
	assert_almost_eq(BattleAudio.stage_pitch(99), float(BattleAudio.cfg().stage_max_pitch), 0.001)

func test_overcharge_swell_climbs_with_the_energy_poured_in() -> void:
	assert_almost_eq(BattleAudio.overcharge_pitch(1), 1.0, 0.001)
	assert_gt(BattleAudio.overcharge_pitch(3), BattleAudio.overcharge_pitch(2))
	assert_lte(BattleAudio.overcharge_pitch(50), float(BattleAudio.cfg().overcharge_max_pitch))

func test_field_sounds_rise_shift_and_fade() -> void:
	assert_eq(BattleAudio.field_sound(false, false), "field_rise")
	assert_eq(BattleAudio.field_sound(false, true), "field_shift")
	assert_eq(BattleAudio.field_sound(true, true), "field_fade")

func test_matchup_tones_tell_strong_from_weak_hits() -> void:
	assert_eq(BattleAudio.eff_tone(2.0), "eff_up")
	assert_eq(BattleAudio.eff_tone(0.5), "eff_down")
	assert_eq(BattleAudio.eff_tone(1.0), "")
	assert_eq(BattleAudio.eff_tone(0.0), "", "no tone for no effect")

func test_end_cues_fade_on_loss_and_flight() -> void:
	assert_eq(BattleAudio.end_cue(BattleModel.Outcome.LOSS), {"fade": true, "sfx": "defeat"})
	assert_eq(BattleAudio.end_cue(BattleModel.Outcome.FLED), {"fade": true, "sfx": ""})
	assert_false(bool(BattleAudio.end_cue(BattleModel.Outcome.WIN).fade), "the victory jingle plays instead")

func test_fast_speed_and_battery_saver_leave_out_flourishes() -> void:
	assert_true(BattleAudio.keep("travel_ember", 2.0, false))
	assert_false(BattleAudio.keep("travel_ember", 4.0, false))
	assert_false(BattleAudio.keep("charge_focus", 4.0, false))
	assert_false(BattleAudio.keep("travel_ember", 1.0, true))
	assert_true(BattleAudio.keep("eff_up", 4.0, true), "matchup tones help players who cannot see")
	assert_true(BattleAudio.keep("hit_strong", 4.0, true), "hits always sound")

func test_accents_keep_a_gap() -> void:
	assert_true(BattleAudio.accent_ok(10.0, 0.0))
	assert_false(BattleAudio.accent_ok(10.1, 10.0))

func test_every_battle_sound_exists_and_takes_battle_priority() -> void:
	var names: Array[String] = ["overcharge", "crit_accent", "rule_seal", "partner_call", "calm_fail", "defeat", "boss_intro",
		"boss_phase", "field_rise", "field_fade", "field_shift", "stage_up", "stage_down", "eff_up", "eff_down"]
	for st: String in StatusRules.RULES:
		names.append(BattleAudio.status_sound(st))
	var log: String = FileAccess.get_file_as_string("res://docs/ASSET_LOG.md")
	for n: String in names:
		assert_true(_sfx_exists(n), n)
		assert_eq(Sound.priority_of(n), Sound.PRIO_BATTLE, n)
		assert_string_contains(log, "audio/sfx/%s.wav" % n)

# --- BattleShow helpers ------------------------------------------------------------------------

func test_keen_hit_holds_longer_than_the_base_hitstop() -> void:
	assert_gt(BattleShow.crit_hitstop(), Juice.HITSTOP_BASE)
	assert_lte(BattleShow.crit_hitstop(), Juice.HITSTOP_MAX)

func test_phase_zoom_is_a_whole_step_in_eras_one_to_three_only() -> void:
	for era: int in [1, 2, 3]:
		var z: float = BattleShow.phase_zoom(era)
		assert_gt(z, 1.0)
		assert_eq(z, roundf(z), "whole-number zoom keeps pixels crisp")
	for era: int in [4, 5]:
		assert_eq(BattleShow.phase_zoom(era), 0.0, "Era IV/V keep their own camera")

func test_banner_titles() -> void:
	var f := BattleEvent.new(BattleEvent.Type.FIELD, {"field": BattleRules.FIELDS.keys()[0]})
	assert_eq(BattleShow.banner_title(f), str(BattleRules.FIELDS.values()[0].label))
	assert_eq(BattleShow.banner_title(BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {"name": "Ashen Heart"})), "Ashen Heart awakens")
	assert_eq(BattleShow.banner_title(BattleEvent.new(BattleEvent.Type.PARTNER, {"partner": "Kestra"})), "Side by side: Kestra")
	assert_eq(BattleShow.banner_title(BattleEvent.new(BattleEvent.Type.BATTLE_END, {"outcome": BattleModel.Outcome.WIN})), "Victory")
	assert_eq(BattleShow.banner_title(BattleEvent.new(BattleEvent.Type.BATTLE_END, {"outcome": BattleModel.Outcome.LOSS})), "Worn out")
	assert_eq(BattleShow.banner_title(BattleEvent.new(BattleEvent.Type.DAMAGE, {})), "")
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for t: String in ["Victory", "Bonded", "Slipped away", "Worn out", "%s awakens", "Side by side: %s"]:
		assert_true(de.has(t), "German for " + t)

func test_backdrop_takes_the_night_tint_only_outdoors() -> void:
	assert_eq(BattleShow.night_tint(DayCycle.Phase.DAY, true, true, "field"), Color.WHITE)
	var night: Color = BattleShow.night_tint(DayCycle.Phase.NIGHT, true, true, "field")
	assert_lt(night.r, 1.0)
	assert_gt(night.r, DayCycle.TINTS[DayCycle.Phase.NIGHT].r, "only part of the tint, the field stays readable")
	assert_eq(BattleShow.night_tint(DayCycle.Phase.NIGHT, true, false, "field"), Color.WHITE)
	assert_eq(BattleShow.night_tint(DayCycle.Phase.NIGHT, false, true, "field"), Color.WHITE)
	assert_eq(BattleShow.night_tint(DayCycle.Phase.NIGHT, true, true, "voice"), Color.WHITE)

func test_rematch_keeps_a_short_intro() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Mossling", 10)] as Array[Spirling], false, 3, 1)
	m.trainer_name = "Test Rival Ona"
	GameState.records.erase(BattleShow.SEEN_KEY)
	assert_eq(BattleShow.intro_share_for(m), 1.0)
	BattleShow.note_intro(m)
	assert_lt(BattleShow.intro_share_for(m), 1.0)
	assert_gt(BattleShow.intro_share_for(m), 0.0)
	var wild := BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Mossling", 10)] as Array[Spirling], true, 3, 0)
	BattleShow.note_intro(wild)
	assert_eq(BattleShow.intro_share_for(wild), 1.0, "wild battles always open in full")

func test_victory_glints_grow_with_the_era() -> void:
	assert_eq(BattleShow.victory_glints(1), 0)
	assert_gte(BattleShow.victory_glints(3), BattleShow.victory_glints(2))

# --- SpirlingAura --------------------------------------------------------------------------------

func test_every_status_has_motes() -> void:
	for st: String in StatusRules.RULES:
		var spec: Dictionary = SpirlingAura.mote_spec(st)
		assert_false(spec.is_empty(), st)
		assert_gt(int(spec.get("count", 0)), 0, st)

func test_stage_dir_sums_the_stages() -> void:
	assert_eq(SpirlingAura.stage_dir_of({}), 0)
	assert_eq(SpirlingAura.stage_dir_of({"atk": 2, "def": -1}), 1)
	assert_eq(SpirlingAura.stage_dir_of({"atk": 1, "spd": -2}), -1)
	assert_eq(SpirlingAura.stage_dir_of({"atk": 1, "spd": -1}), 0)

func test_motes_sit_on_whole_pixels_inside_the_sprite_and_rise() -> void:
	var box := Vector2(40, 40)
	for q: float in [0.0, 0.3, 0.7]:
		for p: Vector2 in SpirlingAura.mote_points(-1, 3, q, box):
			assert_eq(p, p.round())
			assert_true(Rect2(Vector2.ZERO, box).has_point(p), str(p))
	assert_lt(SpirlingAura.mote_points(-1, 1, 0.6, box)[0].y, SpirlingAura.mote_points(-1, 1, 0.1, box)[0].y, "sparks rise")
	assert_gt(SpirlingAura.mote_points(1, 1, 0.6, box)[0].y, SpirlingAura.mote_points(1, 1, 0.1, box)[0].y, "drops fall")

func test_aura_ring_turns_on_whole_pixels() -> void:
	var a: PackedVector2Array = SpirlingAura.aura_points(10, 0.0, Vector2(32, 32))
	assert_eq(a.size(), 10)
	for p: Vector2 in a:
		assert_eq(p, p.round())
	assert_ne(SpirlingAura.aura_points(10, 0.05, Vector2(32, 32)), a)

func test_era_one_and_high_contrast_draw_in_ink() -> void:
	var spec: Dictionary = SpirlingAura.mote_spec("scorch")
	assert_eq(SpirlingAura.mote_color(spec, 1, false), UITheme.INK)
	assert_eq(SpirlingAura.mote_color(spec, 3, true), UITheme.INK)
	assert_eq(SpirlingAura.mote_color(spec, 3, false), Color(str(spec.color)))
	assert_ne(SpirlingAura.aura_color(1, 2, false), SpirlingAura.aura_color(-1, 2, false))

func test_reduced_motion_keeps_the_marks_still() -> void:
	GameState.reduce_motion = true
	var a := SpirlingAura.new()
	add_child_autofree(a)
	a.set_state("scorch", {"atk": 1})
	var q: float = a._q()
	a._process(0.5)
	assert_eq(a._q(), q)

# --- Model and scene ----------------------------------------------------------------------------

func test_overcharge_art_reports_the_energy_poured_in() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 30, ["Overcharge"] as Array[String])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [BattleFixtures.make("Mossling", 30)] as Array[Spirling])
	me.energy = 10
	var used: BattleEvent = null
	for e: BattleEvent in m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0)):
		if e.type == BattleEvent.Type.MOVE_USED and int(e.data.side) == BattleModel.Side.PLAYER:
			used = e
	assert_not_null(used)
	assert_gt(int(used.data.get("overcharge", 0)), 0)

func _scene() -> BattleScene:
	var b := BattleScene.new()
	b._build()
	b.model = BattleModel.new([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Mossling", 10)] as Array[Spirling], false, 5, 1)
	b.model.start()
	return b

func _free(b: BattleScene) -> void:
	b._menu._hold.free()
	b.free()

func test_scene_gives_every_sprite_an_aura_that_follows_the_events() -> void:
	var b: BattleScene = _scene()
	assert_not_null(b._show)
	var show: BattleShow = b._show
	var F: int = BattleModel.Side.FOE
	show.on_event(BattleEvent.new(BattleEvent.Type.SEND_OUT, {"side": F, "slot": 0, "index": 0}))
	var aura: SpirlingAura = show.aura_at(F, 0)
	assert_not_null(aura)
	assert_eq(aura.get_parent(), b._foe_sprite)
	show.on_event(BattleEvent.new(BattleEvent.Type.STATUS_APPLIED, {"side": F, "slot": 0, "status": "soak"}))
	assert_eq(aura.status, "soak")
	show.on_event(BattleEvent.new(BattleEvent.Type.STAT_CHANGED, {"side": F, "slot": 0, "stat": "atk", "delta": 1, "stage": 2}))
	assert_eq(aura.stage_dir, 1)
	show.on_event(BattleEvent.new(BattleEvent.Type.STATUS_CURED, {"side": F, "slot": 0}))
	assert_eq(aura.status, "")
	assert_eq(aura.stage_dir, 1, "a cure keeps the stages")
	show.on_event(BattleEvent.new(BattleEvent.Type.FAINTED, {"side": F, "slot": 0}))
	assert_eq(aura.stage_dir, 0)
	assert_eq(show.aura_at(F, 0), aura, "one aura per sprite")
	_free(b)

func test_scene_shows_field_partner_phase_and_end_banners() -> void:
	var b: BattleScene = _scene()
	var show: BattleShow = b._show
	show.on_event(BattleEvent.new(BattleEvent.Type.FIELD, {"field": BattleRules.FIELDS.keys()[0]}))
	assert_true(show.field_on)
	assert_true(show.banner.visible)
	show.on_event(BattleEvent.new(BattleEvent.Type.FIELD_END, {"field": BattleRules.FIELDS.keys()[0]}))
	assert_false(show.field_on)
	show.on_event(BattleEvent.new(BattleEvent.Type.PARTNER, {"side": 0, "slot": 1, "partner": "Kestra"}))
	show.on_event(BattleEvent.new(BattleEvent.Type.BOSS_PHASE, {"side": 1, "slot": 0, "name": "Ashen Heart"}))
	show.on_event(BattleEvent.new(BattleEvent.Type.BATTLE_END, {"outcome": BattleModel.Outcome.WIN}))
	assert_eq(show.banners.size(), 4)
	assert_eq(show.banners[-1], "Victory")
	assert_eq(b._shake_root.scale, Vector2.ONE, "no zoom left behind outside the tree")
	_free(b)

func test_scene_backdrop_stays_untinted_indoors() -> void:
	var b: BattleScene = _scene()
	b.outdoor = false
	b._layout_field()
	assert_eq(b._backdrop.modulate, Color.WHITE)
	_free(b)
