class_name TitleScreen
extends Control
## Title and new-game flow: boy or girl -> name -> the prologue starts in the overworld.

const OVERWORLD: String = "res://scenes/overworld/Overworld.tscn"
const NAME_MAX: int = 10
const ART_HEIGHT: int = 148
## Era of the title (the newest era any save reached), its art height and the save card.
var _era: int = 1
var _art_h: int = ART_HEIGHT
var _card: EraSaveCard
## True while a slot list is open: the card then follows the focused slot.
var _slot_list: bool = false
## True when the card has its own band under the picture (tall screens).
var _card_band: bool = false

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
	# The title wears the newest era a save has reached (EraMoments, docs/ERA_LOOK_TITLE.md).
	_era = EraMoments.title_era()
	if EraManager.unlocked_era != _era or EraManager.retro_filter != 0:
		EraManager.from_dict({"unlocked_era": _era})
	# The picture takes the height the list and a save card in its own band leave (item 66).
	var room_h: float = get_viewport_rect().size.y
	if _used_slots() > 0 and EraSaveCard.fits_band(get_viewport_rect().size):
		room_h -= EraSaveCard.height_for(EraManager.RESOLUTION[_era].x) + 2
	_art_h = EraTitleArt.title_height(Vector2(EraManager.RESOLUTION[_era]), room_h, EraMenus.layout(_era))
	var art := EraTitleArt.new()
	art.era = _era
	art.set_anchors_preset(Control.PRESET_TOP_WIDE)
	art.offset_bottom = _art_h
	add_child(art)
	_menu = MenuHost.new()
	add_child(_menu)
	_menu.offset_top = _art_h + 4
	if _used_slots() > 0:
		# The save card, in the save's own era look: between the picture and the list where the
		# screen has the room, else over the picture's lower edge while a slot list is open.
		var card_h: int = EraSaveCard.height_for(EraManager.RESOLUTION[_era].x)
		_card_band = EraSaveCard.fits_band(get_viewport_rect().size, _art_h)
		_card = EraSaveCard.new()
		_card.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_card.offset_left = 4
		_card.offset_right = -4
		_card.offset_top = _art_h + 2 if _card_band else _art_h - 12 - card_h
		_card.offset_bottom = _card.offset_top + card_h
		add_child(_card)
		if _card_band:
			_menu.offset_top = _art_h + 4 + card_h
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# In the night sky above the lake, in light ink: lower down it sat on the three Spirlings
	# in dark ink and could not be read.
	_status.offset_top = 64 * _art_h / ART_HEIGHT
	_status.offset_bottom = 86 * _art_h / ART_HEIGHT
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
	# No "Free, in-app purchases" banner on the title art (Chimora 100, item 69): the store
	# listing carries that notice, the shop's About page says the game is free.
	_build_name_box()
	# The version sits under the list frame, not on it (Chimora 100 item 54).
	add_child(version_label())
	_menu.offset_bottom = -VERSION_ROOM
	Loc.events.language_changed.connect(_on_language_changed)
	VirtualPad.set_wanted(false)
	GameState.in_game = false
	Sound.music("title")
	StartupLog.mark("title scene built")
	EraBoot.start(self, _era)
	_run.call_deferred()

## The version, small in the lower right corner (item 1972).
static func version_label() -> Label:
	var v := Label.new()
	v.name = "version"
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.text = version_text()
	v.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	v.offset_left = -60
	v.offset_top = -12
	v.offset_right = -2
	v.offset_bottom = 0
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_theme_color_override("font_color", UITheme.MID)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

## Height kept free under the title list for the version label.
const VERSION_ROOM: int = 5

