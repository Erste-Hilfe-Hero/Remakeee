extends GutTest
## Era IV/V redo (docs/ERA_FEEL_BATTLE.md slice 5): painted stage scenes, crisp bigger Spirlings,
## Era V golden-hour light and send-out camera, the bold HUD font and overworld building depth.

const FIELD := Vector2(270, 250)
const ERA3_SHARE: float = 64.0 / 180.0

var _keep: Array[int] = []
var _settings: Dictionary

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false
	Era45Look.biome_override = ""

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)
	Era45Look.biome_override = ""

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

func _stage(e: int) -> Era4Stage:
	_era(e)
	var st := Era4Stage.new()
	st.size = FIELD
	add_child_autofree(st)
	return st

func test_every_scene_sets_every_colour() -> void:
	for n: String in Era45Look.SCENES:
		var cols: Dictionary = Era45Look.scene(n).get("colours", {})
		for k: String in Era45Look.COLOUR_KEYS:
			assert_true(cols.has(k), "%s has %s" % [n, k])
			assert_true(Color.html_is_valid(str(cols.get(k, ""))), "%s %s is a colour" % [n, k])
	for e: int in [4, 5]:
		for k: String in ["animate", "sun", "shadow", "grade", "sprite", "slabs", "sendout_zoom"]:
			assert_true(Era45Look.era_look(e).has(k), "era %d has %s" % [e, k])

func test_scene_follows_terrain_and_biome() -> void:
	assert_eq(Era45Look.scene_for("field", "route"), "meadow")
	assert_eq(Era45Look.scene_for("field", "cave"), "cave")
	assert_eq(Era45Look.scene_for("ember", "dungeon"), "cave", "a cellar fight stays underground")
	assert_eq(Era45Look.scene_for("lake", "town"), "water", "a lakeside town fights on the water")
	assert_eq(Era45Look.scene_for("field", "town"), "town")
	assert_eq(Era45Look.scene_for("ridge", ""), "snow")
	assert_eq(Era45Look.scene_for("ember", "route"), "ember")
	assert_eq(Era45Look.scene_for("voice", "rift"), "voice")
	assert_eq(Era45Look.scene_for("nowhere", "nothing"), "meadow")

func test_stage_takes_the_scene_of_the_map() -> void:
	Era45Look.biome_override = "cave"
	var st: Era4Stage = _stage(4)
	st.set_terrain("field")
	assert_eq(st.scene_name, "cave")
	Era45Look.biome_override = "route"
	st.set_terrain("lake")
	assert_eq(st.scene_name, "water")

func test_sprites_are_whole_multiples_of_their_art() -> void:
	for e: int in [4, 5]:
		for side: String in ["foe", "player"]:
			for art: float in [56.0, 64.0, 96.0]:
				var px: float = Era45Look.sprite_px(e, side, art)
				assert_eq(fmod(px, art), 0.0, "era %d %s art %d is crisp" % [e, side, art])
				assert_gte(px, art)
				assert_lte(px, 192.0)

func test_spirlings_stand_bigger_than_in_era_three() -> void:
	# Era III draws 64 px on a 180 px screen; Era IV/V on 270 px.
	for art: float in [56.0, 64.0, 96.0]:
		assert_gte(Era45Look.sprite_px(4, "player", art) / 270.0, ERA3_SHARE * 1.5, "player art %d at least 1.5x" % art)
		assert_gte(Era45Look.sprite_px(4, "foe", art) / 270.0, ERA3_SHARE, "foe art %d no smaller" % art)

func test_snap_keeps_the_cap() -> void:
	assert_eq(Era45Look.snap_px(160.0, 96.0, 192.0), 192.0)
	assert_eq(Era45Look.snap_px(160.0, 56.0, 150.0), 112.0, "3x would pass the cap")
	assert_eq(Era45Look.snap_px(40.0, 96.0, 192.0), 96.0, "never below 1x")
	assert_eq(Era45Look.snap_px(50.0, 0.0, 192.0), 50.0)

func test_fit_sprite_stands_on_its_slab() -> void:
	var st: Era4Stage = _stage(4)
	for side: String in ["foe", "player"]:
		var r: Rect2 = st.fit_sprite(side, FIELD, 56.0)
		var q: PackedVector2Array = Era4Stage.slab_quad(st.cfg, side, FIELD)
		assert_eq(r.size.x, Era45Look.sprite_px(4, side, 56.0))
		assert_between(r.end.y, q[0].y, q[3].y, "%s feet on the slab top" % side)
	var foe: PackedVector2Array = Era4Stage.slab_quad(st.cfg, "foe", FIELD)
	var mine: PackedVector2Array = Era4Stage.slab_quad(st.cfg, "player", FIELD)
	assert_lt(foe[3].y, mine[0].y, "the foe stands further back")
	assert_lt(mine[3].y, FIELD.y, "the player's slab shows inside the field")

func test_slabs_stay_flat_topped_not_oval() -> void:
	var st: Era4Stage = _stage(5)
	for side: String in ["foe", "player"]:
		var o: PackedVector2Array = Era4Stage.knoll_outline(Era4Stage.slab_quad(st.cfg, side, FIELD))
		assert_eq(o.size(), 8, "a cut-corner block")
		assert_eq(o[1].y, o[2].y, "flat far edge")
		assert_eq(o[5].y, o[6].y, "flat near edge")
		assert_gt(o[2].x - o[1].x, (o[2].x - o[7].x) * 0.5, "the straight far edge is most of the width")

