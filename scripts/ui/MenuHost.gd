class_name MenuHost
extends Control
## Full-screen menu layer with a list picker and an info panel. Menus are coroutines:
## await host.pick(...), await host.info(...). Shared by the title screen and pause menu.

const PANEL_MARGIN: int = 6

var picker: ListPicker
var _info_panel: PanelContainer
var _info_label: Label
## Optional picture above the info text (gear pages, area 3 item 1050).
var _info_picture: TextureRect
var _info_scroll: ScrollContainer
var _info_wait: bool = false
## Set while the whole menu closes at once (item 1874): every pick answers Back at once.
var close_all: bool = false
var _close_steps: int = 0
const CLOSE_ALL_MAX: int = 40
var _info_bar: Control
const INFO_BAR_W: int = 2
## Where the finger went down while an info text is open (NAN = no press yet), so a drag
## that scrolls the text does not also close it.
var _info_press: Vector2 = Vector2(NAN, NAN)
const TAP_SLOP: float = 6.0
signal _info_closed
## Short note at the top that goes away by itself (item 1839).
var _toast: Label
var _toast_gen: int = 0
var _toast_source: String = ""
var _info_source: String = ""
const TOAST_SECONDS: float = 1.5

func _ready() -> void:
	theme = UITheme.get_theme()
	add_to_group(THEME_GROUP)
	Loc.events.language_changed.connect(_on_language_changed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker = ListPicker.new()
	_fill(picker)
	add_child(picker)
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	_fill(_info_panel)
	_info_panel.visible = false
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info_panel)
	# Long texts (privacy note, German, small title-screen panel) scroll instead of running
	# off the bottom of the screen, where "(tap to continue)" could not be seen.
	# Picture (gear pages) above the scrolling text.
	var box := VBoxContainer.new()
	_info_panel.add_child(box)
	_info_picture = TextureRect.new()
	_info_picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_info_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_info_picture.visible = false
	box.add_child(_info_picture)
	_info_scroll = ScrollContainer.new()
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.scroll_deadzone = int(TAP_SLOP)
	_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_info_scroll)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.custom_minimum_size = Vector2(1, 0)
	# Translated in info(): inside the scroll box the automatic translation did not apply.
	_info_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# Screen readers read new info texts like dialogue lines (item 2087).
	_info_label.accessibility_live = AccessibilityServer.LIVE_POLITE
	_info_scroll.add_child(_info_label)
	# Item 1840: a 2 px bar on the right edge when the text is longer than the window.
	_info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_info_bar = Control.new()
	_info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_bar.draw.connect(_draw_info_bar)
	_info_panel.add_child(_info_bar)
	_info_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _info_bar.queue_redraw())
	_info_scroll.get_v_scroll_bar().changed.connect(_info_bar.queue_redraw)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_left = PANEL_MARGIN + 4
	_toast.offset_right = -PANEL_MARGIN - 4
	_toast.offset_top = PANEL_MARGIN + 2
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.accessibility_live = AccessibilityServer.LIVE_POLITE
	_toast.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_toast.visible = false
	_toast.z_index = 10
	add_child(_toast)

func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_left = PANEL_MARGIN
	c.offset_top = PANEL_MARGIN
	c.offset_right = -PANEL_MARGIN
	c.offset_bottom = -PANEL_MARGIN
	# Keep menus clear of notches and the gesture bar once the viewport is known.
	c.ready.connect(func() -> void: SafeArea.apply(c, PANEL_MARGIN), CONNECT_ONE_SHOT)

## Lists and info windows opened so far, and what the last list showed (the menu walk test,
## item 2210, uses these to see that every row does something).
var picks: int = 0
var infos: int = 0
var last_title: String = ""
var last_rows: Array[String] = []

## Share of the screen height left free above menus in one-hand mode (item 2108): lists and
## texts sit in the lower 60 percent, where the thumb reaches.
const ONE_HAND_TOP: float = 0.4
const ONE_HAND_MIN_H: float = 72.0

## Moves the list and the info window down in one-hand mode and back up when it is off.
func apply_hand_layout() -> void:
	if not is_inside_tree():
		return
	var vp_h: float = get_viewport_rect().size.y
	for c: Control in [picker, _info_panel] as Array[Control]:
		if not c.has_meta("top"):
			c.set_meta("top", c.offset_top)
		var top: float = float(c.get_meta("top"))
		if GameState.one_hand:
			var low: float = vp_h * ONE_HAND_TOP
			# With the pad on screen the list ends above it; keep room for a few rows.
			var pad_top: float = VirtualPad.top_y()
			if pad_top > 0.0:
				low = minf(low, pad_top - ONE_HAND_MIN_H)
			top = maxf(top, low - global_position.y)
		c.offset_top = top
	picker.set_one_hand(GameState.one_hand, GameState.left_handed)

## Shows a list; returns the index or -1 (Back / cancel).
func pick(title: String, entries: Array[Dictionary], cancellable: bool = true, focus: int = -1,
		guard_ms: int = ListPicker.TAP_GUARD_MS, tabs: Array[String] = [], tab: int = 0) -> int:
	if close_all:
		# Item 1874: every open level answers Back until the menu is closed. One frame per
		# level, and a cap, so a list that ignores Back cannot spin forever.
		_close_steps += 1
		if _close_steps > CLOSE_ALL_MAX:
			close_all = false
		await get_tree().process_frame
		return -1
	picks += 1
	last_title = title
	last_rows.clear()
	for e: Dictionary in entries:
		last_rows.append(str(e.get("text", "")))
	apply_hand_layout()
	# Item 1850: a question longer than three lines shows in full first; the list keeps
	# only its last sentence (or "Your choice:") as the title.
	if title_lines(title) > TITLE_MAX_LINES:
		await info(title)
		title = short_title(title)
	var bottom: float = picker.offset_bottom
	keep_above_pad(picker)
	# The era's list layout (EraMenus): plain lists take the era's base, screens their own.
	var lay: Dictionary = _next_layout if not _next_layout.is_empty() else EraMenus.layout(EraManager.active_era())
	_next_layout = {}
	picker.layout = lay
	last_layout = lay
	var r: int = await picker.pick(title, entries, cancellable, focus, guard_ms, tabs, tab)
	picker.offset_bottom = bottom
	return r

var _next_layout: Dictionary = {}
## The layout of the list shown last (tests).
var last_layout: Dictionary = {}
## Screens opened through pick_screen so far, newest last (tests).
var screens_shown: Array[String] = []

