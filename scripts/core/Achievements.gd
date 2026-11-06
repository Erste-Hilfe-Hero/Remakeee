class_name Achievements
extends RefCounted
## Achievements (item 90, plan area 8). The list lives in data/achievements.json: id, title,
## text, category, Waymark reward, and a counted stat with a goal ("n"). Some come in steps
## (group + tier bronze/silver/gold). Each one is a check on the save state, so old saves earn
## everything they already did the first time they are checked. Unlocked ids are kept in
## GameState.records["achievements"] (id -> unlock date); the Waymark reward is paid once per id
## (records["achievements_paid"]), which also pays old saves their rewards once.

const DATA_PATH: String = "res://data/achievements.json"
const CATEGORIES: Array[String] = ["bond", "battle", "explore", "collect", "events", "challenge"]
const CATEGORY_NAMES: Dictionary = {"bond": "Bonding", "battle": "Battles", "explore": "Exploring",
	"collect": "Collecting", "events": "Events", "challenge": "Challenges"}
const REWARDS: Array[int] = [10, 25, 50, 100]

static var _list: Array[Dictionary] = []

static func list() -> Array[Dictionary]:
	if _list.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for a: Variant in (d as Dictionary).get("achievements", []):
					if a is Dictionary:
						_list.append(a)
	return _list

static func find(id: String) -> Dictionary:
	for a: Dictionary in list():
		if str(a.id) == id:
			return a
	return {}

static func all_spirlings() -> Array[Spirling]:
	var out: Array[Spirling] = []
	out.append_array(GameState.party)
	out.append_array(GameState.storage)
	return out

static func _spirlog_count(key: String) -> int:
	var n: int = 0
	for v: Variant in GameState.spirlog.values():
		if bool((v as Dictionary).get(key, false)):
			n += 1
	return n

static func _rifts() -> int:
	return int(GameState.has_flag("rift_cinder_sealed")) + int(GameState.has_flag("rift_tide_sealed"))

## The current value of [param stat] for the save (see data/achievements.json).
static func stat(name: String) -> int:
	if name.begins_with("flag:"):
		return int(GameState.has_flag(name.substr(5)))
	if name.begins_with("record:"):
		return int(GameState.records.get(name.substr(7), 0))
	if name.begins_with("element_bonded:"):
		# 1 when every species of that element is bonded.
		var e: int = int(Elements.E.get(name.substr(15), -1))
		for sd: SpirlingData in Database.spirlings.values():
			if e in sd.elements and not bool((GameState.spirlog.get(sd.species_name, {}) as Dictionary).get("bonded", false)):
				return 0
		return 1
	if name.begins_with("count_"):
		return int(GameState.records.get(name, 0))
	match name:
		"seen":
			return _spirlog_count("seen")
		"bonded":
			return _spirlog_count("bonded")
		"bonded_wild":
			return int(all_spirlings().any(func(s: Spirling) -> bool: return s.data.species_name != GameState.starter))
		"party_size":
			return GameState.party.size()
		"storage_size":
			return GameState.storage.size()
		"sanctuary_size":
			return GameState.sanctuary.size()
		"max_level":
			var top: int = 0
			for s: Spirling in all_spirlings():
				top = maxi(top, s.level)
			return top
		"level30_count":
			return all_spirlings().filter(func(s: Spirling) -> bool: return s.level >= 30).size()
		"starter_level":
			# The first partner's line: the starter species and every form it unfurls into.
			var line: Array[String] = []
			var sd: SpirlingData = Database.species(GameState.starter) if GameState.starter != "" else null
			while sd != null and not sd.species_name in line:
				line.append(sd.species_name)
				sd = sd.evolves_to
			var lv: int = 0
			for s: Spirling in all_spirlings():
				if s.data.species_name in line:
					lv = maxi(lv, s.level)
			return lv
		"evolved":
			return all_spirlings().filter(func(s: Spirling) -> bool: return BalanceSim.stage(s.data) > 1).size()
		"prism":
			return all_spirlings().filter(func(s: Spirling) -> bool: return s.prism).size()
		"rifts":
			return _rifts()
		"rifts_veteran":
			return _rifts() if GameState.difficulty >= GameState.Difficulty.VETERAN else 0
		"rifts_riftborn":
			return _rifts() if GameState.difficulty == GameState.Difficulty.RIFT_BORN else 0
		"oath_rifts":
			return _rifts() if GameState.iron_oath else 0
		"oath_rifts_veteran":
			return _rifts() if GameState.iron_oath and GameState.difficulty >= GameState.Difficulty.VETERAN else 0
		"oath_rifts_riftborn":
			return _rifts() if GameState.iron_oath and GameState.difficulty == GameState.Difficulty.RIFT_BORN else 0
		"side_goals":
			return int(QuestLog.side_goals_done(GameState.flags))
		"gauntlet_best":
			return Gauntlet.FLOORS if GameState.has_flag("gauntlet_clear") else Gauntlet.best()
		"weekly_wins", "rematch_wins", "daily_tasks_done", "waymarks_total":
			return int(GameState.records.get(name, 0))
		"money":
			return GameState.money
		"maps_visited":
			return (GameState.records.get("maps_visited", []) as Array).size()
		"gear":
			return int(GameState.has_gear("grapple_line")) + int(GameState.has_gear("climbing_pick")) + int(GameState.has_gear("storm_lantern"))
		"festival_gifts":
			# Gift flags are "season_<festival id>_<year>"; count different festivals.
			var seen: Dictionary = {}
			for k: Variant in GameState.flags:
				var key: String = str(k)
				if key.begins_with("season_") and GameState.has_flag(key):
					seen[key.trim_prefix("season_").rsplit("_", true, 1)[0]] = true
			return seen.size()
	push_warning("Achievements: unknown stat '%s'" % name)
	return 0

