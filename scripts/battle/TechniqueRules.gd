class_name TechniqueRules
extends RefCounted
## Battle rules of the art set from KAMPF_PLAN_1000 areas "Elemente und Matchups" and "Techniken".
## The state of one battle lives in a meta Dictionary on the BattleModel, so BattleModel only
## calls in at a few points (who acted, which art was used, a hit's multiplier, a block, a lure,
## the events) and Spirlings carry nothing from one battle into the next.

const META: StringName = &"tech_state"

## Element Resonance (item 85): an ally on the field shares an element with the attacker.
const RESONANCE_MULT: float = 1.05
## Elemental echo (item 116): an ally used a damaging art of the same element earlier this turn,
## so this one gets Energy back. Energy, not damage: a damage bonus on top of Resonance made
## same-element teams end fights before any combo could happen (test_goal_sim, reaction goals).
const ECHO_ENERGY: int = 1
## Prism Skin gift (item 103): a hit of x2 or more lands at three quarters (x2 becomes x1.5).
const PRISM_SKIN_MULT: float = 0.75
## Countercurrent gift (item 104): the element that hit it last now lands at half.
const COUNTERCURRENT_MULT: float = 0.5
## Element Ward keepsake (item 87): halves one hit of x2 or more, then it is spent.
const GUARD_ITEM_MULT: float = 0.5
## Ward Circle (item 115): hits of x2 or more on the warded side land at three quarters.
const WARD_MULT: float = 0.75
const WARD_TURNS: int = 3
## Rolling arts (item 132): each use in a row adds this much, up to BUILD_MAX extra steps.
const BUILD_STEP: float = 0.25
const BUILD_MAX: int = 3
## Late Reply (item 133) and Opening Gambit (item 134).
const PAYBACK_MULT: float = 1.5
const FIRST_STRIKE_MULT: float = 1.3
## Hit series (item 135): 2 to 4 hits; the art's power is the mean of 3 hits.
const HITS_MIN: int = 2
const HITS_MAX: int = 4
const HITS_MEAN: float = 3.0
## Counter (item 126): physical damage taken this turn comes back this many times.
const COUNTER_MULT: float = 1.5
## Lure (item 147): single-target arts of the other side go to the lure for this many turns.
const LURE_TURNS: int = 3
## Shoulder guard (item 148): the shielded ally takes this share of each hit this turn.
const SHOULDER_MULT: float = 0.5
## Afterglow (item 149): max Vigor / AFTERGLOW_DIV on each of the next AFTERGLOW_TURNS turns.
const AFTERGLOW_DIV: int = 16
const AFTERGLOW_TURNS: int = 3
## Still Point (item 151): heals this share, then the user dozes for one turn.
const REST_POINT_HEAL: float = 0.5
## Element shift (item 86): turns the new element holds.
const SHIFT_TURNS: int = 3
## Blast (item 152): allies take this share of what a foe would.
const BLAST_ALLY_SHARE: float = 1.0
## Charged arts (item 125): the first use gathers strength, the next use hits this much harder.
const CHARGE_MULT: float = 2.0
## Time-of-day arts (item 154): default factor at their own time of day (DayCycle phase).
const DAYTIME_MULT: float = 1.5
## Element training (item 112): the spark chance after a win doubles for a Spirling whose element
## the field in play boosts.
const FIELD_SPARK_MULT: float = 2.0
const DAYTIME_LINES: Dictionary[String, String] = {"DAWN": "x%s power at dawn.", "DAY": "x%s power by day.",
	"DUSK": "x%s power at dusk.", "NIGHT": "x%s power at night."}

static func state(model: BattleModel) -> Dictionary:
	if not model.has_meta(META):
		model.set_meta(META, {"acted": {}, "streak": {}, "used": [], "last_hit": {}, "brace": {},
			"lure": [{}, {}], "shoulder": {}, "phys": {}, "last_stage": [{}, {}], "ward": [0, 0], "hits": {}, "blast": {},
			"charge": {}, "charging": {}, "charged_hit": {}})
	return model.get_meta(META)

