extends GutTest
## Overworld figures per era (data/era_actor_look.json, docs/ERA_FEEL_CHARS.md).

const FIVE: Array[String] = ["alert", "question", "dots", "heart", "note"]

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

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

func _row(e: int) -> Dictionary:
	return EraActorLook.row(e)

func _walker(style: String = "villager") -> NPC:
	var n := NPC.new()
	n.setup({"id": "t", "x": 4, "y": 4, "sprite": style, "facing": "down"})
	add_child_autofree(n)
	return n

func _actors(player: GridWalker = null) -> EraActors:
	var holder := Node2D.new()
	add_child_autofree(holder)
	var a := EraActors.new()
	a.entities = holder
	a.player = player
	add_child_autofree(a)
	return a

# --- The table ----------------------------------------------------------------------------

func test_all_five_eras_are_configured() -> void:
	assert_eq(EraActorLook.problems(), [] as Array[String])
	for e: int in range(1, 6):
		for k: String in EraActorLook.KEYS:
			assert_true(_row(e).has(k), "era %d has %s" % [e, k])

func test_a_broken_table_is_reported() -> void:
	var keep: Dictionary = EraActorLook.data()
	var bad: Dictionary = keep.duplicate(true)
	bad.eras["5"]["head_turn"] = false
	bad.eras["5"]["head_turn_radius"] = 1
	bad.eras["5"]["emotes"] = ["alert"]
	bad.eras["3"].erase("shadow")
	bad.eras["5"]["step_px"] = 2
	EraActorLook._data = bad
	var found: String = "\n".join(EraActorLook.problems())
	EraActorLook._data = keep
	assert_string_contains(found, "era 3: key shadow is missing")
	assert_string_contains(found, "era 5 loses the emote note")
	assert_string_contains(found, "era 5: movement gets coarser")
	assert_string_contains(found, "era 5: head_turn_radius goes down")
	assert_string_contains(found, "era 5 switches head_turn off again")

func test_no_era_loses_a_feature() -> void:
	for e: int in range(2, 6):
		var now: Dictionary = _row(e)
		var before: Dictionary = _row(e - 1)
		for k: String in EraActorLook.SWITCHES:
			assert_true(bool(now[k]) or not bool(before[k]), "era %d keeps %s" % [e, k])
		for k: String in EraActorLook.GROWING:
			assert_gte(float(now[k]), float(before[k]), "era %d %s" % [e, k])
		for k: String in EraActorLook.LADDERS:
			assert_gte(EraActorLook.LADDERS[k].find(str(now[k])), EraActorLook.LADDERS[k].find(str(before[k])), "era %d %s" % [e, k])
		for kind: Variant in before.emotes:
			assert_has(now.emotes, kind, "era %d keeps the emote %s" % [e, kind])
		for name: String in before.rows:
			assert_true((now.rows as Dictionary).has(name), "era %d keeps the pose %s" % [e, name])
		assert_gte(int(now.frame[1]), int(before.frame[1]), "era %d figures are not smaller" % e)
		assert_lte(float(now.run_time), float(before.run_time), "era %d runs as fast" % e)

func test_each_era_takes_its_step() -> void:
	# I: small figures, 2 walk frames, coarse steps, four inks, the "!" for a Tamer's sight.
	assert_eq(_row(1).frame, [16.0, 16.0])
	assert_eq(int(_row(1).walk_frames), 2)
	assert_eq(int(_row(1).step_px), 2)
	assert_eq(int(_row(1).colours), 4)
	assert_eq(EraActorLook.emote_for("spot", 1), "alert")
	assert_true(EraActorLook.plain_emotes(1))
	# II: same size in colour, bubbles instead of the ink box.
	assert_eq(_row(2).frame, _row(1).frame)
	assert_false(EraActorLook.plain_emotes(2))
	assert_eq(EraActorLook.emote_for("talk", 2), "note")
	assert_eq(EraActorLook.emote_for("talk", 1), "", "Era I shows nothing on a talk")
	# III: own sheets with both feet, running poses and the wading pose.
	assert_true(EraActorLook.own_sheets(3))
	assert_false(EraActorLook.own_sheets(2))
	assert_eq(int(_row(3).walk_frames), 3)
	assert_true(bool(_row(3).run_anim) and bool(_row(3).wade))
	assert_eq(int(_row(3).step_px), 1)
	# IV: taller, shadow, half steps, head turns, the coloured follower.
	assert_gt(int(_row(4).frame[1]), int(_row(3).frame[1]))
	assert_eq(str(_row(4).shadow), "drop")
	assert_has(_row(4).step_seq, "half")
	assert_true(bool(_row(4).head_turn))
	assert_eq(str(_row(4).follower), "colour")
	assert_eq(str(_row(3).follower), "ink")
	# V: living idle, quarter-turn blend, season outfits, bubbles by the moment.
	assert_eq(str(_row(5).idle), "breathe_blink")
	assert_true(bool(_row(5).turn_blend))
	assert_eq(str(_row(5).outfits), "season")
	assert_eq(EraActorLook.emote_for("near_night", 5), "zzz")
	assert_eq(EraActorLook.emote_for("near_night", 4), "")

