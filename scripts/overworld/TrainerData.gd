class_name TrainerData
extends RefCounted
## Helpers for Wayfarer NPCs defined in map JSON. A Wayfarer is an NPC with a "team" or
## "team_by_starter" field:
##   {"id": "bram", "trainer": "Ridgewalker Bram", "team": [{"species": "Shalebat", "level": 7}],
##    "money": 140, "sight": 3, "intro": "crowcrest/bram_intro", "defeat": "crowcrest/bram_defeat",
##    "warden": "cinder", "win_flags": ["some_flag"], "leaves": true, "ai": 2}
## Battles with several Spirlings per side (story set pieces) add:
##   "front": [player, foe]   how many fight at once on each side (e.g. [4, 1], [3, 3]; max 4)
##   "partner": {"name": "Cartographer Kestra", "team": [...], "front": 1}   an ally Wayfarer beside you
##   "boss": "ashen_heart"    the foe in front is a Rift boss (BattleRules.BOSSES)
##   "wild": true             a wild horde: no Wayfarer, so the Echo call (Bond) and Run work
## Battles always start from the overworld and cut to the separate battle screen.
## Plan area 2 (items 612, 638, 639) adds:
##   "profile": "hothead"     personality from data/ai_profiles.json (default "balanced")
##   team entries may carry "moves": ["Kite Cut", ...] (fixed arts) and "held": "spark_coil"
##   "teams_by_difficulty": {"story": [...], "tamer": [...], "veteran": [...], "rift_born": [...]}
##       a team per difficulty; a missing key falls back to "team" / "team_by_starter".

## Default money per top foe ring when the map gives none (item 659): Wayfarers 40, Wardens 70.
const MONEY_PER_LEVEL: int = 40
const WARDEN_MONEY_PER_LEVEL: int = 70
## Daily rematches keep the old, smaller rate so the coin flow stays as it was.
const REMATCH_MONEY_PER_LEVEL: int = 12
## Wardens never play below this AI tier (0 random, 1 greedy, 2 lookahead).
const WARDEN_MIN_AI: int = 1
## AI tier of an ally Wayfarer fighting beside the player.
const PARTNER_AI: int = 1
## Keys of "teams_by_difficulty", in GameState.Difficulty order.
const DIFFICULTY_KEYS: Array[String] = ["story", "tamer", "veteran", "rift_born"]

static func is_trainer(def: Dictionary) -> bool:
	return def.has("team") or def.has("team_by_starter") or def.has("teams_by_difficulty")

## The world flag set once this Wayfarer is beaten.
static func beaten_flag(def: Dictionary, map_id: String) -> String:
	return str(def.get("beaten_flag", "beat_%s_%s" % [map_id, def.get("id", "tamer")]))

static func is_beaten(def: Dictionary, map_id: String, flags: Dictionary) -> bool:
	return bool(flags.get(beaten_flag(def, map_id), false))

## Rematches (item 13): a beaten Wayfarer fights again once per day, scaled up to the party.
## The last rematch day per Wayfarer lives in GameState.records["rematch"] (beaten flag -> date).
static func can_rematch(def: Dictionary, map_id: String, flags: Dictionary, records: Dictionary, today: String) -> bool:
	if not is_trainer(def) or not is_beaten(def, map_id, flags):
		return false
	if bool(def.get("leaves", false)) or bool(def.get("no_rematch", false)):
		return false
	var last: Dictionary = records.get("rematch", {})
	return str(last.get(beaten_flag(def, map_id), "")) != today

## Rematch Key (shop item 4841): a beaten Wayfarer that already had today's rematch.
const REMATCH_KEY: String = "rg_rematch_key"

static func can_rematch_with_key(def: Dictionary, map_id: String, flags: Dictionary, records: Dictionary, today: String) -> bool:
	if not is_trainer(def) or not is_beaten(def, map_id, flags):
		return false
	if bool(def.get("leaves", false)) or bool(def.get("no_rematch", false)):
		return false
	return not can_rematch(def, map_id, flags, records, today)

