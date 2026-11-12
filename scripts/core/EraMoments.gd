class_name EraMoments
extends RefCounted
## The big moments of each era (data/era_moments.json, docs/ERA_LOOK_TITLE.md): title screen,
## boot card, the staged era-change scene, finale card and save card. This file is the data
## side: lookups, the step timeline of a change, which era a save is in, and the data check.
## The screens are EraTitleArt, EraBoot, EraChangeScene, EraFinaleCard and EraSaveCard.

const PATH: String = "res://data/era_moments.json"
const ERAS: Array[int] = [1, 2, 3, 4, 5]
const TITLE_KINDS: Array[String] = ["static", "scroll", "shine", "parallax", "living"]
const FRAMES: Array[String] = ["ink", "wash", "bevel", "round", "gloss"]
const STEP_IDS: Array[String] = ["palette", "detail", "frames", "music", "list"]
const PALETTE_KEYS: Array[String] = ["sky_top", "sky_low", "sun", "far", "mid", "water", "glint", "shore", "ink", "paper", "accent", "cloud"]
## Flags: the finale card of era N was shown, the change scene into era N was shown.
const CARD_FLAG: String = "era_card_%d_seen"
const CHANGE_FLAG: String = "era_change_%d_seen"
## Reduced motion: one plain fade of this many seconds, then the list.
const REDUCED_FADE: float = 0.4
## Seconds between two rows of the "New in this era" list.
const LIST_ROW_TIME: float = 0.3
const LIST_HOLD: float = 0.6

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

static func era(e: int) -> Dictionary:
	var d: Variant = (data().get("eras", {}) as Dictionary).get(str(clampi(e, 1, 5)), {})
	return d if d is Dictionary else {}

static func title(e: int) -> Dictionary:
	return era(e).get("title", {})

static func boot(e: int) -> Dictionary:
	return era(e).get("boot", {})

static func finale(e: int) -> Dictionary:
	return era(e).get("finale", {})

static func frame(e: int) -> String:
	return str(era(e).get("frame", FRAMES[0]))

static func font_scale(e: int) -> int:
	return maxi(int(era(e).get("font_scale", 1)), 1)

## Colour [param key] of the title scene of era [param e].
static func col(e: int, key: String) -> Color:
	return Color(str((era(e).get("palette", {}) as Dictionary).get(key, "000000")))

## A plain text of the data file (studio, skip, continue ...), translated.
static func text(key: String) -> String:
	return Loc.t(str(data().get(key, "")))

## "Era II: Wash", translated.
static func era_label(e: int) -> String:
	return "%s: %s" % [Loc.t("Era %s") % EraFeatures.ROMAN[clampi(e, 1, 5)], Loc.t(str(era(e).get("name", "")))]

## The staged change INTO era [param to] ({} for Era I, nothing changes into it).
static func change(to: int) -> Dictionary:
	var d: Variant = (data().get("changes", {}) as Dictionary).get(str(to), {})
	return d if d is Dictionary else {}

static func steps(to: int) -> Array:
	return change(to).get("steps", [])