func test_speeds_match_the_walker() -> void:
	for e: int in range(1, 6):
		assert_almost_eq(float(_row(e).walk_time), GridWalker.WALK_TIME, 0.0001)
		assert_almost_eq(float(_row(e).run_time), GridWalker.RUN_TIME, 0.0001)

# --- Art ----------------------------------------------------------------------------------

func test_every_figure_has_a_sheet_of_the_right_size() -> void:
	var styles: Array = EraActorLook.data().styles
	assert_gt(styles.size(), 10)
	for e: int in range(3, 6):
		var r: Dictionary = _row(e)
		var blocks: int = (EraActorLook.data().seasons as Array).size() if str(r.outfits) == "season" else 1
		for s: Variant in styles:
			var tex: Texture2D = EraActorLook.sheet(str(s), e)
			assert_not_null(tex, "era %d %s" % [e, s])
			if tex == null:
				continue
			assert_eq(tex.get_width(), int(r.frame[0]) * 4 * blocks, "era %d %s width" % [e, s])
			assert_eq(tex.get_height(), int(r.frame[1]) * (r.rows as Dictionary).size(), "era %d %s height" % [e, s])

func test_every_map_figure_style_is_drawn_or_falls_back() -> void:
	# The Era I sheets stay the source: every style with one has its later sheets.
	for s: Variant in EraActorLook.data().styles:
		assert_true(ResourceLoader.exists("res://art/era1/chars/%s.png" % s), "era 1 %s" % s)
	assert_null(EraActorLook.sheet("no_such_figure", 4))

func test_sheets_grow_richer() -> void:
	var counts: Array[int] = []
	for e: int in range(1, 6):
		var path: String = "res://art/era%d/%s/tamer.png" % [e, "actors" if EraActorLook.own_sheets(e) else "chars"]
		var img: Image = (load(path) as Texture2D).get_image()
		var seen: Dictionary = {}
		var fh: int = int(_row(e).frame[1])
		for y: int in fh:
			for x: int in 64:
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5:
					seen[c.to_html()] = true
		counts.append(seen.size())
	assert_lte(counts[0], 4, "Era I: four inks")
	assert_lte(counts[1], 4, "Era II: four colours per figure")
	assert_gt(counts[2], 8, "Era III: zone colours and shading")
	assert_gte(counts[3], counts[2], "Era IV")
	assert_gte(counts[4], counts[3], "Era V")

func test_emote_sheets_cover_every_kind() -> void:
	var kinds: Array = EraActorLook.data().emote_kinds
	for e: int in range(2, 6):
		var tex: Texture2D = EraActorLook.emote_sheet(e)
		assert_not_null(tex, "era %d" % e)
		if tex != null:
			assert_eq(tex.get_width(), 16 * kinds.size())
			assert_eq(tex.get_height(), 16 * int(_row(e).emote_frames))
	for icon: String in ["!", "?", "...", "heart", "note"]:
		assert_has(FIVE, EraActorLook.emote_kind(icon))
	assert_eq(EraActorLook.emote_kind("cake"), "")

# --- Poses --------------------------------------------------------------------------------

func test_walk_alternates_feet_from_era_three() -> void:
	var r: Dictionary = _row(3)
	assert_eq(EraActorLook.pose(r, "down", true, false, 0.5, 0).row, "step_l")
	assert_eq(EraActorLook.pose(r, "down", true, false, 0.5, 1).row, "step_r")
	assert_eq(EraActorLook.pose(r, "down", true, false, 0.5, -3).row, "step_r", "odd cells left of the map edge")
	assert_eq(EraActorLook.pose(r, "down", true, false, 0.05, 0).row, "stand")
	assert_eq(EraActorLook.pose(r, "left", false, false, 0.0, 0), {"row": "stand", "col": "left"})

