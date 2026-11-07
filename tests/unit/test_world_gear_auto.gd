extends GutTest
## Area 3 item 1060: gear that fits a spot works by itself. Every gear spot takes exactly one
## piece of gear, so the player never has to pick it from a menu: walking into shallow water
## with Wading Boots, or into vines with the Climbing Pick, just works.

func before_all() -> void:
	Database.load_all()

func test_each_gear_kind_names_one_real_gear_item() -> void:
	var seen: Dictionary = {}
	for k: int in TilesetFactory.GEAR_KINDS:
		var id: String = TilesetFactory.GEAR_KINDS[k]
		assert_true(bool(Database.item(id).get("gear", false)), id)
		assert_false(seen.has(k), "one gear per kind of spot")
		seen[k] = id

func test_wading_needs_no_menu() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	ow.load_map("quillbrook", Vector2i(5, 3), "right")
	ow.player.place(Vector2i(5, 3), "right")
	var wade := Vector2i(6, 3)
	assert_eq(ow.map.kind_at(wade), TilesetFactory.Kind.WADE)
	assert_eq(ow._world.can_enter(wade), 0, "without boots the water stops you")
	GameState.add_item("wading_boots", 1)
	assert_eq(ow._world.can_enter(wade), 1, "with boots you just walk in")
