extends GutTest
## Plan area 9, local saves: checksum, read-back check, three rotating backups, structure check.

const TEST_SLOT: String = "user://test_integrity_slot.json"

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
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Puddlet")

func _save_with_money(m: int) -> void:
	GameState.money = m
	assert_true(SaveManager.save_game())

func _overwrite(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_save_carries_a_checksum_that_matches() -> void:
	_save_with_money(5)
	var text: String = FileAccess.get_file_as_string(TEST_SLOT)
	assert_true(text.begins_with(SaveManager.CHECKSUM_PREFIX))
	assert_true(SaveManager.checksum_ok(text))
	var d: Variant = SaveManager.read_save(TEST_SLOT)
	assert_false((d as Dictionary).has("_sha256"), "the checksum never reaches the game or the server")

func test_changed_byte_fails_the_checksum_and_the_backup_loads() -> void:
	_save_with_money(11)
	_save_with_money(22)
	var text: String = FileAccess.get_file_as_string(TEST_SLOT)
	# Still valid JSON, only the number changed: only the checksum can catch this.
	_overwrite(TEST_SLOT, text.replace("\"money\": 22", "\"money\": 99"))
	assert_null(SaveManager.read_save(TEST_SLOT))
	assert_true(SaveManager.load_game())
	assert_eq(GameState.money, 11)
	assert_true(SaveManager.last_load_recovered, "the title screen tells the player")

func test_cut_off_file_falls_back() -> void:
	_save_with_money(1)
	_save_with_money(2)
	var text: String = FileAccess.get_file_as_string(TEST_SLOT)
	_overwrite(TEST_SLOT, text.left(text.length() / 2))
	assert_true(SaveManager.load_game())
	assert_eq(GameState.money, 1)

func test_three_rotating_backups_newest_readable_wins() -> void:
	for m: int in [1, 2, 3, 4, 5]:
		_save_with_money(m)
	for n: int in range(1, SaveManager.BACKUPS + 1):
		assert_true(FileAccess.file_exists(SaveManager.backup_path_for(TEST_SLOT, n)), "backup %d" % n)
	assert_false(FileAccess.file_exists(SaveManager.backup_path_for(TEST_SLOT, SaveManager.BACKUPS + 1)))
	assert_eq(int(SaveManager.read_save(SaveManager.backup_path_for(TEST_SLOT, 3)).money), 2)
	_overwrite(TEST_SLOT, "{ broken")
	_overwrite(SaveManager.backup_path_for(TEST_SLOT, 1), "")
	assert_true(SaveManager.load_game())
	assert_eq(GameState.money, 3, "skips the broken backup and takes the next one")

func test_no_recovery_note_for_a_healthy_save() -> void:
	_save_with_money(7)
	assert_true(SaveManager.load_game())
	assert_false(SaveManager.last_load_recovered)

func test_saves_without_checksum_from_older_builds_still_load() -> void:
	_overwrite(TEST_SLOT, JSON.stringify({"save_version": 3, "money": 42, "party": []}, "\t"))
	assert_true(SaveManager.load_game())
	assert_eq(GameState.money, 42)

func test_delete_removes_every_backup() -> void:
	for m: int in [1, 2, 3, 4]:
		_save_with_money(m)
	SaveManager.delete_save()
	for p: String in SaveManager.save_paths(TEST_SLOT):
		assert_false(FileAccess.file_exists(p), p)
	assert_false(SaveManager.has_save())

func test_sanitize_drops_wrong_types() -> void:
	var d: Dictionary = {"tamer": "x", "party": [5, {"species": "Puddlet", "level": [1], "moves": "a",
		"spark": {"hp": "x", "atk": 3}}], "cell": [1], "money": {"a": 1}, "inventory": {"tonic": [2], "orb": 3},
		"rifts": [1, {}], "map": [], "iron_oath": "true"}
	SaveManager.sanitize(d)
	assert_false(d.has("tamer"))
	assert_false(d.has("cell"))
	assert_false(d.has("money"))
	assert_false(d.has("map"))
	assert_eq(d.party.size(), 1)
	assert_false(d.party[0].has("level"))
	assert_false(d.party[0].has("moves"))
	assert_eq(d.party[0].spark, {"atk": 3})
	assert_eq(d.inventory, {"orb": 3})
	assert_eq(d.rifts, ["1"])
	assert_eq(d.iron_oath, true)

func test_negative_save_version_does_not_break_migration() -> void:
	var d: Variant = SaveManager.parse_save(JSON.stringify({"save_version": -4, "money": 3}))
	assert_true(d is Dictionary)
	assert_eq(int(d.save_version), SaveManager.SAVE_VERSION)
