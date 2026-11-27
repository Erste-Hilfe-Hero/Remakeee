class_name WorldGraph
extends RefCounted
## The whole world as one travel graph (map pass 1.3.2). A node is a walkable patch of one map
## (map id + the patch's number); edges are every way the player changes map: warps, cracked
## floor, ladders, Wayfarer Gear jumps, boat/coach/rail lines and story warps from dialogue and
## scenes (ferry, Echo Path chest, the Undrawn gate). Checks (problems(), all as text):
##   land     every way into a map lands inside the map on floor, not on a person or a block
##   start    every map and floor can be reached from the new-game start (all gates open)
##   trap     every patch the player can stand on still has a way on foot (and by boat or warp)
##            to a rest spring when every person that may stand around is there, time-of-day
##            blocks are shut and story lines/warps behind flags are not running yet
##   region   the story regions open in story order: a region cannot be entered before its
##            gate flag, and it can be entered once its gate and the gates before it are set
##   rest     each rest point (defeat return, fast travel) and the start cell is free floor
## Gear counts as owned and puzzle blocks as solved (Gear and puzzles have their own checks).

const START_MAP: String = "lighthouse"
const START_CELL: Vector2i = Vector2i(4, 4)
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Story regions in the order the story opens them, with the flag that opens each one. A region
## without a flag here opens through the story of the region before it.
const REGION_ORDER: Array[String] = ["veydal", "corvane", "ashmere", "solenne", "vellmarch", "quillmarch", "halcyra", "quivermoor"]
const REGION_GATES: Dictionary[String, String] = {
	"corvane": "ferry_corvane_open",
	"ashmere": "act2_end",
	"vellmarch": "story_complete",
	"quillmarch": "era2_finale_done",
	"halcyra": "era3_finale_done",
	"quivermoor": "era4_finale_done",
}

enum Mode { OPEN, WORST }

var maps: Dictionary = {}
## Flags treated as not set (region check); gates that need them stay shut.
var closed: Dictionary = {}
var mode: int = Mode.OPEN
## map id -> {Vector2i: patch number}
var patch: Dictionary = {}
## "map#n" -> Array of {"to": "map#n", "kind": String}
var edges: Dictionary = {}
## Landing problems found while building.
var land_problems: PackedStringArray = []
## Rest nodes ("map#n" holding a rest point).
var rests: Dictionary = {}

static func load_all() -> Dictionary:
	var out: Dictionary = {}
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		if m != null:
			out[id] = m
	return out

func _init(all_maps: Dictionary, build_mode: int = Mode.OPEN, closed_flags: Dictionary = {}) -> void:
	maps = all_maps
	mode = build_mode
	closed = closed_flags
	for id: String in maps:
		_patches(id)
	for id: String in maps:
		_map_edges(id)
	for t: Variant in Transit.lines().keys():
		_line_edges(str(t))
	for id: String in maps:
		var m: MapData = maps[id]
		if m.heal_point.x >= 0:
			for n: String in _nodes_near(id, m.heal_point):
				rests[n] = true

# --- People and blocks -------------------------------------------------------------------

func _flags_of(v: Variant, out: Array[String]) -> void:
	if v is String:
		out.append(str(v))
	elif v is Array:
		for e: Variant in v:
			_flags_of(e, out)
	elif v is Dictionary:
		for k: Variant in v:
			if str(k) in ["flag", "not_flag"]:
				_flags_of(v[k], out)

## True if a person (or sign) with [param def] may stand on their cell in this mode.
func _stands(def: Dictionary) -> bool:
	if str(def.get("id", "")) == WorldEvents.MERCHANT_ID or NpcSchedule.has_plan(def):
		return false  # moves every day / has a day plan (WorldValidator.check_schedules)
	var hide: String = str(def.get("hide_flag", ""))
	var show: String = str(def.get("show_flag", ""))
	if mode == Mode.WORST:
		# Everyone who may stand there does, except gate keepers who only ever step aside.
		return hide.is_empty() or not show.is_empty()
	if not closed.is_empty():
		if closed.has(hide):
			return true
		if closed.has(show):
			return false
	return show.is_empty() and hide.is_empty() and not def.has("phase_only") and not def.has("weekdays")

