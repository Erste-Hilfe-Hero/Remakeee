extends GutTest
## 1.3.2 perf pass (mid phones): the five hot spots found with tools/perf_probe.gd stay fixed.
## Each fix keeps its old result; the budgets are for the reference phone (cpu_factor in
## data/battle_budget.json) and well above the fixed code, well below the old one.
## 1. SpirlogBook.entry upgraded every saved entry on every read (about 40 us each).
## 2. MapData parsed a whole map file for one name or the list of ids (about 0.8 ms a file).
## 3. Collection.unclaimed walked every kind once per goal (the pause menu and the title).
## 4. ListPicker gave every row five style copies, set while the row was in the tree.
## 5. MapSurround worked out each ring cell's kind once per neighbour.

## Reference-phone budgets in ms (measured fixed / old on a CI-sized box x cpu_factor).
const SPIRLOG_DATA_MS: int = 800
const PLACE_NAMES_MS: int = 160
const PENDING_MS: int = 1200
const SURROUND_MS: int = 400

var _saved: Dictionary
var _cpu: float = 8.0

func before_all() -> void:
	Database.load_all()
	var b: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_budget.json"))
	_cpu = float(b.cpu_factor)

func before_each() -> void:
	_saved = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_saved)

func _phone_ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0 * _cpu

## Every region open, every kind seen and every third bonded: the longest Spirlog.
func _full_spirlog() -> void:
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	for r: String in SpirlingData.REGIONS:
		GameState.set_flag("region_open_" + r)
	var i: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		GameState.current_map = "saltmarsh" if i % 2 == 0 else "brindlewick"
		GameState.mark_seen(sd.species_name, i % 3 == 0)
		i += 1

# --- 1. Spirlog entries -----------------------------------------------------------------------

func test_spirlog_entry_is_kept_until_the_saved_entry_changes() -> void:
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.mark_seen("Mossling")
	var a: Dictionary = SpirlogBook.entry(GameState.spirlog, "Mossling")
	assert_eq(a, GameState.upgrade_spirlog_entry(GameState.spirlog.get("Mossling")))
	assert_true(is_same(a, SpirlogBook.entry(GameState.spirlog, "Mossling")), "unchanged entry is not upgraded again")
	assert_false(bool(a.bonded))
	GameState.mark_seen("Mossling", true)
	assert_true(bool(SpirlogBook.entry(GameState.spirlog, "Mossling").bonded), "a change shows at once")
	# Another log (a test, a friend's save) gets its own entry, not the kept one.
	assert_false(SpirlogBook.is_seen({}, "Mossling"))
	assert_true(SpirlogBook.is_bonded({"Mossling": {"bonded": true}}, "Mossling"))
	assert_true(SpirlogBook.is_bonded(GameState.spirlog, "Mossling"))

func test_spirlog_page_data_fits_the_old_phone() -> void:
	_full_spirlog()
	var log: Dictionary = GameState.spirlog
	var t0: int = Time.get_ticks_usec()
	var kinds: Array[SpirlingData] = SpirlogBook.filtered(log, GameState.flags)
	for r: String in SpirlogBook.open_regions(GameState.flags):
		SpirlogBook.chapter_line(r, log)
	SpirlogBook.gleam_line(log)
	for sd: SpirlingData in kinds:
		SpirlogBook.is_bonded(log, sd.species_name)
		SpirlogBook.list_line(sd, log)
		SpirlogBook.event_of(log, sd.species_name)
		SpirlogBook.found_line(sd, log)
	var ms: float = _phone_ms(t0)
	gut.p("Spirlog page data for %d kinds: about %.0f ms on the reference phone (budget %d)" % [kinds.size(), ms, SPIRLOG_DATA_MS])
	assert_eq(kinds.size(), Database.spirlings.size())
	assert_lt(ms, float(SPIRLOG_DATA_MS))

# --- 2. Map files -----------------------------------------------------------------------------

func test_map_ids_and_names_match_the_files() -> void:
	var want: PackedStringArray = []
	var files: PackedStringArray = DirAccess.get_files_at(MapData.DIR)
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		want.append(f.get_basename())
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + f))
		for i: int in ((raw as Dictionary).get("floors", []) as Array).size() if raw is Dictionary else 0:
			want.append(MapData.floor_id(f.get_basename(), i + 1))
	assert_eq(MapData.all_ids(), want)
	for id: String in want:
		assert_true(MapData.exists(id), id)
		assert_eq(MapData.name_of(id), MapData.load_map(id).display_name, id)
	assert_false(MapData.exists("no_such_map"))
	assert_false(MapData.exists("brindlewick@99"))
	assert_eq(Spirling.place_name("no_such_map"), "No Such Map")

