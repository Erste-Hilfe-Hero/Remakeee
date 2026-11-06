class_name Loc
extends RefCounted
## Game languages (item 62). English is the source text; other languages come from
## data/i18n/<code>/*.json (one file per table in tools/i18n/) and are installed as a PatternTranslation, so every Label and Button
## follows the chosen language. Code that builds text outside a Control calls Loc.t().

const LANGUAGES: Array[String] = ["en", "de"]
const LANGUAGE_NAMES: Dictionary[String, String] = {"en": "English", "de": "Deutsch"}
const DIR: String = "res://data/i18n/%s"
const PATH: String = "res://data/i18n/%s.json"

static var _installed: Dictionary[String, PatternTranslation] = {}
static var _current: String = "en"

## Sends language_changed(code) when the language really changes (plan item 2187), so texts
## drawn by hand (title status, info texts, toasts, list hints) can draw themselves again.
class Events extends RefCounted:
	signal language_changed(code: String)

static var events: Events = Events.new()

## The device language if the game has it, otherwise English.
static func default_language() -> String:
	var dev: String = OS.get_locale_language()
	return dev if dev in LANGUAGES else "en"

static func language() -> String:
	return _current

## Switches every text to [param code]. Unknown codes fall back to English.
static func set_language(code: String) -> void:
	if not code in LANGUAGES:
		code = "en"
	if code != "en" and not _installed.has(code):
		var t: PatternTranslation = load_translation(code)
		if t != null:
			_installed[code] = t
			TranslationServer.add_translation(t)
	var changed: bool = code != _current
	_current = code
	TranslationServer.set_locale(code)
	if changed:
		events.language_changed.emit(code)

## Removes the installed translations (on quit: the script-backed translations must go
## before the scripts are unloaded, or the engine crashes on exit).
static func uninstall() -> void:
	for t: PatternTranslation in _installed.values():
		TranslationServer.remove_translation(t)
	_installed.clear()
	_current = "en"
	TranslationServer.set_locale("en")

## The merged table of [param code]: {"strings": {...}, "keep": [...]}. Reads every file in
## data/i18n/<code>/ (older builds had one data/i18n/<code>.json; that still works). Empty if missing.
static func load_table(code: String) -> Dictionary:
	var paths: Array[String] = []
	var dir: String = DIR % code
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				paths.append(dir.path_join(f))
	elif FileAccess.file_exists(PATH % code):
		paths.append(PATH % code)
	paths.sort()
	var strings: Dictionary = {}
	var keep: Array = []
	for path: String in paths:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			continue
		if data.get("strings") is Dictionary:
			strings.merge(data.strings, true)
		if data.get("keep") is Array:
			keep.append_array(data.keep)
	if paths.is_empty():
		return {}
	return {"strings": strings, "keep": keep}

## Reads the table of [param code] into a PatternTranslation (null if missing).
static func load_translation(code: String) -> PatternTranslation:
	var data: Dictionary = load_table(code)
	if data.is_empty():
		return null
	var t := PatternTranslation.new()
	t.locale = code
	t.load_strings(data.get("strings", {}))
	return t

## Translates [param s] into the current language (unchanged in English or if unknown).
static func t(s: String) -> String:
	if _current == "en":
		return s
	var tr: PatternTranslation = _installed.get(_current)
	if tr == null:
		return s
	var r: String = tr.lookup(s)
	return r if r != "" else s

## English singular or plural for [param n] (plan item 2188): "1 coin", "3 coins". Both forms
## are their own keys in the language files, so other languages get theirs too.
static func plural(n: int, one: String, other: String) -> String:
	var form: String = one if n == 1 else other
	return form % n if form.contains("%d") else form

## The next language after the current one, for a settings toggle.
static func next_language() -> String:
	return LANGUAGES[(LANGUAGES.find(_current) + 1) % LANGUAGES.size()]
