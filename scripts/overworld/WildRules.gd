class_name WildRules
extends RefCounted
## Wild encounter and bond rules of the battle plan area "Wild-Begegnungen und Bond"
## (docs/KAMPF_PLAN_1000.md). Tuning in data/wild_rules.json. Bond chances are never shown as a
## number (LEGAL.md): the field bonus only adds to the hidden chance like a charm.

const PATH: String = "res://data/wild_rules.json"
## GameState.records key: {"tries": n, "bonds": n, "kinds": {species: true}}.
const STATS_RECORD: String = "bond_stats"
const BOND_LEXICON: String = "bond_stats"
const RARITY_WORDS: Dictionary[String, String] = {"common": "Common", "uncommon": "Uncommon", "shy": "Shy", "ancient": "Ancient"}

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data

## Hidden bond bonus of [param field] for [param target] (0 without a field).
static func field_bond_bonus(field: String, target: Spirling) -> float:
	var f: Variant = (data().get("bond_field", {}) as Dictionary).get(field, {})
	if not f is Dictionary:
		return 0.0
	var bonus: float = float((f as Dictionary).get("all", 0.0))
	var best: float = 0.0
	for e: int in target.elements():
		best = maxf(best, float((f as Dictionary).get(str(Elements.E.find_key(e)), 0.0)))
	return bonus + best

## Prism chance after [param chain] wild Spirlings of the same kind in a row.
static func prism_chance(chain: int) -> float:
	var steps: int = clampi(chain, 0, int(data().get("prism_chain_max", 0)))
	return Spirling.PRISM_CHANCE * (1.0 + steps * float(data().get("prism_chain_step", 0.0)))

## Encounter rate factor: more wild Spirlings step out at night outdoors.
static func rate_mult(phase: int, outdoor: bool, day_night: bool) -> float:
	if outdoor and day_night and phase == DayCycle.Phase.NIGHT:
		return float(data().get("night_rate", 1.0))
	return 1.0

## Elements that step out more often in the weather [param kind] (WeatherCycle.KINDS).
static func weather_boost(kind: String) -> Array[int]:
	var out: Array[int] = []
	for e: Variant in (data().get("weather_boost", {}) as Dictionary).get(kind, []):
		if Elements.E.has(str(e)):
			out.append(int(Elements.E[str(e)]))
	return out

## A rare keepsake for a fresh wild Spirling. Draws from its own generator seeded from
## [param rng]'s state, so the encounter roll itself stays the same.
static func roll_held(wild: Spirling, rng: RandomNumberGenerator) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.state ^ 0x5eed
	if r.randf() >= float(data().get("held_chance", 0.0)):
		return
	var items: Array = data().get("held_items", [])
	var total: int = 0
	for it: Dictionary in items:
		total += int(it.get("w", 1))
	if total <= 0:
		return
	var pick: int = r.randi_range(1, total)
	for it: Dictionary in items:
		pick -= int(it.get("w", 1))
		if pick <= 0:
			wild.held = str(it.item)
			return

## The rarity word of a kind for its Spirlog page.
static func rarity_line(sd: SpirlingData) -> String:
	return Loc.t("Rarity: %s") % Loc.t(RARITY_WORDS.get(sd.rarity, "Common"))

## After a battle: counts bond tries and bonds. Returns the lexicon ids it wrote.
static func after_battle(records: Dictionary, model: BattleModel) -> Array[String]:
	var out: Array[String] = []
	if model.bond_tries <= 0:
		return out
	var st: Dictionary = (records.get(STATS_RECORD, {}) as Dictionary).duplicate(true)
	st["tries"] = int(st.get("tries", 0)) + model.bond_tries
	if model.bonded != null:
		st["bonds"] = int(st.get("bonds", 0)) + 1
		var kinds: Dictionary = st.get("kinds", {})
		kinds[model.bonded.data.species_name] = true
		st["kinds"] = kinds
	records[STATS_RECORD] = st
	if model.bonded != null and Lexicon.add(records, BOND_LEXICON):
		out.append(BOND_LEXICON)
	return out

## Bond statistics for the lexicon page and the records: tries, bonds, kinds. No odds.
static func bond_lines(records: Dictionary) -> Array[String]:
	var st: Dictionary = records.get(STATS_RECORD, {})
	return [Loc.t("Echo calls answered: %d") % int(st.get("tries", 0)),
		Loc.t("Bonds formed: %d") % int(st.get("bonds", 0)),
		Loc.t("Kinds bonded this way: %d") % (st.get("kinds", {}) as Dictionary).size()] as Array[String]

## The day's swarm (KAMPF_PLAN "Wild-Schwarm-Ereignisse"): one native kind on one table steps
## out swarm_mult times as often all day. {"table", "species"} or {} without data.
static func swarm(day: String) -> Dictionary:
	var tables: Array[String] = EncounterTable.table_ids()
	tables.sort()
	if tables.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-swarm-" + day)
	var table: String = tables[rng.randi_range(0, tables.size() - 1)]
	var kinds: Array[String] = EncounterTable.species_on(table)
	if kinds.is_empty():
		return {}
	return {"table": table, "species": kinds[rng.randi_range(0, kinds.size() - 1)]}

## Week key of the day key "YYYY-MM-DD": weeks since 1970 (Thursday start, like unix days).
static func week_of(day: String) -> int:
	var unix: int = Time.get_unix_time_from_datetime_string(day + "T00:00:00")
	return int(floor(unix / 86400.0 / 7.0))

