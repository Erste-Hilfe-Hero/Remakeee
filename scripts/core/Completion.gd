class_name Completion
extends RefCounted
## "Journey complete: x%" in the records (plan 3378-3379). Each part counts with a fixed
## weight (docs/BALANCE.md): story 20, side goals 10, Spirlog 25, achievements 20,
## towers 15 and exploring 10 percent.

const WEIGHTS: Dictionary = {"story": 20, "side": 10, "spirlog": 25, "achievements": 20, "towers": 15, "explore": 10}
const PART_NAMES: Dictionary = {"story": "Story", "side": "Side goals", "spirlog": "Spirlog",
	"achievements": "Achievements", "towers": "Towers", "explore": "Exploring"}

## Share of each part between 0.0 and 1.0.
static func parts() -> Dictionary:
	var flags: Dictionary = GameState.flags
	var main: Array = QuestLog.main_goals()
	# The story is done once the last main goal is reached.
	var story: float = 0.0
	if main.size() > 1:
		story = float(QuestLog.current_index(flags)) / float(main.size() - 1)
	var side_all: Array = QuestLog.data().get("side", [])
	var side_done: int = 0
	for g: Variant in side_all:
		if bool(flags.get(str((g as Dictionary).get("done", "")), false)):
			side_done += 1
	var species: int = maxi(1, Database.spirlings.size())
	var maps: int = 0
	var seen: Array = GameState.records.get("maps_visited", []) if GameState.records.get("maps_visited", []) is Array else []
	var all_maps: PackedStringArray = MapData.all_ids()
	for m: String in all_maps:
		if m in seen:
			maps += 1
	var stair: float = float(Gauntlet.best()) / float(Gauntlet.FLOORS)
	if GameState.has_flag("gauntlet_clear"):
		stair = 1.0
	# The stair and the Rift towers count alike.
	var towers: float = stair
	for t: Dictionary in RiftTower.list():
		towers += float(RiftTower.best(t)) / float(RiftTower.floors(t))
	towers /= float(1 + RiftTower.list().size())
	return {
		"story": clampf(story, 0.0, 1.0),
		"side": float(side_done) / float(maxi(1, side_all.size())),
		"spirlog": float(Achievements.stat("bonded")) / float(species),
		"achievements": _badge_share(),
		"towers": clampf(towers, 0.0, 1.0),
		"explore": float(maps) / float(maxi(1, all_maps.size())),
	}

## Badges only reachable during festivals or in the weekly echo do not count (plan 3385).
const EVENT_ONLY_STATS: Array[String] = ["weekly_wins", "festival_gifts", "festivals_all", "record:weekly_flawless"]

static func counts(a: Dictionary) -> bool:
	return not str(a.get("stat", "")) in EVENT_ONLY_STATS

static func _badge_share() -> float:
	var have: Dictionary = Achievements.unlocked()
	var n: int = 0
	var got: int = 0
	for a: Dictionary in Achievements.list():
		if counts(a):
			n += 1
			if have.has(a.id):
				got += 1
	return float(got) / float(maxi(1, n))

## Waymarks at 50, 75 and 100 percent (plan 3382), each paid once and never taken back, even
## when an update adds goals and the percent drops (plan 3386).
const REWARD_STEPS: Dictionary = {50: 50, 75: 100, 100: 300}

## Reward steps reached but not yet paid.
static func unclaimed() -> int:
	var pct: int = percent()
	var paid: Array = GameState.records.get("completion_paid", []) if GameState.records.get("completion_paid") is Array else []
	return REWARD_STEPS.keys().filter(func(s: Variant) -> bool: return pct >= int(s) and not int(s) in paid).size()

## Pays reached reward steps, keeps the percent for the title screen and returns the lines.
static func claim() -> Array[String]:
	var pct: int = percent()
	GameState.records["completion"] = pct
	var paid: Array = GameState.records.get("completion_paid", [])
	var lines: Array[String] = []
	for step: int in REWARD_STEPS:
		if pct >= step and not step in paid:
			paid.append(step)
			lines.append(Loc.t("Journey %d%% complete!") % step)
			lines.append_array(Waymarks.reward_lines(Waymarks.earn(int(REWARD_STEPS[step]), "collection")))
	GameState.records["completion_paid"] = paid
	return lines

