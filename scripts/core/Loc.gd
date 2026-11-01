class_name Loc
extends RefCounted
## Game languages (item 62). English is the source text; other languages come from
## data/i18n/<code>.json and are installed as a PatternTranslation, so every Label and Button
## follows the chosen language. Code that builds text outside a Control calls Loc.t().

const LANGUAGES: Array[String] = ["en", "de"]
const LANGUAGE_NAMES: Dictionary[String, String] = {"en": "English", "de": "Deutsch"}
const PATH: String = "res://data/i18n/%s.json"

static var _installed: Dictionary[String, PatternTranslation] = {}
static var _current: String = "en"

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
	_current = code
	TranslationServer.set_locale(code)

## Reads data/i18n/[param code].json into a PatternTranslation (null if missing).
static func load_translation(code: String) -> PatternTranslation:
	var f := FileAccess.open(PATH % code, FileAccess.READ)
	if f == null:
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
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

## The next language after the current one, for a settings toggle.
static func next_language() -> String:
	return LANGUAGES[(LANGUAGES.find(_current) + 1) % LANGUAGES.size()]
