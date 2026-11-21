extends GutTest
## Plan area 8, items 3354 and 3462-3465: the Echo Path behind the mended Cinder Rift.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	EchoPath.force_week = "2031-01-06"
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	EchoPath.force_week = ""

func test_twelve_templates_of_five_kinds() -> void:
	var t: Array[Dictionary] = EchoPath.templates()
	assert_eq(t.size(), 12)
	var kinds: Dictionary = {}
	for room: Dictionary in t:
		assert_true(str(room.kind) in EchoPath.KINDS, str(room.kind))
		kinds[str(room.kind)] = true
		var rows: Array = room.rows
		assert_eq(rows.size(), EchoPath.HEIGHT)
		for r: Variant in rows:
			assert_eq(str(r).length(), EchoPath.WIDTH)
		for x: int in EchoPath.STAIRS_X:
			assert_eq(str(rows[0])[x], "=")
			assert_eq(str(rows[EchoPath.HEIGHT - 1])[x], "=")
		if str(room.kind) == "treasure":
			assert_true(Database.items.has(str(room.item)))
	assert_eq(kinds.size(), EchoPath.KINDS.size())

func test_weekly_order_is_fixed_and_has_every_kind() -> void:
	var seen_orders: Dictionary = {}
	for i: int in 10:
		var w: String = "week-%d" % i
		var o: Array[int] = EchoPath.order(w)
		assert_eq(o, EchoPath.order(w), "the same for everyone")
		assert_eq(o.size(), EchoPath.ROOMS)
		var uniq: Dictionary = {}
		var kinds: Dictionary = {}
		for idx: int in o:
			uniq[idx] = true
			kinds[str(EchoPath.templates()[idx].kind)] = true
		assert_eq(uniq.size(), EchoPath.ROOMS, "no room twice")
		assert_eq(kinds.size(), EchoPath.KINDS.size(), "one room of every kind")
		seen_orders[str(o)] = true
	assert_gt(seen_orders.size(), 5, "a new layout most weeks")

## Plan 3463: every layout passes the reachability check; across the weeks all 12 templates show up.
func test_every_layout_is_reachable() -> void:
	var used: Dictionary = {}
	var ids: PackedStringArray = [EchoPath.FILE]
	for s: int in range(1, EchoPath.ROOMS + 2):
		ids.append(MapData.floor_id(EchoPath.FILE, s))
	var weeks: int = 0
	while used.size() < 12 and weeks < 60:
		EchoPath.force_week = "layout-%d" % weeks
		weeks += 1
		for idx: int in EchoPath.order():
			used[idx] = true
		var errors: PackedStringArray = []
		WorldValidator.check_reachability(errors, ids, EchoPath.FILE, EchoPath.ARRIVE_UP)
		var real: PackedStringArray = []
		for e: String in errors:
			if not e.contains("cinder_rift"):
				real.append(e)
		assert_eq(real, PackedStringArray(), "week %s" % EchoPath.force_week)
		for id: String in ids:
			var m: MapData = MapData.load_map(id)
			for w: Dictionary in m.warps:
				if str(w.to).begins_with(EchoPath.FILE):
					assert_true(MapData.load_map(str(w.to)).is_walkable(Vector2i(int(w.tx), int(w.ty))), "%s -> %s" % [id, w.to])
	assert_eq(used.size(), 12, "every template is used in some week")

func test_entrance_opens_when_the_cinder_rift_is_mended() -> void:
	var m: MapData = MapData.load_map("cinder_rift")
	m.apply_blocks({})
	assert_false(m.is_walkable(Vector2i(7, 1)), "closed before the Rift is mended")
	m.apply_blocks({EchoPath.OPEN_FLAG: true})
	assert_true(m.is_walkable(Vector2i(7, 1)))
	assert_eq(str(m.warp_at(Vector2i(7, 1)).get("to", "")), EchoPath.FILE)

func test_chest_pays_forty_once_a_week_after_all_rooms() -> void:
	var before: int = GameState.waymarks
	EchoPath.open_chest()
	assert_eq(GameState.waymarks, before, "shut while rooms are left")
	for s: int in range(1, EchoPath.ROOMS + 1):
		assert_true(EchoPath.clear(s))
	assert_false(EchoPath.clear(1), "a room clears once a week")
	EchoPath.open_chest()
	assert_eq(GameState.waymarks, before + EchoPath.CHEST_WAYMARKS)
	EchoPath.open_chest()
	assert_eq(GameState.waymarks, before + EchoPath.CHEST_WAYMARKS, "only the first clear of the week")
	EchoPath.force_week = "2031-01-13"
	assert_eq(EchoPath.done_count(), 0, "a new week, a new path")
	EchoPath.force_week = "2031-01-06"
	assert_eq(EchoPath.done_count(), 0, "going back never brings an old week's chest back")

func test_room_kinds_give_their_content() -> void:
	for s: int in range(1, EchoPath.ROOMS + 1):
		match EchoPath.kind_of(s):
			"wild":
				var w: Spirling = EchoPath.wild_for(s)
				assert_not_null(w)
				assert_true(w.data.species_name in EchoPath.week_species())
			"echo":
				assert_eq(EchoPath.echo_team(s).size(), EchoPath.ECHO_TEAM)
			"treasure":
				var t: Dictionary = EchoPath.template_for(s)
				var had: int = GameState.item_count(str(t.item))
				assert_false(EchoPath.take_treasure(s).is_empty())
				assert_eq(GameState.item_count(str(t.item)), had + int(t.count))
				assert_true(EchoPath.take_treasure(s).is_empty(), "once a week")

func test_week_species_hint() -> void:
	var sp: Array[String] = EchoPath.week_species()
	assert_eq(sp.size(), EchoPath.WEEK_SPECIES)
	assert_eq(sp, EchoPath.week_species())
	for n: String in sp:
		assert_ne(Database.species(n).rarity, "ancient")
		assert_true(EchoPath.spirlog_hint().contains(n))
