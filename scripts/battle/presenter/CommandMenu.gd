class_name CommandMenu
extends PanelContainer
## Bottom command panel: the moves as a one-column list (element symbol, name, Energy cost on the
## right) and a row with Swap / Item / Bond / Leave. Deliberately not a 2x2 move grid.
## Holding a move for LONG_PRESS seconds opens its info card (move_info); a tap closes it.

signal chosen(kind: BattleAction.Kind, index: int)

const MOVE_BUTTON_HEIGHT: int = 13
## Room on the left of a move row for its element symbol.
const ICON_PAD: int = 11
const SMALL_BUTTON_HEIGHT: int = 16
## Fixed height so the field above never jumps when the buttons hide.
const PANEL_HEIGHT: int = Spirling.MAX_MOVES * MOVE_BUTTON_HEIGHT + (Spirling.MAX_MOVES - 1) + SMALL_BUTTON_HEIGHT + 2 + 6

var _content: VBoxContainer
## Info card over the panel (long press on a move).
var _info_panel: PanelContainer
var _info_label: Label
var _hold := Timer.new()
var _held_index: int = -1
## Set when a long press opened the card, so the release does not also pick the move.
var _long_fired: bool = false
var _shown_moves: Array[MoveData] = []
## The battle the menu was last filled from (for the live info lines, item 578).
var _model: BattleModel

const LONG_PRESS: float = 0.45

var _move_buttons: Array[Button] = []
## Element symbol at the left of each move row.
var _move_icons: Array[TextureRect] = []
## Energy cost and matchup, right-aligned in each move row.
var _move_costs: Array[Label] = []
var _swap: Button
var _item: Button
var _bond: Button
var _run: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.ACCENT))
	custom_minimum_size = Vector2(0, PANEL_HEIGHT)
	var v := VBoxContainer.new()
	_content = v
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 1)
	v.add_child(grid)
	for i: int in Spirling.MAX_MOVES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, MOVE_BUTTON_HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Juice.press_feedback(b)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBox = b.get_theme_stylebox(state)
			if sb != null:
				sb = sb.duplicate()
				sb.content_margin_left = ICON_PAD
				b.add_theme_stylebox_override(state, sb)
		var idx: int = i
		b.pressed.connect(func() -> void:
			if _long_fired:
				_long_fired = false
				return
			_hold.stop()
			var el: int = _shown_moves[idx].element if idx < _shown_moves.size() else -1
			Sound.sfx("confirm", 0.0, Sound.art_pick_pitch(el))
			chosen.emit(BattleAction.Kind.MOVE, idx))
		b.button_down.connect(func() -> void:
			_held_index = idx
			_long_fired = false
			_hold.start(LONG_PRESS))
		b.button_up.connect(func() -> void:
			_hold.stop())
		grid.add_child(b)
		_move_buttons.append(b)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(2, (MOVE_BUTTON_HEIGHT - ElementIcons.SIZE) / 2)
		b.add_child(icon)
		_move_icons.append(icon)
		var cost := Label.new()
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cost.offset_right = -3
		b.add_child(cost)
		_move_costs.append(cost)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	_swap = _small(row, "Swap", BattleAction.Kind.SWAP)
	_item = _small(row, "Item", BattleAction.Kind.ITEM)
	_bond = _small(row, "Bond", BattleAction.Kind.BOND)
	_run = _small(row, "Leave", BattleAction.Kind.RUN)
	_hold.one_shot = true
	_hold.timeout.connect(_on_hold)
	add_child(_hold)
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.ACCENT))
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.visible = false
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_panel.add_child(_info_label)
	_info_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if TapInput.is_release(ev):
			close_info())
	add_child(_info_panel)

func _on_hold() -> void:
	if _held_index < 0 or _held_index >= _shown_moves.size():
		return
	_long_fired = true
	open_info(_held_index)