static func version_text() -> String:
	return "v" + Online.CLIENT_VERSION_NAME

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
	var head := HBoxContainer.new()
	v.add_child(head)
	var l := Label.new()
	l.text = "Your name?"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	# Characters left, "4/10" (item 1966).
	head.add_child(CharCounter.make(_name_edit, NAME_MAX))
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
	# The update panel at load (docs/LIVE_CONTENT.md): Play's in-app update, the itch.io download
	# or the App Store page, before the server is even asked.
	await _offer_update()
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
				await privacy_note(_menu, _set_art_note)
				_hide_art_note()
				Online.mark_privacy_seen()
			if await Online.sync_down():
				await _resolve_conflicts()
				await _offer_update()
				_show_status()
				return
			continue
		if st == Online.State.UPDATE_REQUIRED:
			_status.text = ""
			# The update panel updates in the game where it can, otherwise opens the store page (item 2148).
			if await Online.updater.offer("required") == AppUpdate.NONE:
				var u: int = await _menu.pick_strings("A new version of Chimora is out. Please update it in the store to keep playing.",
					["Update", "Try again"] as Array[String], false)
				if u == 0:
					MenuHost.open_url.call(Online.store_url())
			continue
		_status.text = "No connection"
		var offline_ok: bool = Online.offline_start_allowed(_used_slots(), Online.revs.size(), Online.kicked, st)
		var options: Array[String] = ["Try again", "Settings"]
		if offline_ok:
			options.append(OFFLINE_START)
		var idx: int = await _menu.pick_strings(Online.error_text() + "\n" + Loc.t(OFFLINE_NOTE if offline_ok else "Your journeys are safe on the server."),
			options, false)
		if idx == 1:
			await _menu.run_settings()
		elif idx == 2:
			await _start_offline()
			return

## New Game without a connection (plan Chimora 100, item 77): only the prologue, up to its save
## point; then the account is created and the save goes up like any other (Online.offline_save_point).
const OFFLINE_START: String = "Start offline"
const OFFLINE_NOTE: String = "A new journey can start offline. The prologue goes online at its save point."
const OFFLINE_STATUS: String = "Offline: prologue only"

func _start_offline() -> void:
	if not Online.privacy_seen:
		await privacy_note(_menu, _set_art_note)
		_hide_art_note()
		Online.mark_privacy_seen()
	Online.begin_offline_start()
	_status.text = OFFLINE_STATUS

## At load and once more after connecting, once per app start each: a newer build is out (Play's
## in-app update, the App Store lookup or the live content's "latest" for this platform), so the
## update panel offers it. Below "min_client" connect_now already stopped.
static var _update_offered: bool = false
static var _offered_state: String = ""

func _offer_update() -> void:
	if Online.store_version.is_empty():
		await Online.check_store()
	var state: String = Online.update_state()
	# The fresh patch after connecting can say more than the cached one at load.
	if _update_offered and (state == _offered_state or state == "none"):
		return
	var first: bool = not _update_offered
	_update_offered = true
	_offered_state = state
	# Play is asked only at load; after connecting the live content alone decides.
	if first or state != "none":
		await Online.updater.offer(state)

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
	if _card != null:
		if _slot_list and _menu.picker.visible:
			_card.show_slot(_menu.picker.focused_index() + 1)
		elif _at_root and _card_band:
			_card.show_slot(SaveManager.latest_slot())
		else:
			_card.visible = false

func _on_language_changed(_code: String) -> void:
	if not _connecting and Online.is_online():
		_show_status()

func _exit_tree() -> void:
	if Loc.events.language_changed.is_connected(_on_language_changed):
		Loc.events.language_changed.disconnect(_on_language_changed)

func _show_status() -> void:
	var lines: Array[String] = []
	if not Online.motd.is_empty():
		lines.append(Online.motd)
	var maint: String = ReplayLibrary.maintenance_text(Online.unix_now(), Online.maintenance_at)
	if not maint.is_empty():
		lines.append(maint)
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

