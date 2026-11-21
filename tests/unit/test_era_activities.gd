extends GutTest
## The later era functions: Kinship (Era II), the Showcase (Era III), the Dig site (Era IV) and
## wheel battles (Era V). data/era_activities.json, docs/ERA_FUNCTIONS.md.

func _mon(name: String = "Mossling", lvl: int = 20) -> Spirling:
	return Spirling.new(Database.species(name), lvl)

# --- Kinship ----------------------------------------------------------------------

func test_new_functions_open_in_their_era() -> void:
	for pair: Array in [["kinship", 2], ["showcase", 3], ["dig_site", 4], ["wheel_battles", 5]]:
		assert_eq(EraFeatures.era_of(str(pair[0])), int(pair[1]), str(pair[0]))
	assert_eq(EraFeatures.validate(), [] as Array[String])

func test_kinship_waits_for_era_two() -> void:
	var s: Spirling = _mon()
	Kinship.after_battle([s], [s], true, 1)
	assert_eq(s.kinship, 0, "no kinship in the story era")
	Kinship.after_battle([s], [s], true, 2)
	assert_eq(s.kinship, int(Kinship.data().win))

func test_kinship_win_faint_and_cap() -> void:
	var a: Spirling = _mon()
	var b: Spirling = _mon("Mossling", 21)
	a.kinship = 10
	b.kinship = 10
	b.hp = 0
	Kinship.after_battle([a, b], [a, b], true, 5)
	assert_eq(a.kinship, 10 + int(Kinship.data().win))
	assert_eq(b.kinship, 10 - int(Kinship.data().faint))
	a.kinship = Kinship.max_value()
	Kinship.add(a, 50)
	assert_eq(a.kinship, Kinship.max_value())
	b.kinship = 1
	Kinship.add(b, -50)
	assert_eq(b.kinship, 0)

func test_kinship_on_steps() -> void:
	var s: Spirling = _mon()
	var rec: Dictionary = {}
	var every: int = int(Kinship.data().steps)
	for i: int in every - 1:
		assert_false(Kinship.on_step([s], rec, 2))
	assert_true(Kinship.on_step([s], rec, 2))
	assert_eq(s.kinship, int(Kinship.data().step_gain))
	assert_false(Kinship.on_step([s], {}, 1), "not before Era II")

func test_kinship_lines_unfurl_through_kinship() -> void:
	for l: Dictionary in Kinship.data().lines:
		var s: Spirling = _mon(str(l.from), 5)
		var path: Dictionary = {}
		for p: Dictionary in s.data.unfold:
			if str(p.rule) == "kinship":
				path = p
		assert_false(path.is_empty(), "%s has a kinship path" % l.from)
		assert_eq(int(path.value), int(l.value))
		assert_eq(path.to, s.data.unfold[0].to, "same next form as its own rule")
		assert_false(s.unfold_ready(path, {}))
		s.kinship = int(l.value)
		assert_true(s.unfold_ready(path, {}))
		assert_string_contains(s.unfold_hint(path), "Kinship")

func test_kinship_survives_save() -> void:
	var s: Spirling = _mon()
	s.kinship = 42
	assert_eq(Spirling.from_dict(s.to_dict()).kinship, 42)

# --- Showcase ---------------------------------------------------------------------

func test_showcase_appeal_and_repeat() -> void:
	var s: Spirling = _mon()
	var theme: String = Showcase.theme_for("2026-11-12")
	assert_true((Showcase.data().themes as Dictionary).has(theme))
	assert_eq(Showcase.theme_for("2026-11-12"), theme, "same theme all day")
	var mv: MoveData = s.moves[0]
	var once: int = Showcase.appeal(s, theme, mv)
	assert_gt(once, 0)
	assert_lt(Showcase.appeal(s, theme, mv, mv), once, "the same art twice counts less")
	s.kinship = 100
	assert_gt(Showcase.appeal(s, theme, mv), once, "kinship adds appeal")

func test_showcase_best_show_wins_and_places() -> void:
	var s: Spirling = _mon()
	var theme: String = "grace"
	var rivals: Array[int] = Showcase.rivals(s, theme)
	assert_eq(rivals.size(), 3)
	assert_eq(Showcase.place(Showcase.best_total(s, theme), rivals), 1, "a perfect show wins")
	assert_eq(Showcase.place(0, rivals), 4)
	assert_gt(Showcase.prize(1), Showcase.prize(2))
	assert_eq(Showcase.prize(4), 0)
	var rec: Dictionary = {}
	assert_true(Showcase.note(rec, 3))
	assert_false(Showcase.note(rec, 4))
	assert_true(Showcase.note(rec, 1))

# --- Dig site ---------------------------------------------------------------------

func test_dig_field_is_daily_and_fixed() -> void:
	var f: Dictionary = DigSite.field("2026-11-12")
	assert_eq(f, DigSite.field("2026-11-12"))
	assert_eq((f.finds as Dictionary).size(), int(DigSite.data().finds))
	assert_eq((f.rocks as Array).size(), int(DigSite.data().rocks))
	for c: Variant in f.rocks:
		assert_false((f.finds as Dictionary).has(c), "a rock is never a find")
	assert_ne(DigSite.field("2026-11-13"), f)

