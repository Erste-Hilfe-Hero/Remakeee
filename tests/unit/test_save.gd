extends GutTest
## SaveManager: atomic writes, backup fallback, migrations, round trip.

const TEST_SLOT: String = "user://test_save_slot.json"

var _old_slot: String

func before_all() -> void:
	Database.load_all()
	_old_slot = SaveManager.slot_path
	SaveManager.slot_path = TEST_SLOT

func after_all() -> void:
	SaveManager.delete_save()
	SaveManager.slot_path = _old_slot

func before_each() -> void:
	SaveManager.delete_save()
	GameState.new_game(GameState.Difficulty.VETERAN, "Tess", 2, "Puddlet")

func test_round_trip_restores_state() -> void:
	GameState.add_item("tonic", 4)
	GameState.money = 1234
	GameState.current_map = "fernstair"
	GameState.player_cell = Vector2i(6, 9)
	GameState.set_flag("route1_gift")
	GameState.storage.append(Spirling.new(Database.species("Zippit"), 3))
	var before: Dictionary = GameState.to_dict()
	assert_true(SaveManager.save_game())
	GameState.reset()
	assert_true(SaveManager.load_game())
	var after: Dictionary = GameState.to_dict()
	assert_eq(JSON.stringify(after), JSON.stringify(before))
	assert_eq(GameState.difficulty, GameState.Difficulty.VETERAN)
	assert_eq(GameState.party[0].data.species_name, "Puddlet")

func test_save_has_version_and_no_temp_file_left() -> void:
	SaveManager.save_game()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SLOT))
	assert_eq(int(raw.save_version), SaveManager.SAVE_VERSION)
	assert_false(FileAccess.file_exists(SaveManager.temp_path()))

func test_second_save_keeps_backup_and_corrupt_main_falls_back() -> void:
	GameState.money = 1
	SaveManager.save_game()
	GameState.money = 2
	SaveManager.save_game()
	assert_true(FileAccess.file_exists(SaveManager.backup_path()))
	var f := FileAccess.open(TEST_SLOT, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	assert_true(SaveManager.load_game())
	assert_eq(GameState.money, 1, "loaded the backup")

func test_migrates_scaffold_v0_save() -> void:
	var v0: Dictionary = {"region": "veydal", "rifts": ["rift_1"], "difficulty": 3}
	var d: Variant = SaveManager.migrate(v0)
	assert_true(d is Dictionary)
	assert_eq(int(d.save_version), SaveManager.SAVE_VERSION)
	assert_true(bool(d.flags.rift_1_sealed))
	SaveManager.apply_save(d)
	assert_eq(GameState.difficulty, GameState.Difficulty.RIFT_BORN)

func test_migrates_v1_save_to_the_rebuilt_world() -> void:
	var v1: Dictionary = {"save_version": 1, "map": "route_2", "cell": [3, 3], "heal_map": "home",
		"heal_cell": [4, 4], "flags": {"rival_kestra_1": true}}
	var d: Variant = SaveManager.migrate(v1)
	assert_eq(str(d.map), "crowcrest")
	assert_eq(str(d.heal_map), "lighthouse")
	assert_true(bool(d.flags.kestra_spar))
	var m: MapData = MapData.load_map(str(d.map))
	assert_true(m.is_walkable(Vector2i(int(d.cell[0]), int(d.cell[1]))), "lands on an open cell")

func test_rejects_newer_save() -> void:
	assert_null(SaveManager.migrate({"save_version": SaveManager.SAVE_VERSION + 1}))

func test_items_outside_battle_and_storage_rules() -> void:
	var s: Spirling = GameState.party[0]
	GameState.add_item("tonic", 1)
	assert_eq(GameState.use_item_outside_battle("tonic", s), "", "full HP: no effect, not consumed")
	assert_eq(GameState.item_count("tonic"), 1)
	s.hp = 1
	assert_ne(GameState.use_item_outside_battle("tonic", s), "")
	assert_eq(GameState.item_count("tonic"), 0)
	assert_false(GameState.deposit(0), "cannot deposit the last Spirling")
	GameState.receive_spirling(Spirling.new(Database.species("Breezel"), 3))
	assert_true(GameState.deposit(0))
	assert_eq(GameState.storage.size(), 1)
	assert_true(GameState.withdraw(0))
	assert_eq(GameState.party.size(), 2)

func test_party_overflow_goes_to_storage_and_spirlog_tracks() -> void:
	for i: int in 6:
		GameState.receive_spirling(Spirling.new(Database.species("Zippit"), 2))
	assert_eq(GameState.party.size(), GameState.MAX_PARTY)
	assert_eq(GameState.storage.size(), 1)
	assert_true(bool(GameState.spirlog.Zippit.bonded))
