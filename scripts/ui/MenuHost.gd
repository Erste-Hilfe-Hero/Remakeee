class_name MenuHost
extends Control
## Full-screen menu layer with a list picker and an info panel. Menus are coroutines:
## await host.pick(...), await host.info(...). Shared by the title screen and pause menu.

const PANEL_MARGIN: int = 6

var picker: ListPicker
var _info_panel: PanelContainer
var _info_label: Label
var _info_wait: bool = false
signal _info_closed

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
	_info_panel.gui_input.connect(_on_info_input)
	add_child(_info_panel)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_panel.add_child(_info_label)

func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_left = PANEL_MARGIN
	c.offset_top = PANEL_MARGIN
	c.offset_right = -PANEL_MARGIN
	c.offset_bottom = -PANEL_MARGIN
	# Keep menus clear of notches and the gesture bar once the viewport is known.
	c.ready.connect(func() -> void: SafeArea.apply(c, PANEL_MARGIN), CONNECT_ONE_SHOT)

## Shows a list; returns the index or -1 (Back / cancel).
func pick(title: String, entries: Array[Dictionary], cancellable: bool = true) -> int:
	return await picker.pick(title, entries, cancellable)

## Convenience: entries from plain strings.
func pick_strings(title: String, items: Array[String], cancellable: bool = true) -> int:
	var entries: Array[Dictionary] = []
	for t: String in items:
		entries.append({"text": t})
	return await pick(title, entries, cancellable)

## Yes/No question. Returns true for yes.
func confirm(question: String) -> bool:
	return await pick_strings(question, ["Yes", "No"] as Array[String], true) == 0

## Shows a block of text until the player taps or presses accept/cancel.
func info(text: String) -> void:
	_info_label.text = text + "\n\n(tap to continue)"
	_info_panel.visible = true
	_info_wait = true
	await _info_closed
	_info_panel.visible = false

func _close_info() -> void:
	if _info_wait:
		_info_wait = false
		_info_closed.emit()

func _on_info_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close_info()

func _unhandled_input(event: InputEvent) -> void:
	if _info_wait and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close_info()

# --- Shared screens --------------------------------------------------------------

## Settings: text speed, battle speed, auto wild battles, Retro filter, volume. Saved immediately.
func run_settings() -> void:
	while true:
		var retro: String = "Newest" if EraManager.retro_filter == 0 else "Era %d" % EraManager.retro_filter
		var entries: Array[String] = [
			"Text speed: %s" % String(GameState.TextSpeed.keys()[GameState.text_speed]).capitalize(),
			"Battle speed: %dx" % int(GameState.battle_speed_scale()),
			"Auto wild battles: %s" % ("On" if GameState.auto_battle else "Off"),
			"Retro filter: %s" % retro,
			"Volume: %d%%" % int(round(GameState.volume * 100.0)),
			"Music: %d%%" % int(round(GameState.music_volume * 100.0)),
			"Sound effects: %d%%" % int(round(GameState.sfx_volume * 100.0)),
			"Tips: %s" % ("On" if GameState.tips_enabled else "Off"),
			"Controls...",
			"Display and access...",
			"Sound test...",
			"Legal",
			"Account...",
		]
		# Difficulty and the Iron Oath moved out of the new-game flow (only during a journey).
		if GameState.in_game:
			entries.append("Difficulty: %s" % DIFFICULTY_TEXT[GameState.difficulty])
			entries.append("Iron Oath: %s" % ("Sworn" if GameState.iron_oath else "Off"))
		var idx: int = await pick_strings("Settings", entries)
		match idx:
			-1:
				SaveManager.save_settings()
				return
			0:
				GameState.text_speed = ((GameState.text_speed + 1) % GameState.TextSpeed.size()) as GameState.TextSpeed
			1:
				GameState.cycle_battle_speed()
			2:
				GameState.auto_battle = not GameState.auto_battle
			3:
				# Only unlocked eras are offered (Era I only for now).
				var next: int = EraManager.retro_filter + 1
				EraManager.set_retro_filter(0 if next > EraManager.unlocked_era else next)
			4:
				var v: float = GameState.volume + 0.2
				GameState.volume = 0.0 if v > 1.01 else v
				GameState.apply_volume()
			5:
				GameState.music_volume = _step_volume(GameState.music_volume)
				GameState.apply_volume()
			6:
				GameState.sfx_volume = _step_volume(GameState.sfx_volume)
				GameState.apply_volume()
				Sound.sfx("confirm")
			7:
				GameState.tips_enabled = not GameState.tips_enabled
			8:
				await run_controls()
			9:
				await run_display()
			10:
				await run_sound_test()
			11:
				await run_legal()
			12:
				await AccountMenu.run(self)
				if not is_inside_tree():
					return
			13:
				var d: int = await pick_strings("Difficulty", DIFFICULTY_TEXT)
				if d >= 0:
					GameState.difficulty = d as GameState.Difficulty
			14:
				await _iron_oath()

const DIFFICULTY_TEXT: Array[String] = [
	"Story (relaxed)",
	"Tamer (normal)",
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
	if await pick_strings("Iron Oath: Spirlings that faint retire to the Sanctuary for good. This can't be undone.",
			["Not now", "Take the Iron Oath"] as Array[String]) == 1:
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
		GameState.apply_display()
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
			"Gamepad rumble: %s" % ("On" if GameState.rumble else "Off"),
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
				GameState.rumble = not GameState.rumble
				GameState.rumble_pads(0.6, 0.2)
			6:
				await info(PAD_HELP)
		VirtualPad.apply_settings()

## Multi-line summary of a Spirling.
static func summary(s: Spirling) -> String:
	var els: PackedStringArray = []
	for e: int in s.elements():
		els.append(Elements.element_name(e))
	var lines: PackedStringArray = [
		"%s  (%s)" % [s.display_name(), s.data.species_name],
		"%s   Lv %d" % ["/".join(els), s.level],
		"HP %d/%d   XP to next %d" % [s.hp, s.max_hp(), s.xp_to_next()],
		"ATK %d  DEF %d  FOC %d  SPD %d" % [s.atk(), s.def(), s.foc(), s.spd()],
	]
	var tm: Dictionary = s.temperament()
	lines.append("Temperament: %s. %s" % [tm.label, tm.text])
	var tr: Dictionary = BattleRules.trait_info(s.data.trait_id)
	if not tr.is_empty():
		lines.append("Trait: %s. %s" % [tr.label, tr.text])
	if not s.held.is_empty():
		lines.append("Holds: %s" % Database.item(s.held).get("name", s.held))
	lines.append("")
	for mv: MoveData in s.moves:
		var power: String = "-" if mv.power <= 0 else str(mv.power)
		lines.append("%s  %s  P%s  E%d" % [mv.move_name, Elements.element_name(mv.element).substr(0, 3), power, mv.energy_cost])
	return "\n".join(lines)

static func party_line(s: Spirling) -> String:
	var tag: String = " (out)" if s.is_fainted() else ""
	return "%s Lv%d %d/%d%s" % [s.display_name(), s.level, s.hp, s.max_hp(), tag]

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
