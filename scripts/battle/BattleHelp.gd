class_name BattleHelp
extends RefCounted
## The battle guide behind the More button of the battle log (docs/KAMPF_PLAN_1000.md items
## 568 matchup lexicon, 569 stat calculator, 570 battle rules, 583 search, 591 one set of stat
## abbreviations, 597 art kind symbols). Every page is a list of rows {"text", "hint"} so the
## ListPicker can show it on a 144 px screen and the search can run over all of them.

## The one set of stat abbreviations (item 591), the same as the team summary in MenuHost.
const STAT_SHORT: Dictionary[String, String] = {"hp": "VIG", "atk": "MGT", "def": "GRD", "foc": "FOC", "spd": "PCE"}
## Symbol in front of an art's kind (item 597): physical, focus, status.
const KIND_MARK: Dictionary[int, String] = {MoveData.Kind.PHYSICAL: "!", MoveData.Kind.FOCUS: "*", MoveData.Kind.STATUS: "~"}
## Rings ahead the stat calculator looks.
const CALC_STEPS: Array[int] = [1, 5]

static func kind_mark(kind: int) -> String:
	return KIND_MARK.get(kind, "")

# --- Matchups (568) -----------------------------------------------------------------------

## Every matchup learned so far, sorted by element then kind: "Ember on Mossling: x2".
static func matchup_rows(known: Dictionary) -> Array[Dictionary]:
	var keys: Array = known.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var pa: PackedStringArray = str(a).split(":", true, 1)
		var pb: PackedStringArray = str(b).split(":", true, 1)
		return [int(pa[0]), pa[1] if pa.size() > 1 else ""] < [int(pb[0]), pb[1] if pb.size() > 1 else ""])
	var out: Array[Dictionary] = []
	for k: Variant in keys:
		var parts: PackedStringArray = str(k).split(":", true, 1)
		if parts.size() < 2 or int(parts[0]) < 0 or int(parts[0]) >= Elements.E.size():
			continue
		var mult: float = float(known[k])
		var tag: String = CommandMenu.matchup_tag(mult)
		out.append({"text": Loc.t("%s on %s: %s") % [Loc.t(Elements.element_name(int(parts[0]))), parts[1], tag if not tag.is_empty() else "x1"],
			"hint": Loc.t(matchup_word(mult))})
	if out.is_empty():
		out.append({"text": Loc.t("Nothing learned yet."), "hint": Loc.t("Every hit teaches how well an element works on a kind.")})
	return out

static func matchup_word(mult: float) -> String:
	if mult <= 0.0:
		return "No effect at all."
	if mult > 1.0:
		return "Hits hard."
	if mult < 1.0:
		return "Barely lands."
	return "Plain hit."

# --- Battle rules (570) -------------------------------------------------------------------

static func rule_rows() -> Array[Dictionary]:
	return [
		{"text": Loc.t("Energy: start %d, +%d each turn") % [Spirling.START_ENERGY, BattleModel.ENERGY_PER_TURN], "hint": Loc.t("Every art costs Energy. Resting gives +%d.") % BattleModel.REST_ENERGY},
		{"text": Loc.t("Order: first arts, then Pace"), "hint": Loc.t("Arts marked ^ act first. Equal Pace: chance decides.")},
		{"text": Loc.t("Matchups: x2 hard, x.5 weak"), "hint": Loc.t("Learned ones are shown on the arts and under Matchups.")},
		{"text": Loc.t("Keen hit: a rare harder hit"), "hint": Loc.t("Keepsakes can make them more likely.")},
		{"text": Loc.t("Kinds: ! physical, * focus, ~ status"), "hint": Loc.t("Physical arts meet Guard, focus arts meet Focus.")},
		{"text": Loc.t("Fields last %d turns") % BattleRules.RESONANCE_TURNS, "hint": Loc.t("A Resonance art lays a field. It changes which elements hit hard.")},
		{"text": Loc.t("Swapping takes your turn"), "hint": Loc.t("The Spirling that steps in takes the hit.")},
		{"text": Loc.t("Bond and Leave: wild only"), "hint": Loc.t("Against Wayfarers and Wardens you fight to the end.")},
		{"text": Loc.t("Team: up to %d Spirlings") % BattleModel.MAX_PARTY, "hint": Loc.t("A healthy Spirling on the bench can step in on your turn.")},
	]

# --- Stat calculator (569) ----------------------------------------------------------------

## Stats of [param s] now and a few rings ahead: "MGT 34  R13 36  R17 40".
static func stat_rows(s: Spirling) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	var now: Dictionary = stats_at(s, s.level)
	var ahead: Array[int] = []
	for step: int in CALC_STEPS:
		ahead.append(mini(s.level + step, Spirling.LEVEL_SANITY))
	var later: Array[Dictionary] = []
	for lv: int in ahead:
		later.append(stats_at(s, lv))
	for key: String in STAT_SHORT:
		var line: String = "%s %d" % [STAT_SHORT[key], int(now[key])]
		for i: int in ahead.size():
			line += "  R%d %d" % [ahead[i], int(later[i][key])]
		out.append({"text": line, "hint": Loc.t("%s at ring %d and later rings.") % [s.display_name(), s.level]})
	return out

## Stats of [param s] as if it stood at ring [param lv] (the Spirling is left as it was).
static func stats_at(s: Spirling, lv: int) -> Dictionary:
	var keep: int = s.level
	s.level = lv
	var d: Dictionary = {"hp": s.max_hp(), "atk": s.atk(), "def": s.def(), "foc": s.foc(), "spd": s.spd()}
	s.level = keep
	return d

# --- Lexicon entries and search (583) -----------------------------------------------------

static func lexicon_rows(records: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Lexicon.collected(records):
		out.append({"text": Lexicon.title(id), "hint": Lexicon.text(id)})
	return out

## Rows of [param rows] whose text or hint holds [param query] (any case). Empty query: none.
static func search(rows: Array[Dictionary], query: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var q: String = query.strip_edges().to_lower()
	if q.is_empty():
		return out
	for r: Dictionary in rows:
		if (str(r.get("text", "")) + "\n" + str(r.get("hint", ""))).to_lower().contains(q):
			out.append(r)
	return out

## Everything the search looks through.
static func all_rows(known: Dictionary, records: Dictionary, s: Spirling) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(matchup_rows(known))
	out.append_array(rule_rows())
	out.append_array(stat_rows(s))
	out.append_array(lexicon_rows(records))
	return out
