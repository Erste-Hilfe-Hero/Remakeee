class_name EraBattleHud
extends RefCounted
## The battle HUD per era (data/era_battle_hud.json, docs/ERA_FEEL_HUD.md): name plates, the
## text box frame, the command panel, the team row, the ring-rise panel and the Echo call frame.
## Pure helpers, so tests need no scene. Presentation only, never a battle rule.

const PATH: String = "res://data/era_battle_hud.json"
const ERAS: int = 5
## Every era entry sets every one of these.
const KEYS: Array[String] = ["name", "font", "frame", "plate", "plate_slant", "plate_shadow", "plate_header",
	"plate_gloss", "plate_slide", "camera_follow", "bar_h", "bar_h_single", "pip", "marks", "hp_numbers", "xp", "xp_colour",
	"menu", "commands", "art_h", "command_h", "art_fill", "art_slant", "art_detail", "item_shortcut",
	"menu_stagger", "info_card", "team_row", "team_mark", "team_shape", "team_pop", "level_panel",
	"level_count", "bond", "bond_mark", "mini", "accent", "light", "shade"]
## Keys whose value is a step in an ordered list of the file (later = richer).
const RANKED: Dictionary[String, String] = {"frame": "frames", "plate": "plates", "menu": "menus",
	"team_row": "team_rows", "level_panel": "level_panels", "bond": "bonds", "mini": "minis"}
## Switches that stay on once an era turned them on.
const SWITCHES: Array[String] = ["plate_shadow", "plate_header", "plate_gloss", "plate_slide", "marks", "xp_colour",
	"art_fill", "art_detail", "item_shortcut", "menu_stagger", "team_pop", "level_count"]
const MARGIN: int = 4
## Frame slice: FRAME_SIZE square with FRAME_MARGIN of border on each side.
const FRAME_SIZE: int = 11
const FRAME_MARGIN: int = 4
## Content margin of a framed panel, the same as UITheme.panel_style so layouts match.
const FRAME_PAD: int = 5
## Small speed / Auto / Log buttons.
const SIDE_BUTTON: Vector2 = Vector2(26, 13)
const SIDE_BUTTON_LARGE: Vector2 = Vector2(38, 16)
## Stage eras: the player's plate is at least this share of the field wide.
const MIN_PLAYER_PLATE: float = 0.46
## Lines the battle text box holds (TextBox.MAX_LINES).
const TEXT_LINES: int = 3

static var _cfg: Dictionary = {}
static var _frames: Dictionary[String, StyleBoxTexture] = {}
static var _themes: Dictionary[String, Theme] = {}
## The item the player used last in a battle of this session (item shortcut, Era IV on).
static var last_item: String = ""
## Tests: 1 or 0 forces skin_api(); -1 asks the project.
static var skin_override: int = -1

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"eras": {}}
	return _cfg

## The whole entry for [param era]; eras past the table use the newest one.
static func for_era(era: int) -> Dictionary:
	return (cfg().get("eras", {}) as Dictionary).get(str(clampi(era, 1, ERAS)), {})

static func num(era: int, key: String, fallback: float = 0.0) -> float:
	return float(for_era(era).get(key, fallback))

static func flag(era: int, key: String) -> bool:
	return bool(for_era(era).get(key, false))

static func text(era: int, key: String, fallback: String = "") -> String:
	return str(for_era(era).get(key, fallback))

## Position of [param era]'s value for [param key] in its ordered list, -1 if unknown.
static func rank(era: int, key: String) -> int:
	return (cfg().get(RANKED.get(key, ""), []) as Array).find(text(era, key))

## What is wrong with the table, one line each (empty = fine): a missing key, an unknown style,
## a style that steps back or a switch that goes off again in a later era.
static func problems() -> Array[String]:
	var out: Array[String] = []
	for era: int in range(1, ERAS + 1):
		var e: Dictionary = for_era(era)
		for k: String in KEYS:
			if not e.has(k):
				out.append("era %d: missing %s" % [era, k])
		for k: String in RANKED:
			if rank(era, k) < 0:
				out.append("era %d: unknown %s '%s'" % [era, k, text(era, k)])
			elif era > 1 and rank(era, k) < rank(era - 1, k):
				out.append("era %d: %s steps back" % [era, k])
		if era > 1:
			for k: String in SWITCHES:
				if flag(era - 1, k) and not flag(era, k):
					out.append("era %d: %s goes off again" % [era, k])
	return out

