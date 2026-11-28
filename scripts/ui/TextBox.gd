class_name TextBox
extends PanelContainer
## Typewriter text box. show_text() is awaitable: it returns once the player taps / presses
## accept after the text is fully shown (or immediately-ish in auto mode).

signal advanced
## Fires each frame from _process. The typing loop waits on this own signal, so a box freed
## mid-line drops the wait instead of resuming on a gone instance.
signal _ticked

## Seconds to linger before auto-advancing when [member auto_advance] is on.
const AUTO_DELAY: float = 0.35
const MARGIN: int = 3

var auto_advance: bool = false
## The world's talk box: with the "Auto text" setting a waiting line moves on by itself (item 2015).
var world_auto: bool = false
## Called right before the box opens, so its owner can move it (the map puts it on top
## when the Wayfarer stands low, item 2016).
var place_hook: Callable
## Counts shown pages, so an old auto-text timer never skips a newer line.
var _page_no: int = 0
## Text voice of the current speaker (Sound.VOICE_PITCH key); a line that starts with a known
## name and a colon ("Kestra: ...") uses that name's voice instead (item 2503).
var voice: String = "player"
var _line_voice: String = "player"
var _blipped: int = 0
var chars_per_second: float = 60.0
## Typing speed factor of the era on screen (data/era_feel.json "text_cps_mult"): later eras
## type a little faster, the way later handhelds did.
var era_speed: float = 1.0
## At most this many lines per window; longer texts go on to the next window (item 2043).
const MAX_LINES: int = 3
## Holding the box (or A) this long runs on to the next question (item 2013).
const LONG_PRESS_MS: int = 600
## Set by the overworld: a long press fast-forwards. Battles keep every line.
var allow_fast_forward: bool = false
## Set by the battle: the music dips while a line shows (KAMPF_PLAN_1000 695).
var duck_music: bool = false
## True after a long press, until the box hides (questions open after the box hides).
var fast_forward: bool = false
var _press_ms: int = -1

var _label: Label
var _arrow: Label
## Name tag over the box for the one who speaks (plan item 1343).
var _tag: Label
## Head on the name plate (Era IV) or portrait on the box (Era V) of the one who speaks.
var _portrait: SpeakerPortrait
## Least padding reserved for the continue marker on the right (and as much on the left, so
## centred lines stay in the middle).
const ARROW_SPACE: int = 6
## Clear pixels between the end of a line and the continue marker.
const ARROW_GAP: int = 3
## Padding in use: the marker's width in its font plus ARROW_GAP, at least ARROW_SPACE.
var _arrow_space: int = ARROW_SPACE
var _label_pad: StyleBoxEmpty
var _typing: bool = false
var _waiting: bool = false
var _visible_chars: float = 0.0
## Taps this soon after a line is fully shown are ignored, so the second tap of a double tap
## cannot skip a line unread (item 1783).
const READ_GUARD_MS: int = 150
var _shown_ms: int = -100000
## The box rises this far into place when it opens (item 2286).
const OPEN_RISE: int = 6
## Between pages the old text slides up and fades out first (item 2287).
const PAGE_LIFT: int = 2
const PAGE_OUT_TIME: float = 0.08
## The continue marker bobs 1 px, one full cycle per ARROW_BOB_PERIOD seconds (item 2288).
const ARROW_BOB_PERIOD: float = 0.5
var _arrow_pad: StyleBoxEmpty
var _bob_time: float = 0.0

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style())
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	# Text is translated once in show_text() so the typewriter counts the shown characters.
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# Screen readers announce each new line as it appears (item 77).
	_label.accessibility_live = AccessibilityServer.LIVE_POLITE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Talk on the map: left-aligned in the screen's own font, as before update 1.3.0 (owner wish
	# 25.11.2026). The battle box keeps the centred, larger lines of 23.11.2026 (big_text).
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if big_text else HORIZONTAL_ALIGNMENT_LEFT
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep wrapped text clear of the continue marker in the corner.
	_label_pad = StyleBoxEmpty.new()
	_label_pad.content_margin_right = ARROW_SPACE
	_label.add_theme_stylebox_override("normal", _label_pad)
	add_child(_label)
	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_arrow.visible = false
	_arrow_pad = StyleBoxEmpty.new()
	_arrow.add_theme_stylebox_override("normal", _arrow_pad)
	add_child(_arrow)
	_tag = Label.new()
	_tag.top_level = true
	_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tag.add_theme_stylebox_override("normal", UITheme.panel_style())
	_tag.visible = false
	add_child(_tag)
	_portrait = SpeakerPortrait.attach(self)
	visibility_changed.connect(func() -> void:
		if not visible:
			fast_forward = false
			_press_ms = -1
		else:
			if place_hook.is_valid():
				_set_rise(0)
				place_hook.call()
			_rise_in())

