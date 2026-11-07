class_name WeeklyChallenge
extends RefCounted
## Weekly challenge (item 88, plan area 8): every calendar week the same five echo Wayfarers for everyone,
## drawn from a seed made from the week number, so friends can compare runs without any
## server. Each week has a field and a Warden-style rule. The prize can be claimed once a week.

const ROUNDS: int = 5
const TEAM_SIZE: int = 3
const PRIZE: int = 400
## Waymarks for the first full win of the week (plan 3183).
const WAYMARKS: int = 60
## Interim prizes in coins for reaching round 4 and round 5 (wins so far -> coins), once a week.
const INTERIM: Dictionary = {3: 100, 4: 150}
## Weekly board points per round won; all five plus 100 for full health stay within 400.
const POINTS_PER_ROUND: int = 60
## Item prize list (plan 3191): twelve entries with the four power tools.
const REWARDS: Array[String] = ["max_tonic", "spark_charm", "power_brew", "guard_brew", "focus_brew", "dash_brew", "keen_lens", "iron_burr",
	"spark_coil", "bark_wrap", "swift_feather", "kin_charm"]
## Partial win (plan 3195): from round PARTIAL_ROUND on PARTIAL_WAYMARKS, the full WAYMARKS for all five.
const PARTIAL_ROUND: int = 3
const PARTIAL_WAYMARKS: int = 30
## Tries per week that can still win prizes (plan 3196); later tries only count for the best score.
const PRIZE_TRIES: int = 3
## Bonus for a clear with a score under the week's target (plan 3188).
const TARGET_WAYMARKS: int = 20
## Weeks kept in the archive (plan 3190).
const ARCHIVE_WEEKS: int = 8

## Loan-team weeks (plan 3192-3194): every second week everyone fights with the same fixed
## team of three from data/events.json "loan_teams"; the own Spirlings stay at home.
const EVENTS_PATH: String = "res://data/events.json"

static var _loans: Array[Dictionary] = []

var week: String
var rng := RandomNumberGenerator.new()
var field: String
var rule: String
## The week's rule variant (item 799), from its own seed so the other draws stay as they were.
var variant: String = ""
var level: int
## The loan team of this week ({id, ring, team}), empty in a normal week.
var loan: Dictionary = {}

## [param week_key] like "2026-W44"; [param cap_level] is the save's ring cap by story progress
## (GameState.progress_cap()), so everyone at the same point of the story meets the same rings.
func _init(week_key: String, cap_level: int) -> void:
	week = week_key
	rng.seed = hash("chimora-weekly-" + week_key)
	var fields: Array = BattleRules.FIELDS.keys()
	fields.sort()
	field = str(fields[rng.randi_range(0, fields.size() - 1)])
	var rules: Array = BattleRules.RULES.keys().filter(func(r: String) -> bool: return not bool(BattleRules.RULES[r].get("warden_only", false)))
	rules.sort()
	rule = str(rules[rng.randi_range(0, rules.size() - 1)])
	level = clampi(cap_level, 8, Spirling.MAX_LEVEL)
	var picked: Array[String] = BattleRules.draw_variants(hash("chimora-weekly-variant-" + week_key), 1)
	variant = picked[0] if not picked.is_empty() else ""
	if is_loan_week(week_key):
		loan = loan_for(week_key)
		if not loan.is_empty():
			level = int(loan.get("ring", level))