## Number of HUD features on in [param era], for the "later eras never have fewer" rule.
static func feature_score(era: int) -> int:
	var n: int = 0
	for k: String in RANKED:
		n += maxi(rank(era, k), 0)
	for k: String in SWITCHES:
		n += 1 if flag(era, k) else 0
	n += 1 if text(era, "hp_numbers") == "roll" else 0
	n += 1 if text(era, "xp") == "fill" else 0
	n += 1 if num(era, "camera_follow") > 0.0 else 0
	return n

## True once the menu skin of data/era_feel.json is in the project (UITheme then carries the
## era's frame and palette, and the battle text box takes its frame from there).
static func skin_api() -> bool:
	if skin_override >= 0:
		return skin_override == 1
	return ResourceLoader.exists("res://scripts/core/EraFeel.gd")

# --- Colours and fonts ---------------------------------------------------------------

## HUD colours of [param era]: paper and ink from UITheme, the era's accent (bands, frames),
## light (rules, highlights) and shade (shadows). Era I and high contrast use the UI palette.
static func colours(era: int) -> Dictionary:
	var e: Dictionary = for_era(era)
	var own: bool = not UITheme.high_contrast and not str(e.get("accent", "")).is_empty()
	return {
		"paper": UITheme.BG, "ink": UITheme.INK,
		"accent": Color(str(e.accent)) if own else UITheme.MID,
		"light": Color(str(e.light)) if own else UITheme.ACCENT,
		"shade": Color(str(e.shade)) if own else UITheme.INK,
	}

static func large_font(era: int) -> bool:
	return UITheme.large_text or text(era, "font", "pixel") in ["large", "bold"]

## Era IV/V: the bold large font (thicker strokes on the wide screens).
static func bold_font(era: int) -> bool:
	return text(era, "font", "pixel") == "bold"

static func font(era: int) -> Font:
	if bold_font(era):
		return PixelFont.get_bold_font()
	return PixelFont.get_large_font() if large_font(era) else PixelFont.get_font()

static func ascent(era: int) -> int:
	if large_font(era):
		return PixelFont.LARGE_ASCENT
	var own: String = _own_font(era)
	return EraFont.ascent_of(own) if not own.is_empty() else PixelFont.ASCENT

## Height of one text line of [param era]'s font.
static func line_h(era: int) -> int:
	if large_font(era):
		return PixelFont.LARGE_H
	var own: String = _own_font(era)
	return EraFont.cell_height(own) if not own.is_empty() else PixelFont.CELL_H

## The era's own text font the battle theme carries in the current language (Era III writes
## English and German in the 10 px etching font, ascent 8, not the pixel font's 7: the plate
## rows were a pixel short and the status badge and stat marks ran into the next row).
static func _own_font(era: int) -> String:
	return EraText.font_id(era, Loc.language(), UITheme.large_text)

## The UI theme for a battle in [param era]: the shared theme, with the large font from the
## era that uses it (270 x 480 screens).
static func theme(era: int) -> Theme:
	var base: Theme = UITheme.get_theme()
	var want: Font = font(era)
	if not large_font(era) or base.default_font == want:
		return base
	var key: String = "%d:%d" % [base.get_instance_id(), want.get_instance_id()]
	if not _themes.has(key):
		_themes.clear()
		var t: Theme = base.duplicate()
		t.default_font = want
		_themes[key] = t
	return _themes[key]

## Fill of an element-coloured art button: the element's colour washed toward paper until ink
## text on it reaches 4.5:1.
static func art_fill(element: int) -> Color:
	var c: Color = Elements.color(element)
	var mix: float = 0.45
	var out: Color = c.lerp(UITheme.BG, mix)
	while UITheme.contrast(UITheme.INK, out) < 4.5 and mix < 1.0:
		mix += 0.1
		out = c.lerp(UITheme.BG, minf(mix, 1.0))
	return out