## The "Welcome back" card after Continue (plan Chimora 100, item 44): where the Wayfarer
## stands, the current goal and what today brings. One tap closes it.
static func welcome_text(flags: Dictionary) -> String:
	var lines: PackedStringArray = [Loc.t("Welcome back, %s!") % GameState.tamer_name, ""]
	lines.append(Loc.t("You are in %s.") % Loc.t(Spirling.place_name(GameState.current_map)))
	var goal: String = QuestLog.hud_text(flags)
	if goal.is_empty():
		goal = Loc.t(QuestLog.goal_text(QuestLog.current(flags), flags))
	lines.append(Loc.t("Goal: %s") % goal)
	var today: PackedStringArray = []
	var visitor: String = DailyFind.hint(flags)
	if not visitor.is_empty():
		today.append(Loc.t(visitor))
	var tasks: Array = DailyTasks.today().get("tasks", [])
	if not tasks.is_empty():
		var done: int = tasks.filter(func(e: Variant) -> bool: return e is Dictionary and DailyTasks.is_done(e)).size()
		today.append(Loc.t("Daily tasks: %d of %d done.") % [done, tasks.size()])
	if Goals.pending() > 0:
		today.append(Loc.t("A reward waits under Goals."))
	if not today.is_empty():
		lines.append("")
		lines.append_array(today)
	return "\n".join(lines)

func _run() -> void:
	var first_start: bool = GameState.language.is_empty() and not Online.privacy_seen and _used_slots() == 0
	if GameState.language.is_empty():
		StartupLog.mark("language menu ready")
		await _pick_language()
	# The terms come before the server is asked and before any journey, offline ones too.
	if terms_needed():
		# The list takes the room under the wordmark, so every row and the note show at once.
		var top: float = _menu.offset_top
		_menu.offset_top = roundf(TERMS_TOP * get_viewport_rect().size.x / EraTitleArt.BASE_W)
		await terms_step(_menu)
		_menu.offset_top = top
	# An offline start ends when the title shows again; Continue is online only (item 77).
	Online.offline_play = false
	await _go_online()
	if first_start:
		# Item 2000: once, where the comfort settings live, without a tap to dismiss. Over the
		# title art, never over the list (Chimora 100 item 33).
		_show_art_note(FIRST_START_HINT, FIRST_START_HINT_SECONDS)
	while true:
		if not Online.is_online() and not Online.offline_play:
			await _go_online()
		var items: Array[String] = []
		# "Continue" is always the newest save, one tap from launch.
		var latest: int = SaveManager.latest_slot()
		var summary: String = SaveManager.slot_summary(latest) if latest > 0 else ""
		if latest > 0:
			items.append("Continue" if summary.is_empty() else "Continue  %s" % summary)
		items.append("New Game")
		# Played on another phone: a row of its own instead of a question before the game
		# starts (Chimora 100 item 29). With a save here it lives under Settings, Account.
		if _used_slots() == 0 and not Online.offline_play:
			items.append(HAVE_CODE)
		if _used_slots() > 1:
			items.append("Load...")
		items.append("What's new")
		items.append("Join our Discord")
		items.append("Settings")
		_at_root = true
		StartupLog.mark("title menu ready")
		var entries: Array[Dictionary] = []
		for it: String in items:
			entries.append({"text": it})
		if latest > 0:
			# The Continue row carries the badge of the save's era; a long place name ends in
			# an ellipsis instead of being cut (Chimora 100 item 54).
			entries[0]["icon"] = EraSaveCard.badge(maxi(EraMoments.slot_era(latest), 1))
			entries[0]["ellipsis"] = true
		var idx: int = await _menu.pick("", entries, false)
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
					await _menu.info(welcome_text(GameState.flags), EraSaveCard.badge(maxi(EraMoments.slot_era(latest), 1)))
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
			HAVE_CODE:
				if await AccountMenu.claim_code(_menu, false):
					_status.text = ""
			"What's new":
				await _menu.run_news()
			"Join our Discord":
				_menu.open_discord()
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
## Title row for players who come from another phone (item 1964, Chimora 100 item 29).
const HAVE_CODE: String = "I have a code"

## The first-start hint, in a strip over the lower edge of the title art so it never hides a
## row of the list under it (Chimora 100 item 33).
var _art_note: Label

func _show_art_note(text: String, seconds: float) -> void:
	_set_art_note(text)
	_art_note_gen += 1
	var gen: int = _art_note_gen
	await get_tree().create_timer(seconds, true).timeout
	if gen == _art_note_gen:
		_hide_art_note()

