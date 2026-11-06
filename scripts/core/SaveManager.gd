extends Node
## Autoload "SaveManager": versioned JSON saves in user://.
## - Writes to a temp file, checks that it reads back with the same SHA-256 checksum, keeps
##   the last three saves as rotating backups, then renames, so a crash mid-write never
##   corrupts the save (plan items 3633, 3634, 3637).
## - Checks the structure of every save before using it; a broken one never crashes the game,
##   the newest readable backup is loaded instead (items 3609, 3711).
## - Migrates old saves step by step by "save_version".
## - Saves when the app is paused / backgrounded (mobile OSes kill background apps).
## - Never loads .tres files as saves (loading resources can run embedded scripts).

const SAVE_VERSION: int = 4
const SLOT_PATH: String = "user://save_1.json"
## Three save slots (item 58). Slot 1 keeps the old file name, so existing saves stay in it.
const SLOTS: int = 3
const SETTINGS_PATH: String = "user://settings.json"

## How many rotating backups each slot keeps (.bak.json is the newest, then .bak2, .bak3).
const BACKUPS: int = 3
## First line of a save with a checksum: the hash covers the rest of the file (see seal()).
const CHECKSUM_PREFIX: String = "{\n\t\"_sha256\": \""

signal saved
signal save_failed(reason: String)
## The main file of the slot was damaged and a backup was loaded instead.
signal recovered(path: String)

## True when the last load_game() had to use a backup (the title screen tells the player).
var last_load_recovered: bool = false