func test_running_has_its_own_poses() -> void:
	assert_eq(EraActorLook.pose(_row(3), "right", true, true, 0.5, 0).row, "run_l")
	assert_eq(EraActorLook.pose(_row(5), "right", true, true, 0.5, 1).row, "run_r")
	assert_eq(EraActorLook.pose(_row(3), "right", true, false, 0.5, 0).row, "step_l")

func test_era_four_steps_in_four_phases() -> void:
	var r: Dictionary = _row(4)
	var seen: Array[String] = []
	for k: float in [0.1, 0.3, 0.6, 0.9]:
		seen.append(str(EraActorLook.pose(r, "down", true, false, k, 0).row))
	assert_eq(seen, ["half_l", "step_l", "step_l", "half_l"] as Array[String])

func test_wading_wins_over_walking() -> void:
	assert_eq(EraActorLook.pose(_row(3), "up", true, false, 0.5, 0, "", true).row, "wade")
	assert_true(EraActorLook.wades("wading_boots", 3))
	assert_false(EraActorLook.wades("wading_boots", 2), "Eras I and II hop across as before")
	assert_false(EraActorLook.wades("grapple_line", 5))

func test_head_turns_keep_the_body() -> void:
	var r: Dictionary = _row(4)
	assert_eq(EraActorLook.pose(r, "down", false, false, 0.0, 0, "left"), {"row": "head_cw", "col": "down"})
	assert_eq(EraActorLook.pose(r, "down", false, false, 0.0, 0, "right"), {"row": "head_ccw", "col": "down"})
	assert_eq(EraActorLook.pose(r, "down", false, false, 0.0, 0, "up"), {"row": "stand", "col": "up"}, "behind: the whole figure turns")
	assert_eq(EraActorLook.pose(_row(3), "down", false, false, 0.0, 0, "left"), {"row": "stand", "col": "left"}, "Era III glances with the whole figure")

func test_quarter_turn_blend_in_era_five() -> void:
	var r: Dictionary = _row(5)
	assert_eq(EraActorLook.pose(r, "left", false, false, 0.0, 0, "", false, "down"), {"row": "head_cw", "col": "down"})
	assert_eq(EraActorLook.pose(r, "right", true, false, 0.5, 0, "", false, "down"), {"row": "head_ccw", "col": "down"})
	assert_eq(EraActorLook.pose(_row(4), "left", false, false, 0.0, 0, "", false, "down").row, "stand", "Era IV turns at once")

func test_idle_breathes_and_blinks_in_era_five() -> void:
	var r: Dictionary = _row(5)
	var rows: Dictionary = {}
	for ms: int in range(0, 8000, 20):
		rows[EraActorLook.pose(r, "down", false, false, 0.0, 0, "", false, "", ms).row] = true
	assert_true(rows.has("stand") and rows.has("breathe") and rows.has("blink"))
	rows.clear()
	for ms: int in range(0, 8000, 20):
		rows[EraActorLook.pose(_row(4), "down", false, false, 0.0, 0, "", false, "", ms).row] = true
	assert_eq(rows.keys(), ["stand"], "Era IV stands still")

func test_seasons_pick_the_outfit_block() -> void:
	assert_eq(EraActorLook.season(4), "spring")
	assert_eq(EraActorLook.season(7), "summer")
	assert_eq(EraActorLook.season(10), "autumn")
	assert_eq(EraActorLook.season(1), "winter")
	assert_eq(EraActorLook.season(12), "winter")
	assert_eq(EraActorLook.outfit_block(5, 7), 1)
	assert_eq(EraActorLook.outfit_block(5, 12), 3)
	assert_eq(EraActorLook.outfit_block(4, 12), 0, "outfits come with Era V")
	var r: Dictionary = _row(5)
	assert_eq(EraActorLook.src_rect(r, {"row": "step_l", "col": "left"}, 3), Rect2((12 + 2) * 16, int(r.rows.step_l) * 24, 16, 24))

# --- Reduced motion -----------------------------------------------------------------------

