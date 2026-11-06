class_name TitleScreen
extends Control
## Title and new-game flow: boy or girl -> name -> the prologue starts in the overworld.

const OVERWORLD: String = "res://scenes/overworld/Overworld.tscn"
const NAME_MAX: int = 10
const ART_HEIGHT: int = 148

var _menu: MenuHost
## Connection state, server notice and how many Tamers are online.
var _status: Label
var _name_box: PanelContainer
var _name_edit: LineEdit
var _name_keys: NameKeyboard
signal _name_done(text: String)
## While Online.connect_now runs (animated status line).
var _connecting: bool = false
var _connect_started: int = 0
## True while the main title list waits (the back button then asks to quit).
var _at_root: bool = false
## What the root list returns when the Android back button asks to quit.
const QUIT_ASKED: int = -2

func _ready() -> void:
	Database.load_all()
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := TitleArt.new()
	art.set_anchors_preset(Control.PRESET_TOP_WIDE)
	art.offset_bottom = ART_HEIGHT
	add_child(art)
	_menu = MenuHost.new()
	add_child(_menu)
	_menu.offset_top = ART_HEIGHT + 4
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# In the night sky above the lake, in light ink: lower down it sat on the three Spirlings
	# in dark ink and could not be read.
	_status.offset_top = 64
	_status.offset_bottom = 86
	_status.add_theme_color_override("font_color", UITheme.BG)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_build_name_box()
	VirtualPad.set_wanted(false)
	GameState.in_game = false
	Sound.music("title")
	_run.call_deferred()

func _build_name_box() -> void:
	_name_box = PanelContainer.new()
	_name_box.add_theme_stylebox_override("panel", UITheme.panel_style())
	_name_box.set_anchors_preset(Control.PRESET_CENTER)
	_name_box.custom_minimum_size = Vector2(136, 110)
	_name_box.offset_left = -68
	_name_box.offset_right = 68
	_name_box.offset_top = -55
	_name_box.offset_bottom = 55
	_name_box.visible = false
	add_child(_name_box)
	var v := VBoxContainer.new()
	_name_box.add_child(v)
	var l := Label.new()
	l.text = "Your name?"
	v.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	_name_edit.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
	_name_edit.add_theme_color_override("font_color", UITheme.INK)
	_name_edit.text_submitted.connect(func(t: String) -> void: _name_done.emit(t))
	# Gamepad / virtual pad confirm also submits the name.
	_name_edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_accept") and not (ev is InputEventKey):
			_name_done.emit(_name_edit.text))
	v.add_child(_name_edit)
	# Own letter keys: the phone keyboard does not always open (iPhone browser, item from Ali 2026-11-04).
	_name_keys = NameKeyboard.new()
	_name_keys.target = _name_edit
	_name_keys.confirmed.connect(func() -> void: _name_done.emit(_name_edit.text))
	v.add_child(_name_keys)

## Chimora is online only: nothing past the title works without the server (item 1).
func _go_online() -> void:
	while true:
		_connect_started = Time.get_ticks_msec()
		_connecting = true
		var st: Online.State = await Online.connect_now()
		_connecting = false
		if st == Online.State.ONLINE:
			_status.text = ""
			if not Online.privacy_seen:
				await _menu.info(AccountMenu.PRIVACY_NOTE)
				Online.mark_privacy_seen()
			if await Online.sync_down():
				await _resolve_conflicts()
				_show_status()
				return
			continue
		if st == Online.State.UPDATE_REQUIRED:
			_status.text = ""
			# A button opens the store page directly (item 2148).
			var u: int = await _menu.pick_strings("A new version of Chimora is out. Please update it in the store to keep playing.",
				["Open the store", "Try again"] as Array[String], false)
			if u == 0:
				OS.shell_open(Online.store_url())
			continue
		_status.text = "No connection"
		var idx: int = await _menu.pick_strings(Online.error_text() + "\n" + Loc.t("Your journeys are safe on the server."),
			["Try again", "Settings"] as Array[String], false)
		if idx == 1:
			await _menu.run_settings()

## "Connecting..." with moving dots, a note after 5 s and another after 15 s (item 2127).
static func connecting_text(seconds: float) -> String:
	var dots: String = ".".repeat(1 + int(seconds * 2.0) % 3)
	var line: String = Loc.t("Connecting") + dots
	if seconds >= 15.0:
		line += "\n" + Loc.t("Still trying. The next step comes as soon as the server answers.")
	elif seconds >= 5.0:
		line += "\n" + Loc.t("The server is answering slowly.")
	return line

func _process(_delta: float) -> void:
	if _connecting:
		_status.text = connecting_text((Time.get_ticks_msec() - _connect_started) / 1000.0)

