extends SceneTree
## Writes the save and settings fixture of one release with that release's own code. It is copied
## into a checkout of the release commit and run there by make_release_fixture.sh:
##   godot --headless --path <checkout> -s res://release_journey.gd -- <difficulty> <out_dir> <version>
## Autoloads and classes are reached by path so the same file parses on every release since 1.1.0.

## [species, ring] of the team (the lead first) and of storage; tests/unit/test_save_releases.gd
## checks the same lists.
const PARTY: Array = [["Kindlop", 42], ["Zippit", 31], ["Wickit", 19], ["Puddlet", 12], ["Mirkmole", 8]]
const STORAGE: Array = [["Puddlet", 75], ["Zippit", 3], ["Wickit", 61]]
const SETTINGS: Dictionary = {"text_speed": 2, "volume": 0.55, "music_volume": 0.4, "vibration": 1,
	"language": "de", "reduce_motion": true, "tips": false, "weather": false}

var _done: bool = false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_write(int(args[0]), args[1], args[2])
	quit(0)
	return true

func _write(difficulty: int, out_dir: String, version: String) -> void:
	var db: GDScript = load("res://scripts/core/Database.gd")
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	var spirling: GDScript = load("res://scripts/battle/Spirling.gd")
	db.load_all()
	gs.new_game(difficulty, "Ali", 2, "", 1, 2, 3)
	gs.starter = "Kindlop"
	gs.set_flag("got_starter")
	gs.current_map = "lighthouse"
	var rng := RandomNumberGenerator.new()
	rng.seed = 132
	for i: int in PARTY.size():
		var s: Object = spirling.new(db.species(PARTY[i][0]), PARTY[i][1], rng)
		if i == 0:
			s.nickname = "Funke"
			gs.party.append(s)
		else:
			gs.receive_spirling(s)
		gs.mark_seen(PARTY[i][0], true)
	for e: Array in STORAGE:
		gs.storage.append(spirling.new(db.species(e[0]), e[1], rng))
	gs.storage[1].gleam = true
	if "gleam_kind" in gs.storage[1]:
		gs.storage[1].gleam_kind = "classic"
	gs.mark_seen("Fizzlet")
	gs.add_item("kin_charm", 5)
	gs.add_item("tonic", 7)
	gs.money = 12345
	gs.rifts_sealed.assign(["cinder", "tide"])
	for f: String in ["rift_cinder_sealed", "rift_tide_sealed", "aldo_gift", "kestra_spar", "storage_remote"]:
		gs.set_flag(f)
	gs.current_map = "brindlewick"
	gs.player_cell = Vector2i(5, 5)
	gs.facing = "left"
	gs.heal_map = "brindlewick"
	gs.heal_cell = Vector2i(5, 5)
	gs.visited_rests = {"brindlewick": [5, 5]}
	gs.play_time = 7384.0
	var d: Dictionary = sm.build_save()
	d["saved_at"] = "2026-11-20T10:00:00"
	d.erase("_sha256")
	_store(out_dir.path_join("save_%s.json" % version), sm.seal(JSON.stringify(d, "\t")))
	var st: Dictionary = gs.settings_to_dict()
	for k: String in SETTINGS:
		if st.has(k):
			st[k] = SETTINGS[k]
	st["era"] = {"retro_filter": 0}
	st["slot"] = 1
	_store(out_dir.path_join("settings_%s.json" % version), JSON.stringify(st))

func _store(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wrote ", path)
