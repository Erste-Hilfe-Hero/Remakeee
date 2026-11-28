extends SceneTree
## Store preview of the "Mine!" bond (release 1.3.2): the real game, played by a script, recorded
## with Godot's Movie Maker at a fixed frame rate. Order: Route 1 in the rain, a wild Zephlet,
## one art, the Kin Charm, the Mine! bar filled with taps, the bond, the Team list with the new
## Spirling, two more places and skies, the shop's Looks tab.
## Movie Maker writes every frame at the project's base size (144 x 256), but ScreenFit draws the
## view at window / whole pixel scale, so frames would be squeezed. Give the recording the view's
## size in an untracked override.cfg (148 x 320 for an 886 x 1920 window, 154 x 274 for 1080 x 1920;
## the runner prints both sizes and complains if they differ), record, delete override.cfg:
##   printf '[display]\nwindow/size/viewport_width=148\nwindow/size/viewport_height=320\n' > override.cfg
##   xvfb-run -a -s "-screen 0 2200x2200x24" godot --path . --rendering-driver opengl3 \
##     --resolution 886x1920 --fixed-fps 30 --write-movie /tmp/bond/f.png -s res://tools/bond_video.gd
##   rm override.cfg
## Then scale up by whole pixels and encode (App Preview: H.264, 30 fps, 886 x 1920, AAC stereo):
##   ffmpeg -framerate 30 -i /tmp/bond/f%08d.png -i /tmp/bond/f.wav -vf "scale=888:1920:flags=neighbor,crop=886:1920" \
##     -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -crf 16 -r 30 -c:a aac -b:a 256k -ac 2 -shortest preview.mp4

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	root.add_child(load("res://tools/bond_video_runner.gd").new())