## Shows the list of menu screen [param screen] in the active era's layout (EraMenus).
## [param opts]: cancellable, focus, guard_ms, tabs, tab as in pick(); "header" (a Control put
## between title and rows, freed afterwards) and "panel_text" (what the info panel of the touch
## eras says while no row explains itself).
func pick_screen(screen: String, title: String, entries: Array[Dictionary], opts: Dictionary = {}) -> int:
	var lay: Dictionary = EraMenus.layout(EraManager.active_era(), screen)
	for k: String in ["panel_text", "columns", "row_h", "tab_icons"]:
		if opts.has(k):
			lay[k] = opts[k]
	_next_layout = lay
	screens_shown.append(screen)
	var head: Variant = opts.get("header")
	picker.set_header(head as Control if head is Control else null)
	var tabs: Array[String] = []
	tabs.assign(opts.get("tabs", []))
	var r: int = await pick(title, entries, bool(opts.get("cancellable", true)), int(opts.get("focus", -1)),
		int(opts.get("guard_ms", ListPicker.TAP_GUARD_MS)), tabs, int(opts.get("tab", 0)))
	if is_instance_valid(picker):
		picker.set_header(null)
	return r

const TITLE_MAX_LINES: int = 3
const SHORT_TITLE: String = "Your choice:"

## How many lines [param title] takes as a list title.
func title_lines(title: String) -> int:
	var w: float = picker._title.size.x
	if w < 8.0:
		w = get_viewport_rect().size.x - PANEL_MARGIN * 2.0 - ListPicker.BACK_SIZE - 12.0
	var f: Font = UITheme.font()
	var line_h: float = f.get_height(UITheme.FONT_SIZE)
	var h: float = f.get_multiline_string_size(Loc.t(title), HORIZONTAL_ALIGNMENT_LEFT, w, UITheme.FONT_SIZE).y
	return int(ceil(h / maxf(line_h, 1.0) - 0.01))

## The last sentence of a long question, if it fits in three lines, else "Your choice:".
func short_title(title: String) -> String:
	var text: String = Loc.t(title).strip_edges()
	var cut: int = -1
	for mark: String in [". ", "! ", "? ", "\n"]:
		cut = maxi(cut, text.rfind(mark, text.length() - 2))
	var last: String = text.substr(cut + 1).strip_edges() if cut >= 0 else ""
	if not last.is_empty() and title_lines(last) <= TITLE_MAX_LINES:
		return last
	return SHORT_TITLE

## While the touch pad shows (a question during play), the list ends above its buttons so no
## answer lies under a button (item 2012).
static func keep_above_pad(c: Control, pad_top: float = -2.0) -> void:
	var top: float = VirtualPad.top_y() if pad_top == -2.0 else pad_top
	if top < 0.0 or not c.is_inside_tree():
		return
	var h: float = c.get_viewport_rect().size.y
	c.offset_bottom = minf(c.offset_bottom, top - h - PANEL_MARGIN)

## Convenience: entries from plain strings.
func pick_strings(title: String, items: Array[String], cancellable: bool = true) -> int:
	var entries: Array[Dictionary] = []
	for t: String in items:
		entries.append({"text": t})
	return await pick(title, entries, cancellable)

## Yes/No question. Returns true for yes.
## [param yes_text] and [param no_text] can name what each answer does, such as "Delete" and
## "Keep", so the result of a choice is clear (item 1855).
func confirm(question: String, yes_text: String = "Yes", no_text: String = "No") -> bool:
	return await pick_strings(question, [yes_text, no_text] as Array[String], true) == 0

## A question whose "yes" cannot be undone (delete account, replace a save, the Iron Oath,
## taking over another phone's journeys): focus starts on the safe answer, "yes" carries a
## warning mark, and taps in the first 300 ms are ignored (items 1786, 1837).
func confirm_danger(question: String, yes_text: String = "Yes", no_text: String = "No") -> bool:
	var entries: Array[Dictionary] = [{"text": no_text}, {"text": yes_text, "danger": true}]
	return await pick(question, entries, true, 0, ListPicker.DANGER_GUARD_MS) == 1

## Shows a block of text until the player taps or presses accept/cancel, with an optional
## [param picture] above it.
func info(text: String, picture: Texture2D = null) -> void:
	if close_all:
		await get_tree().process_frame
		return
	apply_hand_layout()
	_info_picture.texture = picture
	_info_picture.visible = picture != null
	_info_picture.custom_minimum_size = picture.get_size() if picture != null else Vector2.ZERO
	_info_source = text
	_info_label.text = Loc.t(text) + "\n\n" + Loc.t(continue_hint())
	_info_scroll.scroll_vertical = 0
	_info_press = Vector2(NAN, NAN)
	_info_panel.visible = true
	_info_wait = true
	infos += 1
	await _info_closed
	_info_panel.visible = false

## Several pages of one thing (a Spirling's summary, item 1890): left and right or a tap on
## the left or right third turn the page, a tap elsewhere or A goes on, B closes.
func info_pages(pages: Array[String], picture: Texture2D = null) -> void:
	if pages.is_empty():
		return
	_pages = pages
	_page = 0
	while _page >= 0 and _page < _pages.size():
		var footer: String = "\n\n< %d/%d >" % [_page + 1, _pages.size()] if _pages.size() > 1 else ""
		_page_turn = 0
		await info(Loc.t(_pages[_page]) + footer, picture if _page == 0 else null)
		if _page_turn == -2:
			break
		_page += _page_turn if _page_turn != 0 else 1
		_page = maxi(_page, 0) if _page_turn == -1 else _page
	_pages = []

var _pages: Array[String] = []
## While true, up and down in the info box close it and set [member summary_step] (item 1893).
var summary_step_ok: bool = false
## -1 previous, 1 next team member, 0 when the summary was simply closed.
var summary_step: int = 0
var _page: int = 0
## How the last page was left: 1 next, -1 back, -2 closed, 0 tap (next).
var _page_turn: int = 0

## Shows [param text] for a moment at the top without waiting for a tap ("Saved.").
func toast(text: String, seconds: float = TOAST_SECONDS) -> void:
	_toast_gen += 1
	var gen: int = _toast_gen
	_toast_source = text
	_toast.text = Loc.t(text)
	_toast.visible = true
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds, true).timeout
	if gen == _toast_gen and is_instance_valid(_toast):
		_toast.visible = false

## The toast text while it shows ("" when hidden).
func toast_text() -> String:
	return _toast.text if _toast.visible else ""

