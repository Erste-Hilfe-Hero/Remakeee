extends GutTest
## Plan 2 audit: the twelve Era I Wardens (six from 1.0 plus Brisa, Darrow, Odalys, Aurelio, Kaia,
## Emrys) and the four Vellmarch Wardens. Walks the list and checks each one is complete:
## reachable, team on the level curve, rewards, dialogue in EN and DE, rematch (#370).

## Era I in GameState.STORY_RIFTS order: [rift id, map, npc, trainer name].
const ERA_ONE: Array = [
	["cinder", "cinder_rift", "warden_orrin", "Warden Orrin"],
	["mist", "mist_rift", "warden_brisa", "Warden Brisa"],
	["tide", "tide_rift", "warden_maelis", "Warden Maelis"],
	["rain", "rain_rift", "warden_senna", "Warden Senna"],
	["mirror", "mirror_rift", "warden_joral", "Warden Joral"],
	["root", "root_rift", "warden_darrow", "Warden Darrow"],
	["kiln", "kiln_rift", "warden_tovan", "Warden Tovan"],
	["glass", "glass_rift", "warden_ilse", "Warden Ilse"],
	["shade", "shade_rift", "warden_odalys", "Warden Odalys"],
	["tower", "tower_rift", "warden_aurelio", "Warden Aurelio"],
	["oasis", "oasis_rift", "warden_kaia", "Warden Kaia"],
	["sun", "sun_rift", "warden_emrys", "Warden Emrys"],
]

var _de: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_de = Loc.load_table("de").get("strings", {})

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _top(team: Array) -> int:
	var top: int = 0
	for e: Variant in team:
		top = maxi(top, int((e as Dictionary).get("level", 0)))
	return top

func _german(s: String) -> bool:
	return _de.has(s)

## Every line of a dialogue entry, its after_flag lines included.
func _lines(ref: String) -> Array[String]:
	var out: Array[String] = []
	var e: Dictionary = Dialogue.get_entry(ref)
	for s: Variant in e.get("lines", []):
		out.append(str(s))
	for a: Variant in e.get("after_flag", []):
		for s: Variant in (a as Dictionary).get("lines", []):
			out.append(str(s))
	return out

# --- Era I ---------------------------------------------------------------------------------

func test_the_list_is_the_twelve_story_rifts() -> void:
	var ids: Array[String] = []
	for w: Array in ERA_ONE:
		ids.append(str(w[0]))
		var npc: Dictionary = _npc(str(w[1]), str(w[2]))
		assert_false(npc.is_empty(), "%s stands on %s" % [w[2], w[1]])
		assert_eq(str(npc.get("warden", "")), str(w[0]), str(w[2]))
		assert_eq(str(npc.get("trainer", "")), str(w[3]), str(w[2]))
	assert_eq(ids, GameState.STORY_RIFTS)

func test_every_era_one_warden_is_reachable() -> void:
	var all: PackedStringArray = MapData.all_ids()
	var entries: Dictionary = WorldValidator.entry_cells(all)
	for w: Array in ERA_ONE:
		var mid: String = str(w[1])
		var into: int = 0
		for other: String in all:
			if other == mid:
				continue
			into += MapData.load_map(other).warps.filter(func(x: Dictionary) -> bool: return str(x.to) == mid).size()
		assert_gt(into, 0, "%s has a way in" % mid)
		var m: MapData = MapData.load_map(mid)
		var reach: Dictionary = WorldValidator.reachable_cells(m, entries.get(mid, []))
		assert_false(reach.is_empty(), "%s is entered from the start" % mid)
		var npc: Dictionary = _npc(mid, str(w[2]))
		var c := Vector2i(int(npc.get("x", -1)), int(npc.get("y", -1)))
		var near: bool = false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			near = near or reach.has(c + d)
		assert_true(near, "%s can be walked up to" % w[2])

