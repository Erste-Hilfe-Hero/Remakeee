class_name CommandMenu
extends PanelContainer
## Bottom command panel: the arts as a one-column list (element symbol, name, Energy cost on the
## right) and Swap / Item / Bond / Leave. Deliberately not a 2x2 art grid.
## Holding an art for LONG_PRESS seconds opens its info card (move_info); a tap closes it.
##
## The look follows the era on screen (EraBattleHud "menu", docs/ERA_FEEL_HUD.md): Era I a plain
## text list with a cursor and the four commands as words in two rows; Era II framed buttons
## with colour stripes; Era III element-coloured art buttons with a slanted chip; Era IV large
## touch buttons with the element's name and a matchup word, and a button that uses the last
## item again; Era V the same, coming in one after another, with a richer info card.

signal chosen(kind: BattleAction.Kind, index: int)

const MOVE_BUTTON_HEIGHT: int = 13
## Room on the left of a move row for its element symbol.
const ICON_PAD: int = 11
const SMALL_BUTTON_HEIGHT: int = 16
## Fixed height so the field above never jumps when the buttons hide (the Era II panel; each
## era's own height is EraBattleHud.menu_height).
const PANEL_HEIGHT: int = Spirling.MAX_MOVES * MOVE_BUTTON_HEIGHT + (Spirling.MAX_MOVES - 1) + SMALL_BUTTON_HEIGHT + 2 + 6
## Era I text menu: room for the cursor in front of a row.
const CURSOR_PAD: int = 6
## chosen(ITEM, SHORTCUT) asks for the last item again; chosen(ITEM, -1) opens the list.
const SHORTCUT: int = 0

var _content: VBoxContainer
## Info card over the panel (long press on a move).
var _info_panel: PanelContainer
var _info_label: Label
## Era V: the name of the art on a band in its element's colour.
var _info_head: Label
var _hold := Timer.new()
var _held_index: int = -1
## Set when a long press opened the card, so the release does not also pick the move.
var _long_fired: bool = false
var _shown_moves: Array[MoveData] = []
## The battle the menu was last filled from (for the live info lines, item 578).
var _model: BattleModel
var _slot: int = 0
## Row to focus first on the next refresh: the art this Spirling used last (item 603), -1 none.
var prefer_row: int = -1
## True while a later Spirling of a formation chooses, so Back can take the order before back.
var undo_ok: bool = false

func request_undo() -> void:
	if not ready_for_input():
		return
	Sound.sfx("cancel")
	chosen.emit(BattleAction.Kind.RUN, BattleComfort.UNDO)

const LONG_PRESS: float = 0.45

## Era whose look the panel was built in, and its menu style (text, buttons, typed, touch).
var era: int = 1
var mode: String = "buttons"
var _move_buttons: Array[Button] = []
## Element symbol at the left of each move row.
var _move_icons: Array[TextureRect] = []
var _move_stripes: Array[ColorRect] = []
## Energy cost and matchup, right-aligned in each move row.
var _move_costs: Array[Label] = []
## Era IV on: the matchup word under the cost ("Strong", "Weak", "No effect").
var _move_hints: Array[Label] = []
## Colour of each row's cost and hint text while the row is not focused.
var _row_colors: Array[Color] = []
## Element of each row (-1 none), for the slanted chip of the element-coloured buttons.
var _row_elements: Array[int] = []
var _swap: Button
var _item: Button
var _bond: Button
var _run: Button
## Era IV on: uses the last item again (EraBattleHud.last_item).
var _shortcut: Button
## Era IV/V (commands "column"): the commands and the shortcut beside the arts.
var _column: VBoxContainer

