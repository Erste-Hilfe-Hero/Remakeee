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
	STAT_CHANGED, FIELD, RULE, PARTNER, BOSS,
	FIELD_END, BOSS_PHASE, REACTION, TRAIT,
	ENERGY_TAX, SNARE_SET, SNARE_HIT, SNARE_CLEARED, HEAL_BLOCKED, WEARY,
	DELAYED_SET, DELAYED_HIT, FIELD_NEXT, FIELD_EXTENDED, BATTLE_LINE, WARDEN_WEAKENED, HELD_ENDURE,
	OATH, SHOP_EDGE, HELD_FRUIT, WHEEL_TURN,
	SUPPORT,
	STATUS_VEIL,
	# Lines of the KAMPF_PLAN_1000 arts and element rules (TechniqueRules): "text" % "args".
	TECHNIQUE,
	HELD_ITEM,
}

const STAT_NAMES: Dictionary[String, String] = {"atk": "Might", "def": "Guard", "foc": "Focus", "spd": "Pace"}

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
			if data.get("wild", false) and int(data.get("count", 1)) > 1:
				return "A hushed swarm of %d Spirlings closes in!" % int(data.get("count", 1))
			if data.get("wild", false):
				var shimmer: String = " It shimmers with odd colours!" if bool(data.get("prism", false)) else ""
				if bool(data.get("gleam", false)):
					shimmer = " It gleams in colours of its own!"
				return "A hushed %s blocks your way.%s" % [data.get("foe_name", ""), shimmer]
			if bool(data.get("boss", false)):
				return "%s rises from the Rift!" % data.get("trainer", "")
			return "%s calls for a duel!" % data.get("trainer", "A Wayfarer")
		Type.SEND_OUT, Type.SWAP_IN:
			return "%s steps out!" % who
		Type.SWAP_OUT:
			return "%s steps back to your side." % who
		Type.SWAP_BLOCKED:
			return "%s is rooted and can't swap!" % who
		Type.MOVE_USED:
			if bool(data.get("area", false)):
				return "%s: %s! It sweeps across the foes!" % [who, data.get("move", "")]
			if bool(data.get("muddled", false)):
				return "%s: %s! In its muddle it lashes out at random!" % [who, data.get("move", "")]
			return "%s: %s!" % [who, data.get("move", "")]
		Type.MISSED:
			return "%s missed!" % who
		Type.NO_TARGET:
			return "The art found nothing to strike."
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
			return "%s recovered %d Vigor." % [who, data.get("amount", 0)]
		Type.STATUS_APPLIED:
			return "%s is afflicted with %s!" % [who, StatusRules.label(str(data.get("status", "")))]
		Type.STATUS_FAILED:
			if not str(data.get("field_label", "")).is_empty():
				return "The %s keeps %s safe." % [data.get("field_label", ""), who]
			if bool(data.get("clause", false)):
				return "Calm rule: %s stays awake while an ally drowses." % who
			if bool(data.get("ward", false)):
				return "%s's Status Ward keeps it safe." % who
			# Item 212: every failed status says why.
			if not str(data.get("rule_label", "")).is_empty():
				return "Rule, %s: no status takes hold on %s." % [data.get("rule_label", ""), who]
			if bool(data.get("veil", false)):
				return "The Calm Veil keeps %s safe." % who
			if bool(data.get("reflect", false)):
				return "%s's %s turns the %s back!" % [who, data.get("item_name", ""), StatusRules.label(str(data.get("status", "")))]
			if not str(data.get("already", "")).is_empty():
				return "%s already suffers from %s." % [who, StatusRules.label(str(data.get("already", "")))]
			if not str(data.get("status", "")).is_empty():
				return "%s can't get %s: its gift keeps it safe." % [who, StatusRules.label(str(data.get("status", "")))]
			return "It had no effect on %s." % who
		Type.STATUS_TICK:
			return "%s suffers from %s." % [who, StatusRules.label(str(data.get("status", "")))]
		Type.STATUS_CURED:
			return "%s shook off %s." % [who, StatusRules.label(str(data.get("status", "")))]
		Type.STATUS_PREVENTED:
			return "%s is held back by %s!" % [who, StatusRules.label(str(data.get("status", "")))]
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
			if data.get("success", false):
				return "%s bonded with you!" % who
			if data.get("steadied", false):
				return "%s broke the bond, but your Pass keeps it calm." % who
			return "%s broke the bond!" % who
		Type.FREE_ACTION:
			return "%s seizes the moment!" % who
		Type.FLEE_RESULT:
			return "You slipped away." if data.get("success", false) else "No way out!"
		Type.XP_GAINED:
			if int(data.get("cap", 0)) > 0:
				return "%s gained %d growth. The ring limit holds it at ring %d for now." % [who, data.get("amount", 0), int(data.cap)]
			return "%s gained %d growth." % [who, data.get("amount", 0)]
		Type.LEVEL_UP:
			return "%s grew ring %d!" % [who, data.get("level", 0)]
		Type.MOVE_LEARNED:
			return "%s picked up %s!" % [who, data.get("move", "")]
		Type.BATTLE_END:
			return ""
		Type.STAT_CHANGED:
			var stat: String = STAT_NAMES.get(str(data.get("stat", "")), "")
			var delta: int = int(data.get("delta", 0))
			if delta == 0:
				return "%s's %s is already at its %s." % [who, stat, "peak" if int(data.get("tried", 0)) > 0 else "lowest"]
			var line: String = "%s's %s %s%s" % [who, stat, "goes up" if delta > 0 else "drops", "." if absi(delta) == 1 else " a lot."]
			if bool(data.get("warn", false)):
				line += " " + "Careful, its hits will hurt now!"
			return line
		Type.FIELD:
			return str(data.get("text", ""))
		Type.RULE:
			if bool(data.get("turning", false)):
				return "Turning point, %s: %s" % [data.get("label", ""), data.get("text", "")]
			return "Rule, %s: %s" % [data.get("label", ""), data.get("text", "")]
		Type.PARTNER:
			return "%s fights at your side!" % data.get("partner", "")
		Type.BOSS:
			# How often it acts per turn stands on its own line (KAMPF_PLAN_1000 item 407).
			var acts: int = int(data.get("actions", 1))
			return "%s: %s" % [data.get("label", ""), data.get("text", "")] + ("\nIt acts %d times each turn." % acts if acts > 1 else "")
		Type.SUPPORT:
			return MultiRules.describe(data, who)
		Type.FIELD_END:
			if data.has("by"):
				return "The %s gives way to the %s." % [data.get("label", ""), data.get("by", "")]
			return "The %s fades away." % data.get("label", "")
		Type.BOSS_PHASE:
			return str(data.get("text", ""))
		Type.TRAIT:
			return "%s's gift, %s: %s" % [who, data.get("label", ""), data.get("text", "")]
		Type.REACTION:
			return str(data.get("text", "")) % who
		Type.OATH:
			return Loc.t(str(BattleRules.oath().get("due_text" if bool(data.get("due", false)) else "sworn_text", ""))) % who
		Type.STATUS_VEIL:
			if int(data.get("turns", 0)) <= 0:
				return "The Calm Veil fades."
			return "A Calm Veil settles: no foe status takes hold for %d turns." % int(data.get("turns", 0))
		Type.WEARY:
			return "The long fight wears everyone out. Nobody can heal any more!"
		Type.HEAL_BLOCKED:
			if bool(data.get("fresh", false)):
				return "%s can't heal for %d turns!" % [who, int(data.get("turns", 0))]
			return "%s can't heal right now!" % who
		Type.SNARE_SET:
			if bool(data.get("full", false)):
				return "No room for another snare."
			return "A snare lies in wait on your side!" if int(data.get("side", 0)) == 0 else "A snare lies in wait on the foe's side!"
		Type.SNARE_HIT:
			return "%s springs the snare!" % who
		Type.BATTLE_LINE:
			return "%s: %s" % [data.get("name", ""), data.get("text", "")]
		Type.SHOP_EDGE:
			return str(data.get("text", ""))
		Type.FIELD_EXTENDED:
			if bool(data.get("locked", false)):
				return "The %s won't give way yet." % data.get("label", "")
			if bool(data.get("failed", false)):
				return "There is no Resonance field to hold."
			return "The %s holds on for %d more turns!" % [data.get("label", ""), int(data.get("turns", 0))]
		Type.FIELD_NEXT:
			return "The Rift stirs: %s comes next turn!" % data.get("label", "")
		Type.DELAYED_SET:
			return "%s will land in %d turns!" % [data.get("move", ""), int(data.get("turns", 2))]
		Type.DELAYED_HIT:
			if bool(data.get("faded", false)):
				return "%s fades with nobody to strike." % data.get("move", "")
			return "%s lands on %s!" % [data.get("move", ""), who]
		Type.SNARE_CLEARED:
			return "The snares on your side blow away." if int(data.get("side", 0)) == 0 else "The snares on the foe's side blow away."
		Type.HELD_ENDURE:
			return "%s holds on with its Hold Stone!" % who
		Type.WHEEL_TURN:
			return "The wheel turns! The next Spirlings step up."
		Type.TECHNIQUE:
			return str(data.get("text", "")) % (data.get("args", [who]) as Array)
		Type.HELD_FRUIT:
			return "%s eats its %s!" % [who, data.get("item_name", "")]
		Type.HELD_ITEM:
			if str(data.get("kind", "")) == "guard":
				return "%s's %s takes the edge off the hit!" % [who, data.get("item_name", "")]
			return "%s's %s stirs!" % [who, data.get("item_name", "")]
		Type.WARDEN_WEAKENED:
			return "A Warden Weakener dims %s's team: they start with 15%% less Vigor." % data.get("trainer", "")
		Type.ENERGY_TAX:
			if bool(data.get("fresh", false)):
				return "%s is taxed: every art costs %d more Energy for %d turns!" % [who, int(data.get("cost", 1)), int(data.get("turns", 0))]
			# A tick only updates the strip; the end of the tax gets a line.
			return "The Energy tax on %s lifts." % who if int(data.get("turns", 0)) <= 0 else ""
	return ""
