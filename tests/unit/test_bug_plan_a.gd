extends GutTest
## Bug plan, part A (master plan items 1311-1340): whole-game sweeps that keep fixed bugs fixed.

func before_all() -> void:
	Database.reload_data()

## 1313: every door and passage leads to an existing map, inside it, onto a cell one can stand on.
func test_every_warp_lands_on_a_walkable_cell() -> void:
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for w: Dictionary in m.warps:
			var to: String = str(w.get("to", ""))
			assert_true(MapData.exists(to), "%s -> %s" % [id, to])
			if not MapData.exists(to):
				continue
			var t: MapData = MapData.load_map(to)
			var c := Vector2i(int(w.get("tx", 0)), int(w.get("ty", 0)))
			assert_true(t.in_bounds(c), "%s -> %s %s" % [id, to, c])
			assert_false(TilesetFactory.is_solid(t.kind_at(c)), "%s -> %s %s lands in a wall" % [id, to, c])

## 1314, 1315: every figure and sign points at an existing dialogue entry.
func test_every_figure_and_sign_has_text() -> void:
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for e: Dictionary in m.npcs + m.signs:
			var ref: String = str(e.get("dialogue", ""))
			if ref.is_empty():
				continue
			assert_true(Dialogue.exists(ref), "%s: %s" % [id, ref])

## 1316, 1339: encounter tables have a sane rate, real species, and never a legendary in the grass.
func test_encounter_tables_are_sane() -> void:
	for t: String in EncounterTable.table_ids():
		var r: float = EncounterTable.rate(t)
		assert_between(r, 0.01, 0.35, t)
		for s: Variant in EncounterTable.table(t).get("spawns", []):
			var sd: SpirlingData = Database.species(str((s as Dictionary).get("species", "")))
			assert_not_null(sd, "%s: %s" % [t, s])
			if sd != null:
				assert_ne(sd.rarity, "ancient", "%s: %s" % [t, sd.species_name])

## 1335: every species has a front and a back picture.
func test_every_species_has_front_and_back_art() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		for facing: String in ["front", "back"]:
			assert_ne(EraManager.art_path_from("spirlings/%s_%s.png" % [sd.species_name.to_lower(), facing], sd.era), "",
				"%s %s" % [sd.species_name, facing])

## 1311: a tap-to-move walk stops when the app goes to the background.
func test_leaving_the_app_drops_the_tap_walk() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.follow([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], Vector2i(3, 0))
	p.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(p.path.is_empty())
	assert_eq(p.path_target, Player.NO_TARGET)