## A long text turns one page per tap; only the tap at the end closes it (item 1838).
func _page_or_close() -> void:
	if info_has_more():
		var bar: VScrollBar = _info_scroll.get_v_scroll_bar()
		# Keep the last line of the old page in view so the reader does not lose the place.
		_info_scroll.scroll_vertical = int(minf(bar.value + maxf(bar.page - INFO_OVERLAP, 8.0), bar.max_value - bar.page))
		return
	_close_info()

const INFO_OVERLAP: float = 10.0

## True while the open info text has more below the visible part.
func info_has_more() -> bool:
	var bar: VScrollBar = _info_scroll.get_v_scroll_bar()
	return bar.value + bar.page < bar.max_value - 1.0

func _close_info() -> void:
	if _info_wait:
		_info_wait = false
		_info_closed.emit()

## A tap (press and release without dragging) anywhere closes the info text. Handled before the
## GUI so the scroll box under the finger cannot swallow it.
func _input(event: InputEvent) -> void:
	if not _info_wait or not is_visible_in_tree():
		return
	if TapInput.is_press(event):
		_info_press = TapInput.position(event)
	elif TapInput.is_release(event) and not is_nan(_info_press.x):
		var moved: float = TapInput.position(event).distance_to(_info_press)
		_info_press = Vector2(NAN, NAN)
		if moved <= TAP_SLOP:
			get_viewport().set_input_as_handled()
			if not _pages.is_empty() and not info_has_more():
				var x: float = TapInput.position(event).x - _info_panel.global_position.x
				var third: float = _info_panel.size.x / 3.0
				_page_turn = -1 if x < third else 1
				_close_info()
				return
			_page_or_close()

func _unhandled_input(event: InputEvent) -> void:
	if _info_wait and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_page_or_close()
	elif _info_wait and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_page_turn = -2
		_close_info()
	elif _info_wait and summary_step_ok and (event.is_action_pressed("ui_up") or (event.is_action_pressed("ui_down") and not info_has_more())):
		# Item 1893: up and down go to the team's previous or next Spirling.
		get_viewport().set_input_as_handled()
		summary_step = -1 if event.is_action_pressed("ui_up") else 1
		_page_turn = -2
		_close_info()
	elif _info_wait and not _pages.is_empty() and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		_page_turn = -1 if event.is_action_pressed("ui_left") else 1
		_close_info()

# --- Shared screens --------------------------------------------------------------

## Settings in groups (item 2063): the main list has at most seven rows. Rows are picked by
## key, never by position, so optional rows cannot shift others (item 2062: duplicate match
## arms used to send "Account..." to the Iron Oath). Every change is saved at once (2066), and
## each row explains itself in a line under the list (2067).
const SETTINGS_GROUPS: Array[Array] = [
	["game", "Game..."],
	["sound", "Sound..."],
	["controls", "Controls..."],
	["display", "Display and access..."],
	["wardrobe", "Wardrobe..."],
	["account", "Account..."],
	["legal", "Legal"],
]

const SETTING_HINTS: Dictionary[String, String] = {
	"wardrobe": "Put on or take off the looks you got in the shop.",
	"text_speed": "How fast text appears in talks and battles.",
	"battle_speed": "Plays battle animations faster.",
	"auto_battle": "Wild battles pick moves by themselves.",
	"bench_lessons": "Spirlings on the bench grow too.",
	"wild_ward": "No wild Spirlings step out while it is on.",
	"damage_preview": "Shows how hard a move would hit before you choose it.",
	"bonus_goals": "Optional extra goals in Wayfarer and Warden battles.",
	"tips": "Short hints the first time something new comes up.",
	"play_reminder": "A short note after 90 minutes of play.",
	"difficulty": "How strong your opponents are. You can change it any time.",
	"iron_oath": "Spirlings that faint retire for good. Only before your first Rift.",
	"challenges": "Extra rules for a harder journey. Taken before your first Rift, dropped any time.",
	"volume": "All sound. Left and right change it in steps of 10.",
	"music": "Music only. Left and right change it in steps of 10.",
	"sfx": "Sound effects only. Left and right change it in steps of 10.",
	"voice_volume": "Text voice and Spirling cries. Left and right change it in steps of 10.",
	"ambience": "Wind, water and other sounds of a place. Left and right change it in steps of 10.",
	"mono": "Both ears hear the same sound, for hearing on one side.",
	"sound_test": "Listen to every tune, sound and cry you know.",
	"text_voice": "Short blips while a line types out.",
	"sound_captions": "Important sounds also show as a short text at the top.",
	"screen_shake": "How much the screen shakes on big hits.",
	"vibration": "How strongly the phone or gamepad vibrates.",
	"tap_vibration": "A short buzz each time you tap a choice.",
	"retro": "Old-style colours for each era you reached.",
	"account": "Friend code, moving to a new phone, deleting your account.",
	"legal": "Imprint, privacy and licences.",
	"game": "Text, battles, tips and difficulty.",
	"sound": "Volume, music and sound effects.",
	"controls": "Pad, tap to walk and gamepad.",
	"display": "Contrast, motion, language and battery.",
	"battery": "Fewer frames per second to save battery.",
	"motion": "Calmer screen: no shaking, no flashes.",
	"contrast": "Pure black and white for easier reading.",
	"large_text": "Bigger letters in menus, texts and talk.",
	"language": "English or Deutsch.",
	"day_night": "The light changes with the time of day.",
	"weather": "Rain, fog and wind in the world. Off: always clear.",
	"minimap": "Small map in the top corner. Outside only: hidden in houses and caves.",
	"pad_size": "How big the touch pad and buttons are.",
	"pad_opacity": "How see-through the touch pad is.",
	"left_handed": "Puts the pad on the right and A and B on the left.",
	"tap_to_move": "Tap a tile and your Wayfarer walks there.",
	"always_run": "Run without holding B. Hold B to walk.",
	"bond_style": "Mine: tap one button fast. Echo: repeat the call. Calm: echo with no time limit.",
	"one_hand": "Everything sits low on the screen for one thumb.",
	"swap_ab_touch": "A and B on the touch pad change places.",
	"swap_ab_pad": "The gamepad's A goes back and B confirms.",
	"pad_help": "Which gamepad button does what.",
	"keys_help": "Which key does what in the browser.",
}

func run_settings() -> void:
	while true:
		# Settings in the era's layout (EraMenus): symbols from Era II, info panel from Era IV.
		var entries: Array[Dictionary] = EraMenuKit.settings_entries(_rows_to_entries(SETTINGS_GROUPS), SETTINGS_GROUPS)
		var idx: int = await pick_screen("options", SETTINGS_TITLE, entries)
		if idx < 0:
			SaveManager.save_settings()
			return
		match str(SETTINGS_GROUPS[idx][0]):
			"game": await _run_setting_group("Game", "game")
			"sound": await _run_setting_group("Sound", "sound")
			"controls": await run_controls()
			"display": await run_display()
			"wardrobe": await ShopMenu.run_wardrobe(self)
			"account": await AccountMenu.run(self)
			"legal": await run_legal()
		if not is_inside_tree():
			return
		SaveManager.save_settings()

