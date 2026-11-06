extends GutTest
## Plan area 8, item 3513: the 90-day endgame run stays near the Waymark target.

func before_all() -> void:
	Database.load_all()

func test_ninety_days_stay_near_the_target() -> void:
	var r: Dictionary = EndgameSim.run(90)
	assert_eq(int(r.days), 90)
	assert_eq(int(r.lost), 0, "nothing is lost over the cap")
	assert_between(float(r.per_week), 500.0, 800.0, "about 750 a week for a full plan (docs/BALANCE.md)")
	assert_gt(int(r.spent), 0, "Marla's stand is a real sink")
	assert_gte(int(r.balance), 0)
	for src: Variant in (r.earned as Dictionary).keys():
		assert_true(str(src) in Waymarks.SOURCES, str(src))
	assert_false(EndgameSim.report(r).is_empty())

func test_no_single_repeat_source_outweighs_daily_tasks() -> void:
	var r: Dictionary = EndgameSim.run(90)
	var daily: int = int(r.earned.get("daily_task", 0))
	for src: Variant in (r.earned as Dictionary).keys():
		assert_lte(int(r.earned[src]), daily, "%s should not beat daily tasks" % src)
