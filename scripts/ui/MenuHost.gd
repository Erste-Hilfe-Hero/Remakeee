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
			"Touch controls...",
		]
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
				await run_controls()

## Touch controls: pad size, opacity, left-handed layout, tap-to-move.
func run_controls() -> void:
	while true:
		var entries: Array[String] = [
			"Pad size: %s" % GameState.PAD_SIZE_NAMES[GameState.pad_size],
			"Pad opacity: %d%%" % int(round(GameState.PAD_ALPHAS[GameState.pad_opacity] * 100.0)),
			"Left-handed: %s" % ("On" if GameState.left_handed else "Off"),
			"Tap to walk: %s" % ("On" if GameState.tap_to_move else "Off"),
		]
		var idx: int = await pick_strings("Touch controls", entries)
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
		"",
	]
	for mv: MoveData in s.moves:
		var power: String = "-" if mv.power <= 0 else str(mv.power)
		lines.append("%s  %s  P%s  E%d" % [mv.move_name, Elements.element_name(mv.element).substr(0, 3), power, mv.energy_cost])
	return "\n".join(lines)

static func party_line(s: Spirling) -> String:
	var tag: String = " (out)" if s.is_fainted() else ""
	return "%s Lv%d %d/%d%s" % [s.display_name(), s.level, s.hp, s.max_hp(), tag]