## The matchup word on an art button ("Strong", "Weak", "No effect"); "" when neutral, unknown
## or in an era without the detail line.
static func effect_hint(era: int, mult: float) -> String:
	if not flag(era, "art_detail"):
		return ""
	return str((cfg().get("hint_words", {}) as Dictionary).get(BattleUiStyle.matchup(mult), ""))

# --- Frames --------------------------------------------------------------------------

## The 9-slice picture of frame [param kind] filled with [param bg].
static func frame_image(kind: String, bg: Color, c: Dictionary) -> Image:
	var img := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var last: int = FRAME_SIZE - 1
	var clear := Color(0, 0, 0, 0)
	var ink: Color = c.ink
	var rings: Array[Color] = [ink, ink]
	match kind:
		"wash":
			rings = [ink, c.accent, c.light]
		"bevel":
			rings = [ink, c.paper, c.light]
		"panel", "gloss":
			rings = [ink, c.accent, c.accent]
	for i: int in FRAME_SIZE:
		for ring: int in rings.size():
			if i < ring or i > last - ring:
				continue
			var top: Color = rings[ring]
			var low: Color = rings[ring]
			if kind == "bevel" and ring == 1:
				# Light from the top left: bright upper and left edge, shaded lower and right.
				top = (c.light as Color).lerp(Color.WHITE, 0.5)
				low = c.accent
			elif kind == "bevel" and ring == 2 and i % 2 == 1:
				top = bg
				low = bg
			elif kind == "gloss" and ring == 2:
				top = (c.light as Color).lerp(Color.WHITE, 0.4)
				low = c.light
			img.set_pixel(i, ring, top)
			img.set_pixel(ring, i, top)
			img.set_pixel(i, last - ring, low)
			img.set_pixel(last - ring, i, low)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		var sx: int = 1 if p.x == 0 else -1
		var sy: int = 1 if p.y == 0 else -1
		match kind:
			"wash":
				img.set_pixel(p.x, p.y, clear)
				img.set_pixel(p.x + sx, p.y + sy, ink)
			"bevel":
				img.set_pixel(p.x + sx, p.y + sy, c.light)
			"panel", "gloss":
				# Cut corners: the slant of the plates, repeated on the frame.
				for k: int in 3:
					for j: int in 3 - k:
						img.set_pixel(p.x + sx * j, p.y + sy * k, clear)
				for k: int in 4:
					img.set_pixel(p.x + sx * (3 - k), p.y + sy * k, ink)
	return img

## Frame of [param era] as a stylebox (battle text box, command panel, panels). With the menu
## skin in the project, or a high-contrast screen, the shared UITheme frame is used instead.
static func frame_style(era: int, bg: Color = UITheme.BG) -> StyleBox:
	if skin_api():
		return UITheme.panel_style(bg)
	var kind: String = text(era, "frame", "plain")
	var c: Dictionary = colours(era)
	var key: String = "%s:%s:%s:%s" % [kind, bg.to_html(), (c.ink as Color).to_html(), (c.accent as Color).to_html()]
	if not _frames.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(frame_image(kind, bg, c))
		sb.texture_margin_left = FRAME_MARGIN
		sb.texture_margin_top = FRAME_MARGIN
		sb.texture_margin_right = FRAME_MARGIN
		sb.texture_margin_bottom = FRAME_MARGIN
		sb.set_content_margin_all(FRAME_PAD)
		_frames[key] = sb
	return _frames[key]

## Does the battle text box take this file's frame? Not over a worn shop frame, and not once
## the menu skin frames every text box itself.
static func frames_text_box(shop_frame: String) -> bool:
	return not skin_api() and not shop_frame in UITheme.TEXT_FRAMES

## Height of the battle text box in [param era]: three lines of its font inside the frame.
static func text_box_height(era: int) -> int:
	return maxi(44, TEXT_LINES * line_h(era) + FRAME_PAD * 2 + 2)

# --- Plates --------------------------------------------------------------------------

## Pixels the slanted side of a plate is cut in at row [param y] of [param h] (widest at the
## top), in whole pixels so the edge is a clean stair.
static func slant_inset(y: int, h: int, slant: int) -> int:
	if slant <= 0 or h <= 1:
		return 0
	return int(round(slant * (1.0 - float(y) / float(h - 1))))

