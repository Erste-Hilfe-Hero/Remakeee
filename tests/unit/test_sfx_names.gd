extends GutTest
## Plan area 6, item 2561: every sound named in code (Sound.sfx("...")) has a file in
## audio/sfx/, and every file there is used: named as a quoted string somewhere in scripts/,
## or one of the families built from a name ("hit_<element>", "travel_<element>",
## "step_<ground>_<take>"), or a file of an era sound set in data/era_audio.json.

const FAMILIES: Array[String] = ["hit_", "travel_", "step_"]

var _sources: String = ""

func before_all() -> void:
	var parts: PackedStringArray = []
	_collect("res://scripts", parts)
	_sources = "\n".join(parts)

func _collect(dir: String, out: PackedStringArray) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(FileAccess.get_file_as_string(dir.path_join(f)))
	for d: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)

func _sfx_files() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at("res://audio/sfx"):
		if f.ends_with(".wav"):
			out.append(f.get_basename())
	return out

func test_sources_were_read() -> void:
	assert_gt(_sources.length(), 10000)

func test_every_named_sound_has_a_file() -> void:
	var re := RegEx.create_from_string("sfx\\(\"([a-z0-9_]+)\"")
	var named: Dictionary = {}
	for m: RegExMatch in re.search_all(_sources):
		named[m.get_string(1)] = true
	assert_gt(named.size(), 20)
	for n: String in named:
		assert_true(FileAccess.file_exists(Sound.SFX_DIR % n), "audio/sfx/%s.wav" % n)

## Files named by the era sound sets (data/era_audio.json) are used through Sound.sfx_file().
func _era_files() -> Dictionary:
	var out: Dictionary = {}
	for era: String in (Sound.era_audio().get("eras", {}) as Dictionary):
		for f: Variant in (Sound.era_spec(int(era)).get("sfx", {}) as Dictionary).values():
			out[str(f)] = true
	return out

func test_every_file_is_used() -> void:
	var era_files: Dictionary = _era_files()
	for n: String in _sfx_files():
		var family: bool = false
		for p: String in FAMILIES:
			family = family or n.begins_with(p)
		if family or era_files.has(n):
			continue
		assert_true(_sources.contains("\"%s\"" % n), "audio/sfx/%s.wav is used" % n)
