class_name EraActorLook
extends RefCounted
## How overworld figures look and move in each era (data/era_actor_look.json,
## docs/ERA_FEEL_CHARS.md): sheet size and poses, walk cycle, running poses, the wading pose for
## crossings, drop shadow, emote bubbles, head turns, the Spirling that walks behind, idle
## breathing and blinking, season outfits. Eras I and II keep GridWalker's own drawing of the
## 64x32 sheets; from Era III on [method draw_actor] draws the figure from art/eraN/actors.
## The live part (ticks, bubbles, the follower) is the EraActors node.

const PATH: String = "res://data/era_actor_look.json"
## Which sheet colours of the Wayfarer are skin, hair and coat (made by tools/art/gen_era_chars.py).
const ZONES_PATH: String = "res://data/era_actor_zones.json"
const SHEET_REL: String = "actors/%s.png"
const EMOTE_REL: String = "actors/emotes.png"
## Every era sets every one of these.
const KEYS: Array[String] = ["title", "sheet_dir", "frame", "colours", "walk_frames", "rows", "step_seq",
	"step_px", "walk_time", "run_time", "run_anim", "wade", "shadow", "emotes", "emote_style",
	"emote_frames", "emote_pop", "emote_on", "head_turn", "head_turn_radius", "follower",
	"follower_walk", "follower_shadow", "idle", "turn_blend", "outfits"]
## Switches that stay on in every later era once an era turns them on.
const SWITCHES: Array[String] = ["run_anim", "wade", "emote_pop", "head_turn", "follower_walk", "follower_shadow", "turn_blend"]
## Numbers that never go down from one era to the next.
const GROWING: Array[String] = ["colours", "walk_frames", "emote_frames", "head_turn_radius"]
## Named steps: a later era is never further left in its list.
const LADDERS: Dictionary[String, Array] = {
	"sheet_dir": ["chars", "actors"], "shadow": ["none", "drop"],
	"emote_style": ["ink", "flat", "tail", "shadow", "live"], "follower": ["ink", "colour"],
	"idle": ["still", "breathe_blink"], "outfits": ["none", "season"],
}
const POSES: Array[String] = ["stand", "half", "step"]
const CW: Dictionary[String, String] = {"down": "left", "left": "up", "up": "right", "right": "down"}
const OPPOSITE: Dictionary[String, String] = {"down": "up", "up": "down", "left": "right", "right": "left"}
const SHADOW_COLOR: Color = Color(0.06, 0.05, 0.1, 0.3)

static var _data: Dictionary = {}
static var _tex: Dictionary[String, Texture2D] = {}
static var _zones: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = raw if raw is Dictionary else {}
	return _data

## The row of [param era] (the active era when left out).
static func row(era: int = -1) -> Dictionary:
	var e: int = EraManager.active_era() if era < 0 else era
	var eras: Dictionary = data().get("eras", {})
	var r: Variant = eras.get(str(e), eras.get("1", {}))
	return r if r is Dictionary else {}

static func value(key: String, era: int = -1) -> Variant:
	return row(era).get(key)

## Top-level number of the table (times, cooldowns).
static func num(key: String, fallback: float = 0.0) -> float:
	return float(data().get(key, fallback))

## True from the era on in which this module draws the figures itself.
static func own_sheets(era: int = -1) -> bool:
	return str(row(era).get("sheet_dir", "chars")) == "actors"

## True while the old ink "!" box and the scene's ink label are the era's emotes (Era I).
static func plain_emotes(era: int = -1) -> bool:
	return str(row(era).get("emote_style", "ink")) == "ink"

## Bubble kind for a scene icon ("!", "?", "...", "heart", "note") or a kind name; "" if unknown.
static func emote_kind(icon: String) -> String:
	var icons: Dictionary = data().get("icons", {})
	if icons.has(icon):
		return str(icons[icon])
	return icon if icon in (data().get("emote_kinds", []) as Array) else ""

## The bubble the era shows for [param trigger] (spot, talk, near ...); "" for none.
static func emote_for(trigger: String, era: int = -1) -> String:
	var kind: String = str((row(era).get("emote_on", {}) as Dictionary).get(trigger, ""))
	return kind if kind in (row(era).get("emotes", []) as Array) else ""

