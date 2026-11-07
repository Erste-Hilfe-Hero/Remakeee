class_name InteractHint
extends Node2D
## A small mark above the tile in front of the Wayfarer when A does something there: a speech
## bubble for people, lines for signs, a hand-hold for gear spots and ladders (plan item 2029).
## In front of a spot whose gear the Wayfarer does not have yet, the mark is grey and shows
## that gear's own little sign, so the spot can be remembered for later (area 3 item 1061).

enum Kind { NONE, TALK, READ, GEAR, LOCKED }

## Tiny 5x3 signs of the gear (rows of "#"), drawn grey on a locked spot.
const GLYPHS: Dictionary[String, Array] = {
	"wading_boots": ["#....", "#....", "###.."],
	"climbing_pick": ["####.", "..#..", "..#.."],
	"grapple_line": ["#.#.#", ".#.#.", "....."],
	"storm_lantern": [".###.", ".#.#.", ".###."],
	"pry_bar": ["....#", "..#..", "#...."],
	"rope_ladder": ["#.#..", "###..", "#.#.."],
	"plank_bundle": ["#####", ".....", "#####"],
}

## Gear needed for [param target] from [param from] that the Wayfarer lacks, or "".
static func missing_gear(m: MapData, from: Vector2i, target: Vector2i) -> String:
	var need: String = ""
	var spot: Dictionary = m.gear_spot(from, target)
	if not spot.is_empty():
		need = str(spot.get("gear", ""))
	if need.is_empty():
		need = m.gear_needed_at(target)
	if need.is_empty() and m.in_bounds(target):
		need = str(TilesetFactory.GEAR_KINDS.get(m.kind_at(target), ""))
	return "" if need.is_empty() or GameState.has_gear(need) else need

## Returns the kind of thing at [param target] for a Wayfarer standing on [param from].
static func kind_at(ow: Node, from: Vector2i, target: Vector2i) -> Kind:
	var m: MapData = ow.map
	if m == null:
		return Kind.NONE
	if not missing_gear(m, from, target).is_empty():
		return Kind.LOCKED
	if not m.gear_spot(from, target).is_empty() or not m.ladder_at(target).is_empty():
		return Kind.GEAR
	if ow.npc_at(target) != null:
		return Kind.TALK
	if m.kind_at(target) == TilesetFactory.Kind.COUNTER and ow.npc_at(target + (target - from)) != null:
		return Kind.TALK
	if not m.sign_at(target, GameState.flags).is_empty():
		return Kind.READ
	return Kind.NONE

var ow: Node
var kind: Kind = Kind.NONE
## The gear a LOCKED mark stands for.
var gear: String = ""

func _ready() -> void:
	z_index = 20
	visible = false

func _process(_delta: float) -> void:
	if ow == null or ow.player == null:
		return
	var p: Player = ow.player
	var k: Kind = Kind.NONE
	if not ow.busy and not p.frozen:
		k = kind_at(ow, p.cell, p.facing_cell())
	var g: String = missing_gear(ow.map, p.cell, p.facing_cell()) if k == Kind.LOCKED else ""
	if k != kind or g != gear:
		kind = k
		gear = g
		queue_redraw()
	visible = kind != Kind.NONE
	if visible:
		position = GridWalker.cell_to_pos(p.facing_cell()) + Vector2(GridWalker.TILE / 2.0 - 4, -9)

func _draw() -> void:
	if kind == Kind.NONE:
		return
	# A 9x7 bubble with a tail, ink on paper (grey ink for a spot that needs gear).
	var ink: Color = UITheme.INK if kind != Kind.LOCKED else Color(UITheme.INK, 0.45)
	draw_rect(Rect2(0, 0, 9, 6), UITheme.BG)
	draw_rect(Rect2(0.5, 0.5, 8, 5), ink, false, 1.0)
	draw_rect(Rect2(3, 6, 2, 1), ink)
	match kind:
		Kind.TALK:
			for x: int in [2, 4, 6]:
				draw_rect(Rect2(x, 3, 1, 1), UITheme.INK)
		Kind.READ:
			draw_rect(Rect2(2, 2, 5, 1), UITheme.INK)
			draw_rect(Rect2(2, 4, 3, 1), UITheme.INK)
		Kind.LOCKED:
			var rows: Array = GLYPHS.get(gear, ["#.#.#", "#.#.#", "....."])
			for y: int in rows.size():
				for x: int in str(rows[y]).length():
					if str(rows[y])[x] == "#":
						draw_rect(Rect2(2 + x, 1 + y, 1, 1), ink)
		Kind.GEAR:
			draw_rect(Rect2(4, 2, 1, 2), UITheme.INK)
			draw_rect(Rect2(2, 2, 1, 2), UITheme.INK)
			draw_rect(Rect2(6, 2, 1, 2), UITheme.INK)
