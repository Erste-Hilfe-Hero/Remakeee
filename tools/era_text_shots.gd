extends SceneTree
## The dialogue box and the place banner in Eras II to V, English and German
## (docs/ERA_FEEL_TEXT.md): the era's frame, its own font, the speaker's head on the name plate
## (Era IV) or portrait (Era V). Needs a real display:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/era_text_shots.gd -- compare
##   ... -- update        writes new goldens into tests/golden/era_text/ after a wanted change
##   ... -- shots DIR     writes 2x review shots (all five eras, the spiral warp half closed)
## "compare" writes the current shots and red-marked diffs to user://golden_out and exits 1
## when a screen differs in more than MAX_DIFF of its pixels.

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/era_text_shots_runner.gd").new()
	var mode: String = "compare"
	if "update" in args:
		mode = "update"
	elif "shots" in args:
		mode = "shots"
		var i: int = args.find("shots")
		if i + 1 < args.size():
			runner.set("shots_dir", args[i + 1])
	runner.set("mode", mode)
	root.add_child(runner)
