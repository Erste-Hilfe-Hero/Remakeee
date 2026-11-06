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

## Shows a list; returns the index or -1 (Back / cancel).
func pick(title: String, entries: Array[Dictionary], cancellable: bool = true, focus: int = -1,
		guard_ms: int = ListPicker.TAP_GUARD_MS) -> int:
	return await picker.pick(title, entries, cancellable, focus, guard_ms)

## Convenience: entries from plain strings.
func pick_strings(title: String, items: Array[String], cancellable: bool = true) -> int:
	var entries: Array[Dictionary] = []
	for t: String in items:
		entries.append({"text": t})
	return await pick(title, entries, cancellable)

## Yes/No question. Returns true for yes.
func confirm(question: String) -> bool:
	return await pick_strings(question, ["Yes", "No"] as Array[String], true) == 0

## A question whose "yes" cannot be undone (delete account, replace a save, the Iron Oath,
## taking over another phone's journeys): focus starts on the safe answer, "yes" carries a
## warning mark, and taps in the first 300 ms are ignored (items 1786, 1837).
func confirm_danger(question: String, yes_text: String = "Yes", no_text: String = "No") -> bool:
	var entries: Array[Dictionary] = [{"text": no_text}, {"text": yes_text, "danger": true}]
	return await pick(question, entries, true, 0, ListPicker.DANGER_GUARD_MS) == 1

## Shows a block of text until the player taps or presses accept/cancel, with an optional
## [param picture] above it.
func info(text: String, picture: Texture2D = null) -> void:
	_info_picture.texture = picture
	_info_picture.visible = picture != null
	_info_picture.custom_minimum_size = picture.get_size() if picture != null else Vector2.ZERO
	_info_label.text = Loc.t(text) + "\n\n" + Loc.t("(tap to continue)")
	_info_scroll.scroll_vertical = 0
	_info_press = Vector2(NAN, NAN)
	_info_panel.visible = true
	_info_wait = true
	await _info_closed
	_info_panel.visible = false

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
			_page_or_close()

func _unhandled_input(event: InputEvent) -> void:
	if _info_wait and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_page_or_close()
	elif _info_wait and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
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
	["account", "Account..."],
	["legal", "Legal"],
]

const SETTING_HINTS: Dictionary[String, String] = {
	"text_speed": "How fast text appears in talks and battles.",
	"battle_speed": "Plays battle animations faster.",
	"auto_battle": "Wild battles pick moves by themselves.",
	"bench_lessons": "Spirlings on the bench grow too.",
	"damage_preview": "Shows how hard a move would hit before you choose it.",
	"tips": "Short hints the first time something new comes up.",
	"difficulty": "How strong your opponents are. You can change it any time.",
	"iron_oath": "Spirlings that faint retire for good. Only before your first Rift.",
	"volume": "All sound. Left and right change it in steps of 10.",
	"music": "Music only. Left and right change it in steps of 10.",
	"sfx": "Sound effects only. Left and right change it in steps of 10.",
	"sound_test": "Listen to every tune, sound and cry you know.",
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
	"language": "English or Deutsch.",
	"day_night": "The light changes with the time of day.",
	"pad_size": "How big the touch pad and buttons are.",
	"pad_opacity": "How see-through the touch pad is.",
	"left_handed": "Puts the pad on the right and A and B on the left.",
	"tap_to_move": "Tap a tile and your Wayfarer walks there.",
	"one_hand": "Everything sits low on the screen for one thumb.",
	"rumble": "The gamepad shakes on big hits.",
	"pad_help": "Which gamepad button does what.",
}

func run_settings() -> void:
	while true:
		var idx: int = await pick(SETTINGS_TITLE, _rows_to_entries(SETTINGS_GROUPS))
		if idx < 0:
			SaveManager.save_settings()
			return
		match str(SETTINGS_GROUPS[idx][0]):
			"game": await _run_setting_group("Game", "game")
			"sound": await _run_setting_group("Sound", "sound")
			"controls": await run_controls()
			"display": await run_display()
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
				["bench_lessons", "Bench lessons: %s" % ("On" if GameState.bench_xp else "Off")],
				["damage_preview", "Damage preview: %s" % ("On" if GameState.damage_preview else "Off")],
				["tips", "Tips: %s" % ("On" if GameState.tips_enabled else "Off")],
			]
			# Difficulty and the Iron Oath only during a journey.
			if GameState.in_game:
				rows.append(["difficulty", "Challenge: %s" % DIFFICULTY_TEXT[GameState.difficulty]])
				rows.append(["iron_oath", "Iron Oath: %s" % ("Sworn" if GameState.iron_oath else "Off")])
		"sound":
			rows = [
				["volume", "Volume: %d%%" % int(round(GameState.volume * 100.0))],
				["music", "Music: %d%%" % int(round(GameState.music_volume * 100.0))],
				["sfx", "Sound effects: %d%%" % int(round(GameState.sfx_volume * 100.0))],
				["sound_test", "Sound test..."],
			]
	return rows

const SLIDER_KEYS: Array[String] = ["volume", "music", "sfx"]

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

