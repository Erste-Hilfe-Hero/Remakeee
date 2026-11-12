class_name TitleScreen
extends Control
## Title and new-game flow: boy or girl -> name -> the prologue starts in the overworld.

const OVERWORLD: String = "res://scenes/overworld/Overworld.tscn"
const NAME_MAX: int = 10
const ART_HEIGHT: int = 148
const IAP_NOTE: String = "Free, in-app purchases"
var _iap_note: Label

var _menu: MenuHost
## Connection state, server notice and how many Wanderers are online.
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
	# A see-through dark strip keeps the line readable over any title art (item 1965).
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0, 0, 0, 0.55)
	strip.set_content_margin_all(1)
	_status.add_theme_stylebox_override("normal", strip)
	_status.visible = false
	add_child(_status)
	# Free to play with optional purchases, said before the game starts (shop item 4036).
	_iap_note = Label.new()
	_iap_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_iap_note.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_iap_note.offset_top = ART_HEIGHT - 11
	_iap_note.offset_bottom = ART_HEIGHT
	_iap_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_iap_note.add_theme_color_override("font_color", UITheme.BG)
	_iap_note.add_theme_stylebox_override("normal", strip)
	_iap_note.text = Loc.t(IAP_NOTE)
	add_child(_iap_note)
	_build_name_box()
	Loc.events.language_changed.connect(_on_language_changed)
	VirtualPad.set_wanted(false)
	GameState.in_game = false
	Sound.music("title")
	StartupLog.mark("title scene built")
	_run.call_deferred()

func _build_name_box() -> void:
	_name_box = PanelContainer.new()
	_name_box.add_theme_stylebox_override("panel", UITheme.panel_style())
	_name_box.set_anchors_preset(Control.PRESET_CENTER)
	_name_box.custom_minimum_size = Vector2(136, 128)
	_name_box.offset_left = -68
	_name_box.offset_right = 68
	_name_box.offset_top = -64
	_name_box.offset_bottom = 64
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
	# Back to the boy or girl choice (item 1962).
	_name_keys.cancelled.connect(func() -> void: _name_done.emit(NAME_BACK))
	v.add_child(_name_keys)
	v.add_child(_name_keys.make_extra_row())

## Chimora is online only: nothing past the title works without the server (item 1).
func _go_online() -> void:
	while true:
		# Another device took the account (plan item 3010): only play here when the player says so.
		if Online.kicked:
			_status.text = ""
			await _menu.pick_strings(Online.error_text("other_device"), ["Play on this device"] as Array[String], false)
			Online.kicked = false
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
				await _offer_update()
				_show_status()
				return
			continue
		if st == Online.State.UPDATE_REQUIRED:
			_status.text = ""
			# A button opens the store page directly (item 2148).
			var u: int = await _menu.pick_strings("A new version of Chimora is out. Please update it in the store to keep playing.",
				["Update", "Try again"] as Array[String], false)
			if u == 0:
				MenuHost.open_url.call(Online.store_url())
			continue
		_status.text = "No connection"
		var idx: int = await _menu.pick_strings(Online.error_text() + "\n" + Loc.t("Your journeys are safe on the server."),
			["Try again", "Settings"] as Array[String], false)
		if idx == 1:
			await _menu.run_settings()

## Once per app start: a newer build is in the store (App Store lookup or the live content's
## "latest" for this platform), so offer it. Below "min_client" connect_now already stopped.
static var _update_offered: bool = false

func _offer_update() -> void:
	if _update_offered:
		return
	_update_offered = true
	await Online.check_store()
	if Online.update_state() != "optional":
		return
	if await _menu.pick_strings("A new version of Chimora is out.", ["Update", "Later"] as Array[String], false) == 0:
		MenuHost.open_url.call(Online.store_url())

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
	_status.visible = not _status.text.is_empty()

func _on_language_changed(_code: String) -> void:
	if _iap_note != null:
		_iap_note.text = Loc.t(IAP_NOTE)
	if not _connecting and Online.is_online():
		_show_status()

