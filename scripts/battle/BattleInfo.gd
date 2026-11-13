class_name BattleInfo
extends RefCounted
## Battle plan areas "Info und Transparenz" and "Bedienung und Komfort" (docs/KAMPF_PLAN_1000.md
## items 563-600 and 603-631): the pure rules behind the log filter, the battle facts page (foe
## arts seen so far, known traits, field and status turns, seed), the turn-order and Energy lines
## of the art card, the per-target preview, the switch list's matchup, the end-of-battle report,
## the remembered art and target and the 1-4 art keys. BattleScene and CommandMenu only show them.

## Log filters in the order a tap on the filter row cycles them (item 565).
const FILTERS: Array[String] = ["all", "hits", "status", "mine", "foe"]
const FILTER_LABELS: Dictionary[String, String] = {
	"all": "Everything", "hits": "Hits", "status": "Status and fields", "mine": "Your side", "foe": "Foe side",
}
## Entries kept for the filtered log; the panel shows the last BattleScene.LOG_KEEP of them.
const ENTRY_KEEP: int = 80

const HIT_TYPES: Array[BattleEvent.Type] = [
	BattleEvent.Type.MOVE_USED, BattleEvent.Type.MISSED, BattleEvent.Type.NO_TARGET, BattleEvent.Type.DAMAGE,
	BattleEvent.Type.HEAL, BattleEvent.Type.FAINTED, BattleEvent.Type.DELAYED_HIT, BattleEvent.Type.REACTION,
	BattleEvent.Type.SNARE_HIT, BattleEvent.Type.HELD_ENDURE,
]
const STATUS_TYPES: Array[BattleEvent.Type] = [
	BattleEvent.Type.STATUS_APPLIED, BattleEvent.Type.STATUS_FAILED, BattleEvent.Type.STATUS_TICK,
	BattleEvent.Type.STATUS_CURED, BattleEvent.Type.STATUS_PREVENTED, BattleEvent.Type.STAT_CHANGED,
	BattleEvent.Type.FIELD, BattleEvent.Type.FIELD_END, BattleEvent.Type.FIELD_NEXT, BattleEvent.Type.FIELD_EXTENDED,
	BattleEvent.Type.ENERGY_TAX, BattleEvent.Type.SNARE_SET, BattleEvent.Type.SNARE_CLEARED,
	BattleEvent.Type.HEAL_BLOCKED, BattleEvent.Type.WEARY, BattleEvent.Type.TRAIT, BattleEvent.Type.RULE,
	BattleEvent.Type.BOSS_PHASE,
]

# --- Log filter (item 565) -------------------------------------------------------------

## "hits", "status" or "other" for the log filter.
static func kind_of(e: BattleEvent) -> String:
	if e.type in HIT_TYPES:
		return "hits"
	if e.type in STATUS_TYPES:
		return "status"
	return "other"

## One log entry: its line, filter kind and side (-1 when it belongs to no side).
static func entry(e: BattleEvent) -> Dictionary:
	return {"text": e.describe(), "kind": kind_of(e), "side": int(e.data.get("side", -1))}

static func passes(en: Dictionary, filter: String) -> bool:
	match filter:
		"hits", "status":
			return str(en.get("kind", "")) == filter
		"mine":
			return int(en.get("side", -1)) == BattleModel.Side.PLAYER
		"foe":
			return int(en.get("side", -1)) == BattleModel.Side.FOE
	return true

## The last [param keep] lines of [param entries] that pass [param filter].
static func filter_lines(entries: Array, filter: String, keep: int) -> Array[String]:
	var out: Array[String] = []
	for en: Dictionary in entries:
		if not str(en.get("text", "")).is_empty() and passes(en, filter):
			out.append(str(en.text))
	while out.size() > keep:
		out.pop_front()
	return out

static func next_filter(filter: String) -> String:
	return FILTERS[(FILTERS.find(filter) + 1) % FILTERS.size()]

