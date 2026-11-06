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
const TOAST_SECONDS: float = 1.5

func _ready() -> void:
	theme = UITheme.get_theme()
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
			_close_info()

func _unhandled_input(event: InputEvent) -> void:
	if _info_wait and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close_info()

# --- Shared screens --------------------------------------------------------------

## Settings: text speed, battle speed, auto wild battles, Retro filter, volume. Saved immediately.
func run_settings() -> void:
	while true:
		var rows: Array[Array] = settings_rows()
		var entries: Array[String] = []
		for r: Array in rows:
			entries.append(str(r[1]))
		var idx: int = await pick_strings("Settings", entries)
		if idx < 0:
			SaveManager.save_settings()
			return
		await _settings_action(str(rows[idx][0]))
		if not is_inside_tree():
			return
		# Every change is kept at once, not only on Back (item 2066).
		SaveManager.save_settings()

## The settings list as [key, text] pairs. Rows are picked by key, never by position, so
## optional rows (Difficulty, Iron Oath during a journey) cannot shift other rows (item 2062:
## duplicate match arms used to send "Account..." to the Iron Oath).
static func settings_rows() -> Array[Array]:
	var retro: String = "Newest" if EraManager.retro_filter == 0 else "Era %d" % EraManager.retro_filter
	var rows: Array[Array] = [
		["text_speed", "Text speed: %s" % String(GameState.TextSpeed.keys()[GameState.text_speed]).capitalize()],
		["battle_speed", "Battle speed: %dx" % int(GameState.battle_speed_scale())],
		["auto_battle", "Auto wild battles: %s" % ("On" if GameState.auto_battle else "Off")],
		["bench_xp", "Bench lessons: %s" % ("On" if GameState.bench_xp else "Off")],
		["damage_preview", "Damage preview: %s" % ("On" if GameState.damage_preview else "Off")],
		["retro", "Retro filter: %s" % retro],
		["volume", "Volume: %d%%" % int(round(GameState.volume * 100.0))],
		["music", "Music: %d%%" % int(round(GameState.music_volume * 100.0))],
		["sfx", "Sound effects: %d%%" % int(round(GameState.sfx_volume * 100.0))],
		["tips", "Tips: %s" % ("On" if GameState.tips_enabled else "Off")],
		["controls", "Controls..."],
		["display", "Display and access..."],
		["sound_test", "Sound test..."],
		["legal", "Legal"],
		["account", "Account..."],
	]
	# Difficulty and the Iron Oath moved out of the new-game flow (only during a journey).
	if GameState.in_game:
		rows.append(["difficulty", "Difficulty: %s" % DIFFICULTY_TEXT[GameState.difficulty]])
		rows.append(["iron_oath", "Iron Oath: %s" % ("Sworn" if GameState.iron_oath else "Off")])
	return rows

func _settings_action(key: String) -> void:
	match key:
		"text_speed":
			GameState.text_speed = ((GameState.text_speed + 1) % GameState.TextSpeed.size()) as GameState.TextSpeed
		"battle_speed":
			GameState.cycle_battle_speed()
		"auto_battle":
			GameState.auto_battle = not GameState.auto_battle
		"bench_xp":
			GameState.bench_xp = not GameState.bench_xp
		"damage_preview":
			GameState.damage_preview = not GameState.damage_preview
		"retro":
			# Only unlocked eras are offered (Era I only for now).
			var next: int = EraManager.retro_filter + 1
			EraManager.set_retro_filter(0 if next > EraManager.unlocked_era else next)
		"volume":
			GameState.volume = _step_volume(GameState.volume)
			GameState.apply_volume()
		"music":
			GameState.music_volume = _step_volume(GameState.music_volume)
			GameState.apply_volume()
		"sfx":
			GameState.sfx_volume = _step_volume(GameState.sfx_volume)
			GameState.apply_volume()
			Sound.sfx("confirm")
		"tips":
			GameState.tips_enabled = not GameState.tips_enabled
		"controls":
			await run_controls()
		"display":
			await run_display()
		"sound_test":
			await run_sound_test()
		"legal":
			await run_legal()
		"account":
			await AccountMenu.run(self)
		"difficulty":
			var d: int = await pick_strings("Difficulty", DIFFICULTY_TEXT)
			if d >= 0:
				GameState.difficulty = d as GameState.Difficulty
		"iron_oath":
			await _iron_oath()