func _ready() -> void:
	era = EraManager.active_era()
	var e: Dictionary = EraBattleHud.for_era(era)
	mode = str(e.get("menu", "buttons"))
	add_theme_stylebox_override("panel", EraBattleHud.frame_style(era, panel_bg(era)))
	custom_minimum_size = Vector2(0, EraBattleHud.menu_height(era))
	var art_h: int = int(e.get("art_h", MOVE_BUTTON_HEIGHT))
	var v := VBoxContainer.new()
	_content = v
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 1)
	# Era IV/V: the commands stand in a column beside the arts, so the field gets taller.
	if str(e.get("commands", "row")) == "column":
		var split := HBoxContainer.new()
		split.add_theme_constant_override("separation", 2)
		v.add_child(split)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_stretch_ratio = EraBattleHud.ART_SHARE
		split.add_child(grid)
		_column = VBoxContainer.new()
		_column.add_theme_constant_override("separation", 1)
		_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_column.size_flags_stretch_ratio = 1.0 - EraBattleHud.ART_SHARE
		split.add_child(_column)
	else:
		v.add_child(grid)
	for i: int in Spirling.MAX_MOVES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, art_h)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Juice.press_feedback(b)
		_style_row(b, _row_left())
		var idx: int = i
		b.pressed.connect(func() -> void:
			if _long_fired:
				_long_fired = false
				return
			_hold.stop()
			if not ready_for_input():
				return
			var el: int = _shown_moves[idx].element if idx < _shown_moves.size() else -1
			Sound.sfx("confirm", 0.0, Sound.art_pick_pitch(el))
			chosen.emit(BattleAction.Kind.MOVE, idx))
		b.button_down.connect(func() -> void:
			_held_index = idx
			_long_fired = false
			_hold.start(LONG_PRESS))
		b.button_up.connect(func() -> void:
			_hold.stop())
		b.draw.connect(_draw_row.bind(b, idx))
		for sig: Signal in [b.focus_entered, b.focus_exited, b.button_down, b.button_up]:
			sig.connect(_tint_row.bind(idx))
		grid.add_child(b)
		_move_buttons.append(b)
		_row_colors.append(UITheme.INK)
		_row_elements.append(-1)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(2 + (CURSOR_PAD if mode == "text" else 0), (art_h - ElementIcons.SIZE - 2) / 2)
		b.add_child(icon)
		_move_icons.append(icon)
		_move_stripes.append(_stripe(b))
		var two_lines: bool = bool(e.get("art_detail", false))
		var cost := Label.new()
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost.vertical_alignment = VERTICAL_ALIGNMENT_TOP if two_lines else VERTICAL_ALIGNMENT_CENTER
		cost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cost.offset_right = -3
		cost.offset_top = 2 if two_lines else 0
		b.add_child(cost)
		_move_costs.append(cost)
		var hint := Label.new()
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hint.offset_right = -3
		hint.offset_bottom = -1
		hint.visible = two_lines
		b.add_child(hint)
		_move_hints.append(hint)
	var row: Container
	if _column != null:
		row = _column
	elif str(e.get("commands", "row")) == "grid":
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 2)
		g.add_theme_constant_override("v_separation", 1)
		row = g
	else:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		row = h
	if row.get_parent() == null:
		v.add_child(row)
	_swap = _small(row, "Swap", BattleAction.Kind.SWAP)
	_item = _small(row, "Item", BattleAction.Kind.ITEM)
	_bond = _small(row, "Bond", BattleAction.Kind.BOND)
	_run = _small(row, "Leave", BattleAction.Kind.RUN)
	if bool(e.get("item_shortcut", false)):
		_shortcut = Button.new()
		_shortcut.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_shortcut.custom_minimum_size = Vector2(0, EraBattleHud.shortcut_height(era))
		_shortcut.clip_text = true
		_shortcut.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Juice.press_feedback(_shortcut)
		_shortcut.pressed.connect(func() -> void:
			if not ready_for_input():
				return
			Sound.sfx("confirm")
			chosen.emit(BattleAction.Kind.ITEM, SHORTCUT))
		if _column != null:
			_column.add_child(_shortcut)
		else:
			v.add_child(_shortcut)
	_hold.one_shot = true
	_hold.timeout.connect(_on_hold)
	add_child(_hold)
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", EraBattleHud.frame_style(era, panel_bg(era)))
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.visible = false
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(card)
	_info_head = Label.new()
	_info_head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info_head.visible = false
	card.add_child(_info_head)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(_info_label)
	_info_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if TapInput.is_release(ev):
			close_info())
	add_child(_info_panel)
	apply_size()

## Big buttons (KAMPF_PLAN items 623, 896): every art row and command grows to BattleComfort.art_h /
## command_h,
## the panel with them. Called again when the setting changes in the battle's More list.
func apply_size() -> void:
	custom_minimum_size = Vector2(0, BattleComfort.menu_height(era))
	for b: Button in _move_buttons:
		b.custom_minimum_size.y = BattleComfort.art_h(era)
	for b: Button in [_swap, _item, _bond, _run]:
		if b != null:
			b.custom_minimum_size.y = BattleComfort.command_h(era)

## Fill of the command panel: plain paper in Era I, the era's light colour washed into paper
## later (the shared accent once the menu skin frames the panel).
static func panel_bg(p_era: int) -> Color:
	if EraBattleHud.skin_api() or UITheme.high_contrast:
		return UITheme.ACCENT
	if p_era <= 1:
		return UITheme.BG
	return (EraBattleHud.colours(p_era).light as Color).lerp(UITheme.BG, 0.55)

## Room on the left of an art row: the symbol, plus the cursor (text menu) or the chip's slant.
func _row_left() -> int:
	return ICON_PAD + (CURSOR_PAD if mode == "text" else int(EraBattleHud.num(era, "art_slant")))

## Styles of a row button: [param left] pixels of room for the cursor, chip or symbol. The
## text menu (Era I) has no button boxes at all. In every era the row in focus keeps its own
## look and dark text, and _draw_row marks it (a cursor, or an ink frame), so the cost and the
## matchup colour stay readable on it and the mark survives the 4-ink filter.
func _style_row(b: Button, left: int) -> void:
	_plain_focus(b)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox
		if mode == "text":
			sb = StyleBoxEmpty.new()
			sb.set_content_margin_all(1)
		else:
			# From the shared theme, not from the button: a button outside the tree only knows
			# the engine's grey default boxes.
			sb = UITheme.get_theme().get_stylebox("normal" if state == "hover" else state, "Button").duplicate()
		sb.content_margin_left = left
		b.add_theme_stylebox_override(state, sb)

## No dark focus box and no light focus text on [param b]; _draw_row draws the focus mark.
func _plain_focus(b: Button) -> void:
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key: String in ["font_hover_color", "font_focus_color"] + (["font_pressed_color", "font_hover_pressed_color"] if mode == "text" else []):
		b.add_theme_color_override(key, UITheme.INK)

