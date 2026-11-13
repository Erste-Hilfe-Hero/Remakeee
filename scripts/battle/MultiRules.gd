class_name MultiRules
extends RefCounted
## Multi-Spirling battle extras (docs/KAMPF_PLAN_1000.md, "Mehrfachkämpfe", items 361 to 400):
## support arts (team guard, decoy, cover, ally and team heals), the Wayfarer's formation bonus,
## aim lines with a damage preview per target, the remembered and the automatic target, slot
## lines for screen readers and the stair's double floors. Data in data/multi_rules.json; the
## per-side support state lives in BattleModel.support.

const PATH: String = "res://data/multi_rules.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {"_empty": true}
	return _data

## Typing speed factor of the battle text box (item 372): with several Spirlings a side every
## action's line types faster, so a turn of four actions does not drag. 1.0 in one-on-one.
static func text_speed(m: BattleModel) -> float:
	if m == null or not m.is_multi():
		return 1.0
	return maxf(1.0, float(data().get("text_speed", 1.0)))

static func support_turns(kind: String) -> int:
	return int(data().get("support_turns", {}).get(kind, 2))

# --- Support state ---------------------------------------------------------------------------

## The support entry [param kind] of [param side] ({} when none is up).
static func state(m: BattleModel, side: int, kind: String) -> Dictionary:
	return (m.support[side] as Dictionary).get(kind, {})

## Puts support [param kind] up for [param side] for [param turns] turns (+1: the end of this
## very turn already counts one down) and says so.
static func raise(m: BattleModel, side: int, slot: int, kind: String, turns: int, extra: Dictionary = {}) -> void:
	var entry: Dictionary = {"turns": turns + 1, "slot": slot}
	entry.merge(extra)
	(m.support[side] as Dictionary)[kind] = entry
	var d: Dictionary = m._who(side, slot)
	d.merge({"kind": kind, "turns": turns})
	d.merge(extra)
	if extra.has("covered"):
		d["ally"] = m.active_spirling(side, int(extra.covered)).display_name()
	m.emit_event(BattleEvent.Type.SUPPORT, d)

## Where a single-target art aimed at [param slot] of [param target_side] really lands: a cover
## takes hits meant for its ward, a decoy draws every single-target art (item 379, 380).
static func redirect(m: BattleModel, target_side: int, slot: int) -> int:
	var cover: Dictionary = state(m, target_side, "cover")
	if not cover.is_empty() and int(cover.get("covered", -1)) == slot and _standing(m, target_side, int(cover.slot)):
		return int(cover.slot)
	var decoy: Dictionary = state(m, target_side, "decoy")
	if not decoy.is_empty() and _standing(m, target_side, int(decoy.slot)):
		return int(decoy.slot)
	return slot

## Damage multiplier for hits on [param side] (team guard, item 381).
static func guard_mult(m: BattleModel, side: int) -> float:
	return float(data().get("guard_mult", 0.75)) if not state(m, side, "team_guard").is_empty() else 1.0

## Counts every support down at the end of a turn; the ones that run out say so. A fallen swarm
## leader leaves the rest of the swarm slower.
static func tick(m: BattleModel) -> void:
	_leader_check(m)
	for side: int in 2:
		var sup: Dictionary = m.support[side]
		for kind: String in sup.keys():
			var e: Dictionary = sup[kind]
			e["turns"] = int(e.turns) - 1
			var holder_gone: bool = kind != "team_guard" and not _standing(m, side, int(e.slot))
			if int(e.turns) <= 0 or holder_gone:
				sup.erase(kind)
				m.emit_event(BattleEvent.Type.SUPPORT, {"side": side, "slot": int(e.slot), "kind": kind, "ended": true})

static func _standing(m: BattleModel, side: int, slot: int) -> bool:
	return slot >= 0 and slot < m.slot_count(side) and m.is_standing(m.active_spirling(side, slot))

## The standing ally of [param slot] with the lowest Vigor share, or -1 (item 365).
static func weakest_ally(m: BattleModel, side: int, slot: int) -> int:
	var best: int = -1
	var low: float = 2.0
	for s: int in m.standing_slots(side):
		if s == slot:
			continue
		var f: float = m.active_spirling(side, s).hp_fraction()
		if f < low:
			low = f
			best = s
	return best

