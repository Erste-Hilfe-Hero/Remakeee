extends GutTest
## Updating keeps the journey (1.3.2): a save, settings file and cloud copy written by every
## shipped release loads with the current code and nothing in it is lost. The fixtures under
## tests/fixtures/saves/releases/ were written by each release's own code at its release commit
## (tools/save_fixtures/make_release_fixture.sh), so they have exactly the shape players have.
## The check is generic: every value an old save had must come back unchanged after loading,
## and fields added since (with their defaults) need no change here. When a release ships, add
## its fixture with the script and its name to RELEASES.

const DIR: String = "res://tests/fixtures/saves/releases/"
## version -> difficulty the fixture journey was started on (Rift-Born, Veteran, Story, Veteran).
const RELEASES: Dictionary[String, int] = {"1.1.0": 3, "1.2.0": 2, "1.3.0": 0, "1.3.1": 2}
## Keys whose old value does not have to come back: bookkeeping, or a choice 1.3.2 removed
## on purpose (#646: one mode for everyone, checked in its own test).
const NOT_KEPT: Array[String] = ["_sha256", "saved_at", "save_version", "difficulty"]
## Team and storage the generator gave every fixture journey: [species, ring]. 1.1.0 capped every
## Spirling at Ring 60, so its storage holds 60 where later releases hold 75 and 61.
const PARTY: Array = [["Kindlop", 42], ["Zippit", 31], ["Wickit", 19], ["Puddlet", 12], ["Mirkmole", 8]]
const STORAGE: Array = [["Puddlet", 75], ["Zippit", 3], ["Wickit", 61]]
const TEST_SLOT: String = "user://test_release_save.json"

var _saved: Dictionary
var _settings: Dictionary
var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_revs: Dictionary
var _old_dirty: Dictionary
var _kept_slot: String = ""

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_revs = Online.revs.duplicate()
	_old_dirty = Online.dirty.duplicate()
	var p: String = SaveManager.path_for_slot(1)
	if FileAccess.file_exists(p):
		_kept_slot = FileAccess.get_file_as_string(p)

func after_all() -> void:
	SaveManager.set_slot(1)
	SaveManager.delete_save()
	if not _kept_slot.is_empty():
		SaveManager.write_atomic(SaveManager.path_for_slot(1), _kept_slot)
	Online.backend = _old_backend
	Online.state = _old_state
	Online.revs = _old_revs
	Online.dirty = _old_dirty
	Online.conflicts.clear()
	GameState.in_game = false

func before_each() -> void:
	_saved = GameState.to_dict()
	_settings = GameState.settings_to_dict()