func test_era_five_is_golden_and_era_four_is_daylight() -> void:
	for n: String in Era45Look.SCENES:
		var four: Dictionary = Era45Look.palette(n, 4)
		var five: Dictionary = Era45Look.palette(n, 5)
		var raw: Dictionary = Era45Look.scene(n).colours
		assert_eq((four.sky_top as Color).to_html(false), str(raw.sky_top), "%s: Era IV keeps the drawn colours" % n)
		assert_gt((five.ground_near as Color).r, (four.ground_near as Color).r, "%s: Era V is warmer" % n)
		assert_eq(five.accent, four.accent, "%s: lamps and embers keep their glow" % n)
	var cave_shift: float = (Era45Look.palette("cave", 5).ground_near as Color).r - (Era45Look.palette("cave", 4).ground_near as Color).r
	var meadow_shift: float = (Era45Look.palette("meadow", 5).ground_near as Color).r - (Era45Look.palette("meadow", 4).ground_near as Color).r
	assert_lt(cave_shift, meadow_shift, "caves take less of the sunset")

func test_light_layer_only_in_era_five() -> void:
	assert_null(_stage(4).light_layer(), "Era IV has plain daylight")
	assert_not_null(_stage(5).light_layer(), "Era V lays golden light over the field")

func test_motion_only_in_era_five_and_never_reduced() -> void:
	assert_false(Era45Look.animates(4, false))
	assert_true(Era45Look.animates(5, false))
	assert_false(Era45Look.animates(5, true), "reduced motion stills clouds, grass and water")
	GameState.reduce_motion = true
	var st: Era4Stage = _stage(5)
	st._process(0.5)
	assert_eq(st._time, 0.0)

func test_sendout_camera_leans_in_only_in_era_five() -> void:
	var node := Control.new()
	node.size = FIELD
	add_child_autofree(node)
	_era(4)
	BattleCamera.sendout(node, Rect2(20, 120, 112, 112))
	assert_eq(node.scale, Vector2.ONE, "Era IV keeps the send-out still")
	_era(5)
	GameState.reduce_motion = true
	BattleCamera.sendout(node, Rect2(20, 120, 112, 112))
	assert_eq(node.scale, Vector2.ONE, "reduced motion: no camera")
	GameState.reduce_motion = false
	BattleCamera.sendout(node, Rect2(20, 120, 112, 112))
	await wait_process_frames(4)
	assert_gt(node.scale.x, 1.0, "Era V leans in on the new Spirling")

func test_bold_font_doubles_the_strokes() -> void:
	for ch: String in ["I", "H", "a", "7"]:
		var large: Array[String] = PixelFont.large_glyph(ch)
		var bold: Array[String] = PixelFont.bold_glyph(ch)
		assert_eq(bold.size(), large.size())
		var lit_l: int = 0
		var lit_b: int = 0
		for r: int in large.size():
			lit_l += large[r].count("#")
			lit_b += bold[r].count("#")
			for x: int in large[r].length():
				if large[r][x] == "#":
					assert_eq(bold[r][x], "#", "'%s' keeps every pixel" % ch)
		assert_gt(lit_b, lit_l, "'%s' is heavier" % ch)

func test_era_four_and_five_hud_use_the_bold_font() -> void:
	for e: int in [4, 5]:
		assert_true(EraBattleHud.bold_font(e))
		assert_eq(EraBattleHud.font(e), PixelFont.get_bold_font())
		assert_eq(EraBattleHud.theme(e).default_font, PixelFont.get_bold_font())
		assert_eq(EraBattleHud.line_h(e), PixelFont.LARGE_H)
	for e: int in [1, 2, 3]:
		assert_false(EraBattleHud.bold_font(e))

func test_player_plate_keeps_room_beside_a_big_sprite() -> void:
	var big := Rect2(0, 60, 192, 192)
	var l: Dictionary = EraBattleHud.single_layout(4, FIELD, Rect2(150, 40, 96, 96), big)
	assert_gte((l.player_plate as Rect2).size.x, roundf(FIELD.x * EraBattleHud.MIN_PLAYER_PLATE))
	assert_lte((l.player_plate as Rect2).end.x, FIELD.x)

func test_overworld_depth_only_for_era_four_and_five_regions() -> void:
	assert_true(EraDepthLayer.for_map("veydal", 5).is_empty(), "the story acts keep their flat look")
	assert_true(EraDepthLayer.for_map("quillmarch", 5).is_empty(), "Era III stays flat")
	assert_eq(int(EraDepthLayer.for_map("halcyra", 5).side), int(EraDepthLayer.cfg().eras["4"].side))
	assert_eq(int(EraDepthLayer.for_map("quivermoor", 5).side), int(EraDepthLayer.cfg().eras["5"].side))
	assert_true(EraDepthLayer.for_map("quivermoor", 3).is_empty(), "the Retro filter flattens it again")
	assert_gte(int(EraDepthLayer.cfg().eras["5"].side), int(EraDepthLayer.cfg().eras["4"].side))
	assert_true(TilesetFactory.Kind.DOOR in EraDepthLayer.kinds(), "doors are part of the house")

func test_depth_faces_meet_at_the_corner() -> void:
	var c := Vector2i(3, 2)
	var s: PackedVector2Array = EraDepthLayer.side_face(c, 5)
	var t: PackedVector2Array = EraDepthLayer.top_face(c, 5)
	assert_eq(s[1], t[2], "side wall and top face share the back corner")
	assert_eq(s[0], t[3], "and the front corner")
	assert_lt(s[1].y, s[0].y, "the faces lean back")
