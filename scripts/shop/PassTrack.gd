class_name PassTrack
extends RefCounted
## The Wayfarer Pass track (Chimora pay2win rebuild, 27 Nov 2026): 30 steps from data/pass_track.json,
## each with a free and a premium reward (premium = an active Wayfarer Pass, offer rg_pass). Pass
## points come from play: every battle won, every bond and every daily task done is reported to the
## server (pass_points_add), which counts it with its own copy of the numbers and a day cap. Rewards
## are taken on the server (pass_claim) and arrive the shop's ways (Riftglass, unlocks, deliveries).
## Same rules: supabase/migrations/20261127140040_pass_track.sql and LocalPassTrack.

const DATA_PATH: String = "res://data/pass_track.json"
const LANES: Array[String] = ["free", "premium"]
## The offer that opens the premium row.
const PASS_OFFER: String = "rg_pass"

static var _data: Dictionary = {}
## Last pass_state from the server ({} until the screen asked).
static var state: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if d is Dictionary:
			_data = d
	return _data

static func tiers() -> Array:
	return data().get("tiers", [])

static func tier_count() -> int:
	return tiers().size()

static func per_tier() -> int:
	return maxi(1, int(data().get("points_per_tier", 100)))

static func day_cap() -> int:
	return int(data().get("day_cap", 400))

static func season_days() -> int:
	return maxi(1, int(data().get("season_days", 30)))

## Points for one play event ("win", "bond", "daily_task"); 0 for anything else.
static func points_for(kind: String) -> int:
	return int((data().get("points", {}) as Dictionary).get(kind, 0))

## The step reached with [param points] (0 to tier_count()).
static func tier_for(points: int) -> int:
	return clampi(points / per_tier(), 0, tier_count())

## Points inside the current step, for the progress bar: [have, need]. At the last step the bar is full.
static func progress(points: int) -> Array[int]:
	if tier_for(points) >= tier_count():
		return [per_tier(), per_tier()]
	return [posmod(points, per_tier()), per_tier()]

## The reward list of step [param tier] (1-based) in [param lane].
static func reward(tier: int, lane: String) -> Array:
	if tier < 1 or tier > tier_count():
		return []
	return (tiers()[tier - 1] as Dictionary).get(lane, [])

## Season number of [param unix] (UTC day): 0 from season_epoch, one more every season_days days.
static func season_of(unix: int) -> int:
	return floori(float(unix / 86400 - epoch_day()) / float(season_days()))

static func epoch_day() -> int:
	var e: PackedStringArray = str(data().get("season_epoch", "2026-01-01")).split("-")
	return int(Time.get_unix_time_from_datetime_dict({"year": int(e[0]), "month": int(e[1]), "day": int(e[2])})) / 86400

## Unix time the season [param season] starts and ends (UTC midnight; the server uses Berlin time).
static func season_start(season: int) -> int:
	return (epoch_day() + season * season_days()) * 86400

static func season_end(season: int) -> int:
	return season_start(season + 1)

static func claimed(st: Dictionary, tier: int, lane: String) -> bool:
	return int(st.get("claimed_" + lane, 0)) & (1 << (tier - 1)) != 0

## Why reward [param tier] / [param lane] cannot be taken in [param st] ("" = it can): not_reached,
## claimed, no_pass (premium row without the pass).
static func block_reason(st: Dictionary, tier: int, lane: String) -> String:
	if tier < 1 or tier > tier_count() or not lane in LANES:
		return "bad_tier"
	if tier_for(int(st.get("points", 0))) < tier:
		return "not_reached"
	if claimed(st, tier, lane):
		return "claimed"
	if lane == "premium" and not bool(st.get("premium", false)):
		return "no_pass"
	return ""

## Every reward that can be taken now, as [tier, lane], step by step, free first.
static func open_claims(st: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for t: int in range(1, tier_count() + 1):
		for lane: String in LANES:
			if block_reason(st, t, lane).is_empty():
				out.append([t, lane])
	return out

## Premium rewards already reached but locked because the pass is missing.
static func locked_premium(st: Dictionary) -> int:
	if bool(st.get("premium", false)):
		return 0
	var n: int = 0
	for t: int in range(1, tier_for(int(st.get("points", 0))) + 1):
		if not claimed(st, t, "premium"):
			n += 1
	return n

## One reward as text: "500 coins, 2x Ring Tonic" (names from the shop catalog, like offer contents).
static func reward_text(grants: Array) -> String:
	var parts: Array[String] = []
	for e: Dictionary in ShopCatalog.contents({"id": "", "grants": grants}):
		parts.append(ShopCatalog.entry_line(e))
	return ", ".join(parts)

# --- Server ------------------------------------------------------------------------------------

static func refresh() -> Dictionary:
	var r: Dictionary = await Online.call_fn("pass_state")
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		state = r.data
	return r

## Takes one reward; bag items, coins and Spirlings are picked up at once (Billing.claim), Riftglass
## and unlocks show with the next shop state.
static func claim(tier: int, lane: String) -> Dictionary:
	var why: String = block_reason(state, tier, lane)
	if not why.is_empty():
		return {"ok": false, "error": why}
	var r: Dictionary = await Online.call_fn("pass_claim", {"p_tier": tier, "p_lane": lane})
	if not r.ok:
		return {"ok": false, "error": "offline" if r.net else str(r.error)}
	var d: Dictionary = r.data if r.data is Dictionary else {}
	if bool(d.get("ok", false)):
		state["claimed_" + lane] = int(state.get("claimed_" + lane, 0)) | (1 << (tier - 1))
		if d.has("balance"):
			Billing.state["balance"] = int(d.balance)
		await Billing.claim()
	return d

## A play event for the pass ("win", "bond", "daily_task"). Only while online: the server counts it
## once (action queue) and caps it; offline play does not fill the pass.
static func note(kind: String) -> void:
	if points_for(kind) <= 0 or Online.state != Online.State.ONLINE:
		return
	Online.send_small("pass_points_add", {"p_kind": kind, "p_amount": 1})