func _show_status() -> void:
	var lines: Array[String] = []
	if not Online.motd.is_empty():
		lines.append(Online.motd)
	if Online.online_now > 1:
		lines.append("%d Wayfarers are in Veydal" % Online.online_now)
	_status.text = "\n".join(lines)

## A slot changed on this phone and on another device: the player picks which to keep (item 8).
func _resolve_conflicts() -> void:
	for slot: int in Online.conflicts.duplicate():
		var idx: int = await _menu.pick_strings("Slot %d was played on this phone and on another device. Which journey do you keep?" % slot,
			["The other device's", "This phone's"] as Array[String], false)
		if idx == 1:
			await Online.resolve_conflict_keep_local(slot)
		else:
			await Online.resolve_conflict_take_server(slot)

func _run() -> void:
	await _go_online()
	while true:
		if not Online.is_online():
			await _go_online()
		var items: Array[String] = []
		# "Continue" is always the newest save, one tap from launch.
		var latest: int = SaveManager.latest_slot()
		var summary: String = SaveManager.slot_summary(latest) if latest > 0 else ""
		if latest > 0:
			items.append("Continue" if summary.is_empty() else "Continue  %s" % summary)
		items.append("New Game")
		if _used_slots() > 1:
			items.append("Load...")
		items.append("Settings")
		_at_root = true
		var idx: int = await _menu.pick_strings("", items, false)
		_at_root = false
		if idx == QUIT_ASKED:
			if await _menu.confirm("Quit Chimora?"):
				get_tree().quit()
			continue
		var choice: String = "Continue" if items[idx].begins_with("Continue") else items[idx]
		match choice:
			"Continue":
				SaveManager.set_slot(latest)
				if SaveManager.load_game():
					await _say_if_recovered()
					SaveManager.save_settings()
					_enter_game()
					return
				await _menu.info("The save could not be read.")
			"Load...":
				var n: int = await _pick_slot("Load which save?", false)
				if n > 0:
					SaveManager.set_slot(n)
					if SaveManager.load_game():
						await _say_if_recovered()
						SaveManager.save_settings()
						_enter_game()
						return
					await _menu.info("The save could not be read.")
			"New Game":
				var slot: int = await _pick_slot("Save the new journey in...", true)
				if slot <= 0:
					continue
				if not SaveManager.slot_summary(slot).is_empty() and not await _menu.confirm_danger("Start over in slot %d? That save will be replaced when you save." % slot):
					continue
				SaveManager.set_slot(slot)
				if await _new_game():
					SaveManager.save_settings()
					_enter_game()
					return
			"Settings":
				await _menu.run_settings()

## Android back (item 1787): on the main list it asks to quit, otherwise it works like B.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _menu == null:
		return
	if _at_root and _menu.picker.visible:
		_menu.picker.picked.emit(QUIT_ASKED)
	elif _name_box != null and _name_box.visible:
		pass
	else:
		BackButton.press_cancel()

func _enter_game() -> void:
	Online.push_profile()
	get_tree().change_scene_to_file(OVERWORLD)

func _used_slots() -> int:
	var n: int = 0
	for i: int in range(1, SaveManager.SLOTS + 1):
		if not SaveManager.slot_summary(i).is_empty():
			n += 1
	return n

## Lists the three slots. [param allow_empty]: empty slots can be picked (new game). Returns 0 on cancel.
func _pick_slot(title: String, allow_empty: bool) -> int:
	var labels: Array[String] = []
	for i: int in range(1, SaveManager.SLOTS + 1):
		var s: String = SaveManager.slot_summary(i)
		labels.append("Slot %d: %s" % [i, s if not s.is_empty() else "empty"])
	while true:
		var idx: int = await _menu.pick_strings(title, labels)
		if idx < 0:
			return 0
		if allow_empty or not SaveManager.slot_summary(idx + 1).is_empty():
			return idx + 1
	return 0

## New game (Ali, 2026-11-04): boy or girl, then a name, and the journey starts. The partner
## Spirling is picked in the story (prologue at the lighthouse). Difficulty and the Iron Oath
## live in the settings during the game.
func _new_game() -> bool:
	var look: int = await _menu.pick_strings("Who are you?", ["Boy", "Girl"] as Array[String])
	if look < 0:
		return false
	_name_edit.text = GameState.DEFAULT_NAMES[look]
	_name_box.visible = true
	_name_keys.fresh = true
	_name_keys.focus_first()
	var name: String = await _name_done
	_name_box.visible = false
	GameState.new_game(GameState.Difficulty.TAMER, name, look, "", look)
	GameState.iron_oath = false
	EraManager.from_dict({})
	return true

## The main save file was damaged and a backup was loaded (plan item 3609).
func _say_if_recovered() -> void:
	if SaveManager.last_load_recovered:
		await _menu.info("The save was damaged. The latest backup was loaded.")
