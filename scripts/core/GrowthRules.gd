class_name GrowthRules
extends RefCounted
## Growth (XP) rules of the battle plan area "Fortschritt, XP und Training"
## (docs/KAMPF_PLAN_1000.md). Tuning in data/growth_rules.json. There is no top ring: the curve
## runs on (Spirling.LEVEL_SANITY only guards broken data); a ring cap holds only on Veteran and
## Rift-Born in Act I (GameState.level_cap).

const PATH: String = "res://data/growth_rules.json"
## GameState.records keys.
const AREA_RECORD: String = "growth_by_region"
const WORLD_RECORD: String = "world_growth_left"
const BENCH_LEXICON: String = "bench_lessons"
const GROWTH_LEXICON: String = "growth_curve"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data

static func num(key: String, fallback: float) -> float:
	return float(data().get(key, fallback))

## Growth factor of a whole battle: the difficulty (Story grows faster), a rematch, and a running
## world goal boost from [param records].
static func battle_mult(difficulty: int, trainer: Dictionary, records: Dictionary) -> float:
	var per: Array = data().get("difficulty_mult", [])
	var m: float = float(per[difficulty]) if difficulty >= 0 and difficulty < per.size() else 1.0
	if bool(trainer.get("rematch", false)):
		m *= num("rematch_mult", 1.0)
	if int(records.get(WORLD_RECORD, 0)) > 0:
		m *= num("world_goal_mult", 1.0)
	return m

## Growth factor of one Spirling: its keepsake ("held": {"growth_mult"}) and its kinship.
static func spirling_mult(s: Spirling) -> float:
	var m: float = 1.0
	if not s.held.is_empty():
		var h: Variant = Database.item(s.held).get("held", {})
		if h is Dictionary:
			m *= float((h as Dictionary).get("growth_mult", 1.0))
	if s.kinship >= int(num("kinship_min", 999999)):
		m *= num("kinship_mult", 1.0)
	return m

## Text for a Spirling that rose several rings at once, or "" for one ring.
static func summary_line(name: String, from_ring: int, to_ring: int) -> String:
	if to_ring - from_ring < 2:
		return ""
	return "%s grew %d rings: ring %d to ring %d." % [name, to_ring - from_ring, from_ring, to_ring]

## After a battle: counts the growth per region, uses up a world goal battle and writes the
## lexicon entries the battle earned. Returns the new lexicon ids.
static func after_battle(records: Dictionary, region: String, growth: int, bench_growth: int) -> Array[String]:
	var out: Array[String] = []
	if growth > 0 and not region.is_empty():
		var by: Dictionary = (records.get(AREA_RECORD, {}) as Dictionary).duplicate()
		by[region] = int(by.get(region, 0)) + growth
		records[AREA_RECORD] = by
	if int(records.get(WORLD_RECORD, 0)) > 0:
		records[WORLD_RECORD] = int(records[WORLD_RECORD]) - 1
	if bench_growth > 0 and Lexicon.add(records, BENCH_LEXICON):
		out.append(BENCH_LEXICON)
	if growth > 0 and Lexicon.add(records, GROWTH_LEXICON):
		out.append(GROWTH_LEXICON)
	return out

## The world goal of the week reached 100 %: the next battles grow faster.
static func grant_world_boost(records: Dictionary) -> void:
	records[WORLD_RECORD] = int(num("world_goal_battles", 0))

## Lines for the records: growth per region, most first, and a running world goal boost.
static func summary_lines(records: Dictionary) -> Array[String]:
	var out: Array[String] = [Loc.t("Growth by region")]
	var by: Dictionary = records.get(AREA_RECORD, {})
	var keys: Array = by.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(by[a]) > int(by[b]) or (int(by[a]) == int(by[b]) and str(a) < str(b)))
	for k: Variant in keys:
		out.append("  %s: %d" % [Loc.t(str(k).capitalize()), int(by[k])])
	if keys.is_empty():
		out.append("  " + Loc.t("No growth yet."))
	var left: int = int(records.get(WORLD_RECORD, 0))
	if left > 0:
		out.append(Loc.t("World goal boost: %d battles left.") % left)
	return out

## Growth one even wild battle gives at [param ring] for a kind of [param xp_yield] (one earner).
static func even_battle_growth(ring: int, xp_yield: int, difficulty: int) -> int:
	var total: float = float(xp_yield) * float(ring) / BattleModel.XP_LEVEL_DIV
	return maxi(1, int(total * battle_mult(difficulty, {}, {})))

## Even wild battles one Spirling needs from [param from_ring] to [param to_ring].
static func battles_between(from_ring: int, to_ring: int, xp_yield: int, difficulty: int) -> int:
	var ring: int = from_ring
	var xp: int = Spirling.xp_for_level(from_ring)
	var n: int = 0
	while ring < to_ring and n < 100000:
		xp += even_battle_growth(ring, xp_yield, difficulty)
		n += 1
		while Spirling.xp_for_level(ring + 1) <= xp:
			ring += 1
	return n

## The growth curve as a markdown table (docs/BALANCE.md, section "growth").
static func curve_table(xp_yield: int) -> String:
	var lines: PackedStringArray = ["| Ring | Growth to reach it | To the next ring | Even wild battles to the next ring (Tamer) | Story |",
		"| --- | --- | --- | --- | --- |"]
	for r: Variant in data().get("curve_rings", []):
		var ring: int = int(r)
		lines.append("| %d | %d | %d | %d | %d |" % [ring, Spirling.xp_for_level(ring), Spirling.xp_for_level(ring + 1) - Spirling.xp_for_level(ring),
			battles_between(ring, ring + 1, xp_yield, GameState.Difficulty.TAMER), battles_between(ring, ring + 1, xp_yield, GameState.Difficulty.STORY)])
	lines.append("")
	lines.append("Growth to reach ring L = floor(%s x L ^ %s). There is no top ring. One battle gives yield x foe ring / %d (x%s against a Wayfarer), shared by the Spirlings that fought; the bench gets %d %% with Bench lessons. Table for a kind of yield %d." % [
		str(Spirling.XP_MULT), str(Spirling.XP_EXP), int(BattleModel.XP_LEVEL_DIV), str(BattleModel.TRAINER_XP_MULT), int(GameState.BENCH_XP_SHARE * 100), xp_yield])
	lines.append("Factors: Story x%s, rematch x%s, kinship %d+ x%s, Growth Charm x%s, world goal x%s for %d battles. No penalty for a higher ring than the foe (only Era V scales by ring)." % [
		str((data().get("difficulty_mult", [1.0]) as Array)[0]), str(num("rematch_mult", 1.0)), int(num("kinship_min", 0)),
		str(num("kinship_mult", 1.0)), str(float((Database.item("growth_charm").get("held", {}) as Dictionary).get("growth_mult", 1.0))),
		str(num("world_goal_mult", 1.0)), int(num("world_goal_battles", 0))])
	return "\n".join(lines)