## Cost and hint text in the row's matchup colour (paper while the row is pressed dark).
func _tint_row(i: int) -> void:
	var b: Button = _move_buttons[i]
	var col: Color = UITheme.BG if mode != "text" and b.is_pressed() and not b.disabled else _row_colors[i]
	if not b.is_pressed() and EraBattleHud.flag(era, "art_fill") and _row_elements[i] >= 0 and UITheme.contrast(col, EraBattleHud.art_fill(_row_elements[i])) < 4.5:
		# On an element-coloured row a matchup colour that fades into the fill turns to ink.
		col = UITheme.INK
	_move_costs[i].add_theme_color_override("font_color", col)
	_move_hints[i].add_theme_color_override("font_color", col)
	b.queue_redraw()

## Drawn over a row button: the slanted element chip of the element-coloured buttons (Era III
## on) and the focus mark: the cursor of the text menu, an ink frame in the button eras.
func _draw_row(b: Button, i: int) -> void:
	var focused: bool = b.has_focus() and not b.disabled
	_draw_kind(b, i)
	if mode == "text":
		if focused:
			var cy: float = floorf(b.size.y / 2.0)
			b.draw_colored_polygon(PackedVector2Array([Vector2(1, cy - 3), Vector2(5, cy), Vector2(1, cy + 3)]), UITheme.INK)
		return
	var el: int = _row_elements[i] if i >= 0 and i < _row_elements.size() else -1
	if el >= 0 and EraBattleHud.flag(era, "art_fill"):
		var slant: float = EraBattleHud.num(era, "art_slant")
		var col: Color = UITheme.DISABLED if b.disabled else Elements.color(el)
		b.draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(ICON_PAD + slant, 1), Vector2(ICON_PAD, b.size.y - 1), Vector2(1, b.size.y - 1)]), col)
	if focused:
		b.draw_rect(Rect2(Vector2.ZERO, b.size), UITheme.INK, false, 1.0)
		b.draw_rect(Rect2(Vector2.ONE, b.size - Vector2(2, 2)), UITheme.INK, false, 1.0)