## Draws a name plate over [param r] on [param ci]: plain box (I), washed box with soft corners
## (II), slanted plate with a name band (III), with a shadow (IV) and a gloss line (V).
## [param slant_left] says which side leans. [param band_h] is the height of the name band.
static func draw_plate(ci: CanvasItem, r: Rect2, era: int, slant_left: bool, band_h: int) -> void:
	var e: Dictionary = for_era(era)
	var c: Dictionary = colours(era)
	var slant: int = int(e.get("plate_slant", 0))
	var h: int = int(r.size.y)
	var soft: bool = str(e.get("plate", "plain")) == "tab"
	var shadow: int = 2 if bool(e.get("plate_shadow", false)) else 0
	for pass_i: int in (2 if shadow > 0 else 1):
		var is_shadow: bool = shadow > 0 and pass_i == 0
		var off := Vector2(shadow, shadow) if is_shadow else Vector2.ZERO
		for y: int in h:
			var cut: int = slant_inset(y, h, slant)
			if soft and (y == 0 or y == h - 1):
				cut = 1
			var x0: float = r.position.x + (cut if slant_left or soft else 0)
			var x1: float = r.end.x - (cut if not slant_left or soft else 0)
			var row := Rect2(Vector2(x0, r.position.y + y) + off, Vector2(x1 - x0, 1))
			if is_shadow:
				ci.draw_rect(row, Color(c.shade, 0.45))
				continue
			var edge: bool = y == 0 or y == h - 1
			var fill: Color = c.paper
			if bool(e.get("plate_header", false)) and y < band_h:
				fill = c.accent
				if bool(e.get("plate_gloss", false)) and y >= 1 and y <= 2:
					fill = (c.accent as Color).lerp(c.light, 0.45)
			elif soft and (y == 1 or y == h - 2):
				fill = c.light
			ci.draw_rect(row, c.ink if edge else fill)
			if not edge:
				ci.draw_rect(Rect2(row.position, Vector2.ONE), c.ink)
				ci.draw_rect(Rect2(Vector2(row.end.x - 1, row.position.y), Vector2.ONE), c.ink)
				if soft:
					ci.draw_rect(Rect2(row.position + Vector2(1, 0), Vector2.ONE), c.light)
					ci.draw_rect(Rect2(Vector2(row.end.x - 2, row.position.y), Vector2.ONE), c.light)
		if not is_shadow and bool(e.get("plate_header", false)) and band_h < h - 1:
			var cut_b: int = slant_inset(band_h, h, slant)
			var bx0: float = r.position.x + (cut_b if slant_left else 0) + 1
			var bx1: float = r.end.x - (cut_b if not slant_left else 0) - 1
			ci.draw_rect(Rect2(bx0, r.position.y + band_h, bx1 - bx0, 1), c.light)

## Padding a plate draws around its content: [left, top, right, bottom], with room for the
## slanted side and the shadow.
static func plate_pad(era: int, slant_left: bool) -> Array[int]:
	var slant: int = int(num(era, "plate_slant"))
	var shadow: int = 2 if flag(era, "plate_shadow") else 0
	return [3 + (slant if slant_left else 0), 2, 3 + (0 if slant_left else slant) + shadow, 2 + shadow]

## Where the battle camera moved a point: a share of how far [param anchor] travels when the
## field is scaled by [param zoom] around [param pivot] (Era V plates lean after the camera).
static func camera_shift(pivot: Vector2, zoom: Vector2, anchor: Vector2, share: float) -> Vector2:
	if share <= 0.0 or zoom == Vector2.ONE:
		return Vector2.ZERO
	return (((anchor - pivot) * zoom + pivot - anchor) * share).round()