## Battle log line of a SUPPORT event.
static func describe(data: Dictionary, who: String) -> String:
	var kind: String = str(data.get("kind", ""))
	if bool(data.get("ended", false)):
		match kind:
			"team_guard": return "The guard over your side fades." if int(data.get("side", 0)) == 0 else "The guard over the foe's side fades."
			"decoy": return "%s stops drawing the foes' aim." % who
			"cover": return "%s stops covering its ally." % who
		return ""
	match kind:
		"team_guard": return "%s raises a guard over its whole side for %d turns!" % [who, int(data.get("turns", 0))]
		"decoy": return "%s draws every aimed art onto itself for %d turns!" % [who, int(data.get("turns", 0))]
		"cover": return "%s steps in front of %s!" % [who, str(data.get("ally", ""))]
		"formation": return "Formation, %s: %s" % [str(data.get("label", "")), who]
		"no_ally": return "%s has nobody to cover." % who
		"leader": return "%s leads the swarm!" % who
		"combo": return "Combo, %s! The art hits %s harder." % [str(data.get("label", "")), who]
		"leader_down": return "With %s down, the swarm falters!" % str(data.get("name", ""))
	return ""

# --- Front and back row (item 367) -----------------------------------------------------------

## True when [param slot] of [param side] stands in the back row (a side of 3 or 4).
static func in_back_row(m: BattleModel, side: int, slot: int) -> bool:
	var front: int = int(data().get("rows", {}).get("front_slots", 2))
	return m.slot_count(side) > front and slot >= front

## Damage multiplier of the rows for one hit of [param mv]: a single-target physical art reaches
## the back row weaker, and an art from the back row hits weaker.
static func row_mult(m: BattleModel, user_side: int, user_slot: int, target_side: int, t_slot: int, mv: MoveData) -> float:
	if mv.kind != MoveData.Kind.PHYSICAL or mv.is_area():
		return 1.0
	var r: Dictionary = data().get("rows", {})
	var x: float = 1.0
	if in_back_row(m, target_side, t_slot):
		x *= float(r.get("back_phys_taken", 1.0))
	if in_back_row(m, user_side, user_slot):
		x *= float(r.get("back_phys_dealt", 1.0))
	return x

# --- Combo arts (items 369, 370) -------------------------------------------------------------

## The combo a hit of [param element] on [param target_side]/[param t_slot] completes this turn
## (an ally of the user hit the same foe with the paired element), or {}. Remembers the hit.
static func combo(m: BattleModel, user_side: int, user_slot: int, target_side: int, t_slot: int, element: int) -> Dictionary:
	if m.slot_count(user_side) < 2:
		return {}
	if int(m.get_meta("combo_turn", -1)) != m.turn:
		m.set_meta("combo_turn", m.turn)
		m.set_meta("combo_hits", {})
	var hits: Dictionary = m.get_meta("combo_hits")
	var key: String = "%d:%d" % [target_side, t_slot]
	var before: Array = hits.get(key, [])
	var found: Dictionary = {}
	for h: Variant in before:
		if int(h[0]) == user_side and int(h[1]) != user_slot:
			for c: Variant in data().get("combos", []):
				var els: Array = (c as Dictionary).get("elements", [])
				var mine: String = Elements.E.find_key(element) if Elements.E.values().has(element) else ""
				var theirs: String = Elements.E.find_key(int(h[2])) if Elements.E.values().has(int(h[2])) else ""
				if mine != theirs and mine in els and theirs in els:
					found = c
	before.append([user_side, user_slot, element])
	hits[key] = before
	return found

static func combo_mult() -> float:
	return float(data().get("combo_mult", 1.25))

# --- Swarm leader (item 368) ------------------------------------------------------------------

## The foe slot leading a wild swarm (the highest ring, the first on ties), or -1.
static func swarm_leader(m: BattleModel) -> int:
	if not m.is_wild or m.slot_count(BattleModel.Side.FOE) < 2:
		return -1
	var best: int = -1
	for s: int in m.slot_count(BattleModel.Side.FOE):
		var sp: Spirling = m.active_spirling(BattleModel.Side.FOE, s)
		if m.is_standing(sp) and (best < 0 or sp.level > m.active_spirling(BattleModel.Side.FOE, best).level):
			best = s
	return best