func test_era_one_teams_follow_the_level_curve() -> void:
	var last_top: int = 0
	var last_size: int = 0
	for i: int in ERA_ONE.size():
		var w: Array = ERA_ONE[i]
		var team: Array = TrainerData.team_entries(_npc(str(w[1]), str(w[2])), "", -1)
		var top: int = _top(team)
		assert_gte(top, last_top, "%s (ring %d) after ring %d" % [w[2], top, last_top])
		assert_lte(top, GameState.LEVEL_CAPS[i], "%s fits the ring cap with %d Rifts mended" % [w[2], i])
		assert_gte(team.size(), last_size, "%s fields no fewer Spirlings than the Warden before" % w[2])
		for e: Variant in team:
			assert_not_null(Database.species(str((e as Dictionary).species)), "%s: %s" % [w[2], (e as Dictionary).species])
		last_top = top
		last_size = team.size()
	assert_lte(last_top, _top(StoryBattles.get_def("echo_1").get("team", [])), "the finale tops the last Warden")

func test_era_one_rewards() -> void:
	var gifts: Dictionary = {}
	var last_money: int = 0
	for w: Array in ERA_ONE:
		var npc: Dictionary = _npc(str(w[1]), str(w[2]))
		var money: int = int(npc.get("money", 0))
		assert_gte(money, last_money, "%s pays no less than the Warden before" % w[2])
		last_money = money
		var mend: Array = npc.get("mend_items", [])
		assert_eq(mend.size(), 1, "%s gives a gift after the mend" % w[2])
		for it: Variant in mend:
			var item: Dictionary = Database.item(str(it))
			assert_false(item.is_empty(), str(it))
			assert_not_null(Database.move(str(item.get("teaches", ""))), "%s teaches an art" % it)
			assert_false(gifts.has(str(it)), "%s: %s is already another Warden's gift" % [w[2], it])
			gifts[str(it)] = true

func test_era_one_dialogue_in_english_and_german() -> void:
	for w: Array in ERA_ONE:
		var npc: Dictionary = _npc(str(w[1]), str(w[2]))
		for k: String in ["dialogue", "intro", "defeat"]:
			assert_true(Dialogue.exists(str(npc.get(k, ""))), "%s %s" % [w[2], k])
			var lines: Array[String] = _lines(str(npc.get(k, "")))
			assert_false(lines.is_empty(), "%s %s" % [w[2], k])
			for s: String in lines:
				assert_true(_german(s), "DE missing for %s: %s" % [w[2], s])
		# A line after the mend and one after the finale (item 1605).
		var after: Array = (Dialogue.get_entry(str(npc.dialogue)).get("after_flag", []) as Array).map(
			func(a: Dictionary) -> String: return str(a.flag))
		assert_has(after, "rift_%s_sealed" % w[0], str(w[2]))
		assert_has(after, "story_complete", str(w[2]))

func test_era_one_rematch() -> void:
	for w: Array in ERA_ONE:
		var npc: Dictionary = _npc(str(w[1]), str(w[2]))
		var e: Dictionary = WardenRematch.entry_for(str(w[1]), str(w[2]))
		assert_false(e.is_empty(), "%s has a rematch" % w[2])
		if e.is_empty():
			continue
		assert_eq(str(e.warden), str(w[0]))
		var team: Array = e.team
		assert_eq(team.size(), 6, str(w[2]))
		assert_gt(_top(team), _top(TrainerData.team_entries(npc, "", -1)), str(w[2]))
		assert_lte(_top(team), Spirling.MAX_LEVEL, str(w[2]))
		assert_gt(int(e.money), int(npc.get("money", 0)), "%s rematch pays more" % w[2])
		var reward: String = str((e.reward as Dictionary).item)
		assert_false(Database.item(reward).is_empty(), reward)
		assert_does_not_have(npc.get("mend_items", []), reward, "%s rematch gives something new" % w[2])
		for k: String in ["intro", "win", "lose"]:
			assert_false((e[k] as Array).is_empty(), "%s rematch %s" % [w[2], k])
			for s: Variant in e[k]:
				assert_true(_german(str(s)), "DE missing: %s" % s)
		var flags: Dictionary = {TrainerData.beaten_flag(npc, str(w[1])): true}
		assert_false(WardenRematch.can_challenge(npc, str(w[1]), flags), "%s waits for the finale" % w[2])
		flags["story_complete"] = true
		assert_true(WardenRematch.can_challenge(npc, str(w[1]), flags), str(w[2]))

