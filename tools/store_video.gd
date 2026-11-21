extends SceneTree
## App preview video (plan Chimora 100, item 89): real gameplay, every frame saved at the game's own
## resolution (Movie Maker would squeeze the later eras into the first era's 144 x 256), then
## scaled and encoded to the App Store preview format by tools/store/make_store_video.py.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/store_video.gd -- /tmp/video
## Order: Era V 3v3 battle, a Gleam entrance, the unfurl moment, one town in Eras I to IV, a live duel.

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/store_video_runner.gd").new()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		runner.set("out", args[0])
	root.add_child(runner)
