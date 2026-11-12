extends GutTest
## Warden rematches after the finale (data/warden_rematch.json, WardenRematch.gd).

func before_all() -> void:
	Database.load_all()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func test_all_twelve_wardens_have_a_rematch() -> void:
	var seen: Dictionary = {}
	for e: Dictionary in WardenRematch.entries():
		seen[str(e.warden)] = true
		var npc: Dictionary = _npc(str(e.map), str(e.npc))
		assert_false(npc.is_empty(), "%s: npc %s on %s" % [e.warden, e.npc, e.map])
		assert_eq(str(npc.get("warden", "")), str(e.warden), str(e.warden))
	assert_eq(seen.size(), 12)

func test_teams_are_stronger_and_valid() -> void:
	for e: Dictionary in WardenRematch.entries():
		var npc: Dictionary = _npc(str(e.map), str(e.npc))
		var old_top: int = 0
		for t: Dictionary in TrainerData.team_entries(npc, "", -1):
			old_top = maxi(old_top, int(t.level))
		var team: Array = e.team
		assert_eq(team.size(), 6, str(e.warden))
		for t: Dictionary in team:
			assert_not_null(Database.species(str(t.species)), str(t.species))
			assert_gt(int(t.level), old_top, str(e.warden))
			assert_true(int(t.level) <= Spirling.STORY_RING, str(e.warden))

func test_rewards_and_lines() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for e: Dictionary in WardenRematch.entries():
		assert_false(Database.item(str(e.reward.item)).is_empty(), str(e.reward.item))
		assert_gt(int(e.money), 0)
		for k: String in ["intro", "win", "lose"]:
			assert_gt((e[k] as Array).size(), 0, "%s %s" % [e.warden, k])
			for s: Variant in e[k]:
				assert_true(de.has(str(s)), "DE missing: %s" % s)

func test_unlocks_after_finale_and_once() -> void:
	var e: Dictionary = WardenRematch.entries()[0]
	var npc: Dictionary = _npc(str(e.map), str(e.npc))
	var flags: Dictionary = {}
	assert_false(WardenRematch.can_challenge(npc, str(e.map), flags))
	flags[TrainerData.beaten_flag(npc, str(e.map))] = true
	assert_false(WardenRematch.can_challenge(npc, str(e.map), flags))
	flags["story_complete"] = true
	assert_true(WardenRematch.can_challenge(npc, str(e.map), flags))
	flags[WardenRematch.won_flag(e)] = true
	assert_false(WardenRematch.can_challenge(npc, str(e.map), flags))

func test_rematch_def_uses_own_team_and_flag() -> void:
	var e: Dictionary = WardenRematch.entries()[0]
	var npc: Dictionary = _npc(str(e.map), str(e.npc))
	var def: Dictionary = WardenRematch.rematch_def(npc, e)
	assert_eq(def.team, e.team)
	assert_false(def.has("second_trial"))
	assert_eq(TrainerData.beaten_flag(def, str(e.map)), WardenRematch.won_flag(e))
	var team: Array[Spirling] = TrainerData.build_team(def, "", RandomNumberGenerator.new())
	assert_eq(team.size(), 6)