func _people(m: MapData) -> Dictionary:
	if _people_cache.has(m.id):
		return _people_cache[m.id]
	var out: Dictionary = {}
	for n: Dictionary in m.npcs:
		if _stands(n):
			out[Vector2i(int(n.x), int(n.y))] = str(n.get("id", ""))
	_people_cache[m.id] = out
	return out

func _block_open(b: Dictionary) -> bool:
	if closed.has(str(b.get("open_flag", ""))):
		return false
	return not (mode == Mode.WORST and b.has("phase_only"))

func _blocked(m: MapData) -> Dictionary:
	var out: Dictionary = {}
	for b: Dictionary in m.blocks:
		if not _block_open(b):
			out[Vector2i(int(b.x), int(b.y))] = true
	return out

## Floor the player can stand on: walkable ground with every block open, gear and puzzle cells
## crossable, no person and no shut block.
func passable(m: MapData, c: Vector2i, people: Dictionary, shut: Dictionary) -> bool:
	if not m.in_bounds(c) or people.has(c) or shut.has(c):
		return false
	# Map rows load with every block open (MapData keeps the shut ones out of the rows).
	var k: int = m.kind_at(c)
	return not TilesetFactory.is_solid(k) or TilesetFactory.GEAR_KINDS.has(k) or k == TilesetFactory.Kind.BOULDER \
		or k == TilesetFactory.Kind.PLANK or m.gear_needed_at(c) != ""

var _block_cells: Dictionary = {}
var _people_cache: Dictionary = {}

func _is_block(m: MapData, c: Vector2i) -> bool:
	if not _block_cells.has(m.id):
		var cells: Dictionary = {}
		for b: Dictionary in m.blocks:
			cells[Vector2i(int(b.x), int(b.y))] = true
		_block_cells[m.id] = cells
	return (_block_cells[m.id] as Dictionary).has(c)

# --- Patches -----------------------------------------------------------------------------

func _patches(id: String) -> void:
	var m: MapData = maps[id]
	var people: Dictionary = _people(m)
	var shut: Dictionary = _blocked(m)
	var p: Dictionary = {}
	var n: int = 0
	for y: int in m.height:
		for x: int in m.rows[y].length():
			var c := Vector2i(x, y)
			if p.has(c) or not passable(m, c, people, shut):
				continue
			p[c] = n
			var q: Array[Vector2i] = [c]
			while not q.is_empty():
				var a: Vector2i = q.pop_back()
				for d: Vector2i in DIRS:
					var b: Vector2i = a + d
					if not p.has(b) and passable(m, b, people, shut):
						p[b] = n
						q.append(b)
			edges["%s#%d" % [id, n]] = []
			n += 1
	patch[id] = p

func node_at(id: String, c: Vector2i) -> String:
	var p: Dictionary = patch.get(id, {})
	return "%s#%d" % [id, p[c]] if p.has(c) else ""