const SETTINGS_TITLE: String = "Settings"

## Rows of a settings group as [key, text] pairs.
static func settings_rows(group: String = "game") -> Array[Array]:
	var rows: Array[Array] = []
	match group:
		"game":
			rows = [
				["text_speed", "Text speed: %s" % String(GameState.TextSpeed.keys()[GameState.text_speed]).capitalize()],
				["battle_speed", "Battle speed: %dx" % int(GameState.battle_speed_scale())],
				["auto_battle", "Auto wild battles: %s" % ("On" if GameState.auto_battle else "Off")],
				["bench_lessons", "Bench lessons: %s" % shop_or("bench_lessons", "On" if GameState.bench_xp else "Off")],
				["wild_ward", "Wild Ward: %s" % shop_or("wild_ward", "On" if GameState.wild_ward else "Off")],
				["damage_preview", "Damage preview: %s" % shop_or("damage_preview", "On" if GameState.damage_preview else "Off")],
				["bonus_goals", "Bonus goals: %s" % ("On" if GameState.bonus_goals else "Off")],
				["tips", "Tips: %s" % ("On" if GameState.tips_enabled else "Off")],
				["play_reminder", "Break reminder: %s" % ("On" if GameState.play_reminder else "Off")],
			]
			# Difficulty and the Iron Oath only during a journey.
			if GameState.in_game:
				# A lowered challenge stays visible (item 746).
				rows.append(["difficulty", "Challenge: %s" % DIFFICULTY_TEXT[GameState.difficulty] + (" " + Loc.t("(lowered)") if GameState.difficulty_lowered() else "")])
				rows.append(["iron_oath", "Iron Oath: %s" % ("Sworn" if GameState.iron_oath else "Off")])
				rows.append(["challenges", "Challenges..."])
		"sound":
			rows = [
				["volume", "Volume: %d%%" % int(round(GameState.volume * 100.0))],
				["music", "Music: %d%%" % int(round(GameState.music_volume * 100.0))],
				["sfx", "Sound effects: %d%%" % int(round(GameState.sfx_volume * 100.0))],
				["voice_volume", "Voices: %d%%" % int(round(GameState.voice_volume * 100.0))],
				["ambience", "Ambience: %d%%" % int(round(GameState.ambience_volume * 100.0))],
				["mono", "Mono sound: %s" % ("On" if GameState.mono_audio else "Off")],
				["text_voice", "Text voice: %s" % ("On" if GameState.text_voice else "Off")],
				["sound_captions", "Sound captions: %s" % ("On" if GameState.sound_captions else "Off")],
				["sound_test", "Sound test..."],
			]
	return rows

const SLIDER_KEYS: Array[String] = ["volume", "music", "sfx", "voice_volume", "ambience"]

