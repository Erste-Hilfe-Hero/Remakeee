class_name EraMenuKit
extends RefCounted
## Building blocks of the era menu screens (docs/ERA_FEEL_MENUS.md): rows, headers and small
## views that the start menu, team, satchel, Spirlog, save screen and map share. What each era
## shows comes from EraMenus.layout(); the colours and frames from UITheme (EraFeel skin).

const SHORTCUTS: String = "Shortcuts"
## What the info panel of the touch eras says about each start-menu entry.
const PAUSE_HINTS: Dictionary[String, String] = {
	"Goals": "What to do next, today's tasks and waiting rewards.",
	"Map book": "Aldo's map book with your own notes.",
	"Ledger": "Every secret you share with someone. Leverage and risk.",
	"Map": "The world map with your marks.",
	"Room": "Reset this room's puzzle or take a step back.",
	"Team": "Your Spirlings: order, summary, items, keepsakes.",
	"Satchel": "Everything you carry, sorted by pocket.",
	"Shop": "Optional purchases. Nothing in it is random.",
	"Shop (locked)": "Closed for your age.",
	"Spirlog": "Every kind you have seen or bonded.",
	"Travel": "Boat and coach to places you know.",
	"Friends": "Friends, trades, duels and Lantern Mail.",
	"Leagues": "Ranked duels of this season.",
	"Records": "Badges, deeds and the numbers of your road.",
	"Storage": "Spirlings that rest outside the team.",
	"Save": "Write your road into the book.",
	"Save and to title": "Save, then go back to the title.",
	"Photo": "Hide the menus and take a picture.",
	"Join our Discord": "Chat with other Wayfarers, news and tips.",
	"Settings": "Sound, controls, display and account.",
	"Shortcuts": "Pin up to four entries to the top of this menu.",
}
const SETTING_GROUP_HINTS: Dictionary[String, String] = {
	"game": "Difficulty, text speed and battle options.",
	"sound": "Volume of music, sounds, voices and ambience.",
	"controls": "Touch pad, gamepad and keys.",
	"display": "Language, contrast, text size, motion and the Retro filter.",
	"wardrobe": "Looks you own for the Wayfarer and the menus.",
	"account": "Your account, cloud save and data.",
	"legal": "Imprint, privacy, terms and licences.",
}
const BAR_WIDE: int = 64
## One beat of the two-frame bob of small sprites, in milliseconds.
const BOB_MS: int = 300

static func era() -> int:
	return EraManager.active_era()

static var _blank: Dictionary[int, ImageTexture] = {}

## A see-through square that keeps room for a picture the row draws itself.
static func blank(size: int) -> ImageTexture:
	if not _blank.has(size):
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank[size] = ImageTexture.create_from_image(img)
	return _blank[size]

## The symbol of [param id] in [param lay]'s era and icon size; null where the era has none.
static func icon_for(id: String, lay: Dictionary) -> Texture2D:
	if not bool(lay.get("icons", false)):
		return null
	return EraMenuArt.icon(id, int(lay.get("era", 1)), maxi(EraMenuArt.SIZE, int(lay.get("icon_size", EraMenuArt.SIZE))))

