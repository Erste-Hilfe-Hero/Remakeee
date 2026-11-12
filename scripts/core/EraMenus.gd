class_name EraMenus
extends RefCounted
## Menu screen layouts per era (docs/ERA_FEEL_MENUS.md): how the start menu, team, summary,
## satchel, Spirlog, save screen, settings, shop list and world map are built in each of the
## five eras, one table per era in data/era_menus.json. The skin (colours, frames, font) is
## EraFeel; this is the structure. Every function of a screen is there in every era, only
## presented in that era's way (problems()).

const PATH: String = "res://data/era_menus.json"
## The plain list every other menu uses (confirm questions, sub lists).
const LIST: String = "list"
const STYLES: Array[String] = ["text", "icon", "tabbed", "touch", "living"]
const CURSORS: Array[String] = ["arrow", "frame", "glow"]
const PANELS: Array[String] = ["none", "bottom"]
const ANIMS: Array[String] = ["none", "slide"]
## Keys every era's base list sets.
const BASE_KEYS: Array[String] = ["style", "columns", "row_h", "cursor", "icons", "icon_size", "panel", "anim", "backdrop", "wrap"]
## Summary sections; every era shows all four, grouped into its pages or tabs.
const SECTIONS: Array[String] = ["info", "stats", "arts", "marks"]
const SECTION_NAMES: Dictionary[String, String] = {"info": "Info", "stats": "Values", "arts": "Arts", "marks": "Honours"}
## Smallest row a finger hits safely in the touch eras, in screen pixels of that era.
const TOUCH_MIN_ROW: int = 24
## List result when a team row was dragged to another slot (the move is already done).
const DRAG_PICKED: int = -300
## Shortcuts: screens of the start menu the player pinned, kept as story flags.
const QUICK_FLAG: String = "quick_%s"
const QUICK_MAX: int = 4
const WEEKDAYS: Array[String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

static var _cfg: Dictionary = {}

static func config() -> Dictionary:
	if _cfg.is_empty():
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cfg = d
	return _cfg

static func screens() -> Array[String]:
	var out: Array[String] = []
	out.assign(config().get("screens", []))
	return out

## The functions of [param screen] that every era must present.
static func functions(screen: String) -> Array[String]:
	var out: Array[String] = []
	out.assign((config().get("functions", {}) as Dictionary).get(screen, []))
	return out

## The layout of [param screen] in era [param era] (clamped to I-V): the era's base list with
## the screen's own keys on top. An unknown screen (and LIST) gets the base list.
static func layout(era: int, screen: String = LIST) -> Dictionary:
	var e: int = clampi(era, 1, 5)
	var row: Dictionary = (config().get("eras", {}) as Dictionary).get(str(e), {})
	var out: Dictionary = (row.get("base", {}) as Dictionary).duplicate(true)
	var own: Dictionary = (row.get("screens", {}) as Dictionary).get(screen, {})
	for k: Variant in own:
		out[k] = own[k] if not own[k] is Dictionary and not own[k] is Array else own[k].duplicate(true)
	out["era"] = e
	out["screen"] = screen
	return out

## How era [param era] presents [param fn] of [param screen] ("" when it is missing).
static func presents(era: int, screen: String, fn: String) -> String:
	return str((layout(era, screen).get("functions", {}) as Dictionary).get(fn, ""))

## Name of the era's menu style, translated.
static func style_name(era: int) -> String:
	return Loc.t(str(((config().get("eras", {}) as Dictionary).get(str(clampi(era, 1, 5)), {}) as Dictionary).get("name", "")))

## Problems with the table as "kind:era:screen:key". Empty when the table is sound: every era
## sets every base key with a known value, every screen presents every one of its functions,
## the summary shows all four sections, touch rows are large enough, and an era never takes
## back icons, the info panel, the row height or a column of the era before.
static func problems() -> Array[String]:
	var out: Array[String] = []
	for e: int in range(1, 6):
		var row: Dictionary = (config().get("eras", {}) as Dictionary).get(str(e), {})
		var base: Dictionary = row.get("base", {})
		for k: String in BASE_KEYS:
			if not base.has(k):
				out.append("missing:%d:base:%s" % [e, k])
		for pair: Array in [["style", STYLES], ["cursor", CURSORS], ["panel", PANELS], ["anim", ANIMS]]:
			if not str(base.get(pair[0], "")) in (pair[1] as Array):
				out.append("unknown:%d:base:%s" % [e, pair[0]])
		for s: String in screens():
			if not (row.get("screens", {}) as Dictionary).has(s):
				out.append("missing:%d:%s" % [e, s])
				continue
			var l: Dictionary = layout(e, s)
			var fns: Dictionary = l.get("functions", {})
			for fn: String in functions(s):
				if str(fns.get(fn, "")).is_empty() or str(fns.get(fn)) == "none":
					out.append("function:%d:%s:%s" % [e, s, fn])
			if int(l.get("columns", 0)) < 1 or int(l.get("columns", 0)) > 3:
				out.append("columns:%d:%s" % [e, s])
			if str(l.get("style", "")) in ["touch", "living"] and int(l.get("row_h", 0)) < TOUCH_MIN_ROW:
				out.append("touch:%d:%s" % [e, s])
			if e > 1:
				var prev: Dictionary = layout(e - 1, s)
				if int(l.get("row_h", 0)) < int(prev.get("row_h", 0)):
					out.append("lowers:%d:%s:row_h" % [e, s])
				if int(l.get("columns", 0)) < int(prev.get("columns", 0)):
					out.append("lowers:%d:%s:columns" % [e, s])
				for k: String in ["icons", "backdrop"]:
					if bool(prev.get(k, false)) and not bool(l.get(k, false)):
						out.append("loses:%d:%s:%s" % [e, s, k])
				if str(prev.get("panel", "none")) != "none" and str(l.get("panel", "none")) == "none":
					out.append("loses:%d:%s:panel" % [e, s])
		var seen: Array[String] = []
		for page: Variant in layout(e, "summary").get("pages", []):
			for sec: Variant in page as Array:
				seen.append(str(sec))
		for sec: String in SECTIONS:
			if seen.count(sec) != 1:
				out.append("section:%d:summary:%s" % [e, sec])
	return out

# --- Shortcuts -------------------------------------------------------------------

static func _quick_key(label: String) -> String:
	return QUICK_FLAG % label.to_lower().replace(" ", "_")

## The pinned labels among [param labels], in menu order.
static func quick_list(flags: Dictionary, labels: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for l: String in labels:
		if bool(flags.get(_quick_key(l), false)):
			out.append(l)
	return out

## Pins or unpins [param label]; at most QUICK_MAX stay pinned. Returns true when it changed.
static func quick_toggle(flags: Dictionary, label: String, labels: Array[String]) -> bool:
	var key: String = _quick_key(label)
	if bool(flags.get(key, false)):
		flags.erase(key)
		return true
	if quick_list(flags, labels).size() >= QUICK_MAX:
		return false
	flags[key] = true
	return true

# --- Clock and season ------------------------------------------------------------

## "Tuesday 14:05  dusk" from a datetime dictionary and a day phase.
static func clock_text(dt: Dictionary, phase: int) -> String:
	return "%s %02d:%02d  %s" % [Loc.t(WEEKDAYS[clampi(int(dt.get("weekday", 0)), 0, 6)]),
		int(dt.get("hour", 0)), int(dt.get("minute", 0)), Loc.t(DayCycle.phase_name(phase))]

## The clock line of right now, by the device clock.
static func clock_now() -> String:
	return clock_text(Time.get_datetime_dict_from_system(), DayCycle.current())

static func season_name(month: int) -> String:
	match month:
		3, 4, 5:
			return "Spring"
		6, 7, 8:
			return "Summer"
		9, 10, 11:
			return "Autumn"
		_:
			return "Winter"

## Elements of the season page in [param month]: the season's own pair plus [param extra]
## (the running festival's boosted elements).
static func season_elements(month: int, extra: Array[int] = []) -> Array[int]:
	var out: Array[int] = []
	for name: Variant in (config().get("seasons", {}) as Dictionary).get(season_name(month), []):
		if Elements.E.has(str(name)):
			out.append(int(Elements.E[str(name)]))
	for e: int in extra:
		if not e in out:
			out.append(e)
	return out

## True when [param sd] carries one of [param elements] (the season page of the Spirlog).
static func in_season(sd: SpirlingData, elements: Array[int]) -> bool:
	for e: int in sd.elements:
		if e in elements:
			return true
	return false

## Metres from a height text such as "0.4 m" (0 when it has no number).
static func height_m(text: String) -> float:
	var num: String = ""
	for ch: String in text:
		if ch.is_valid_int() or (ch == "." and not num.is_empty()):
			num += ch
		elif ch == "," and not num.is_empty():
			num += "."
		elif not num.is_empty():
			break
	return num.to_float() if not num.is_empty() else 0.0

static func wayfarer_height() -> float:
	return float(config().get("wayfarer_height_m", 1.6))

## "0.4 m beside you (1.6 m)": the size compare as words, for the eras that show no picture.
static func size_line(sd: SpirlingData) -> String:
	return Loc.t("Size: %s beside you (%s m)") % [sd.height, ("%.1f" % wayfarer_height())]

# --- Summary ---------------------------------------------------------------------

## The marks a Spirling has earned (the ribbon page): {id, name, text}.
static func marks(s: Spirling, leader: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if leader:
		out.append({"id": "leader", "name": "Lead mark", "text": "Walks at the head of the team."})
	if not GleamRules.mark(s).is_empty():
		out.append({"id": "gleam", "name": "Gleam mark", "text": "A rare Gleam. People will pay for that, or worse."})
	if s.favorite:
		out.append({"id": "favourite", "name": "Heart mark", "text": "Your favourite. Do not tell the others."})
	for ring: int in [50, 25, 10]:
		if s.level >= ring:
			out.append({"id": "ring%d" % ring, "name": "Ring %d mark" % ring, "text": "Grew past Ring %d at your side." % ring})
			break
	if s.earlier_form() != null:
		out.append({"id": "unfurled", "name": "Unfurl mark", "text": "Has unfurled into a later form."})
	if not s.held.is_empty():
		out.append({"id": "keepsake", "name": "Bearer mark", "text": "Carries a keepsake for you."})
	if s.met_ring > 0 and s.level - s.met_ring >= 10:
		out.append({"id": "loyal", "name": "Long road mark", "text": "Ten Rings and more since you met."})
	return out

## The text of one summary section of [param s].
static func summary_section(s: Spirling, key: String, leader: bool = false) -> String:
	var lines: PackedStringArray = []
	match key:
		"info":
			var els: PackedStringArray = []
			for e: int in s.elements():
				els.append(Elements.element_name(e))
			lines.append("%s  (%s)" % [s.display_name(), s.data.species_name])
			lines.append("%s   %s" % ["/".join(els), Loc.t("Ring %d" % s.level)])
			if not s.origin_map.is_empty():
				lines.append(Loc.t("Met in %s at Ring %d") % [Loc.t(Spirling.place_name(s.origin_map)), maxi(s.met_ring, 1)])
			var tm: Dictionary = s.temperament()
			lines.append(Loc.t("Temperament: %s" % tm.label) + "\n" + Loc.t(str(tm.text)))
			var tr: Dictionary = BattleRules.trait_info(s.gift_id())
			lines.append(Loc.t("Gift: %s" % tr.label) + "\n" + Loc.t(str(tr.text)) if not tr.is_empty() else Loc.t("No gift."))
			if not s.held.is_empty():
				var it: Dictionary = Database.item(s.held)
				lines.append(Loc.t("Keepsake: %s" % it.get("name", s.held)) + "\n" + Loc.t(str(it.get("description", ""))))
			else:
				lines.append(Loc.t("No keepsake."))
		"stats":
			lines.append("%s  %s" % [s.display_name(), Loc.t("Ring %d" % s.level)])
			lines.append(Loc.t("Vigor %d/%d" % [s.hp, s.max_hp()]) + ("  " + Loc.t("worn out") if s.is_fainted() else ""))
			lines.append(Loc.t("Growth to next ring %d" % s.xp_to_next()))
			lines.append(Loc.t("Might %d" % s.atk()))
			lines.append(Loc.t("Guard %d" % s.def()))
			lines.append(Loc.t("Focus %d" % s.foc()))
			lines.append(Loc.t("Pace %d" % s.spd()))
		"arts":
			lines.append(Loc.t("Arts of %s" % s.display_name()))
			for mv: MoveData in s.moves:
				var power: String = "-" if mv.power <= 0 else str(mv.power)
				lines.append("%s\n  %s  %s  %s" % [Loc.t(mv.move_name), Loc.t(Elements.element_name(mv.element)),
					Loc.t("Power %s" % power), Loc.t("Energy %d" % mv.energy_cost)])
		"marks":
			var ms: Array[Dictionary] = marks(s, leader)
			lines.append(Loc.t("Honours (%d)") % ms.size())
			if ms.is_empty():
				lines.append(Loc.t("No honours yet. They come with the road."))
			for m: Dictionary in ms:
				lines.append("%s: %s" % [Loc.t(str(m.name)), Loc.t(str(m.text))])
	return "\n".join(lines)

## The summary pages of [param s] in era [param era]: the era's page grouping, each page the
## texts of its sections. Era I has two pages, Era II three, the tabbed eras one per section.
static func summary_pages(s: Spirling, era: int, leader: bool = false) -> Array[String]:
	var out: Array[String] = []
	for page: Variant in layout(era, "summary").get("pages", []):
		var parts: PackedStringArray = []
		for sec: Variant in page as Array:
			parts.append(summary_section(s, str(sec), leader))
		out.append("\n\n".join(parts))
	return out

# --- Save card -------------------------------------------------------------------

## "3:07" hours and minutes of [param seconds].
static func play_time_text(seconds: float) -> String:
	var mins: int = int(seconds / 60.0)
	return "%d:%02d" % [mins / 60, mins % 60]

## The lines of the save card: who, where, how long, how many kinds, and the clock when
## [param clock] is not empty.
static func save_lines(tamer: String, place: String, seconds: float, seen: int, bonded: int, team: int, clock: String = "") -> Array[String]:
	var out: Array[String] = [tamer, Loc.t(place),
		Loc.t("Time on the road %s") % play_time_text(seconds),
		Loc.t("Spirlog %d seen, %d bonded") % [seen, bonded],
		Loc.t("Team %d") % team]
	if not clock.is_empty():
		out.append(clock)
	return out