static func filter_row(filter: String) -> String:
	return Loc.t("Show: %s (tap for next)") % Loc.t(FILTER_LABELS.get(filter, "Everything"))

# --- Arts the foe has shown (items 566, 567) --------------------------------------------

## Notes an art a foe used, so the facts page can name it. [param seen] maps a foe's party
## index (as text) to the art names, in the order they were first used.
static func note(seen: Dictionary, e: BattleEvent) -> void:
	if e.type != BattleEvent.Type.MOVE_USED or int(e.data.get("side", -1)) != BattleModel.Side.FOE:
		return
	var key: String = str(int(e.data.get("index", -1)))
	var mv: String = str(e.data.get("move", ""))
	if mv.is_empty():
		return
	var list: Array = seen.get(key, [])
	if not mv in list:
		list.append(mv)
	seen[key] = list

## Arts of the foe in party slot [param index] seen so far.
static func seen_arts(seen: Dictionary, index: int) -> Array:
	return seen.get(str(index), [])

## Facts page at the top of the log (items 566, 567, 573-575, 579, 600, 627): every foe on the
## field with its elements, its trait once it showed itself and the arts it used so far; the
## field and its turns left; your statuses with their turns; the ring limit, Bench lessons and
## the battle seed.
static func facts(model: BattleModel, seen: Dictionary) -> String:
	if model == null:
		return ""
	var lines: Array[String] = [Loc.t("Battle facts")]
	for slot: int in model.standing_slots(BattleModel.Side.FOE):
		var s: Spirling = model.active_spirling(BattleModel.Side.FOE, slot)
		if s == null:
			continue
		var els: Array[String] = []
		for el: int in s.elements():
			els.append(Loc.t(Elements.element_name(el)))
		lines.append("%s R%d, %s" % [s.display_name(), s.level, "/".join(els)])
		if s.has_meta("trait_shown"):
			lines.append("  " + Loc.t("Trait: %s") % Loc.t(str(BattleRules.trait_info(s.gift_id()).get("label", "?"))))
		var arts: Array = seen_arts(seen, model.active_index(BattleModel.Side.FOE, slot))
		lines.append("  " + (Loc.t("Arts seen: %s") % ", ".join(arts) if not arts.is_empty() else Loc.t("Arts seen: none yet")))
		if not s.status.is_empty():
			lines.append("  " + Loc.t(StatusRules.label(s.status)))
	for slot: int in model.standing_slots(BattleModel.Side.PLAYER):
		var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER, slot)
		if me != null and not me.status.is_empty():
			lines.append(status_line(me))
	var f: String = field_line(model)
	if not f.is_empty():
		lines.append(f)
	if model.level_cap < Spirling.LEVEL_SANITY:
		lines.append(Loc.t("Ring limit %d") % model.level_cap)
	if model.bench_share > 0.0:
		lines.append(Loc.t("Bench lessons: the bench learns %d%% as much.") % roundi(model.bench_share * 100.0))
	lines.append(Loc.t("Seed %d") % model.battle_seed)
	return "\n".join(lines)

## "Ash Storm, 3 turns left" or "Ash Storm" for a field that holds all battle, "" without one.
static func field_line(model: BattleModel) -> String:
	if model.field.is_empty() or not BattleRules.FIELDS.has(model.field):
		return ""
	var label: String = Loc.t(str(BattleRules.FIELDS[model.field].get("label", model.field)))
	if model.field_turns > 0:
		return Loc.t("Field: %s, %d turns left") % [label, model.field_turns]
	return Loc.t("Field: %s") % label

## Your Spirling's status with the turns it still lasts (when the status counts down).
static func status_line(s: Spirling) -> String:
	var label: String = Loc.t(StatusRules.label(s.status))
	if s.status_turns > 0:
		return Loc.t("%s: %s, %d turns left") % [s.display_name(), label, s.status_turns]
	return "%s: %s" % [s.display_name(), label]