static func _crown_leader(m: BattleModel) -> void:
	var s: int = swarm_leader(m)
	if s < 0:
		return
	var sw: Dictionary = data().get("swarm", {})
	var lead: Spirling = m.active_spirling(BattleModel.Side.FOE, s)
	lead.set_meta("swarm_leader", true)
	var d: Dictionary = m._who(BattleModel.Side.FOE, s)
	d["kind"] = "leader"
	m.emit_event(BattleEvent.Type.SUPPORT, d)
	for stat: String in sw.get("leader_stage", {"atk": 1}):
		m.change_stage(BattleModel.Side.FOE, stat, int(sw.get("leader_stage", {"atk": 1})[stat]), s)

static func _leader_check(m: BattleModel) -> void:
	for sp: Spirling in m.party(BattleModel.Side.FOE):
		if sp.has_meta("swarm_leader") and sp.is_fainted() and not sp.has_meta("swarm_mourned"):
			sp.set_meta("swarm_mourned", true)
			var sw: Dictionary = data().get("swarm", {})
			m.emit_event(BattleEvent.Type.SUPPORT, {"side": BattleModel.Side.FOE, "slot": -1, "kind": "leader_down", "name": sp.display_name()})
			for s: int in m.standing_slots(BattleModel.Side.FOE):
				for stat: String in sw.get("falter_stage", {"spd": -1}):
					m.change_stage(BattleModel.Side.FOE, stat, int(sw.get("falter_stage", {"spd": -1})[stat]), s)

# --- Formation bonus (item 400) ----------------------------------------------------------------

