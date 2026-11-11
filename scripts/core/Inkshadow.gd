class_name Inkshadow
extends RefCounted
## Inkshadow: the lead Spirling walks one step behind the Wayfarer, drawn in ink, and mutters a
## remark every few dozen steps. It keeps a grudge: each battle it ends fainted adds a mark in
## GameState.records["inkshadow_grudge"][uid]; from "grudge_sour" marks on its remarks turn sour.
## The grudge is flavour only, it never costs the player anything. Each battle it ends standing
## adds a bond mark (records["inkshadow_bond"]); from "bond_warm" marks on it says warm lines and
## finds coins more often ("find_chance_warm"). Values live in data/inkshadow.json.

const DATA_PATH: String = "res://data/inkshadow.json"
const RECORD: String = "inkshadow_grudge"
const BOND: String = "inkshadow_bond"
const STEPS: String = "inkshadow_steps"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

## The cell the shadow stands on: the cell the Wayfarer just left, or the one behind them
## (opposite of [param facing]) right after a warp.
static func trail_cell(prev_cell: Vector2i, cell: Vector2i, facing: String) -> Vector2i:
	if prev_cell != cell and absi(prev_cell.x - cell.x) + absi(prev_cell.y - cell.y) == 1:
		return prev_cell
	return cell - GridWalker.DIRS.get(facing, Vector2i.DOWN)

## The Spirling that walks behind: the first one in the team that is still standing.
static func lead() -> Spirling:
	var i: int = GameState.first_healthy_index()
	return GameState.party[i] if i >= 0 else null

static func grudge(s: Spirling) -> int:
	return int(GameState.as_dict(GameState.records.get(RECORD, {})).get(s.uid, 0))

static func is_sour(s: Spirling) -> bool:
	return grudge(s) >= int(data().get("grudge_sour", 3))

static func bond(s: Spirling) -> int:
	return int(GameState.as_dict(GameState.records.get(BOND, {})).get(s.uid, 0))

static func is_warm(s: Spirling) -> bool:
	return bond(s) >= int(data().get("bond_warm", 5))

## Chance per remark that [param s] digs up coins; higher once it is warm.
static func find_chance(s: Spirling) -> float:
	return float(data().get("find_chance_warm" if is_warm(s) else "find_chance", 0.0))

## At the end of a battle: a grudge mark for every team member that fainted, a bond mark for
## every one still standing (by uid, both capped).
static func note_battle(party: Array[Spirling]) -> void:
	var g: Dictionary = GameState.as_dict(GameState.records.get(RECORD, {})).duplicate()
	var b: Dictionary = GameState.as_dict(GameState.records.get(BOND, {})).duplicate()
	var top: int = int(data().get("grudge_max", 9))
	var bond_top: int = int(data().get("bond_max", 9))
	for s: Spirling in party:
		if s.uid.is_empty():
			continue
		if s.hp <= 0:
			g[s.uid] = mini(top, int(g.get(s.uid, 0)) + 1)
		else:
			b[s.uid] = mini(bond_top, int(b.get(s.uid, 0)) + 1)
	GameState.records[RECORD] = g
	GameState.records[BOND] = b

## Forgives one grudge mark (a heal at a camp or a spring).
static func soothe(s: Spirling) -> void:
	var g: Dictionary = GameState.as_dict(GameState.records.get(RECORD, {})).duplicate()
	if int(g.get(s.uid, 0)) > 0:
		g[s.uid] = int(g[s.uid]) - 1
	GameState.records[RECORD] = g

## Called on every step. Returns {} most steps; every "remark_every" steps it returns
## {"text": String} or sometimes {"text": String, "money": int}.
static func step(rng: RandomNumberGenerator) -> Dictionary:
	var s: Spirling = lead()
	if s == null:
		return {}
	var n: int = int(GameState.records.get(STEPS, 0)) + 1
	GameState.records[STEPS] = n
	if n % maxi(1, int(data().get("remark_every", 40))) != 0:
		return {}
	return remark(s, rng)

## One remark for [param s], already translated and filled in.
static func remark(s: Spirling, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = data()
	var who: String = s.display_name()
	if rng.randf() < find_chance(s):
		var finds: Array = d.get("finds", [])
		if not finds.is_empty():
			var coins: int = int(d.get("find_coins", 0))
			return {"text": Loc.t(str(finds[rng.randi() % finds.size()])) % [who, coins], "money": coins}
	var pool: Array = GameState.as_dict(d.get("remarks", {})).get(s.temper, [])
	if is_sour(s):
		pool = d.get("sour", [])
	elif is_warm(s):
		pool = d.get("warm", [])
	if pool.is_empty():
		return {}
	return {"text": Loc.t(str(pool[rng.randi() % pool.size()])) % who}