## Opening: the box comes up OPEN_RISE pixels from below with the "open" curve. Only where
## the box places itself (the map); inside a container the layout owns its position.
## The shift is applied relative to the last step, so the box may still grow upward for long
## text while it rises.
func _rise_in() -> void:
	if Juice.reduced() or get_parent() is Container or not is_inside_tree():
		return
	_set_rise(OPEN_RISE)
	Juice.tween(self, "rise", 0, "open")

## Closing: the box sinks OPEN_RISE pixels and fades with the "close" curve, then hides
## (item 2286). Instant under reduced motion and inside a container. Awaitable.
func close() -> void:
	if not visible:
		return
	if Juice.reduced() or get_parent() is Container or not is_inside_tree():
		visible = false
		return
	Juice.tween(self, "modulate:a", 0.0, "close")
	await Juice.tween(self, "rise", OPEN_RISE, "close").finished
	visible = false
	_set_rise(0)
	modulate.a = 1.0

## Pixels the box currently sits below its place (0 when settled).
var rise: int = 0:
	set(v):
		position.y += v - rise
		rise = v

func _set_rise(v: int) -> void:
	rise = v

## The box frame of the era on screen (docs/ERA_FEEL_UI.md), on the map and in battle alike: a
## worn shop frame when one is chosen, else the era's frame (ink, wash, etched, panorama,
## living) for the box and the name tag, and the era's typing speed.
func apply_era_frame() -> void:
	var sb: StyleBox = UITheme.text_frame_style(GameState.dialogue_frame())
	if pad_y >= 0:
		sb = sb.duplicate()
		sb.content_margin_top = pad_y
		sb.content_margin_bottom = pad_y
	add_theme_stylebox_override("panel", sb)
	if _tag != null:
		_tag.add_theme_stylebox_override("normal", UITheme.panel_style())
	era_speed = maxf(0.1, float(EraManager.feel("text_cps_mult")))
	_apply_big_font()
	_reserve_arrow()

## Keeps the continue marker clear of the text.
func _reserve_arrow() -> void:
	if _arrow == null or _label_pad == null:
		return
	var f: Font = _arrow.get_theme_font("font")
	var w: int = int(ceilf(f.get_string_size(_arrow.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _arrow.get_theme_font_size("font_size")).x)) if f != null else 0
	_arrow_space = maxi(ARROW_SPACE, w + ARROW_GAP)
	_label_pad.content_margin_left = _arrow_space if big_text else 0
	_label_pad.content_margin_right = _arrow_space

## Talk and battle lines are one font step larger than the screen around them (owner wish
## 23.11.2026, plan Chimora 100): a line under the large 12 px height takes the large glyphs
## (or the era's own font when it is that tall). A line already that tall is drawn at
## BIG_SCALE times the small glyphs when [param allow_double] is set (the map's talk box),
## else it stays (the Era IV/V battle box keeps its large bold HUD font: doubled, the
## two-part order prompt ran past the box). Returns [font, font size].
const BIG_SCALE: int = 2
## Centred, one step larger lines (owner wish 23.11.2026). Set by the battle; the map's talk
## box is back to the plain text since 25.11.2026 (owner: "Texte im Chat gleich machen wie davor").
var big_text: bool = false
static func big_font(inherited: Font, size: int, allow_double: bool) -> Array:
	if inherited != null and inherited.get_height(size) >= PixelFont.LARGE_H:
		return [PixelFont.get_font(), UITheme.FONT_SIZE * BIG_SCALE] if allow_double else [inherited, size]
	var own: FontFile = EraText.font(true)
	return [own if own != null else PixelFont.get_large_font(), UITheme.FONT_SIZE]