static func _rows_to_entries(rows: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for r: Array in rows:
		var key: String = str(r[0])
		entries.append({"text": str(r[1]), "hint": SETTING_HINTS.get(key, ""), "slider": key in SLIDER_KEYS})
	return entries

func _run_setting_group(title: String, group: String) -> void:
	while true:
		var rows: Array[Array] = settings_rows(group)
		var idx: int = await pick(title, _rows_to_entries(rows))
		if idx < 0:
			return
		await _settings_action(str(rows[idx][0]), picker.last_dir)
		if not is_inside_tree():
			return
		SaveManager.save_settings()

## Shown instead of the value while a setting still needs its shop unlock (short in every language).
const SHOP_MARK: String = "€"

## [param value] for a setting row, or SHOP_MARK while its shop unlock is missing (Ali, 7 Nov).
static func shop_or(key: String, value: String) -> String:
	return value if ShopEffects.owns_setting(key) else SHOP_MARK

## Shows where to buy [param key] and returns true when the setting is still locked.
func locked_setting(key: String) -> bool:
	if ShopEffects.owns_setting(key):
		return false
	toast("In the shop: %s" % ShopEffects.setting_offer_name(key))
	return true

## Next text speed; Fast only with the shop's Fast Text.
static func next_text_speed(current: int) -> GameState.TextSpeed:
	var next: int = (current + 1) % GameState.TextSpeed.size()
	if next == GameState.TextSpeed.FAST and not ShopEffects.owns_setting("fast_text"):
		next = GameState.TextSpeed.SLOW
	return next as GameState.TextSpeed

func _settings_action(key: String, dir: int = 1) -> void:
	if key in ShopEffects.SETTING_UNLOCKS and locked_setting(key):
		return
	match key:
		"text_speed":
			GameState.text_speed = next_text_speed(GameState.text_speed)
		"battle_speed":
			GameState.cycle_battle_speed()
		"auto_battle":
			GameState.auto_battle = not GameState.auto_battle
		"bench_lessons":
			GameState.bench_xp = not GameState.bench_xp
		"wild_ward":
			GameState.wild_ward = not GameState.wild_ward
		"damage_preview":
			GameState.damage_preview = not GameState.damage_preview
		"bonus_goals":
			GameState.bonus_goals = not GameState.bonus_goals
		"tips":
			GameState.tips_enabled = not GameState.tips_enabled
		"play_reminder":
			GameState.play_reminder = not GameState.play_reminder
		"volume":
			GameState.volume = step_volume(GameState.volume, dir)
			GameState.apply_volume()
		"music":
			GameState.music_volume = step_volume(GameState.music_volume, dir)
			GameState.apply_volume()
		"sfx":
			GameState.sfx_volume = step_volume(GameState.sfx_volume, dir)
			GameState.apply_volume()
			Sound.sfx("confirm")
		"voice_volume":
			GameState.voice_volume = step_volume(GameState.voice_volume, dir)
			GameState.apply_volume()
			Sound.text_blip("player", "a")
		"ambience":
			GameState.ambience_volume = step_volume(GameState.ambience_volume, dir)
			GameState.apply_volume()
		"mono":
			GameState.mono_audio = not GameState.mono_audio
			GameState.apply_volume()
			Sound.sfx("confirm")
		"text_voice":
			GameState.text_voice = not GameState.text_voice
			Sound.text_blip("player", "a")
			Sound.text_blip("player", "a")
		"sound_captions":
			GameState.sound_captions = not GameState.sound_captions
		"sound_test":
			await run_sound_test()
		"difficulty":
			var opts: Array[Dictionary] = []
			for i: int in DIFFICULTY_TEXT.size():
				opts.append({"text": DIFFICULTY_TEXT[i], "hint": DifficultyTable.hint(i, DIFFICULTY_HINTS[i])})
			var d: int = await pick("Difficulty", opts, true, GameState.difficulty)
			if d >= 0:
				GameState.set_difficulty(d)
		"iron_oath":
			await _iron_oath()
		"challenges":
			await ChallengeMenu.run(self)

## Short names for the list rows; the line under the list explains each (items 2185, 2067).
const DIFFICULTY_TEXT: Array[String] = ["Story", "Wayfarer", "Veteran", "Rift-Born"]
const DIFFICULTY_HINTS: Array[String] = [
	"Relaxed battles for enjoying the story. Foes deal 90% damage, land fewer critical hits, and battles give 20% more Growth.",
	"The normal journey.",
	"Ring limits and smarter opponents.",
	"No items in battle.",
]

## The Iron Oath (item 15) can only be sworn before the first Rift is mended, and never undone.
func _iron_oath() -> void:
	if GameState.iron_oath:
		await info("You swore the Iron Oath. It holds until the journey ends.")
		return
	if not GameState.rifts_sealed.is_empty() or GameState.has_flag("rift_cinder_sealed") or GameState.has_flag("rift_tide_sealed"):
		await info("The Iron Oath can only be sworn before you mend your first Rift.")
		return
	if await confirm_danger("Iron Oath: Spirlings that faint retire to the Sanctuary for good, and every Waymark reward pays 25% more. This can't be undone.",
			"Take the Iron Oath", "Not now"):
		GameState.iron_oath = true

## Sound test (item 71): every music track, sound effect and the cries of Spirlings you have seen.
func run_sound_test() -> void:
	var back_to: String = Sound.current_track
	var back_amb: String = Sound.current_ambience
	while true:
		var idx: int = await pick_strings("Sound test", ["Music", "Sound effects", "Cries", "Places"])
		match idx:
			-1:
				Sound.music(back_to, true)
				Sound.ambience(back_amb)
				return
			3:
				# Ambience loops as their own group (item 2585).
				var places: Array[String] = Sound.list_sounds("res://audio/ambience/")
				while true:
					var a: int = await pick_strings("Places", places)
					if a < 0:
						break
					Sound.ambience(places[a])
			0:
				var tracks: Array[String] = Sound.list_sounds("res://audio/music/")
				while true:
					var t: int = await pick_strings("Music", tracks)
					if t < 0:
						break
					Sound.music(tracks[t])
			1:
				var fx: Array[String] = Sound.list_sounds("res://audio/sfx/")
				while true:
					var f: int = await pick_strings("Sound effects", fx)
					if f < 0:
						break
					Sound.sfx(fx[f])
			2:
				var seen: Array[SpirlingData] = sound_test_cries()
				if seen.is_empty():
					await info("Meet a Spirling to hear its cry.")
					continue
				var names: Array[String] = []
				for sd: SpirlingData in seen:
					names.append(sd.species_name)
				while true:
					var c: int = await pick_strings("Cries", names)
					if c < 0:
						break
					Sound.cry(seen[c])

## Species whose cry the sound test offers: every one the Spirlog has seen, in dex order.
static func sound_test_cries() -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		if bool((GameState.spirlog.get(sd.species_name, {}) as Dictionary).get("seen", false)):
			out.append(sd)
	out.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	return out

## Display and accessibility: battery saver, reduced motion, high contrast, language, Retro filter.
func run_display() -> void:
	while true:
		var rows: Array[Array] = display_rows()
		var idx: int = await pick("Display and access", _rows_to_entries(rows))
		if idx < 0:
			return
		var dkey: String = str(rows[idx][0])
		if dkey in ShopEffects.SETTING_UNLOCKS and locked_setting(dkey):
			continue
		match dkey:
			"battery":
				GameState.battery_saver = not GameState.battery_saver
			"motion":
				GameState.reduce_motion = not GameState.reduce_motion
			"contrast":
				GameState.high_contrast = not GameState.high_contrast
			"color_blind":
				GameState.color_blind = not GameState.color_blind
			"large_text":
				GameState.large_text = not GameState.large_text
			"language":
				var codes: Array[String] = Loc.LANGUAGES
				var lang_rows: Array[Dictionary] = []
				for c: String in codes:
					lang_rows.append({"text": Loc.LANGUAGE_NAMES[c]})
				var li: int = await pick("Language", lang_rows, true, codes.find(Loc.language()))
				if li >= 0:
					GameState.language = codes[li]
			"day_night":
				GameState.day_night = not GameState.day_night
			"weather":
				GameState.weather = not GameState.weather
			"minimap":
				var modes: Array[String] = Survey.MINIMAP_MODES
				GameState.minimap = modes[(modes.find(GameState.minimap) + 1) % modes.size()]
			"retro":
				# Only unlocked eras are offered (Era I only for now).
				var next: int = EraManager.retro_filter + 1
				EraManager.set_retro_filter(0 if next > EraManager.unlocked_era else next)
			"era_replay":
				EraManager.replay_upgrade()
			"screen_shake":
				GameState.screen_shake = (GameState.screen_shake + 1) % Juice.LEVEL_NAMES.size()
		GameState.apply_display()
		# High contrast shows at once on every open menu (item 2065).
		refresh_all_themes(get_tree())
		SaveManager.save_settings()

const MINIMAP_NAMES: Dictionary = {"on": "On", "off": "Off", "outdoor": "Outside only"}

static func display_rows() -> Array[Array]:
	var retro: String = "Newest" if EraManager.retro_filter == 0 else "Era %d" % EraManager.retro_filter
	var rows: Array[Array] = [
		["battery", "Battery saver: %s" % ("On" if GameState.battery_saver else "Off")],
		["motion", "Less motion: %s" % ("On" if GameState.reduce_motion else "Off")],
		["contrast", "High contrast: %s" % ("On" if GameState.high_contrast else "Off")],
		["color_blind", "Colour-blind: %s" % ("On" if GameState.color_blind else "Off")],
		["large_text", "Large text: %s" % ("On" if GameState.large_text else "Off")],
		["language", "Language: %s" % Loc.LANGUAGE_NAMES[Loc.language()]],
		["day_night", "Day and night: %s" % shop_or("day_night", "On" if GameState.day_night else "Off")],
		["weather", "Weather: %s" % shop_or("weather", "On" if GameState.weather else "Off")],
		["minimap", "Minimap: %s" % shop_or("minimap", MINIMAP_NAMES[GameState.minimap])],
		["retro", "Retro filter: %s" % shop_or("retro", retro)],
		["screen_shake", "Screen shake: %s" % Juice.LEVEL_NAMES[GameState.screen_shake]],
	]
	rows.append_array(era_replay_rows())
	return rows

## "Replay era change" (docs/ERA_FEEL_UI.md): only once an era past Era I is on screen.
static func era_replay_rows() -> Array[Array]:
	if EraManager.active_era() < EraManager.Era.WASH:
		return []
	return [["era_replay", "Replay era change"]]

## Hand-made texts follow a language change at once (item 2187).
func _on_language_changed(_code: String) -> void:
	if not is_instance_valid(_info_label):
		return
	if _info_panel.visible:
		_info_label.text = Loc.t(_info_source) + "\n\n" + Loc.t(continue_hint())
	if _toast.visible:
		_toast.text = Loc.t(_toast_source)
	picker.retranslate()

func _exit_tree() -> void:
	if Loc.events.language_changed.is_connected(_on_language_changed):
		Loc.events.language_changed.disconnect(_on_language_changed)

## Every menu layer in the tree picks up the current palette.
static func refresh_all_themes(tree: SceneTree) -> void:
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(THEME_GROUP):
		if n.has_method("refresh_theme"):
			n.refresh_theme()
		elif n is Control:
			(n as Control).theme = UITheme.get_theme()

const THEME_GROUP: StringName = &"ui_theme_users"

func refresh_theme() -> void:
	theme = UITheme.get_theme()
	picker.refresh_theme()
	_info_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	_toast.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))