static func _effect(mv: MoveData, id: StringName) -> Dictionary:
	for fx: Dictionary in mv.effects:
		if StringName(fx.get("id", "")) == id:
			return fx
	return {}

# --- hooks from BattleModel ------------------------------------------------------------------

## A Spirling took its action this turn (any kind). Late Reply and Opening Gambit read it.
static func note_acted(model: BattleModel, a: BattleAction) -> void:
	if a != null and a.actor != null:
		(state(model).acted as Dictionary)[a.actor] = model.turn

## An art was used (after its cost was paid): the streak for rolling arts and the elements the
## side has used this turn (elemental echo).
static func note_move(model: BattleModel, side: int, me: Spirling, mv: MoveData, slot: int = 0) -> void:
	var st: Dictionary = state(model)
	if echoes(model, side, me, mv):
		model.change_energy(side, ECHO_ENERGY, slot)
		say(model, side, slot, "%s picks up the echo and gains %d Energy!", [ECHO_ENERGY])
	var prev: Array = (st.streak as Dictionary).get(me, ["", 0, -9])
	var n: int = int(prev[1]) + 1 if str(prev[0]) == mv.move_name and int(prev[2]) == model.turn - 1 else 0
	st.streak[me] = [mv.move_name, n, model.turn]
	var kept: Array = (st.used as Array).filter(func(u: Dictionary) -> bool: return int(u.turn) == model.turn)
	if mv.is_damaging():
		kept.append({"turn": model.turn, "side": side, "who": me, "element": mv.element})
	st["used"] = kept
	if not _effect(mv, &"charge_up").is_empty():
		var charge: Dictionary = st.charge
		if str(charge.get(me, "")) == mv.move_name:
			charge.erase(me)
			st.charged_hit[me] = model.turn
		else:
			charge[me] = mv.move_name
			st["charging"] = {"side": side, "move": mv.move_name, "turn": model.turn}
			say(model, side, slot, "%s gathers its strength!")

## True if [param target] was already standing and acted earlier this turn.
static func acted_this_turn(model: BattleModel, s: Spirling) -> bool:
	return int((state(model).acted as Dictionary).get(s, -1)) == model.turn

## Extra steps of a rolling art (0 on the first use, then 1, 2, 3).
static func streak(model: BattleModel, me: Spirling, mv: MoveData) -> int:
	var prev: Array = (state(model).streak as Dictionary).get(me, ["", 0, -9])
	return mini(int(prev[1]), BUILD_MAX) if str(prev[0]) == mv.move_name and int(prev[2]) == model.turn else 0

## Multiplier for one hit of [param mv] by [param me] on [param target]. Called once per hit
## from BattleModel._do_move, after the accuracy roll; it may spend a keepsake and says so.
static func hit_mult(model: BattleModel, side: int, slot: int, me: Spirling, target_side: int, t_slot: int, target: Spirling, mv: MoveData) -> float:
	var st: Dictionary = state(model)
	var m: float = resonance_mult(model, side, me)
	if not _effect(mv, &"build_up").is_empty():
		m *= 1.0 + BUILD_STEP * float(streak(model, me, mv))
	if not _effect(mv, &"payback").is_empty() and acted_this_turn(model, target):
		m *= PAYBACK_MULT
	if not _effect(mv, &"first_strike").is_empty() and not acted_this_turn(model, target):
		m *= FIRST_STRIKE_MULT
	m *= dual_ratio(mv, target)
	m *= daytime_mult(model, mv)
	if int((st.charged_hit as Dictionary).get(me, -1)) == model.turn:
		m *= CHARGE_MULT
	if not _effect(mv, &"multi_hit").is_empty():
		var hits: int = model.rng.randi_range(HITS_MIN, HITS_MAX)
		st.hits[me] = hits
		m *= float(hits) / HITS_MEAN
	if int((st.shoulder as Dictionary).get(target, -1)) == model.turn:
		m *= SHOULDER_MULT
		model.emit_event(BattleEvent.Type.TECHNIQUE, _who(model, target_side, t_slot, "An ally takes the brunt for %s!"))
	var eff: float = DamageCalc.effectiveness(target, mv)
	if eff >= 2.0:
		var gifts: Dictionary = ShopEffects.gift_table(target)
		if gifts.has("super_taken"):
			m *= float(gifts.super_taken)
			model.reveal_trait(target_side, t_slot)
		if int((st.ward as Array)[target_side]) > model.turn:
			m *= WARD_MULT
		if bool(BattleRules.held_info(target.held).get("super_guard", false)):
			m *= GUARD_ITEM_MULT
			var d: Dictionary = _who(model, target_side, t_slot, "%s's %s takes the edge off the hit!")
			d["args"] = [d.name, str(Database.item(target.held).get("name", target.held))]
			target.held = ""
			model.emit_event(BattleEvent.Type.TECHNIQUE, d)
	if bool(ShopEffects.gift_table(target).get("countercurrent", false)) and int((st.last_hit as Dictionary).get(target, -1)) == mv.element:
		m *= COUNTERCURRENT_MULT
		model.reveal_trait(target_side, t_slot)
	if mv.is_damaging():
		st.last_hit[target] = mv.element
	return m