const DIFFICULTY_TEXT: Array[String] = [
	"Story (relaxed)",
	"Wayfarer (normal)",
	"Veteran (caps, smart AI)",
	"Rift-Born (no battle items)",
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

## Display and accessibility: battery saver, reduced motion, high contrast, language.
func run_display() -> void:
	while true:
		var entries: Array[String] = [
			"Battery saver (30 FPS): %s" % ("On" if GameState.battery_saver else "Off"),
			"Reduce motion and flashes: %s" % ("On" if GameState.reduce_motion else "Off"),
			"High contrast menus: %s" % ("On" if GameState.high_contrast else "Off"),
			"Language: %s" % Loc.LANGUAGE_NAMES[Loc.language()],
			"Day and night: %s" % ("On" if GameState.day_night else "Off"),
			"Screen shake: %s" % Juice.LEVEL_NAMES[GameState.screen_shake],
		]
		var idx: int = await pick_strings("Display and access", entries)
		match idx:
			-1:
				return
			0:
				GameState.battery_saver = not GameState.battery_saver
			1:
				GameState.reduce_motion = not GameState.reduce_motion
			2:
				GameState.high_contrast = not GameState.high_contrast
			3:
				GameState.language = Loc.next_language()
			4:
				GameState.day_night = not GameState.day_night
			5:
				GameState.screen_shake = (GameState.screen_shake + 1) % Juice.LEVEL_NAMES.size()
		GameState.apply_display()
		SaveManager.save_settings()
		if idx == 2:
			await info("High contrast applies to menus and text from the next screen on.")

## Volume steps of 20%, wrapping from 100% to 0%.
static func _step_volume(v: float) -> float:
	var n: float = v + 0.2
	return 0.0 if n > 1.01 else n

const PAD_HELP: String = "Gamepad\nD-pad or left stick: move\nA: talk, confirm\nB: back, hold to run\nStart or Select: menu\nRB: battle speed\nY: auto wild battles"

## Controls: pad size, opacity, left-handed layout, tap-to-move.
func run_controls() -> void:
	while true:
		var entries: Array[String] = [
			"Pad size: %s" % GameState.PAD_SIZE_NAMES[GameState.pad_size],
			"Pad opacity: %d%%" % int(round(GameState.PAD_ALPHAS[GameState.pad_opacity] * 100.0)),
			"Left-handed: %s" % ("On" if GameState.left_handed else "Off"),
			"Tap to walk: %s" % ("On" if GameState.tap_to_move else "Off"),
			"One-hand layout: %s" % ("On" if GameState.one_hand else "Off"),
			"Vibration: %s" % Juice.LEVEL_NAMES[GameState.vibration],
			"Gamepad buttons...",
		]
		var idx: int = await pick_strings("Controls", entries)
		match idx:
			-1:
				return
			0:
				GameState.pad_size = (GameState.pad_size + 1) % GameState.PAD_SIZE_NAMES.size()
			1:
				GameState.pad_opacity = (GameState.pad_opacity + 1) % GameState.PAD_ALPHAS.size()
			2:
				GameState.left_handed = not GameState.left_handed
			3:
				GameState.tap_to_move = not GameState.tap_to_move
			4:
				GameState.one_hand = not GameState.one_hand
			5:
				GameState.vibration = (GameState.vibration + 1) % Juice.LEVEL_NAMES.size()
				Haptics.play("confirm")
			6:
				await info(PAD_HELP)
		VirtualPad.apply_settings()
		SaveManager.save_settings()

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
