extends GutTest
## KAMPF_PLAN_1000 items 976 (battle tables in JSON), 991 (data packs, no code), 992 (signed packs)
## and 993 (developer battle editor).

const BattleSetup := preload("res://tools/battle_editor/BattleSetup.gd")
const PACK_DIR: String = "res://tests/fixtures/battle_packs"
const PACK: String = PACK_DIR + "/cinder_pit.kpack.json"

var keys: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	keys = {"test-fixture": FileAccess.get_file_as_string(PACK_DIR + "/test_key.pub.pem")}

func after_each() -> void:
	BattleRules.reload_tables()

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

# --- 976 ---

func test_tables_come_from_json_in_order() -> void:
	var raw: Dictionary = _json(BattleRules.TABLES_PATH)
	assert_eq(BattleRules.FIELDS.keys(), raw.fields.keys(), "field order stays as in the file (seeded field pick)")
	assert_eq(BattleRules.RULES.keys(), raw.rules.keys())
	assert_eq(BattleRules.BOSSES.keys(), raw.bosses.keys())
	assert_eq(BattleRules.TRAITS.keys(), raw.traits.keys())
	assert_eq(BattleRules.REACTIONS.size(), (raw.reactions as Array).size())
	assert_eq(str(BattleRules.FIELDS.high_tide.intro), str(raw.fields.high_tide.intro))

func test_whole_numbers_stay_int_and_fractions_float() -> void:
	assert_eq(typeof(BattleRules.FIELDS.pollen_drift.regen_div), TYPE_INT)
	assert_eq(typeof(BattleRules.RULES.ember_pulse.difficulty[0]), TYPE_INT)
	assert_true(1 in BattleRules.RULES.ember_pulse.difficulty)
	assert_eq(typeof(BattleRules.BOSSES.ashen_heart.hp_per_ally), TYPE_FLOAT)
	assert_eq(typeof(BattleRules.BOSSES.ashen_heart.phase.stage.atk), TYPE_INT)

func test_code_holds_no_table_literals() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/BattleRules.gd")
	for name: String in ["TRAITS", "FIELDS", "REACTIONS", "RULES", "BOSSES"]:
		assert_false(src.contains("const %s:" % name), "%s lives in data/battle_tables.json" % name)
	assert_eq(KampfChecks.field_errors(), PackedStringArray())
	assert_eq(KampfChecks.boss_errors(), PackedStringArray())

# --- 991, 992 ---

func test_signed_pack_adds_a_field_and_a_boss() -> void:
	var r: Dictionary = BattlePacks.read(PACK, keys)
	assert_eq(r.errors, PackedStringArray())
	assert_eq(r.key, "test-fixture")
	assert_false(BattleRules.FIELDS.has("cinder_pit"))
	BattlePacks.apply(r.pack)
	assert_true(BattleRules.FIELDS.has("cinder_pit"))
	assert_true(BattleRules.BOSSES.has("cinder_heart"))
	var m: BattleModel = BattleSetup.build({"player": [["Kindlop", 14]], "foe": [["Mossling", 14]], "seed": 3})
	m.start()
	assert_true(m.set_field("cinder_pit"))
	assert_true(BattleRules.field_blocks("cinder_pit", "soak"))
	BattleRules.reload_tables()
	assert_false(BattleRules.FIELDS.has("cinder_pit"), "reload drops what packs added")

func test_untrusted_or_changed_pack_is_refused() -> void:
	assert_false((BattlePacks.read(PACK).errors as PackedStringArray).is_empty(), "the shipped key list does not trust the test key")
	assert_false((BattlePacks.read(PACK, {"other": keys["test-fixture"]}).errors as PackedStringArray).is_empty())
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PACK)
	var sig: String = FileAccess.get_file_as_string(PACK + ".sig")
	assert_true(BattlePacks.signed_by(bytes, str(JSON.parse_string(sig).sig), keys["test-fixture"]))
	var changed: PackedByteArray = bytes.duplicate()
	changed[changed.size() / 2] = changed[changed.size() / 2] ^ 1
	assert_false(BattlePacks.signed_by(changed, str(JSON.parse_string(sig).sig), keys["test-fixture"]), "one flipped bit breaks the signature")
	var tmp: String = "user://k40_pack.kpack.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_buffer(changed)
	f.close()
	f = FileAccess.open(tmp + ".sig", FileAccess.WRITE)
	f.store_string(sig)
	f.close()
	var r: Dictionary = BattlePacks.read(tmp, keys)
	assert_true((r.pack as Dictionary).is_empty())
	assert_string_contains(str(r.errors), "signature")
	DirAccess.remove_absolute(tmp + ".sig")
	assert_string_contains(str(BattlePacks.read(tmp, keys).errors), "no signature")
	DirAccess.remove_absolute(tmp)

