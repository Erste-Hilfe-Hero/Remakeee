extends GutTest
## The Wake: a daily funeral show scored by three mourners; the Heir takes bribes and may tell.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _mon(species: String) -> Spirling:
	return Spirling.new(Database.species(species), 10, _rng(1))

func test_data_has_three_mourners_and_rivals() -> void:
	var d: Dictionary = Wake.data()
	assert_eq((d.mourners as Array).size(), 3)
	assert_false((d.rivals as Array).is_empty())
	assert_gt(int(d.bribe_cost), 0)
	for m: Dictionary in d.mourners:
		for n: Variant in m.likes + m.hates:
			assert_true(String(n).to_upper() in Elements.E.keys(), "element " + str(n))

func test_shown_elements_merge_art_and_performer() -> void:
	var s: Spirling = _mon("Puddlet")
	assert_eq(Wake.shown_elements(s, Database.move("Cinder Nip")), ["Ember", "Tide"] as Array[String])
	assert_eq(Wake.shown_elements(s, Database.move("Undertow")), ["Tide"] as Array[String])

func test_hate_takes_points_never_below_zero() -> void:
	var undertaker: Dictionary = Wake.data().mourners[1]
	var base: int = int(Wake.data().base)
	assert_eq(Wake.mourner_score(undertaker, ["Ember"] as Array[String]), maxi(0, base - int(Wake.data().hate_malus)))
	assert_eq(Wake.mourner_score(undertaker, ["Stone"] as Array[String]), base + int(Wake.data().like_bonus))

func test_gloomy_art_scores_more_than_fire() -> void:
	var s: Spirling = _mon("Puddlet")
	var tide: int = Wake.perform(s, Database.move("Undertow"), false, _rng(3)).score
	var fire: int = Wake.perform(s, Database.move("Cinder Nip"), false, _rng(3)).score
	assert_gt(tide, fire)

func test_bribe_either_helps_or_betrays() -> void:
	var s: Spirling = _mon("Puddlet")
	var art: MoveData = Database.move("Undertow")
	var seen: Dictionary = {}
	for i: int in 40:
		var plain: int = Wake.perform(s, art, false, _rng(i)).score
		var r: Dictionary = Wake.perform(s, art, true, _rng(i))
		if r.betrayed:
			assert_eq(int(r.score), 0)
			assert_false(r.won)
			seen["betrayed"] = true
		else:
			seen["helped"] = true
	assert_eq(seen.size(), 2, "both outcomes happen over 40 wakes")

func test_once_a_day_and_wins_counted() -> void:
	assert_false(Wake.held_today("2026-11-11"))
	var money: int = GameState.money
	Wake.finish({"won": true, "prize": 600}, "2026-11-11")
	assert_true(Wake.held_today("2026-11-11"))
	assert_false(Wake.held_today("2026-11-12"))
	assert_eq(Wake.wins(), 1)
	assert_eq(GameState.money, money + 600)

func test_deceased_is_fixed_per_day() -> void:
	assert_eq(Wake.deceased("2026-11-11"), Wake.deceased("2026-11-11"))
	assert_ne(Wake.deceased("2026-11-11"), "")

func test_undertaker_stands_in_gravers_hall() -> void:
	var m: MapData = MapData.load_map("gravers_hall")
	var found: bool = false
	for n: Dictionary in m.npcs:
		if str(n.get("id", "")) == "undertaker":
			found = true
	assert_true(found)
	assert_eq(str(Dialogue.get_entry("gravers_hall/undertaker").get("action", "")), "wake")

func test_german_for_every_line() -> void:
	var de: Dictionary = Loc.load_table("de").strings
	var d: Dictionary = Wake.data()
	var lines: Array = d.deceased.duplicate()
	for m: Dictionary in d.mourners:
		lines.append_array([m.name, m.like_line, m.hate_line])
	for r: Dictionary in d.rivals:
		lines.append(r.name)
	for line: Variant in lines:
		assert_true(de.has(str(line)), "German missing: " + str(line))
