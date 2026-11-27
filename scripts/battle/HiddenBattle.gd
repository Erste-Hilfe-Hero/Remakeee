class_name HiddenBattle
extends RefCounted
## Hidden battle touches (data/hidden_mechanics.json "battle", docs/HIDDEN_MECHANICS.md): two art
## combos (art A on a Spirling's last action, art B now), two sky synergies (an element under a
## weather field) and two keen rules that raise the crit chance. They only work in world battles
## (BattleModel.hidden_rules); league, live duel, raid and echo battles never set it. Everything
## depends on the battle's own state and its seeded RNG draws stay the same, so a replay or the
## referee plays the battle exactly again (the flag travels in the replay as "hidden").

const DATA_PATH: String = "res://data/hidden_mechanics.json"
const META: StringName = &"hidden_state"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = (raw as Dictionary).get("battle", {}) if raw is Dictionary else {}
	return _data

static func _state(model: BattleModel) -> Dictionary:
	if not model.has_meta(META):
		model.set_meta(META, {"prev": {}, "cur": {}, "said": {}})
	return model.get_meta(META)

## Called when [param me] uses [param mv]: its last art becomes the previous one.
static func note_move(model: BattleModel, me: Spirling, mv: MoveData) -> void:
	if not model.hidden_rules or me == null or mv == null:
		return
	var st: Dictionary = _state(model)
	st.prev[me] = str((st.cur as Dictionary).get(me, ""))
	st.cur[me] = mv.move_name

## The combo [param me] completes with [param mv] now, or {}.
static func combo(model: BattleModel, me: Spirling, mv: MoveData) -> Dictionary:
	if not model.hidden_rules or mv == null:
		return {}
	var prev: String = str((_state(model).prev as Dictionary).get(me, ""))
	for c: Dictionary in data().get("combos", []):
		if str(c.first) == prev and str(c.then) == mv.move_name:
			return c
	return {}

## The sky synergy of [param mv] on field [param field], or {}.
static func sky(model: BattleModel, mv: MoveData) -> Dictionary:
	if not model.hidden_rules or mv == null or mv.neutral:
		return {}
	for s: Dictionary in data().get("skies", []):
		if str(s.field) == model.field and int(Elements.E.get(str(s.element), -1)) == mv.element:
			return s
	return {}

## Damage factor of the hidden touches for one hit of [param mv]; says each touch once per action.
static func hit_mult(model: BattleModel, side: int, slot: int, me: Spirling, mv: MoveData) -> float:
	var f: float = 1.0
	for t: Dictionary in [combo(model, me, mv), sky(model, mv)]:
		if t.is_empty():
			continue
		f *= float(t.get("mult", 1.0))
		var key: String = "%s|%d|%d|%d" % [str(t.id), model.turn, side, slot]
		if not (_state(model).said as Dictionary).has(key):
			_state(model).said[key] = true
			TechniqueRules.say(model, side, slot, str(t.text))
	return f

## Factor on the crit chance of [param me] hitting [param target] (no line, it stays hidden).
static func crit_mult(model: BattleModel, me: Spirling, target: Spirling) -> float:
	if not model.hidden_rules or me == null or target == null:
		return 1.0
	var f: float = 1.0
	for k: Dictionary in data().get("keen", []):
		match str(k.rule):
			"low_vigor":
				if me.hp > 0 and float(me.hp) <= float(me.max_hp()) * float(k.below):
					f *= float(k.crit_mult)
			"underdog":
				if me.level + int(k.rings) <= target.level:
					f *= float(k.crit_mult)
	return f