func after_each() -> void:
	GameState.from_dict(_saved)
	GameState.settings_from_dict(_settings)
	SaveManager.slot_path = SaveManager.path_for_slot(SaveManager.slot)
	for p: String in SaveManager.save_paths(TEST_SLOT) + [TEST_SLOT + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func _text(version: String) -> String:
	return FileAccess.get_file_as_string(DIR + "save_%s.json" % version)

## Highest ring the code of [param version] could write (1.1.0: Ring 60 for every Spirling).
func _old_cap(version: String) -> int:
	return 60 if version == "1.1.0" else 1000

func _old(version: String) -> Dictionary:
	return JSON.parse_string(_text(version))

## Paths of every value in [param old] that [param now] lost or changed (scalars compared as
## JSON: 5 and 5.0 are equal). Keys only [param now] has are new fields and fine.
static func lost(old: Variant, now: Variant, path: String = "") -> Array[String]:
	var out: Array[String] = []
	if old is Dictionary:
		if not now is Dictionary:
			return [path + " (no longer a dictionary)"]
		for k: Variant in old:
			if path.is_empty() and str(k) in NOT_KEPT:
				continue
			if not (now as Dictionary).has(k):
				out.append(path + str(k) + " (dropped)")
			else:
				out.append_array(lost(old[k], now[k], path + str(k) + "."))
	elif old is Array:
		if not now is Array or (now as Array).size() != (old as Array).size():
			return [path + " (list changed size)"]
		for i: int in (old as Array).size():
			out.append_array(lost(old[i], now[i], path + str(i) + "."))
	elif not same(old, now):
		out.append("%s %s -> %s" % [path, JSON.stringify(old), JSON.stringify(now)])
	return out

## True when two scalars hold the same value; JSON reads every number back as a float.
static func same(a: Variant, b: Variant) -> bool:
	var num: Array[int] = [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return is_equal_approx(float(a), float(b))
	return JSON.stringify(a) == JSON.stringify(b)

func test_there_is_a_fixture_for_every_release() -> void:
	for v: String in RELEASES:
		assert_true(FileAccess.file_exists(DIR + "save_%s.json" % v), "save of %s" % v)
		assert_true(FileAccess.file_exists(DIR + "settings_%s.json" % v), "settings of %s" % v)
		assert_eq(int(_old(v).save_version), 5, "%s wrote save version 5" % v)

func test_every_release_save_loads_with_nothing_lost() -> void:
	for v: String in RELEASES:
		var d: Variant = SaveManager.parse_save(_text(v))
		assert_true(d is Dictionary, "%s: checksum and structure accepted" % v)
		SaveManager.apply_save(d)
		var miss: Array[String] = lost(_old(v), SaveManager.build_save())
		assert_eq(miss, [] as Array[String], "%s: values lost on load" % v)

func test_team_storage_bag_and_place_are_kept() -> void:
	for v: String in RELEASES:
		SaveManager.apply_save(SaveManager.parse_save(_text(v)))
		assert_eq(GameState.party.size(), PARTY.size(), v)
		for i: int in PARTY.size():
			assert_eq(GameState.party[i].data.species_name, PARTY[i][0], v)
			assert_eq(GameState.party[i].level, PARTY[i][1], "%s: team ring" % v)
		assert_eq(GameState.party[0].nickname, "Funke", v)
		assert_eq(GameState.storage.size(), STORAGE.size(), v)
		for i: int in STORAGE.size():
			assert_eq(GameState.storage[i].data.species_name, STORAGE[i][0], v)
			assert_eq(GameState.storage[i].level, mini(STORAGE[i][1], _old_cap(v)), "%s: storage ring" % v)
		assert_true(GameState.storage[1].gleam, "%s: a Gleam Spirling stays Gleam" % v)
		assert_eq(GameState.item_count("tonic"), 7, v)
		assert_eq(GameState.item_count("kin_charm"), 25, v)
		assert_eq(GameState.money, 12345, v)
		assert_eq(GameState.rifts_sealed, ["cinder", "tide"] as Array[String], v)
		for f: String in ["aldo_gift", "kestra_spar", "storage_remote", "got_starter"]:
			assert_true(GameState.has_flag(f), "%s: flag %s" % [v, f])
		assert_eq(GameState.current_map, "brindlewick", v)
		assert_eq(GameState.player_cell, Vector2i(5, 5), v)
		assert_true(MapData.load_map(GameState.current_map).is_walkable(GameState.player_cell), v)
		assert_eq(GameState.tamer_name, "Ali", v)
		assert_true(bool(GameState.spirlog.Mirkmole.bonded), "%s: Spirlog kept" % v)
		assert_almost_eq(GameState.play_time, 7384.0, 1.0, v)

func test_old_difficulty_is_ignored() -> void:
	for v: String in RELEASES:
		assert_eq(int(_old(v).difficulty), RELEASES[v], "%s fixture was started on that difficulty" % v)
		SaveManager.apply_save(SaveManager.parse_save(_text(v)))
		assert_eq(GameState.difficulty, GameState.Difficulty.TAMER, "%s loads in the one mode" % v)
		assert_true(GameState.items_allowed_in_battle(), "%s: a Rift-Born save may use items now" % v)
		assert_eq(int(SaveManager.build_save().difficulty), GameState.Difficulty.TAMER, v)

func test_spirlings_above_any_old_cap_keep_growing() -> void:
	for v: String in RELEASES:
		SaveManager.apply_save(SaveManager.parse_save(_text(v)))
		# Two Rifts sealed: the old Veteran cap was 18; these stand far above it (1.1.0 storage at its own Ring 60 cap).
		var lead: Spirling = GameState.party[0]
		assert_gt(lead.level, GameState.PROGRESS_RINGS[GameState.rifts_sealed.size()], v)
		var top: Spirling = GameState.storage[0]
		assert_eq(top.level, mini(75, _old_cap(v)), v)
		var hp_before: int = lead.max_hp()
		lead.level_up()
		assert_eq(lead.level, 43, "%s: a Ring 42 Spirling still grows" % v)
		assert_gt(lead.max_hp(), hp_before, v)
		assert_gt(top.xp_to_next(), 0, "%s: Ring %d can still grow" % [v, top.level])
		var ring: int = top.level
		top.level_up()
		assert_eq(top.level, ring + 1, "%s: past the old Ring 60 cap" % v)
		GameState.from_dict(GameState.to_dict())
		assert_eq(GameState.party[0].level, 43, "%s: the new ring is saved" % v)
		assert_eq(GameState.storage[0].level, ring + 1, v)

func test_file_on_disk_loads_and_saves_again_unchanged() -> void:
	for v: String in RELEASES:
		var f := FileAccess.open(TEST_SLOT, FileAccess.WRITE)
		f.store_string(_text(v))
		f.close()
		SaveManager.slot_path = TEST_SLOT
		assert_true(SaveManager.load_game(), "%s: load_game" % v)
		assert_false(SaveManager.last_load_recovered, "%s: no backup needed" % v)
		assert_true(SaveManager.save_game(), "%s: saves in 1.3.2 format" % v)
		var again: Variant = SaveManager.read_save(TEST_SLOT)
		assert_true(again is Dictionary, v)
		assert_eq(lost(_old(v), again), [] as Array[String], "%s: lost after saving again" % v)
		SaveManager.delete_save()

func test_old_settings_are_kept() -> void:
	for v: String in RELEASES:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "settings_%s.json" % v))
		GameState.settings_from_dict(old)
		var now: Dictionary = GameState.settings_to_dict()
		assert_eq(GameState.text_speed, 2, v)
		assert_almost_eq(GameState.volume, 0.55, 0.001, v)
		assert_almost_eq(GameState.music_volume, 0.4, 0.001, v)
		assert_eq(GameState.vibration, 1, v)
		assert_eq(GameState.language, "de", v)
		# The journey switched the weather off. 1.3.1 forced it off for everyone, so its "off" is
		# turned on once (owner 27.11.2026); before 1.3.1 off was the player's choice and stays.
		assert_eq(GameState.weather, v == "1.3.1", "%s: weather" % v)
		for k: String in old:
			if now.has(k) and not k in ["era", "slot", "weather"]:
				assert_true(lost(old[k], now[k]).is_empty(), "%s: setting %s %s -> %s" % [v, k, old[k], now[k]])

