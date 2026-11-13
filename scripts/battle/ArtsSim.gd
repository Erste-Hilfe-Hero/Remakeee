class_name ArtsSim
extends RefCounted
## KAMPF_PLAN_1000 item 155: balance check for every art of the areas "Elemente und Matchups" and
## "Techniken". For each art, random teams of 3 whose lead shares the art's element play the same
## battle twice through BalanceSim._paired: once with the art in the lead's first move slot, once
## with its own learnset. The gain is the difference of the win rates.
##   godot --headless --path . -s res://tools/balance_sim.gd -- --mode arts --level 36 --rounds 200

## The arts Hesper teaches (data/dialogue/lighthouse.json), in shop order.
const ARTS: Array[String] = ["Hold Fast", "Shove Off", "Grudge Return", "Kindred Balm", "Rank and File",
	"Shake Loose", "Rolling Drum", "Late Reply", "Opening Gambit", "Pebble Hail", "Rift Hush", "Bright Lure",
	"Close Ranks", "Ember Afterglow", "Borrowed Stance", "Still Point", "Ground Burst", "Dye Bath", "Ward Circle",
	"Magma Rush", "Tidal Gust", "Clean Slate", "Coiled Strike", "Night Prowl", "Noon Glare"]
## An art may move its side's win rate by at most this much up, and this much down (a dead slot).
const GAIN_MAX: float = 0.08
const LOSS_MAX: float = -0.10

## Runs every art (or only those in [param only]) over [param battles] battle pairs at ring
## [param level]. Time-of-day arts fight at their own time of day.
static func run(level: int, battles: int, seed_value: int, only: Array[String] = []) -> Dictionary:
	Database.load_all()
	var pools: Dictionary = BalanceSim.mono_pools(level)
	var all: Array[String] = BalanceSim.valid_species(level)
	var rows: Dictionary = {}
	for art: String in ARTS:
		if not only.is_empty() and not art in only:
			continue
		var mv: MoveData = Database.move(art)
		if mv == null:
			continue
		var pool: Array[String] = []
		pool.assign(pools.get(Elements.element_name(mv.element), all))
		var r: Dictionary = BalanceSim._paired(level, battles, hash([seed_value, art]), pool, func(m: BattleModel, side: int) -> void:
			teach(m.parties[side][0], mv)
			var phase: String = str(TechniqueRules._effect(mv, &"daytime").get("phase", ""))
			if not phase.is_empty():
				m.day_phase = int(DayCycle.Phase.get(phase, -1)))
		var gain: float = float(r.with) - float(r.without)
		rows[art] = {"with": snappedf(r.with, 0.001), "without": snappedf(r.without, 0.001), "gain": snappedf(gain, 0.001),
			"ok": gain >= LOSS_MAX and gain <= GAIN_MAX}
	return {"mode": "arts", "level": level, "battles": battles, "arts": rows}

## Puts [param mv] into the first move slot of [param s] (or adds it to a short move list).
static func teach(s: Spirling, mv: MoveData) -> void:
	if s.moves.is_empty():
		s.moves.append(mv)
	else:
		s.moves[0] = mv

static func report(result: Dictionary) -> String:
	var lines: PackedStringArray = ["# Art report", "",
		"Level %d, %d battle pairs per art (teams of 3 led by a Spirling of the art's element, the art in its first slot against its own learnset). Band %+d to %+d points." % [
			result.level, result.battles, roundi(LOSS_MAX * 100.0), roundi(GAIN_MAX * 100.0)], "",
		"| Art | With | Without | Gain | Flag |", "| --- | --- | --- | --- | --- |"]
	for art: String in result.arts:
		var row: Dictionary = result.arts[art]
		var g: float = float(row.gain)
		lines.append("| %s | %d%% | %d%% | %+.1f | %s |" % [art, roundi(float(row.with) * 100.0), roundi(float(row.without) * 100.0),
			g * 100.0, "" if bool(row.ok) else ("too strong" if g > GAIN_MAX else "too weak")])
	return "\n".join(lines) + "\n"
