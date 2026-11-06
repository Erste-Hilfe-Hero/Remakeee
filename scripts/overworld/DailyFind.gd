class_name DailyFind
extends RefCounted
## "Find of the day": each calendar day one area with wild Spirlings hosts a visitor that
## doesn't normally live there, a little stronger and with high Spark values. It is found at
## most once per day and missing a day costs nothing (no streaks, no timers to chase).

## Chance that a wild encounter in today's area is the visitor (until it was met today).
const CHANCE: float = 0.25
const LEVEL_BONUS: int = 2
## Minimum Spark per stat for the visitor (normal Spirlings roll 0..SPARK_MAX).
const SPARK_FLOOR: int = 10

## "YYYY-MM-DD" in local time by the server clock (item 10).
static func today_key() -> String:
	var d: Dictionary = Online.date_now()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

static func flag_for(day: String) -> String:
	return "daily_find_%s" % day

## Today's pick: {"table": id, "species": name, "level": int}, or {} if no data.
static func pick(day: String) -> Dictionary:
	var tables: Array[String] = EncounterTable.table_ids()
	tables.sort()
	if tables.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-daily-" + day)
	var table: String = tables[rng.randi_range(0, tables.size() - 1)]
	var native: Array[String] = EncounterTable.species_on(table)
	var visitors: Array[String] = []
	for t: String in tables:
		for sp: String in EncounterTable.species_on(t):
			if not sp in native and not sp in visitors:
				visitors.append(sp)
	if visitors.is_empty():
		visitors = native.duplicate()
	visitors.sort()
	var top: int = 2
	for s: Dictionary in EncounterTable.table(table).get("spawns", []):
		top = maxi(top, int(s.get("max", 2)))
	return {"table": table, "species": visitors[rng.randi_range(0, visitors.size() - 1)], "level": top + LEVEL_BONUS}

## Returns today's visitor if this encounter in [param table] should be it, else null.
## Sets the day's flag when it appears.
static func maybe_spawn(table: String, flags: Dictionary, rng: RandomNumberGenerator, day: String = "") -> Spirling:
	if day.is_empty():
		day = today_key()
	var p: Dictionary = pick(day)
	if p.is_empty() or str(p.table) != table or bool(flags.get(flag_for(day), false)):
		return null
	if rng.randf() >= CHANCE:
		return null
	var sd: SpirlingData = Database.species(str(p.species))
	if sd == null:
		return null
	var s := Spirling.new(sd, int(p.level), rng)
	for key: String in s.spark:
		s.spark[key] = maxi(s.spark[key], SPARK_FLOOR)
	s.restore()
	flags[flag_for(day)] = true
	DailyTasks.record("daily_find", {"map": table})
	return s

## One line for the Goals screen.
static func hint(flags: Dictionary, day: String = "") -> String:
	if day.is_empty():
		day = today_key()
	var p: Dictionary = pick(day)
	if p.is_empty():
		return ""
	var where: String = MapData.load_map(str(p.table)).display_name if MapData.exists(str(p.table)) else str(p.table).capitalize()
	if bool(flags.get(flag_for(day), false)):
		return "Today's visitor in %s has been met. Another arrives tomorrow." % where
	return "Today: a rare visitor stirs in %s." % where