func _settings_action(key: String, dir: int = 1) -> void:
	match key:
		"text_speed":
			GameState.text_speed = ((GameState.text_speed + 1) % GameState.TextSpeed.size()) as GameState.TextSpeed
		"battle_speed":
			GameState.cycle_battle_speed()
		"auto_battle":
			GameState.auto_battle = not GameState.auto_battle
		"bench_lessons":
			GameState.bench_xp = not GameState.bench_xp
		"damage_preview":
			GameState.damage_preview = not GameState.damage_preview
		"tips":
			GameState.tips_enabled = not GameState.tips_enabled
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
		"sound_test":
			await run_sound_test()
		"difficulty":
			var opts: Array[Dictionary] = []
			for i: int in DIFFICULTY_TEXT.size():
				opts.append({"text": DIFFICULTY_TEXT[i], "hint": DIFFICULTY_HINTS[i]})
			var d: int = await pick("Difficulty", opts, true, GameState.difficulty)
			if d >= 0:
				GameState.difficulty = d as GameState.Difficulty
		"iron_oath":
			await _iron_oath()

## Short names for the list rows; the line under the list explains each (items 2185, 2067).
const DIFFICULTY_TEXT: Array[String] = ["Story", "Wayfarer", "Veteran", "Rift-Born"]
const DIFFICULTY_HINTS: Array[String] = [
	"Relaxed battles for enjoying the story.",
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
	while true:
		var idx: int = await pick_strings("Sound test", ["Music", "Sound effects", "Cries"])
		match idx:
			-1:
				Sound.music(back_to)
				return
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
		match str(rows[idx][0]):
			"battery":
				GameState.battery_saver = not GameState.battery_saver
			"motion":
				GameState.reduce_motion = not GameState.reduce_motion
			"contrast":
				GameState.high_contrast = not GameState.high_contrast
			"language":
				GameState.language = Loc.next_language()
			"day_night":
				GameState.day_night = not GameState.day_night
			"retro":
				# Only unlocked eras are offered (Era I only for now).
				var next: int = EraManager.retro_filter + 1
				EraManager.set_retro_filter(0 if next > EraManager.unlocked_era else next)
		GameState.apply_display()
		# High contrast shows at once on every open menu (item 2065).
		refresh_all_themes(get_tree())
		SaveManager.save_settings()

static func display_rows() -> Array[Array]:
	var retro: String = "Newest" if EraManager.retro_filter == 0 else "Era %d" % EraManager.retro_filter
	return [
		["battery", "Battery saver: %s" % ("On" if GameState.battery_saver else "Off")],
		["motion", "Less motion: %s" % ("On" if GameState.reduce_motion else "Off")],
		["contrast", "High contrast: %s" % ("On" if GameState.high_contrast else "Off")],
		["language", "Language: %s" % Loc.LANGUAGE_NAMES[Loc.language()]],
		["day_night", "Day and night: %s" % ("On" if GameState.day_night else "Off")],
		["retro", "Retro filter: %s" % retro],
	]

## Hand-made texts follow a language change at once (item 2187).
func _on_language_changed(_code: String) -> void:
	if not is_instance_valid(_info_label):
		return
	if _info_panel.visible:
		_info_label.text = Loc.t(_info_source) + "\n\n" + Loc.t("(tap to continue)")
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
			"one_hand":
				GameState.one_hand = not GameState.one_hand
			"rumble":
				GameState.rumble = not GameState.rumble
				GameState.rumble_pads(0.6, 0.2)
			"pad_help":
				await info(PAD_HELP)
		VirtualPad.apply_settings()
		SaveManager.save_settings()

static func controls_rows() -> Array[Array]:
	return [
		["pad_size", "Pad size: %s" % GameState.PAD_SIZE_NAMES[GameState.pad_size]],
		["pad_opacity", "Pad opacity: %d%%" % int(round(GameState.PAD_ALPHAS[GameState.pad_opacity] * 100.0))],
		["left_handed", "Left-handed: %s" % ("On" if GameState.left_handed else "Off")],
		["tap_to_move", "Tap to walk: %s" % ("On" if GameState.tap_to_move else "Off")],
		["one_hand", "One-hand layout: %s" % ("On" if GameState.one_hand else "Off")],
		["rumble", "Gamepad rumble: %s" % ("On" if GameState.rumble else "Off")],
		["pad_help", "Gamepad buttons..."],
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
	var tr: Dictionary = BattleRules.trait_info(s.data.trait_id)
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
	var tr: Dictionary = BattleRules.trait_info(s.data.trait_id)
	if not tr.is_empty():
		lines.append("Gift: %s. %s" % [tr.label, tr.text])
	lines.append("Keepsake: %s" % (str(Database.item(s.held).get("name", s.held)) if not s.held.is_empty() else "none"))
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

## One storage row: favourite star, name, Ring, and a keepsake mark (item 357).
static func storage_line(s: Spirling) -> String:
	return "%s%s R%d%s" % ["* " if s.favorite else "", s.display_name(), s.level, "  +%s" % str(Database.item(s.held).get("name", s.held)) if not s.held.is_empty() else ""]

static func party_line(s: Spirling) -> String:
	var tag: String = " (out)" if s.is_fainted() else ""
	return "%s R%d %d/%d%s" % [s.display_name(), s.level, s.hp, s.max_hp(), tag]

## Settings -> Legal: imprint/privacy/terms links and the engine licence notice.
func run_legal() -> void:
	while true:
		var idx: int = await pick_strings("Legal", ["Imprint & privacy", "Licences"] as Array[String])
		match idx:
			-1:
				return
			0:
				await info(LegalInfo.links_text())
			1:
				for page: String in LegalInfo.pages(LegalInfo.licence_text()):
					await info(page)