## True if achievement [param id] is earned by the current save.
static func earned(id: String) -> bool:
	var a: Dictionary = find(id)
	return not a.is_empty() and stat(str(a.stat)) >= int(a.get("n", 1))

## Progress (k, n) for achievements with a count above 1, else [].
static func progress(a: Dictionary) -> Array[int]:
	var n: int = int(a.get("n", 1))
	if n <= 1:
		return []
	return [mini(stat(str(a.stat)), n), n]

static func unlocked() -> Dictionary:
	return GameState.records.get("achievements", {})

## Marks every newly earned achievement, pays Waymark rewards that are still due (also for
## achievements unlocked before rewards existed) and returns the titles of new ones.
static func check() -> Array[String]:
	var have: Dictionary = unlocked().duplicate()
	var paid: Dictionary = (GameState.records.get("achievements_paid", {}) as Dictionary).duplicate()
	var fresh: Array[String] = []
	for a: Dictionary in list():
		var id: String = a.id
		if not have.has(id) and earned(id):
			have[id] = Time.get_date_string_from_unix_time(Online.unix_now())
			fresh.append(str(a.title))
		if have.has(id) and not paid.has(id):
			paid[id] = true
			Waymarks.earn(int(a.get("reward", 0)), "achievement")
	GameState.records["achievements"] = have
	GameState.records["achievements_paid"] = paid
	return fresh

## The achievement titled [param title] (check() returns titles), or {}.
static func by_title(title: String) -> Dictionary:
	for a: Dictionary in list():
		if str(a.title) == title:
			return a
	return {}

## Menu lines: "[x] Title" for each achievement.
static func lines() -> Array[String]:
	var have: Dictionary = unlocked()
	var out: Array[String] = []
	for a: Dictionary in list():
		out.append("%s %s" % ["[x]" if have.has(a.id) else "[ ]", a.title])
	return out

## The info card for one achievement: title, text, progress, reward and date.
static func card(a: Dictionary) -> String:
	var parts: PackedStringArray = [Loc.t(str(a.title)), Loc.t(str(a.text))]
	var p: Array[int] = progress(a)
	if not p.is_empty():
		parts.append(Loc.t("Progress: %d/%d") % [p[0], p[1]])
	parts.append(Loc.t("Reward: %d Waymarks") % int(a.get("reward", 0)))
	var when: String = str(unlocked().get(a.id, ""))
	if when != "":
		parts.append(Loc.t("Earned %s") % when)
	return "\n".join(parts)