## Element Resonance: x1.05 while an ally beside [param me] shares one of its elements.
static func resonance_mult(model: BattleModel, side: int, me: Spirling) -> float:
	for s: int in model.standing_slots(side):
		var ally: Spirling = model.active_spirling(side, s)
		if ally == me:
			continue
		for e: int in ally.elements():
			if e in me.elements():
				return RESONANCE_MULT
	return 1.0

## Elemental echo: true when an ally already used a damaging art of the same element this turn.
static func echoes(model: BattleModel, side: int, me: Spirling, mv: MoveData) -> bool:
	if not mv.is_damaging():
		return false
	for u: Dictionary in state(model).used:
		if int(u.turn) == model.turn and int(u.side) == side and u.who != me and int(u.element) == mv.element:
			return true
	return false

## Brace: true when [param target] stands braced this turn; the art bounces off with a line.
static func blocks_hit(model: BattleModel, target_side: int, t_slot: int, target: Spirling, mv: MoveData) -> bool:
	# A charged art only gathers strength on its first use (item 125): no hit this turn.
	var ch: Dictionary = state(model).charging
	if int(ch.get("turn", -1)) == model.turn and int(ch.get("side", -1)) == BattleModel.other(target_side) and str(ch.get("move", "")) == mv.move_name:
		return true
	if not reaches_foe(mv):
		return false
	var b: Dictionary = (state(model).brace as Dictionary).get(target, {})
	if int(b.get("turn", -1)) != model.turn:
		return false
	model.emit_event(BattleEvent.Type.TECHNIQUE, _who(model, target_side, t_slot, "%s braces and the art glances off!"))
	return true

## True for an art that does something to the foe (damage, a status, a foe stage); Brace stops
## only these, never an art the user casts on its own side.
static func reaches_foe(mv: MoveData) -> bool:
	if mv.is_damaging():
		return true
	for fx: Dictionary in mv.effects:
		var id: StringName = StringName(fx.get("id", ""))
		if id in [&"inflict_status", &"element_shift", &"energy_tax", &"energy_burn", &"heal_block", &"energy_drain", &"stage_steal"]:
			return true
		if id == &"stat_change" and not bool(fx.get("self", true)):
			return true
	return false

## Emits one TECHNIQUE line about the Spirling in [param slot]: [param text] % ([name] + args).
static func say(model: BattleModel, side: int, slot: int, text: String, args: Array = []) -> void:
	var d: Dictionary = _who(model, side, slot, text)
	(d.args as Array).append_array(args)
	model.emit_event(BattleEvent.Type.TECHNIQUE, d)