## save_version -> Callable(Dictionary) -> Dictionary that upgrades to save_version + 1.
var _migrations: Dictionary[int, Callable] = {
	0: _migrate_0_to_1,
	1: _migrate_1_to_2,
	2: _migrate_2_to_3,
	3: _migrate_3_to_4,
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
## Active slot (1..SLOTS); remembered in the settings file.
var slot: int = 1

static func path_for_slot(n: int) -> String:
	return "user://save_%d.json" % clampi(n, 1, SLOTS)

func set_slot(n: int) -> void:
	slot = clampi(n, 1, SLOTS)
	slot_path = path_for_slot(slot)

## Summary for a slot without switching to it ("" = empty or unreadable).
func slot_summary(n: int) -> String:
	var old: String = slot_path
	slot_path = path_for_slot(n)
	var s: String = save_summary() if has_save() else ""
	slot_path = old
	return s

## The slot whose save was written most recently, or 0 if none has a save.
func latest_slot() -> int:
	var best: int = 0
	var best_time: int = -1
	for n: int in range(1, SLOTS + 1):
		var p: String = path_for_slot(n)
		if FileAccess.file_exists(p):
			var t: int = FileAccess.get_modified_time(p)
			if t > best_time:
				best_time = t
				best = n
	return best
var settings_path: String = SETTINGS_PATH

func _ready() -> void:
	load_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.in_game:
			save_game()
		save_settings()

func has_save() -> bool:
	for p: String in save_paths(slot_path):
		if FileAccess.file_exists(p):
			return true
	return false

func backup_path() -> String:
	return backup_path_for(slot_path, 1)

## Backup [param n] (1 = newest) of [param path]. Backup 1 keeps the old ".bak.json" name.
static func backup_path_for(path: String, n: int) -> String:
	return path.get_basename() + (".bak.json" if n <= 1 else ".bak%d.json" % n)

## The main file followed by its backups, newest first.
static func save_paths(path: String) -> Array[String]:
	var out: Array[String] = [path]
	for n: int in range(1, BACKUPS + 1):
		out.append(backup_path_for(path, n))
	return out

func temp_path() -> String:
	return slot_path + ".tmp"

## Builds the full save dictionary.
func build_save() -> Dictionary:
	var d: Dictionary = GameState.to_dict()
	d["era"] = EraManager.to_dict()
	d["save_version"] = SAVE_VERSION
	d["saved_at"] = Time.get_datetime_string_from_system(true)
	return d

## Saves the active slot to the local cache and sends it to the server (Online).
func save_game() -> bool:
	var ok: bool = write_save(slot_path, build_save())
	# Only the real slot files go online (tests point slot_path somewhere else).
	if ok and slot_path == path_for_slot(slot):
		Online.note_saved(slot)
	return ok

## Writes a save dictionary with its checksum (used for the slots and for saves from the server).
func write_save(path: String, d: Dictionary) -> bool:
	var clean: Dictionary = d.duplicate(true)
	clean.erase("_sha256")
	return write_atomic(path, seal(JSON.stringify(clean, "\t")))

## Adds a SHA-256 checksum of [param text] (a JSON object) as its first key.
static func seal(text: String) -> String:
	if not text.begins_with("{\n"):
		return text
	return CHECKSUM_PREFIX + text.sha256_text() + "\",\n" + text.substr(2)

## Checks the checksum of a sealed save. Files without one (older builds) count as unchecked
## but fine: a cut-off one still fails to parse.
static func checksum_ok(text: String) -> bool:
	if not text.begins_with(CHECKSUM_PREFIX):
		return true
	var start: int = CHECKSUM_PREFIX.length()
	var want: String = text.substr(start, 64)
	if text.substr(start + 64, 3) != "\",\n":
		return false
	return ("{\n" + text.substr(start + 67)).sha256_text() == want

## Writes [param text] to [param path] via temp file, read-back check, rotating backups and rename.
func write_atomic(path: String, text: String) -> bool:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		save_failed.emit("cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# Read it back before touching the old copies: a full disk or a cut-off write is caught
	# here while the backups are still intact (item 3637).
	if FileAccess.get_file_as_string(tmp) != text or not checksum_ok(FileAccess.get_file_as_string(tmp)):
		DirAccess.remove_absolute(tmp)
		save_failed.emit("read-back check failed for %s" % tmp)
		return false
	if FileAccess.file_exists(path):
		_rotate_backups(path)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		save_failed.emit("rename failed: %s" % error_string(err))
		return false
	saved.emit()
	return true

## Shifts the backups down by one (.bak2 -> .bak3, .bak -> .bak2) and makes the current file .bak.
func _rotate_backups(path: String) -> void:
	var oldest: String = backup_path_for(path, BACKUPS)
	if FileAccess.file_exists(oldest):
		DirAccess.remove_absolute(oldest)
	for n: int in range(BACKUPS - 1, 0, -1):
		var p: String = backup_path_for(path, n)
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(p, backup_path_for(path, n + 1))
	DirAccess.rename_absolute(path, backup_path_for(path, 1))

## Reads, migrates and applies the save. Falls back to the newest readable backup if the main
## file is broken (and says so through [member last_load_recovered] and [signal recovered]).
func load_game() -> bool:
	last_load_recovered = false
	var main_there: bool = FileAccess.file_exists(slot_path)
	for path: String in save_paths(slot_path):
		var d: Variant = read_save(path)
		if d is Dictionary:
			apply_save(d)
			if path != slot_path and main_there:
				last_load_recovered = true
				recovered.emit(path)
			return true
	return false

func read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return parse_save(FileAccess.get_file_as_string(path))

## Checks, parses, cleans and migrates the text of a save. Returns null if it cannot be used.
func parse_save(text: String) -> Variant:
	if not checksum_ok(text):
		return null
	# JSON.new().parse() reports errors quietly (parse_string logs them), which keeps a corrupt
	# save from spamming the log before we fall back to the backup.
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var d: Dictionary = json.data
	d.erase("_sha256")
	var migrated: Variant = migrate(sanitize(d))
	return sanitize(migrated) if migrated is Dictionary else null

# --- Structure check (item 3609) ------------------------------------------------------------
# A save can come from an older build, the server or a damaged file. Every value the loaders
# read is checked for its type here; a wrong one is dropped so the loader uses its default.

const DICT_KEYS: Array[String] = ["tamer", "spirlog", "inventory", "flags", "matchups", "rests",
	"records", "switches", "era", "world"]
const LIST_KEYS: Array[String] = ["rifts", "party", "storage", "sanctuary"]
const CELL_KEYS: Array[String] = ["cell", "heal_cell"]
const NUMBER_KEYS: Array[String] = ["difficulty", "money", "play_time", "save_version"]
const TEXT_KEYS: Array[String] = ["region", "map", "facing", "starter", "saved_at"]
const FLAG_KEYS: Array[String] = ["iron_oath"]
## Chain glyph in PixelFont, shown before the slot line of an Iron Oath save.
const OATH_GLYPH: String = "\ue003"
const SPIRLING_LISTS: Array[String] = ["party", "storage", "sanctuary"]
const SPIRLING_NUMBERS: Array[String] = ["level", "xp", "hp"]
const SPIRLING_TEXTS: Array[String] = ["species", "nickname", "uid", "held"]

static func _is_number(v: Variant) -> bool:
	return (v is int or v is float or v is bool) and not (v is float and (is_nan(v) or is_inf(v)))

static func _is_scalar(v: Variant) -> bool:
	return v is String or v is StringName or _is_number(v)

## Drops every value of [param d] whose type the loaders cannot use. Returns [param d].
static func sanitize(d: Dictionary) -> Dictionary:
	for k: String in DICT_KEYS:
		if d.has(k) and not d[k] is Dictionary:
			d.erase(k)
	for k: String in LIST_KEYS:
		if d.has(k) and not d[k] is Array:
			d.erase(k)
	for k: String in CELL_KEYS:
		if d.has(k) and not (d[k] is Array and (d[k] as Array).size() >= 2 and _is_number(d[k][0]) and _is_number(d[k][1])):
			d.erase(k)
	for k: String in NUMBER_KEYS:
		if d.has(k) and not _is_number(d[k]):
			d.erase(k)
	for k: String in TEXT_KEYS + FLAG_KEYS:
		if d.has(k) and not _is_scalar(d[k]):
			d.erase(k)
	for k: String in FLAG_KEYS:
		if d.has(k) and d[k] is String:
			d[k] = d[k] == "true"
	if d.has("rifts"):
		var rifts: Array = []
		for r: Variant in d.rifts:
			if _is_scalar(r):
				rifts.append(str(r))
		d["rifts"] = rifts
	for k: String in ["inventory", "matchups"]:
		if d.has(k):
			_keep_numbers(d[k])
	if d.has("tamer"):
		var t: Dictionary = d.tamer
		if t.has("name") and not _is_scalar(t.name):
			t.erase("name")
		for k: String in ["color", "look"]:
			if t.has(k) and not _is_number(t[k]):
				t.erase(k)
	if d.has("era"):
		_keep_numbers(d.era)
	for k: String in SPIRLING_LISTS:
		if not d.has(k):
			continue
		var kept: Array = []
		for s: Variant in d[k]:
			if s is Dictionary:
				kept.append(_sanitize_spirling(s))
		d[k] = kept
	return d

static func _keep_numbers(d: Dictionary) -> void:
	for key: Variant in d.keys():
		if not _is_number(d[key]):
			d.erase(key)

static func _sanitize_spirling(s: Dictionary) -> Dictionary:
	for k: String in SPIRLING_NUMBERS:
		if s.has(k) and not _is_number(s[k]):
			s.erase(k)
	for k: String in SPIRLING_TEXTS:
		if s.has(k) and not _is_scalar(s[k]):
			s.erase(k)
	if s.has("prism") and not _is_number(s.prism):
		s.erase("prism")
	if s.has("spark"):
		if s.spark is Dictionary:
			_keep_numbers(s.spark)
		else:
			s.erase("spark")
	if s.has("moves"):
		if s.moves is Array:
			var mv: Array = []
			for m: Variant in s.moves:
				if _is_scalar(m):
					mv.append(str(m))
			s["moves"] = mv
		else:
			s.erase("moves")
	return s

## Upgrades [param d] to SAVE_VERSION. Returns null if it is from a newer game version.
func migrate(d: Dictionary) -> Variant:
	var v: int = maxi(int(d.get("save_version", 0)), 0)
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

## Version 2 -> 3: originality pass. Renamed moves keep working, the storage flag got a new
## name, and the team is five Spirlings now (extras rest in storage).
const MOVE_RENAMES_V3: Dictionary[String, String] = {
	"Headlong Charge": "Bowl Over", "Tailwind Step": "Drift Step", "Clear Mind": "Still Thought",
	"Surge Fang": "Storm Gnash", "Eclipse Fang": "Dusk Gnaw", "Brine Fang": "Salt Snap",
	"Brine Jet": "Spindrift Shot", "Gloom Pulse": "Gloom Ripple", "Quake Stomp": "Tremor Thud",
	"Boulder Slam": "Cairn Crash", "Tidal Crash": "Breaker Plunge", "Flare Lash": "Kiln Strike",
	"Blaze Coil": "Furnace Spiral", "Cyclone Edge": "Gale Scythe", "Shell Up": "Hunker Down",
}
const TEAM_SIZE_V3: int = 5

func _migrate_2_to_3(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var flags: Dictionary = out.get("flags", {})
	if flags.has("pc_unlocked"):
		flags.erase("pc_unlocked")
		flags["storage_remote"] = true
	out["flags"] = flags
	for key: String in ["party", "storage", "sanctuary"]:
		for s: Variant in out.get(key, []):
			if s is Dictionary and (s as Dictionary).has("moves"):
				var mv: Array = []
				for m: Variant in s.moves:
					mv.append(MOVE_RENAMES_V3.get(str(m), str(m)))
				s["moves"] = mv
	var party: Array = out.get("party", [])
	if party.size() > TEAM_SIZE_V3:
		var storage: Array = out.get("storage", [])
		storage.append_array(party.slice(TEAM_SIZE_V3))
		out["storage"] = storage
		out["party"] = party.slice(0, TEAM_SIZE_V3)
	return out

## Version 3 -> 4: Spirlings get stored temperaments and their story (plan area 1, items 4,
## 5 and 7). The temperament each one had (read from its uid over six kinds) is kept, so no old
## temperament changes. Spirlog entries get the new fields.
const SPIRLING_DEFAULTS_V4: Dictionary = {
	"variant": "", "origin_map": "", "met_ring": 0, "met_day": 0, "lineage": [], "echo_streak": 0,
}

func _migrate_3_to_4(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	for key: String in ["party", "storage", "sanctuary"]:
		for s: Variant in out.get(key, []):
			if not s is Dictionary:
				continue
			var sd: Dictionary = s
			if not sd.has("temper"):
				sd["temper"] = Spirling.legacy_temper(str(sd.get("uid", "")))
			for f: String in SPIRLING_DEFAULTS_V4:
				if not sd.has(f):
					var v: Variant = SPIRLING_DEFAULTS_V4[f]
					sd[f] = v.duplicate() if v is Array else v
			if str(sd.origin_map).is_empty():
				sd["met_ring"] = int(sd.get("level", 1)) if int(sd.met_ring) <= 0 else sd.met_ring
	var log: Dictionary = {}
	for k: Variant in (out.get("spirlog", {}) as Dictionary):
		log[str(k)] = GameState.upgrade_spirlog_entry(out.spirlog[k])
	out["spirlog"] = log
	return out

## Short "where and how long" line for the title screen's Continue button, or "" if unreadable.
func save_summary() -> String:
	for path: String in save_paths(slot_path):
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
	var line: String = "%s  %d:%02d" % [place, secs / 3600, (secs / 60) % 60]
	# A small chain marks a journey under the Iron Oath (plan 3396).
	if d.get("iron_oath", false) is bool and bool(d.get("iron_oath", false)):
		line = OATH_GLYPH + " " + line
	return line

func delete_save() -> void:
	for p: String in save_paths(slot_path) + [temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func save_settings() -> void:
	var d: Dictionary = GameState.settings_to_dict()
	d["era"] = {"retro_filter": EraManager.retro_filter}
	d["slot"] = slot
	write_atomic(settings_path, JSON.stringify(d))

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		GameState.apply_volume()
		GameState.apply_display()
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if raw is Dictionary:
		GameState.settings_from_dict(raw)
		if slot_path == SLOT_PATH:
			set_slot(int(raw.get("slot", 1)))
		VirtualPad.apply_settings()
