class_name RulesBook
extends RefCounted
## The battle rules page of the lexicon (KAMPF_PLAN items 17-19, 25, 26, 32, 33, 37, 53, 55): every
## rule the battle model follows, with its numbers read from the constants that the model uses,
## so the page can never drift from the game. Always open, nothing has to be collected first.

const PAGES: Array[String] = ["Turn order", "End of a turn", "Energy", "Fields", "Fleeing", "Warden rules", "Story and bosses"]

static func titles() -> Array[String]:
	var out: Array[String] = []
	for t: String in PAGES:
		out.append(Loc.t(t))
	return out

## The lines of page [param i] (an index into PAGES), translated.
static func page(i: int) -> Array[String]:
	match i:
		0: return turn_order()
		1: return end_of_turn()
		2: return energy()
		3: return fields()
		4: return fleeing()
		5: return warden_rules()
		6: return story_and_bosses()
	return []

## The highest priority any art has (moves.json).
static func max_priority() -> int:
	var best: int = 0
	for mv: MoveData in Database.moves.values():
		best = maxi(best, mv.priority)
	return best

static func turn_order() -> Array[String]:
	return [
		Loc.t("Running away comes first, then swaps, items and the Ink Oath, then arts and Rest."),
		Loc.t("Among arts the higher priority goes first. +%d is the most any art has.") % max_priority(),
		Loc.t("At the same priority the higher Pace goes first."),
		Loc.t("At the same Pace a coin decides. The log says who won the toss."),
		Loc.t("A Rift boss acts more than once a turn. Its extra actions come last and show as reverb."),
		Loc.t("An item takes the whole turn of the Spirling that uses it."),
		Loc.t("A Spirling without an order rests. It never picks a random art."),
		Loc.t("Arts that strike every foe never touch your own side."),
	]

static func end_of_turn() -> Array[String]:
	return [
		Loc.t("When every action is done, in this order:"),
		Loc.t("1. Conditions bite (Scorch, Root) and timed ones count down."),
		Loc.t("2. Mending: gifts, keepsakes, the field and Root Mend."),
		Loc.t("3. Energy: +%d for every Spirling in front.") % BattleModel.ENERGY_PER_TURN,
		Loc.t("4. The field: a called field counts down and the place's own comes back."),
		Loc.t("From turn %d on nobody heals, and the long fight costs everyone 1/%d of its Vigor each turn.") % [BattleRules.WEARY_TURN, BattleModel.WEARY_CHIP_DIV],
	]

static func energy() -> Array[String]:
	return [
		Loc.t("Every Spirling starts with %d Energy and holds at most %d.") % [Spirling.START_ENERGY, Spirling.MAX_ENERGY],
		Loc.t("Rest gives +%d Energy on top of the turn's own.") % BattleModel.REST_ENERGY,
		Loc.t("Swapping costs no Energy. Each Spirling keeps its own Energy on the bench."),
		Loc.t("Overcharge arts spend up to %d spare Energy, each point +%d%% power.") % [BattleRules.OVERCHARGE_MAX_EXTRA, roundi(BattleRules.OVERCHARGE_PER_ENERGY * 100.0)],
		Loc.t("Two Overcharge arts in two turns in a row chain for +%d%% more.") % roundi(BattleRules.OVERCHARGE_CHAIN_BONUS * 100.0),
		Loc.t("The foe's Energy shows as pips in its info strip."),
		Loc.t("On Story the foe's Spirlings start with %d Energy less.") % BattleRules.foe_start_cut(GameState.Difficulty.STORY),
		Loc.t("Live duels and leagues use the very same Energy rules."),
	]

static func fields() -> Array[String]:
	var out: Array[String] = []
	for id: String in BattleRules.FIELDS:
		var f: Dictionary = BattleRules.FIELDS[id]
		var parts: Array[String] = [Loc.t("%s: %s arts +%d%%, %s arts -%d%%.") % [Loc.t(str(f.label)),
			Loc.t(Elements.element_name(int(Elements.E[str(f.boost)]))), roundi((BattleRules.FIELD_BOOST - 1.0) * 100.0),
			Loc.t(Elements.element_name(int(Elements.E[str(f.weaken)]))), roundi((1.0 - BattleRules.FIELD_WEAKEN) * 100.0)]]
		if int(f.get("rest_bonus", 0)) > 0:
			parts.append(Loc.t("Rest gives +%d Energy more.") % int(f.rest_bonus))
		if f.has("cheap_element"):
			parts.append(Loc.t("Where it is the place's own field, %s arts cost %d Energy less.") % [
				Loc.t(Elements.element_name(int(Elements.E[str(f.cheap_element)]))), BattleRules.FIELD_COST_CUT])
		for st: Variant in f.get("blocks", []):
			parts.append(Loc.t("Nobody catches %s.") % StatusRules.label(str(st)))
		out.append(" ".join(parts))
	out.append(Loc.t("A called field holds for %d turns.") % BattleRules.RESONANCE_TURNS)
	return out

static func fleeing() -> Array[String]:
	return [
		Loc.t("Leaving a wild battle costs nothing."),
		Loc.t("At equal Pace the first try works %d%% of the time.") % roundi(BattleModel.FLEE_BASE * 100.0),
		Loc.t("Every failed try makes the next one %d%% likelier.") % roundi(BattleModel.FLEE_PER_ATTEMPT * 100.0),
		Loc.t("A faster Spirling slips away more easily."),
		Loc.t("Wayfarers never let you leave."),
	]

## One line per Warden rule label (the Story forms share the label with their harder twin).
static func warden_rules() -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for id: String in BattleRules.RULES:
		var r: Dictionary = BattleRules.RULES[id]
		if seen.has(str(r.label)):
			continue
		seen[str(r.label)] = true
		out.append("%s: %s" % [Loc.t(str(r.label)), Loc.t(str(r.text))])
	return out

static func story_and_bosses() -> Array[String]:
	return [
		Loc.t("On Story the foes land half as many keen hits."),
		Loc.t("On Story Rest also mends %d%% of a Spirling's Vigor.") % roundi(BattleModel.STORY_REST_HEAL * 100.0),
		Loc.t("A Rift boss fight ends after %d turns: the Rift closes again and you can come back.") % BattleModel.BOSS_ROUND_LIMIT,
	]
