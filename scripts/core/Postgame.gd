class_name Postgame
extends RefCounted
## Postgame list on the goals screen (plan 3286): once Act I ends ("Waiting for the Ferry")
## every endgame activity shows as a line with a check box and its progress.

static func shown() -> bool:
	return GameState.has_flag(GameState.ACT1_END_FLAG)

static func _weekly_cleared() -> bool:
	var rec: Dictionary = GameState.as_dict(GameState.records.get("weekly", {}))
	return str(rec.get("week", "")) == WeeklyChallenge.this_week() and GameState.as_bool(rec.get("claimed", false))

## One entry per activity: {"text" (translated), "done"}.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var masters: int = Masters.list().size()
	if Masters.open():
		out.append({"text": Loc.t("Beat the Master Wayfarers %d/%d") % [Masters.beaten_count(), masters], "done": Masters.beaten_count() >= masters})
	else:
		out.append({"text": Loc.t("Mend both Rifts to meet the Master Wayfarers"), "done": false})
	out.append({"text": Loc.t("Climb the lighthouse stair: floor %d/%d") % [Gauntlet.best(), Gauntlet.FLOORS], "done": GameState.has_flag("gauntlet_clear") or Gauntlet.best() >= Gauntlet.FLOORS})
	out.append({"text": Loc.t("Clear this week's echo challenge"), "done": _weekly_cleared()})
	out.append({"text": Loc.t("Trade with Marla at the lighthouse"), "done": GameState.has_flag("marla_met")})
	var bonded: int = Achievements.stat("bonded")
	out.append({"text": Loc.t("Bond every Spirling %d/%d") % [bonded, Database.spirlings.size()], "done": bonded >= Database.spirlings.size()})
	out.append({"text": Loc.t("Season path: step %d/%d") % [SeasonPath.tier(), SeasonPath.tiers()], "done": SeasonPath.tier() >= SeasonPath.tiers()})
	var badges: int = Achievements.unlocked().size()
	out.append({"text": Loc.t("Badges %d/%d") % [badges, Achievements.list().size()], "done": badges >= Achievements.list().size()})
	return out

## Goals screen block, or [] before the end of Act I.
static func lines() -> Array[String]:
	var out: Array[String] = []
	if not shown():
		return out
	out.append(Loc.t("After the story:"))
	for e: Dictionary in entries():
		out.append("%s %s" % ["[x]" if bool(e.done) else "[ ]", str(e.text)])
	return out
