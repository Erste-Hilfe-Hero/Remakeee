class_name EasyText
extends RefCounted
## Simple battle text (docs/KAMPF_PLAN_1000.md item 902): the most common battle lines in short,
## plain words, one fact per sentence. BattleEvent.describe() uses them while the option is on;
## every other line stays as it is.

const LINES: Dictionary[String, String] = {
	"damage": "%s loses %d Vigor.",
	"keen": "Lucky hit!",
	"strong": "Very strong hit!",
	"weak": "Weak hit.",
	"missed": "%s misses.",
	"status": "%s now has %s.",
	"tick": "%s loses Vigor from %s.",
	"prevented": "%s can't act because of %s.",
	"cured": "%s is free of %s.",
	"fainted": "%s can't fight any more.",
	"heal": "%s gets %d Vigor back.",
	"rest": "%s rests and gets Energy.",
	"no_energy": "%s needs more Energy.",
	"stat_up": "%s: %s up.",
	"stat_down": "%s: %s down.",
	"stat_far_up": "%s: %s far up.",
	"stat_far_down": "%s: %s far down.",
	"swap_blocked": "%s can't swap out.",
	"free": "%s gets an extra turn.",
}

## The plain line for [param e], "" when the normal line stays.
static func line(e: BattleEvent) -> String:
	var who: String = str(e.data.get("name", ""))
	var st: String = StatusRules.label(str(e.data.get("status", "")))
	match e.type:
		BattleEvent.Type.DAMAGE:
			var out: String = LINES.damage % [who, int(e.data.get("amount", 0))]
			var eff: float = float(e.data.get("eff", 1.0))
			if bool(e.data.get("crit", false)):
				out += " " + LINES.keen
			if eff > 1.0:
				out += " " + LINES.strong
			elif eff < 1.0 and eff > 0.0:
				out += " " + LINES.weak
			return out
		BattleEvent.Type.MISSED:
			return LINES.missed % who
		BattleEvent.Type.STATUS_APPLIED:
			return LINES.status % [who, st] if str(e.data.get("combo", "")).is_empty() else ""
		BattleEvent.Type.STATUS_TICK:
			return LINES.tick % [who, st]
		BattleEvent.Type.STATUS_PREVENTED:
			return LINES.prevented % [who, st]
		BattleEvent.Type.STATUS_CURED:
			return LINES.cured % [who, st]
		BattleEvent.Type.FAINTED:
			return LINES.fainted % who
		BattleEvent.Type.HEAL:
			return LINES.heal % [who, int(e.data.get("amount", 0))]
		BattleEvent.Type.REST:
			return LINES.rest % who
		BattleEvent.Type.NOT_ENOUGH_ENERGY:
			return LINES.no_energy % who
		BattleEvent.Type.SWAP_BLOCKED:
			return LINES.swap_blocked % who
		BattleEvent.Type.FREE_ACTION:
			return LINES.free % who
		BattleEvent.Type.STAT_CHANGED:
			var delta: int = int(e.data.get("delta", 0))
			if delta == 0:
				return ""
			var key: String = ("stat_far_" if absi(delta) > 1 else "stat_") + ("up" if delta > 0 else "down")
			var out: String = LINES[key] % [who, BattleEvent.STAT_NAMES.get(str(e.data.get("stat", "")), "")]
			if bool(e.data.get("warn", false)):
				out += " " + "Careful, its hits will hurt now!"
			return out
	return ""
