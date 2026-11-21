extends GutTest
## Inkshadow: the lead Spirling trails one step behind, remarks by temperament, keeps a grudge.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_data_values() -> void:
	var d: Dictionary = Inkshadow.data()
	assert_gt(int(d.remark_every), 0)
	assert_gt(int(d.grudge_sour), 0)
	assert_gte(int(d.grudge_max), int(d.grudge_sour))
	for t: Dictionary in Spirling.TEMPERAMENTS:
		assert_false(GameState.as_dict(d.remarks).get(t.id, []).is_empty(), "remarks for " + str(t.id))
	assert_false((d.sour as Array).is_empty())

func test_trail_cell() -> void:
	assert_eq(Inkshadow.trail_cell(Vector2i(4, 5), Vector2i(5, 5), "right"), Vector2i(4, 5), "the cell just left")
	assert_eq(Inkshadow.trail_cell(Vector2i(0, 0), Vector2i(5, 5), "down"), Vector2i(5, 4), "behind after a warp")
	assert_eq(Inkshadow.trail_cell(Vector2i(5, 5), Vector2i(5, 5), "left"), Vector2i(6, 5))

func test_lead_is_first_standing() -> void:
	assert_eq(Inkshadow.lead(), GameState.party[0])
	GameState.party[0].hp = 0
	assert_null(Inkshadow.lead(), "nobody standing, nobody follows")

func test_grudge_grows_capped_and_soothes() -> void:
	var s: Spirling = GameState.party[0]
	var top: int = int(Inkshadow.data().grudge_max)
	s.hp = 0
	for i: int in top + 3:
		Inkshadow.note_battle(GameState.party)
	assert_eq(Inkshadow.grudge(s), top)
	assert_true(Inkshadow.is_sour(s))
	Inkshadow.soothe(s)
	assert_eq(Inkshadow.grudge(s), top - 1)

func test_standing_spirling_keeps_no_grudge() -> void:
	Inkshadow.note_battle(GameState.party)
	assert_eq(Inkshadow.grudge(GameState.party[0]), 0)

func test_remark_every_n_steps() -> void:
	var n: int = int(Inkshadow.data().remark_every)
	var r: RandomNumberGenerator = _rng(7)
	var said: int = 0
	for i: int in n * 3:
		if not Inkshadow.step(r).is_empty():
			said += 1
	assert_eq(said, 3)

func test_sour_remarks_come_from_sour_pool() -> void:
	var s: Spirling = GameState.party[0]
	GameState.records[Inkshadow.RECORD] = {s.uid: int(Inkshadow.data().grudge_sour)}
	var sour: Array[String] = []
	for line: Variant in Inkshadow.data().sour:
		sour.append(str(line) % s.display_name())
	for i: int in 20:
		var got: Dictionary = Inkshadow.remark(s, _rng(i))
		assert_has(sour, str(got.text))
		assert_false(got.has("money"), "a grudge finds no coins")

func test_kind_spirling_sometimes_finds_coins() -> void:
	var s: Spirling = GameState.party[0]
	var found: int = 0
	for i: int in 60:
		var got: Dictionary = Inkshadow.remark(s, _rng(i))
		if got.has("money"):
			assert_eq(int(got.money), int(Inkshadow.data().find_coins))
			found += 1
	assert_gt(found, 0)
	assert_lt(found, 60)

func test_german_for_every_line() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	var d: Dictionary = Inkshadow.data()
	var lines: Array = []
	for t: String in d.remarks:
		lines.append_array(d.remarks[t])
	lines.append_array(d.sour)
	lines.append_array(d.finds)
	for line: Variant in lines:
		assert_true(de.has(str(line)), "German missing: " + str(line))
