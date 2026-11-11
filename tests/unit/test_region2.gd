extends GutTest
## Vellmarch, the post-game Era II region (data/region2.json, scripts/core/Region2.gd).

var _d: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_d = Region2.data()

func test_opens_only_after_the_finale_in_era_two() -> void:
	assert_eq(str(_d.unlock_flag), EraManager.STORY_COMPLETE_FLAG)
	assert_false(Region2.is_open({}))
	assert_true(Region2.is_open({"story_complete": true}))
	assert_eq(EraManager.REGION_ERA[str(_d.id)], EraManager.Era.WASH)
	assert_eq(int(_d.era), 2)

func test_towns_and_routes_link_up() -> void:
	var towns: Dictionary = {}
	var cells: Dictionary = {}
	for t: Dictionary in _d.towns:
		towns[t.id] = true
		assert_false(cells.has(str(t.pos)), "%s cell" % t.id)
		cells[str(t.pos)] = true
	assert_gte(towns.size(), 4)
	assert_gte((_d.routes as Array).size(), 5)
	var reached: Dictionary = {str(_d.arrival.to): true}
	for i: int in 10:
		for r: Dictionary in _d.routes:
			var a: String = str(r.links[0])
			var b: String = str(r.links[1])
			assert_true(towns.has(a) and towns.has(b), "%s links towns" % r.id)
			if reached.has(a) or reached.has(b):
				reached[a] = true
				reached[b] = true
	assert_eq(reached.size(), towns.size(), "every town reachable from the quay")

func test_slots_have_stand_ins_and_rings_climb() -> void:
	var last: int = 0
	for r: Dictionary in _d.routes:
		assert_gte(int(r.ring[0]), last, "%s ring" % r.id)
		assert_gt(int(r.ring[0]), 50, "post-game rings")
		last = int(r.ring[0])
		var total: int = 0
		for s: Dictionary in r.slots:
			total += int(s.weight)
			assert_true(Database.spirlings.has(Region2.slot_species(s)), str(s.slot))
		assert_eq(total, 100, r.id)
	assert_gt(Region2.open_slots().size(), 0, "slots wait for the region's own Spirlings")
	assert_eq(Region2.slot_species({"species": "Siltgrove", "stand_in": "Cogwright"}), "Siltgrove")

func test_four_wardens_each_hold_a_rift() -> void:
	var ws: Array = Region2.wardens()
	assert_eq(ws.size(), 4)
	var ring: int = 0
	for w: Dictionary in ws:
		var r: Dictionary = Region2.rift(str(w.rift))
		assert_false(r.is_empty(), str(w.id))
		assert_eq(str(r.warden), str(w.id))
		assert_gt(int(w.ring), ring)
		ring = int(w.ring)
		for t: Dictionary in w.team:
			assert_true(Database.spirlings.has(Region2.slot_species(t)), str(w.id))
			assert_lte(int(t.level), int(w.ring))

func test_next_warden_follows_sealed_rifts() -> void:
	var f: Dictionary = {}
	assert_true(Region2.next_warden(f).is_empty(), "shut before the finale")
	f["story_complete"] = true
	assert_eq(str(Region2.next_warden(f).id), "odile")
	f["v2_rift_lock_sealed"] = true
	assert_eq(str(Region2.next_warden(f).id), "brannoc")
	for r: Dictionary in _d.rifts:
		f[r.flag] = true
	assert_true(Region2.next_warden(f).is_empty())

func test_story_is_a_chain_full_of_betrayal() -> void:
	var f: Dictionary = {"story_complete": true}
	var seen: int = 0
	while not Region2.current_chapter(f).is_empty():
		var c: Dictionary = Region2.current_chapter(f)
		assert_false(str(c.betrayal.text).is_empty(), str(c.id))
		f[c.sets] = true
		seen += 1
		assert_lt(seen, 20)
	assert_eq(seen, (_d.story as Array).size())
	assert_true(f.has("vellmarch_done"))

func test_region_elements_are_in_the_chart() -> void:
	var types: Dictionary = Elements.chart().get("types", {})
	for e: String in _d.elements:
		assert_true(types.has(e), e)
		assert_eq(int(types[e].era), 2)

func test_texts_have_german() -> void:
	var texts: Array[String] = [str(_d.name), str(_d.arrival.text)]
	for k: String in ["towns", "routes", "rifts", "wardens"]:
		for e: Dictionary in _d[k]:
			texts.append(str(e.name))
	for t: Dictionary in _d.towns:
		texts.append(str(t.text))
	for w: Dictionary in _d.wardens:
		texts.append_array([str(w.intro), str(w.defeat)])
	for c: Dictionary in _d.story:
		texts.append_array([str(c.title), str(c.text), str(c.betrayal.text)])
	var de: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/region2.json"))
	for s: String in texts:
		assert_true(de.strings.has(s) or s in de.keep, s)