## The art's kind symbol (BattleHelp.KIND_ICONS, item 145) just left of its cost text.
func _draw_kind(b: Button, i: int) -> void:
	if i < 0 or i >= _shown_moves.size() or i >= _move_costs.size() or _move_costs[i].text.is_empty():
		return
	var cost: Label = _move_costs[i]
	var fs: int = cost.get_theme_font_size("font_size")
	var w: float = cost.get_theme_font("font").get_string_size(cost.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var size: int = BattleHelp.KIND_ICON_SIZE
	var top: bool = cost.vertical_alignment == VERTICAL_ALIGNMENT_TOP
	var y: float = cost.offset_top + floorf((fs - size) / 2.0) + 1.0 if top else floorf((b.size.y - size) / 2.0)
	var ink: Color = b.get_theme_color("font_disabled_color" if b.disabled else "font_color", "Button")
	BattleHelp.draw_kind_icon(b, _shown_moves[i].kind, Vector2(b.size.x + cost.offset_right - w - size - 3.0, y), ink)

## Thin colour stripe on the button's left edge (era colour code); transparent in Era I.
func _stripe(b: Button) -> ColorRect:
	var r := ColorRect.new()
	r.name = "Stripe"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.TRANSPARENT
	r.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	r.offset_right = float(HpBarStyle.cfg().get("command_stripe", 2))
	b.add_child(r)
	return r

func _on_hold() -> void:
	if _held_index < 0 or _held_index >= _shown_moves.size():
		return
	_long_fired = true
	open_info(_held_index)

## Shows the info card for the move in row [param index]. Era V sets the art's name on a band
## in its element's colour and lets the card rise into place (not under reduced motion).
func open_info(index: int) -> void:
	if index < 0 or index >= _shown_moves.size():
		return
	var mv: MoveData = _shown_moves[index]
	var text: String = move_info(mv, _model)
	# Live lines (items 571, 572): likely turn order and the Energy left, above the close hint.
	var live: Array[String] = BattleInfo.card_lines(_model, _slot, mv)
	if not live.is_empty():
		var parts: PackedStringArray = text.split("\n")
		var close: String = parts[parts.size() - 1]
		parts.remove_at(parts.size() - 1)
		text = "\n".join(parts) + "\n" + "\n".join(live) + "\n" + close
	var rich: bool = EraBattleHud.text(era, "info_card", "plain") == "rich"
	_info_head.visible = rich
	if rich:
		var lines: PackedStringArray = text.split("\n")
		_info_head.text = lines[0]
		var band := StyleBoxFlat.new()
		band.bg_color = EraBattleHud.art_fill(mv.element)
		band.border_color = UITheme.INK
		band.border_width_bottom = 1
		band.set_content_margin_all(2)
		_info_head.add_theme_stylebox_override("normal", band)
		lines.remove_at(0)
		text = "\n".join(lines)
	_info_label.text = text
	_info_panel.visible = true
	if rich and not Juice.reduced():
		_info_panel.modulate.a = 0.0
		Juice.tween(_info_panel, "modulate:a", 1.0, "open")
	Sound.sfx("confirm")

func close_info() -> void:
	_info_panel.visible = false

func is_info_open() -> bool:
	return _info_panel.visible

## Info card text for [param mv]: element, kind, power, accuracy, Energy and what its effects do.
## With [param model] a field_element art names the element it takes right now and a delayed_hit
## art the turn it would land (item 578).
static func move_info(mv: MoveData, model: BattleModel = null) -> String:
	var lines: Array[String] = [mv.move_name]
	# The kind's symbol (item 597): ! physical, * focus, ~ status, as in the rules page.
	var kind: String = BattleHelp.kind_mark(mv.kind) + " " + Loc.t(MoveData.Kind.keys()[mv.kind].capitalize())
	if mv.is_damaging():
		lines.append(Loc.t("%s, %s, power %d") % [Elements.element_name(mv.element), kind, mv.power])
	else:
		lines.append(Loc.t("%s, %s") % [Elements.element_name(mv.element), kind])
	lines.append(Loc.t("Accuracy %d%%, %d Energy") % [roundi(mv.accuracy * 100.0), mv.energy_cost])
	if mv.priority > 0:
		lines.append(Loc.t("Acts before other arts."))
	if mv.is_area():
		lines.append(Loc.t("Reaches every foe."))
	if mv.overcharge:
		lines.append(Loc.t("Spends all leftover Energy for more power."))
	if mv.cooldown > 0:
		lines.append(Loc.t("Locked for %d turns after each use.") % mv.cooldown)
	if mv.ignore_daze:
		lines.append(Loc.t("Daze does not spoil its aim."))
	if mv.ignore_stages:
		lines.append(Loc.t("Ignores the foe's raised Guard and Focus."))
	for fx: Dictionary in mv.effects:
		var chance: float = float(fx.get("chance", 1.0))
		var line: String = ""
		match StringName(fx.get("id", "")):
			&"inflict_status":
				line = Loc.t("Inflicts %s.") % Loc.t(StatusRules.label(str(fx.get("status", ""))))
			&"stat_change":
				var stat: String = Loc.t(BattleEvent.STAT_NAMES.get(str(fx.get("stat", "")), ""))
				var amt: int = int(fx.get("amount", 1))
				if bool(fx.get("self", true)):
					line = (Loc.t("Raises its own %s by %d.") if amt > 0 else Loc.t("Lowers its own %s by %d.")) % [stat, absi(amt)]
					if int(fx.get("full_hp_amount", 0)) != 0:
						line += " " + Loc.t("By %d at full Vigor.") % absi(int(fx.full_hp_amount))
				else:
					line = (Loc.t("Raises the foe's %s by %d.") if amt > 0 else Loc.t("Lowers the foe's %s by %d.")) % [stat, absi(amt)]
			&"heal_self":
				line = Loc.t("Heals %d%% of its Vigor.") % roundi(float(fx.get("amount", 0.5)) * 100.0)
			&"drain":
				line = Loc.t("Heals from the damage it deals.")
			&"recoil":
				line = Loc.t("Hurts itself a little too.")
			&"energy_drain":
				line = Loc.t("Takes Energy from the foe.")
			&"set_field":
				var f: Dictionary = BattleRules.FIELDS.get(str(fx.get("field", "")), {})
				line = Loc.t("Lays %s for %d turns.") % [Loc.t(str(f.get("label", ""))), BattleRules.RESONANCE_TURNS]
			&"bonus_vs_status":
				var vs: String = str(fx.get("vs_status", ""))
				var mult: String = String.num(float(fx.get("vs_mult", 1.0)), 1)
				if vs == "*":
					line = Loc.t("x%s power if the foe has any status.") % mult
				elif vs == "stage_down":
					line = Loc.t("x%s power if the foe has a lowered stat.") % mult
				else:
					line = Loc.t("x%s power if the foe has %s.") % [mult, Loc.t(StatusRules.label(vs))]
			&"energy_tax":
				var turns: int = int(fx.get("amount", 0))
				line = Loc.t("The foe's arts cost %d more Energy for %d turns.") % [BattleRules.ENERGY_TAX_COST, turns if turns > 0 else BattleRules.ENERGY_TAX_TURNS]
			&"field_element":
				line = Loc.t("In a field it takes the field's element, power +%d.") % int(fx.get("power_bonus", BattleRules.FIELD_ELEMENT_POWER))
				if model != null and BattleRules.FIELDS.has(model.field):
					line += " " + Loc.t("Right now: %s.") % Elements.element_name(BattleRules.resolve_move(mv, model.field).element)
			&"energy_burn":
				line = Loc.t("Burns away %d of the foe's Energy.") % int(fx.get("amount", 1))
			&"heal_block":
				var hb: int = int(fx.get("amount", 0))
				line = Loc.t("The foe can't heal for %d turns.") % (hb if hb > 0 else BattleRules.HEAL_BLOCK_TURNS)
			&"cure_target":
				var ct: String = str(fx.get("status", ""))
				line = Loc.t("Ends the foe's %s.") % Loc.t(StatusRules.label(ct)) if not ct.is_empty() else Loc.t("Ends the foe's status.")
			&"stage_steal":
				line = Loc.t("Steals one raised stage from the foe.")
			&"stage_copy":
				line = Loc.t("Copies every stage of the foe onto itself.")
			&"stage_swap":
				line = Loc.t("Trades all stages with the foe.")
			&"status_veil":
				var sv: int = int(fx.get("amount", 0))
				line = Loc.t("No foe status takes hold on its side for %d turns.") % (sv if sv > 0 else BattleRules.STATUS_VEIL_TURNS)
			&"energy_gain":
				line = Loc.t("Gains %d Energy.") % int(fx.get("amount", 1))
			&"energy_lock":
				line = Loc.t("The foe gains no Energy for %d turns.") % maxi(1, int(fx.get("amount", 1)))
			&"energy_give":
				line = Loc.t("Hands up to %d of its Energy to the ally beside it.") % maxi(1, int(fx.get("amount", 1)))
			&"energy_swap":
				line = Loc.t("Trades its Energy with the foe's.")
			# Multi-battle support arts (KAMPF_PLAN_1000, Mehrfachkämpfe).
			&"heal_team":
				line = Loc.t("Heals it and every ally beside it by %d%% of their Vigor.") % roundi(float(fx.get("amount", 0.2)) * 100.0)
			&"heal_ally":
				line = Loc.t("Heals the most hurt ally beside it by %d%% of its Vigor.") % roundi(float(fx.get("amount", 0.33)) * 100.0)
			&"team_guard":
				line = Loc.t("Its side takes less damage for %d turns.") % MultiRules.support_turns("team_guard")
			&"decoy":
				line = Loc.t("Draws the foes' aimed arts for %d turns.") % MultiRules.support_turns("decoy")
			&"cover":
				line = Loc.t("Takes the aimed hits meant for its most hurt ally for %d turns.") % MultiRules.support_turns("cover")
			&"stage_reset":
				line = Loc.t("Sets every stage on both sides back to 0.")
			&"cure_team":
				line = Loc.t("Cures the status of its whole team.")
			&"self_cost":
				line = Loc.t("Costs %d%% of its own Vigor, never the last point.") % roundi(float(fx.get("amount", 0.25)) * 100.0)
			&"cure_self":
				line = Loc.t("Cures its own status.")
			&"status_shift":
				line = Loc.t("Hands its own status to the foe.")
			&"clear_snares":
				line = Loc.t("Blows the snares off its own side.")
			&"delayed_hit":
				line = Loc.t("Lands %d turns later on whoever stands there.") % int(fx.get("turns", 2))
				if model != null:
					line += " " + Loc.t("Used now, it lands on turn %d.") % (model.turn + 1 + int(fx.get("turns", 2)))
			&"mend":
				line = Loc.t("Then mends a little at the end of the next %d turns.") % int(fx.get("turns", BattleRules.MEND_TURNS))
			&"field_extend":
				var fe: int = int(fx.get("amount", 0))
				line = Loc.t("Makes the Resonance field last %d turns longer.") % (fe if fe > 0 else BattleRules.FIELD_EXTEND_TURNS)
			&"side_snare":
				var sn: Dictionary = fx.get("snare", {})
				if float(sn.get("hp", 0.0)) > 0.0:
					line = Loc.t("Lays a snare: the next foe to step in loses %d%% Vigor.") % roundi(float(sn.hp) * 100.0)
				elif not str(sn.get("status", "")).is_empty():
					line = Loc.t("Lays a snare: the next foe to step in gets %s.") % Loc.t(StatusRules.label(str(sn.status)))
				else:
					line = Loc.t("Lays a snare that weakens the next foe to step in.")
			&"self_stage_after":
				var parts: Array[String] = []
				var st: Dictionary = fx.get("stages", {})
				for k: String in st:
					var n: int = int(st[k])
					var sname: String = Loc.t(BattleEvent.STAT_NAMES.get(k, ""))
					parts.append((Loc.t("Then raises its own %s by %d.") if n > 0 else Loc.t("Then lowers its own %s by %d.")) % [sname, absi(n)])
				line = " ".join(parts)
			_:
				# The KAMPF_PLAN_1000 arts describe themselves (TechniqueRules).
				line = TechniqueRules.info_line(fx)
		if line.is_empty():
			continue
		if chance < 1.0:
			line = Loc.t("%d%% chance: %s") % [roundi(chance * 100.0), line]
		lines.append(line)
	lines.append(Loc.t("(tap to close)"))
	return "\n".join(lines)

func _small(parent: Control, text: String, kind: BattleAction.Kind) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, EraBattleHud.num(era, "command_h", SMALL_BUTTON_HEIGHT))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Four buttons share 144 px; long German words ("Tauschen") pushed the whole battle screen
	# wider than the display (owner, 9 Nov: buttons not shown right). Clip instead of growing.
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	if mode == "text":
		# Era I: plain words in two rows of two, a cursor in front of the one in focus.
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_row(b, CURSOR_PAD + 1)
		b.draw.connect(_draw_row.bind(b, -1))
	else:
		# Width follows the drawn word, so "Binden" gets more room than "Item".
		_fit_command(b)
		# Thin side margins: four German words need every pixel of the 144.
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBox = UITheme.get_theme().get_stylebox("normal" if state == "hover" else state, "Button").duplicate()
			sb.content_margin_left = 1
			sb.content_margin_right = 1
			b.add_theme_stylebox_override(state, sb)
		_plain_focus(b)
		b.draw.connect(_draw_row.bind(b, -1))
	Juice.press_feedback(b)
	b.pressed.connect(func() -> void:
		if not ready_for_input():
			return
		Sound.sfx("confirm")
		chosen.emit(kind, -1))
	_stripe(b)
	parent.add_child(b)
	return b