## Volume steps of 10%, up or down, held between 0% and 100% (item 2064: one tap used to jump
## from 100% to 0%).
static func step_volume(v: float, dir: int) -> float:
	var steps: int = clampi(roundi(v * 10.0) + (1 if dir >= 0 else -1), 0, 10)
	return steps / 10.0

const PAD_HELP: String = "Gamepad\nD-pad or left stick: move\nA: talk, confirm\nB: back, hold to run\nStart or Select: menu\nRB: battle speed\nY: auto wild battles"
const PAD_HELP_SWAPPED: String = "Gamepad (A and B swapped)\nD-pad or left stick: move\nB: talk, confirm\nA: back, hold to run\nStart or Select: menu\nRB: battle speed\nY: auto wild battles"
## Keyboard help page (item 2110), mainly for the browser build.
const KEYS_HELP: String = "Keyboard\nArrow keys or W A S D: move\nEnter or Space: talk, confirm\nEscape or Backspace: back\nHold Backspace: run\nM: menu\nF: battle speed\nR: auto wild battles"

static func pad_help() -> String:
	return PAD_HELP_SWAPPED if GameState.swap_ab_pad else PAD_HELP

## Controls: pad size, opacity, left-handed layout, tap-to-move.
func run_controls() -> void:
	while true:
		var rows: Array[Array] = controls_rows()
		var idx: int = await pick("Controls", _rows_to_entries(rows))
		if idx < 0:
			return
		match str(rows[idx][0]):
			"pad_size":
				GameState.pad_size = (GameState.pad_size + 1) % GameState.PAD_SIZE_NAMES.size()
			"pad_opacity":
				GameState.pad_opacity = (GameState.pad_opacity + 1) % GameState.PAD_ALPHAS.size()
			"left_handed":
				GameState.left_handed = not GameState.left_handed
			"tap_to_move":
				GameState.tap_to_move = not GameState.tap_to_move
			"always_run":
				GameState.always_run = not GameState.always_run
			"bond_style":
				GameState.bond_style = next_bond_style(GameState.bond_style)
			"one_hand":
				GameState.one_hand = not GameState.one_hand
			"vibration":
				GameState.vibration = (GameState.vibration + 1) % Juice.LEVEL_NAMES.size()
				Haptics.play("confirm")
			"tap_vibration":
				GameState.tap_vibration = not GameState.tap_vibration
				if GameState.tap_vibration:
					Haptics.play(ListPicker.TAP_BUZZ)
			"swap_ab_touch":
				GameState.swap_ab_touch = not GameState.swap_ab_touch
			"swap_ab_pad":
				GameState.swap_ab_pad = not GameState.swap_ab_pad
				GameState.apply_pad_swap(GameState.swap_ab_pad)
			"pad_help":
				await info(pad_help())
			"keys_help":
				await info(KEYS_HELP)
		VirtualPad.apply_settings()
		SaveManager.save_settings()

const BOND_STYLE_NAMES: Dictionary = {"mine": "Mine", "echo": "Echo", "calm": "Calm"}

## Mine, Echo, Calm, then Mine again.
static func next_bond_style(current: String) -> String:
	var i: int = GameState.BOND_STYLES.find(current)
	return GameState.BOND_STYLES[(i + 1) % GameState.BOND_STYLES.size()]

static func controls_rows() -> Array[Array]:
	return [
		["pad_size", "Pad size: %s" % GameState.PAD_SIZE_NAMES[GameState.pad_size]],
		["pad_opacity", "Pad opacity: %d%%" % int(round(GameState.PAD_ALPHAS[GameState.pad_opacity] * 100.0))],
		["left_handed", "Left-handed: %s" % ("On" if GameState.left_handed else "Off")],
		["tap_to_move", "Tap to walk: %s" % ("On" if GameState.tap_to_move else "Off")],
		["always_run", "Always run: %s" % ("On" if GameState.always_run else "Off")],
		["bond_style", "Bonding: %s" % BOND_STYLE_NAMES.get(GameState.bond_style, "Mine")],
		["one_hand", "One-hand layout: %s" % ("On" if GameState.one_hand else "Off")],
		["swap_ab_touch", "Touch A/B swap: %s" % ("On" if GameState.swap_ab_touch else "Off")],
		["swap_ab_pad", "Pad A/B swap: %s" % ("On" if GameState.swap_ab_pad else "Off")],
		["vibration", "Vibration: %s" % Juice.LEVEL_NAMES[GameState.vibration]],
		["tap_vibration", "Tap buzz: %s" % ("On" if GameState.tap_vibration else "Off")],
		["pad_help", "Gamepad buttons..."],
		["keys_help", "Keyboard keys..."],
	]