## False in battle: see big_font().
var allow_double: bool = true
## Padding above and below the text, -1 for the frame's own. The battle box uses a tighter one,
## so three large lines fit the 44 px box of the 144 px eras.
var pad_y: int = -1
## Set by the battle: a prompt too long for MAX_LINES larger lines keeps the smaller font.
var fit_prompt: bool = false

func _apply_big_font() -> void:
	if _label == null:
		return
	_label.remove_theme_font_override("font")
	_label.remove_theme_font_size_override("font_size")
	if not big_text:
		return
	var big: Array = big_font(_label.get_theme_font("font"), _label.get_theme_font_size("font_size"), allow_double)
	_label.add_theme_font_override("font", big[0])
	_label.add_theme_font_size_override("font_size", big[1])

## The last talk lines of the overworld (200 list items 14, 115), newest last, for the Talk log
## under More. Only a box with [member keep_log] writes here, so battle lines stay out.
static var talk_log: Array[String] = []
const TALK_LOG_MAX: int = 20
var keep_log: bool = false

static func log_line(line: String) -> void:
	if line.strip_edges().is_empty():
		return
	talk_log.append(line)
	while talk_log.size() > TALK_LOG_MAX:
		talk_log.remove_at(0)

## Shows [param text] with the typewriter effect and waits for the player (or the auto timer).
func show_text(text: String, speaker: String = "") -> void:
	# A worn shop text frame (item 4282); the plain box otherwise.
	apply_era_frame()
	# Story lines may address the player by name: "{name}" (after translation).
	var shown: String = Loc.t(text).replace("{name}", GameState.tamer_name)
	# Old lines carry the speaker as "Aldo: ..."; it moves to the name tag. A name in the
	# line wins over the one passed in (the NPC's role, item 2011).
	# The English line decides whether someone is named, so Japanese and Chinese "名前：" lines
	# get the name tag (and the Era IV/V portrait) too.
	var parts: PackedStringArray = Dialogue.split_translated(text.replace("{name}", GameState.tamer_name), shown)
	var key: String = speaker
	if not parts[0].is_empty():
		speaker = parts[0]
		shown = parts[1]
		key = parts[2]
	else:
		speaker = Loc.t(speaker).replace("{name}", GameState.tamer_name)
	set_speaker(speaker, key)
	if keep_log:
		log_line((speaker + ": " if not speaker.is_empty() else "") + shown)
	_line_voice = voice_for_line(speaker + ": " if not speaker.is_empty() else shown, voice)
	var pages: Array[String] = split_lines(shown, _text_width(), _label.get_theme_font("font"),
			_label.get_theme_font_size("font_size"), MAX_LINES)
	if duck_music:
		Sound.duck_music(true)
	for i: int in pages.size():
		if i > 0:
			await _page_out()
		await _show_page(pages[i])
	if duck_music:
		Sound.duck_music(false)

## The old page lifts PAGE_LIFT pixels and fades before the next one types (item 2287).
func _page_out() -> void:
	if fast_forward or auto_advance or Juice.reduced() or not is_visible_in_tree():
		return
	var home: Vector2 = _label.position
	var tw: Tween = _label.create_tween().set_parallel()
	Juice.shaped(tw.tween_property(_label, "position:y", home.y - PAGE_LIFT, PAGE_OUT_TIME), "close")
	Juice.shaped(tw.tween_property(_label, "modulate:a", 0.0, PAGE_OUT_TIME), "close")
	await tw.finished
	_label.position = home
	_label.modulate.a = 1.0

