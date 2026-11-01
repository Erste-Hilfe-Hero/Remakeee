extends Node
## Autoload "SaveManager": versioned JSON saves in user://.
## - Writes to a temp file, keeps the previous save as a backup, then renames, so a crash
##   mid-write never corrupts the save.
## - Migrates old saves step by step by "save_version".
## - Saves when the app is paused / backgrounded (mobile OSes kill background apps).
## - Never loads .tres files as saves (loading resources can run embedded scripts).

const SAVE_VERSION: int = 2
const SLOT_PATH: String = "user://save_1.json"
const SETTINGS_PATH: String = "user://settings.json"

signal saved
signal save_failed(reason: String)

## save_version -> Callable(Dictionary) -> Dictionary that upgrades to save_version + 1.
var _migrations: Dictionary[int, Callable] = {
	0: _migrate_0_to_1,
	1: _migrate_1_to_2,
}
## Act I world rebuild (save version 2): old map id -> [new map id, safe cell].
const MAP_RENAMES_V2: Dictionary[String, Array] = {
	"home": ["lighthouse", [4, 4]],
	"start_town": ["brindlewick", [5, 5]],
	"kestra_home": ["map_house", [4, 5]],
	"route_1": ["fernstair", [5, 23]],
	"route_2": ["crowcrest", [5, 21]],
	"thornridge": ["thornridge", [6, 13]],
}
## Overridable for tests.
var slot_path: String = SLOT_PATH
var settings_path: String = SETTINGS_PATH

func _ready() -> void:
	load_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.in_game:
			save_game()
		save_settings()

func has_save() -> bool:
	return FileAccess.file_exists(slot_path) or FileAccess.file_exists(backup_path())

func backup_path() -> String:
	return slot_path.get_basename() + ".bak.json"

func temp_path() -> String:
	return slot_path + ".tmp"

## Builds the full save dictionary.
func build_save() -> Dictionary:
	var d: Dictionary = GameState.to_dict()
	d["era"] = EraManager.to_dict()
	d["save_version"] = SAVE_VERSION
	d["saved_at"] = Time.get_datetime_string_from_system(true)
	return d

func save_game() -> bool:
	return write_atomic(slot_path, JSON.stringify(build_save(), "\t"))

## Writes [param text] to [param path] via temp file + backup + rename.
func write_atomic(path: String, text: String) -> bool:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		save_failed.emit("cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var backup: String = path.get_basename() + ".bak.json"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(path, backup)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		save_failed.emit("rename failed: %s" % error_string(err))
		return false
	saved.emit()
	return true

## Reads, migrates and applies the save. Falls back to the backup if the main file is broken.
func load_game() -> bool:
	for path: String in [slot_path, backup_path()]:
		var d: Variant = read_save(path)
		if d is Dictionary:
			apply_save(d)
			return true
	return false

func read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	# JSON.new().parse() reports errors quietly (parse_string logs them), which keeps a corrupt
	# save from spamming the log before we fall back to the backup.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return null
	return migrate(json.data)

## Upgrades [param d] to SAVE_VERSION. Returns null if it is from a newer game version.
func migrate(d: Dictionary) -> Variant:
	var v: int = int(d.get("save_version", 0))
	if v > SAVE_VERSION:
		return null
	while v < SAVE_VERSION:
		d = _migrations[v].call(d)
		v += 1
		d["save_version"] = v
	return d

func apply_save(d: Dictionary) -> void:
	Database.load_all()
	GameState.from_dict(d)
	EraManager.from_dict(d.get("era", {}))

## Version 0 = the scaffold's GameState format: {"region", "rifts", "difficulty"} only.
func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	if not out.has("party"):
		out["party"] = []
	if not out.has("map"):
		out["map"] = "lighthouse"
	if out.has("rifts") and not out.has("flags"):
		var flags: Dictionary = {}
		for r: Variant in out.rifts:
			flags["%s_sealed" % r] = true
		out["flags"] = flags
	return out

## Version 1 -> 2: the world was rebuilt (lighthouse start, named paths instead of routes).
## Players on a renamed or reshaped map are moved to a safe cell on its replacement.
func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var m: String = str(out.get("map", "lighthouse"))
	if MAP_RENAMES_V2.has(m):
		out["map"] = MAP_RENAMES_V2[m][0]
		out["cell"] = MAP_RENAMES_V2[m][1]
	var hm: String = str(out.get("heal_map", "lighthouse"))
	if hm == "thornridge":
		out["heal_cell"] = [9, 4]
	elif MAP_RENAMES_V2.has(hm):
		out["heal_map"] = MAP_RENAMES_V2[hm][0]
		out["heal_cell"] = MAP_RENAMES_V2[hm][1]
	var flags: Dictionary = out.get("flags", {})
	if flags.has("rival_kestra_1"):
		flags["kestra_spar"] = true
	if flags.has("mom_gift"):
		flags["aldo_gift"] = true
	if flags.has("route1_gift"):
		flags["fern_gift"] = true
	out["flags"] = flags
	return out

## Short "where and how long" line for the title screen's Continue button, or "" if unreadable.
func save_summary() -> String:
	for path: String in [slot_path, backup_path()]:
		var d: Variant = read_save(path)
		if d is Dictionary:
			return summary_line(d)
	return ""

static func summary_line(d: Dictionary) -> String:
	var map_id: String = str(d.get("map", ""))
	var place: String = map_id.replace("_", " ").capitalize()
	var m: MapData = MapData.load_map(map_id) if MapData.exists(map_id) else null
	if m != null and not m.display_name.is_empty():
		place = m.display_name
	var secs: int = int(float(d.get("play_time", 0.0)))
	return "%s  %d:%02d" % [place, secs / 3600, (secs / 60) % 60]

func delete_save() -> void:
	for p: String in [slot_path, backup_path(), temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func save_settings() -> void:
	var d: Dictionary = GameState.settings_to_dict()
	d["era"] = {"retro_filter": EraManager.retro_filter}
	write_atomic(settings_path, JSON.stringify(d))

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		GameState.apply_volume()
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if raw is Dictionary:
		GameState.settings_from_dict(raw)
		VirtualPad.apply_settings()
