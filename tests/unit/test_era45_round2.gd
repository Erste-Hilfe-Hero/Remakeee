extends GutTest
## Era IV/V round 2 (docs/ERA_FEEL_UI.md slice 6, docs/ERA_FEEL_BATTLE.md slice 6): the 2.5D
## overworld (raised houses, taller trees and cliffs, whole-number camera zoom, fill around small
## maps), the command column that makes the battle field taller, thicker single-battle Vigor
## bars, and the bold Era IV/V font and frames outside battle.

const SCREENS: Dictionary = {1: Vector2(144, 256), 2: Vector2(144, 256), 3: Vector2(180, 320), 4: Vector2(270, 480), 5: Vector2(270, 480)}
const TOWN_ROWS: Array[String] = ["TTTTTT", "T.RR.T", "T.HD.T", "T.__.T", "T^^^.T", "T....T"]

var _keep: Array[int] = []
var _settings: Dictionary

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false
	EraBattleHud.skin_override = 0

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.set_retro_filter(mini(_keep[1], _keep[0]))
	GameState.settings_from_dict(_settings)
	EraDepthLayer.enabled = true
	EraBattleHud.skin_override = -1

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.set_retro_filter(e)

func _map(region: String, rows: Array[String] = TOWN_ROWS, outdoor: bool = true) -> MapData:
	return MapData.from_dict("era45b_test", {"name": "Test", "region": region, "outdoor": outdoor, "biome": "town", "rows": rows})

# --- Overworld ------------------------------------------------------------------------

func test_camera_zoom_is_a_whole_number_only_on_the_wide_screens() -> void:
	for e: int in range(1, 6):
		var z: int = EraDepthLayer.camera_zoom(e)
		assert_gte(z, 1, "era %d: a whole number" % e)
		assert_eq(float(z), float(EraDepthLayer.for_screen(e).get("zoom", 1)), "era %d from the data" % e)
		var view: Vector2 = (SCREENS[e] as Vector2) / float(z)
		assert_gte(view.x, 128.0, "era %d still shows eight tiles across" % e)
		if e >= 4:
			# The owner (13 Nov): IV/V must not look bigger than Era III.
			assert_lte(16.0 * z / (SCREENS[e] as Vector2).x, 16.0 / 180.0, "era %d reads no closer than Era III" % e)
	EraDepthLayer.enabled = false
	assert_eq(EraDepthLayer.camera_zoom(5), 1, "the before shots keep the old view")

func test_town_zoom_settles_on_the_screen_zoom() -> void:
	_era(5)
	var host := Node2D.new()
	add_child_autofree(host)
	var ground := TileMapLayer.new()
	host.add_child(ground)
	var cam := Camera2D.new()
	host.add_child(cam)
	var look := EraTerrainLook.new()
	look.screen_zoom = true
	host.add_child(look)
	var m: MapData = _map("quivermoor")
	m.paint(ground)
	look.show_map(m, ground, cam)
	var z: float = float(EraDepthLayer.camera_zoom(5))
	assert_eq(look.base_zoom, z)
	assert_almost_eq(cam.zoom.x, 0.9 * z, 0.001, "the town zoom starts a little wider")
	look._process(5.0)
	assert_eq(cam.zoom, Vector2(z, z), "and ends on crisp whole pixels")
	GameState.reduce_motion = true
	look.show_map(m, ground, cam)
	assert_eq(cam.zoom, Vector2(z, z), "reduced motion: no zoom, still the screen zoom")
	_era(3)
	look.show_map(_map("quillmarch"), ground, cam)
	assert_eq(cam.zoom, Vector2.ONE, "Era III keeps its view")

func test_fill_carries_the_border_on() -> void:
	var cells: Dictionary[Vector2i, Vector2i] = EraDepthLayer.fill_cells(Vector2i(4, 3), 2)
	assert_eq(cells.size(), 8 * 7 - 4 * 3)
	assert_eq(cells[Vector2i(-2, -2)], Vector2i(0, 0), "a corner copies the map's corner")
	assert_eq(cells[Vector2i(5, 1)], Vector2i(3, 1), "a side copies the edge cell beside it")
	assert_false(cells.has(Vector2i(1, 1)), "nothing inside the map")

