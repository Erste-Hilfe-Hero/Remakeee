extends SceneTree
## Whole-world connectivity report (scripts/core/WorldGraph.gd):
##   godot --headless --path . -s res://tools/maps/world_graph.gd
## Prints every problem and exits 1 if there is one. CI runs the same checks in
## tests/unit/test_world_graph.gd; tests/unit/test_world_walk.gd walks every warp in the real Overworld.

func _initialize() -> void:
	var g: GDScript = load("res://scripts/core/WorldGraph.gd")
	var out: PackedStringArray = g.call("problems")
	for p: String in out:
		print(p)
	print("world graph: %d problems" % out.size())
	quit(1 if not out.is_empty() else 0)