## Shows [param text] over the art until _hide_art_note (the explanation of the list below).
func _set_art_note(text: String) -> void:
	_art_note_gen += 1
	if _art_note == null:
		_art_note = Label.new()
		_art_note.name = "art_note"
		_art_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_art_note.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_art_note.offset_left = 4
		_art_note.offset_right = -4
		_art_note.offset_bottom = _art_h - 1
		_art_note.offset_top = _art_note.offset_bottom
		_art_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_art_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_art_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_art_note.add_theme_color_override("font_color", UITheme.INK)
		_art_note.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
		_art_note.accessibility_live = AccessibilityServer.LIVE_POLITE
		_art_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art_note)
	_art_note.text = Loc.t(text)
	_art_note.visible = true

var _art_note_gen: int = 0

func _hide_art_note() -> void:
	if is_instance_valid(_art_note):
		_art_note.visible = false

## The note over the art while it shows (tests), else null.
func art_note() -> Label:
	return _art_note if _art_note != null and _art_note.visible else null

## First connect (Chimora 100 item 28): one short sentence, "More" opens the whole note.
const PRIVACY_SHORT: String = "Online only: your journeys are safe on our server. No ads, no tracking."
const PRIVACY_TITLE: String = "Privacy"
const PRIVACY_ROWS: Array[String] = ["OK", "More"]

## The sentence is the rows' hint under the list, or, with [param note] (the title screen), it
## stands over the title art so both rows stay in view on the smallest screen.
static func privacy_rows(hint: bool = true) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for r: String in PRIVACY_ROWS:
		rows.append({"text": r, "hint": Loc.t(PRIVACY_SHORT) if hint else ""})
	return rows

static func privacy_note(menu: MenuHost, note: Callable = Callable()) -> void:
	while true:
		if note.is_valid():
			note.call(PRIVACY_SHORT)
		if await menu.pick(PRIVACY_TITLE, privacy_rows(not note.is_valid()), false) != 1:
			return
		await menu.info(Loc.t(AccountMenu.PRIVACY_NOTE) + "\n\n" + Loc.t(LocalNotify.PRIVACY_LINE))

## Before the first connection and the first journey the player accepts the terms of use and
## the privacy policy (docs/legal/NUTZUNGSBEDINGUNGEN.md 2.1). Players with a save see it once on
## their next start; a new LegalInfo.TERMS_VERSION asks again. The short privacy note stands with
## it, so the separate note after connecting is not needed any more.
const TERMS_SCREEN: String = "terms"
const TERMS_TITLE: String = "Before you play"
const TERMS_ACCEPT: String = "I have read and accept the Terms of Use and the Privacy Policy."
const TERMS_READ: String = "Read the Terms of Use"
const PRIVACY_READ: String = "Read the Privacy Policy"
const TERMS_GO: String = "Continue"
const TERMS_WHY: String = "Tick the box above to continue."
enum TermsRow { ACCEPT, TERMS, PRIVACY, GO }
## Top of the terms list on the 144 px wide title: just under the wordmark and its subtitle.
const TERMS_TOP: float = 46.0
## Rows a finger hits safely: 18 px of the 144 px wide screen are 48 pt on a 390 pt phone.
const TERMS_ROW_H: int = 18

static func terms_needed() -> bool:
	return GameState.terms_version != LegalInfo.TERMS_VERSION

## The rows of the terms step; "Continue" works only once the box is ticked. The sentence of the
## privacy note is the rows' hint under the list.
static func terms_rows(checked: bool) -> Array[Dictionary]:
	var h: String = Loc.t(PRIVACY_SHORT)
	return [
		{"text": TERMS_ACCEPT, "icon": check_box(checked), "icon_top": true, "say": Loc.t("Ticked" if checked else "Not ticked"), "hint": h},
		{"text": TERMS_READ, "hint": h},
		{"text": PRIVACY_READ, "hint": h},
		{"text": TERMS_GO, "disabled": not checked, "hint": h, "why": "" if checked else TERMS_WHY},
	]