func test_pack_is_data_only_and_only_adds() -> void:
	var good: Dictionary = BattleRules._whole(_json(PACK))
	assert_eq(BattlePacks.errors(good), PackedStringArray())
	var code: Dictionary = good.duplicate(true)
	code["script"] = "res://mods/evil.gd"
	assert_gt(BattlePacks.errors(code).size(), 1, "unknown key and a path")
	var path: Dictionary = good.duplicate(true)
	path.fields.cinder_pit.intro = "user://x"
	assert_string_contains(str(BattlePacks.errors(path)), "no paths")
	var change: Dictionary = good.duplicate(true)
	change.fields["high_tide"] = change.fields.cinder_pit
	assert_string_contains(str(BattlePacks.errors(change)), "only adds")
	var broken: Dictionary = good.duplicate(true)
	broken.fields.cinder_pit.boost = "NOT_AN_ELEMENT"
	broken.bosses.cinder_heart.phase.field = "nowhere"
	var errs: String = str(BattlePacks.errors(broken))
	assert_string_contains(errs, "not an element")
	assert_string_contains(errs, "does not exist")

func test_load_dir_applies_signed_packs() -> void:
	assert_eq(BattlePacks.load_dir(PACK_DIR, keys), PackedStringArray())
	assert_true(BattleRules.FIELDS.has("cinder_pit"))
	BattleRules.reload_tables()
	assert_eq(BattlePacks.load_dir(PACK_DIR).size(), 1, "no trusted key, the pack stays out")
	assert_false(BattleRules.FIELDS.has("cinder_pit"))

# --- 993 ---

func test_setup_parses_and_checks() -> void:
	assert_eq(BattleSetup.parse_team("Kindlop 12, Mossling", 9), [["Kindlop", 12], ["Mossling", 9]])
	assert_eq(BattleSetup.team_text([["Kindlop", 12]]), "Kindlop 12")
	var errs: String = str(BattleSetup.errors({"player": [["Nobody", 5]], "foe": [], "field": "nowhere", "rule": "x", "boss": "y", "front": [9, 1]}))
	for part: String in ["unknown species", "foe: 1 to", "unknown field", "unknown rule", "unknown boss", "front sizes"]:
		assert_string_contains(errs, part)

func test_setup_plays_the_same_battle_for_the_same_seed() -> void:
	var s: Dictionary = {"player": [["Kindlop", 14], ["Zippit", 14]], "foe": [["Mossling", 14], ["Wickit", 14]],
		"field": "high_tide", "rule": "ember_pulse", "seed": 11, "ai": 2, "front": [2, 2]}
	var a: Dictionary = BattleSetup.play(s)
	var b: Dictionary = BattleSetup.play(s)
	assert_eq(a.errors, PackedStringArray())
	assert_true(a.outcome in ["WIN", "LOSS", "NONE"])
	assert_gt(int(a.turns), 0)
	assert_eq(a.log, b.log)

func test_editor_runs_a_pack_battle() -> void:
	var ed: Control = load("res://tools/battle_editor/battle_editor.tscn").instantiate()
	add_child_autofree(ed)
	ed.pack_path.text = PACK_DIR
	assert_eq(ed.load_packs(keys), PackedStringArray())
	assert_eq(ed.pack_battles.size(), 1)
	ed.pack_pick.select(1)
	ed._pack_battle(1)
	assert_eq(ed.setup().field, "cinder_pit")
	assert_eq(ed.setup().player, [["Kindlop", 14], ["Zippit", 14]])
	var r: Dictionary = ed.run()
	assert_eq(r.errors, PackedStringArray())
	assert_string_contains(ed.output.text, "turns")
	assert_string_contains(ed.output.text, "Coals glow")
	ed.name_edit.text = "k40 test"
	var path: String = ed.save_setup()
	assert_eq(_json(path).field, "cinder_pit")
	DirAccess.remove_absolute(path)