## The rematch team: the same Spirlings, all raised by the same amount so the strongest one
## matches the party's best level (never above the level cap, never below the first fight).
static func rematch_team(def: Dictionary, starter: String, rng: RandomNumberGenerator, party_top: int, cap: int, difficulty: int = -1) -> Array[Spirling]:
	var team: Array[Spirling] = build_team(def, starter, rng, difficulty, cap)
	var top: int = 0
	for s: Spirling in team:
		top = maxi(top, s.level)
	var shift: int = maxi(0, mini(party_top, cap) - top)
	var out: Array[Spirling] = []
	var entries: Array = team_entries(def, starter, difficulty)
	for i: int in team.size():
		var s: Spirling = team[i]
		if shift <= 0:
			out.append(s)
			continue
		var up := Spirling.new(s.data, s.level + shift, rng)
		up.spark = s.spark.duplicate()
		up.hp = up.max_hp()
		# Item 661: the named arts stay, the rest of the kit comes from the new ring's learn list.
		var named: Array = (entries[i] as Dictionary).get("moves", []) if i < entries.size() and entries[i] is Dictionary else []
		var kit: Array[MoveData] = []
		for mv: MoveData in s.moves:
			if mv.move_name in named and kit.size() < 4:
				kit.append(mv)
		for mv: MoveData in up.moves:
			if kit.size() < 4 and not kit.has(mv):
				kit.append(mv)
		up.moves = kit
		up.held = s.held
		out.append(up)
	return out

## Warden "Second Trial" (items 682-684): a one-time rematch once every Rift in "needs_flags" is
## mended. The npc's "second_trial" block holds its own "team" / "teams_by_difficulty", two "rules"
## that always apply together (on every difficulty) and "money".
const SECOND_TRIAL_RULES: int = 2

static func has_second_trial(def: Dictionary) -> bool:
	return def.get("second_trial") is Dictionary and def.has("warden")

## The Trial as a Wayfarer definition of its own: the Warden's name, profile and items, the block's
## teams, both rules joined, its own beaten flag.
static func second_trial_def(def: Dictionary, map_id: String) -> Dictionary:
	var block: Dictionary = def.get("second_trial", {})
	var out: Dictionary = def.duplicate(true)
	for k: String in ["team", "team_by_starter", "teams_by_difficulty", "rule", "rule_by_difficulty", "money", "intro", "defeat",
			"lexicon", "win_flags", "second_trial"]:
		out.erase(k)
	for k: String in ["team", "teams_by_difficulty", "money"]:
		if block.has(k):
			out[k] = block[k]
	out["rule"] = "+".join(PackedStringArray(block.get("rules", [])))
	out["beaten_flag"] = "second_trial_" + beaten_flag(def, map_id)
	return out

## True when the Second Trial is open: the Warden is beaten, the Rifts are mended, the Trial not won.
static func can_second_trial(def: Dictionary, map_id: String, flags: Dictionary) -> bool:
	if not has_second_trial(def) or not is_beaten(def, map_id, flags):
		return false
	for f: Variant in (def.second_trial as Dictionary).get("needs_flags", []):
		if not bool(flags.get(str(f), false)):
			return false
	return not is_beaten(second_trial_def(def, map_id), map_id, flags)

## The team entries for this Wayfarer ("team_by_starter" picks one from the player's starter).
## [param difficulty] is a GameState.Difficulty value; -1 ignores "teams_by_difficulty".
static func team_entries(def: Dictionary, starter: String, difficulty: int = -1) -> Array:
	var by_diff: Variant = def.get("teams_by_difficulty", {})
	if difficulty >= 0 and difficulty < DIFFICULTY_KEYS.size() and by_diff is Dictionary:
		var block: Variant = (by_diff as Dictionary).get(DIFFICULTY_KEYS[difficulty])
		if block is Array:
			return block
	if def.has("team_by_starter"):
		var by: Dictionary = def.team_by_starter
		if by.has(starter):
			return by[starter]
		return by.values()[0] if not by.is_empty() else []
	return def.get("team", [])

## True if the Wayfarer has its own team block for [param difficulty].
static func has_block(def: Dictionary, difficulty: int) -> bool:
	var by: Variant = def.get("teams_by_difficulty", {})
	return difficulty >= 0 and difficulty < DIFFICULTY_KEYS.size() and by is Dictionary and (by as Dictionary).get(DIFFICULTY_KEYS[difficulty]) is Array

