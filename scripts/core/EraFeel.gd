class_name EraFeel
extends RefCounted
## Era feel outside battle (docs/ERA_FEEL_UI.md): text box frame, font, typing speed and voice,
## menu skin, Vigor bars, warps, place banners, overworld extras and the era-change sequence,
## one row per era in data/era_feel.json. EraManager.feel(key) reads the active era's value.

const PATH: String = "res://data/era_feel.json"
## Keys every era sets.
const KEYS: Array[String] = ["title", "caption", "palette", "frame", "font", "text_cps_mult", "blip",
	"bar", "warp", "town_popup", "water_shimmer", "flower_sway", "grass_fx", "reflections", "footprints",
	"season_tint", "idle_breathe", "walk_frames", "tilt", "camera_lead", "levels", "upgrade", "jingle"]
## Overworld extras: once on in an era, on in every later era.
const RISING_FLAGS: Array[String] = ["water_shimmer", "flower_sway", "grass_fx", "reflections", "footprints",
	"season_tint", "idle_breathe"]
## Numbers that never go down from one era to the next.
const RISING_NUMBERS: Array[String] = ["text_cps_mult", "walk_frames", "tilt", "camera_lead", "levels"]
const FRAMES: Array[String] = ["ink", "wash", "etched", "panorama", "living"]
const BARS: Array[String] = ["ink", "colour", "gradient", "bevel", "gloss"]
const POPUPS: Array[String] = ["plain", "sign", "board", "ribbon", "ribbon_shine"]
const UPGRADES: Array[String] = ["none", "radial", "sharpen", "unfold", "breathe"]
const WARPS: Array[String] = ["door", "iris"]
## Story flag set once the era-change sequence into an era was shown.
const SEEN_FLAG: String = "era_seen_%d"

static var _cfg: Dictionary = {}

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

static func value(era: int, key: String) -> Variant:
	return of(era).get(key)

static func palette(era: int) -> Array[Color]:
	var out: Array[Color] = []
	for h: Variant in of(era).get("palette", []):
		out.append(Color(str(h)))
	return out

## True when the era-change sequence into [param era] is still owed: the era is open, is the
## one on screen (not an older Retro filter look) and its sequence has not been shown yet.
static func upgrade_due(era: int, active: int, unlocked: int, has_flag: Callable) -> bool:
	return era >= 2 and era <= unlocked and era == active and not bool(has_flag.call(SEEN_FLAG % era))

## The caption line of the sequence into [param era], translated.
static func caption(era: int) -> String:
	return Loc.t(str(value(era, "title"))) + "\n" + Loc.t(str(value(era, "caption")))

## Tint over the world for the season of [param month] (1-12); Era V shows the seasons.
static func season_tint(month: int) -> Color:
	match month:
		3, 4, 5:
			return Color(1.0, 0.97, 0.98)
		6, 7, 8:
			return Color(1.0, 1.0, 0.95)
		9, 10, 11:
			return Color(1.0, 0.94, 0.88)
		_:
			return Color(0.93, 0.96, 1.0)

## Fill colour of an Era II "colour" bar by the share left: green, yellow, red.
static func bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color("3e9a52")
	if ratio > 0.2:
		return Color("d6a227")
	return Color("c4432f")

## Draws a Vigor bar of [param style] into [param rect] on [param ci]. "ink" is the Era I bar:
## a line of the row's ink on the greyed track.
static func draw_bar(ci: CanvasItem, rect: Rect2, ratio: float, ink: Color, style: String) -> void:
	var fill_w: float = maxf(1.0, roundf(rect.size.x * ratio)) if ratio > 0.0 else 0.0
	var fill := Rect2(rect.position, Vector2(fill_w, rect.size.y))
	match style:
		"colour":
			ci.draw_rect(rect, UITheme.DISABLED)
			if fill_w > 0.0:
				ci.draw_rect(fill, bar_color(ratio))
		"gradient":
			ci.draw_rect(rect, UITheme.DISABLED)
			if fill_w > 0.0:
				var c: Color = bar_color(ratio)
				ci.draw_rect(fill, c.darkened(0.25))
				ci.draw_rect(Rect2(fill.position, Vector2(fill_w, 1)), c.lightened(0.2))
		"bevel", "gloss":
			var outer := rect.grow(1)
			ci.draw_rect(outer, UITheme.INK)
			ci.draw_rect(rect, UITheme.DISABLED.darkened(0.3))
			if fill_w > 0.0:
				var c: Color = bar_color(ratio)
				ci.draw_rect(fill, c)
				var hi: Color = c.lightened(0.45 if style == "gloss" else 0.25)
				ci.draw_rect(Rect2(fill.position, Vector2(fill_w, 1)), hi)
		_:
			ci.draw_rect(rect, UITheme.DISABLED)
			if fill_w > 0.0:
				ci.draw_rect(fill, ink)

## Problems with the table as "kind:era:key": a missing key, a bad palette, an unknown style,
## an extra that switches off again or a number that goes down. Empty when the table is sound.
static func problems() -> Array[String]:
	var out: Array[String] = []
	for e: int in range(1, 6):
		var row: Dictionary = of(e)
		for k: String in KEYS:
			if not row.has(k):
				out.append("missing:%d:%s" % [e, k])
		if palette(e).size() != 5:
			out.append("palette:%d" % e)
		for pair: Array in [["frame", FRAMES], ["bar", BARS], ["town_popup", POPUPS], ["upgrade", UPGRADES], ["warp", WARPS]]:
			if not str(row.get(pair[0], "")) in (pair[1] as Array):
				out.append("unknown:%d:%s" % [e, pair[0]])
		if e == 1:
			continue
		var prev: Dictionary = of(e - 1)
		for k: String in RISING_FLAGS:
			if bool(prev.get(k, false)) and not bool(row.get(k, false)):
				out.append("loses:%d:%s" % [e, k])
		for k: String in RISING_NUMBERS:
			if float(row.get(k, 0)) < float(prev.get(k, 0)):
				out.append("lowers:%d:%s" % [e, k])
	return out
