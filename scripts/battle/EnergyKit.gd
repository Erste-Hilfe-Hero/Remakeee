class_name EnergyKit
extends RefCounted
## Energy rules of KAMPF_PLAN_1000 items 50, 64, 67, 72, 73, 74 and 77; the numbers live in
## data/kampf_energy.json. Battle state of its own sits in a meta of the model, so
## BattleModel and Spirling only call in here.

const PATH: String = "res://data/kampf_energy.json"
const META: String = "energy_kit"
## Rule variant key (data/rule_variants.json): Energy a Soaked Spirling loses at each turn end (item 74).
const SOAK_DRAIN_KEY: String = "soak_drain"
const SOAK: String = "soak"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data

static func num(key: String, default: float) -> float:
	return float(data().get(key, default))

# --- Item 50: the most Energy per kind ---------------------------------------------------------

## Energy a kind of [param role] holds above Spirling.MAX_ENERGY.
static func role_bonus(role: String) -> int:
	return int((data().get("role_cap", {}) as Dictionary).get(role, 0))

## Energy [param s] holds above Spirling.MAX_ENERGY because of its kind's role.
static func role_cap(s: Spirling) -> int:
	return role_bonus(s.data.role) if s != null and s.data != null else 0

## The most Energy [param s] can hold with normal rules: 10, 11 or 12.
static func cap_of(s: Spirling) -> int:
	return Spirling.MAX_ENERGY + role_cap(s)

## Rules book lines: which roles hold more Energy.
static func role_lines() -> Array[String]:
	var out: Array[String] = []
	var caps: Dictionary = data().get("role_cap", {})
	for role: String in caps:
		out.append(Loc.t("%s kinds hold %d more Energy (%d in all).") % [Loc.t(role.capitalize()), int(caps[role]), Spirling.MAX_ENERGY + int(caps[role])])
	return out

# --- Battle state ------------------------------------------------------------------------------

static func state(model: BattleModel) -> Dictionary:
	if not model.has_meta(META):
		model.set_meta(META, {"spent": {}, "fought": {}})
	return model.get_meta(META)

# --- Item 67: the bench catches its breath -----------------------------------------------------

## At each turn end: every standing Spirling on the bench that has already stood in front gains
## bench_regen Energy, up to its cap. Returns how many gained.
static func bench_tick(model: BattleModel) -> int:
	var st: Dictionary = state(model)
	var fought: Dictionary = st.fought
	var gain: int = int(num("bench_regen", 0.0))
	var n: int = 0
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		var team: Array = model.party(side)
		for i: int in team.size():
			var s: Spirling = team[i]
			if model.slot_of(side, i) >= 0:
				fought[s] = true
				continue
			if gain <= 0 or not fought.has(s) or not model.is_standing(s):
				continue
			var cap: int = model.energy_cap_of(side, s)
			if s.energy < cap:
				s.energy = mini(s.energy + gain, cap)
				n += 1
	return n

# --- Item 74: Damp Sparks (rule variant) -------------------------------------------------------

## Under the variant Damp Sparks a Soaked Spirling in front loses Energy at each turn end.
static func soak_tick(model: BattleModel) -> void:
	var drain: int = int(model.rules.get(SOAK_DRAIN_KEY, 0.0))
	if drain <= 0:
		return
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		for slot: int in model.standing_slots(side):
			var s: Spirling = model.active_spirling(side, slot)
			if s.status != SOAK or s.energy <= 0:
				continue
			var d: Dictionary = model._who(side, slot)
			d.merge({"text": "The water seeps into %s: it loses %d Energy!", "args": [s.display_name(), mini(drain, s.energy)]})
			model.emit_event(BattleEvent.Type.TECHNIQUE, d)
			model.change_energy(side, -drain, slot)

# --- Item 77: arts that grow with the Energy already spent -------------------------------------

## Notes [param amount] Energy [param s] paid for an art.
static func note_spent(model: BattleModel, s: Spirling, amount: int) -> void:
	if amount > 0:
		var spent: Dictionary = state(model).spent
		spent[s] = int(spent.get(s, 0)) + amount

## Energy [param s] has paid for arts in this battle.
static func spent_of(model: BattleModel, s: Spirling) -> int:
	return int(state(model).spent.get(s, 0))

## Power factor of a spent_scale art after [param spent] Energy paid for arts.
static func spent_mult(spent: int) -> float:
	return 1.0 + num("spent_per", 0.04) * clampi(spent, 0, int(num("spent_max", 15.0)))

# --- Items 72 and 73: the pips -----------------------------------------------------------------

## Side of an Energy pip: the era's own, or one_hand_pip in one-hand mode if that is bigger.
static func pip_size(era_pip: float, one_hand: bool) -> float:
	return maxf(era_pip, num("one_hand_pip", 3.0)) if one_hand else era_pip

## Pips lit [param t] seconds into the flow after a Rest from [param from] to [param to]: the
## gained pips fill one after another, rest_flow_step apart.
static func flow_lit(from: int, to: int, t: float, step: float = -1.0) -> int:
	if to <= from:
		return to
	if step < 0.0:
		step = num("rest_flow_step", 0.12)
	if step <= 0.0:
		return to
	return mini(to, from + 1 + floori(t / step))

## Seconds the whole flow from [param from] to [param to] takes.
static func flow_time(from: int, to: int) -> float:
	return maxf(0.0, float(to - from)) * num("rest_flow_step", 0.12)

# --- Item 64: the Energy lesson of the first battles -------------------------------------------

## Tip id (Tips.LINES) [param e] brings up in a battle: the low-Energy lesson when the player's
## Spirling runs low, the Rest lesson at its first Rest. "" for none.
static func tip_for(e: BattleEvent) -> String:
	if int(e.data.get("side", -1)) != BattleModel.Side.PLAYER:
		return ""
	match e.type:
		BattleEvent.Type.ENERGY_CHANGED:
			if int(e.data.get("energy", 99)) <= int(num("tutorial_low", 3.0)):
				return "energy_low"
		BattleEvent.Type.NOT_ENOUGH_ENERGY:
			return "energy_low"
		BattleEvent.Type.REST:
			return "energy_rest"
	return ""
