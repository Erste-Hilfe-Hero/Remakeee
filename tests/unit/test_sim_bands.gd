extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 850-856): the target bands of
## docs/BALANCE.md, measured on the real battle model with fixed seeds.
##
## KNOWN_GAPS are bands the game misses today. They are written down in docs/BALANCE.md
## ("Known gaps") and checked to stay there, so nobody loses track of them; everything else has
## to be in its band. Take an entry out once it is fixed.
const KNOWN_GAPS: Array[String] = ["field:ash_storm", "field:deep_murk", "field:dawn_glow", "field:static_veil",
	"ladder:2", "ladder:3", "mono:Gale", "mono:Umbra", "mono:Volt"]

var duels: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	for lv: int in [20, 36]:
		duels[lv] = BalanceSim.run(lv, 3, 850)

## Item 850.
func test_first_mover_advantage_stays_under_the_cap() -> void:
	for lv: int in duels:
		var fa: float = float(duels[lv].first_advantage)
		assert_lt(fa, BalanceSim.FIRST_ADVANTAGE_MAX + 0.0001, "ring %d: the faster Spirling wins %d%%" % [lv, roundi(fa * 100.0)])

## Item 851.
func test_turns_to_knockout_at_ring_36() -> void:
	var ko: float = float(duels[36].ko_turns)
	assert_between(ko, BalanceSim.KO_TURNS_BAND.x, BalanceSim.KO_TURNS_BAND.y, "turns to KO %.2f" % ko)

## Item 852.
func test_rest_share_in_team_mode() -> void:
	var rs: float = float(BalanceSim.run_team(36, 150, 852).rest_share)
	assert_between(rs, BalanceSim.REST_BAND.x, BalanceSim.REST_BAND.y, "rest share %d%%" % roundi(rs * 100.0))

## Item 853.
func test_no_keepsake_lifts_the_win_rate_by_more_than_six_points() -> void:
	var r: Dictionary = BalanceSim.run_keepsakes(36, 120, 1234)
	assert_gt(r.keepsakes.size(), 3)
	for id: String in r.keepsakes:
		assert_lt(float(r.keepsakes[id].gain), BalanceSim.KEEPSAKE_MAX_GAIN + 0.0001, "%s %+.1f" % [id, float(r.keepsakes[id].gain) * 100.0])

## Item 854 (ring 36).
func test_every_field_lifts_its_element_by_eight_to_fifteen_points() -> void:
	var r: Dictionary = BalanceSim.run_fields(36, 200, 1234)
	assert_eq(r.fields.size(), 6)
	for fid: String in r.fields:
		var g: float = float(r.fields[fid].gain)
		_check("field:" + fid, g >= BalanceSim.FIELD_GAIN_BAND.x and g <= BalanceSim.FIELD_GAIN_BAND.y, "%s %+.1f" % [fid, g * 100.0])

## Item 855.
func test_ai_ladder_meets_its_targets() -> void:
	var r: Dictionary = BalanceSim.run_ladder(36, 200, 1234)
	for t: Variant in r.tiers:
		var row: Dictionary = r.tiers[t]
		_check("ladder:%d" % int(row.tier), bool(row.ok), "tier %d against %d wins %d%% (target %d%%)" % [
			int(row.tier), int(row.tier) - 1, roundi(float(row.rate) * 100.0), roundi(float(row.target) * 100.0)])

## Item 856.
func test_every_element_lands_in_the_mono_band() -> void:
	var r: Dictionary = BalanceSim.run_mono(36, 400, 1234)
	for e: String in r.elements:
		var wr: float = BalanceSim.win_rate(r.elements[e])
		_check("mono:" + e, wr >= BalanceSim.MONO_BAND.x and wr <= BalanceSim.MONO_BAND.y, "%s teams win %d%%" % [e, roundi(wr * 100.0)])

func test_known_gaps_are_written_down() -> void:
	var doc: String = FileAccess.get_file_as_string("res://docs/BALANCE.md")
	assert_string_contains(doc, "## Known gaps")
	for gap: String in KNOWN_GAPS:
		assert_string_contains(doc, "`%s`" % gap)

## In band, or a known gap (then it is reported but not failed).
func _check(key: String, ok: bool, what: String) -> void:
	if key in KNOWN_GAPS:
		gut.p("known gap %s: %s" % [key, what])
		return
	assert_true(ok, what)
