class_name CommandMenu
extends PanelContainer
## Bottom command panel: the moves as a one-column list (element symbol, name, Energy cost on the
## right) and a row with Swap / Item / Bond / Leave. Deliberately not a 2x2 move grid.

signal chosen(kind: BattleAction.Kind, index: int)

const MOVE_BUTTON_HEIGHT: int = 13
## Room on the left of a move row for its element symbol.
const ICON_PAD: int = 11
const SMALL_BUTTON_HEIGHT: int = 16
## Fixed height so the field above never jumps when the buttons hide.
const PANEL_HEIGHT: int = Spirling.MAX_MOVES * MOVE_BUTTON_HEIGHT + (Spirling.MAX_MOVES - 1) + SMALL_BUTTON_HEIGHT + 2 + 6

var _content: VBoxContainer

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
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBox = b.get_theme_stylebox(state)
			if sb != null:
				sb = sb.duplicate()
				sb.content_margin_left = ICON_PAD
				b.add_theme_stylebox_override(state, sb)
		var idx: int = i
		b.pressed.connect(func() -> void:
			Sound.sfx("confirm")
			chosen.emit(BattleAction.Kind.MOVE, idx))
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

func _small(parent: Control, text: String, kind: BattleAction.Kind) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, SMALL_BUTTON_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
static func move_line(mv: MoveData, energy: int, mult: float, multi: bool = false, pct: int = -1) -> String:
	if energy < mv.energy_cost:
		return "need %dE" % mv.energy_cost
	if multi and mv.is_area():
		return "%dE all" % mv.energy_cost
	# The preview already carries the matchup, so it replaces the x2/x.5 tag (short rows on 144 px).
	if pct >= 0 and mv.power > 0:
		return "%dE ~%d%%" % [mv.energy_cost, pct]
	var tag: String = "" if mv.power <= 0 else matchup_tag(mult)
	return "%dE %s" % [mv.energy_cost, tag] if not tag.is_empty() else "%dE" % mv.energy_cost

## Damage preview: expected damage of [param mv] as a share (0-100) of [param foe]'s max HP,
## with traits, held items and the field. Mean roll, no keen hit, same estimate the AI uses.
static func damage_pct(model: BattleModel, me: Spirling, foe: Spirling, mv: MoveData) -> int:
	if not mv.is_damaging() or foe == null:
		return -1
	var dmg: float = DamageCalc.estimate(me, foe, mv) * BattleRules.damage_mult(me, foe, mv, model.field)
	return clampi(roundi(dmg * 100.0 / float(maxi(foe.max_hp(), 1))), 1, 100)

## Fills the buttons from the model's current legal actions for the Spirling in [param slot].
## The matchup tag shows only when one foe stands (with several, the target is picked after).
func refresh(model: BattleModel, slot: int = 0) -> void:
	var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER, slot)
	var foes: Array[int] = model.standing_slots(BattleModel.Side.FOE)
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, foes[0]) if foes.size() == 1 else null
	var multi: bool = model.is_multi()
	for i: int in _move_buttons.size():
		var b: Button = _move_buttons[i]
		if i < me.moves.size():
			var mv: MoveData = me.moves[i]
			var mult: float = GameState.known_multiplier(mv.element, foe) if foe != null else -1.0
			b.text = mv.move_name
			var pct: int = damage_pct(model, me, foe, mv) if GameState.damage_preview and mult >= 0.0 else -1
			_move_costs[i].text = move_line(mv, me.energy, mult, multi, pct)
			_move_icons[i].texture = ElementIcons.outlined(mv.element)
			b.tooltip_text = "%s %s, power %d" % [Elements.element_name(mv.element), MoveData.Kind.keys()[mv.kind].capitalize(), mv.power]
			b.disabled = not me.can_afford(mv)
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
	# "Rest" stands in for the moves when none is affordable.
	if not BattleAction.Kind.MOVE in kinds:
		_move_buttons[0].text = "Rest (+%d)" % BattleModel.REST_ENERGY
		_move_costs[0].text = ""
		_move_icons[0].texture = null
		_move_buttons[0].disabled = false
	for b: Button in _move_buttons + [_swap, _item, _bond, _run]:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break

func set_enabled(on: bool) -> void:
	_content.visible = on