## The steps of the change into [param to] with their start and end second. With reduced
## motion the four staged steps collapse into one plain fade and the list follows at once.
static func timeline(to: int, reduced: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: float = 0.0
	if reduced:
		out.append({"id": "fade", "style": "fade", "caption": "", "start": 0.0, "end": REDUCED_FADE})
		at = REDUCED_FADE
	for s: Dictionary in steps(to):
		var id: String = str(s.get("id", ""))
		if reduced and id != "list":
			continue
		var dur: float = float(s.get("time", 0.0))
		if id == "list":
			dur = list_time(to, reduced)
		out.append({"id": id, "style": str(s.get("style", "")), "caption": str(s.get("caption", "")), "start": at, "end": at + dur})
		at += dur
	return out

## Seconds the list needs to show every row (all at once with reduced motion).
static func list_time(to: int, reduced: bool = false) -> float:
	return LIST_HOLD if reduced else EraFeatures.new_in(to).size() * LIST_ROW_TIME + LIST_HOLD

static func total_time(to: int, reduced: bool = false) -> float:
	var tl: Array[Dictionary] = timeline(to, reduced)
	return float(tl[-1].end) if not tl.is_empty() else 0.0

## Second at which the list step starts: a skip jumps here.
static func skip_time(to: int, reduced: bool = false) -> float:
	for s: Dictionary in timeline(to, reduced):
		if str(s.id) == "list":
			return float(s.start)
	return total_time(to, reduced)

## Where the change into [param to] stands at second [param t]: the running step ("id",
## "style", "caption", its own progress "p") and the progress 0..1 of every step by id, so the
## scene can draw finished steps as done and later ones as untouched.
static func state_at(to: int, t: float, reduced: bool = false) -> Dictionary:
	var out: Dictionary = {"id": "", "style": "", "caption": "", "p": 0.0, "done": false}
	for id: String in STEP_IDS:
		out[id] = 1.0 if reduced and id != "list" else 0.0
	var tl: Array[Dictionary] = timeline(to, reduced)
	for s: Dictionary in tl:
		var span: float = maxf(float(s.end) - float(s.start), 0.0001)
		var p: float = clampf((t - float(s.start)) / span, 0.0, 1.0)
		out[str(s.id)] = p
		if t >= float(s.start):
			out.id = s.id
			out.style = s.style
			out.caption = s.caption
			out.p = p
	out.done = not tl.is_empty() and t >= float(tl[-1].end)
	return out

## Rows of the list that are on screen at list progress [param p] (0..1) for era [param to].
static func list_rows_shown(to: int, p: float, reduced: bool = false) -> int:
	var n: int = EraFeatures.new_in(to).size()
	if reduced or n == 0:
		return n
	return clampi(int(floor(p * list_time(to) / LIST_ROW_TIME)) + 1, 0, n)

## The list itself: one translated name per new or upgraded function of era [param to].
static func list_lines(to: int) -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in EraFeatures.new_in(to):
		out.append(Loc.t(str(f.name)))
	return out

## What the music step does: the bus effects of the old era before it, of the new era after
## it, and the song that takes over (Sound.music resolves "title" to the new era's variant).
static func music_plan(from: int, to: int) -> Dictionary:
	return {"before_fx": clampi(from, 1, 5), "after_fx": clampi(to, 1, 5), "track": "title"}

## Era a save file is in: its newest unlocked era, or the older one its Retro filter picks.
static func save_era(d: Dictionary) -> int:
	var e: Variant = d.get("era", {})
	if not e is Dictionary:
		return 1
	var unlocked: int = clampi(GameState.as_int((e as Dictionary).get("unlocked_era", 1)), 1, 5)
	var retro: int = clampi(GameState.as_int((e as Dictionary).get("retro_filter", 0)), 0, unlocked)
	return retro if retro > 0 else unlocked

## Newest era a save file has unlocked (the title screen shows this one).
static func save_unlocked(d: Dictionary) -> int:
	var e: Variant = d.get("era", {})
	return clampi(GameState.as_int((e as Dictionary).get("unlocked_era", 1)), 1, 5) if e is Dictionary else 1

## The readable save at [param path] (the file or its newest backup), or {}.
static func save_dict(path: String) -> Dictionary:
	for p: String in SaveManager.save_paths(path):
		if FileAccess.file_exists(p):
			var d: Variant = SaveManager.read_save(p)
			if d is Dictionary:
				return d
	return {}

## The readable save of slot [param n], or {}.
static func slot_dict(n: int) -> Dictionary:
	return save_dict(SaveManager.path_for_slot(n))

## Era look of slot [param n] (0 for an empty slot).
static func slot_era(n: int) -> int:
	var d: Dictionary = slot_dict(n)
	return save_era(d) if not d.is_empty() else 0

## Newest era any slot has unlocked: the era of the title screen (1 without saves).
static func title_era() -> int:
	var best: int = 1
	for n: int in range(1, SaveManager.SLOTS + 1):
		var d: Dictionary = slot_dict(n)
		if not d.is_empty():
			best = maxi(best, save_unlocked(d))
	return best

static func finale_flag(e: int) -> String:
	return str(era(e).get("finale_flag", ""))

## True when the finale card of era [param e] is owed: its finale is done and the card unseen.
static func card_owed(e: int, has_flag: Callable) -> bool:
	var f: String = finale_flag(e)
	return not f.is_empty() and bool(has_flag.call(f)) and not bool(has_flag.call(CARD_FLAG % e))

## Data problems (empty when fine); tests/unit/test_era_moments.gd fails on any.
static func problems() -> Array[String]:
	var out: Array[String] = []
	for key: String in ["studio", "skip", "continue", "the_end", "to_be_continued"]:
		if str(data().get(key, "")).is_empty():
			out.append("text %s missing" % key)
	var last_colours: int = 0
	var last_layers: int = 0
	for e: int in ERAS:
		var d: Dictionary = era(e)
		if d.is_empty():
			out.append("era %d missing" % e)
			continue
		for key: String in ["name", "region", "subtitle", "finale_flag"]:
			if str(d.get(key, "")).is_empty():
				out.append("era %d: %s missing" % [e, key])
		if not frame(e) in FRAMES:
			out.append("era %d: unknown frame %s" % [e, frame(e)])
		for key: String in PALETTE_KEYS:
			if not (d.get("palette", {}) as Dictionary).has(key):
				out.append("era %d: palette %s missing" % [e, key])
		if int(d.get("colours", 0)) <= last_colours:
			out.append("era %d: colours must grow" % e)
		last_colours = int(d.get("colours", 0))
		var t: Dictionary = title(e)
		if not str(t.get("kind", "")) in TITLE_KINDS:
			out.append("era %d: unknown title kind" % e)
		if int(t.get("layers", 0)) < last_layers:
			out.append("era %d: parallax layers must not shrink" % e)
		last_layers = int(t.get("layers", 0))
		if (t.get("cast", []) as Array).is_empty():
			out.append("era %d: title cast empty" % e)
		if str(boot(e).get("kind", "")).is_empty() or float(boot(e).get("time", 0.0)) <= 0.0:
			out.append("era %d: boot kind or time missing" % e)
		var f: Dictionary = finale(e)
		if str(f.get("headline", "")).is_empty() or (f.get("lines", []) as Array).size() < 3:
			out.append("era %d: finale headline or lines missing" % e)
	if str(title(1).get("kind", "")) != "static" or float(title(1).get("blink", 0.0)) <= 0.0:
		out.append("era 1: the title is static with a 2-frame blink")
	if str(title(5).get("legend", "")).is_empty() or not bool(title(5).get("camera", false)):
		out.append("era 5: the title needs its legend and the camera move")
	var styles: Dictionary = {}
	for to: int in range(2, 6):
		var ids: Array[String] = []
		for s: Dictionary in steps(to):
			ids.append(str(s.get("id", "")))
			if str(s.get("caption", "")).is_empty() or str(s.get("style", "")).is_empty():
				out.append("change %d: step %s needs a style and a caption" % [to, s.get("id", "")])
			if str(s.get("id", "")) != "list":
				if float(s.get("time", 0.0)) <= 0.0:
					out.append("change %d: step %s needs a time" % [to, s.get("id", "")])
				var sk: String = "%s:%s" % [s.get("id", ""), s.get("style", "")]
				if styles.has(sk):
					out.append("change %d: style %s is used by change %d too" % [to, sk, styles[sk]])
				styles[sk] = to
		if ids != STEP_IDS:
			out.append("change %d: steps must be %s" % [to, ", ".join(STEP_IDS)])
		if str(change(to).get("headline", "")).is_empty():
			out.append("change %d: headline missing" % to)
	return out

## Every English text of the data file (the German table must carry each one).
static func all_texts() -> Array[String]:
	var out: Array[String] = []
	for key: String in ["studio", "skip", "continue", "the_end", "to_be_continued"]:
		out.append(str(data().get(key, "")))
	for e: int in ERAS:
		out.append(str(era(e).get("name", "")))
		out.append(str(era(e).get("subtitle", "")))
		out.append(str(finale(e).get("headline", "")))
		for l: Variant in finale(e).get("lines", []):
			out.append(str(l))
	for to: int in range(2, 6):
		out.append(str(change(to).get("headline", "")))
		for s: Dictionary in steps(to):
			out.append(str(s.get("caption", "")))
	return out
