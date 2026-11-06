extends GutTest
## No plain linear tween for movement or fades (plan area 6, item 2245). Linear is the default
## of tween_property / tween_method, so every visual tweener outside Juice must get a curve via
## Juice.shaped or set_trans. Bars that must fill evenly and audio fades are listed here.

## file: reason it may stay linear
const ALLOWED: Dictionary = {
	"res://scripts/battle/presenter/InfoStrip.gd": "power bar fills evenly",
	"res://scripts/battle/presenter/MiniStrip.gd": "power bar fills evenly",
	"res://scripts/overworld/TripScene.gd": "trip progress bar",
	"res://scripts/core/Sound.gd": "volume fades",
	"res://scripts/ui/UnfurlSequence.gd": "reduced-motion cross-fade",
	"res://scripts/ui/Toast.gd": "area 8 notice, steady fade out",
	"res://scripts/overworld/Overworld.gd": "grapple rope pulls; map fades use Juice.shaped",
}

func _scripts(dir: String, out: Array[String]) -> void:
	for f: String in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			_scripts(dir + f, out)
		elif f.ends_with(".gd"):
			out.append(dir + f)

func test_visual_tweens_have_a_curve() -> void:
	var files: Array[String] = []
	_scripts("res://scripts/", files)
	assert_gt(files.size(), 50)
	var bad: Array[String] = []
	for path: String in files:
		if path.ends_with("/Juice.gd") or ALLOWED.has(path):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var l: String = lines[i]
			if not (".tween_property(" in l or ".tween_method(" in l):
				continue
			if "TRANS_LINEAR" in l or not ("set_trans" in l or "Juice.shaped" in l):
				# A multi-line tween_method closes a few lines further down.
				var tail: String = "\n".join(lines.slice(i, mini(i + 6, lines.size())))
				if "TRANS_LINEAR" in tail or not ("set_trans" in tail or "Juice.shaped" in tail):
					bad.append("%s:%d" % [path, i + 1])
	assert_eq(bad, [] as Array[String], "linear tweens: %s" % ", ".join(bad))