## A small tick box for the accept row, ticked or empty.
static func check_box(on: bool) -> ImageTexture:
	var key: int = 1 if on else 0
	if _boxes.has(key):
		return _boxes[key]
	var img: Image = Image.create(9, 9, false, Image.FORMAT_RGBA8)
	# Paper inside, so the box shows on a light row and on the dark focused one alike.
	img.fill(UITheme.BG)
	for i: int in 9:
		for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 8), Vector2i(0, i), Vector2i(8, i)]:
			img.set_pixelv(p, UITheme.INK)
	if on:
		for p: Vector2i in [Vector2i(2, 4), Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(7, 2),
				Vector2i(2, 5), Vector2i(3, 6), Vector2i(4, 5), Vector2i(5, 4)]:
			img.set_pixelv(p, UITheme.INK)
	_boxes[key] = ImageTexture.create_from_image(img)
	return _boxes[key]

static var _boxes: Dictionary[int, ImageTexture] = {}

## Keeps the accepted version on this device and counts the privacy note as seen.
static func accept_terms() -> void:
	GameState.terms_version = LegalInfo.TERMS_VERSION
	SaveManager.save_settings()
	Online.mark_privacy_seen()

static func terms_step(menu: MenuHost) -> void:
	var checked: bool = false
	var focus: int = TermsRow.ACCEPT
	while true:
		var idx: int = await menu.pick_screen(TERMS_SCREEN, TERMS_TITLE, terms_rows(checked),
			{"cancellable": false, "focus": focus, "wrap": true, "row_h": TERMS_ROW_H})
		focus = maxi(idx, 0)
		match idx:
			TermsRow.ACCEPT:
				checked = not checked
				if checked:
					focus = TermsRow.GO
			TermsRow.TERMS:
				MenuHost.open_url.call(LegalInfo.terms_url())
				menu.toast(LegalInfo.terms_url())
			TermsRow.PRIVACY:
				MenuHost.open_url.call(LegalInfo.privacy_url())
				menu.toast(LegalInfo.privacy_url())
			TermsRow.GO:
				if checked:
					accept_terms()
					return

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
	_hide_art_note()
	_name_box.visible = true
	_name_keys.fresh = true
	# Phones open their own keyboard (any script), gamepads use the letter keys (item 36).
	if NameKeyboard.system_keyboard_first():
		_name_keys.open_system_keyboard.call_deferred()
	else:
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
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
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
	var labels: Array[Dictionary] = []
	for i: int in range(1, SaveManager.SLOTS + 1):
		var s: String = SaveManager.slot_summary(i)
		var row: Dictionary = {"text": "Slot %d: %s" % [i, s if not s.is_empty() else "empty"]}
		# Each used slot carries the badge of its era; the card above shows the focused one.
		if not s.is_empty():
			row["icon"] = EraSaveCard.badge(maxi(EraMoments.slot_era(i), 1))
		labels.append(row)
	_slot_list = true
	var picked: int = 0
	while true:
		var idx: int = await _menu.pick(title, labels)
		if idx < 0:
			break
		if allow_empty or not SaveManager.slot_summary(idx + 1).is_empty():
			picked = idx + 1
			break
	_slot_list = false
	return picked

## New game (Chimora 100 items 25, 27): how hard battles should be, then one look screen with a
## live picture of the Wayfarer, then a name, and the journey starts. The partner Spirling is
## picked in the story (prologue at the lighthouse). Challenge rules and the Iron Oath are
## optional rows under Settings during the journey, until the first Rift is mended.
func _new_game() -> bool:
	var diff: int = -1
	var look: Array[int] = [0, 0, 0, 0]
	var name: String = ""
	var step: int = 0
	while step < 3:
		match step:
			0:
				diff = await ask_difficulty(_menu, _set_art_note)
				_hide_art_note()
				step = 1 if diff >= 0 else -1
			1:
				step = 2 if await look_screen(_menu, look, _look_stage()) else 0
			2:
				name = await _ask_name(GameState.DEFAULT_NAMES[look[LOOK_BODY]])
				step = 3 if name != NAME_BACK else 1
		if step < 0:
			return false
	GameState.new_game(diff as GameState.Difficulty, name.strip_edges(), look[LOOK_COAT], "", look[LOOK_BODY], look[LOOK_SKIN], look[LOOK_HAIR])
	GameState.iron_oath = false
	EraManager.from_dict({})
	return true