## Lure: the slot a single-target art of [param side] is drawn to, or [param target_slot].
static func lured_slot(model: BattleModel, side: int, target_slot: int) -> int:
	var foe: int = BattleModel.other(side)
	var l: Dictionary = (state(model).lure as Array)[foe]
	if l.is_empty() or int(l.until) < model.turn:
		return target_slot
	var s: Spirling = model.active_spirling(foe, int(l.slot)) if int(l.slot) < model.slot_count(foe) else null
	if s != l.who or not model.is_standing(s):
		return target_slot
	return int(l.slot)

## Watches the event stream for Counter (physical damage taken) and Borrowed Stance (stage moves).
static func observe(model: BattleModel, e: BattleEvent) -> void:
	if e.type == BattleEvent.Type.DAMAGE and e.data.has("move"):
		var mv: MoveData = Database.move(str(e.data.move))
		var who: Spirling = model.active_spirling(int(e.data.get("side", 0)), int(e.data.get("slot", 0)))
		if mv != null and who != null and mv.kind == MoveData.Kind.PHYSICAL:
			var p: Dictionary = (state(model).phys as Dictionary).get(who, {})
			var before: int = int(p.get("amount", 0)) if int(p.get("turn", -1)) == model.turn else 0
			state(model).phys[who] = {"turn": model.turn, "amount": before + int(e.data.get("amount", 0))}
		if mv != null:
			var key: String = "%d:%d" % [1 - int(e.data.get("side", 0)), mv.element]
			var es: Dictionary = state(model).get("elem_dmg", {})
			es[key] = int(es.get(key, 0)) + int(e.data.get("amount", 0))
			state(model)["elem_dmg"] = es
	elif e.type == BattleEvent.Type.STAT_CHANGED and int(e.data.get("delta", 0)) != 0:
		(state(model).last_stage as Array)[int(e.data.get("side", 0))] = {"stat": str(e.data.stat), "delta": int(e.data.delta)}

## Physical damage [param s] took this turn (Counter).
static func phys_taken(model: BattleModel, s: Spirling) -> int:
	var p: Dictionary = (state(model).phys as Dictionary).get(s, {})
	return int(p.get("amount", 0)) if int(p.get("turn", -1)) == model.turn else 0

## The hits a hit-series art rolled on its last use (0 if none).
static func hits_of(model: BattleModel, s: Spirling) -> int:
	return int((state(model).hits as Dictionary).get(s, 0))

static func _who(model: BattleModel, side: int, slot: int, text: String) -> Dictionary:
	var s: Spirling = model.active_spirling(side, slot)
	var n: String = s.display_name() if s != null else ""
	return {"side": side, "slot": slot, "name": n, "text": text, "args": [n]}

