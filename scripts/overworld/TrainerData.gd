class_name TrainerData
extends RefCounted
## Helpers for Tamer NPCs defined in map JSON. A Tamer is an NPC with a "team" or
## "team_by_starter" field:
##   {"id": "bram", "trainer": "Hiker Bram", "team": [{"species": "Shalebat", "level": 7}],
##    "money": 140, "sight": 3, "intro": "crowcrest/bram_intro", "defeat": "crowcrest/bram_defeat",
##    "warden": "cinder", "win_flags": ["some_flag"], "leaves": true, "ai": 2}
## Battles with several Spirlings per side (story set pieces) add:
##   "front": [player, foe]   how many fight at once on each side (e.g. [4, 1], [3, 3]; max 4)
##   "partner": {"name": "Cartographer Kestra", "team": [...], "front": 1}   an ally Tamer beside you
##   "boss": "ashen_heart"    the foe in front is a Rift boss (BattleRules.BOSSES)
##   "wild": true             a wild horde: no Tamer, so the Echo call (Bond) and Run work
## Battles always start from the overworld and cut to the separate battle screen.

## Default money per foe level when the map gives none.
const MONEY_PER_LEVEL: int = 12
## Wardens never play below this AI tier (0 random, 1 greedy, 2 lookahead).
const WARDEN_MIN_AI: int = 1
## AI tier of an ally Tamer fighting beside the player.
const PARTNER_AI: int = 1

static func is_trainer(def: Dictionary) -> bool:
	return def.has("team") or def.has("team_by_starter")

## The world flag set once this Tamer is beaten.
static func beaten_flag(def: Dictionary, map_id: String) -> String:
	return str(def.get("beaten_flag", "beat_%s_%s" % [map_id, def.get("id", "tamer")]))

static func is_beaten(def: Dictionary, map_id: String, flags: Dictionary) -> bool:
	return bool(flags.get(beaten_flag(def, map_id), false))

## Rematches (item 13): a beaten Tamer fights again once per day, scaled up to the party.
## The last rematch day per Tamer lives in GameState.records["rematch"] (beaten flag -> date).
static func can_rematch(def: Dictionary, map_id: String, flags: Dictionary, records: Dictionary, today: String) -> bool:
	if not is_trainer(def) or not is_beaten(def, map_id, flags):
		return false
	if bool(def.get("leaves", false)) or bool(def.get("no_rematch", false)):
		return false
	var last: Dictionary = records.get("rematch", {})
	return str(last.get(beaten_flag(def, map_id), "")) != today

## The rematch team: the same Spirlings, all raised by the same amount so the strongest one
## matches the party's best level (never above the level cap, never below the first fight).
static func rematch_team(def: Dictionary, starter: String, rng: RandomNumberGenerator, party_top: int, cap: int) -> Array[Spirling]:
	var team: Array[Spirling] = build_team(def, starter, rng)
	var top: int = 0
	for s: Spirling in team:
		top = maxi(top, s.level)
	var shift: int = maxi(0, mini(party_top, cap) - top)
	var out: Array[Spirling] = []
	for s: Spirling in team:
		out.append(Spirling.new(s.data, s.level + shift, rng) if shift > 0 else s)
	return out

## The team entries for this Tamer ("team_by_starter" picks one from the player's starter).
static func team_entries(def: Dictionary, starter: String) -> Array:
	if def.has("team_by_starter"):
		var by: Dictionary = def.team_by_starter
		if by.has(starter):
			return by[starter]
		return by.values()[0] if not by.is_empty() else []
	return def.get("team", [])

## Builds the battle team. Unknown species are skipped (the validator reports them).
static func build_team(def: Dictionary, starter: String, rng: RandomNumberGenerator) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for e: Variant in team_entries(def, starter):
		var entry: Dictionary = e
		var sd: SpirlingData = Database.species(str(entry.get("species", "")))
		if sd != null:
			out.append(Spirling.new(sd, int(entry.get("level", 5)), rng))
	return out

## Prize money: explicit "money", else a level-based default.
static func prize_money(def: Dictionary, team: Array[Spirling]) -> int:
	if def.has("money"):
		return int(def.money)
	var top: int = 0
	for s: Spirling in team:
		top = maxi(top, s.level)
	return top * MONEY_PER_LEVEL

## AI tier for this Tamer given the difficulty default.
static func ai_tier(def: Dictionary, difficulty_ai: int) -> int:
	var tier: int = int(def.get("ai", difficulty_ai))
	if def.has("warden") or def.has("boss"):
		tier = maxi(tier, WARDEN_MIN_AI)
	return tier

## The battle info dictionary for Overworld.start_battle.
static func battle_info(def: Dictionary, team: Array[Spirling], difficulty_ai: int) -> Dictionary:
	var info: Dictionary = {
		"name": str(def.get("trainer", def.get("id", "Tamer"))),
		"ai": ai_tier(def, difficulty_ai),
		"money": 0 if is_wild_horde(def) else prize_money(def, team),
		"items": def.get("items", {}),
		"warden": def.has("warden") or def.has("boss"),
		"rule": str(def.get("rule", "")),
		"front": front(def),
		"boss": str(def.get("boss", "")),
		"wild": is_wild_horde(def),
	}
	if def.has("partner"):
		info["partner"] = def.partner
	return info

## How many Spirlings fight at once: [player, foe] (1v1 unless the Tamer sets "front").
static func front(def: Dictionary) -> Array[int]:
	var f: Array = def.get("front", [1, 1])
	var out: Array[int] = [1, 1]
	if f.size() == 2:
		out = [clampi(int(f[0]), 1, BattleRules.MAX_FRONT), clampi(int(f[1]), 1, BattleRules.MAX_FRONT)]
	return out

## True for a wild horde set piece: no Tamer, so bonding and running are allowed.
static func is_wild_horde(def: Dictionary) -> bool:
	return bool(def.get("wild", false))


## True if a Tamer at [param from] facing [param dir] with [param sight] cells sees [param target].
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