func test_reduced_motion_stills_the_figures() -> void:
	var r: Dictionary = _row(5)
	for ms: int in range(0, 8000, 20):
		assert_eq(EraActorLook.pose(r, "down", false, false, 0.0, 0, "", false, "", ms, true).row, "stand")
	assert_eq(EraActorLook.pose(r, "left", false, false, 0.0, 0, "", false, "down", 0, true).row, "stand", "no blend frame")
	# The walk cycle and head turns stay: they carry information, not decoration.
	assert_eq(EraActorLook.pose(r, "down", true, false, 0.5, 0, "", false, "", 0, true).row, "step_l")
	assert_eq(EraActorLook.pose(r, "down", false, false, 0.0, 0, "left", false, "", 0, true).row, "head_cw")
	assert_eq(EraActors.follower_offset(0.5, 0, "breathe_blink", true), Vector2.ZERO)
	assert_eq(EraActors.follower_offset(1.0, 900, "breathe_blink", true), Vector2.ZERO)
	assert_eq(EraActors.follower_offset(0.5, 0, "still", false), Vector2(0, -1), "hop in the middle of the step")
	assert_eq(EraActors.follower_offset(1.0, 900, "breathe_blink", false), Vector2(0, 1))

func test_reduced_motion_keeps_bubbles_still() -> void:
	_era(5)
	var a: EraActors = _actors()
	var n: NPC = _walker()
	assert_true(a.show_bubble(n, "dots"))
	var b: Dictionary = a.bubbles[0]
	var r: Dictionary = _row(5)
	var rest: Vector2 = n.position + Vector2(0, -8 - 13)
	b.age = 0.01
	assert_eq(a.bubble_place(b, r, true), {"at": rest, "frame": 0})
	assert_eq(a.bubble_place(b, r, false).at, rest + Vector2(0, 2), "pops in from 2 px lower")
	b.age = 0.3
	assert_eq(a.bubble_place(b, r, true), {"at": rest, "frame": 0})
	assert_eq(int(a.bubble_place(b, r, false).frame), 1, "second frame after a quarter second")

# --- The live node ------------------------------------------------------------------------

func test_bubbles_by_era() -> void:
	var n: NPC = _walker()
	var a: EraActors = _actors()
	_era(1)
	assert_false(a.show_bubble(n, "!"), "Era I keeps its ink box")
	_era(2)
	assert_true(a.show_bubble(n, "!"))
	assert_eq(a.bubble_of(n), "alert")
	assert_true(a.show_bubble(n, "..."), "a new bubble replaces the old one")
	assert_eq(a.bubbles.size(), 1)
	assert_false(a.show_bubble(n, "zzz"), "sleep bubbles come with Era V")
	_era(5)
	assert_true(a.react(n, "near_rain"))
	assert_eq(a.bubble_of(n), "drop")
	assert_eq(EraActors.near_trigger(true, false), "near_night")
	assert_eq(EraActors.near_trigger(true, true), "near_rain")
	assert_eq(EraActors.near_trigger(false, false), "near")

func test_bubbles_time_out_and_alert_holds() -> void:
	_era(3)
	var n: NPC = _walker()
	var a: EraActors = _actors()
	a.show_bubble(n, "note", 0.5)
	a._tick_bubbles(0.3)
	assert_eq(a.bubbles.size(), 1)
	a._tick_bubbles(0.3)
	assert_eq(a.bubbles.size(), 0)
	n.alert = true
	a._tick_npc(n, _row(3))
	assert_eq(a.bubble_of(n), "alert")
	a._tick_bubbles(5.0)
	assert_eq(a.bubble_of(n), "alert", "stays while the Tamer is alert")
	n.alert = false
	a._tick_bubbles(0.01)
	assert_eq(a.bubbles.size(), 0)

func test_scene_and_talk_reach_the_node_on_screen() -> void:
	_era(2)
	var n: NPC = _walker()
	assert_false(EraActors.bubble_on(n, "?", 0.6), "no overworld, no bubble")
	var a: EraActors = _actors()
	assert_true(EraActors.bubble_on(n, "?", 0.6))
	assert_eq(a.bubble_of(n), "question")
	await n.turn_toward(Vector2i(4, 5))
	assert_eq(a.bubble_of(n), "note", "a talk shows the era's talk bubble")
	_era(1)
	a.bubbles.clear()
	await n.turn_toward(Vector2i(4, 5))
	assert_eq(a.bubbles.size(), 0)