## Info card line for one of the effects above ("" for any other effect).
static func info_line(fx: Dictionary) -> String:
	var amount: float = float(fx.get("amount", 0.0))
	match StringName(fx.get("id", "")):
		&"brace":
			return Loc.t("Foe arts glance off it this turn. Fails if used twice in a row.")
		&"force_out":
			return Loc.t("In a Wayfarer duel the target is knocked back to its bench.")
		&"counter":
			return Loc.t("Pays back the physical damage it took this turn, x%s.") % String.num(amount if amount > 0.0 else COUNTER_MULT, 1)
		&"heal_ally":
			return Loc.t("Heals the most hurt ally by %d%% of its Vigor.") % roundi((amount if amount > 0.0 else 0.4) * 100.0)
		&"team_stage":
			var stat: String = Loc.t(BattleEvent.STAT_NAMES.get(str(fx.get("stat", "def")), ""))
			return Loc.t("Raises the %s of its whole side on the field by %d.") % [stat, maxi(1, int(amount))]
		&"clear_drops":
			return Loc.t("Clears its own lowered stats.")
		&"build_up":
			return Loc.t("Used in a row it hits %d%% harder each time, up to %d times.") % [roundi(BUILD_STEP * 100.0), BUILD_MAX]
		&"payback":
			return Loc.t("x%s power if the target acted first this turn.") % String.num(PAYBACK_MULT, 1)
		&"first_strike":
			return Loc.t("x%s power if the target has not acted yet this turn.") % String.num(FIRST_STRIKE_MULT, 1)
		&"multi_hit":
			return Loc.t("Strikes %d to %d times.") % [HITS_MIN, HITS_MAX]
		&"clear_field":
			return Loc.t("Ends the field in play.")
		&"lure":
			return Loc.t("Draws every single-target foe art to itself for %d turns.") % LURE_TURNS
		&"shoulder":
			return Loc.t("The most hurt ally takes half damage this turn.")
		&"afterglow":
			return Loc.t("The target keeps burning for %d turns.") % AFTERGLOW_TURNS
		&"mirror_stage":
			return Loc.t("Copies the last stat change on the foe's side.")
		&"rest_point":
			return Loc.t("Heals %d%% of its Vigor, then dozes for a turn.") % roundi(REST_POINT_HEAL * 100.0)
		&"blast_allies":
			return Loc.t("Hits its own allies on the field too.")
		&"element_shift":
			return Loc.t("The target counts as the user's element for %d turns.") % SHIFT_TURNS
		&"elem_ward":
			return Loc.t("Very effective hits on its side land softer for %d turns.") % WARD_TURNS
		&"dual_element":
			return Loc.t("Also counts as %s and lands with the better element.") % Elements.chart_name(str(fx.get("element", "")))
		&"reset_target":
			return Loc.t("Sets every stage of the target back to 0.")
		&"charge_up":
			return Loc.t("The first use gathers strength; the next use hits x%s.") % String.num(CHARGE_MULT, 1)
		&"daytime":
			var line: String = DAYTIME_LINES.get(str(fx.get("phase", "NIGHT")), "")
			return "" if line.is_empty() else Loc.t(line) % String.num(amount if amount > 0.0 else DAYTIME_MULT, 1)
	return ""

# --- batch 2: mixed arts, field countdown, element summary ------------------------------------

## A mixed art (item 114, effect "dual_element" with "element"): it lands with whichever of its two
## elements works better on [param target]; this is the factor on top of its first element.
static func dual_ratio(mv: MoveData, target: Spirling) -> float:
	var fx: Dictionary = _effect(mv, &"dual_element")
	if fx.is_empty() or target == null or not Elements.E.has(str(fx.get("element", ""))):
		return 1.0
	var first: float = Elements.multiplier(mv.element, target.elements())
	var second: float = Elements.multiplier(int(Elements.E[str(fx.element)]), target.elements())
	return second / first if second > first and first > 0.0 else 1.0

## Item 122: one turn before a Resonance field runs out, the log says so.
static func field_last_turn(model: BattleModel) -> void:
	var label: String = str(BattleRules.FIELDS.get(model.field, {}).get("label", ""))
	if label.is_empty():
		return
	model.emit_event(BattleEvent.Type.TECHNIQUE, {"side": 0, "slot": 0, "name": "", "text": "The %s will fade after the next turn.", "args": [label]})

## Item 105: damage per element and side so far, "side:element" -> damage.
static func element_damage(model: BattleModel) -> Dictionary:
	return state(model).get("elem_dmg", {})

## Item 105: the element lines for the end of a battle, strongest element first, for [param side].
static func element_summary(model: BattleModel, side: int = 0) -> String:
	var rows: Array = []
	var dmg: Dictionary = element_damage(model)
	for k: String in dmg:
		var parts: PackedStringArray = k.split(":")
		if int(parts[0]) == side and int(dmg[k]) > 0:
			rows.append([int(parts[1]), int(dmg[k])])
	if rows.is_empty():
		return ""
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	var out: PackedStringArray = [Loc.t("Damage by element")]
	for r: Array in rows:
		out.append("%s: %d" % [Elements.element_name(int(r[0])), int(r[1])])
	return "\n".join(out)

