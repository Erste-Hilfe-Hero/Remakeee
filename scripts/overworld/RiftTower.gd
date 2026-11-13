class_name RiftTower
extends RefCounted
## Rift towers (plan area 8, items 3266-3275): the Cinder Stair in the Cinder Rift and the Tide
## Shaft in the Tidewater Rift, open once that Rift is sealed. Fifteen floors of echoes of three
## elements only; teams of at most MAX_TEAM Spirlings, each at MIN_RING or more. The Tide Shaft
## counts its floors down and gets darker per section. The team rests every SECTION floors.
## The first clear of a floor pays FLOOR_WAYMARKS, the top floor TOP_WAYMARKS (once each).

const DATA_PATH: String = "res://data/endgame.json"
const MAX_TEAM: int = 3
const MIN_RING: int = 30
const SECTION: int = 5
const ECHO_TEAM: int = 3
const FLOOR_WAYMARKS: int = 5
const TOP_WAYMARKS: int = 50
const BASE_PRIZE: int = 150
const PRIZE_STEP: int = 25
## How much darker the Tide Shaft backdrop gets per section.
const SHADE_STEP: float = 0.2

static var _list: Array[Dictionary] = []

var def: Dictionary = {}
var seed_value: int = 0

func _init(p_def: Dictionary, p_seed: int) -> void:
	def = p_def
	seed_value = p_seed

static func list() -> Array[Dictionary]:
	if _list.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for t: Variant in (d as Dictionary).get("rift_towers", []):
					if t is Dictionary:
						_list.append(t)
	return _list

static func find(id: String) -> Dictionary:
	for t: Dictionary in list():
		if str(t.id) == id:
			return t
	return {}

static func floors(t: Dictionary) -> int:
	return int(t.get("floors", 15))

static func is_open(t: Dictionary) -> bool:
	return GameState.has_flag(str(t.get("open_flag", "")))

static func best(t: Dictionary) -> int:
	return clampi(int(GameState.records.get("rift_" + str(t.id), 0)), 0, floors(t))

static func elements_of(t: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for e: Variant in t.get("elements", []):
		out.append(int(Elements.E.get(str(e), 0)))
	return out

## Spirlings of [param team] that may enter: ring MIN_RING or more.
static func eligible(team: Array[Spirling]) -> Array[Spirling]:
	return team.filter(func(s: Spirling) -> bool: return s.level >= MIN_RING)

## The entrance line: rules and best floor.
static func entrance_text(t: Dictionary) -> String:
	return Loc.t("%s: %d floors, echoes of %s only. Up to %d Spirlings, each at ring %d or more. Best: %d of %d.") % [
		Loc.t(str(t.name)), floors(t), ", ".join(elements_of(t).map(func(e: int) -> String: return Loc.t(Elements.element_name(e)))),
		MAX_TEAM, MIN_RING, best(t), floors(t)]

## "Floor 3 of 15", or for a tower that counts down "Depth 13 of 15" (plan 3268).
static func floor_label(t: Dictionary, floor_index: int) -> String:
	if bool(t.get("down", false)):
		return Loc.t("Depth %d of %d") % [floors(t) - floor_index, floors(t)]
	return Loc.t("Floor %d of %d") % [floor_index + 1, floors(t)]

## Backdrop shade for [param floor_index]: darker per section in a tower that counts down.
static func shade(t: Dictionary, floor_index: int) -> float:
	if not bool(t.get("down", false)):
		return 0.0
	return minf(0.6, SHADE_STEP * float(floor_index / SECTION))

## Echo ring on [param floor_index]: MIN_RING on the first floor, two more per floor.
static func level_for(floor_index: int) -> int:
	return mini(MIN_RING + 2 * floor_index, Spirling.STORY_RING)

## Forms that fit the ring and share one of the tower's elements.
static func pool(t: Dictionary, level: int) -> Array[SpirlingData]:
	var els: Array[int] = elements_of(t)
	var out: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		var evo_at: int = BalanceSim.evolve_at(sd)
		if level < BalanceSim.min_level(sd) or (evo_at > 0 and level >= evo_at):
			continue
		if sd.elements.any(func(e: int) -> bool: return e in els):
			out.append(sd)
	out.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	return out

## The echo team for a floor, the same for the same run seed.
func team(floor_index: int) -> Array[Spirling]:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, floor_index, str(def.id)])
	var lvl: int = level_for(floor_index)
	var p: Array[SpirlingData] = pool(def, lvl)
	var out: Array[Spirling] = []
	for i: int in ECHO_TEAM:
		if p.is_empty():
			break
		out.append(Spirling.new(p[r.randi_range(0, p.size() - 1)], lvl, r))
	return out

## Rule variants of a floor (item 799): none in the first section, one in the second, two from
## the third on; drawn from the run seed, so the floor card can name them before the battle.
func variants_for(floor_index: int) -> Array[String]:
	var count: int = clampi(floor_index / SECTION, 0, 2)
	if count == 0:
		return []
	return BattleRules.draw_variants(hash([seed_value, floor_index, str(def.id), "variants"]), count)

## The floor card: the floor and, when there are any, its rule variants.
func floor_card(floor_index: int) -> String:
	var text: String = floor_label(def, floor_index)
	var ids: Array[String] = variants_for(floor_index)
	if not ids.is_empty():
		text += "\n" + Loc.t("Rule variants: %s") % BattleRules.variant_names(ids)
	return text

func prize(floor_index: int) -> int:
	return BASE_PRIZE + PRIZE_STEP * floor_index

static func ai_for(floor_index: int) -> int:
	return clampi(2 + floor_index / SECTION, 2, 3)

## Books a run that cleared [param cleared] floors: best floor and Waymarks for new floors.
static func finish(t: Dictionary, cleared: int) -> Array[String]:
	var old: int = best(t)
	var n: int = mini(cleared, floors(t))
	if n <= old:
		return []
	GameState.records["rift_" + str(t.id)] = n
	var amount: int = (n - old) * FLOOR_WAYMARKS + (TOP_WAYMARKS if n >= floors(t) else 0)
	var lines: Array[String] = Waymarks.reward_lines(Waymarks.earn(amount, "tower"))
	# Every fifth floor cleared the first time also leaves a find (GrowthRules, KAMPF_PLAN).
	for id: String in GrowthRules.tower_finds(old, n, SECTION):
		GameState.add_item(id)
		lines.append(Loc.t("Tower find: %s") % Loc.t(str(Database.item(id).get("name", id))))
	if n >= floors(t):
		lines.append_array(TraitKit.tower_reward(str(t.id)))
	return lines

## The tower card (plan 3270): every tower with its best floor and next reward.
static func card_lines() -> Array[String]:
	var out: Array[String] = [Loc.t("Lighthouse stair: best floor %d of %d") % [Gauntlet.best(), Gauntlet.FLOORS]]
	for t: Dictionary in list():
		if not is_open(t):
			out.append(Loc.t("%s: opens once its Rift is sealed.") % Loc.t(str(t.name)))
			continue
		var b: int = best(t)
		if b >= floors(t):
			out.append(Loc.t("%s: cleared, %d of %d.") % [Loc.t(str(t.name)), b, floors(t)])
		else:
			out.append(Loc.t("%s: best %d of %d, next floor pays %d Waymarks.") % [Loc.t(str(t.name)), b, floors(t),
				FLOOR_WAYMARKS + (TOP_WAYMARKS if b + 1 >= floors(t) else 0)])
	return out
