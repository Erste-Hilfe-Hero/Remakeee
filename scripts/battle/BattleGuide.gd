class_name BattleGuide
extends RefCounted
## The battle guide (KAMPF_PLAN_1000 areas "Status-Zustände" and "Werte-Stufen und Werte"):
## reference pages with the real numbers, built from the tables the battle reads (StatusRules,
## BattleRules, DamageCalc, Spirling), so a page can never drift from the rules. Opened from the
## pause menu next to the Lexicon. Every line goes through Loc.t, numbers via patterns.

const PAGES: Array[String] = ["Statuses", "Stages", "Keen hits and order", "Values"]

static func titles() -> Array[String]:
	var out: Array[String] = []
	for p: String in PAGES:
		out.append(Loc.t(p))
	return out

## Page [param i] as text. [param lead] (may be null) fills the worked example on "Values".
static func page(i: int, lead: Spirling = null) -> String:
	match i:
		0: return "\n".join(status_lines())
		1: return "\n".join(stage_lines())
		2: return "\n".join(order_lines())
		3: return "\n".join(value_lines(lead))
	return ""

## One entry per status: name and what it does, with its numbers (item 188), then how statuses
## meet bonds and bosses (items 190, 213).
static func status_lines() -> Array[String]:
	var out: Array[String] = [Loc.t("A Spirling carries one status at a time.")]
	for st: String in StatusRules.RULES:
		out.append("%s: %s" % [Loc.t(StatusRules.label(st)), Loc.t(StatusRules.text(st))])
	out.append(Loc.t("Statuses last as long on every difficulty."))
	out.append(Loc.t("A Rift boss shakes a status off in half the time, at most %d turns.") % StatusRules.BOSS_OPEN_TURNS)
	out.append(Loc.t("A wild Spirling with a status is easier to bond with."))
	out.append(Loc.t("Every status ends when the battle ends."))
	return out

## Stage range, the factor of every stage (items 221, 222), when stages go away (item 223) and
## what Chimora leaves out on purpose (items 237, 238, 245).
static func stage_lines() -> Array[String]:
	var out: Array[String] = [Loc.t("Stages run from %d to +%d.") % [BattleRules.STAGE_MIN, BattleRules.STAGE_MAX]]
	for st: int in range(BattleRules.STAGE_MIN, BattleRules.STAGE_MAX + 1):
		out.append(BattleRules.stage_line(Loc.t("Stage"), st))
	out.append(Loc.t("A Spirling keeps its stages when it steps back and comes in again."))
	out.append(Loc.t("Every stage ends when the battle ends."))
	out.append(Loc.t("On a Rift boss lowered stages count half."))
	out.append(Loc.t("There are no stages for aim or dodging."))
	return out

## Keen hits and who moves first (items 235, 239).
static func order_lines() -> Array[String]:
	return [
		Loc.t("A keen hit lands 1 time in %d and deals x%s damage.") % [roundi(1.0 / DamageCalc.CRIT_CHANCE), String.num(DamageCalc.CRIT_MULT, 1)],
		Loc.t("Some keepsakes make keen hits more likely."),
		Loc.t("Order: swaps and items first, then arts by priority, then by Pace."),
		Loc.t("Equal Pace: the battle's seed tosses a coin, the same seed always the same way."),
	]

## The value formula, the same for your Spirlings and every foe (items 232, 256, 259), with a
## worked example for [param lead].
static func value_lines(lead: Spirling = null) -> Array[String]:
	var out: Array[String] = [
		Loc.t("Vigor = (base + spark/2) x (ring + %d) / %d") % [int(Spirling.HP_LEVEL_OFFSET), int(Spirling.HP_LEVEL_DIV)],
		Loc.t("Others = (base + spark/2) x (ring + %d) / %d + %d") % [int(Spirling.STAT_LEVEL_OFFSET), int(Spirling.STAT_LEVEL_DIV), Spirling.STAT_FLAT],
		Loc.t("Temperament: x%s on its stat.") % String.num(Spirling.TEMPER_BONUS, 2),
		Loc.t("Foes use the very same formula."),
	]
	if lead != null and lead.data != null:
		out.append("")
		out.append(Loc.t("%s at ring %d:") % [lead.display_name(), lead.level])
		for key: String in ["hp", "atk", "def", "foc", "spd"]:
			out.append(Loc.t("%s: base %d, spark %d = %d") % [Loc.t(stat_label(key)), base_of(lead, key), int(lead.spark.get(key, 0)), value(lead, key)])
	return out

static func stat_label(key: String) -> String:
	return "Vigor" if key == "hp" else str(BattleEvent.STAT_NAMES.get(key, key))

static func base_of(s: Spirling, key: String) -> int:
	return s.data.base_hp if key == "hp" else s.data.base_stat(key)

## The value of [param key] on [param s] as the stat screen shows it.
static func value(s: Spirling, key: String) -> int:
	return s.max_hp() if key == "hp" else int(s.call(key))

## The value calculator (item 232): what a kind with [param base] reaches at [param ring] with
## [param spark], leaning toward the stat when [param lean] (temperament).
static func calc(key: String, base: int, ring: int, spark: int, lean: bool = false) -> int:
	var b: float = float(base) + float(spark) * Spirling.SPARK_WEIGHT
	var m: float = Spirling.TEMPER_BONUS if lean else 1.0
	if key == "hp":
		return maxi(1, int(int(floor(b * (float(ring) + Spirling.HP_LEVEL_OFFSET) / Spirling.HP_LEVEL_DIV)) * m))
	return int((int(floor(b * (float(ring) + Spirling.STAT_LEVEL_OFFSET) / Spirling.STAT_LEVEL_DIV)) + Spirling.STAT_FLAT) * m)