## The formations the Wayfarer's opening line fills: [{id, label, element, count, stage, slots}].
static func formations(m: BattleModel, side: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if m.slot_count(side) < 2:
		return out
	for f: Variant in data().get("formation", []):
		var el: int = int(Elements.E.get(str((f as Dictionary).get("element", "")), -1))
		var slots: Array[int] = []
		for s: int in m.slot_count(side):
			var sp: Spirling = m.active_spirling(side, s)
			if m.is_standing(sp) and not m.is_partner_slot(side, s) and el in sp.elements():
				slots.append(s)
		if slots.size() >= int((f as Dictionary).get("count", 2)):
			var row: Dictionary = (f as Dictionary).duplicate(true)
			row["slots"] = slots
			out.append(row)
	return out

## Gives the player's opening formation its stages (only the Wayfarer's own Spirlings; a foe
## Wayfarer only with "formation": true, item 399), and a wild swarm its leader (item 368).
static func apply_formation_bonus(m: BattleModel) -> void:
	_crown_leader(m)
	_formation_for(m, BattleModel.Side.PLAYER)
	if m.foe_formation and not m.is_wild:
		_formation_for(m, BattleModel.Side.FOE)

static func _formation_for(m: BattleModel, side: int) -> void:
	for f: Dictionary in formations(m, side):
		for s: int in f.slots:
			var d: Dictionary = m._who(side, s)
			d.merge({"kind": "formation", "label": str(f.label)})
			m.emit_event(BattleEvent.Type.SUPPORT, d)
			for stat: String in f.stage:
				m.change_stage(side, stat, int(f.stage[stat]), s)

# --- Aim, auto aim, screen reader (items 362, 363, 385, 386, 395) -----------------------------

## Line while aiming at [param foe]: name, the expected share of its Vigor and the matchup.
## [param pct] is -1 when the preview is off, [param mult] -1 when the matchup is unknown.
static func aim_line(foe_name: String, pct: int, mult: float) -> String:
	var parts: PackedStringArray = [foe_name]
	if pct >= 0:
		parts.append("~%d%%" % pct)
	var tag: String = CommandMenu.matchup_tag(mult)
	if not tag.is_empty():
		parts.append(tag)
	return " ".join(parts)

## The foe slot to aim at first: the one aimed at last time if it still stands, else the first.
static func default_target(last: int, foes: Array[int]) -> int:
	if foes.is_empty():
		return -1
	return last if last in foes else foes[0]

## The foe slot an automatic aim picks: the most expected damage, ties to the lowest Vigor.
static func best_target(m: BattleModel, me: Spirling, mv: MoveData, side: int = BattleModel.Side.PLAYER) -> int:
	var best: int = -1
	var score: float = -1.0
	for s: int in m.standing_slots(BattleModel.other(side)):
		var foe: Spirling = m.active_spirling(BattleModel.other(side), s)
		var dmg: float = DamageCalc.estimate(me, foe, mv) * BattleRules.damage_mult(me, foe, mv, m.field) if mv.is_damaging() else 0.0
		var share: float = dmg / float(maxi(foe.hp, 1)) + (1.0 - foe.hp_fraction()) * 0.01
		if share > score:
			score = share
			best = s
	return best

## What a screen reader says for a Spirling in a formation slot (item 395).
static func slot_spoken(m: BattleModel, side: int, slot: int) -> String:
	var s: Spirling = m.active_spirling(side, slot)
	if s == null:
		return ""
	var whose: String = Loc.t("Foe") if side == BattleModel.Side.FOE else (Loc.t("Ally") if m.is_partner_slot(side, slot) else Loc.t("Yours"))
	return Loc.t("%s, slot %d of %d: %s, Vigor %d of %d") % [whose, slot + 1, m.slot_count(side), s.display_name(), s.hp, s.max_hp()]

# --- Log filter (item 373) ---------------------------------------------------------------------

## Filter steps of the battle log in multi battles: everything, the player's side, the foes'.
const LOG_MODES: Array[String] = ["All", "Yours", "Foes"]

## The lines of [param lines] (side of each in [param sides], -1 for both) that filter [param mode]
## keeps; lines that belong to no side always stay.
static func filter_log(lines: Array[String], sides: Array[int], mode: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in lines.size():
		var s: int = sides[i] if i < sides.size() else -1
		if mode <= 0 or s < 0 or (mode == 1 and s == BattleModel.Side.PLAYER) or (mode == 2 and s == BattleModel.Side.FOE):
			out.append(lines[i])
	return out

## AI level of a story partner: from Veteran on the partner fights with the master AI (item 387).
static func partner_ai(base: int, difficulty: int) -> int:
	return maxi(base, 3) if difficulty >= GameState.Difficulty.VETERAN else base

# --- Tower (item 374) ------------------------------------------------------------------------

## Field sizes of lighthouse stair floor [param floor_no]: every few floors (not the Warden's) two
## against two, else one against one.
static func tower_front(floor_no: int, warden: bool) -> Array:
	var t: Dictionary = data().get("tower", {})
	var every: int = int(t.get("every", 0))
	if warden or every <= 0 or floor_no % every != 0:
		return [1, 1]
	var n: int = int(t.get("front", 2))
	return [n, n]

# --- AI (item 387) ---------------------------------------------------------------------------

## Extra AI score for a support art effect [param fx] used by [param side]/[param slot].
static func ai_score(m: BattleModel, side: int, slot: int, fx: Dictionary) -> float:
	var id: StringName = StringName(fx.get("id", ""))
	var me: Spirling = m.active_spirling(side, slot)
	var mates: Array[int] = m.standing_slots(side)
	match id:
		&"heal_team":
			var lost: float = 0.0
			for s: int in mates:
				lost += minf(float(fx.get("amount", 0.2)), 1.0 - m.active_spirling(side, s).hp_fraction())
			return 40.0 * lost
		&"heal_ally":
			var w: int = weakest_ally(m, side, slot)
			var f: float = m.active_spirling(side, w).hp_fraction() if w >= 0 else me.hp_fraction()
			return 40.0 * minf(float(fx.get("amount", 0.33)), 1.0 - f) if f < 0.6 else 0.0
		&"team_guard":
			return 6.0 * float(mates.size()) if state(m, side, "team_guard").is_empty() and mates.size() > 1 else 0.0
		&"decoy":
			return 8.0 * me.hp_fraction() if state(m, side, "decoy").is_empty() and mates.size() > 1 else 0.0
		&"cover":
			var w2: int = weakest_ally(m, side, slot)
			if w2 < 0 or not state(m, side, "cover").is_empty():
				return 0.0
			return 12.0 * maxf(0.0, me.hp_fraction() - m.active_spirling(side, w2).hp_fraction())
	return 0.0