# --- Art card lines (items 571, 572) -----------------------------------------------------

## "first", "after", "even" or "hidden": how [param mv] of [param me] likely ranks against
## [param foe] using a plain art. Same keys as BattleModel._sort_key without the dice.
static func order_hint(model: BattleModel, me: Spirling, foe: Spirling, mv: MoveData) -> String:
	if model == null or me == null or foe == null:
		return "hidden"
	if BattleRules.rule_number(model.foe_rule, "hidden_order") > 0.0:
		return "hidden"
	if mv.priority != 0:
		return "first" if mv.priority > 0 else "after"
	var mine: float = me.effective_spd() * ShopEffects.seal_speed_mult(int(model.seals[BattleModel.Side.PLAYER][2]))
	var theirs: float = foe.effective_spd() * ShopEffects.seal_speed_mult(int(model.seals[BattleModel.Side.FOE][2]))
	if int(mine) == int(theirs):
		return "even"
	return "first" if int(mine) > int(theirs) else "after"

const ORDER_TEXT: Dictionary[String, String] = {
	"first": "Likely acts before the foe.", "after": "Likely acts after the foe.",
	"even": "Same Pace as the foe: chance decides.", "hidden": "Turn order hidden.",
}

## Energy left after using [param mv] now (never below 0).
static func energy_after(me: Spirling, mv: MoveData) -> int:
	return maxi(me.energy - me.move_cost(mv), 0)

## Live lines for the art card of [param mv] used by the Spirling in [param slot].
static func card_lines(model: BattleModel, slot: int, mv: MoveData) -> Array[String]:
	var out: Array[String] = []
	if model == null:
		return out
	var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER, slot)
	if me == null:
		return out
	var foes: Array[int] = model.standing_slots(BattleModel.Side.FOE)
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, foes[0]) if not foes.is_empty() else null
	out.append(Loc.t(ORDER_TEXT[order_hint(model, me, foe, mv)]))
	if me.can_afford(mv):
		out.append(Loc.t("Energy after: %d") % energy_after(me, mv))
	# Miss chance with Daze and the Warden rule, when it is not a sure hit (KAMPF_PLAN item 14).
	var miss: int = miss_pct(model, me, mv, foe)
	if miss > 0:
		out.append(Loc.t("Misses %d%% of the time.") % miss)
	return out

## Chance in percent that [param mv] misses [param foe] right now (0 for a sure hit).
static func miss_pct(model: BattleModel, me: Spirling, mv: MoveData, foe: Spirling = null) -> int:
	if model == null or me == null or mv == null or (not mv.is_damaging() and mv.accuracy >= 1.0):
		return 0
	return roundi((1.0 - model.hit_chance(me, mv, foe)) * 100.0)

# --- Previews in lists (items 563, 625) --------------------------------------------------

## " ~40%" for the per-target damage preview in a battle with several foes, "" when the preview
## is off, the art does no damage or the matchup is not known yet.
static func target_preview(model: BattleModel, me: Spirling, foe: Spirling, mv: MoveData) -> String:
	if model == null or me == null or foe == null or mv == null or not mv.is_damaging():
		return ""
	if not GameState.damage_preview or not ShopEffects.owns_setting("damage_preview"):
		return ""
	if GameState.known_multiplier(mv.element, foe) < 0.0:
		return ""
	return " ~%d%%" % CommandMenu.damage_pct(model, me, foe, mv)

## Best known matchup of [param s]'s damaging arts against [param foe] as a tag (" x2"), for
## the switch list (item 625). "" when nothing is known or it is plain.
static func switch_tag(s: Spirling, foe: Spirling) -> String:
	if s == null or foe == null:
		return ""
	var best: float = -1.0
	for mv: MoveData in s.moves:
		if mv.power <= 0:
			continue
		best = maxf(best, GameState.known_multiplier(mv.element, foe))
	var tag: String = CommandMenu.matchup_tag(best)
	return "" if tag.is_empty() else " " + tag