## Season name for a month (1-12), from "season_months".
static func season(month: int) -> String:
	var months: Dictionary = data().get("season_months", {})
	for s: String in months:
		for m: Variant in months[s]:
			if int(m) == month:
				return s
	return str((data().get("seasons", ["spring"]) as Array)[0])

## Column block of the sheet for today's outfit: 0 unless the era has season outfits.
static func outfit_block(era: int = -1, month: int = -1) -> int:
	if str(row(era).get("outfits", "none")) != "season":
		return 0
	var m: int = month if month > 0 else int(Online.date_now().month)
	return maxi(0, (data().get("seasons", []) as Array).find(season(m)))

## True when a crossing with [param gear] is waded on foot in this era (no hop arc).
static func wades(gear: String, era: int = -1) -> bool:
	return bool(row(era).get("wade", false)) and gear in (data().get("wade_gear", []) as Array)

## Figure sheet of [param style] in [param era], or null when that era has none.
static func sheet(style: String, era: int) -> Texture2D:
	return _load("res://art/era%d/%s" % [era, SHEET_REL % style])

## Bubble sheet of [param era] (columns "emote_kinds", rows frames), or null.
static func emote_sheet(era: int) -> Texture2D:
	return _load("res://art/era%d/%s" % [era, EMOTE_REL])

static func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

## The Wayfarer's sheet of [param style] in [param era], repainted in the player's own look:
## [param look] is {"skin": Color, "hair": Color, "coat": Color}. Null when the era has no sheet.
static func player_sheet(style: String, era: int, look: Dictionary) -> Texture2D:
	var key: String = "%d/%s/%s" % [era, style, look]
	if _tex.has(key):
		return _tex[key]
	var base: Texture2D = sheet(style, era)
	var img: Image = repaint(base.get_image(), zones(style, era), look) if base != null else null
	_tex[key] = ImageTexture.create_from_image(img) if img != null else base
	return _tex[key]

## Colour groups of a Wayfarer sheet: {"skin": {html: tone step}, "hair": ..., "coat": ...}.
static func zones(style: String, era: int) -> Dictionary:
	if _zones.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ZONES_PATH))
		_zones = raw if raw is Dictionary else {"_": 0}
	var z: Variant = (_zones.get(str(era), {}) as Dictionary).get(style, {})
	return z if z is Dictionary else {}

## The same colour one tone step darker (below 0) or lighter (above 0).
static func toned(c: Color, step: float) -> Color:
	return c.darkened(-step) if step < 0.0 else c.lightened(step)

## A copy of [param src] with every colour of [param groups] replaced by the look's colour for
## that group at the same tone step. Null when there is nothing to repaint.
static func repaint(src: Image, groups: Dictionary, look: Dictionary) -> Image:
	var swap: Dictionary[int, Color] = {}
	for g: String in groups:
		if look.has(g):
			for html: String in groups[g]:
				swap[Color(html).to_rgba32()] = toned(look[g], float(groups[g][html]))
	if src == null or swap.is_empty():
		return null
	var img: Image = src.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a8 == 255 and swap.has(c.to_rgba32()):
				img.set_pixel(x, y, swap[c.to_rgba32()])
	return img

## The player's own colours for [method player_sheet].
static func player_look() -> Dictionary:
	return {"skin": GameState.SKIN_TONES[clampi(GameState.skin_tone, 0, GameState.SKIN_TONES.size() - 1)],
		"hair": GameState.HAIR_COLORS[clampi(GameState.hair_color, 0, GameState.HAIR_COLORS.size() - 1)],
		"coat": GameState.body_color()}