## The three difficulties asked at new game, easiest first, with one line each. The fourth,
## Rift-Born, stays in Settings (Challenge) for players who know the game.
const DIFFICULTY_TITLE: String = "Difficulty"
const DIFFICULTY_CHOICES: Array[GameState.Difficulty] = [GameState.Difficulty.STORY, GameState.Difficulty.TAMER, GameState.Difficulty.VETERAN]
const DIFFICULTY_ROWS: Array[String] = ["Relaxed", "Normal", "Tough"]
const DIFFICULTY_LINES: Array[String] = [
	"Gentle battles, more Growth.",
	"The journey as it is meant to be.",
	"Ring limits, smarter foes.",
]
## Said over the title art while the choice is open: nothing is locked in.
const DIFFICULTY_LATER: String = "You can change it later in Settings."

static func difficulty_rows(hint: bool = true) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in DIFFICULTY_ROWS.size():
		rows.append({"text": DIFFICULTY_ROWS[i], "hint": Loc.t(DIFFICULTY_LINES[i]) if hint else ""})
	return rows

## The line said for difficulty row [param i] over the title art.
static func difficulty_note(i: int) -> String:
	return Loc.t(DIFFICULTY_LINES[clampi(i, 0, DIFFICULTY_LINES.size() - 1)]) + "\n" + Loc.t(DIFFICULTY_LATER)

## Returns the picked GameState.Difficulty, or -1 for Back. Normal has the focus. With
## [param note] (the title screen) the focused row's line goes over the art, not under the list.
static func ask_difficulty(menu: MenuHost, note: Callable = Callable()) -> int:
	var follow: Callable = func(i: int) -> void:
		if i < DIFFICULTY_LINES.size():
			note.call(difficulty_note(i))
	if note.is_valid():
		note.call(difficulty_note(1))
		menu.picker.row_focused.connect(follow)
	var idx: int = await menu.pick(DIFFICULTY_TITLE, difficulty_rows(not note.is_valid()), true, 1)
	if note.is_valid() and menu.picker.row_focused.is_connected(follow):
		menu.picker.row_focused.disconnect(follow)
	return DIFFICULTY_CHOICES[idx] if idx >= 0 and idx < DIFFICULTY_CHOICES.size() else -1

## The look screen: body, skin, hair and coat in one list over a live picture, plus Random.
## A tap (or right) moves a row to the next choice, left to the one before.
const LOOK_BODY: int = 0
const LOOK_SKIN: int = 1
const LOOK_HAIR: int = 2
const LOOK_COAT: int = 3
const LOOK_RANDOM: int = 4
const LOOK_DONE: int = 5
const LOOK_TITLE: String = "Your look"
const LOOK_ROWS: Array[String] = ["Wayfarer: %s", "Skin: %s", "Hair: %s", "Coat: %s"]
const BODY_NAMES: Array[String] = ["Boy", "Girl"]

static func look_choices(part: int) -> Array[String]:
	match part:
		LOOK_SKIN:
			return GameState.SKIN_NAMES
		LOOK_HAIR:
			return GameState.HAIR_NAMES
		LOOK_COAT:
			return GameState.COAT_NAMES
	return BODY_NAMES