func test_place_names_do_not_read_the_file_each_time() -> void:
	Spirling.place_name("ledgerholm")
	var t0: int = Time.get_ticks_usec()
	for i: int in 200:
		Spirling.place_name("ledgerholm")
		MapData.all_ids()
	var ms: float = _phone_ms(t0)
	gut.p("200 place names and id lists: about %.0f ms on the reference phone (budget %d)" % [ms, PLACE_NAMES_MS])
	assert_lt(ms, float(PLACE_NAMES_MS))

# --- 3. Rewards waiting -----------------------------------------------------------------------

## The count as Collection.unclaimed worked it out before the perf pass.
func _unclaimed_reference() -> int:
	var claimed: Dictionary = GameState.records.get("collection", {}) if GameState.records.get("collection") is Dictionary else {}
	var total: int = SpirlogBook.visible_kinds(GameState.flags).size()
	var n: int = 0
	for g: Dictionary in Collection.GOALS:
		if not claimed.has(g.id) and Collection.goal_have(g, GameState.spirlog) >= Collection.needed(g, total):
			n += 1
	var seen: int = Collection.seen_kinds(GameState.spirlog)
	for g: Dictionary in Collection.SEEN_GOALS:
		if not claimed.has(g.id) and seen >= (total if int(g.seen) < 0 else int(g.seen)):
			n += 1
	for g: Dictionary in Collection.SET_GOALS:
		if not claimed.has(g.id) and Collection.set_count(str(g.kind)) >= Collection.set_need(g):
			n += 1
	return n

func test_rewards_waiting_count_is_unchanged() -> void:
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	assert_eq(Collection.unclaimed(), _unclaimed_reference(), "new game")
	_full_spirlog()
	var full: int = Collection.unclaimed()
	assert_eq(full, _unclaimed_reference(), "every kind seen")
	assert_gt(full, 0)
	GameState.records["collection"] = {"kinds_3": true, "veydal_10": true, "seen_5": true}
	assert_eq(Collection.unclaimed(), _unclaimed_reference(), "some claimed")

func test_pause_menu_dot_count_fits_the_old_phone() -> void:
	_full_spirlog()
	Goals.pending()
	var t0: int = Time.get_ticks_usec()
	Goals.pending()
	var ms: float = _phone_ms(t0)
	gut.p("Goals.pending with every kind seen: about %.0f ms on the reference phone (budget %d)" % [ms, PENDING_MS])
	assert_lt(ms, float(PENDING_MS))

# --- 4. List rows -----------------------------------------------------------------------------

func test_list_rows_share_one_padded_style_set() -> void:
	var lp := ListPicker.new()
	add_child_autofree(lp)
	var entries: Array[Dictionary] = []
	for i: int in 40:
		entries.append({"text": "Row %d" % i})
	var run := func() -> void: await lp.pick("T", entries)
	run.call()
	await get_tree().process_frame
	var rows: Array[Button] = lp.buttons()
	assert_eq(rows.size(), 41, "rows and Back")
	var distinct: Dictionary = {}
	for b: Button in rows:
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			assert_true(b.has_theme_stylebox_override(state), state)
			distinct[b.get_theme_stylebox(state)] = true
	assert_eq(distinct.size(), 5, "one style per state for the whole list")
	var sb: StyleBox = rows[0].get_theme_stylebox("normal")
	var theme_sb: StyleBox = lp._box.get_theme_stylebox("normal", "Button")
	assert_eq(int(sb.content_margin_left), ListPicker.POINTER_SPACE)
	assert_eq(sb.content_margin_right, theme_sb.content_margin_right)
	assert_eq(sb.content_margin_top, theme_sb.content_margin_top)
	assert_eq(sb.get_class(), theme_sb.get_class())
	lp.refresh_theme()
	assert_eq(int(rows[3].get_theme_stylebox("focus").content_margin_left), ListPicker.POINTER_SPACE)

# --- 5. Land around the map -------------------------------------------------------------------

func test_surround_is_unchanged_and_quick() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(270, 480)
	add_child_autofree(vp)
	var s := MapSurround.new()
	vp.add_child(s)
	var m: MapData = MapData.load_map("brindlewick")
	var t0: int = Time.get_ticks_usec()
	s.show_map(m)
	var ms: float = _phone_ms(t0)
	gut.p("land around a map at 270x480: about %.0f ms on the reference phone (budget %d)" % [ms, SURROUND_MS])
	assert_gt(s.ring, 0)
	var outside := func(c: Vector2i) -> int: return MapSurround.kind_outside(m, c)
	var cells: Array[Vector2i] = s.get_used_cells()
	assert_gt(cells.size(), 1000)
	for c: Vector2i in cells:
		assert_false(m.in_bounds(c))
		if s.get_cell_atlas_coords(c) != TilesetFactory.atlas_coords(MapSurround.kind_outside(m, c), c, outside):
			fail_test("cell %s" % c)
			return
	assert_lt(ms, float(SURROUND_MS))