static func loan_teams() -> Array[Dictionary]:
	if _loans.is_empty():
		var f := FileAccess.open(EVENTS_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for t: Variant in (d as Dictionary).get("loan_teams", []):
					if t is Dictionary:
						_loans.append(t)
	return _loans

## Odd ISO weeks are loan-team weeks ("2026-W45" -> 45).
static func is_loan_week(week_key: String) -> bool:
	var parts: PackedStringArray = week_key.split("-W")
	return parts.size() == 2 and int(parts[1]) % 2 == 1 and not loan_teams().is_empty()

## The loan team of week [param week_key], the same for everyone.
static func loan_for(week_key: String) -> Dictionary:
	var all: Array[Dictionary] = loan_teams()
	if all.is_empty():
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-loan-" + week_key)
	return all[r.randi_range(0, all.size() - 1)]

## Fresh Spirlings of the loan team: fixed species, ring and techniques, full health.
func loan_party() -> Array[Spirling]:
	var out: Array[Spirling] = []
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-loan-party-" + week)
	for e: Variant in loan.get("team", []):
		var d: Dictionary = e
		var sd: SpirlingData = Database.species(str(d.get("species", "")))
		if sd == null:
			continue
		var sp := Spirling.new(sd, int(loan.get("ring", level)), r)
		var ms: Array[MoveData] = []
		for m: Variant in d.get("moves", []):
			var md: MoveData = Database.move(str(m))
			if md != null:
				ms.append(md)
		if not ms.is_empty():
			sp.moves = ms
		sp.restore()
		out.append(sp)
	return out

## Board line about this week's mode.
func mode_line() -> String:
	if loan.is_empty():
		return Loc.t("Your own team. Next week everyone gets the same loan team.")
	var names: PackedStringArray = []
	for e: Variant in loan.get("team", []):
		names.append(str((e as Dictionary).get("species", "")))
	return Loc.t("Loan-team week: everyone fights with %s at ring %d.") % [", ".join(names), int(loan.get("ring", level))]

## The echo team for round [param i]; the same for everyone in the same week.
func team(i: int) -> Array[Spirling]:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s-%d" % [week, i])
	var pool: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		var evo_at: int = BalanceSim.evolve_at(sd)
		if level >= BalanceSim.min_level(sd) and not (evo_at > 0 and level >= evo_at):
			pool.append(sd)
	pool.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	var out: Array[Spirling] = []
	for k: int in TEAM_SIZE:
		out.append(Spirling.new(pool[r.randi_range(0, pool.size() - 1)], level, r))
	return out

## Pays the interim prize for [param wins] rounds won if it is due this week. Returns the coins
## paid (0 if none). [param rec] is this week's record (GameState.records["weekly"]).
static func claim_interim(rec: Dictionary, wins: int) -> int:
	if not INTERIM.has(wins):
		return 0
	var paid: Array = rec.get("interim", [])
	if wins in paid:
		return 0
	paid.append(wins)
	rec["interim"] = paid
	GameState.money += int(INTERIM[wins])
	return int(INTERIM[wins])

## Score line after a round (plan 3185): turns, power left and fainted Spirlings.
static func round_text(round_no: int, turns: int, party: Array[Spirling]) -> String:
	var hp: float = 0.0
	var fainted: int = 0
	for s: Spirling in party:
		hp += s.hp_fraction()
		if s.is_fainted():
			fainted += 1
	var pct: int = int(round(100.0 * hp / maxf(1.0, float(party.size()))))
	return Loc.t("Round %d of %d: %d turns, %d%% power left, %d fainted.") % [round_no, ROUNDS, turns, pct, fainted]

## Run score of a full clear (plan 3187), lower is better: every turn counts 10, every
## percent of power lost counts 1. 0 for a run that did not clear all rounds.
static func run_score(wins: int, turns: int, party: Array[Spirling]) -> int:
	if wins < ROUNDS:
		return 0
	var hp: float = 0.0
	for s: Spirling in party:
		hp += s.hp_fraction()
	var pct: int = int(round(100.0 * hp / maxf(1.0, float(party.size()))))
	return turns * 10 + (100 - pct)

## The week's fixed target score (plan 3188): from the seed, between 180 and 260.
static func target(week_key: String) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = hash("chimora-weekly-target-" + week_key)
	return 180 + 10 * r.randi_range(0, 8)

## This week's record, fresh in a new week: {week, best, claimed, tries, partial, score, target_paid}.
static func record_for(week_key: String) -> Dictionary:
	var rec: Dictionary = GameState.records.get("weekly", {})
	if str(rec.get("week", "")) != week_key and not GameState.time_went_back(str(rec.get("week", "")), week_key):
		rec = {"week": week_key, "best": 0, "claimed": false}
	return rec

## Counts a new try; true while it can still win prizes.
static func start_try(rec: Dictionary) -> bool:
	rec["tries"] = int(rec.get("tries", 0)) + 1
	return int(rec.tries) <= PRIZE_TRIES

static func prize_tries_left(rec: Dictionary) -> int:
	return maxi(0, PRIZE_TRIES - int(rec.get("tries", 0)))

## Books a finished run: best rounds, best score (records.weekly_best), partial Waymarks, the
## target bonus and the archive. The full prize stays with the caller. Returns the lines to show.
func finish_run(rec: Dictionary, wins: int, turns: int, party: Array[Spirling], prizes: bool) -> Array[String]:
	var lines: Array[String] = []
	rec["best"] = maxi(int(rec.get("best", 0)), wins)
	var score: int = run_score(wins, turns, party)
	if score > 0:
		var best: int = int(rec.get("score", 0))
		if best == 0 or score < best:
			rec["score"] = score
			GameState.records["weekly_best"] = {"week": week, "score": score}
			lines.append(Loc.t("New best score this week: %d (target %d).") % [score, target(week)])
	if prizes and wins >= PARTIAL_ROUND and not bool(rec.get("partial", false)):
		rec["partial"] = true
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(PARTIAL_WAYMARKS, "weekly")))
	if prizes and score > 0 and score < target(week) and not bool(rec.get("target_paid", false)):
		rec["target_paid"] = true
		lines.append(Loc.t("Under the target score of %d!") % target(week))
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(TARGET_WAYMARKS, "weekly")))
	_archive(rec)
	return lines