static func look_rows(look: Array[int]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for part: int in LOOK_ROWS.size():
		rows.append({"text": LOOK_ROWS[part] % look_choices(part)[look[part]], "slider": true})
	rows.append({"text": "Random"})
	rows.append({"text": "Done"})
	return rows

## Moves [param part] of [param look] by [param dir] choices, wrapping around.
static func step_look(look: Array[int], part: int, dir: int) -> void:
	look[part] = posmod(look[part] + (dir if dir != 0 else 1), look_choices(part).size())

static func random_look(look: Array[int], rng: RandomNumberGenerator) -> void:
	for part: int in LOOK_ROWS.size():
		look[part] = rng.randi_range(0, look_choices(part).size() - 1)

## Returns true on Done, false on Back. [param look] holds the choices and is changed in place.
## The picture goes into [param stage] (the title shows it over its art, so the list keeps its
## rows), else above the list.
static func look_screen(menu: MenuHost, look: Array[int], stage: Control = null) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var focus: int = 0
	while menu.is_inside_tree():
		if stage != null:
			for c: Node in stage.get_children():
				c.queue_free()
			stage.add_child(look_preview(look))
			stage.visible = true
		else:
			menu.picker.set_header(look_preview(look))
		var idx: int = await menu.pick(LOOK_TITLE, look_rows(look), true, focus)
		if stage != null:
			stage.visible = false
		elif is_instance_valid(menu.picker):
			menu.picker.set_header(null)
		if idx < 0:
			return false
		focus = idx
		if idx < LOOK_ROWS.size():
			step_look(look, idx, menu.picker.last_dir)
		elif idx == LOOK_RANDOM:
			random_look(look, rng)
		elif idx == LOOK_DONE:
			return true
	return false

## The panel over the title art that holds the look picture (built once).
var _look_panel: PanelContainer

func _look_stage() -> Control:
	if _look_panel == null:
		_look_panel = PanelContainer.new()
		_look_panel.name = "look_stage"
		_look_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
		_look_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_look_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_look_panel.offset_top = maxf(4.0, (_art_h - LOOK_FRAME * LOOK_SCALE) / 2.0 - 4.0)
		_look_panel.visible = false
		add_child(_look_panel)
	return _look_panel

## Size of one Wayfarer frame and how much bigger the preview draws it.
const LOOK_FRAME: int = 16
const LOOK_SCALE: int = 3
## Sheet colours the tamer sheets are drawn in (same as shaders/tamer_palette.gdshader).
const SRC_SKIN: Color = Color(0.949, 0.890, 0.761)
const SRC_CLOTH: Color = Color(0.416, 0.259, 0.337)
const HAIR_ROWS: int = 3

## The Wayfarer facing down and to the side in the picked colours, side by side.
static func look_preview(look: Array[int]) -> Control:
	var box := HBoxContainer.new()
	box.name = "look_preview"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	for column: int in [0, 3]:
		var r := TextureRect.new()
		r.texture = look_texture(look, column)
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.custom_minimum_size = Vector2(LOOK_FRAME * LOOK_SCALE, LOOK_FRAME * LOOK_SCALE)
		box.add_child(r)
	return box

## One frame of the Wayfarer sheet ([param column]: 0 down, 1 up, 2 left, 3 right), recoloured
## and scaled LOOK_SCALE times. Null when the sheet is missing.
static func look_texture(look: Array[int], column: int) -> Texture2D:
	var sheet: Texture2D = GridWalker.sheet_for(GameState.TAMER_SPRITES[look[LOOK_BODY]])
	if sheet == null:
		return null
	var img: Image = sheet.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img = img.get_region(Rect2i(column * LOOK_FRAME, 0, LOOK_FRAME, LOOK_FRAME))
	img.convert(Image.FORMAT_RGBA8)
	var skin: Color = GameState.SKIN_TONES[look[LOOK_SKIN]]
	var hair: Color = GameState.HAIR_COLORS[look[LOOK_HAIR]]
	var coat: Color = GameState.TAMER_COLORS[look[LOOK_COAT]]
	for y: int in LOOK_FRAME:
		for x: int in LOOK_FRAME:
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if _same(c, SRC_SKIN):
				img.set_pixel(x, y, Color(skin, c.a))
			elif _same(c, SRC_CLOTH):
				img.set_pixel(x, y, Color(hair if y < HAIR_ROWS else coat, c.a))
	img.resize(LOOK_FRAME * LOOK_SCALE, LOOK_FRAME * LOOK_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func _same(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.02

## The main save file was damaged and a backup was loaded (plan item 3609).
func _say_if_recovered() -> void:
	if SaveManager.last_load_recovered:
		await _menu.info("The save was damaged. The latest backup was loaded.")
