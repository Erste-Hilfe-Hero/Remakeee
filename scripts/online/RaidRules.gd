class_name RaidRules
extends RefCounted
## Raid Rifts extras (Online 100, points 23, 24, 28, 29, 30), shared by the game and LocalBackend.
## The server does the same in 20261111000050_raid_more.sql from server_config.raid_rules.

const CONFIG_PATH: String = "res://data/raid_rules.json"
const TIER_NAMES: Array[String] = ["Easy", "Normal", "Hard"]

static func config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

## Week number since 1970 (the guardian changes every week, point 24).
static func week_index(unix: int) -> int:
	return unix / 604800

## The guardian of the week from [param pool]; with [param roll] (0-99) below legendary_chance a
## legendary instead (point 30), picked by week as well. Returns {guardian, legendary}.
static func guardian(cfg: Dictionary, pool: Array, week: int, roll: int) -> Dictionary:
	var legs: Array = cfg.get("legendaries", [])
	if not legs.is_empty() and roll < int(cfg.get("legendary_chance", 0)):
		return {"guardian": str(legs[week % legs.size()]), "legendary": true}
	if pool.is_empty():
		return {}
	return {"guardian": str(pool[week % pool.size()]), "legendary": false}

## Strength for a party size base [param base_hp], tier and legendary (point 23).
static func hp(cfg: Dictionary, base_hp: int, tier: int, legendary: bool) -> int:
	var t: Dictionary = cfg.tiers[tier]
	var out: int = base_hp * int(t.hp) / 100
	if legendary:
		out = out * int(cfg.get("legendary_hp", 150)) / 100
	return out

static func tier_ok(cfg: Dictionary, tier: Variant) -> bool:
	return (tier is int or tier is float) and int(tier) >= 0 and int(tier) < (cfg.get("tiers", []) as Array).size()

## Reward count: the member with the most damage gets top_bonus more (point 28).
static func reward_count(cfg: Dictionary, base: int, top: bool) -> int:
	return base + (int(cfg.get("top_bonus", 1)) if top else 0)

# --- Random groups, Echo teams and role signs (points 25, 26, 27; 20261113000020_raid_bund_more.sql) ---

const ROLE_NAMES: Dictionary = {"": "No sign", "attack": "Attack", "guard": "Guard", "help": "Help"}

static func role_ok(cfg: Dictionary, role: Variant) -> bool:
	return role is String and (str(role).is_empty() or (cfg.get("roles", ["attack", "guard", "help"]) as Array).has(role))

## Whether a random group forms with [param others] waiting players after [param waited] seconds:
## -1 = keep waiting, else the number of Echo teams that fill the free places (point 26).
static func group_echoes(cfg: Dictionary, others: int, waited: int) -> int:
	if waited >= int(cfg.get("echo_wait", 60)):
		return 3 - mini(others, 3)
	if others >= 3 or (others >= 1 and waited >= int(cfg.get("group_wait", 30))):
		return 0
	return -1

## Damage of one Echo team: echo_share percent of the strength, dealt at once.
static func echo_damage(cfg: Dictionary, hp_total: int) -> int:
	return hp_total * int(cfg.get("echo_share", 15)) / 100