## Rows of the start menu: the label, from Era II its symbol, in the touch eras what it does
## for the info panel. A waiting reward keeps its dot on "Goals" (in Era I as "!" text).
## Rows in [param dots] have something new (MenuDots, item 1872) and carry the same dot.
static func pause_entries(labels: Array[String], waiting: bool, lay: Dictionary, dots: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var panel: bool = str(lay.get("panel", "none")) != "none"
	for l: String in labels:
		var e: Dictionary = {"text": l}
		var ic: Texture2D = icon_for(l if EraMenuArt.has(l) else "Shop", lay)
		if l == "Goals" and waiting:
			# A red dot on "Goals" while a reward waits (plan 3529); Era I, the plain text
			# list, says it with a "!" after the word.
			if bool(lay.get("icons", false)):
				e["icon"] = Goals.dot()
			else:
				e["text"] = Loc.t(l) + " !"
			e["say"] = "reward waiting"
		elif l in dots:
			if bool(lay.get("icons", false)):
				e["icon"] = Goals.dot()
			else:
				e["text"] = Loc.t(l) + " !"
			e["say"] = "new"
		elif ic != null:
			e["icon"] = ic
		if panel and PAUSE_HINTS.has(l):
			e["hint"] = PAUSE_HINTS[l]
		out.append(e)
	return out

## The settings groups in the era's layout: a symbol per group from Era II, in the touch eras
## what each group holds for the info panel. [param groups] is MenuHost.SETTINGS_GROUPS.
static func settings_entries(entries: Array[Dictionary], groups: Array) -> Array[Dictionary]:
	var lay: Dictionary = EraMenus.layout(era(), "options")
	for i: int in entries.size():
		var key: String = str(groups[i][0])
		var pic: Texture2D = icon_for(key, lay)
		if pic != null:
			entries[i]["icon"] = pic
		if str(entries[i].get("hint", "")).is_empty() and str(lay.get("panel", "none")) != "none":
			entries[i]["hint"] = SETTING_GROUP_HINTS.get(key, "")
	return entries

## 0 or -1: the two-frame bob of row [param index]'s sprite at [param ms]. Rows alternate, so
## the team does not hop in step. Still under reduced motion.
static func bob_at(ms: int, index: int, reduced: bool) -> int:
	if reduced:
		return 0
	return -1 if (ms / BOB_MS + index) % 2 == 0 else 0

## One team row in [param lay]'s era. Era I: name, Ring and Vigor as text over the ink line
## bar. Era II: a small bobbing sprite, the colour bar and element symbols. Era III: coloured
## element badges. Era IV and V: a large card with a 28 px sprite, a wide bar with numbers and
## a grip to drag the row to another slot.
static func party_entry(s: Spirling, leader: bool, index: int, lay: Dictionary) -> Dictionary:
	var base: Dictionary = MenuHost.party_entry(s, leader)
	var sp: int = int(lay.get("sprite", 0))
	var els: PackedStringArray = []
	for e: int in s.elements():
		els.append(Loc.t(Elements.element_name(e)))
	var out: Dictionary = {"text": "%s R%d" % [s.display_name(), s.level], "say": base.say, "leader": leader,
		"hint": str(base.hint) + "  " + "/".join(els),
		"animate": bool(lay.get("sprite_anim", false)),
		"decorate": func(b: Button) -> void: draw_party_row(b, s, leader, index, lay)}
	if sp > 0:
		out["icon"] = blank(sp)
	return out

static func draw_party_row(b: Button, s: Spirling, leader: bool, index: int, lay: Dictionary) -> void:
	var ink: Color = b.get_theme_color("font_focus_color" if b.has_focus() else "font_color", "Button")
	var sp: int = int(lay.get("sprite", 0))
	var big: bool = b.size.y >= 30.0
	var style: String = str(lay.get("badges", "text"))
	var x0: float = ListPicker.POINTER_SPACE + (sp + 2 if sp > 0 else 0)
	if sp > 0:
		var tex: Texture2D = MiniSprite.of(s.data.species_name, sp)
		if tex != null:
			var bob: int = bob_at(Time.get_ticks_msec(), index, Juice.reduced() or not bool(lay.get("sprite_anim", false)))
			b.draw_texture(tex, Vector2(ListPicker.POINTER_SPACE, floorf((b.size.y - sp) / 2.0) + bob))
	var ratio: float = clampf(float(s.hp) / maxf(1.0, float(s.max_hp())), 0.0, 1.0)
	var bar_w: float = BAR_WIDE if big else MenuHost.BAR_WIDTH
	var bar_h: float = 3.0 if big else 2.0
	var y: float = b.size.y - (8.0 if big else 3.0)
	EraFeel.draw_bar(b, Rect2(x0, y, bar_w, bar_h), ratio, ink, str(EraManager.feel("bar")))
	if ratio <= 0.0:
		var cx: float = x0 + bar_w + 3
		b.draw_line(Vector2(cx - 2, y - 2), Vector2(cx + 2, y + 2), ink)
		b.draw_line(Vector2(cx + 2, y - 2), Vector2(cx - 2, y + 2), ink)
	var font: Font = b.get_theme_font("font", "Button")
	var fs: int = b.get_theme_font_size("font_size", "Button")
	var right: float = b.size.x - 3.0
	if bool(lay.get("drag", false)):
		# Grip: three short lines at the right end.
		for i: int in 3:
			var gy: float = floorf(b.size.y / 2.0) - 3 + i * 3
			b.draw_line(Vector2(right - 7, gy), Vector2(right, gy), ink)
		right -= 11.0
	if leader:
		b.draw_colored_polygon(PackedVector2Array([Vector2(right - 5, 3), Vector2(right, 5.5), Vector2(right - 5, 8)]), ink)
		b.draw_line(Vector2(right - 6, 3), Vector2(right - 6, b.size.y - 3 if not big else 12), ink)
		right -= 9.0
	if style == "text":
		# Era I: Vigor as numbers at the right end, no symbols.
		var nums: String = "%d/%d" % [s.hp, s.max_hp()]
		var w: float = font.get_string_size(nums, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		b.draw_string(font, Vector2(right - w, floorf(b.size.y / 2.0) + font.get_ascent(fs) / 2.0 - 1), nums, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		return
	if big:
		var nums2: String = "%d/%d" % [s.hp, s.max_hp()]
		b.draw_string(font, Vector2(x0 + bar_w + 8, y + bar_h + 2), nums2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	var els: Array[int] = s.elements()
	var w2: float = 0.0
	for e: int in els:
		w2 += (ElementIcons.size() + 5.0) if style == "colour" else (ElementIcons.size() + 1.0)
	var at := Vector2(right - w2, 4.0 if big else floorf((b.size.y - EraMenuArt.badge_h()) / 2.0))
	for e: int in els:
		at.x += EraMenuArt.draw_badge(b, e, at, style, ink)

## The clock strip of the start menu and the save screen from Era II on: the time-of-day
## symbol, weekday, time and phase. It follows the device clock.
class ClockStrip extends HBoxContainer:
	var label: Label
	var _icon: PhaseIcon
	var _t: float = 0.0

	func _ready() -> void:
		name = "clock_strip"
		add_theme_constant_override("separation", 3)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(9, 9)
		add_child(holder)
		_icon = PhaseIcon.new()
		holder.add_child(_icon)
		_icon.position = Vector2(1, 1)
		label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_color_override("font_color", UITheme.MID)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		add_child(label)
		refresh()

	func refresh() -> void:
		label.text = EraMenus.clock_now()
		_icon.phase = DayCycle.current()
		_icon.queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if _t >= 1.0:
			_t = 0.0
			refresh()

static func clock_strip() -> Control:
	return ClockStrip.new()

## A row of small Spirling sprites (the save card, the Spirlog forms). With [member animated]
## they bob on the two-frame beat.
class SpriteRow extends Control:
	var species: Array[String] = []
	var px: int = 14
	var animated: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2((px + 2) * species.size(), px + 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not animated or Juice.reduced():
			return
		_t += delta
		if _t >= ListPicker.ROW_BEAT:
			_t = 0.0
			queue_redraw()

	func _draw() -> void:
		for i: int in species.size():
			var tex: Texture2D = MiniSprite.of(species[i], px)
			if tex != null:
				draw_texture(tex, Vector2(i * (px + 2), 1 + EraMenuKit.bob_at(Time.get_ticks_msec(), i, Juice.reduced() or not animated)))

## The save card above the save rows: who, where, how long, how many kinds; from Era II the
## clock and the team's sprites (bobbing in Era V).
static func save_card(lay: Dictionary, here: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "save_card"
	box.add_theme_constant_override("separation", 1)
	var seen: int = 0
	var bonded: int = 0
	for k: Variant in GameState.spirlog:
		seen += 1 if SpirlogBook.is_seen(GameState.spirlog, str(k)) else 0
		bonded += 1 if SpirlogBook.is_bonded(GameState.spirlog, str(k)) else 0
	var place: String = Spirling.place_name(here if not here.is_empty() else GameState.current_map)
	# Era I has no clock strip: the day and time stand on the card as its last line.
	var with_clock: bool = str(lay.get("card", "text")) == "clock"
	var lines: Array[String] = EraMenus.save_lines(GameState.tamer_name, place, GameState.play_time, seen, bonded,
		GameState.party.size(), "" if with_clock else EraMenus.clock_now())
	if with_clock:
		box.add_child(ClockStrip.new())
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	label.text = "\n".join(lines)
	box.add_child(label)
	var sp: int = int(lay.get("party", 0))
	if sp > 0 and not GameState.party.is_empty():
		var row := SpriteRow.new()
		row.px = sp
		row.animated = bool(lay.get("party_anim", false))
		for s: Spirling in GameState.party:
			row.species.append(s.data.species_name)
		box.add_child(row)
	return box

## The pocket header of the satchel: from Era II the pocket's name and how many kinds of
## things are in it (the tabs are symbols), from Era III with the pocket's picture.
static func pocket_header(pocket: int, pocket_name: String, count: int, lay: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "pocket_art"
	row.add_theme_constant_override("separation", 4)
	var art: bool = bool(lay.get("pocket_art", false))
	if art:
		var pic := TextureRect.new()
		pic.texture = EraMenuArt.pocket_art(pocket, int(lay.get("era", 3)))
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.custom_minimum_size = Vector2(EraMenuArt.POCKET_ART)
		row.add_child(pic)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = "%s%s%s" % [Loc.t(pocket_name), "\n" if art else "  ", Loc.t("%d kinds") % count]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	return row

## The pocket symbols for the satchel's tabs, one per pocket id in [param pockets].
static func pocket_tab_icons(pockets: Array[int], lay: Dictionary) -> Array:
	var out: Array = []
	for p: int in pockets:
		out.append(icon_for("pocket%d" % p, lay))
	return out

## A full-screen card over a menu with [param content], a caption and Back. Await closed.
class Card extends PanelContainer:
	signal closed

	func build(content: Control, caption: String) -> void:
		theme = UITheme.get_theme()
		add_theme_stylebox_override("panel", UITheme.panel_style())
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side: String in ["left", "top", "right", "bottom"]:
			set("offset_" + side, MenuHost.PANEL_MARGIN * (1 if side in ["left", "top"] else -1))
		mouse_filter = Control.MOUSE_FILTER_STOP
		var v := VBoxContainer.new()
		add_child(v)
		content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(content)
		var label := Label.new()
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(1, 0)
		label.text = caption
		v.add_child(label)
		var back := Button.new()
		back.text = "Back"
		back.custom_minimum_size = Vector2(0, maxi(ListPicker.ROW_HEIGHT, int(EraMenus.layout(EraMenuKit.era()).get("row_h", 16))))
		back.pressed.connect(func() -> void: closed.emit())
		v.add_child(back)
		back.grab_focus.call_deferred()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			closed.emit()

## Shows [param content] as a card over [param parent] until Back.
static func show_card(parent: Node, content: Control, caption: String) -> void:
	var card := Card.new()
	card.name = "era_card"
	parent.add_child(card)
	card.build(content, caption)
	await card.closed
	card.queue_free()

## What does not fit on the screen while [param host]'s list is open, as plain sentences: the
## list or a row outside the screen, a header that takes more than 45 percent of the height,
## fewer than three rows in view, or (with [param check_text]) a row whose text is cut off.
## Empty when the screen is sound. Used by the GUT tests and tools/era_menu_shots.gd.
static func fit_problems(host: MenuHost, check_text: bool = true) -> Array[String]:
	var out: Array[String] = []
	var summary: EraSummary = host.get_node_or_null("era_summary") as EraSummary
	if summary != null:
		for t: Node in summary._tab_row.get_children():
			var tb: Button = t as Button
			var font: Font = tb.get_theme_font("font", "Button")
			var fs: int = tb.get_theme_font_size("font_size", "Button")
			var sb: StyleBox = tb.get_theme_stylebox("normal", "Button")
			if font.get_string_size(Loc.t(tb.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tb.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT) + 0.5:
				out.append("summary tab cut off: %s" % Loc.t(tb.text))
		return out
	var p: ListPicker = host.picker
	if not p.visible:
		return out
	var f: Control = host.get_viewport().gui_get_focus_owner()
	if f is Button and f in p.buttons() and not p.row_fully_shown(f):
		out.append("the cursor row is out of view: %s" % (f as Button).text)
	var vp: Rect2 = host.get_viewport_rect()
	if not vp.grow(0.5).encloses(p.get_global_rect()):
		out.append("the list leaves the screen")
	var head: Control = p.header()
	if head != null and head.get_global_rect().size.y > vp.size.y * 0.45:
		out.append("the header takes more than 45 percent of the screen")
	var scroll: Rect2 = p._scroll.get_global_rect()
	var shown: int = 0
	var rows: Array[Button] = p.buttons()
	for b: Button in rows:
		var r: Rect2 = b.get_global_rect()
		if r.position.x < vp.position.x - 0.5 or r.end.x > vp.end.x + 0.5:
			out.append("row leaves the screen: %s" % b.text)
		if scroll.grow(0.5).encloses(r):
			shown += 1
		if not check_text:
			continue
		var sb: StyleBox = b.get_theme_stylebox("normal", "Button")
		var room: float = b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
		if b.icon != null and b.vertical_icon_alignment != VERTICAL_ALIGNMENT_TOP:
			room -= b.icon.get_width() + b.get_theme_constant("h_separation", "Button")
		var text: String = b.text if b.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else Loc.t(b.text)
		var font: Font = b.get_theme_font("font", "Button")
		var fs: int = b.get_theme_font_size("font_size", "Button")
		if b.clip_text:
			if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
				out.append("row text cut off: %s" % text)
			continue
		# A wrapping row: no single word may be wider than the row, or it breaks inside the word.
		for word: String in text.split(" ", false):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
				out.append("word broken in a row: %s" % text)
				break
	if shown < mini(3, rows.size()):
		out.append("fewer than three rows in view")
	return out