## What is still missing (plan 3380): up to three open goals per part.
static func missing() -> Dictionary:
	var flags: Dictionary = GameState.flags
	var out: Dictionary = {}
	var story: Array[String] = []
	if parts().story < 1.0:
		story.append(Loc.t(QuestLog.goal_text(QuestLog.current(flags), flags)))
	out["story"] = story
	var side: Array[String] = []
	for g: Variant in QuestLog.data().get("side", []):
		var gd: Dictionary = g
		var shown: String = str(gd.get("show", ""))
		if not bool(flags.get(str(gd.get("done", "")), false)) and (shown == "" or bool(flags.get(shown, false))) and side.size() < 3:
			side.append(Loc.t(str(gd.get("text", ""))))
	out["side"] = side
	var kinds: Array[String] = []
	for sd: SpirlingData in SpirlogBook.visible_kinds(flags):
		var e: Dictionary = GameState.spirlog.get(sd.species_name, {})
		if bool(e.get("seen", false)) and not bool(e.get("bonded", false)) and kinds.size() < 3:
			kinds.append(Loc.t("Bond with %s") % sd.species_name)
	out["spirlog"] = kinds
	var near: Array[Dictionary] = []
	for a: Dictionary in Achievements.list():
		if counts(a) and not Achievements.unlocked().has(a.id) and not Achievements.is_hidden(a):
			near.append(a)
	var ratio := func(a: Dictionary) -> float: return float(Achievements.stat(str(a.stat))) / float(maxi(1, int(a.get("n", 1))))
	near.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return ratio.call(x) > ratio.call(y))
	var badges: Array[String] = []
	for a: Dictionary in near.slice(0, 3):
		badges.append(Loc.t(str(a.title)) + ": " + Loc.t(str(a.text)))
	out["achievements"] = badges
	var towers: Array[String] = []
	if not GameState.has_flag("gauntlet_clear"):
		towers.append(Loc.t("Lighthouse stair: best floor %d of %d") % [Gauntlet.best(), Gauntlet.FLOORS])
	for t: Dictionary in RiftTower.list():
		if RiftTower.best(t) < RiftTower.floors(t):
			towers.append(Loc.t("%s: best %d of %d") % [Loc.t(str(t.name)), RiftTower.best(t), RiftTower.floors(t)])
	out["towers"] = towers
	var places: Array[String] = []
	var seen: Array = GameState.records.get("maps_visited", []) if GameState.records.get("maps_visited", []) is Array else []
	var left: int = 0
	for m: String in MapData.all_ids():
		if not m in seen:
			left += 1
	if left > 0:
		places.append(Loc.t("%d places not visited yet") % left)
	out["explore"] = places
	return out

## The checklist as lines, part by part.
static func missing_lines() -> Array[String]:
	var m: Dictionary = missing()
	var out: Array[String] = []
	for k: String in WEIGHTS:
		var items: Array = m.get(k, [])
		if items.is_empty():
			continue
		out.append(Loc.t(str(PART_NAMES[k])) + ":")
		for it: Variant in items:
			out.append("  - " + str(it))
	if out.is_empty():
		out.append(Loc.t("Nothing left. Your journey is complete!"))
	return out

## Whole percent, 0..100.
static func percent() -> int:
	var p: Dictionary = parts()
	var total: float = 0.0
	for k: String in WEIGHTS:
		total += float(WEIGHTS[k]) * float(p.get(k, 0.0))
	return clampi(floori(total), 0, 100)

## Records block: the total and one line per part.
static func lines() -> Array[String]:
	var p: Dictionary = parts()
	var out: Array[String] = [Loc.t("Journey complete: %d%%") % percent()]
	for k: String in WEIGHTS:
		out.append("  " + Loc.t("%s: %d%% (counts %d%%)") % [Loc.t(str(PART_NAMES[k])), roundi(100.0 * float(p[k])), int(WEIGHTS[k])])
	return out