## The kind of the week on [param table] (KAMPF_PLAN "Wild-Begegnung Wochen-Spawn"), or "".
static func weekly(table: String, week: int) -> String:
	var kinds: Array[String] = EncounterTable.species_on(table)
	if kinds.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chimora-week-%d-%s" % [week, table])
	return kinds[rng.randi_range(0, kinds.size() - 1)]

## Weight factors {species: mult} for [param table] on [param day] (swarm and kind of the week).
static func event_mults(table: String, day: String) -> Dictionary:
	var out: Dictionary = {}
	var wk: String = weekly(table, week_of(day))
	if not wk.is_empty():
		out[wk] = int(data().get("weekly_mult", 1))
	var sw: Dictionary = swarm(day)
	if str(sw.get("table", "")) == table:
		out[str(sw.species)] = int(out.get(str(sw.species), 1)) * int(data().get("swarm_mult", 1))
	return out

## Lines for the records page: today's swarm.
static func event_lines(day: String) -> Array[String]:
	var sw: Dictionary = swarm(day)
	if sw.is_empty():
		return []
	return [Loc.t("Swarm today: %s near %s") % [Loc.t(str(sw.species)), Spirling.place_name(str(sw.table))]] as Array[String]

## The Storm Lantern sets the encounter rate (KAMPF_PLAN "Wild-Begegnungs-Rate einstellbar"):
## 0 dim, 1 normal, 2 bright, saved in GameState.records[LANTERN_RECORD].
const LANTERN_ITEM: String = "storm_lantern"
const LANTERN_RECORD: String = "lantern_rate"
const LANTERN_WORDS: Array[String] = ["Dim: fewer wild Spirlings", "Normal", "Bright: more wild Spirlings"]

static func lantern_setting(records: Dictionary) -> int:
	return clampi(int(records.get(LANTERN_RECORD, 1)), 0, LANTERN_WORDS.size() - 1)

## Encounter rate factor of the lantern setting; only with the lantern in the satchel.
static func lantern_mult(records: Dictionary, has_lantern: bool) -> float:
	var rates: Array = data().get("lantern_rates", [])
	var i: int = lantern_setting(records)
	if not has_lantern or i >= rates.size():
		return 1.0
	return float(rates[i])

## A wild horde's leader (KAMPF_PLAN "Wild-Horde mit Anführer"): its highest-ring member, the
## first on a tie, or null for a lone wild Spirling. When it falls the rest waver (BattleModel).
const WAVER_LINE: String = "The swarm wavers without its leader!"

static func horde_leader(foes: Array) -> Spirling:
	if foes.size() < 2:
		return null
	var best: Spirling = foes[0]
	for f: Spirling in foes:
		if f.level > best.level:
			best = f
	return best

## Wild surprise: now and then a wild Spirling gets the jump and strikes before your arts in the
## first turn (more often at night). Seeded from the battle seed, so it uses no game RNG.
const SURPRISE_LINE: String = "The wild %s takes you by surprise!"

static func surprise(battle_seed: int, phase: int) -> bool:
	var r := RandomNumberGenerator.new()
	r.seed = battle_seed ^ 0x5a17
	var chance: float = float(data().get("surprise_chance", 0.0))
	if phase == DayCycle.Phase.NIGHT:
		chance *= float(data().get("surprise_night_mult", 1.0))
	return r.randf() < chance

## Elder wild Spirlings (endgame, after Act I): rare old ones of their kind with more rings and
## bright sparks, and more growth. Marked with ELDER_META for the battle's opening line.
const ELDER_META: StringName = &"wild_elder"
const ELDER_LINE: String = "This %s is ancient, scarred by many seasons!"

static func roll_elder(wild: Spirling, act1_done: bool, rng: RandomNumberGenerator) -> bool:
	if wild == null or not act1_done:
		return false
	var r := RandomNumberGenerator.new()
	r.seed = rng.state ^ 0xe1de
	if r.randf() >= float(data().get("elder_chance", 0.0)):
		return false
	make_elder(wild)
	return true

static func make_elder(wild: Spirling) -> void:
	wild.level = mini(Spirling.LEVEL_SANITY, wild.level + int(data().get("elder_rings", 0)))
	wild.xp = Spirling.xp_for_level(wild.level)
	var floor_spark: int = int(data().get("elder_spark", 0))
	for key: String in Spirling.STAT_KEYS:
		wild.spark[key] = clampi(maxi(int(wild.spark.get(key, 0)), floor_spark), 0, Spirling.SPARK_MAX)
	wild.hp = wild.max_hp()
	wild.set_meta(ELDER_META, true)

static func is_elder(s: Spirling) -> bool:
	return s != null and s.has_meta(ELDER_META)

## Growth factor of a battle against an elder.
static func elder_growth(foes: Array) -> float:
	for s: Variant in foes:
		if s is Spirling and is_elder(s):
			return float(data().get("elder_growth_mult", 1.0))
	return 1.0

## Fog limits sight: wild battles under a foggy sky miss more often (both sides).
const FOG_LINE: String = "The fog is thick: arts miss more often."

static func sight_mult(sky: String) -> float:
	return float((data().get("sight", {}) as Dictionary).get(sky, 1.0))
