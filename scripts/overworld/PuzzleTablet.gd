class_name PuzzleTablet
extends NPC
## A riddle stone of PuzzleSpots: a small carved slab drawn in code (no sprite sheet), standing
## where data/puzzle_spots.json puts it. A solved stone shows a lit mark.

const STONE: Color = Color("9a948a")
const STONE_DARK: Color = Color("6e685f")
const GLOW: Color = Color("f2c14e")

var puzzle_id: String = ""

func setup(def: Dictionary) -> void:
	super.setup(def)
	puzzle_id = str(def.get("puzzle", ""))

func _draw() -> void:
	var ink: Color = UITheme.INK
	draw_rect(Rect2(3, 3, 10, 12), STONE)
	draw_rect(Rect2(4, 2, 8, 1), STONE)
	draw_rect(Rect2(3, 13, 10, 2), STONE_DARK)
	draw_rect(Rect2(3, 3, 10, 12), ink, false, 1.0)
	draw_line(Vector2(4, 2), Vector2(12, 2), ink, 1.0)
	for y: int in [6, 8, 10]:
		draw_line(Vector2(5, y), Vector2(11, y), STONE_DARK, 1.0)
	if PuzzleSpots.solved(puzzle_id):
		draw_rect(Rect2(7, 4, 2, 1), GLOW)