## Short matchup tag for a known multiplier ("" when unknown or neutral).
## Effects that take Energy from the foe (KAMPF_PLAN item 46): such arts carry ENERGY_THIEF_MARK.
const ENERGY_THIEF_FX: Array[StringName] = [&"energy_drain", &"energy_burn", &"energy_swap", &"energy_lock"]
const ENERGY_THIEF_MARK: String = "<"

## Marks in front of an art's name: "^" acts first (item 595), "<" takes the foe's Energy (item 46).
static func art_marks(mv: MoveData) -> String:
	var out: String = "^" if mv.priority > 0 else ""
	for id: StringName in ENERGY_THIEF_FX:
		if mv.has_effect(id):
			return out + ENERGY_THIEF_MARK
	return out

static func matchup_tag(mult: float) -> String:
	if mult < 0.0 or is_equal_approx(mult, 1.0):
		return ""
	if mult >= 4.0:
		return "x4"
	if mult > 1.0:
		return "x2"
	if mult <= 0.25:
		return "x.25"
	return "x.5"

## Second line of a move button: cost, or what is missing, plus the known matchup.
## [param multi] marks sweeps ("all") in battles with several foes. [param pct] is the damage
## preview (expected share of the foe's max HP, -1 for none).
## [param cost] is what the move costs now (-1: its own cost; more under an Energy tax) and
## [param wait] the turns a cooldown still locks it.
## [param max_energy]: an art that costs more can never be paid in this battle (KAMPF_PLAN item 65).
## [param oc_mult]: an Overcharge art's power multiplier right now, shown when there is no preview (item 45).
## [param status_pct] (item 194) adds the art's status chance on the foe to the preview, as the
## status tag and the chance ("SCO30"), -1 for none.
static func move_line(mv: MoveData, energy: int, mult: float, multi: bool = false, pct: int = -1, cost: int = -1, wait: int = 0,
		max_energy: int = 99, oc_mult: float = 0.0, status_pct: int = -1, status: String = "") -> String:
	var c: int = cost if cost >= 0 else mv.energy_cost
	if wait > 0:
		return "wait %d" % wait
	if c > max_energy:
		return "never"
	if energy < c:
		return "need %dE" % c
	if oc_mult > 1.0 and pct < 0 and not (multi and mv.is_area()):
		return "%dE x%.1f" % [c, oc_mult]
	if multi and mv.is_area():
		return "%dE all" % c
	# The preview already carries the matchup, so it replaces the x2/x.5 tag (short rows on 144 px).
	if pct >= 0 and mv.power > 0:
		if status_pct > 0 and StatusRules.exists(status):
			return "%dE ~%d%% %s%d" % [c, pct, StatusRules.tag(status), status_pct]
		return "%dE ~%d%%" % [c, pct]
	var tag: String = "" if mv.power <= 0 else matchup_tag(mult)
	# A status art that can miss shows its hit chance (KAMPF_PLAN_1000 item 144).
	if mv.power <= 0 and mv.accuracy < 1.0:
		tag = "%d%%" % roundi(mv.accuracy * 100.0)
	return "%dE %s" % [c, tag] if not tag.is_empty() else "%dE" % c

