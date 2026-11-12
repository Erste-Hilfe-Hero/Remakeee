class_name EraText
extends RefCounted
## Text look of the later eras (docs/ERA_FEEL_TEXT.md, data/era_text.json): which own font an
## era writes with, whether the dialogue box shows who speaks (a small head on the name plate in
## Era IV, an animated portrait in Era V) and the spiral door warp of Era III. Eras I and II
## keep the pixel font and the plain name tag they came with.

const PATH: String = "res://data/era_text.json"
const KEYS: Array[String] = ["font", "portrait", "warp"]
const PORTRAITS: Array[String] = ["none", "icon", "bust"]
const WARPS: Array[String] = ["", "spiral"]
const BUST_ART: String = "res://art/era5/portraits/%s.png"
const ICON_ART: String = "res://art/era4/portraits/%s.png"
## Read aloud for the portrait by screen readers.
const PORTRAIT_LABEL: String = "Portrait of %s"

static var _cfg: Dictionary = {}
static var _by_name: Dictionary[String, String] = {}
## The era whose skin is on screen; EraManager sets it with the rest of the era skin.
static var skin_era: int = 1

static func config() -> Dictionary:
	if _cfg.is_empty():
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cfg = d
	return _cfg

## The row of era [param era] (clamped to I-V).
static func of(era: int) -> Dictionary:
	var eras: Dictionary = config().get("eras", {})
	return eras.get(str(clampi(era, 1, 5)), {})

## Called by EraManager when the era on screen changes.
static func set_era(era: int) -> void:
	skin_era = clampi(era, 1, 5)

## Id of the own font era [param era] writes [param lang] with, "" for the pixel font: the era
## fonts are drawn for the languages in "languages" (English and German), every other language
## keeps the pixel font with its accents, Cyrillic and CJK. With the Large text option a font
## smaller than the large pixel font gives way to it.
static func font_id(era: int, lang: String, large_text: bool = false) -> String:
	var id: String = str(of(era).get("font", ""))
	if id.is_empty() or not lang in (config().get("languages", []) as Array):
		return ""
	if not EraFont.has_font(id):
		return ""
	if large_text and EraFont.cell_height(id) < PixelFont.LARGE_H:
		return ""
	return id

## The own font of the era on screen in the current language, null for the pixel font.
static func font(large_text: bool = false) -> FontFile:
	var id: String = font_id(skin_era, Loc.language(), large_text)
	return EraFont.get_font(id) if not id.is_empty() else null

## How era [param era] shows the speaker: "none", "icon" or "bust".
static func portrait_mode(era: int) -> String:
	var m: String = str(of(era).get("portrait", "none"))
	return m if m in PORTRAITS else "none"

## Speaker id for the name shown on the name tag, "" when that speaker has no portrait. The
## whole name wins ("Mother Grell"); else one of its words may be a speaker's short name
## ("Veit Harrow" is Veit). Upper and lower case do not matter.
static func speaker_id(shown: String) -> String:
	if _by_name.is_empty():
		var sp: Dictionary = config().get("speakers", {})
		for id: String in sp:
			for n: Variant in (sp[id] as Dictionary).get("names", []):
				_by_name[str(n).to_lower()] = id
	var key: String = shown.strip_edges().to_lower()
	if key.is_empty():
		return ""
	if _by_name.has(key):
		return _by_name[key]
	for word: String in key.split(" ", false):
		if _by_name.has(word):
			return _by_name[word]
	return ""

static func speaker_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign((config().get("speakers", {}) as Dictionary).keys())
	return out

## res:// path of the art of speaker [param id] for [param mode] ("icon" or "bust"), "" when
## the mode shows none or the file is missing.
static func art_path(id: String, mode: String) -> String:
	if id.is_empty() or not mode in ["icon", "bust"]:
		return ""
	var path: String = (BUST_ART if mode == "bust" else ICON_ART) % id
	return path if ResourceLoader.exists(path) or FileAccess.file_exists(path) else ""

## Number setting [param key] of the "portrait" block.
static func portrait_value(key: String, fallback: float) -> float:
	return float((config().get("portrait", {}) as Dictionary).get(key, fallback))

## Number setting [param key] of the "spiral" block.
static func spiral_value(key: String, fallback: float) -> float:
	return float((config().get("spiral", {}) as Dictionary).get(key, fallback))

## The door warp of era [param era]: its own variant when it has one, else [param base] (the
## warp of data/era_feel.json). Reduced motion always gets the plain fade.
static func warp(era: int, base: String, reduced: bool = false) -> String:
	if reduced:
		return "fade"
	var own: String = str(of(era).get("warp", ""))
	return own if not own.is_empty() and own in WARPS else base

## Which frame of a bust shows: 0 resting, 1 eyes shut, 2 speaking. [param t] is the time the
## portrait has been up, [param typing] whether the line is still being typed. Reduced motion
## keeps the resting frame.
static func bust_frame(t: float, typing: bool, reduced: bool) -> int:
	if reduced:
		return 0
	var every: float = maxf(0.5, portrait_value("blink_every", 3.4))
	if fmod(t, every) > every - portrait_value("blink_time", 0.14):
		return 1
	var talk: float = maxf(0.02, portrait_value("talk_time", 0.11))
	if typing and int(t / talk) % 2 == 1:
		return 2
	return 0

## Problems with the table as "kind:where": a missing key, an unknown font, portrait mode or
## warp, an era that shows less of the speaker than the one before, a speaker without a name
## or without art, a name used twice. Empty when the table is sound.
static func problems() -> Array[String]:
	var out: Array[String] = []
	for e: int in range(1, 6):
		var row: Dictionary = of(e)
		for k: String in KEYS:
			if not row.has(k):
				out.append("missing:%d:%s" % [e, k])
		var fid: String = str(row.get("font", ""))
		if not fid.is_empty() and not EraFont.has_font(fid):
			out.append("font:%d" % e)
		if not str(row.get("portrait", "")) in PORTRAITS:
			out.append("portrait:%d" % e)
		elif e > 1 and PORTRAITS.find(str(row.portrait)) < PORTRAITS.find(portrait_mode(e - 1)):
			out.append("loses:%d:portrait" % e)
		if not str(row.get("warp", "")) in WARPS:
			out.append("warp:%d" % e)
		if e > 1 and not fid.is_empty() and not str(of(e - 1).get("font", "")).is_empty() \
				and EraFont.cell_height(fid) < EraFont.cell_height(str(of(e - 1).font)):
			out.append("shrinks:%d:font" % e)
	for lang: Variant in config().get("languages", []):
		if not str(lang) in Loc.LANGUAGES:
			out.append("language:%s" % lang)
	var seen: Dictionary[String, String] = {}
	var sp: Dictionary = config().get("speakers", {})
	for id: String in sp:
		var names: Array = (sp[id] as Dictionary).get("names", [])
		if names.is_empty():
			out.append("names:%s" % id)
		for n: Variant in names:
			var key: String = str(n).to_lower()
			if seen.has(key):
				out.append("twice:%s" % key)
			seen[key] = id
		for mode: String in ["icon", "bust"]:
			if art_path(id, mode).is_empty():
				out.append("art:%s:%s" % [id, mode])
	return out
