class_name GoalMarks
extends Node2D
## Marks the doors and exits toward the current goal in the world (plan Chimora 100, item 38):
## a small arrow in front of each warp cell from QuestLog.goal_warps, pointing the way the
## Wayfarer walks through it, bobbing one pixel unless motion is reduced. UITheme colours, so
## it takes each era's ink and accent.

## Warp cells and the direction to walk through each ("up", "down", "left", "right").
var marks: Array[Dictionary] = []
var _t: float = 0.0

const DIRS: Dictionary = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

func _ready() -> void:
	name = "goal_marks"
	z_index = 20

## Marks the warps of [param m] at [param cells].
func show_cells(m: MapData, cells: Array[Vector2i]) -> void:
	marks.clear()
	if m != null:
		for c: Vector2i in cells:
			var w: Dictionary = m.warp_at(c)
			marks.append({"cell": c, "dir": str(w.get("facing", "down"))})
	queue_redraw()

func _process(delta: float) -> void:
	if marks.is_empty() or Juice.reduced():
		return
	var before: int = int(_t * 3.0) % 2
	_t += delta
	if int(_t * 3.0) % 2 != before:
		queue_redraw()

func _draw() -> void:
	var bob: float = 0.0 if Juice.reduced() else float(int(_t * 3.0) % 2)
	var half: float = GridWalker.TILE / 2.0
	for mk: Dictionary in marks:
		var d: Vector2 = DIRS.get(str(mk.dir), Vector2.DOWN)
		# A solid ink arrow (accent core) half a tile in front of the warp, pointing into it.
		var c: Vector2 = (GridWalker.cell_to_pos(mk.cell) + Vector2(half, half) - d * (half + 3.0) + d * bob).round()
		var side: Vector2 = Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 4.0, c - d * 2.0 + side * 5.0, c - d * 2.0 - side * 5.0]), UITheme.INK)
		draw_colored_polygon(PackedVector2Array([c + d * 1.5, c - d * 0.5 + side * 2.5, c - d * 0.5 - side * 2.5]), UITheme.ACCENT)