## Damage preview: expected damage of [param mv] as a share (0-100) of [param foe]'s max HP,
## with traits, held items and the field. Mean roll, no keen hit, same estimate the AI uses.
static func damage_pct(model: BattleModel, me: Spirling, foe: Spirling, mv: MoveData) -> int:
	if not mv.is_damaging() or foe == null:
		return -1
	var dmg: float = BattleRules.expected_damage(me, foe, mv, model.field)
	return clampi(roundi(dmg * 100.0 / float(maxi(foe.max_hp(), 1))), 1, 100)

## Power multiplier an Overcharge art [param mv] of [param me] would have if used now (the
## Energy left after its cost, plus the chain bonus); 0.0 for any other art (KAMPF_PLAN item 45).
static func overcharge_now(model: BattleModel, me: Spirling, mv: MoveData) -> float:
	if not mv.overcharge or me == null:
		return 0.0
	var chained: bool = model.turn > 0 and me.overcharge_turn == model.turn - 1
	return BattleRules.overcharge_mult(mini(me.energy - me.move_cost(mv), BattleRules.OVERCHARGE_MAX_EXTRA), chained)

## The status [param mv] may put on [param foe] and its chance in percent (item 194), or {} when
## it inflicts none or the status can't take hold now (one already sits there, a gift, field,
## rule or veil keeps it off).
static func status_chance(model: BattleModel, foe: Spirling, mv: MoveData) -> Dictionary:
	if foe == null:
		return {}
	for fx: Dictionary in mv.effects:
		if StringName(fx.get("id", "")) != &"inflict_status" or bool(fx.get("self", false)):
			continue
		var st: String = str(fx.get("status", ""))
		if not StatusRules.exists(st) or BattleRules.is_immune(foe, st) or BattleRules.field_blocks(model.field, st):
			return {}
		if not foe.status.is_empty() and StatusRules.combo(foe.status, st).is_empty():
			return {}
		var foe_side: int = BattleModel.Side.FOE
		if not model.status_block(foe_side, st, BattleModel.Side.PLAYER).is_empty():
			return {}
		var acc: float = 1.0 if mv.is_damaging() else mv.accuracy
		return {"status": st, "pct": clampi(roundi(float(fx.get("chance", 1.0)) * acc * 100.0), 1, 100)}
	return {}