func _exit_tree() -> void:
	if Loc.events.language_changed.is_connected(_on_language_changed):
		Loc.events.language_changed.disconnect(_on_language_changed)

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
	var first_start: bool = GameState.language.is_empty() and not Online.privacy_seen and _used_slots() == 0
	if GameState.language.is_empty():
		StartupLog.mark("language menu ready")
		await _pick_language()
	await _go_online()
	if first_start:
		await _ask_other_phone()
		# Item 2000: once, where the comfort settings live, without a tap to dismiss.
		_menu.toast(FIRST_START_HINT, FIRST_START_HINT_SECONDS)
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
		items.append("What's new")
		items.append("Settings")
		_at_root = true
		StartupLog.mark("title menu ready")
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
				# With all slots empty there is nothing to choose (item 1959).
				var slot: int = 1 if _used_slots() == 0 else await _pick_slot("Save the new journey in...", true)
				if slot <= 0:
					continue
				if not SaveManager.slot_summary(slot).is_empty() and not await _menu.confirm_danger("Start over in slot %d? That save will be replaced when you save." % slot):
					continue
				SaveManager.set_slot(slot)
				if await _new_game():
					SaveManager.start_fresh_slot()
					SaveManager.save_settings()
					_enter_game()
					return
			"What's new":
				await _menu.run_news()
			"Settings":
				await _menu.run_settings()

## First start (item 1958): English or Deutsch, the device language comes first.
func _pick_language() -> void:
	var codes: Array[String] = Loc.LANGUAGES.duplicate()
	var entries: Array[Dictionary] = []
	for c: String in codes:
		entries.append({"text": Loc.LANGUAGE_NAMES[c]})
	var idx: int = await _menu.pick("Language / Sprache", entries, false, codes.find(Loc.default_language()))
	GameState.language = codes[maxi(idx, 0)]
	GameState.apply_display()
	SaveManager.save_settings()

const FIRST_START_HINT: String = "Large text, one-hand layout and more are under Settings."
const FIRST_START_HINT_SECONDS: float = 4.0

## First start (item 1964): someone who played on another phone gets there with a code
## instead of starting over by mistake.
func _ask_other_phone() -> void:
	var idx: int = await _menu.pick_strings("Played Chimora on another phone before?",
		["No, I am new", "Yes, I have a code"] as Array[String], false)
	if idx == 1:
		await AccountMenu.claim_code(_menu, false)

## Android back (item 1787): on the main list it asks to quit, otherwise it works like B.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _menu == null:
		return
	if _at_root and _menu.picker.visible:
		_menu.picker.picked.emit(QUIT_ASKED)
	elif _name_box != null and _name_box.visible:
		_name_done.emit(NAME_BACK)
	else:
		BackButton.press_cancel()

## What the name box returns when Back was pressed.
const NAME_BACK: String = "\n"

## The name box until a real name comes (item 1961: empty or only spaces is refused and the
## suggestion comes back), or NAME_BACK.
func _ask_name(suggestion: String) -> String:
	_name_edit.text = suggestion
	_name_box.visible = true
	_name_keys.fresh = true
	_name_keys.focus_first()
	var name: String = ""
	while true:
		name = await _name_done
		if name == NAME_BACK or NameKeyboard.valid_name(name):
			break
		Sound.sfx("cancel")
		_name_edit.text = suggestion
		_name_keys.fresh = true
	_name_box.visible = false
	return name

func _enter_game() -> void:
	Online.push_profile()
	# The title slides 24 px up and fades out before the world brightens in (item 2280).
	if not Juice.reduced():
		Juice.tween(self, "modulate:a", 0.0, "close")
		await Juice.tween(self, "position", position + Vector2(0, -24), "close").finished
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

## New game (Ali, 2026-11-04): boy or girl, skin tone, hair and coat colour (Ali, 7 Nov), then a name, and the journey starts. The partner
## Spirling is picked in the story (prologue at the lighthouse). Difficulty and the Iron Oath
## live in the settings during the game.
func _new_game() -> bool:
	var look: int = -1
	var skin: int = 0
	var hair: int = 0
	var coat: int = 0
	var name: String = ""
	while true:
		look = await _menu.pick_strings("Who are you?", ["Boy", "Girl"] as Array[String])
		if look < 0:
			return false
		skin = await _menu.pick_strings("Skin tone", GameState.SKIN_NAMES)
		if skin < 0:
			continue
		hair = await _menu.pick_strings("Hair colour", GameState.HAIR_NAMES)
		if hair < 0:
			continue
		coat = await _menu.pick_strings("Coat colour", GameState.COAT_NAMES)
		if coat < 0:
			continue
		name = await _ask_name(GameState.DEFAULT_NAMES[look])
		if name != NAME_BACK:
			break
	GameState.new_game(GameState.Difficulty.TAMER, name.strip_edges(), coat, "", look, skin, hair)
	GameState.iron_oath = false
	EraManager.from_dict({})
	return true

## The main save file was damaged and a backup was loaded (plan item 3609).
func _say_if_recovered() -> void:
	if SaveManager.last_load_recovered:
		await _menu.info("The save was damaged. The latest backup was loaded.")
