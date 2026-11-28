extends SceneTree
## Golden images of the battle screen (KAMPF_PLAN_1000 item 937): the settled command menu and
## the open art info card, 1v1 and 2v2, in Era I and Era V, English and German. Needs a real display:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/battle_ui_golden.gd -- compare
##   ... -- update      writes new goldens into tests/golden/battle_ui/ after a wanted change
## "compare" writes the current shots and red-marked diffs to user://golden_out and exits 1
## when a screen differs in more than MAX_DIFF of its pixels.

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/battle_ui_golden_runner.gd").new()
	runner.set("mode", "update" if "update" in OS.get_cmdline_user_args() else "compare")
	root.add_child(runner)
