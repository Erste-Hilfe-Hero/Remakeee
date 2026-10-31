class_name NPC
extends GridWalker
## A standing character. Talks using a dialogue reference; Tamers also carry a team (M5).

var npc_id: String = ""
var dialogue_ref: String = ""
var definition: Dictionary = {}

func setup(def: Dictionary) -> void:
	definition = def
	npc_id = str(def.get("id", ""))
	dialogue_ref = str(def.get("dialogue", ""))
	body_color = Color(str(def.get("color", "b04a4a")))
	place(Vector2i(int(def.x), int(def.y)), str(def.get("facing", "down")))

## Turns toward [param who_cell].
func face_toward(who_cell: Vector2i) -> void:
	var d: Vector2i = who_cell - cell
	if absi(d.x) > absi(d.y):
		face("right" if d.x > 0 else "left")
	else:
		face("down" if d.y > 0 else "up")