func test_dig_swings_cost_picks() -> void:
	var day: String = "2026-11-12"
	var f: Dictionary = DigSite.field(day)
	var dig: Dictionary = DigSite.start(day)
	var picks: int = int(dig.picks)
	var find_cell: int = int((f.finds as Dictionary).keys()[0])
	var r: Dictionary = DigSite.swing(dig, find_cell)
	assert_eq(str(r.item), str(f.finds[find_cell]))
	assert_eq(int(dig.picks), picks - 1)
	assert_false(bool(DigSite.swing(dig, find_cell).ok), "a dug cell stays dug")
	r = DigSite.swing(dig, int(f.rocks[0]))
	assert_true(bool(r.rock))
	assert_eq(int(dig.picks), picks - 1 - int(DigSite.data().rock_cost))
	assert_string_contains(DigSite.grid_text(dig), "*")
	assert_string_contains(DigSite.grid_text(dig), "o")
	assert_eq(DigSite.cell_name(0), "A1")

func test_dig_once_a_day() -> void:
	var rec: Dictionary = {}
	assert_true(DigSite.open_today(rec, "2026-11-12"))
	DigSite.mark_done(rec, "2026-11-12")
	assert_false(DigSite.open_today(rec, "2026-11-12"))
	assert_true(DigSite.open_today(rec, "2026-11-13"))

func test_dig_loot_exists() -> void:
	for id: Variant in DigSite.data().loot:
		assert_false(Database.item(str(id)).is_empty(), str(id))

# --- Wheel battles ----------------------------------------------------------------

func _wheel_model(on: bool) -> BattleModel:
	var mine: Array[Spirling] = [_mon("Mossling", 30), _mon("Mossling", 31), _mon("Mossling", 32), _mon("Mossling", 33)]
	var foes: Array[Spirling] = [_mon("Mossling", 30), _mon("Mossling", 31)]
	var m := BattleModel.new(mine, foes, false, 9)
	m.wheel = on
	m.start()
	return m

func test_wheel_turns_the_front_each_turn() -> void:
	var m: BattleModel = _wheel_model(true)
	assert_eq(m.active_index(0), 0)
	m.turn = 1
	m._turn_wheel()
	assert_eq(m.active_index(0), 1)
	assert_eq(m.active_index(1), 1)
	m._turn_wheel()
	assert_eq(m.active_index(0), 2)
	assert_eq(m.active_index(1), 0, "a team of two turns back")
	m._turn_wheel()
	assert_eq(m.active_index(0), 0, "only the first three turn")

func test_wheel_skips_the_fallen_and_is_off_by_default() -> void:
	var m: BattleModel = _wheel_model(true)
	m.parties[0][1].hp = 0
	assert_eq(m.wheel_next(0), 2)
	var plain: BattleModel = _wheel_model(false)
	plain._turn_wheel()
	assert_eq(plain.active_index(0), 0)
	assert_eq(plain.wheel_next(0), -1)

func test_wheel_is_kept_in_replays() -> void:
	var m: BattleModel = _wheel_model(true)
	var snap: Dictionary = BattleReplay.snapshot(m, "", "")
	assert_eq(int(snap.wheel), 3)
	assert_false(BattleReplay.snapshot(_wheel_model(false), "", "").has("wheel"), "plain replays stay the same")

# --- World and text ---------------------------------------------------------------

func _npc_with(map_id: String, key: String) -> Array:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	return (m.npcs as Array).filter(func(n: Dictionary) -> bool: return n.has(key) or str(n.get("id", "")) == key)

func test_hosts_stand_in_their_era_region() -> void:
	assert_eq(_npc_with("ledgerholm", "showcase_host").size(), 1)
	assert_eq(EraManager.region_era("quillmarch"), 3)
	assert_string_contains(FileAccess.get_file_as_string("res://data/dialogue/quillmarch.json"), "\"action\": \"showcase\"")
	assert_eq(_npc_with("paleshore", "digger").size(), 1)
	assert_string_contains(FileAccess.get_file_as_string("res://data/dialogue/paleshore.json"), "\"action\": \"dig\"")
	for rift: String in ["wick_rift", "taproot_rift", "raft_rift", "bloom_rift"]:
		var w: Array = _npc_with(rift, "wheel")
		assert_eq(w.size(), 1, rift)
		assert_eq((w[0].team as Array).size(), 3, rift + " turns a wheel of three")

func test_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for k: String in ["Kinship: %d/%d", "Needs: Kinship %d (now %d)", "The wheel turns! The next Spirlings step up.",
			"Today's theme: %s. Who goes on stage?", "Round %d of %d: which art?", "%s shows %s. Appeal %d.",
			"Picks left: %d", "You dig up %s!", "The dig is over. Found: %s", "Look at the field"]:
		assert_true(de.has(k), k)
	for t: Dictionary in (Showcase.data().themes as Dictionary).values():
		assert_true(de.has(str(t.label)), str(t.label))