## Shows the info card for the move in row [param index].
func open_info(index: int) -> void:
	if index < 0 or index >= _shown_moves.size():
		return
	_info_label.text = move_info(_shown_moves[index], _model)
	_info_panel.visible = true
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
	var kind: String = Loc.t(MoveData.Kind.keys()[mv.kind].capitalize())
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
	b.custom_minimum_size = Vector2(0, SMALL_BUTTON_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Juice.press_feedback(b)
	b.pressed.connect(func() -> void:
		Sound.sfx("confirm")
		chosen.emit(kind, -1))
	parent.add_child(b)
	return b

## Short matchup tag for a known multiplier ("" when unknown or neutral).
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
static func move_line(mv: MoveData, energy: int, mult: float, multi: bool = false, pct: int = -1, cost: int = -1, wait: int = 0) -> String:
	var c: int = cost if cost >= 0 else mv.energy_cost
	if wait > 0:
		return "wait %d" % wait
	if energy < c:
		return "need %dE" % c
	if multi and mv.is_area():
		return "%dE all" % c
	# The preview already carries the matchup, so it replaces the x2/x.5 tag (short rows on 144 px).
	if pct >= 0 and mv.power > 0:
		return "%dE ~%d%%" % [c, pct]
	var tag: String = "" if mv.power <= 0 else matchup_tag(mult)
	return "%dE %s" % [c, tag] if not tag.is_empty() else "%dE" % c

## Damage preview: expected damage of [param mv] as a share (0-100) of [param foe]'s max HP,
## with traits, held items and the field. Mean roll, no keen hit, same estimate the AI uses.
static func damage_pct(model: BattleModel, me: Spirling, foe: Spirling, mv: MoveData) -> int:
	if not mv.is_damaging() or foe == null:
		return -1
	var hit: MoveData = BattleRules.resolve_move(mv, model.field)
	var dmg: float = DamageCalc.estimate(me, foe, hit) * BattleRules.damage_mult(me, foe, hit, model.field)
	return clampi(roundi(dmg * 100.0 / float(maxi(foe.max_hp(), 1))), 1, 100)

## Fills the buttons from the model's current legal actions for the Spirling in [param slot].
## The matchup tag shows only when one foe stands (with several, the target is picked after).
func refresh(model: BattleModel, slot: int = 0) -> void:
	_model = model
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
			b.text = mv.move_name
			var pct: int = damage_pct(model, me, foe, mv) if GameState.damage_preview and mult >= 0.0 else -1
			_move_costs[i].text = move_line(mv, me.energy, mult, multi, pct, me.move_cost(mv), me.cooldown_left(mv))
			_move_icons[i].texture = ElementIcons.outlined(mv.element)
			b.tooltip_text = "%s %s, power %d" % [Elements.element_name(mv.element), MoveData.Kind.keys()[mv.kind].capitalize(), mv.power]
			b.disabled = not me.can_afford(mv) or model.move_locked(mv)
		else:
			b.text = "-"
			_move_costs[i].text = ""
			_move_icons[i].texture = null
			b.disabled = true
	var kinds: Array[int] = []
	for a: BattleAction in model.legal_actions(BattleModel.Side.PLAYER, slot):
		kinds.append(a.kind)
	_swap.disabled = not BattleAction.Kind.SWAP in kinds
	_item.disabled = not BattleAction.Kind.ITEM in kinds
	_bond.disabled = not BattleAction.Kind.BOND in kinds
	_run.disabled = not BattleAction.Kind.RUN in kinds
	# A Trial can be restarted at any time (item 708).
	_run.text = "Restart" if model.has_meta("puzzle_max") else "Leave"
	if model.has_meta("puzzle_max"):
		_run.disabled = false
	# "Rest" stands in for the moves when none is affordable.
	if not BattleAction.Kind.MOVE in kinds:
		_move_buttons[0].text = "Rest (+%d)" % int(model.rules.get("rest_energy", BattleModel.REST_ENERGY))
		_move_costs[0].text = ""
		_move_icons[0].texture = null
		_move_buttons[0].disabled = false
	for b: Button in _move_buttons + [_swap, _item, _bond, _run]:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break

func set_enabled(on: bool) -> void:
	_content.visible = on
	if not on:
		close_info()