# --- Remembered art and target (items 603, 615, 613) -------------------------------------

## Row to focus first: [param prefer] (the art used last time) while it is usable, else the
## first usable row, -1 when none is.
static func focus_row(enabled: Array[bool], prefer: int) -> int:
	if prefer >= 0 and prefer < enabled.size() and enabled[prefer]:
		return prefer
	return enabled.find(true)

## Position in [param foes] (standing foe slots) to aim at first: the slot aimed at last time
## while it still stands, else the first.
static func aim_start(foes: Array[int], last: int) -> int:
	var i: int = foes.find(last)
	return i if i >= 0 else 0

## Art row for a number key (1-4, top row or keypad), -1 for any other key.
static func art_key(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_4:
		return keycode - KEY_1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_4:
		return keycode - KEY_KP_1
	return -1

# --- End-of-battle report (item 581) -------------------------------------------------------

static func new_report() -> Dictionary:
	return {"dealt": 0, "taken": 0, "downed": 0, "lost": 0, "keen": 0, "best": 0, "best_art": "", "by": {}}

## Counts [param e] into [param r]. [param last_art] is the player art that was used last,
## [param last_user] the name of the Spirling that used it (damage per Spirling, plan item 20).
static func count(r: Dictionary, e: BattleEvent, last_art: String, last_user: String = "") -> void:
	var side: int = int(e.data.get("side", -1))
	match e.type:
		BattleEvent.Type.DAMAGE:
			var amount: int = int(e.data.get("amount", 0))
			if side == BattleModel.Side.FOE:
				r["dealt"] += amount
				if not last_user.is_empty() and not bool(e.data.get("status_tick", false)):
					var by: Dictionary = r.get("by", {})
					by[last_user] = int(by.get(last_user, 0)) + amount
					r["by"] = by
				if bool(e.data.get("crit", false)):
					r["keen"] += 1
				if amount > int(r.best) and not bool(e.data.get("status_tick", false)):
					r["best"] = amount
					r["best_art"] = last_art
			elif side == BattleModel.Side.PLAYER:
				r["taken"] += amount
		BattleEvent.Type.FAINTED:
			if side == BattleModel.Side.FOE:
				r["downed"] += 1
			elif side == BattleModel.Side.PLAYER:
				r["lost"] += 1

## The report as lines for the log.
static func report_lines(r: Dictionary, turns: int) -> Array[String]:
	var out: Array[String] = [Loc.t("Battle report"),
		Loc.t("Turns: %d") % turns,
		Loc.t("Damage dealt: %d, taken: %d") % [int(r.dealt), int(r.taken)],
		Loc.t("Foes down: %d, yours down: %d") % [int(r.downed), int(r.lost)]]
	if int(r.keen) > 0:
		out.append(Loc.t("Keen hits: %d") % int(r.keen))
	if int(r.best) > 0:
		out.append(Loc.t("Best hit: %d (%s)") % [int(r.best), str(r.best_art)] if not str(r.best_art).is_empty() else Loc.t("Best hit: %d") % int(r.best))
	var star: String = star_of(r)
	if not star.is_empty():
		out.append(Loc.t("Star of the battle: %s") % star)
	return out

## The player's Spirling that dealt the most damage (plan item 20), "" when none hit; a tie
## goes to the one named first.
static func star_of(r: Dictionary) -> String:
	var best: String = ""
	var most: int = 0
	var by: Dictionary = r.get("by", {})
	for k: Variant in by:
		if int(by[k]) > most:
			most = int(by[k])
			best = str(k)
	return best

# --- Tips for new battle parts (items 585, 631) ---------------------------------------------

## Tip id (Tips.LINES) that [param e] introduces the first time, "" for none.
static func tip_for(e: BattleEvent) -> String:
	match e.type:
		BattleEvent.Type.FIELD:
			return "resonance"
		BattleEvent.Type.BOSS_PHASE:
			return "boss_phase"
	return ""