## Builds the battle team. Unknown species are skipped (the validator reports them).
## Entries may fix the arts ("moves", unknown names skipped) and a keepsake ("held").
## With a [param difficulty] (items 726-727) every foe gets GameState.FOE_SPARK in all stats, and a
## shared team (no block of its own for that difficulty) moves by GameState.FOE_LEVEL_SHIFT rings,
## never above [param ring_cap] + GameState.FOE_OVER_CAP.
static func build_team(def: Dictionary, starter: String, rng: RandomNumberGenerator, difficulty: int = -1, ring_cap: int = Spirling.MAX_LEVEL) -> Array[Spirling]:
	var out: Array[Spirling] = []
	var tuned: bool = difficulty >= 0 and difficulty < DIFFICULTY_KEYS.size()
	var shift: int = 0
	if tuned and not has_block(def, difficulty):
		shift = GameState.FOE_LEVEL_SHIFT[difficulty]
	var entries: Array = team_entries(def, starter, difficulty)
	if difficulty == GameState.Difficulty.RIFT_BORN and not has_block(def, difficulty):
		entries = rift_born_entries(def, entries)
	for e: Variant in entries:
		var entry: Dictionary = e
		var sd: SpirlingData = Database.species(str(entry.get("species", "")))
		if sd == null:
			continue
		var lvl: int = int(entry.get("level", 5))
		if shift != 0:
			lvl = clampi(lvl + shift, 1, maxi(lvl, mini(Spirling.MAX_LEVEL, ring_cap + GameState.FOE_OVER_CAP)))
		var s := Spirling.new(sd, lvl, rng)
		if tuned:
			for key: String in Spirling.STAT_KEYS:
				s.spark[key] = GameState.FOE_SPARK[difficulty]
			s.hp = s.max_hp()
		var fixed: Array[MoveData] = []
		for n: Variant in entry.get("moves", []):
			var mv: MoveData = Database.move(str(n))
			if mv != null and not fixed.has(mv) and fixed.size() < 4:
				fixed.append(mv)
		# Named arts come first; the rest of the four are filled from the default kit.
		if not fixed.is_empty():
			for mv: MoveData in s.moves:
				if fixed.size() < 4 and not fixed.has(mv):
					fixed.append(mv)
			s.moves = fixed
		s.held = str(entry.get("held", s.held)) if keeps_keepsakes(difficulty) else ""
		if tuned and def.has("warden") and difficulty >= GameState.Difficulty.VETERAN:
			var main: String = main_stat(s)
			s.spark[main] = maxi(int(s.spark.get(main, 0)), WARDEN_MAIN_SPARK)
			s.hp = s.max_hp()
		out.append(s)
	return out

## Rift-Born teams (item 743) have one Spirling more than on Tamer, at most RIFT_BORN_MAX_TEAM.
## A shared team gets a second copy of its lowest-ring entry (without its keepsake). Bosses and
## wild hordes keep their size.
const RIFT_BORN_MAX_TEAM: int = 5

static func rift_born_entries(def: Dictionary, entries: Array) -> Array:
	if entries.is_empty() or entries.size() >= RIFT_BORN_MAX_TEAM or def.has("boss") or is_wild_horde(def):
		return entries
	var low: Dictionary = entries[0]
	for e: Variant in entries:
		if e is Dictionary and int((e as Dictionary).get("level", 5)) < int(low.get("level", 5)):
			low = e
	var extra: Dictionary = low.duplicate(true)
	extra.erase("held")
	var out: Array = entries.duplicate()
	out.append(extra)
	return out

## Item 685: from Veteran on a Warden's Spirlings have at least this Spark in their main stat.
const WARDEN_MAIN_SPARK: int = 10

## "atk" or "foc": the stat behind most of the Spirling's damaging arts (a tie goes to "atk").
static func main_stat(s: Spirling) -> String:
	var phys: int = 0
	var foc: int = 0
	for mv: MoveData in s.moves:
		if not mv.is_damaging():
			continue
		if mv.kind == MoveData.Kind.FOCUS:
			foc += 1
		else:
			phys += 1
	return "foc" if foc > phys else "atk"

## Prize money: explicit "money", else a level-based default.
static func prize_money(def: Dictionary, team: Array[Spirling]) -> int:
	if def.has("money"):
		return int(def.money)
	var top: int = 0
	for s: Spirling in team:
		top = maxi(top, s.level)
	return top * (WARDEN_MONEY_PER_LEVEL if def.has("warden") else MONEY_PER_LEVEL)

