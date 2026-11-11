extends GutTest
## The Burrow: a claimable hollow in Murk Hollow with a wall of earned trophies and a squatter.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_claim() -> void:
	assert_false(Burrow.claimed())
	Burrow.claim()
	assert_true(Burrow.claimed())

func test_trophies_earned_by_flag_and_record() -> void:
	assert_true(Burrow.earned_ids().is_empty(), "a new game has nothing to hang")
	GameState.set_flag("rift_cinder_sealed")
	assert_eq(Burrow.earned_ids(), ["cinder_seal"] as Array[String])
	GameState.records["wake_wins"] = 1
	GameState.records["inkshadow_grudge"] = {"abc": 2}
	assert_true("black_veil" in Burrow.earned_ids())
	assert_true("grudge_jar" in Burrow.earned_ids(), "a table record counts by its size")

func test_hang_rules() -> void:
	assert_false(Burrow.hang("cinder_seal"), "not earned yet")
	for f: String in ["rift_cinder_sealed", "rift_tide_sealed", "rift_mist_sealed", "veydal_rifts_mended"]:
		GameState.set_flag(f)
	assert_true(Burrow.hang("cinder_seal"))
	assert_false(Burrow.hang("cinder_seal"), "already up")
	assert_true(Burrow.hang("tide_seal"))
	assert_true(Burrow.hang("mist_seal"))
	assert_eq(Burrow.wall().size(), int(Burrow.data().wall_slots))
	assert_false(Burrow.hang("veydal_map"), "wall full")
	Burrow.take_down("tide_seal")
	assert_true(Burrow.hang("veydal_map"))

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	return r

func test_squatter_leaves_rent_and_takes_nothing() -> void:
	GameState.set_flag("rift_cinder_sealed")
	GameState.set_flag("rift_tide_sealed")
	Burrow.hang("cinder_seal")
	Burrow.hang("tide_seal")
	assert_true(Burrow.visit("2026-11-01", _rng()).is_empty(), "first visit")
	assert_true(Burrow.visit("2026-11-03", _rng()).is_empty(), "short absence")
	var days: int = int(Burrow.data().squatter_days)
	var later: String = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-11-03") + days * 86400)
	var money: int = GameState.money
	var got: Dictionary = Burrow.visit(later, _rng())
	assert_gt(int(Burrow.data().rent_coins), 0)
	assert_eq(int(got.coins), int(Burrow.data().rent_coins))
	assert_eq(GameState.money, money + int(Burrow.data().rent_coins), "rent is a gift")
	assert_ne(str(got.note), "")
	assert_eq(Burrow.wall(), ["cinder_seal", "tide_seal"] as Array[String], "trophies are never lost")

func test_hollow_is_on_the_map() -> void:
	var m: MapData = MapData.load_map("murk_hollow")
	assert_eq(str(m.sign_at(Vector2i(0, 9)).get("dialogue", "")), "murk_hollow/burrow")
	assert_eq(str(Dialogue.get_entry("murk_hollow/burrow").get("action", "")), "burrow")

func test_german_for_every_trophy() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	assert_true(de.has(str(Burrow.data().rent_line)))
	for line: Variant in Burrow.data().squatter_notes:
		assert_true(de.has(str(line)), "German missing: " + str(line))
	for t: Dictionary in Burrow.data().trophies:
		assert_true(de.has(str(t.name)), "German missing: " + str(t.name))
		assert_true(de.has(str(t.text)), "German missing: " + str(t.text))
