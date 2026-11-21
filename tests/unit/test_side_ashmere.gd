extends GutTest
## Act III side content in Ashmere: the Soot Vaults, Juno Sallow, the collecting goals and
## the side goals with a betrayal in them (tools/act_hours.py puts the act at 20 h).

const NATIVES: Array[String] = ["Hushkin", "Blotling", "Duskdigger", "Calderox", "Cairnhold", "Talusgard"]
const GOALS: Array[String] = ["soot_vaults", "juno", "wage_plates", "census", "press_parts", "station_lost",
	"kiln_fire", "cinder_ash", "harl_story", "bram_ash", "clan_ious", "salt_song", "new_paymaster"]

func before_all() -> void:
	Database.load_all()

func test_vaults_are_six_rooms_in_ashmere() -> void:
	var top: MapData = MapData.load_map("soot_vaults")
	assert_not_null(top)
	assert_eq(top.region, "ashmere")
	assert_eq(top.floor_count, 6)
	for i: int in top.floor_count:
		var m: MapData = MapData.load_map(MapData.floor_id("soot_vaults", i))
		assert_eq(m.encounter_table, "soot_vaults", "room %d" % i)

func test_vaults_are_home_to_the_six_census_kinds() -> void:
	var found: Array[String] = []
	for sp: Variant in EncounterTable.table("soot_vaults").get("spawns", []):
		found.append(str((sp as Dictionary).species))
	for n: String in NATIVES:
		assert_has(found, n)

func test_every_side_goal_is_listed() -> void:
	var ids: Array[String] = []
	for g: Variant in QuestLog.data().get("side", []):
		ids.append(str((g as Dictionary).id))
	for id: String in GOALS:
		assert_has(ids, id)

func test_gorse_is_caught_only_with_all_three_tickets() -> void:
	var e: Dictionary = Dialogue.get_entry("ashmere_side/gorse_check")
	assert_false(Dialogue.check(e.get("if"), {"press_part_1": true, "press_part_2": true}))
	assert_true(Dialogue.check(e.get("if"), {"press_part_1": true, "press_part_2": true, "press_part_3": true}))
	assert_eq(str(e.action), "battle gorse")
	assert_true(StoryBattles.has("gorse"))

func test_census_ends_after_all_six() -> void:
	var e: Dictionary = Dialogue.get_entry("ashmere_side/mott_end")
	var flags: Dictionary = {}
	for n: String in NATIVES:
		assert_false(Dialogue.check(e.get("if"), flags))
		flags["census_" + n.to_lower()] = true
	assert_true(Dialogue.check(e.get("if"), flags))

func test_fitch_betrays_unless_tibb_vouched() -> void:
	var fav: Dictionary = Trust.favor("fitch_toll")
	var vars: Dictionary = {}
	assert_eq(Trust.resolve(fav, Trust.trust_in("fitch", vars), Trust.use_in("fitch", vars), 0.9), "betray")
	assert_true(str(Dialogue.get_entry("ashmere_side/dace_defeat").action).contains("trust fitch 40"))
	Trust.apply_values({"trust": {"fitch": 40}}, vars)
	assert_eq(Trust.resolve(fav, Trust.trust_in("fitch", vars), Trust.use_in("fitch", vars), 0.9), "kept")

func test_juno_sells_the_route_into_the_ledger() -> void:
	var juno: Dictionary = {}
	for n: Dictionary in MapData.load_map("soot_vaults@4").npcs:
		if str(n.id) == "juno_3":
			juno = n
	assert_has(juno.get("win_flags", []), Trust.ledger_flag("juno_sale"))
	for ref: String in ["soot_vaults/ledger_juno", "soot_vaults/ledger_fitch"]:
		assert_gte(Trust.ledger_text(ref).size(), 2, ref)

func test_texts_have_german() -> void:
	for ref: String in ["ashmere_side/brisk_ask", "soot_vaults/crake_intro", "ashmere_side/marn_wait"]:
		for line: String in Dialogue.lines_for(Dialogue.get_entry(ref), {}):
			assert_true(Loc.load_table("de").strings.has(line), line)