func _show_page(page: String) -> void:
	_label.text = page
	if fast_forward:
		_label.visible_characters = -1
		_typing = false
		_waiting = false
		await get_tree().process_frame
		return
	_label.visible_characters = 0
	_visible_chars = 0.0
	_blipped = 0
	_typing = true
	_waiting = false
	_arrow.visible = false
	while _typing:
		await _ticked
	if auto_advance:
		await get_tree().create_timer(AUTO_DELAY).timeout
		return
	_waiting = true
	_arrow.visible = true
	_page_no += 1
	if world_auto and GameState.auto_text:
		_auto_next(_page_no, auto_text_delay(page))
	await advanced
	_arrow.visible = false

## Seconds a world line waits under "Auto text": 1.5 s plus 0.05 s per character (item 2015).
static func auto_text_delay(page: String) -> float:
	return 1.5 + 0.05 * page.length()

func _auto_next(page_no: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self) and _waiting and page_no == _page_no and GameState.auto_text:
		_waiting = false
		advanced.emit()

## Voice for [param line]: a known speaker name before a colon wins over [param fallback].
static func voice_for_line(line: String, fallback: String) -> String:
	var colon: int = line.find(":")
	if colon > 0 and colon <= 12:
		var key: String = Sound.voice_for(line.substr(0, colon).to_lower())
		if key != "villager" and key != "player":
			return key
	return fallback

## Shows text without waiting (prompts such as "Orders for Kindlop?").
func show_prompt(text: String, speaker: String = "") -> void:
	apply_era_frame()
	var shown: String = Loc.t(text).replace("{name}", GameState.tamer_name)
	var key: String = speaker
	if speaker.is_empty():
		var parts: PackedStringArray = Dialogue.split_translated(text.replace("{name}", GameState.tamer_name), shown)
		speaker = parts[0]
		shown = parts[1]
		key = parts[2]
	set_speaker(speaker, key)
	# A prompt does not page: in battle one longer than MAX_LINES in the larger font (the order
	# line of a formation battle) keeps the screen's own font, so the box leaves the field room.
	if fit_prompt and split_lines(shown, _text_width(), _label.get_theme_font("font"), _label.get_theme_font_size("font_size"), MAX_LINES).size() > 1:
		_label.remove_theme_font_override("font")
		_label.remove_theme_font_size_override("font_size")
	_label.text = shown
	_label.visible_characters = -1
	_typing = false
	_waiting = false
	_arrow.visible = false

## Shows [param who] on the name tag over the box ("" hides it). [param key] is the English
## name the later eras look the portrait up by (the shown name when empty).
func set_speaker(who: String, key: String = "") -> void:
	_tag.text = who
	_tag.visible = not who.is_empty()
	if _portrait != null:
		_portrait.show_for(key if not key.is_empty() and not who.is_empty() else who, _tag)
	_place_tag()

func speaker() -> String:
	return _tag.text if _tag.visible else ""

## True while a line is still being typed (the Era V portrait moves its mouth).
func is_typing() -> bool:
	return _typing

## The name tag sits on the box's top edge, or under it when a box at the top leaves no room.
static func tag_offset_y(box_y: float, box_h: float, tag_h: float) -> float:
	var y: float = -tag_h + 2.0
	return y if box_y + y >= 0.0 else box_h - 2.0

func _place_tag() -> void:
	if _tag.visible:
		_tag.global_position = global_position + Vector2(2, tag_offset_y(global_position.y, size.y, _tag.size.y))
		_tag.visible = is_visible_in_tree()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _tag != null:
		_tag.visible = is_visible_in_tree() and not _tag.text.is_empty()
		_place_tag()

## Width the text can use inside the box.
func _text_width() -> float:
	var w: float = size.x if size.x > 0.0 else get_viewport_rect().size.x
	var sb: StyleBox = get_theme_stylebox("panel")
	if sb != null:
		w -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	return w - _arrow_space * (2 if big_text else 1)

