class_name WayfarerThemes
extends RefCounted
## KAMPF_PLAN_1000 items 521-525: every Wayfarer has a theme, an element and a tactic
## (data/wayfarer_themes.json). Wayfarers with their own "tactic" key (field, status, stages) carry
## the arts of that tactic and play it; from Veteran on every Wayfarer's team plays together: the
## lead lays the Resonance field of the team's element, the next ones bring the tactic's arts.

const PATH: String = "res://data/wayfarer_themes.json"
const KINDS: Array[String] = ["field", "status", "stages"]

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data

static func tactics() -> Dictionary:
	return data().get("tactics", {})

## The element most of the base team shares, as an Elements.E key ("EMBER"); the first one seen
## wins a tie. "" for a team without known kinds.
static func element_of(def: Dictionary) -> String:
	var counts: Dictionary = {}
	var order: Array[int] = []
	for e: Variant in TrainerData.team_entries(def, "", -1):
		var sd: SpirlingData = Database.species(str((e as Dictionary).get("species", ""))) if e is Dictionary else null
		if sd == null:
			continue
		for el: int in sd.elements:
			if not counts.has(el):
				order.append(el)
			counts[el] = int(counts.get(el, 0)) + 1
	var best: int = -1
	for el: int in order:
		if best < 0 or int(counts[el]) > int(counts[best]):
			best = el
	return "" if best < 0 else String(Elements.E.keys()[best])

## The tactic id: the npc's "tactic", else the one of its AI profile, else the default.
static func tactic_of(def: Dictionary) -> String:
	var own: String = str(def.get("tactic", ""))
	if tactics().has(own):
		return own
	var by: Dictionary = data().get("profile_tactics", {})
	var p: String = str(def.get("profile", ""))
	if by.has(p):
		return str(by[p])
	return str(data().get("default_tactic", "power"))

static func theme(def: Dictionary) -> Dictionary:
	return {"element": element_of(def), "tactic": tactic_of(def)}

## "Ember, Field tricks" (translated) for the Wayfarer book.
static func label_of(t: Dictionary) -> String:
	var parts: PackedStringArray = []
	if not str(t.get("element", "")).is_empty():
		parts.append(Elements.chart_name(str(t.element)))
	var tac: Dictionary = tactics().get(str(t.get("tactic", "")), {})
	if tac.has("name"):
		parts.append(Loc.t(str(tac.name)))
	return ", ".join(parts)

static func _themed(def: Dictionary) -> bool:
	return not def.has("warden") and not def.has("boss") and not TrainerData.is_wild_horde(def)

## True when the team plays its Veteran synergy (no own team block for that difficulty).
static func veteran_synergy(def: Dictionary, difficulty: int) -> bool:
	return _themed(def) and difficulty >= GameState.Difficulty.VETERAN and not TrainerData.has_block(def, difficulty)

## The art kinds handed to the team, one per Spirling in team order.
static func art_kinds(def: Dictionary, difficulty: int) -> Array:
	if not _themed(def):
		return []
	var tac: Dictionary = tactics().get(tactic_of(def), {})
	if veteran_synergy(def, difficulty):
		return tac.get("veteran_arts", [])
	if def.has("tactic"):
		return tac.get("arts", [])
	return []

## AI weights on top of the profile for a Wayfarer with its own tactic.
static func tune(def: Dictionary) -> Dictionary:
	if not _themed(def) or not def.has("tactic"):
		return {}
	var t: Variant = (tactics().get(tactic_of(def), {}) as Dictionary).get("tune", {})
	return (t as Dictionary).duplicate() if t is Dictionary else {}

## The start line when the tactic is in play (own tactic or Veteran synergy), else "".
static func line(def: Dictionary, difficulty: int) -> String:
	if art_kinds(def, difficulty).is_empty():
		return ""
	return str((tactics().get(tactic_of(def), {}) as Dictionary).get("line", ""))

## True if [param mv] is an art of [param kind].
static func is_kind(mv: MoveData, kind: String) -> bool:
	match kind:
		"field":
			return mv.has_effect(&"set_field")
		"status":
			return mv.kind == MoveData.Kind.STATUS and not mv.status_effect.is_empty()
		"stages":
			if mv.kind != MoveData.Kind.STATUS:
				return false
			for fx: Dictionary in mv.effects:
				if StringName(fx.get("id", "")) == &"stat_change" and bool(fx.get("self", false)) and int(fx.get("amount", 0)) > 0:
					return true
	return false

## The art of [param kind] for [param s]: a field art only of the team's element (the synergy);
## status and stage arts of its own elements first, then the team's, then the first one there is.
static func pick_art(kind: String, s: Spirling, theme_element: String) -> MoveData:
	var want: Array[int] = []
	if kind != "field":
		want.append_array(s.elements())
	var idx: int = Elements.E.keys().find(theme_element)
	if idx >= 0:
		want.append(idx)
	var first: MoveData = null
	for el: int in want:
		for mv: MoveData in Database.moves.values():
			if mv.element == el and is_kind(mv, kind):
				return mv
	if kind == "field":
		return null
	for mv: MoveData in Database.moves.values():
		if is_kind(mv, kind):
			first = mv
			break
	return first

## Puts [param mv] into the kit: a free slot, else the weakest damaging art while three or more
## remain, else the last art that deals no damage.
static func teach(s: Spirling, mv: MoveData) -> void:
	if s.moves.has(mv):
		return
	if s.moves.size() < Spirling.MAX_MOVES:
		s.moves.append(mv)
		return
	var dmg: Array[int] = []
	for i: int in s.moves.size():
		if s.moves[i].is_damaging():
			dmg.append(i)
	var at: int = -1
	if dmg.size() >= 3:
		at = dmg[0]
		for i: int in dmg:
			if s.moves[i].power < s.moves[at].power:
				at = i
	else:
		for i: int in s.moves.size():
			if not s.moves[i].is_damaging():
				at = i
	if at >= 0:
		s.moves[at] = mv

## Hands the tactic's arts to [param team] (called by TrainerData.build_team and rematch_team).
static func apply(def: Dictionary, team: Array[Spirling], difficulty: int) -> void:
	var kinds: Array = art_kinds(def, difficulty)
	if kinds.is_empty():
		return
	var el: String = element_of(def)
	for i: int in mini(kinds.size(), team.size()):
		var mv: MoveData = pick_art(str(kinds[i]), team[i], el)
		if mv != null:
			teach(team[i], mv)
