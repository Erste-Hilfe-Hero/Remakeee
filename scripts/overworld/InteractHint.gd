class_name InteractHint
extends Node2D
## A small mark above the tile in front of the Wayfarer when A does something there: a speech
## bubble for people, lines for signs, a hand-hold for gear spots and ladders (plan item 2029).

enum Kind { NONE, TALK, READ, GEAR }

## Returns the kind of thing at [param target] for a Wayfarer standing on [param from].
static func kind_at(ow: Node, from: Vector2i, target: Vector2i) -> Kind:
	var m: MapData = ow.map
	if m == null:
		return Kind.NONE
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
	if k != kind:
		kind = k
		queue_redraw()
	visible = kind != Kind.NONE
	if visible:
		position = GridWalker.cell_to_pos(p.facing_cell()) + Vector2(GridWalker.TILE / 2.0 - 4, -9)

func _draw() -> void:
	if kind == Kind.NONE:
		return
	# A 9x7 bubble with a tail, ink on paper.
	draw_rect(Rect2(0, 0, 9, 6), UITheme.BG)
	draw_rect(Rect2(0.5, 0.5, 8, 5), UITheme.INK, false, 1.0)
	draw_rect(Rect2(3, 6, 2, 1), UITheme.INK)
	match kind:
		Kind.TALK:
			for x: int in [2, 4, 6]:
				draw_rect(Rect2(x, 3, 1, 1), UITheme.INK)
		Kind.READ:
			draw_rect(Rect2(2, 2, 5, 1), UITheme.INK)
			draw_rect(Rect2(2, 4, 3, 1), UITheme.INK)
		Kind.GEAR:
			draw_rect(Rect2(4, 2, 1, 2), UITheme.INK)
			draw_rect(Rect2(2, 2, 1, 2), UITheme.INK)
			draw_rect(Rect2(6, 2, 1, 2), UITheme.INK)