## Fills the buttons from the model's current legal actions for the Spirling in [param slot].
## The matchup tag shows only when one foe stands (with several, the target is picked after).
func refresh(model: BattleModel, slot: int = 0) -> void:
	_model = model
	_slot = slot
	var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER, slot)
	var foes: Array[int] = model.standing_slots(BattleModel.Side.FOE)
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, foes[0]) if foes.size() == 1 else null
	var multi: bool = model.is_multi()
	close_info()
	_shown_moves = []
	for mv: MoveData in me.moves:
		_shown_moves.append(mv)
	for i: int in _move_buttons.size():
		var b: Button = _move_buttons[i]
		if i < me.moves.size():
			var mv: MoveData = me.moves[i]
			var mult: float = GameState.known_multiplier(mv.element, foe) if foe != null else -1.0
			# An art that acts first carries an arrow (item 595).
			b.text = BattleComfort.fav_mark(me, mv) + art_marks(mv) + mv.move_name
			var pct: int = damage_pct(model, me, foe, mv) if GameState.damage_preview and ShopEffects.owns_setting("damage_preview") and mult >= 0.0 else -1
			var oc: float = overcharge_now(model, me, mv)
			if pct > 0 and oc > 1.0:
				pct = mini(100, roundi(pct * oc))
			var sc: Dictionary = status_chance(model, foe, mv) if pct >= 0 else {}
			_move_costs[i].text = move_line(mv, me.energy, mult, multi, pct, me.move_cost(mv), me.cooldown_left(mv),
				model.max_energy_of(BattleModel.Side.PLAYER), oc, int(sc.get("pct", -1)), str(sc.get("status", "")))
			var filled: bool = EraBattleHud.flag(era, "art_fill")
			_row_elements[i] = mv.element
			# On the element chip (Era III on) the symbol stands in ink on paper, else in its colour.
			_move_icons[i].texture = ElementIcons.outlined(mv.element, UITheme.INK if filled else BattleUiStyle.badge_color(era, mv.element))
			_move_stripes[i].color = BattleUiStyle.badge_color(era, mv.element) if BattleUiStyle.colour_on(era) and not filled else Color.TRANSPARENT
			var shown_mult: float = mult if mv.power > 0 else -1.0
			_move_costs[i].text = BattleUiStyle.matchup_mark(shown_mult, GameState.color_blind) + _move_costs[i].text
			_row_colors[i] = BattleUiStyle.matchup_color(era, shown_mult)
			if EraBattleHud.flag(era, "art_detail"):
				# Era IV on: the element's name under the art's name, the matchup word under the cost.
				b.text = BattleComfort.fav_mark(me, mv) + art_marks(mv) + Loc.t(mv.move_name) + "\n" + Loc.t(Elements.element_name(mv.element))
				_move_hints[i].text = Loc.t(EraBattleHud.effect_hint(era, shown_mult))
			_style_row(b, _row_left())
			if filled:
				_fill_row(b, mv.element)
			b.tooltip_text = "%s %s, power %d" % [Elements.element_name(mv.element), MoveData.Kind.keys()[mv.kind].capitalize(), mv.power]
			# Screen readers read the whole info card, no long press needed.
			b.accessibility_description = move_info(mv, model)
			b.disabled = not me.can_afford(mv) or model.move_locked(mv)
		else:
			b.text = "-"
			b.accessibility_description = ""
			_move_costs[i].text = ""
			_move_hints[i].text = ""
			_move_icons[i].texture = null
			_move_stripes[i].color = Color.TRANSPARENT
			_row_elements[i] = -1
			_row_colors[i] = UITheme.INK
			_style_row(b, _row_left())
			b.disabled = true
		_tint_row(i)
	var kinds: Array[int] = []
	for a: BattleAction in model.legal_actions(BattleModel.Side.PLAYER, slot):
		kinds.append(a.kind)
	for pair: Array in [[_swap, "swap"], [_item, "item"], [_bond, "bond"], [_run, "run"]]:
		var sb: ColorRect = (pair[0] as Button).get_node_or_null("Stripe")
		if sb != null:
			sb.color = BattleUiStyle.command_color(era, pair[1])
	# An ally in another slot to trade places with also opens Swap (item 366).
	_swap.disabled = not BattleAction.Kind.SWAP in kinds and MultiRules.shift_targets(model, BattleModel.Side.PLAYER, slot).is_empty()
	# A keepsake from the bag to put on also opens Item (KAMPF_PLAN_1000 298).
	_item.disabled = not BattleAction.Kind.ITEM in kinds and KeepsakeKit.swap_ids(model, slot).is_empty()
	# Against another Wayfarer the Bond button offers the Ink Oath instead (once per battle).
	_bond.text = "Bond" if model.is_wild else "Oath"
	_fit_command(_bond)
	_bond.disabled = not (BattleAction.Kind.BOND in kinds or model.can_oath(BattleModel.Side.PLAYER, slot))
	_run.disabled = not BattleAction.Kind.RUN in kinds
	# A Trial can be restarted at any time (item 708).
	_run.text = "Restart" if model.has_meta("puzzle_max") else "Leave"
	_fit_command(_run)
	if model.has_meta("puzzle_max"):
		_run.disabled = false
	# "Rest" stands in for the moves when none is affordable.
	if not BattleAction.Kind.MOVE in kinds:
		_move_buttons[0].text = "Rest (+%d)" % model.rest_gain()
		_move_costs[0].text = ""
		_move_hints[0].text = ""
		_move_icons[0].texture = null
		_row_elements[0] = -1
		_row_colors[0] = UITheme.INK
		_style_row(_move_buttons[0], _row_left())
		_move_buttons[0].disabled = false
		_tint_row(0)
	_refresh_shortcut(model, BattleAction.Kind.ITEM in kinds)
	var usable: Array[bool] = []
	for b: Button in _move_buttons:
		usable.append(not b.disabled)
	var row: int = BattleInfo.focus_row(usable, prefer_row)
	if row >= 0:
		_move_buttons[row].grab_focus.call_deferred()
		return
	for b: Button in [_swap, _item, _bond, _run]:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break

