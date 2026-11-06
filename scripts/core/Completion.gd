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
	# The last main goal ("Waiting for the Ferry") has no flag: the story is done once it shows.
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
	var towers: float = float(Gauntlet.best()) / float(Gauntlet.FLOORS)
	if GameState.has_flag("gauntlet_clear"):
		towers = 1.0
	return {
		"story": clampf(story, 0.0, 1.0),
		"side": float(side_done) / float(maxi(1, side_all.size())),
		"spirlog": float(Achievements.stat("bonded")) / float(species),
		"achievements": float(Achievements.unlocked().size()) / float(maxi(1, Achievements.list().size())),
		"towers": clampf(towers, 0.0, 1.0),
		"explore": float(maps) / float(maxi(1, all_maps.size())),
	}

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