## The pose of a figure right now: {"row": sheet row name, "col": direction of the column}.
## [param k] is how far the current tile step is (0-1), [param parity] alternates per tile (which
## foot), [param look] is the glance direction ("" = none), [param turn_from] the facing before a
## fresh quarter turn ("" = none), [param idle_ms] a clock for breathing and blinking.
static func pose(r: Dictionary, facing: String, moving: bool, running: bool, k: float, parity: int,
		look: String = "", wading: bool = false, turn_from: String = "", idle_ms: int = 0,
		reduced: bool = false) -> Dictionary:
	var rows: Dictionary = r.get("rows", {})
	if wading and rows.has("wade"):
		return {"row": "wade", "col": facing}
	# A quarter turn leads with the head: the old body, the head already in the new direction.
	if not turn_from.is_empty() and bool(r.get("turn_blend", false)) and not reduced and rows.has("head_cw"):
		if CW[turn_from] == facing:
			return {"row": "head_cw", "col": turn_from}
		if CW[facing] == turn_from:
			return {"row": "head_ccw", "col": turn_from}
	var foot: String = "l" if parity % 2 == 0 else "r"
	if moving:
		var seq: Array = r.get("step_seq", ["stand", "step", "step", "stand"])
		var phase: String = str(seq[clampi(int(k * seq.size()), 0, seq.size() - 1)])
		if phase == "stand":
			return {"row": "stand", "col": facing}
		if running and phase == "step" and bool(r.get("run_anim", false)) and rows.has("run_" + foot):
			return {"row": "run_" + foot, "col": facing}
		var name: String = "%s_%s" % [phase, foot]
		return {"row": name if rows.has(name) else "step_" + foot, "col": facing}
	if not look.is_empty() and look != facing:
		if bool(r.get("head_turn", false)) and rows.has("head_cw") and look != OPPOSITE[facing]:
			return {"row": "head_cw" if CW[facing] == look else "head_ccw", "col": facing}
		return {"row": "stand", "col": look}
	if str(r.get("idle", "still")) == "breathe_blink" and not reduced:
		var every: int = maxi(1, int(num("blink_every_ms", 3600.0)))
		if rows.has("blink") and idle_ms % every < int(num("blink_ms", 140.0)):
			return {"row": "blink", "col": facing}
		if rows.has("breathe") and (idle_ms / maxi(1, int(num("breathe_ms", 900.0)))) % 2 == 1:
			return {"row": "breathe", "col": facing}
	return {"row": "stand", "col": facing}

## The pose of walker [param w] now, with the walker's own state.
static func pose_of(w: GridWalker, r: Dictionary) -> Dictionary:
	var k: float = clampf(w._t / w._duration, 0.0, 1.0) if w.moving else 0.0
	var now: int = Time.get_ticks_msec()
	var turn_from: String = str(w.era_anim.get("turn_from", "")) if now < int(w.era_anim.get("turn_until", 0)) else ""
	return pose(r, w.facing, w.moving, w.running, k, w.cell.x + w.cell.y, w.look,
		bool(w.era_anim.get("wade", false)), turn_from, now + int(w.era_anim.get("seed", 0)), Juice.reduced())

## Region of the sheet for a pose.
static func src_rect(r: Dictionary, p: Dictionary, block: int = 0) -> Rect2:
	var frame: Array = r.get("frame", [16, 16])
	var fw: int = int(frame[0])
	var fh: int = int(frame[1])
	var col: int = GridWalker.SHEET_COLUMNS.get(str(p.col), 0)
	return Rect2((block * 4 + col) * fw, int((r.get("rows", {}) as Dictionary).get(str(p.row), 0)) * fh, fw, fh)

## Draws walker [param w] in the active era's own style; false when the era (or this figure) has
## no own sheet, so GridWalker draws it as before. Call only from the walker's _draw.
static func draw_actor(w: GridWalker) -> bool:
	var era: int = EraManager.active_era()
	var r: Dictionary = row(era)
	if not own_sheets(era):
		return false
	var tex: Texture2D = player_sheet(w.sprite_style, era, player_look()) if w is Player else sheet(w.sprite_style, era)
	if tex == null:
		return false
	var frame: Array = r.get("frame", [16, 16])
	var lift: int = int(frame[1]) - GridWalker.TILE
	var p: Dictionary = pose_of(w, r)
	if str(r.get("shadow", "none")) == "drop" and str(p.row) != "wade":
		draw_shadow(w, Vector2.ZERO)
	var shift: Vector2 = w.jolt
	if w.bob and w.moving and str(p.row).begins_with("step") and not Juice.reduced():
		shift += Vector2(0, 1)
	w.draw_set_transform(shift)
	w.draw_texture_rect_region(tex, Rect2(0, -lift, int(frame[0]), int(frame[1])), src_rect(r, p, int(w.era_anim.get("outfit", outfit_block(era)))))
	HatArt.draw(w, Vector2(8, 3 - lift), w.hat)
	return true