## Waymarks still due for the full clear: the partial share was paid already.
static func full_waymarks(rec: Dictionary) -> int:
	return WAYMARKS - (PARTIAL_WAYMARKS if bool(rec.get("partial", false)) else 0)

func _archive(rec: Dictionary) -> void:
	var arch: Array = GameState.records.get("weekly_archive", [])
	arch = arch.filter(func(e: Variant) -> bool: return e is Dictionary and str((e as Dictionary).get("week", "")) != week)
	arch.push_front({"week": week, "field": field, "rule": rule, "best": int(rec.get("best", 0)), "score": int(rec.get("score", 0))})
	GameState.records["weekly_archive"] = arch.slice(0, ARCHIVE_WEEKS)

## Archive screen: the last weeks with field, rule and the own result.
static func archive_text() -> String:
	var arch: Array = GameState.records.get("weekly_archive", [])
	if arch.is_empty():
		return Loc.t("No weekly echo tried yet.")
	var out: PackedStringArray = [Loc.t("The last %d weeks:") % ARCHIVE_WEEKS]
	for e: Variant in arch:
		var d: Dictionary = e
		var res: String = Loc.t("%d of %d rounds") % [int(d.get("best", 0)), ROUNDS]
		if int(d.get("score", 0)) > 0:
			res += ", " + Loc.t("score %d") % int(d.score)
		out.append("%s  %s, %s: %s" % [str(d.get("week", "")), Loc.t(str(BattleRules.FIELDS.get(str(d.get("field", "")), {}).get("label", d.get("field", "")))),
			Loc.t(str(BattleRules.RULES.get(str(d.get("rule", "")), {}).get("label", d.get("rule", "")))), res])
	return "\n".join(out)

## Week preview (plan 3189): field, rule, target and the elements of the first three teams.
func preview_text() -> String:
	var out: PackedStringArray = [Loc.t("This week: %s, rule %s, ring %d.") % [Loc.t(str(BattleRules.FIELDS[field].label)), Loc.t(str(BattleRules.RULES[rule].label)), level],
		Loc.t("Target score: %d (lower is better).") % target(week)]
	if not variant.is_empty():
		out.append(variant_line())
	out.append(mode_line())
	for i: int in 3:
		var els: PackedStringArray = []
		for sp: Spirling in team(i):
			for e: int in sp.data.elements:
				var nm: String = Loc.t(Elements.element_name(e))
				if not nm in els:
					els.append(nm)
		out.append(Loc.t("Echo %d: %s") % [i + 1, ", ".join(els)])
	return "\n".join(out)

## "Rule variant: Glass Blades, Every Spirling has half its Vigor."
func variant_line() -> String:
	var v: Dictionary = BattleRules.variants().get(variant, {})
	return Loc.t("Rule variant: %s. %s") % [Loc.t(str(v.get("label", variant))), Loc.t(str(v.get("text", "")))]

## The variant ids for this week's battles.
func variant_ids() -> Array[String]:
	return [variant] as Array[String] if not variant.is_empty() else [] as Array[String]

func reward_item() -> String:
	return REWARDS[rng.randi_range(0, REWARDS.size() - 1)]

## ISO-8601 week key ("YYYY-Www") for a unix time.
static func week_key(unix: int) -> String:
	var d: Dictionary = Time.get_date_dict_from_unix_time(unix)
	# ISO weekday: Monday 1 .. Sunday 7. Godot: Sunday 0 .. Saturday 6.
	var wd: int = int(d.weekday)
	if wd == 0:
		wd = 7
	# The Thursday of this week decides the ISO year.
	var thursday: int = unix + (4 - wd) * 86400
	var td: Dictionary = Time.get_date_dict_from_unix_time(thursday)
	var jan1: int = Time.get_unix_time_from_datetime_dict({"year": td.year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var day_of_year: int = int((thursday - jan1) / 86400)
	return "%04d-W%02d" % [td.year, day_of_year / 7 + 1]

static func this_week() -> String:
	return week_key(Online.unix_now())
