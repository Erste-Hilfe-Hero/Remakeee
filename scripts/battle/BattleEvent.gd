class_name BattleEvent
extends RefCounted
## One thing that happened in a battle. The model emits a list of these per step;
## the presenter plays them back in order. Data keys depend on the type (see describe()).

enum Type {
	BATTLE_START, SEND_OUT, MOVE_USED, MISSED, NO_TARGET, DAMAGE, HEAL,
	STATUS_APPLIED, STATUS_FAILED, STATUS_TICK, STATUS_CURED, STATUS_PREVENTED,
	ENERGY_CHANGED, NOT_ENOUGH_ENERGY, REST, FAINTED, SWAP_OUT, SWAP_IN, SWAP_BLOCKED,
	ITEM_USED, BOND_ATTEMPT, BOND_RESULT, FREE_ACTION, FLEE_RESULT,
	XP_GAINED, LEVEL_UP, MOVE_LEARNED, BATTLE_END,
	STAT_CHANGED, FIELD, RULE,
}

const STAT_NAMES: Dictionary[String, String] = {"atk": "ATK", "def": "DEF", "foc": "FOC", "spd": "SPD"}

var type: Type
var data: Dictionary

func _init(t: Type = Type.BATTLE_START, d: Dictionary = {}) -> void:
	type = t
	data = d

func type_name() -> String:
	return Type.keys()[type]

## Plain-text line for logs, tests and the text box.
func describe() -> String:
	var who: String = str(data.get("name", ""))
	match type:
		Type.BATTLE_START:
			if data.get("wild", false):
				var shimmer: String = " It shimmers with odd colours!" if bool(data.get("prism", false)) else ""
				return "A hushed %s blocks your way.%s" % [data.get("foe_name", ""), shimmer]
			return "%s calls for a duel!" % data.get("trainer", "A Tamer")
		Type.SEND_OUT, Type.SWAP_IN:
			return "%s steps out!" % who
		Type.SWAP_OUT:
			return "%s steps back to your side." % who
		Type.SWAP_BLOCKED:
			return "%s is rooted and can't swap!" % who
		Type.MOVE_USED:
			return "%s: %s!" % [who, data.get("move", "")]
		Type.MISSED:
			return "%s missed!" % who
		Type.NO_TARGET:
			return "But there was no target..."
		Type.DAMAGE:
			var eff: float = float(data.get("eff", 1.0))
			var tail: String = ""
			if bool(data.get("crit", false)):
				tail += " A keen hit!"
			if eff > 1.0:
				tail += " It's overwhelming!"
			elif eff < 1.0 and eff > 0.0:
				tail += " It barely landed..."
			return ("%s took %d damage." % [who, data.get("amount", 0)]) + tail
		Type.HEAL:
			return "%s recovered %d HP." % [who, data.get("amount", 0)]
		Type.STATUS_APPLIED:
			return "%s is afflicted with %s!" % [who, StatusRules.label(str(data.get("status", "")))]
		Type.STATUS_FAILED:
			return "It had no effect on %s." % who
		Type.STATUS_TICK:
			return "%s is hurt by %s." % [who, StatusRules.label(str(data.get("status", "")))]
		Type.STATUS_CURED:
			return "%s shook off %s." % [who, StatusRules.label(str(data.get("status", "")))]
		Type.STATUS_PREVENTED:
			return "%s can't move (%s)!" % [who, StatusRules.label(str(data.get("status", "")))]
		Type.ENERGY_CHANGED:
			return ""
		Type.NOT_ENOUGH_ENERGY:
			return "%s doesn't have enough Energy!" % who
		Type.REST:
			return "%s catches its breath." % who
		Type.FAINTED:
			return "%s is out of the fight!" % who
		Type.ITEM_USED:
			return "Used %s on %s." % [data.get("item_name", ""), who]
		Type.BOND_ATTEMPT:
			return "You reach out to %s..." % who
		Type.BOND_RESULT:
			return "%s bonded with you!" % who if data.get("success", false) else "%s broke the bond!" % who
		Type.FREE_ACTION:
			return "%s seizes the moment!" % who
		Type.FLEE_RESULT:
			return "You slipped away." if data.get("success", false) else "No way out!"
		Type.XP_GAINED:
			return "%s gained %d XP." % [who, data.get("amount", 0)]
		Type.LEVEL_UP:
			return "%s reached Lv%d!" % [who, data.get("level", 0)]
		Type.MOVE_LEARNED:
			return "%s picked up %s!" % [who, data.get("move", "")]
		Type.BATTLE_END:
			return ""
		Type.STAT_CHANGED:
			var stat: String = STAT_NAMES.get(str(data.get("stat", "")), "")
			var delta: int = int(data.get("delta", 0))
			if delta == 0:
				return "%s's %s won't go any %s!" % [who, stat, "higher" if int(data.get("tried", 0)) > 0 else "lower"]
			return "%s's %s %s%s" % [who, stat, "rose" if delta > 0 else "fell", "!" if absi(delta) == 1 else " sharply!"]
		Type.FIELD:
			return str(data.get("text", ""))
		Type.RULE:
			return "Rule, %s: %s" % [data.get("label", ""), data.get("text", "")]
	return ""
