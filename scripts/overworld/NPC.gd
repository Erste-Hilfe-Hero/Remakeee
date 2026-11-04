class_name NPC
extends GridWalker
## A standing character. Talks using a dialogue reference; Wayfarers also carry a team (M5).

var npc_id: String = ""
var dialogue_ref: String = ""
var definition: Dictionary = {}

func setup(def: Dictionary) -> void:
	definition = def
	npc_id = str(def.get("id", ""))
	dialogue_ref = str(def.get("dialogue", ""))
	body_color = Color(str(def.get("color", "b04a4a")))
	sprite_style = str(def.get("sprite", "villager"))
	place(Vector2i(int(def.x), int(def.y)), str(def.get("facing", "down")))

## Shows a "!" above the head when a Wayfarer spots the player.
var alert: bool = false:
	set(v):
		alert = v
		queue_redraw()

func _draw() -> void:
	super._draw()
	if alert:
		draw_rect(Rect2(6, -9, 4, 8), UITheme.BG)
		draw_rect(Rect2(6, -9, 4, 8), UITheme.INK, false, 1.0)
		draw_rect(Rect2(7, -8, 2, 4), UITheme.INK)
		draw_rect(Rect2(7, -3, 2, 1), UITheme.INK)

## Turns toward [param who_cell].
func face_toward(who_cell: Vector2i) -> void:
	var d: Vector2i = who_cell - cell
	if absi(d.x) > absi(d.y):
		face("right" if d.x > 0 else "left")
	else:
		face("down" if d.y > 0 else "up")