## Wraps [param text] word by word to [param width] and groups the lines into windows of
## [param max_lines]. A line break in the text starts a new line.
static func split_lines(text: String, width: float, font: Font, font_size: int, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	for para: String in text.split("\n"):
		var line: String = ""
		for word: String in para.split(" ", false):
			var tried: String = word if line.is_empty() else line + " " + word
			if _fits(tried, width, font, font_size):
				line = tried
			elif not _fits(word, width, font, font_size):
				# Japanese and Chinese have no spaces: a run wider than the box breaks between characters.
				line = _break_run("" if line.is_empty() else line + " ", word, lines, width, font, font_size)
			else:
				lines.append(line)
				line = word
		lines.append(line)
	var pages: Array[String] = []
	for i: int in range(0, lines.size(), maxi(1, max_lines)):
		pages.append("\n".join(lines.slice(i, i + max_lines)))
	return pages

## Characters a Japanese or Chinese line never starts with; the one before moves down with them.
const NO_LINE_START: String = "。、，．！？：；」』）〉》】・ー…,.!?:;)"

static func _fits(text: String, width: float, font: Font, font_size: int) -> bool:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width

## Adds [param run] to [param line] character by character, pushing full lines to
## [param lines]; returns the unfinished last line.
static func _break_run(line: String, run: String, lines: Array[String], width: float, font: Font, font_size: int) -> String:
	for c: String in run:
		if line.strip_edges().is_empty() or _fits(line + c, width, font, font_size):
			line += c
		elif NO_LINE_START.contains(c) and line.length() > 1:
			lines.append(line.left(-1).strip_edges(false, true))
			line = line.right(1) + c
		else:
			lines.append(line.strip_edges(false, true))
			line = c
	return line

## Starts fast-forward: the current line ends, the next ones run without waiting.
func start_fast_forward() -> void:
	if not allow_fast_forward:
		return
	fast_forward = true
	_press_ms = -1
	if _typing:
		_label.visible_characters = -1
		_typing = false
	elif _waiting:
		_waiting = false
		advanced.emit()

func _process(delta: float) -> void:
	_ticked.emit()
	if _press_ms >= 0 and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		start_fast_forward()
	if _tag.visible:
		_place_tag()
	_bob_arrow(delta)
	if not _typing:
		return
	_visible_chars += delta * chars_per_second * era_speed
	_label.visible_characters = int(_visible_chars)
	var text: String = _label.text
	while _blipped < mini(_label.visible_characters, text.length()):
		Sound.text_blip(_line_voice, text[_blipped])
		_blipped += 1
	if _label.visible_characters >= _label.get_total_character_count():
		_label.visible_characters = -1
		_typing = false
		_shown_ms = Time.get_ticks_msec()

func _bob_arrow(delta: float) -> void:
	if not _arrow.visible:
		_bob_time = 0.0
		_arrow_pad.content_margin_bottom = 0
		return
	_bob_time = fmod(_bob_time + delta, ARROW_BOB_PERIOD)
	var up: bool = not Juice.reduced() and _bob_time >= ARROW_BOB_PERIOD / 2.0
	_arrow_pad.content_margin_bottom = 1 if up else 0

## Finishes the current line and continues at once (scene "Skip").
func advance_now() -> void:
	if _typing:
		_label.visible_characters = -1
		_typing = false
	if _waiting:
		_waiting = false
		advanced.emit()

func _skip_or_advance(tap: bool = false) -> void:
	if _typing:
		_label.visible_characters = -1
		_typing = false
		_shown_ms = Time.get_ticks_msec()
	elif _waiting:
		if tap and Time.get_ticks_msec() - _shown_ms < READ_GUARD_MS:
			return
		_waiting = false
		advanced.emit()

func _gui_input(event: InputEvent) -> void:
	# A tap on the pad's A button already advances through ui_accept (item 1818).
	if TapInput.is_press(event) and VirtualPad.covers(get_global_transform_with_canvas() * TapInput.position(event)):
		return
	if TapInput.is_press(event):
		_press_ms = Time.get_ticks_msec()
		_skip_or_advance(true)
		accept_event()
	elif TapInput.is_release(event):
		_press_ms = -1

func _unhandled_input(event: InputEvent) -> void:
	# B moves talk on just like A (item 2018), so nobody who presses B gets stuck.
	if (_typing or _waiting) and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_press_ms = Time.get_ticks_msec()
		_skip_or_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_accept") or event.is_action_released("ui_cancel"):
		_press_ms = -1
