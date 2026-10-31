class_name CommandMenu
extends PanelContainer
## Bottom command panel: four move buttons (name + Energy cost) and Swap / Item / Bond / Run.

signal chosen(kind: BattleAction.Kind, index: int)

const MOVE_BUTTON_HEIGHT: int = 22
const SMALL_BUTTON_HEIGHT: int = 16
## Fixed height so the field above never jumps when the buttons hide.
const PANEL_HEIGHT: int = 2 * MOVE_BUTTON_HEIGHT + SMALL_BUTTON_HEIGHT + 2 * 2 + 6

var _content: VBoxContainer

var _move_buttons: Array[Button] = []
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
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	v.add_child(grid)
	for i: int in Spirling.MAX_MOVES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, MOVE_BUTTON_HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var idx: int = i
		b.pressed.connect(func() -> void: chosen.emit(BattleAction.Kind.MOVE, idx))
		grid.add_child(b)
		_move_buttons.append(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	_swap = _small(row, "Swap", BattleAction.Kind.SWAP)
	_item = _small(row, "Item", BattleAction.Kind.ITEM)
	_bond = _small(row, "Bond", BattleAction.Kind.BOND)
	_run = _small(row, "Run", BattleAction.Kind.RUN)

func _small(parent: Control, text: String, kind: BattleAction.Kind) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, SMALL_BUTTON_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: chosen.emit(kind, -1))
	parent.add_child(b)
	return b

## Fills the buttons from the model's current legal actions.
func refresh(model: BattleModel) -> void:
	var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER)
	for i: int in _move_buttons.size():
		var b: Button = _move_buttons[i]
		if i < me.moves.size():
			var mv: MoveData = me.moves[i]
			b.text = "%s\n%d Energy" % [mv.move_name, mv.energy_cost]
			b.tooltip_text = "%s %s, power %d" % [Elements.element_name(mv.element), MoveData.Kind.keys()[mv.kind].capitalize(), mv.power]
			b.disabled = not me.can_afford(mv)
		else:
			b.text = "-"
			b.disabled = true
	var kinds: Array[int] = []
	for a: BattleAction in model.legal_actions(BattleModel.Side.PLAYER):
		kinds.append(a.kind)
	_swap.disabled = not BattleAction.Kind.SWAP in kinds
	_item.disabled = not BattleAction.Kind.ITEM in kinds
	_bond.disabled = not BattleAction.Kind.BOND in kinds
	_run.disabled = not BattleAction.Kind.RUN in kinds
	# "Rest" stands in for the moves when none is affordable.
	if not BattleAction.Kind.MOVE in kinds:
		_move_buttons[0].text = "Rest (+%d)" % BattleModel.REST_ENERGY
		_move_buttons[0].disabled = false
	for b: Button in _move_buttons + [_swap, _item, _bond, _run]:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break

func set_enabled(on: bool) -> void:
	_content.visible = on