func test_depth_layer_fills_small_outdoor_maps_and_darkens_rooms() -> void:
	_era(5)
	var ground := TileMapLayer.new()
	add_child_autofree(ground)
	var layer := EraDepthLayer.new()
	add_child_autofree(layer)
	var m: MapData = _map("quivermoor")
	m.paint(ground)
	layer.show_map(m, ground)
	var fill: TileMapLayer = layer.get_node("era_fill")
	assert_true(fill.show_behind_parent)
	assert_eq(fill.get_cell_atlas_coords(Vector2i(-3, 2)), ground.get_cell_atlas_coords(Vector2i(0, 2)))
	assert_eq(fill.get_cell_atlas_coords(Vector2i(2, 2)), Vector2i(-1, -1), "the map itself stays the ground's")
	var room: MapData = _map("quivermoor", ["WWWW", "WffW", "WDWW"] as Array[String], false)
	room.paint(ground)
	layer.show_map(room, ground)
	assert_eq(fill.get_used_cells().size(), 0, "a room gets the dark colour, not its walls carried on")
	assert_false(str(layer.screen_cfg.get("indoor", "")).is_empty())

func test_old_regions_keep_their_look_on_the_wide_screen() -> void:
	_era(5)
	assert_true(EraDepthLayer.for_map("veydal", 5).is_empty(), "no raised houses in the story acts")
	assert_eq(EraDepthLayer.for_screen(5).get("fill"), "edge", "but the screen fill holds everywhere")
	assert_eq(EraDepthLayer.lift_of("veydal", TilesetFactory.Kind.TREE, 5), 5, "and the canopy keeps its lift")

func test_lifts_grow_from_era_four_to_five_and_agree_with_the_canopy() -> void:
	var four: Dictionary = EraDepthLayer.cfg().eras["4"]
	var five: Dictionary = EraDepthLayer.cfg().eras["5"]
	assert_gt(int(four.raise), 0, "Era IV houses stand taller")
	assert_gte(int(five.raise), int(four.raise))
	for k: String in ["TREE", "CLIFF", "ROOF"]:
		assert_gt(int(four.lift[k]), 0, k)
		assert_gte(int(five.lift[k]), int(four.lift[k]), k)
	assert_eq(int(four.lift.ROOF), int(four.raise), "the canopy ridge sits on the lifted roof")
	assert_eq(int(five.lift.ROOF), int(five.raise))
	_era(5)
	assert_eq(EraDepthLayer.lift_of("quivermoor", TilesetFactory.Kind.TREE, 1), int(five.lift.TREE))
	assert_eq(EraDepthLayer.lift_of("halcyra", TilesetFactory.Kind.ROOF, 1), int(four.lift.ROOF))
	assert_eq(EraDepthLayer.lift_of("halcyra", TilesetFactory.Kind.LAMP, 3), 3, "kinds without a lift keep the canopy's")
	EraDepthLayer.enabled = false
	assert_eq(EraDepthLayer.lift_of("quivermoor", TilesetFactory.Kind.TREE, 6), 6)

func test_stretched_tiles_close_the_gap_exactly() -> void:
	for b: Vector2i in [Vector2i(2, 3), Vector2i(4, 11), Vector2i(12, 13)]:
		for lift: int in [6, 8, 10]:
			var strips: Array[Vector3i] = EraDepthLayer.stretch_rows(b, lift)
			assert_eq(strips[0], Vector3i(-lift, 0, b.x), "the top rows move up by the lift")
			var y: int = b.x - lift
			for i: int in range(1, strips.size()):
				assert_eq(strips[i].x, y, "strips follow each other")
				assert_true(strips[i].y >= b.x and strips[i].y + strips[i].z <= b.y, "only band rows repeat")
				y += strips[i].z
			assert_eq(y, b.x, "the band ends where the old row stood")
	assert_true(EraDepthLayer.stretch_rows(Vector2i(2, 3), 0).is_empty())

func test_raised_house_faces_reach_the_lifted_roof() -> void:
	var c := Vector2i(3, 2)
	var s: PackedVector2Array = EraDepthLayer.side_face(c, 6, -10.0, 6.0)
	var t: PackedVector2Array = EraDepthLayer.top_face(c, 6, -10.0)
	assert_eq(s[0], t[3], "the side wall meets the top face of the lifted roof")
	assert_eq(s[1], t[2])
	assert_eq(s[0].y, c.y * 16.0 - 10.0)

# --- Battle ---------------------------------------------------------------------------

func _field_h(era: int) -> float:
	return (SCREENS[era] as Vector2).y - EraBattleHud.text_box_height(era) - EraBattleHud.menu_height(era)

func test_command_column_makes_the_field_taller() -> void:
	for e: int in [4, 5]:
		assert_eq(EraBattleHud.text(e, "commands"), "column")
		var arts: int = Spirling.MAX_MOVES * int(EraBattleHud.num(e, "art_h")) + Spirling.MAX_MOVES - 1
		assert_lte(EraBattleHud.command_column_height(e), arts, "the column is no taller than the arts")
		assert_gte(_field_h(e), 290.0, "era %d: the field takes 60 %% of the screen" % e)
		assert_gte(int(EraBattleHud.num(e, "command_h")), 22, "commands stay finger sized")
	for e: int in [1, 2, 3]:
		assert_ne(EraBattleHud.text(e, "commands"), "column", "older eras keep their menu")

