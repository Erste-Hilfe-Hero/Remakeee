class_name SeasonPath
extends RefCounted
## Free season path (plan area 8): one path per quarter of the year (Jan-Mar, Apr-Jun, Jul-Sep,
## Oct-Dec) with TIERS steps. Path points come only from playing: daily tasks, the weekly echo
## and festival goals. Every step has a fixed reward that is shown before the season starts;
## the same rewards come back every season, so nothing is missed for good. Progress lives in
## GameState.records["season_path"] = {"season": "2026-Q4", "points": n, "claimed": steps}.

const DATA_PATH: String = "res://data/endgame.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = (d as Dictionary).get("season_path", {})
	return _data

static func tiers() -> int:
	return int(data().get("tiers", 30))

static func per_tier() -> int:
	return int(data().get("points_per_tier", 100))

static func rewards() -> Array:
	return data().get("rewards", [])

## Path points for one [param source] ("daily_task", "weekly", "festival_stage").
static func points_for(source: String) -> int:
	return int((data().get("points", {}) as Dictionary).get(source, 0))

## "2026-Q4" by the server clock.
static func season_key() -> String:
	var d: Dictionary = Online.date_now()
	return "%04d-Q%d" % [int(d.year), (int(d.month) - 1) / 3 + 1]

## This season's progress (a new season starts at 0).
static func state() -> Dictionary:
	var st: Dictionary = GameState.as_dict(GameState.records.get("season_path", {}))
	var stored: String = str(st.get("season", ""))
	if stored != season_key() and not GameState.time_went_back(stored, season_key()):
		st = {"season": season_key(), "points": 0, "claimed": 0}
		GameState.records["season_path"] = st
	return st

## Waymarks for every step past the last one (plan 3244): no new cosmetics, just Waymarks.
const EXTRA_STEP_WAYMARKS: int = 20

## Steps reached past the last one this season.
static func extra_steps() -> int:
	return maxi(0, GameState.as_int(state().get("points", 0)) / per_tier() - tiers())

static func tier() -> int:
	return mini(GameState.as_int(state().get("points", 0)) / per_tier(), tiers())

## Adds points from [param source], pays every step reached. Returns the reward lines.
static func add(source: String) -> Array[String]:
	var n: int = points_for(source)
	var lines: Array[String] = []
	if n <= 0:
		return lines
	var st: Dictionary = state()
	st.points = GameState.as_int(st.get("points", 0)) + n
	while GameState.as_int(st.get("claimed", 0)) < tier():
		st.claimed = GameState.as_int(st.claimed) + 1
		lines.append(Loc.t("Season path step %d of %d!") % [int(st.claimed), tiers()])
		lines.append_array(pay(rewards()[int(st.claimed) - 1]))
	while GameState.as_int(st.get("extra", 0)) < extra_steps():
		st["extra"] = GameState.as_int(st.get("extra", 0)) + 1
		lines.append(Loc.t("Season path bonus step %d!") % int(st.extra))
		lines.append_array(Waymarks.reward_lines(Waymarks.earn(EXTRA_STEP_WAYMARKS, "season_path")))
	return lines

static func pay(r: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if int(r.get("coins", 0)) > 0:
		GameState.money += int(r.coins)
		lines.append(Loc.t("+%d coins") % int(r.coins))
	if str(r.get("item", "")) != "":
		GameState.add_item(str(r.item), int(r.get("count", 1)))
		lines.append("%s x%d" % [Loc.t(str(Database.item(str(r.item)).get("name", r.item))), int(r.get("count", 1))])
	lines.append_array(Waymarks.reward_lines(Waymarks.earn(int(r.get("waymarks", 0)), "season_path")))
	return lines

## One line per step for the path screen: "[x] 3  Power Brew x2".
static func lines() -> Array[String]:
	var out: Array[String] = []
	var claimed: int = GameState.as_int(state().get("claimed", 0))
	var rs: Array = rewards()
	for i: int in rs.size():
		out.append("%s %2d  %s" % ["[x]" if i < claimed else "[ ]", i + 1, reward_text(rs[i])])
	return out

static func reward_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(r.get("coins", 0)) > 0:
		parts.append(Loc.t("%d coins") % int(r.coins))
	if str(r.get("item", "")) != "":
		parts.append("%s x%d" % [Loc.t(str(Database.item(str(r.item)).get("name", r.item))), int(r.get("count", 1))])
	if int(r.get("waymarks", 0)) > 0:
		parts.append("%s%d" % [Waymarks.GLYPH, int(r.waymarks)])
	return ", ".join(parts)

## Goals tab (plan 3245): a bar to the next step and what it brings.
static func goal_lines() -> Array[String]:
	var pts: int = GameState.as_int(state().get("points", 0))
	var into: int = pts % per_tier()
	var filled: int = into * 10 / maxi(1, per_tier())
	var out: Array[String] = [title(), "[%s%s] %d/%d" % ["#".repeat(filled), "-".repeat(10 - filled), into, per_tier()]]
	var t: int = tier()
	if t < tiers() and t < rewards().size():
		out.append(Loc.t("Next step: %s") % reward_text(rewards()[t]))
	else:
		out.append(Loc.t("Every further step: %s") % ("%s%d" % [Waymarks.GLYPH, EXTRA_STEP_WAYMARKS]))
	return out

## Title of the path screen: season, points and step.
static func title() -> String:
	var st: Dictionary = state()
	return Loc.t("Season path %s: step %d of %d (%d points)") % [str(st.season), tier(), tiers(), GameState.as_int(st.points)]