## A small oval shadow under the feet of a 16 px cell at [param at].
static func draw_shadow(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at.x + 4, at.y + 13, 8, 1), SHADOW_COLOR)
	ci.draw_rect(Rect2(at.x + 3, at.y + 14, 10, 1), SHADOW_COLOR)
	ci.draw_rect(Rect2(at.x + 4, at.y + 15, 8, 1), SHADOW_COLOR)

## Everything wrong with the table: missing keys, a later era that drops a feature, poses without
## a row, bubbles the sheet has no column for. Empty when the table is sound (GUT test).
static func problems() -> Array[String]:
	var out: Array[String] = []
	var d: Dictionary = data()
	var kinds: Array = d.get("emote_kinds", [])
	var prev: Dictionary = {}
	for era: int in range(EraManager.Era.INK, EraManager.NEWEST + 1):
		var eras: Dictionary = d.get("eras", {})
		if not eras.has(str(era)):
			out.append("era %d is missing" % era)
			continue
		var r: Dictionary = eras[str(era)]
		for k: String in KEYS:
			if not r.has(k):
				out.append("era %d: key %s is missing" % [era, k])
		var rows: Dictionary = r.get("rows", {})
		for need: String in ["stand", "step_l", "step_r"]:
			if not rows.has(need):
				out.append("era %d: no row for %s" % [era, need])
		for ph: Variant in r.get("step_seq", []):
			if not str(ph) in POSES:
				out.append("era %d: unknown step pose %s" % [era, ph])
			elif str(ph) == "half" and not rows.has("half_l"):
				out.append("era %d: half steps without a row" % era)
		for sw: Array in [["run_anim", "run_l"], ["wade", "wade"], ["head_turn", "head_cw"], ["turn_blend", "head_cw"]]:
			if bool(r.get(sw[0], false)) and not rows.has(sw[1]):
				out.append("era %d: %s without the row %s" % [era, sw[0], sw[1]])
		if str(r.get("idle", "")) == "breathe_blink" and not (rows.has("breathe") and rows.has("blink")):
			out.append("era %d: idle animation without its rows" % era)
		for e: Variant in r.get("emotes", []):
			if not e in kinds:
				out.append("era %d: unknown emote %s" % [era, e])
		for trig: String in r.get("emote_on", {}):
			if not r.emote_on[trig] in (r.get("emotes", []) as Array):
				out.append("era %d: %s shows %s, which the era has not got" % [era, trig, r.emote_on[trig]])
		for k: String in LADDERS:
			if not str(r.get(k, "")) in LADDERS[k]:
				out.append("era %d: %s is not one of %s" % [era, k, LADDERS[k]])
		if not prev.is_empty():
			for k: String in SWITCHES:
				if bool(prev.get(k, false)) and not bool(r.get(k, false)):
					out.append("era %d switches %s off again" % [era, k])
			for k: String in GROWING:
				if float(r.get(k, 0)) < float(prev.get(k, 0)):
					out.append("era %d: %s goes down" % [era, k])
			for k: String in LADDERS:
				if LADDERS[k].find(str(r.get(k, ""))) < LADDERS[k].find(str(prev.get(k, ""))):
					out.append("era %d: %s steps back" % [era, k])
			if int(r.get("step_px", 1)) > int(prev.get("step_px", 1)):
				out.append("era %d: movement gets coarser" % era)
			if float(r.get("run_time", 0)) > float(prev.get("run_time", 0)) or float(r.get("walk_time", 0)) > float(prev.get("walk_time", 0)):
				out.append("era %d: walking or running gets slower" % era)
			if int((r.get("frame", [0, 0]) as Array)[1]) < int((prev.get("frame", [0, 0]) as Array)[1]):
				out.append("era %d: figures get smaller" % era)
			for e: Variant in prev.get("emotes", []):
				if not e in (r.get("emotes", []) as Array):
					out.append("era %d loses the emote %s" % [era, e])
			for trig: String in prev.get("emote_on", {}):
				if not (r.get("emote_on", {}) as Dictionary).has(trig):
					out.append("era %d loses the emote trigger %s" % [era, trig])
			for name: String in prev.get("rows", {}):
				if not rows.has(name):
					out.append("era %d loses the pose %s" % [era, name])
		prev = r
	for icon: String in ["!", "?", "...", "heart", "note"]:
		if emote_kind(icon).is_empty():
			out.append("scene icon %s has no bubble" % icon)
	return out