## Multi-line summary of a Spirling.
static func summary(s: Spirling) -> String:
	var els: PackedStringArray = []
	for e: int in s.elements():
		els.append(Elements.element_name(e))
	var lines: PackedStringArray = [
		"%s  (%s)" % [s.display_name(), s.data.species_name],
		"%s   Ring %d" % ["/".join(els), s.level],
		"Vigor %d/%d   Growth to next ring %d" % [s.hp, s.max_hp(), s.xp_to_next()],
		"MGT %d  GRD %d  FOC %d  PCE %d" % [s.atk(), s.def(), s.foc(), s.spd()],
	]
	var tm: Dictionary = s.temperament()
	lines.append("Temperament: %s. %s" % [tm.label, tm.text])
	var tr: Dictionary = BattleRules.trait_info(s.gift_id())
	if not tr.is_empty():
		lines.append("Gift: %s. %s" % [tr.label, tr.text])
	if not s.held.is_empty():
		lines.append("Keepsake: %s" % Database.item(s.held).get("name", s.held))
	lines.append("")
	for mv: MoveData in s.moves:
		var power: String = "-" if mv.power <= 0 else str(mv.power)
		lines.append("%s  %s  P%s  E%d" % [mv.move_name, Elements.element_name(mv.element).substr(0, 3), power, mv.energy_cost])
	return "\n".join(lines)

## Storage detail card (plan area 1, item 380): Ring, temperament, gift, keepsake and a
## suggestion, where and when it was met, and its spark words.
static func storage_card(s: Spirling) -> String:
	var lines: PackedStringArray = [
		"%s%s  (%s)" % ["* " if s.favorite else "", s.display_name(), s.data.species_name],
		"Ring %d" % s.level,
	]
	var tm: Dictionary = s.temperament()
	lines.append("Temperament: %s. %s" % [tm.label, tm.text])
	var tr: Dictionary = BattleRules.trait_info(s.gift_id())
	if not tr.is_empty():
		lines.append("Gift: %s. %s" % [tr.label, tr.text])
	lines.append("Keepsake: %s" % (str(Database.item(s.held).get("name", s.held)) if not s.held.is_empty() else "none"))
	if EraFeatures.is_unlocked(Kinship.FEATURE):
		lines.append(Kinship.label(s))
	var hint: String = keepsake_suggestion(s)
	if not hint.is_empty():
		lines.append(hint)
	if not s.origin_map.is_empty():
		lines.append("Met in %s at Ring %d" % [Spirling.place_name(s.origin_map), maxi(s.met_ring, 1)])
	if s.met_day > 0:
		lines.append("On %s" % Time.get_date_string_from_unix_time(s.met_day * 86400))
	var parts: PackedStringArray = []
	for key: String in Spirling.STAT_KEYS:
		parts.append("%s %s" % [key.to_upper(), GameState.spark_word(int(s.spark.get(key, 0)))])
	lines.append("Sparks: %s" % ", ".join(parts))
	return "\n".join(lines)

## "Suits it: Bark Wrap" when the kind's keepsake_hint is not what it holds already (item 355).
static func keepsake_suggestion(s: Spirling) -> String:
	var hint: String = s.data.keepsake_hint
	if hint.is_empty() or hint == s.held:
		return ""
	return "Suits it: %s" % str(Database.item(hint).get("name", hint))

## One storage row: favourite star, name, Ring, and a keepsake mark (item 357). A Spirling on a
## roaming trip carries the backpack glyph (plan 3448).
static func storage_line(s: Spirling) -> String:
	return "%s%s%s%s R%d%s" % [Expeditions.GLYPH + " " if Expeditions.is_away(s.uid) else "", "* " if s.favorite else "", GleamRules.mark(s), s.display_name(), s.level, "  +%s" % str(Database.item(s.held).get("name", s.held)) if not s.held.is_empty() else ""]

static func party_line(s: Spirling) -> String:
	var tag: String = " " + Loc.t("worn out") if s.is_fainted() else ""
	return "%s%s R%d %d/%d%s" % [GleamRules.mark(s), s.display_name(), s.level, s.hp, s.max_hp(), tag]

## Summary in pages (item 1890): values, arts, gift and keepsake, temperament. Values are
## written out in full (item 1891).
static func summary_pages(s: Spirling) -> Array[String]:
	var els: PackedStringArray = []
	for e: int in s.elements():
		els.append(Elements.element_name(e))
	var head: String = "%s  (%s)\n%s   %s" % [s.display_name(), s.data.species_name, "/".join(els), Loc.t("Ring %d" % s.level)]
	var values: PackedStringArray = [head, "",
		Loc.t("Vigor %d/%d" % [s.hp, s.max_hp()]) + ("  " + Loc.t("worn out") if s.is_fainted() else ""),
		Loc.t("Growth to next ring %d" % s.xp_to_next()),
		Loc.t("Might %d" % s.atk()), Loc.t("Guard %d" % s.def()), Loc.t("Focus %d" % s.foc()), Loc.t("Pace %d" % s.spd())]
	var arts: PackedStringArray = [Loc.t("Arts of %s" % s.display_name()), ""]
	for mv: MoveData in s.moves:
		var power: String = "-" if mv.power <= 0 else str(mv.power)
		arts.append("%s\n  %s  %s  %s" % [mv.move_name, Elements.element_name(mv.element),
			Loc.t("Power %s" % power), Loc.t("Energy %d" % mv.energy_cost)])
	var gift: PackedStringArray = []
	var tr: Dictionary = BattleRules.trait_info(s.gift_id())
	gift.append(Loc.t("Gift: %s" % tr.label) + "\n" + Loc.t(str(tr.text)) if not tr.is_empty() else Loc.t("No gift."))
	gift.append("")
	if not s.held.is_empty():
		var it: Dictionary = Database.item(s.held)
		gift.append(Loc.t("Keepsake: %s" % it.get("name", s.held)) + "\n" + Loc.t(str(it.get("description", ""))))
	else:
		gift.append(Loc.t("No keepsake."))
	var tm: Dictionary = s.temperament()
	var nature: String = Loc.t("Temperament: %s" % tm.label) + "\n" + Loc.t(str(tm.text))
	return [head.left(0) + "\n".join(values), "\n".join(arts), "\n".join(gift), nature] as Array[String]