func test_command_menu_puts_the_commands_beside_the_arts() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 9)] as Array[Spirling], [BattleFixtures.make("Zippit", 7)] as Array[Spirling], true, 3)
	m.inventory = {"tonic": 2}
	m.start()
	var keep: String = EraBattleHud.last_item
	EraBattleHud.last_item = "tonic"
	_era(4)
	var menu := CommandMenu.new()
	add_child_autofree(menu)
	menu.size = Vector2(270, 0)
	menu.refresh(m, 0)
	await get_tree().process_frame
	var arts: Node = menu._move_buttons[0].get_parent()
	assert_true(arts is VBoxContainer, "the arts stay one column")
	assert_true(arts.get_parent() is HBoxContainer, "with the commands beside them")
	assert_eq(menu._swap.get_parent(), menu._column)
	assert_eq(menu._shortcut.get_parent(), menu._column)
	assert_eq(menu._shortcut.text, "%s x2" % Loc.t(str(Database.item("tonic").get("name", "tonic"))), "the column shows item and count")
	assert_gt(menu._move_buttons[0].size.x, menu._swap.size.x * 1.8, "the arts keep most of the width")
	EraBattleHud.last_item = keep

func test_single_battle_bars_are_thicker_formation_bars_unchanged() -> void:
	for e: int in range(1, 6):
		var single: Dictionary = EraBattleHud.plate_rows(e, true)
		var ledger: Dictionary = EraBattleHud.plate_rows(e)
		assert_eq(int(ledger.bar_h), int(EraBattleHud.num(e, "bar_h")), "era %d ledger" % e)
		if e >= 4:
			assert_gte(int(single.bar_h), int(ledger.bar_h) + 3, "era %d: a thick bar one-on-one" % e)
		else:
			assert_eq(int(single.bar_h), int(ledger.bar_h), "era %d unchanged" % e)
		assert_gte(int(single.row3_y), int(single.bar_y) + int(single.bar_h) + 2, "Energy row under the thick bar")
	var strip := InfoStrip.new()
	assert_false(strip.single, "a strip is a ledger until the one-on-one layout says otherwise")
	strip.free()

# --- Font and frames ------------------------------------------------------------------

func test_era_four_and_five_font_is_bold_and_keeps_every_pixel() -> void:
	assert_true(EraFont.is_bold("pano12"))
	assert_false(EraFont.is_bold("etch10"), "Era III keeps its thin etching")
	for ch: String in ["A", "g", "W", "ä", "1"]:
		var raw: Array = EraFontGlyphs.FONTS["pano12"].glyphs[ch]
		var bold: Array = EraFont.glyph("pano12", ch)
		assert_eq(bold.size(), raw.size())
		for r: int in raw.size():
			assert_eq(str(bold[r]).length(), str(raw[r]).length() + 1, "'%s' one px wider" % ch)
			for x: int in str(raw[r]).length():
				if str(raw[r])[x] == "#":
					assert_eq(str(bold[r])[x], "#", "'%s' keeps every pixel" % ch)
	assert_eq(PixelFont.embolden(["#.#"]), ["####"] as Array[String])
	assert_eq(PixelFont.bold_glyph("A"), PixelFont.embolden(PixelFont.large_glyph("A")), "the same strokes as the battle HUD")

func test_era_four_and_five_frames_have_a_heavy_rule() -> void:
	for kind: String in ["panorama", "living"]:
		var img: Image = (UITheme.frame_style_of(kind) as StyleBoxTexture).texture.get_image()
		assert_eq(img.get_pixel(4, 0), UITheme.INK, kind)
		assert_eq(img.get_pixel(4, 1), UITheme.INK, "%s: two px of ink" % kind)
	var etched: Image = (UITheme.frame_style_of("etched") as StyleBoxTexture).texture.get_image()
	assert_ne(etched.get_pixel(4, 1), UITheme.INK, "Era III keeps its bevel")

func test_battle_text_box_writes_bold_in_era_four() -> void:
	_era(4)
	var host := Control.new()
	host.theme = EraBattleHud.theme(4)
	add_child_autofree(host)
	var tb := TextBox.new()
	host.add_child(tb)
	await get_tree().process_frame
	assert_eq(tb._label.get_theme_font("font"), PixelFont.get_bold_font())
