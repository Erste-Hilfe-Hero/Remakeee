class_name Goals
extends RefCounted
## The goals screen in tabs (plan area 8, items 3526-3528, 3245): Story, Today, Week,
## Collection and the season Path. Each tab is a block of lines, already translated.

const TABS: Array[String] = ["Story", "Today", "Week", "Collection", "Season path"]

static func _join(blocks: Array) -> String:
	var parts: PackedStringArray = []
	for b: Variant in blocks:
		var text: String = "\n".join(b) if b is Array else str(b)
		if not text.strip_edges().is_empty():
			parts.append(text)
	return "\n\n".join(parts)

## Story: the main goal, open side goals and, after Act I, the postgame list.
static func story() -> String:
	return _join([Loc.t(QuestLog.summary(GameState.flags)), Postgame.lines()])

## Today: find of the day, daily tasks, the wandering merchant and world events, trips.
static func today() -> String:
	var daily: String = DailyFind.hint(GameState.flags)
	var trips: Array[String] = Expeditions.status_lines()
	if not trips.is_empty():
		trips.insert(0, Loc.t("Roaming trips:"))
	return _join([Loc.t(daily) if daily != "" else "", Festival.goal_lines(), WorldEvents.lines(), DailyTasks.lines(), trips])

static func _weekly_line() -> String:
	var rec: Dictionary = GameState.as_dict(GameState.records.get("weekly", {}))
	var week: String = WeeklyChallenge.this_week()
	var best: int = GameState.as_int(rec.get("best", 0)) if str(rec.get("week", "")) == week else 0
	var cleared: bool = str(rec.get("week", "")) == week and GameState.as_bool(rec.get("claimed", false))
	return "%s %s" % ["[x]" if cleared else "[ ]", Loc.t("Weekly echo: best %d of %d this week") % [best, WeeklyChallenge.ROUNDS]]

## Week: weekly echo, Marla's offer of the week, Master Wayfarers and the endless stair.
static func week() -> String:
	var out: Array[String] = [_weekly_line()]
	if Exchange.is_open():
		var left: int = 0
		for o: Dictionary in Exchange.offers():
			left += Exchange.left(o)
		out.append(Loc.t("Marla's crates this week: %d goods left") % left)
		if Exchange.goal_line() != "":
			out.append(Exchange.goal_line())
	if Masters.open():
		var due: int = 0
		for m: Dictionary in Masters.list():
			if Masters.pays_now(str(m.id)):
				due += 1
		out.append(Loc.t("Master Wayfarers who still pay this week: %d of %d") % [due, Masters.list().size()])
	var cp: int = Gauntlet.checkpoint()
	var stair: String = Loc.t("Lighthouse stair: best floor %d of %d") % [Gauntlet.best(), Gauntlet.FLOORS]
	if cp > 0:
		stair += " " + Loc.t("(rest point at floor %d)") % cp
	out.append(stair)
	for t: Dictionary in RiftTower.list():
		if RiftTower.is_open(t):
			out.append(RiftTower.card_lines()[RiftTower.list().find(t) + 1])
	if GameState.has_flag(EchoPath.OPEN_FLAG):
		out.append(EchoPath.goal_line())
	return "\n".join(out)

## Collection: the monthly album, Spirlog goals and the season path.
static func collection() -> String:
	var spirlog: String = Loc.t(Collection.progress_text(GameState.spirlog, Database.spirlings.size()))
	var next: String = Collection.next_text(GameState.spirlog, SpirlogBook.visible_kinds(GameState.flags).size(), GameState.flags)
	if not next.is_empty():
		spirlog += "\n" + Loc.t(next)
	spirlog += "\n" + "\n".join(Collection.set_lines())
	return _join([Album.lines(), spirlog, Loc.t("Journey complete: %d%%") % Completion.percent()])

## Path (plan 3245): the season path with a bar and the next reward.
static func path() -> String:
	return "\n".join(SeasonPath.goal_lines())

static func tab_text(tab: String) -> String:
	match tab:
		"Story": return story()
		"Today": return today()
		"Week": return week()
		"Collection": return collection()
		"Season path": return path()
	return ""

## Every tab in one text (tests, and a quick look).
static func all_text() -> String:
	var parts: PackedStringArray = []
	for t: String in TABS:
		parts.append(tab_text(t))
	return "\n\n".join(parts)
