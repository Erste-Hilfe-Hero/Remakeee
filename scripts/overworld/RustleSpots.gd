class_name RustleSpots
extends RefCounted
## Rustling spots (era function "rustling_spots", opens in Era V): once a day every outdoor map
## with wild Spirlings has one patch of encounter ground that shakes hard. Stepping in starts a
## battle with the rarest kind of the map, a few rings higher and with a better Gleam chance.
## The spot is the same for everyone on a day (hash of map id and day) and is used up per map
## and day (records "rustle_done").

const RECORD: String = "rustle_done"
const FEATURE: String = "rustling_spots"
const RING_BONUS: int = 3
const GLEAM_MULT: float = 4.0
const LINE: String = "The grass shakes hard... Something rare is hiding here!"

## Encounter cells of [param m] (empty indoors or without a table).
static func cells(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if m == null or not m.outdoor or m.encounter_table.is_empty():
		return out
	for y: int in m.height:
		for x: int in m.width:
			var c := Vector2i(x, y)
			if m.kind_at(c) in TilesetFactory.ENCOUNTER_KINDS:
				out.append(c)
	return out

## The shaking cell of [param m] on [param day], or (-1, -1) when the map has none.
static func spot(m: MapData, day: String) -> Vector2i:
	var all: Array[Vector2i] = cells(m)
	if all.is_empty():
		return Vector2i(-1, -1)
	return all[absi(hash("%s|%s" % [m.id, day])) % all.size()]

## True while the spot of [param m] still shakes today: the era is open and it is not used.
static func active(m: MapData, day: String, records: Dictionary, era: int = -1) -> bool:
	if not EraFeatures.is_unlocked(FEATURE, era):
		return false
	if str((records.get(RECORD, {}) as Dictionary).get(m.id if m != null else "", "")) == day:
		return false
	return spot(m, day).x >= 0

## True when stepping on [param cell] of [param m] sets off today's spot.
static func due(m: MapData, cell: Vector2i, day: String, records: Dictionary, era: int = -1) -> bool:
	return active(m, day, records, era) and spot(m, day) == cell

static func mark_done(records: Dictionary, map_id: String, day: String) -> void:
	var done: Dictionary = records.get(RECORD, {})
	done[map_id] = day
	records[RECORD] = done

## The rarest spawn of table [param id] (lowest weight; first on a tie), or {}.
static func rarest(id: String) -> Dictionary:
	var best: Dictionary = {}
	for s: Dictionary in EncounterTable.spawns_on(id, ""):
		if best.is_empty() or int(s.get("weight", 1)) < int(best.get("weight", 1)):
			best = s
	return best

## The Spirling hiding in the spot: the rarest kind of the table, RING_BONUS rings above its
## usual top ring, Gleam GLEAM_MULT times as likely.
static func make_wild(id: String, rng: RandomNumberGenerator, chain: Dictionary = {}) -> Spirling:
	var s: Dictionary = rarest(id)
	var sd: SpirlingData = Database.species(str(s.get("species", ""))) if not s.is_empty() else null
	if sd == null:
		return null
	var wild := Spirling.new(sd, int(s.get("max", 4)) + RING_BONUS, rng)
	wild.gleam = GleamRules.roll(rng, GleamRules.chain_for(chain, sd.species_name), GLEAM_MULT * ShopEffects.gleam_mult())
	return wild

## The shaking patch on the map: a few blades that sway back and forth.
class Mark extends Node2D:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var tile: float = float(TilesetFactory.TILE)
		var sway: float = sin(_t * 18.0) * 2.0 if not Juice.reduced() else 0.0
		var ink: Color = UITheme.INK
		for i: int in 4:
			var x: float = 2.0 + i * (tile - 4.0) / 3.0
			draw_line(Vector2(x, tile - 1.0), Vector2(x + sway * (1.0 if i % 2 == 0 else -1.0), tile * 0.35), ink, 1.0)
		draw_circle(Vector2(tile * 0.5 + sway, tile * 0.2), 1.0, Color(1, 1, 0.85))