## Keys 1 to 4 pick the art in that row while the menu is open (item 613).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not _content.visible or is_info_open():
		return
	var row: int = BattleInfo.art_key(k.keycode)
	if row < 0 or row >= _move_buttons.size() or _move_buttons[row].disabled:
		return
	get_viewport().set_input_as_handled()
	_move_buttons[row].pressed.emit()

## Long presses are optional (Kampf-Plan, Barrierefreiheit): on a keyboard I or F1, on a gamepad
## the top face button opens or closes the info card of the focused art.
static func is_info_key(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		return (event as InputEventKey).keycode in [KEY_I, KEY_F1]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	return false

## Toggles the info card of the art in row [param index].
func toggle_info(index: int) -> void:
	if is_info_open():
		close_info()
	else:
		open_info(index)

func _unhandled_input(event: InputEvent) -> void:
	# Back takes the order of the Spirling before back (KAMPF_PLAN item 604).
	if undo_ok and is_visible_in_tree() and _content.visible and not is_info_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_undo()
		return
	if not is_visible_in_tree() or not _content.visible or not is_info_key(event):
		return
	var index: int = _move_buttons.find(get_viewport().gui_get_focus_owner())
	if index < 0 and not is_info_open():
		return
	toggle_info(index)
	get_viewport().set_input_as_handled()

## A command's share of the row follows its word, so a longer word ("Schwur") gets more room.
func _fit_command(b: Button) -> void:
	if mode != "text":
		b.size_flags_stretch_ratio = EraBattleHud.font(era).get_string_size(Loc.t(b.text), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x + 8.0

## The item the shortcut would use: the last one used, while it is still in the bag, usable in
## battle and allowed again this battle; "" otherwise.
static func shortcut_item(model: BattleModel, last: String) -> String:
	if model == null or last.is_empty() or not bool(Database.item(last).get("battle", false)):
		return ""
	if model.bag_count(BattleModel.Side.PLAYER, last) <= 0 or not model.item_left_this_battle(BattleModel.Side.PLAYER, last):
		return ""
	return last

func _refresh_shortcut(model: BattleModel, items_ok: bool) -> void:
	if _shortcut == null:
		return
	var id: String = shortcut_item(model, EraBattleHud.last_item)
	if id.is_empty():
		_shortcut.text = Loc.t("Again: -")
	else:
		var item_name: String = Loc.t(str(Database.item(id).get("name", id)))
		var n: int = model.bag_count(BattleModel.Side.PLAYER, id)
		# In the narrow command column (Era IV/V) the item and its count stand alone.
		_shortcut.text = ("%s x%d" % [item_name, n]) if _column != null else Loc.t("Again: %s x%d") % [item_name, n]
	_shortcut.disabled = id.is_empty() or not items_ok

## Element-coloured row (Era III on): the element's colour washed toward paper, so ink text
## keeps its contrast; focus and press keep the theme's dark box.
func _fill_row(b: Button, element: int) -> void:
	var sb: StyleBoxFlat = UITheme.flat_style(EraBattleHud.art_fill(element), UITheme.INK)
	# Two pixels of paper between the element chip and the art's name.
	sb.content_margin_left = _row_left() + 2
	sb.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", sb)

## When the menu last opened for an order (the tap guard of KAMPF_PLAN_1000 item 908).
var _shown_ms: int = -100000

## False while the player's tap guard still runs after the menu opened.
func ready_for_input() -> bool:
	return BattleCalm.input_ready(_shown_ms, Time.get_ticks_msec())

func set_enabled(on: bool) -> void:
	var was: bool = _content.visible
	if on:
		_shown_ms = Time.get_ticks_msec()
	_content.visible = on
	if not on:
		close_info()
	elif not was and EraBattleHud.flag(era, "menu_stagger"):
		# Era V: the rows come in one after another (all at once under reduced motion).
		var rows: Array = []
		rows.append_array(_move_buttons)
		rows.append_array([_swap, _item, _bond, _run])
		Juice.stagger(rows, 0.02)