## Item 119: a warning tag when [param s] would step in against an element it is weak to: the
## standing foe element with the strongest multiplier on it ("" when nothing beats x1).
static func switch_warning(model: BattleModel, side: int, s: Spirling) -> String:
	var worst: float = 1.0
	var by: int = -1
	var foe: int = BattleModel.other(side)
	for slot: int in model.standing_slots(foe):
		for e: int in model.active_spirling(foe, slot).elements():
			var m: float = Elements.multiplier(e, s.elements())
			if m > worst:
				worst = m
				by = e
	if by < 0:
		return ""
	# Short, so it fits beside the name in the 144 px party picker: "!Ember".
	return "!" + Elements.element_name(by)

# --- batch 3: charged and time-of-day arts, aim hint ------------------------------------------

## Time-of-day art (item 157, effect "daytime" with "phase"): x amount at that DayCycle phase.
## Indoors or with the day cycle off (day_phase -1) it is a plain art.
static func daytime_mult(model: BattleModel, mv: MoveData) -> float:
	var fx: Dictionary = _effect(mv, &"daytime")
	if fx.is_empty() or model.day_phase < 0 or model.day_phase >= DayCycle.Phase.size():
		return 1.0
	if DayCycle.Phase.keys()[model.day_phase] != str(fx.get("phase", "NIGHT")):
		return 1.0
	var amount: float = float(fx.get("amount", 0.0))
	return amount if amount > 0.0 else DAYTIME_MULT

## True while [param me] holds a gathered charge for [param mv] (item 125).
static func is_charged(model: BattleModel, me: Spirling, mv: MoveData) -> bool:
	return str((state(model).charge as Dictionary).get(me, "")) == mv.move_name

## Item 92: the known matchup of [param mv] on [param foe] as a short tag (" x2") for the
## target choice in a battle with several foes. "" for status arts, unknown or plain matchups.
static func aim_tag(foe: Spirling, mv: MoveData) -> String:
	if foe == null or mv == null or not mv.is_damaging():
		return ""
	var tag: String = CommandMenu.matchup_tag(GameState.known_art_multiplier(mv, foe))
	return "" if tag.is_empty() else " " + tag

# --- batch 4: matchup page, element training ----------------------------------------------------

## Item 112: factor on the battle spark chance of [param s]; FIELD_SPARK_MULT when the field in
## play boosts one of its elements, else 1.
static func spark_field_mult(model: BattleModel, s: Spirling) -> float:
	var boost: String = str(BattleRules.FIELDS.get(model.field, {}).get("boost", ""))
	if boost.is_empty() or not Elements.E.has(boost):
		return 1.0
	return FIELD_SPARK_MULT if int(Elements.E[boost]) in s.elements() else 1.0

## Items 81 and 83: the lexicon page of matchups seen in battle, from GameState.known_matchups
## ("element:species" -> factor). One line per attacking element and direction, marked with a
## shape ("+" strong, "-" weak) rather than a colour. Plain matchups are left out.
static func matchup_lines(known: Dictionary) -> Array[String]:
	var by: Dictionary = {}
	for key: String in known:
		var parts: PackedStringArray = key.split(":", false, 1)
		if parts.size() < 2 or not parts[0].is_valid_int():
			continue
		var mult: float = float(known[key])
		if mult < 0.0 or is_equal_approx(mult, 1.0):
			continue
		var mark: String = "+" if mult > 1.0 else "-"
		var row: Array = [int(parts[0]), mark]
		if not by.has(row):
			by[row] = []
		(by[row] as Array).append("%s %s" % [Loc.t(parts[1]), CommandMenu.matchup_tag(mult)])
	var rows: Array = by.keys()
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
	var out: Array[String] = []
	for row: Array in rows:
		var names: Array = by[row]
		names.sort()
		out.append("%s %s: %s" % [row[1], Loc.t(Elements.element_name(int(row[0]))), ", ".join(names)])
	if out.is_empty():
		out.append(Loc.t("No matchups seen yet. Every hit you land is written down here."))
	else:
		out.push_front(Loc.t("+ strong, - weak. Every hit you land is written down here."))
	return out