func test_villagers_turn_their_head_from_era_four() -> void:
	var p := GridWalker.new()
	add_child_autofree(p)
	var a: EraActors = _actors(p)
	var n: NPC = _walker()
	p.place(Vector2i(6, 4))
	_era(3)
	a._tick_npc(n, _row(3))
	assert_eq(n.look, "", "Era III: no head turn")
	_era(4)
	a._tick_npc(n, _row(4))
	assert_eq(n.look, "right")
	assert_eq(n.facing, "down", "the body and a Tamer's line of sight stay")
	p.place(Vector2i(4, 6))
	a._tick_npc(n, _row(4))
	assert_eq(n.look, "", "already facing the Wayfarer")
	p.place(Vector2i(9, 9))
	a._tick_npc(n, _row(4))
	assert_eq(n.look, "")
	assert_false(bool(n.era_anim.watching))
	# A Tamer keeps looking down the road.
	var t: NPC = _walker()
	t.definition["trainer"] = "x"
	p.place(Vector2i(5, 4))
	a._tick_npc(t, _row(4))
	assert_eq(t.look, "")

func test_noticing_shows_a_bubble_once_per_cooldown_in_era_five() -> void:
	_era(5)
	var p := GridWalker.new()
	add_child_autofree(p)
	var a: EraActors = _actors(p)
	a.is_night = func() -> bool: return true
	var n: NPC = _walker()
	p.place(Vector2i(6, 4))
	a._tick_npc(n, _row(5))
	assert_eq(a.bubble_of(n), "zzz")
	a.bubbles.clear()
	p.place(Vector2i(12, 12))
	a._tick_npc(n, _row(5))
	p.place(Vector2i(6, 4))
	a._tick_npc(n, _row(5))
	assert_eq(a.bubbles.size(), 0, "not again within the cooldown")

func test_coarse_steps_in_the_first_eras() -> void:
	assert_eq(EraActors.snap(Vector2(21, 37), 2), Vector2(20, 36))
	assert_eq(EraActors.snap(Vector2(16, 32), 2), Vector2(16, 32), "cells stay cells")
	assert_eq(EraActors.snap(Vector2(21, 37), 1), Vector2(21, 37))

func test_follower_is_ink_then_colour_and_walks() -> void:
	var a: EraActors = _actors()
	var f := Sprite2D.new()
	f.centered = false
	f.modulate = Color(0.1, 0.1, 0.2, 0.85)
	add_child_autofree(f)
	a.follower = f
	f.position = Vector2(32, 32)
	_era(3)
	a._tick_follower(_row(3), 0.016)
	assert_eq(f.modulate, Color(0.1, 0.1, 0.2, 0.85), "Eras I-III: the ink shadow")
	assert_eq(f.get_child_count(), 0)
	_era(4)
	a._tick_follower(_row(4), 0.016)
	assert_eq(f.modulate, Color.WHITE)
	assert_true((f.get_child(0) as Sprite2D).visible, "drop shadow")
	f.position = Vector2(48, 32)
	a._tick_follower(_row(4), GridWalker.WALK_TIME / 2.0)
	assert_eq(f.position, Vector2(40, 32), "half way after half a step")
	assert_true(f.flip_h)
	a._tick_follower(_row(4), GridWalker.WALK_TIME)
	assert_eq(f.position, Vector2(48, 32))
	f.position = Vector2(160, 160)
	a._tick_follower(_row(4), 0.016)
	assert_eq(f.position, Vector2(160, 160), "a warp jumps, it is not walked")
	_era(1)
	a._tick_follower(_row(1), 0.016)
	assert_eq(f.modulate, Color(0.1, 0.1, 0.2, 0.85), "the Retro filter brings the ink back")
	assert_false((f.get_child(0) as Sprite2D).visible)

func test_walker_draws_through_the_era_look() -> void:
	var n: NPC = _walker("elder")
	var a: EraActors = _actors()
	_era(4)
	a._tick_walker(n, _row(4), true, 1)
	assert_eq(str(n.era_anim.key), "stand/down")
	n.step("right")
	n._t = n._duration * 0.5
	a._tick_walker(n, _row(4), true, 1)
	assert_eq(str(n.era_anim.key), "step_r/right")
	assert_eq(str(n.era_anim.turn_from), "down", "a quarter turn is remembered for the blend")