## The AI profile for [param difficulty]: "profile", but none below "profile_from" (a difficulty
## key, item 681: Wardens play their personality from Tamer on).
static func profile_for(def: Dictionary, difficulty: int = -1) -> String:
	var from: int = DIFFICULTY_KEYS.find(str(def.get("profile_from", "")))
	if from > 0 and difficulty >= 0 and difficulty < from:
		return ""
	return str(def.get("profile", ""))

## The weight changes on top of the profile ({} when no profile applies).
static func profile_tune(def: Dictionary, difficulty: int = -1) -> Dictionary:
	if profile_for(def, difficulty).is_empty():
		return {}
	var t: Variant = def.get("profile_tune", {})
	return (t as Dictionary).duplicate() if t is Dictionary else {}

## AI tier for this Wayfarer given the difficulty default. On Tamer (item 734) Wayfarers play
## tier 1 and Wardens tier 2; the Warden floor WARDEN_MIN_AI holds on every difficulty.
static func ai_tier(def: Dictionary, difficulty_ai: int, difficulty: int = -1) -> int:
	var tier: int = int(def.get("ai", difficulty_ai))
	var warden: bool = def.has("warden") or def.has("boss")
	if difficulty == GameState.Difficulty.TAMER:
		tier = TAMER_WARDEN_AI if warden else TAMER_AI
	if warden:
		tier = maxi(tier, WARDEN_MIN_AI)
	return tier

const TAMER_AI: int = 1
const TAMER_WARDEN_AI: int = 2

## Keepsakes stay off foe teams on Story and Tamer (item 734).
static func keeps_keepsakes(difficulty: int) -> bool:
	return difficulty < 0 or difficulty >= GameState.Difficulty.VETERAN

## The Warden rule for [param difficulty] ("rule_by_difficulty" wins over "rule").
static func rule_for(def: Dictionary, difficulty: int = -1) -> String:
	var by: Variant = def.get("rule_by_difficulty", {})
	if difficulty >= 0 and difficulty < DIFFICULTY_KEYS.size() and by is Dictionary and (by as Dictionary).has(DIFFICULTY_KEYS[difficulty]):
		var v: Variant = by[DIFFICULTY_KEYS[difficulty]]
		# A list stacks several rules (item 677), stored as "a+b".
		return "+".join(PackedStringArray(v)) if v is Array else str(v)
	return str(def.get("rule", ""))

## The battle info dictionary for Overworld.start_battle.
static func battle_info(def: Dictionary, team: Array[Spirling], difficulty_ai: int, difficulty: int = -1) -> Dictionary:
	var info: Dictionary = {
		"name": str(def.get("trainer", def.get("id", "Wayfarer"))),
		"ai": ai_tier(def, difficulty_ai, difficulty),
		"money": 0 if is_wild_horde(def) else prize_money(def, team),
		"items": def.get("items", {}),
		"warden": def.has("warden") or def.has("boss"),
		"rule": rule_for(def, difficulty),
		"front": front(def),
		"boss": str(def.get("boss", "")),
		"wild": is_wild_horde(def),
		"profile": profile_for(def, difficulty),
		"profile_tune": profile_tune(def, difficulty),
	}
	if def.has("partner"):
		info["partner"] = def.partner
	return info

## How many Spirlings fight at once: [player, foe] (1v1 unless the Wayfarer sets "front").
static func front(def: Dictionary) -> Array[int]:
	var f: Array = def.get("front", [1, 1])
	var out: Array[int] = [1, 1]
	if f.size() == 2:
		out = [clampi(int(f[0]), 1, BattleRules.MAX_FRONT), clampi(int(f[1]), 1, BattleRules.MAX_FRONT)]
	return out

## True for a wild horde set piece: no Wayfarer, so bonding and running are allowed.
static func is_wild_horde(def: Dictionary) -> bool:
	return bool(def.get("wild", false))


## True if a Wayfarer at [param from] facing [param dir] with [param sight] cells sees [param target].
## [param blocked] is called for every cell between them and must return false for clear cells.
static func sees(from: Vector2i, dir: Vector2i, sight: int, target: Vector2i, blocked: Callable) -> bool:
	if sight <= 0:
		return false
	var c: Vector2i = from
	for i: int in sight:
		c += dir
		if c == target:
			return true
		if blocked.call(c):
			return false
	return false
