class_name Achievements
extends RefCounted
## Local achievements (item 90). Each one is a check on the save state, so old saves earn
## everything they already did the first time they are checked. Nothing leaves the device.
## Unlocked ids are kept in GameState.records["achievements"] (id -> unlock date).

const LIST: Array[Dictionary] = [
	{"id": "first_bond", "title": "First Bond", "text": "Bond with a wild Spirling."},
	{"id": "full_team", "title": "Full Team", "text": "Travel with a full team of five Spirlings."},
	{"id": "seen_10", "title": "Field Notes", "text": "See 10 kinds of Spirling."},
	{"id": "bonded_10", "title": "Kindred", "text": "Bond with 10 kinds of Spirling."},
	{"id": "seen_all", "title": "Complete Spirlog", "text": "See every kind of Spirling in Veydal."},
	{"id": "level_30", "title": "Seasoned", "text": "Raise a Spirling to Lv30."},
	{"id": "evolved", "title": "Growing Up", "text": "See a Spirling grow into its next form."},
	{"id": "first_rift", "title": "Mender", "text": "Mend your first Rift."},
	{"id": "both_rifts", "title": "Quiet Valley", "text": "Mend both Rifts of Veydal."},
	{"id": "lamps", "title": "Lamplighter", "text": "Solve the lamp puzzle in Murk Hollow."},
	{"id": "helper", "title": "Good Neighbour", "text": "Finish every side goal."},
	{"id": "tower", "title": "Echo Climber", "text": "Climb the whole lighthouse tower."},
	{"id": "weekly", "title": "Week by Week", "text": "Win a weekly challenge."},
	{"id": "prism", "title": "Odd Colours", "text": "Bond with a shimmering Spirling."},
	{"id": "rich", "title": "Full Purse", "text": "Hold 10000 coins."},
	{"id": "oath", "title": "Oathkeeper", "text": "Mend both Rifts of Veydal under the Iron Oath."},
	{"id": "rematch", "title": "Old Rivals", "text": "Win 5 rematches against Tamers."},
]

static func all_spirlings() -> Array[Spirling]:
	var out: Array[Spirling] = []
	out.append_array(GameState.party)
	out.append_array(GameState.storage)
	return out

## True if achievement [param id] is earned by the current save.
static func earned(id: String) -> bool:
	var seen: int = 0
	var bonded: int = 0
	for v: Variant in GameState.spirlog.values():
		if bool((v as Dictionary).get("seen", false)):
			seen += 1
		if bool((v as Dictionary).get("bonded", false)):
			bonded += 1
	match id:
		"first_bond":
			for s: Spirling in all_spirlings():
				if s.data.species_name != GameState.starter:
					return true
			return false
		"full_team":
			return GameState.party.size() >= GameState.MAX_PARTY
		"seen_10":
			return seen >= 10
		"bonded_10":
			return bonded >= 10
		"seen_all":
			return seen >= Database.spirlings.size()
		"level_30":
			return all_spirlings().any(func(s: Spirling) -> bool: return s.level >= 30)
		"evolved":
			return all_spirlings().any(func(s: Spirling) -> bool: return BalanceSim.stage(s.data) > 1)
		"first_rift":
			return GameState.has_flag("rift_cinder_sealed") or GameState.has_flag("rift_tide_sealed")
		"both_rifts":
			return GameState.has_flag("rift_cinder_sealed") and GameState.has_flag("rift_tide_sealed")
		"lamps":
			return GameState.has_flag("hollow_lamps")
		"helper":
			return QuestLog.side_goals_done(GameState.flags)
		"tower":
			return GameState.has_flag("gauntlet_clear")
		"weekly":
			return int(GameState.records.get("weekly_wins", 0)) > 0
		"prism":
			return all_spirlings().any(func(s: Spirling) -> bool: return s.prism)
		"rich":
			return GameState.money >= 10000
		"oath":
			return GameState.iron_oath and GameState.has_flag("rift_cinder_sealed") and GameState.has_flag("rift_tide_sealed")
		"rematch":
			return int(GameState.records.get("rematch_wins", 0)) >= 5
	return false

static func unlocked() -> Dictionary:
	return GameState.records.get("achievements", {})

## Marks every newly earned achievement and returns their titles (for a message).
static func check() -> Array[String]:
	var have: Dictionary = unlocked().duplicate()
	var fresh: Array[String] = []
	for a: Dictionary in LIST:
		var id: String = a.id
		if not have.has(id) and earned(id):
			have[id] = Time.get_date_string_from_system()
			fresh.append(str(a.title))
	if not fresh.is_empty():
		GameState.records["achievements"] = have
	return fresh

## Menu lines: "[x] Title: text" for each achievement.
static func lines() -> Array[String]:
	var have: Dictionary = unlocked()
	var out: Array[String] = []
	for a: Dictionary in LIST:
		out.append("%s %s" % ["[x]" if have.has(a.id) else "[ ]", a.title])
	return out
