extends GutTest
## Bug sweep 12 Nov 2026: people who stand on a map for good must not wall off a way out.
## WorldValidator.check_reachability floods from every entry at once, so a map cut in two by
## townsfolk passed as long as each half had its own door (Stillwater: the Mirror Rift road,
## Cinderfold: the door of Gravers' Hall).

## People who never leave their cell: no "hide_flag" (gate keepers step aside), no "leaves".
## People with a day plan are left out by WorldValidator.reachable_cells itself.
func _stays(def: Dictionary) -> bool:
	return not def.has("hide_flag") and not bool(def.get("leaves", false))

func _near(reach: Dictionary, c: Vector2i) -> bool:
	if reach.has(c):
		return true
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if reach.has(c + d):
			return true
	return false

## Cells reached from the first warp of [param m]; a warp back onto the same map (a culvert)
## carries on from its far end.
func _reach_from_first_warp(m: MapData) -> Dictionary:
	var starts: Array = [Vector2i(int(m.warps[0].x), int(m.warps[0].y))]
	var reach: Dictionary = {}
	var grew: bool = true
	while grew:
		grew = false
		reach = WorldValidator.reachable_cells(m, starts)
		for w: Dictionary in m.warps:
			var far := Vector2i(int(w.tx), int(w.ty))
			if str(w.to) == m.id and not far in starts and _near(reach, Vector2i(int(w.x), int(w.y))):
				starts.append(far)
				grew = true
	return reach

func _cut_warps(id: String) -> Array[String]:
	var out: Array[String] = []
	var m: MapData = MapData.load_map(id)
	if m == null or m.warps.size() < 2:
		return out
	m.npcs.assign(m.npcs.filter(_stays))
	var reach: Dictionary = _reach_from_first_warp(m)
	for w: Dictionary in m.warps:
		if not _near(reach, Vector2i(int(w.x), int(w.y))):
			out.append("%s: the way to '%s' at %s,%s is walled off from the way to '%s'" % [id, w.to, w.x, w.y, m.warps[0].to])
	return out

func test_people_who_stay_wall_off_no_way_out() -> void:
	var cut: Array[String] = []
	for id: String in MapData.all_ids():
		cut.append_array(_cut_warps(id))
	assert_eq("\n".join(cut), "")

func test_stillwater_road_to_the_mirror_rift_is_open() -> void:
	assert_eq(_cut_warps("stillwater"), [] as Array[String])

func test_cinderfold_door_of_gravers_hall_is_open() -> void:
	assert_eq(_cut_warps("cinderfold"), [] as Array[String])

func test_two_people_who_stay_never_share_a_cell() -> void:
	var clash: Array[String] = []
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		var at: Dictionary = {}
		for n: Dictionary in m.npcs:
			if WorldValidator._unplaced(n) or not n.has("x") or not _stays(n):
				continue
			var c := Vector2i(int(n.x), int(n.y))
			if at.has(c):
				clash.append("%s: '%s' and '%s' both stand on %s" % [id, at[c], n.get("id", ""), c])
			at[c] = str(n.get("id", ""))
	assert_eq("\n".join(clash), "")

## Flags a win over [param def] sets (TrainerData: "win_flags", and a Warden seals its Rift).
func _win_flags(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in def.get("win_flags", []):
		out.append(str(f))
	if def.has("warden"):
		out.append("rift_%s_sealed" % def.warden)
	return out

## Cells reached from the doors of [param m] while the blocks in [param shut] stay closed.
func _reach_with_closed(m: MapData, shut: Array[String], skip: Dictionary) -> Dictionary:
	var open: Dictionary = {}
	for b: Dictionary in m.blocks:
		if not str(b.get("open_flag", "")) in shut:
			open[str(b.get("open_flag", ""))] = true
	m.apply_blocks(open)
	var people: Dictionary = {}
	for n: Dictionary in m.npcs:
		if n != skip and n.has("x") and not WorldValidator._unplaced(n) and _stays(n):
			people[Vector2i(int(n.x), int(n.y))] = true
	var reach: Dictionary = {}
	var queue: Array[Vector2i] = []
	for w: Dictionary in m.warps:
		reach[Vector2i(int(w.x), int(w.y))] = true
		queue.append(Vector2i(int(w.x), int(w.y)))
	var me := Vector2i(int(skip.x), int(skip.y))
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not reach.has(n) and n != me and m.is_walkable(n) and not people.has(n):
				reach[n] = true
				queue.append(n)
	return reach

## Quivermoor's four Rifts (12 Nov 2026): bog water lay across the only gap of the hall, and
## the validator still reached the Warden through the way out, which opens only after the win.
func test_whoever_opens_a_block_is_reached_while_it_is_shut() -> void:
	var stuck: Array[String] = []
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m == null or m.blocks.is_empty() or m.warps.is_empty():
			continue
		for n: Dictionary in m.npcs:
			var mine: Array[String] = []
			for b: Dictionary in m.blocks:
				if str(b.get("open_flag", "")) in _win_flags(n) and not str(b.open_flag) in mine:
					mine.append(str(b.open_flag))
			if mine.is_empty() or not n.has("x"):
				continue
			if not _near(_reach_with_closed(m, mine, n), Vector2i(int(n.x), int(n.y))):
				stuck.append("%s: '%s' opens %s but stands behind it" % [id, n.get("id", ""), mine])
	assert_eq("\n".join(stuck), "")

## Madderby (12 Nov 2026): Morrow stood on the cell the Woadfen road arrives on. A gate keeper
## who only ever leaves ("hide_flag" without "show_flag", met before the way behind opens) may.
func test_nobody_stands_where_a_way_arrives() -> void:
	var ids: PackedStringArray = MapData.all_ids()
	var entries: Dictionary = WorldValidator.entry_cells(ids)
	var taken: Array[String] = []
	for id: String in ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		for n: Dictionary in m.npcs:
			if WorldValidator._unplaced(n) or not n.has("x") or (n.has("hide_flag") and not n.has("show_flag")):
				continue
			if Vector2i(int(n.x), int(n.y)) in entries.get(id, []):
				taken.append("%s: '%s' stands on arrival cell %s,%s" % [id, n.get("id", ""), n.x, n.y])
	assert_eq("\n".join(taken), "")