## The patch on [param c], or the patches next to it (a person, sign or warp on a wall cell).
func _nodes_near(id: String, c: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var own: String = node_at(id, c)
	if not own.is_empty():
		out.append(own)
		return out
	for d: Vector2i in DIRS:
		var n: String = node_at(id, c + d)
		if not n.is_empty() and not n in out:
			out.append(n)
	return out

func _link(from: Array[String], to: String, kind: String) -> void:
	for f: String in from:
		(edges[f] as Array).append({"to": to, "kind": kind})

## Checks a landing cell and returns its node ("" if it is no good).
func _land(what: String, to: String, c: Vector2i) -> String:
	if not maps.has(to):
		land_problems.append("%s: leads to unknown map '%s'" % [what, to])
		return ""
	var m: MapData = maps[to]
	if not m.in_bounds(c):
		land_problems.append("%s: lands outside '%s' at %s" % [what, to, c])
		return ""
	if not m.is_walkable(c) or _is_block(m, c):
		land_problems.append("%s: lands on %s in '%s' at %s" % [what, "a block" if _is_block(m, c) else "a solid tile '%s'" % m.char_at(c), to, c])
		return ""
	# Anyone who may ever stand there counts, gate keepers too (they stand there until their flag).
	for n: Dictionary in m.npcs:
		if Vector2i(int(n.x), int(n.y)) == c and str(n.get("id", "")) != WorldEvents.MERCHANT_ID and not NpcSchedule.has_plan(n):
			land_problems.append("%s: lands on '%s' standing at %s in '%s'" % [what, n.get("id", ""), c, to])
			return ""
	return node_at(to, c)

func _map_edges(id: String) -> void:
	var m: MapData = maps[id]
	for w: Dictionary in m.warps:
		var at := Vector2i(int(w.x), int(w.y))
		var dest: String = _land("'%s' warp %s" % [id, at], str(w.to), Vector2i(int(w.tx), int(w.ty)))
		if not dest.is_empty():
			_link(_nodes_near(id, at), dest, "warp")
	if not m.drop_to.is_empty():
		for y: int in m.height:
			for x: int in m.rows[y].length():
				var c := Vector2i(x, y)
				if m.kind_at(c) == TilesetFactory.Kind.CRACKED:
					var dest: String = _land("'%s' cracked floor %s" % [id, c], m.drop_to, c)
					if not dest.is_empty():
						_link(_nodes_near(id, c), dest, "drop")
	for ld: Dictionary in m.ladders:
		var at := Vector2i(int(ld.x), int(ld.y))
		var dest: String = _land("'%s' ladder %s" % [id, at], str(ld.to), Vector2i(int(ld.tx), int(ld.ty)))
		if not dest.is_empty():
			_link(_nodes_near(id, at), dest, "ladder")
	for g: Dictionary in m.gear_spots:
		if not g.has("to"):
			continue
		var f: Array = g.get("from", [])
		var src: String = node_at(id, Vector2i(int(f[0]), int(f[1])))
		var dst: String = node_at(id, Vector2i(int(g.to[0]), int(g.to[1])))
		if not src.is_empty() and not dst.is_empty():
			_link([src] as Array[String], dst, "gear")
	for list: Array in [m.npcs, m.signs]:
		for def: Dictionary in list:
			if not def.has("dialogue"):
				continue
			if mode == Mode.WORST and def.has("show_flag"):
				continue
			if closed.has(str(def.get("show_flag", ""))):
				continue
			var at := Vector2i(int(def.x), int(def.y))
			for t: Dictionary in story_warps(str(def.dialogue)):
				if not _gated(t.flags):
					var dest: String = _land("'%s' %s at %s (%s)" % [id, def.get("id", "sign"), at, t.via], str(t.to), t.cell)
					if not dest.is_empty():
						_link(_nodes_near(id, at), dest, "story")
	# Arrival scenes play wherever the player comes in.
	for on: Dictionary in StoryPlacements.enter_entries(id):
		for t: Dictionary in _scene_warps(str(on.get("scene", "")), {}, []):
			var dest: String = _land("'%s' arrival scene (%s)" % [id, t.via], str(t.to), t.cell)
			if not dest.is_empty():
				var all: Array[String] = []
				for k: String in edges:
					if k.begins_with(id + "#"):
						all.append(k)
				_link(all, dest, "story")

func _gated(flags: Array) -> bool:
	if mode == Mode.WORST and not flags.is_empty():
		return true
	for f: Variant in flags:
		if closed.has(str(f)):
			return true
	return false

func _line_edges(lid: String) -> void:
	var l: Dictionary = Transit.line(lid)
	if bool(l.get("story", false)):
		return  # run by its own dialogue (story warps)
	var gate: String = str(l.get("open_flag", ""))
	if not gate.is_empty() and (mode == Mode.WORST or closed.has(gate)):
		return
	var at: Dictionary = {}
	for s: String in Transit.stops(lid):
		var a: Dictionary = Transit.arrival(lid, s)
		var n: String = _land("line '%s' stop" % lid, s, a.get("cell", Vector2i(-1, -1)))
		if not n.is_empty():
			at[s] = n
	for a: String in at:
		for b: String in at:
			if a != b:
				_link([at[a]] as Array[String], at[b], "line")

# --- Story warps -------------------------------------------------------------------------

## Map changes a talk with [param ref] can start: [{"to", "cell", "flags": [...], "via"}].
## "flags" are the flags its conditions name (a gated warp).
func story_warps(ref: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_walk_dialogue(ref, {}, [], out)
	return out

func _walk_dialogue(ref: String, seen: Dictionary, flags: Array, out: Array[Dictionary]) -> void:
	if ref.is_empty() or seen.has(ref) or seen.size() > 64:
		return
	seen[ref] = true
	var e: Dictionary = Dialogue.get_entry(ref)
	if e.is_empty():
		return
	var here: Array = flags.duplicate()
	if e.has("if"):
		var f: Array[String] = []
		_flags_of(e.get("if"), f)
		if e.has("else"):
			_walk_dialogue(Dialogue.resolve_ref(ref, str(e.else)), seen, flags, out)
		here.append_array(f)
	if e.has("action"):
		_action_warps(str(e.action), here, ref, seen, out)
	for ch: Variant in e.get("choices", []):
		if not ch is Dictionary:
			continue
		var cf: Array = here.duplicate()
		if (ch as Dictionary).has("if"):
			var f: Array[String] = []
			_flags_of(ch.get("if"), f)
			cf.append_array(f)
		if (ch as Dictionary).has("action"):
			_action_warps(str(ch.action), cf, ref, seen, out)
		if (ch as Dictionary).has("next"):
			_walk_dialogue(Dialogue.resolve_ref(ref, str(ch.next)), seen, cf, out)
	if e.has("next"):
		_walk_dialogue(Dialogue.resolve_ref(ref, str(e.next)), seen, here, out)

func _action_warps(action: String, flags: Array, via: String, seen: Dictionary, out: Array[Dictionary]) -> void:
	var a: PackedStringArray = action.split(" ", false)
	if a.is_empty():
		return
	match a[0]:
		"warp":
			if a.size() >= 4:
				out.append({"to": a[1], "cell": Vector2i(int(a[2]), int(a[3])), "flags": flags, "via": via})
		"echo_chest":
			out.append({"to": EchoPath.FILE, "cell": EchoPath.ARRIVE_DOWN, "flags": flags, "via": via})
		"scene":
			if a.size() >= 2:
				out.append_array(_scene_warps(a[1], seen, flags))

func _scene_warps(id: String, seen: Dictionary, flags: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key: String = "scene:" + id
	if id.is_empty() or seen.has(key):
		return out
	seen[key] = true
	var path: String = ScenePlayer.DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return out
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		return out
	for st: Variant in (raw as Dictionary).get("steps", []):
		if not st is Dictionary:
			continue
		if (st as Dictionary).has("action"):
			_action_warps(str(st.action), flags, "scene " + id, seen, out)
		if (st as Dictionary).has("dialogue"):
			_walk_dialogue(str(st.dialogue), seen, flags, out)
	return out

# --- Searches ----------------------------------------------------------------------------

func reach(starts: Array[String]) -> Dictionary:
	var seen: Dictionary = {}
	var q: Array[String] = []
	for s: String in starts:
		if not s.is_empty() and not seen.has(s):
			seen[s] = true
			q.append(s)
	while not q.is_empty():
		var n: String = q.pop_back()
		for e: Dictionary in edges.get(n, []):
			if not seen.has(e.to):
				seen[e.to] = true
				q.append(str(e.to))
	return seen

## Nodes that can still get to a rest node.
func reach_rest() -> Dictionary:
	var back: Dictionary = {}
	for n: String in edges:
		for e: Dictionary in edges[n]:
			var arr: Array = back.get(e.to, [])
			arr.append(n)
			back[e.to] = arr
	var seen: Dictionary = {}
	var q: Array[String] = []
	for r: String in rests:
		seen[r] = true
		q.append(r)
	while not q.is_empty():
		var n: String = q.pop_back()
		for p: Variant in back.get(n, []):
			if not seen.has(p):
				seen[p] = true
				q.append(str(p))
	return seen

func start_node() -> String:
	return node_at(START_MAP, START_CELL)

func cells_of(node: String) -> Array[Vector2i]:
	var id: String = node.get_slice("#", 0)
	var k: int = int(node.get_slice("#", 1))
	var out: Array[Vector2i] = []
	var p: Dictionary = patch.get(id, {})
	for c: Vector2i in p:
		if p[c] == k:
			out.append(c)
	return out

# --- Checks ------------------------------------------------------------------------------

## Every problem of the world graph, as text (empty when the world is sound).
static func problems(all_maps: Dictionary = {}) -> PackedStringArray:
	if all_maps.is_empty():
		all_maps = load_all()
	var out: PackedStringArray = []
	var open := WorldGraph.new(all_maps, Mode.OPEN)
	var worst := WorldGraph.new(all_maps, Mode.WORST)
	out.append_array(open.land_problems)
	for p: String in worst.land_problems:
		if not p in out:
			out.append(p)
	out.append_array(open.check_rests())
	var reached: Dictionary = open.reach([open.start_node()] as Array[String])
	if open.start_node().is_empty():
		out.append("start: %s %s is no free floor" % [START_MAP, START_CELL])
	var maps_reached: Dictionary = {}
	for n: String in reached:
		maps_reached[n.get_slice("#", 0)] = true
	for id: String in all_maps:
		if not maps_reached.has(id):
			out.append("start: '%s' cannot be reached from the start" % id)
	out.append_array(traps(open, worst, reached))
	out.append_array(region_order(all_maps))
	return out

## Patches the player can reach that have no way back to a rest spring when everything that
## may stand in the way does.
static func traps(open: WorldGraph, worst: WorldGraph, reached: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var safe: Dictionary = worst.reach_rest()
	var stand: Dictionary = {}
	for n: String in reached:
		for c: Vector2i in open.cells_of(n):
			var w: String = worst.node_at(n.get_slice("#", 0), c)
			if not w.is_empty():
				stand[w] = true
	var ids: Array = stand.keys()
	ids.sort()
	for w: String in ids:
		if not safe.has(w):
			var cells: Array[Vector2i] = worst.cells_of(w)
			cells.sort()
			out.append("trap: '%s' %d cells from %s have no way back to a rest spring" % [w.get_slice("#", 0), cells.size(), cells[0]])
	return out

## Rest points (defeat return, fast travel) and the start: free floor, not a warp.
func check_rests() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in maps:
		var m: MapData = maps[id]
		if m.heal_point.x < 0:
			continue
		var c: Vector2i = m.heal_point
		var why: String = ""
		if not m.in_bounds(c) or not m.is_walkable(c) or _is_block(m, c):
			why = "is not floor"
		elif _people(m).has(c):
			why = "has '%s' standing on it" % _people(m)[c]
		elif not m.warp_at(c).is_empty():
			why = "is a warp"
		if not why.is_empty():
			out.append("rest: '%s' rest point %s %s" % [id, c, why])
	return out

## Each story region opens in order: shut while its gate flag (and every later one) is unset,
## open once its gate and the earlier ones are set.
static func region_order(all_maps: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var region_of: Dictionary = {}
	for id: String in all_maps:
		region_of[id] = (all_maps[id] as MapData).region
	for i: int in REGION_ORDER.size():
		var r: String = REGION_ORDER[i]
		var later: Dictionary = {}
		for j: int in range(i + 1, REGION_ORDER.size()):
			if REGION_GATES.has(REGION_ORDER[j]):
				later[REGION_GATES[REGION_ORDER[j]]] = true
		var open := WorldGraph.new(all_maps, Mode.OPEN, later)
		if not _region_reached(open, region_of, r):
			out.append("region: %s cannot be reached once %s" % [r, "the game starts" if i == 0 else "its gate '%s' is set" % REGION_GATES.get(r, REGION_ORDER[i - 1])])
		if REGION_GATES.has(r):
			var shut: Dictionary = later.duplicate()
			shut[REGION_GATES[r]] = true
			var gated := WorldGraph.new(all_maps, Mode.OPEN, shut)
			if _region_reached(gated, region_of, r):
				out.append("region: %s can be entered before its gate '%s' is set" % [r, REGION_GATES[r]])
	return out

static func _region_reached(g: WorldGraph, region_of: Dictionary, r: String) -> bool:
	for n: String in g.reach([g.start_node()] as Array[String]):
		if region_of.get(n.get_slice("#", 0), "") == r:
			return true
	return false