# --- Vellmarch (Era II, data/region2.json) -------------------------------------------------

func test_vellmarch_rifts_are_reachable_on_the_sheet() -> void:
	var d: Dictionary = Region2.data()
	var reached: Dictionary = {str(d.arrival.to): true}
	for i: int in 10:
		for r: Dictionary in d.routes:
			if reached.has(str(r.links[0])) or reached.has(str(r.links[1])):
				reached[str(r.links[0])] = true
				reached[str(r.links[1])] = true
	assert_eq((d.rifts as Array).size(), 4)
	for r: Dictionary in d.rifts:
		assert_true(reached.has(str(r.near)), "%s lies by a town the barge leads to" % r.id)
		assert_eq(str(Region2.rift(str(r.id)).warden), str(r.warden))

func test_vellmarch_teams_follow_the_level_curve() -> void:
	var last_ring: int = _top(_npc("sun_rift", "warden_emrys").team)
	var last_size: int = (_npc("sun_rift", "warden_emrys").team as Array).size()
	for w: Dictionary in Region2.wardens():
		assert_gt(int(w.ring), last_ring, "%s comes after ring %d" % [w.id, last_ring])
		assert_lte(int(w.ring), Spirling.MAX_LEVEL, "%s ring fits Spirling.MAX_LEVEL" % w.id)
		assert_eq(_top(w.team), int(w.ring), "%s ace is at its ring" % w.id)
		assert_gte((w.team as Array).size(), last_size, "%s fields no fewer than the Warden before" % w.id)
		for t: Dictionary in w.team:
			assert_not_null(Database.species(Region2.slot_species(t)), str(w.id))
		last_ring = int(w.ring)
		last_size = (w.team as Array).size()
	for r: Dictionary in Region2.data().routes:
		assert_lte(int(r.ring[1]), Spirling.MAX_LEVEL, "%s ring fits Spirling.MAX_LEVEL" % r.id)

func test_vellmarch_rewards_dialogue_and_rematch() -> void:
	var last_money: int = 0
	for w: Dictionary in Region2.wardens():
		assert_gt(int(w.money), last_money, str(w.id))
		last_money = int(w.money)
		var reward: String = str((w.get("reward", {}) as Dictionary).get("item", ""))
		assert_false(Database.item(reward).is_empty(), "%s reward %s" % [w.id, reward])
		for s: String in [str(w.intro), str(w.defeat)]:
			assert_true(_german(s), "DE missing: %s" % s)
		var re: Dictionary = w.get("rematch", {})
		assert_false(re.is_empty(), "%s has a rematch" % w.id)
		if re.is_empty():
			continue
		assert_eq(str(re.after), "vellmarch_done", str(w.id))
		assert_eq((re.team as Array).size(), 6, str(w.id))
		for t: Dictionary in re.team:
			assert_not_null(Database.species(Region2.slot_species(t)), str(w.id))
			assert_gte(int(t.level), _top(w.team), str(w.id))
			assert_lte(int(t.level), Spirling.MAX_LEVEL, str(w.id))
		assert_gt(int(re.money), int(w.money), str(w.id))
		var again: String = str((re.reward as Dictionary).item)
		assert_false(Database.item(again).is_empty(), again)
		assert_ne(again, reward, "%s rematch gives something new" % w.id)
		for k: String in ["intro", "win", "lose"]:
			assert_false((re[k] as Array).is_empty(), "%s rematch %s" % [w.id, k])
			for s: Variant in re[k]:
				assert_true(_german(str(s)), "DE missing: %s" % s)
	var sets: Array = (Region2.data().story as Array).map(func(c: Dictionary) -> String: return str(c.sets))
	assert_has(sets, "vellmarch_done", "the rematch flag is set by the arc")
