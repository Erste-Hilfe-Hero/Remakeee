class_name EndgameSim
extends RefCounted
## Endgame economy run (plan area 8, item 3513): DAYS game days with a fixed play plan, worked
## out from the real reward constants and data, no battles. Prints Waymarks in and out per
## source and the endgame coins. Run with tools/balance_sim.gd -- endgame.
##
## The plan (an active player after Act I, both Rifts mended, all masters open):
##   every day   all daily tasks, two rounds of 8-hour roaming trips with MAX trips each
##   every week  weekly echo cleared, all eight masters, the Echo Path, STAIR_FLOORS new floors
##               of the lighthouse stair (until the top), then buy at Marla's stand cheapest first
##   every month the full album; one festival in the run with all five goals
## One-off rewards (achievements, Spirlog goals) are left out: they do not repeat.

const DAYS: int = 90
const TRIPS_PER_DAY: int = 2
const TRIP_HOURS: int = 8
const STAIR_FLOORS: int = 3
const FESTIVALS: int = 1
const MONTH_DAYS: int = 30

static func _add(d: Dictionary, k: String, n: int) -> void:
	d[k] = int(d.get(k, 0)) + n

static func run(days: int = DAYS) -> Dictionary:
	var earned: Dictionary = {}
	var coins: Dictionary = {}
	var by_day: Dictionary = {}
	# Lambdas capture plain locals by value, so the running numbers live in one dictionary.
	var st: Dictionary = {"balance": 0, "lost": 0, "season_points": 0, "season_claimed": 0}
	var spent: int = 0
	var bought: int = 0
	var floors: int = 0
	var trip: Dictionary = Expeditions.plan_for(TRIP_HOURS)
	var rewards: Array = SeasonPath.rewards()
	var pay := func(src: String, n: int) -> void:
		var got: int = mini(n, maxi(0, Waymarks.CAP - int(st.balance)))
		st.lost = int(st.lost) + n - got
		st.balance = int(st.balance) + got
		_add(earned, src, got)
	var season := func(src: String) -> void:
		st.season_points = int(st.season_points) + SeasonPath.points_for(src)
		while int(st.season_claimed) < mini(int(st.season_points) / SeasonPath.per_tier(), SeasonPath.tiers()) and int(st.season_claimed) < rewards.size():
			var r: Dictionary = rewards[int(st.season_claimed)]
			st.season_claimed = int(st.season_claimed) + 1
			pay.call("season_path", int(r.get("waymarks", 0)))
			_add(coins, "season_path", int(r.get("coins", 0)))
	for day: int in range(1, days + 1):
		for i: int in DailyTasks.PER_DAY:
			pay.call("daily_task", DailyTasks.REWARD)
			season.call("daily_task")
		pay.call("daily_bonus", DailyTasks.BONUS)
		if not trip.is_empty():
			var n: int = TRIPS_PER_DAY * Expeditions.max_trips()
			pay.call("expedition", n * int(trip.waymarks))
			_add(coins, "expedition", n * int(trip.coins))
		if day % 7 == 0:
			var week: int = day / 7
			pay.call("weekly", WeeklyChallenge.WAYMARKS)
			season.call("weekly")
			_add(coins, "weekly", WeeklyChallenge.PRIZE)
			for m: Dictionary in Masters.list():
				pay.call("master", Masters.FIRST_WAYMARKS if week == 1 else Masters.WEEKLY_WAYMARKS)
			pay.call("echo_path", EchoPath.CHEST_WAYMARKS)
			for f: int in STAIR_FLOORS:
				if floors >= Gauntlet.FLOORS:
					break
				floors += 1
				pay.call("tower", Gauntlet.SECTION_WAYMARKS if floors % Gauntlet.SECTION == 0 else Gauntlet.FLOOR_WAYMARKS)
				_add(coins, "tower", Gauntlet.BASE_PRIZE + Gauntlet.PRIZE_STEP * (floors - 1))
			var offers: Array[Dictionary] = Exchange.all_offers()
			offers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.price) < int(b.price))
			for o: Dictionary in offers:
				for k: int in int(o.get("stock", 1)):
					if int(st.balance) >= int(o.price):
						st.balance = int(st.balance) - int(o.price)
						spent += int(o.price)
						bought += 1
		if day % MONTH_DAYS == 0:
			pay.call("album", Album.FULL_WAYMARKS)
		if day == 45 and FESTIVALS > 0:
			for s: int in Festival.STAGES.size():
				pay.call("festival", Festival.STAGE_WAYMARKS)
				season.call("festival_stage")
		if day % 30 == 0:
			by_day[day] = int(st.balance)
	var total: int = 0
	for k: String in earned:
		total += int(earned[k])
	return {"days": days, "earned": earned, "total": total, "spent": spent, "bought": bought,
		"balance": int(st.balance), "lost": int(st.lost), "by_day": by_day, "coins": coins, "season_step": int(st.season_claimed),
		"per_day": float(total) / days, "per_week": float(total) * 7.0 / days}

static func report(r: Dictionary) -> String:
	var out: PackedStringArray = ["# Endgame run: %d days" % int(r.days), "", "| Source | Waymarks |", "| --- | --- |"]
	var keys: Array = (r.earned as Dictionary).keys()
	keys.sort()
	for k: Variant in keys:
		out.append("| %s | %d |" % [k, int(r.earned[k])])
	out.append("| **total in** | **%d** |" % int(r.total))
	out.append("| spent at Marla's stand (%d goods) | %d |" % [int(r.bought), int(r.spent)])
	out.append("| lost over the cap | %d |" % int(r.lost))
	out.append("")
	out.append("Per day %.1f, per week %.0f. Balance on day 30/60/90: %s. Season path step %d." % [float(r.per_day), float(r.per_week),
		", ".join((r.by_day as Dictionary).values().map(func(v: Variant) -> String: return str(v))), int(r.season_step)])
	out.append("")
	out.append("| Endgame coins | Coins |")
	out.append("| --- | --- |")
	var ck: Array = (r.coins as Dictionary).keys()
	ck.sort()
	for k: Variant in ck:
		out.append("| %s | %d |" % [k, int(r.coins[k])])
	return "\n".join(out)