## Team row (item 1889): 14x14 sprite, name and ring, a 40 px Vigor bar under the name and the
## element icons on the right; worn-out Spirlings get their own mark (item 1892).
static func party_entry(s: Spirling, leader: bool = false) -> Dictionary:
	# The row is too narrow for "worn out" next to the icons: a cross on the empty bar shows
	# it, the hint and the screen reader say it.
	var worn: String = "worn out" if s.is_fainted() else ""
	var hint: String = Loc.t("Vigor %d/%d" % [s.hp, s.max_hp()])
	if s.is_fainted():
		hint += "  " + Loc.t(worn)
	# The leader on slot 1 carries a small flag (item 1903).
	if leader:
		hint = Loc.t("Leads the team") + "  " + hint
	# A Spirling that can unfurl now carries an arrow mark (item 1905).
	var ready: bool = can_unfurl_now(s)
	if ready:
		hint += "  " + Loc.t("Ready to unfurl")
	return {"text": "%s R%d" % [s.display_name(), s.level], "icon": MiniSprite.of(s.data.species_name, 14),
		"decorate": func(b: Button) -> void: _draw_party_row(b, s, leader, ready), "unfurl": ready,
		"hint": hint, "say": (("leads the team, worn out" if s.is_fainted() else "leads the team") if leader else worn), "leader": leader}

const BAR_WIDTH: int = 40
const FLAG_INSET: int = 8

## True when [param s] could unfurl right now (outside any special place).
static func can_unfurl_now(s: Spirling) -> bool:
	return not s.data.unfold.is_empty() and not s.unfurl_targets().is_empty()

## A small up arrow left of the leader flag: this Spirling can unfurl now.
static func _draw_unfurl_mark(b: Button, ink: Color) -> void:
	var x: float = b.size.x - FLAG_INSET - 8.0
	var top: float = 3.0
	b.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + 3, top + 3), Vector2(x - 3, top + 3)]), ink)
	b.draw_rect(Rect2(x - 1, top + 3, 2, 4), ink)

## A small pennant at the right end of the leader's row.
static func _draw_leader_flag(b: Button, ink: Color) -> void:
	var x: float = b.size.x - FLAG_INSET
	var top: float = 3.0
	var bottom: float = b.size.y - 3.0
	b.draw_line(Vector2(x, top), Vector2(x, bottom), ink)
	b.draw_colored_polygon(PackedVector2Array([Vector2(x + 1, top), Vector2(x + 6, top + 2.5), Vector2(x + 1, top + 5)]), ink)

static func _draw_party_row(b: Button, s: Spirling, leader: bool = false, ready: bool = false) -> void:
	var ink: Color = b.get_theme_color("font_focus_color" if b.has_focus() else "font_color", "Button")
	if leader:
		_draw_leader_flag(b, ink)
	if ready:
		_draw_unfurl_mark(b, ink)
	var x0: float = ListPicker.POINTER_SPACE + 16
	var y: float = b.size.y - 3
	var ratio: float = clampf(float(s.hp) / maxf(1.0, float(s.max_hp())), 0.0, 1.0)
	# The bar takes the era's look (data/era_feel.json "bar"): ink line, then colour, shading, bevel, gloss.
	EraFeel.draw_bar(b, Rect2(x0, y, BAR_WIDTH, 2), ratio, ink, str(EraManager.feel("bar")))
	if ratio <= 0.0:
		# Worn out: a small cross at the end of the empty bar.
		var cx: float = x0 + BAR_WIDTH + 3
		b.draw_line(Vector2(cx - 2, y - 2), Vector2(cx + 2, y + 2), ink)
		b.draw_line(Vector2(cx + 2, y - 2), Vector2(cx - 2, y + 2), ink)
	var els: Array[int] = s.elements()
	var w: float = els.size() * (ElementIcons.SIZE + 1)
	ElementIcons.draw_row(b, els, Vector2(b.size.x - 3 - w, floorf((b.size.y - ElementIcons.SIZE) / 2.0)), ink)

## Settings -> Legal: imprint/privacy/terms links and the engine licence notice.
## The community server, opened from Settings > Legal on the title screen and in the pause menu.
const DISCORD_URL: String = "https://discord.gg/e69SM39rKK"
## Opens a link outside the game; tests replace it so no browser starts.
static var open_url: Callable = func(url: String) -> void: OS.shell_open(url)

func run_legal() -> void:
	while true:
		var idx: int = await pick_strings("Legal", ["Imprint & privacy", "Licences", "Join our Discord"] as Array[String])
		match idx:
			-1:
				return
			0:
				await info(LegalInfo.links_text())
			1:
				for page: String in LegalInfo.pages(LegalInfo.licence_text()):
					await info(page)
			2:
				open_url.call(DISCORD_URL)
				toast(DISCORD_URL)

## "What's new" (docs/LIVE_CONTENT.md): patch notes and news from the live content, newest
## first, and the Discord invite. An entry with a link offers to open it after its text.
func run_news() -> void:
	while true:
		var entries: Array[Dictionary] = LiveContent.news()
		var rows: Array[String] = []
		for e: Dictionary in entries:
			rows.append(str(e.title))
		rows.append("Join our Discord")
		var idx: int = await pick_strings("What's new", rows)
		if idx < 0:
			return
		if idx == entries.size():
			open_url.call(DISCORD_URL)
			toast(DISCORD_URL)
			continue
		var e: Dictionary = entries[idx]
		var head: String = str(e.title) if str(e.date).is_empty() else "%s  %s" % [e.title, e.date]
		await info(head + "\n\n" + str(e.body))
		if not str(e.url).is_empty() and await confirm("Open the link?"):
			open_url.call(str(e.url))

## The info scroll bar: the part of the text in view, drawn in MID on the right edge.
## Returns the drawn rect (empty when everything fits), for tests.
func info_bar_rect() -> Rect2:
	var bar: VScrollBar = _info_scroll.get_v_scroll_bar()
	if bar.max_value <= bar.page + 0.5 or bar.max_value <= 0.0:
		return Rect2()
	var top: float = _info_scroll.position.y + _info_scroll.get_parent_control().position.y
	var h: float = _info_scroll.size.y
	var x: float = _info_bar.size.x - INFO_BAR_W - 1
	var len: float = maxf(4.0, h * bar.page / bar.max_value)
	var y: float = top + (h - len) * (bar.value / maxf(1.0, bar.max_value - bar.page))
	return Rect2(Vector2(x, y), Vector2(INFO_BAR_W, len))

func _draw_info_bar() -> void:
	var r: Rect2 = info_bar_rect()
	if r.size.y > 0.0:
		_info_bar.draw_rect(r, UITheme.MID)

## "(tap to continue)" in the words of the device used last (item 1841).
const CONTINUE_HINTS: Dictionary[String, String] = {"touch": "(tap to continue)", "pad": "(A: continue)", "keys": "(Enter: continue)"}

static func continue_hint() -> String:
	return CONTINUE_HINTS.get(ListPicker.last_device, CONTINUE_HINTS.touch)