## The server keeps the copy an old release uploaded (save_put adds "schema"). Pulling it onto a
## 1.3.2 phone and loading it must keep everything, and the next upload is the 1.3.2 format.
func test_cloud_copy_from_an_old_release_loads_and_goes_up_upgraded() -> void:
	for v: String in RELEASES:
		var server := LocalBackend.new()
		server.rng.seed = 1
		Online.backend = server
		Online.state = Online.State.OFFLINE
		Online.revs = {}
		Online.dirty = {}
		SaveManager.set_slot(1)
		SaveManager.delete_save()
		assert_eq(await Online.connect_now(), Online.State.ONLINE, v)
		var up: Dictionary = _old(v)
		up.erase("_sha256")
		up["schema"] = Online.SAVE_SCHEMA
		var put: Dictionary = (await server.call_fn("save_put", {"p_slot": 1, "p_data": up, "p_summary": "", "p_base_rev": 0})).data
		assert_true(bool(put.ok), "%s: the server took the old copy" % v)
		assert_true(await Online.sync_down(), v)
		assert_true(SaveManager.load_game(), "%s: pulled copy loads" % v)
		assert_eq(lost(_old(v), SaveManager.build_save()), [] as Array[String], "%s: lost through the cloud" % v)
		assert_eq(GameState.difficulty, GameState.Difficulty.TAMER, v)
		assert_true(SaveManager.save_game(), v)
		await wait_process_frames(2)
		var back: Dictionary = (await server.call_fn("save_get", {"p_slot": 1})).data
		assert_eq(int(back.rev), 2, "%s: the upgraded journey went up" % v)
		assert_eq(int(back.data.difficulty), GameState.Difficulty.TAMER, v)
		assert_eq(back.data.party.size(), PARTY.size(), v)