## Digits of an odometer showing [param value]: one {digit, next, shift} per place, left to
## right. shift 0..1 is how far the place has rolled toward its next digit; a place only turns
## while every place to its right passes from 9 to 0.
static func roll_digits(value: float, places: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: float = maxf(value, 0.0)
	var whole: int = int(floor(v))
	var carry: float = v - floor(v)
	for p: int in places:
		var d: int = int(whole / int(pow(10, p))) % 10
		out.push_front({"digit": d, "next": (d + 1) % 10, "shift": carry})
		carry = carry if d == 9 else 0.0
	return out

# --- Ring rise -----------------------------------------------------------------------

## Stat rows of the ring-rise panel for [param s] growing from ring [param from_level] to
## [param to_level]: [{key, label, old, new, gain}] for Vigor, Might, Guard, Focus and Pace.
static func stat_rows(s: Spirling, from_level: int, to_level: int) -> Array[Dictionary]:
	var keep: int = s.level
	var vals: Array[Array] = []
	for lv: int in [from_level, to_level]:
		s.level = maxi(lv, 1)
		vals.append([s.max_hp(), s.atk(), s.def(), s.foc(), s.spd()])
	s.level = keep
	var labels: Array[String] = ["Vigor", "Might", "Guard", "Focus", "Pace"]
	var out: Array[Dictionary] = []
	for i: int in labels.size():
		out.append({"key": Spirling.STAT_KEYS[i], "label": labels[i], "old": int(vals[0][i]), "new": int(vals[1][i]),
			"gain": int(vals[1][i]) - int(vals[0][i])})
	return out

# --- Team row ------------------------------------------------------------------------

## State of one team mark: "fit", "hurt" (half Vigor or less), "status" or "down".
static func team_state(s: Spirling) -> String:
	if s == null or s.is_fainted():
		return "down"
	if not s.status.is_empty():
		return "status"
	return "hurt" if s.hp_fraction() <= 0.5 else "fit"

## Colour of a team mark in [param era]: Era I ink only (down = hollow), Era II fit and hurt in
## colour, from Era III the status colour too.
static func team_colour(era: int, state: String, status: String = "") -> Color:
	var style: String = text(era, "team_row", "ink")
	if style == "ink" or state == "down":
		return UITheme.INK
	if state == "status" and style == "status":
		return Color(str((EraBattleFeel.cfg().get("status_colours", {}) as Dictionary).get(status, "6a4256")))
	return Color(str(cfg().get("hurt_colour" if state != "fit" else "fit_colour", "3e9a4a")))

## Width of a team row with [param n] marks.
static func team_row_size(era: int, n: int, compact: bool = false) -> Vector2:
	var m: int = int(num(era, "team_mark", 5)) - (1 if compact else 0)
	return Vector2(maxi(n, 0) * (m + 2) - (2 if n > 0 else 0), m)

# --- Layout --------------------------------------------------------------------------

## Rows inside a name plate of [param era], in content pixels: name baseline (asc), the Vigor
## bar (bar_y, bar_h), the Energy row (row3_y, row3_h), the baseline of the player's extra
## row with the Growth bar and the Vigor numbers (row4), and the heights with and without it.
## [param single]: the plates of a one-on-one battle, whose Vigor bar may be thicker (bar_h_single).
static func plate_rows(era: int, single: bool = false) -> Dictionary:
	var a: int = ascent(era)
	var bar_h: int = int(num(era, "bar_h_single" if single else "bar_h", 3))
	# The status tag stands from one pixel above the bar, one line high: the Energy row starts
	# under it even when the font is taller than the bar row (Era III's 10 px font).
	var row3: int = maxi(a + 2 + bar_h + 2 + 2, 2 * a + 2)
	var row3_h: int = maxi(8, a)
	return {"asc": a, "bar_y": a + 2, "bar_h": bar_h, "row3_y": row3, "row3_h": row3_h, "row4": row3 + row3_h + a,
		"h": row3 + row3_h, "h_extra": row3 + row3_h + a + 1}

## Height of a name plate's content in [param era]; [param extra_row] adds the Growth bar and
## Vigor numbers of the player's own plate.
static func plate_height(era: int, extra_row: bool, single: bool = false) -> int:
	return int(plate_rows(era, single)["h_extra" if extra_row else "h"])

static func side_button(era: int) -> Vector2:
	return SIDE_BUTTON_LARGE if large_font(era) else SIDE_BUTTON

## Height of the command panel in [param era] (fixed, so the field never jumps).
static func menu_height(era: int) -> int:
	var e: Dictionary = for_era(era)
	var arts: int = Spirling.MAX_MOVES * int(e.get("art_h", 13)) + (Spirling.MAX_MOVES - 1)
	var extra: int = (shortcut_height(era) + 2) if bool(e.get("item_shortcut", false)) else 0
	if str(e.get("commands", "row")) == "column":
		# Era IV/V: the commands and the item shortcut stand in a column beside the arts.
		return maxi(arts, command_column_height(era)) + FRAME_PAD * 2 - 2
	var rows: int = 2 if str(e.get("commands", "row")) == "grid" else 1
	var cmds: int = rows * int(e.get("command_h", 16)) + (rows - 1)
	return arts + 2 + cmds + extra + FRAME_PAD * 2 - 2

## Height of the command column (commands "column"): four commands, then the item shortcut.
static func command_column_height(era: int) -> int:
	var e: Dictionary = for_era(era)
	var extra: int = (shortcut_height(era) + 2) if bool(e.get("item_shortcut", false)) else 0
	return 4 * int(e.get("command_h", 16)) + 3 + extra

## Share of the panel width the arts take when the commands stand in a column beside them.
const ART_SHARE: float = 0.7

static func shortcut_height(era: int) -> int:
	return line_h(era) + 6

## Where everything of the one-on-one HUD goes on a field of [param field] pixels, given the
## two sprite rects the stage hands in. Returns rects (field coordinates): foe_plate,
## player_plate (content rects), foe_sprite, player_sprite (moved in Era I-III so no plate
## covers a sprite), buttons (3), goal, foe_team, player_team, level_panel; and flags
## foe_slant_left, player_slant_left. Nothing in it overlaps (tests/unit/test_era_battle_hud.gd).
static func single_layout(era: int, field: Vector2, foe_sprite: Rect2, player_sprite: Rect2, team: int = 7) -> Dictionary:
	var w: float = field.x
	var h: float = field.y
	var stage: bool = era >= EraManager.STAGE_25D_FROM
	var b: Vector2 = side_button(era)
	var out: Dictionary = {"foe_slant_left": true}
	var fh: float = plate_height(era, false, true)
	var ph: float = plate_height(era, true, true)
	var fpad: Array[int] = plate_pad(era, true)
	var buttons: Array[Rect2] = []
	var row: Vector2 = team_row_size(era, team)
	if stage:
		# Stage eras: the slabs place the sprites. Buttons stand in a column at the top left,
		# the foe's plate at the top right, the player's plate at the bottom right.
		for i: int in 3:
			buttons.append(Rect2(MARGIN, MARGIN + i * (b.y + 2), b.x, b.y))
		var fw: float = roundf(w * 0.5)
		out["foe_plate"] = Rect2(w - MARGIN - fpad[2] - fw, MARGIN + fpad[1], fw, fh)
		out["foe_team"] = Rect2(w - MARGIN - row.x, MARGIN + fpad[1] + fh + fpad[3] + 3, row.x, row.y)
		# The big Era IV/V back sprite may reach under the plate; the plate keeps room for its name.
		var pw: float = maxf(roundf(w - player_sprite.end.x - MARGIN * 2 - fpad[0] - fpad[2]), roundf(w * MIN_PLAYER_PLATE))
		out["player_slant_left"] = true
		out["player_plate"] = Rect2(w - MARGIN - fpad[2] - pw, h - MARGIN - fpad[3] - ph, pw, ph)
		out["player_team"] = Rect2(w - MARGIN - row.x, h - MARGIN - fpad[3] - ph - fpad[1] - 3 - row.y, row.x, row.y)
		out["goal"] = Rect2(MARGIN, MARGIN + 3 * (b.y + 2), roundf(w * 0.4), line_h(era) * 2)
	else:
		# Era I-III: foe at the top left with its plate to the right, the small buttons in a
		# row under that plate; the player's Spirling at the bottom right, its plate to the left.
		var fs: float = foe_sprite.size.x
		foe_sprite = Rect2(Vector2(MARGIN, MARGIN), foe_sprite.size)
		player_sprite.position.x = w - MARGIN - player_sprite.size.x
		var fx: float = MARGIN + fs + 2 + fpad[0]
		out["foe_plate"] = Rect2(fx, MARGIN + fpad[1], w - MARGIN - fpad[2] - fx, fh)
		var by: float = MARGIN + fpad[1] + fh + fpad[3] + 3
		for i: int in 3:
			buttons.append(Rect2(w - MARGIN - (3 - i) * b.x - (2 - i), by, b.x, b.y))
		out["foe_team"] = Rect2(w - MARGIN - row.x, by + b.y + 3, row.x, row.y)
		var ppad: Array[int] = plate_pad(era, false)
		var pw: float = player_sprite.position.x - MARGIN - 2 - ppad[0] - ppad[2]
		out["player_slant_left"] = false
		out["player_plate"] = Rect2(MARGIN + ppad[0], h - MARGIN - ppad[3] - ph, pw, ph)
		out["player_team"] = Rect2(MARGIN, h - MARGIN - ppad[3] - ph - ppad[1] - 3 - row.y, row.x, row.y)
		var gy: float = foe_sprite.end.y + 2
		out["goal"] = Rect2(MARGIN, gy, player_sprite.position.x - MARGIN - 2, maxf(float(out.player_team.position.y) - 2 - gy, 0.0))
	out["foe_sprite"] = foe_sprite
	out["player_sprite"] = player_sprite
	out["buttons"] = buttons
	return out

## The outer rect a plate draws over, from its content rect.
static func plate_outer(era: int, content: Rect2, slant_left: bool) -> Rect2:
	var p: Array[int] = plate_pad(era, slant_left)
	return Rect2(content.position - Vector2(p[0], p[1]), content.size + Vector2(p[0] + p[2], p[1] + p[3]))

## Top band of the formation HUD (several Spirlings per side) on a field [param w] wide:
## ledger (content rect of the plate of the Spirling in focus), buttons (3; Back takes the
## third while aiming), goal, player_team, foe_team. Era I-III keep the ledger across the top
## with both team rows on one line under it; the wide Era IV/V screens put the buttons in a row
## beside a shorter ledger. Everything ends above FORMATION_TOP, where the foes' rank starts.
const FORMATION_TOP: int = 48
static func formation_layout(era: int, w: float, team: int = 7) -> Dictionary:
	var b: Vector2 = side_button(era)
	var pad: Array[int] = plate_pad(era, false)
	var ph: float = plate_height(era, true)
	var out: Dictionary = {}
	var buttons: Array[Rect2] = []
	var row: Vector2 = team_row_size(era, team, true)
	if large_font(era) and w >= 240.0:
		var bx: float = w - MARGIN - 3 * b.x - 4
		for i: int in 3:
			buttons.append(Rect2(bx + i * (b.x + 2), MARGIN, b.x, b.y))
		# One pixel higher than the margin: the tall plate and its shadow end on the foes' rank.
		out["ledger"] = Rect2(MARGIN + pad[0], MARGIN - 1 + pad[1], bx - MARGIN * 2 - pad[0] - pad[2], ph)
		out["player_team"] = Rect2(bx, MARGIN + b.y + 4, row.x, row.y)
		out["foe_team"] = Rect2(bx, MARGIN + b.y + 4 + row.y + 3, row.x, row.y)
		var gx: float = bx + row.x + 4
		out["goal"] = Rect2(gx, MARGIN + b.y + 2, maxf(w - MARGIN - gx, 0.0), FORMATION_TOP - (MARGIN + b.y + 2))
	else:
		for i: int in 3:
			buttons.append(Rect2(w - MARGIN - b.x, MARGIN + i * (b.y + 2), b.x, b.y))
		out["ledger"] = Rect2(MARGIN + pad[0], MARGIN + pad[1], w - b.x - MARGIN * 3 - pad[0] - pad[2], ph)
		var band: float = MARGIN + pad[1] + ph + pad[3] + 1
		var right: float = w - b.x - MARGIN * 2
		out["player_team"] = Rect2(MARGIN, band, row.x, row.y)
		out["foe_team"] = Rect2(right - row.x, band, row.x, row.y)
		out["goal"] = Rect2(MARGIN + row.x + 3, band - 1, maxf(right - row.x - 6 - MARGIN - row.x, 0.0), FORMATION_TOP - band)
	out["buttons"] = buttons
	return out
