extends SceneTree
## Golden images of the menu screens (plan item 2044), in English and German at 144x256.
## Needs a real display:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/ui_golden.gd -- compare
##   ... -- update      writes new goldens into tests/golden/ after a wanted change
## "compare" writes the current shots and red-marked diffs to user://golden_out and exits 1
## when a screen differs in more than MAX_DIFF of its pixels.

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	# Autoload classes are only known once the tree runs, so the work lives in a node script.
	var runner: Node = load("res://tools/ui_golden_runner.gd").new()
	runner.set("mode", "update" if "update" in OS.get_cmdline_user_args() else "compare")
	root.add_child(runner)