## A cloud copy can be older than any release on the phone (a save made before version 5):
## it is migrated when the slot is loaded, like a file on disk.
func test_cloud_copy_with_an_older_save_version_is_migrated() -> void:
	var server := LocalBackend.new()
	server.rng.seed = 1
	Online.backend = server
	Online.state = Online.State.OFFLINE
	Online.revs = {}
	Online.dirty = {}
	SaveManager.set_slot(1)
	SaveManager.delete_save()
	await Online.connect_now()
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v4_spirling_story.json"))
	old["schema"] = Online.SAVE_SCHEMA
	assert_true(bool((await server.call_fn("save_put", {"p_slot": 1, "p_data": old.duplicate(true), "p_summary": "", "p_base_rev": 0})).data.ok))
	assert_true(await Online.sync_down())
	assert_true(SaveManager.load_game())
	assert_eq(GameState.party[0].temper, "curious")
	assert_eq(GameState.party[0].origin_map, "lighthouse")
	assert_eq(GameState.waymarks, 0, "version 5 defaults added")
	assert_eq(GameState.difficulty, GameState.Difficulty.TAMER)
	assert_true(SaveManager.save_game())
	await wait_process_frames(2)
	var back: Dictionary = (await server.call_fn("save_get", {"p_slot": 1})).data
	assert_eq(int(back.data.save_version), SaveManager.SAVE_VERSION)

## Riftglass and shop unlocks live in the account (server, or user://local_server.json offline).
## A store from before 1.3.2 keeps its balance, and a Ring Cap Seal owner keeps the unlock
## although the seal is off sale and changes nothing in play now.
func test_riftglass_and_unlocks_from_an_old_store_are_kept() -> void:
	var path: String = "user://test_release_store.json"
	var b := LocalBackend.new()
	b.rng.seed = 1
	b.switch_user("ann")
	var shop: Dictionary = {"band": 18, "rises_at": 0, "withdrawal_ok": false,
		"ledger": [{"amount": 500, "reason": "store", "ref": "purchase:1", "at": 1763600000},
			{"amount": -120, "reason": "spend", "ref": "offer:x", "at": 1763600100}],
		"purchases": [], "unlocks": {"ring_cap_plus": 1, "storage_wing": 2}, "deliveries": [], "subs": [],
		"cap": null, "raise_to": null, "raise_at": 0, "next_id": 3}
	b.db.users["ann"]["shop"] = shop
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(b.db))
	f.close()
	var again := LocalBackend.new(path)
	again.switch_user("ann")
	var st: Dictionary = (await again.call_fn("shop_state", {})).data
	assert_eq(int(st.balance), 380, "Riftglass balance kept")
	assert_eq(int(st.unlocks.ring_cap_plus), 1, "Ring Cap Seal owners keep the unlock")
	assert_eq(int(st.unlocks.storage_wing), 2)
	DirAccess.remove_absolute(path)

func test_a_new_optional_field_does_not_count_as_lost() -> void:
	var old: Dictionary = _old("1.3.1")
	var now: Dictionary = old.duplicate(true)
	now["daily_rewards"] = {"streak": 0}
	(now.party[0] as Dictionary)["future_field"] = 0
	assert_eq(lost(old, now), [] as Array[String])
	now.party.pop_back()
	now.erase("money")
	assert_eq(lost(old, now).size(), 2, "a dropped Spirling or value is caught")
