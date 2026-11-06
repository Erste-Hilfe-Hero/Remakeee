class_name BattleScene
extends Control
## Battle presenter. Owns a BattleModel, asks the player for actions, and plays the model's
## events back in order (sprites, HP bars, Energy pips, text box). Holds no battle rules.
##
## Layout (original): foe strip along the top edge, foe sprite top-right, player sprite
## bottom-left, player strip just above the text box, commands at the bottom.
##
## Formation layout (story battles with several Spirlings per side, up to 4 against 4): every
## Spirling is drawn at half size (28 px, an exact 2:1 step so pixels stay crisp) in one of two
## ranks, foes along the upper bank and the player's side along the lower one, each with a small
## tag (HP bar, Energy ticks). One ledger strip at the top shows the details of the Spirling in
## focus. A map pin marks whose turn it is; single-target moves are aimed by tapping a foe.

signal battle_finished(outcome: BattleModel.Outcome, model: BattleModel)
signal _target_picked(slot: int)

const TEXT_BOX_HEIGHT: int = 44
const STRIP_HEIGHT: int = 22
const MARGIN: int = 4
## Pause before an auto-battle move, so the player can still tap Auto off.
const AUTO_DELAY: float = 0.35
const DEMO_SEED: int = 2024
## Lines kept for the battle log (shown newest last).
const LOG_KEEP: int = 14
## Formation layout: sprite size and the gap between neighbours in a rank.
const SLOT_SPRITE: int = 28
const SLOT_GAP: int = 6

var model: BattleModel
## Backdrop for where the battle started (field, lake, ridge, ember). Set before adding.
var backdrop: String = "field"
## How much darker the backdrop is drawn (0 = as is), for towers that sink deeper (plan 3268).
var backdrop_shade: float = 0.0
## Music for this fight ("battle" or "warden"); the overworld sets it before adding the scene.
var music_track: String = "battle"
## Set to true to quit the app when the battle ends (standalone demo).
var quit_on_finish: bool = false
## Standalone demo format when no model is set: "" (1v1), "boss" (4v1), "duel3" (3v3),
## "tag" (you and an ally vs 2) or "horde" (2 vs a wild swarm of 4).
var demo: String = ""
## Every player input, in order, for BattleReplay (item 14).
var inputs: Array = []
## Set to a recorded input list to watch a replay instead of playing.
var replay_inputs: Array = []
var _replaying: bool = false

var _field: Control
## Holds the backdrop and the sprites; Juice shakes this node, never the strips or menus.
var _shake_root: Control
## Element effects for arts, drawn above the sprites inside the shake root.
var _fx: ElementFx
var _backdrop: BattleBackdrop
var _foe_sprite: SpirlingSprite
var _player_sprite: SpirlingSprite
var _foe_strip: InfoStrip
var _player_strip: InfoStrip
var _text: TextBox
var _menu: CommandMenu
var _picker: ListPicker
var _bond_game: BondMinigame
## Echo call plan per wild Spirling (uid): a second try in this battle hears the same call.
var _bond_plans: Dictionary[String, Dictionary] = {}
var _ff_button: Button
var _auto_button: Button
var _goal_label: Label
var _rule_banner: RuleBanner
var _auto_ai := BattleAI.new(1)
var _log_button: Button
var _log_panel: PanelContainer
var _log_label: Label
## Formation layout state (empty in 1v1).
var _multi: bool = false
var _slot_sprites: Array[Array] = [[], []]
var _slot_strips: Array[Array] = [[], []]
var _pin: TargetPin
var _back_button: Button
var _target_buttons: Array[Button] = []
## Plain-text lines of what happened so far (item 11: re-read the last turns).
var log_lines: Array[String] = []
## Element of the player's last move, so the hit that follows teaches the matchup.
var _last_player_element: int = -1
## Element of the last move each side used, for the hit sound.
var _last_element: Array[int] = [-1, -1]
## HP ratio at or below which the pinch music takes over (item 69).
const PINCH_RATIO: float = 0.25

## Gamepad / keyboard shortcuts for the speed and auto buttons (item 63).
func _unhandled_input(event: InputEvent) -> void:
	if _ff_button == null:
		return
	if event.is_action_pressed(GameState.SPEED_ACTION) and _ff_button.visible:
		get_viewport().set_input_as_handled()
		_ff_button.pressed.emit()
	elif event.is_action_pressed(GameState.AUTO_ACTION) and _auto_button.visible:
		get_viewport().set_input_as_handled()
		_auto_button.button_pressed = not _auto_button.button_pressed

func _enter_tree() -> void:
	Juice.in_battle = true

func _exit_tree() -> void:
	Juice.in_battle = false
	Juice.set_shake_root(null)

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if model == null:
		model = _demo_model()
		quit_on_finish = false
	_multi = model.is_multi()
	_run.call_deferred()

## Call before adding to the tree.
## Shows "T3 ✓", "T3 ✗" or "T3" for the bonus goal of this battle (item 762).
func _refresh_goal() -> void:
	if _goal_label == null or not model.has_meta("goal_tracker") or not GameState.bonus_goals:
		return
	var t: BattleGoals.Tracker = model.get_meta("goal_tracker")
	var mark: String = ["✗", "", "✓"][t.status() + 1]
	_goal_label.text = (Loc.t("T%d") % (t.turns() + 1)) + ("" if mark.is_empty() else " " + mark)
	_goal_label.visible = true

func setup(p_model: BattleModel) -> void:
	model = p_model

# --- Layout -------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	SafeArea.apply(col)
	_field = Control.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.clip_contents = true
	_field.resized.connect(_layout_field)
	col.add_child(_field)
	_text = TextBox.new()
	_text.custom_minimum_size = Vector2(0, TEXT_BOX_HEIGHT)
	col.add_child(_text)
	_menu = CommandMenu.new()
	col.add_child(_menu)

	_shake_root = Control.new()
	_shake_root.name = "shake_root"
	_shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.add_child(_shake_root)
	Juice.set_shake_root(_shake_root)

	_backdrop = BattleBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shake_root.add_child(_backdrop)

	_foe_sprite = SpirlingSprite.new()
	_player_sprite = SpirlingSprite.new()
	_foe_strip = InfoStrip.new()
	_player_strip = InfoStrip.new()
	_player_strip.show_numbers = true
	for n: Control in [_foe_sprite, _player_sprite]:
		_shake_root.add_child(n)
	_fx = ElementFx.new()
	_fx.name = "element_fx"
	_shake_root.add_child(_fx)
	for n: Control in [_foe_strip, _player_strip]:
		_field.add_child(n)
	_foe_sprite.visible = false
	_player_sprite.visible = false

	_ff_button = Button.new()
	_ff_button.focus_mode = Control.FOCUS_NONE
	_ff_button.pressed.connect(func() -> void:
		GameState.cycle_battle_speed()
		_apply_speed())
	_field.add_child(_ff_button)
	_auto_button = Button.new()
	_auto_button.text = "Auto"
	_auto_button.toggle_mode = true
	_auto_button.focus_mode = Control.FOCUS_NONE
	_auto_button.button_pressed = GameState.auto_battle
	_auto_button.toggled.connect(func(on: bool) -> void:
		GameState.auto_battle = on
		_apply_speed())
	_auto_button.visible = false
	_field.add_child(_auto_button)
	# Turn count with the bonus goal mark (plan area 2, item 762); only shown when a goal is on.
	_goal_label = Label.new()
	_goal_label.visible = false
	_goal_label.add_theme_font_size_override("font_size", 8)
	_field.add_child(_goal_label)
	_rule_banner = RuleBanner.new()
	_field.add_child(_rule_banner)
	_log_button = Button.new()
	_log_button.text = "Log"
	_log_button.focus_mode = Control.FOCUS_NONE
	_log_button.pressed.connect(_toggle_log)
	_field.add_child(_log_button)
	_pin = TargetPin.new()
	_field.add_child(_pin)
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.visible = false
	_back_button.pressed.connect(func() -> void: _target_picked.emit(-1))
	_field.add_child(_back_button)

	_bond_game = BondMinigame.new()
	_bond_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bond_game)
	_picker = ListPicker.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.offset_left = MARGIN * 2
	_picker.offset_right = -MARGIN * 2
	_picker.offset_top = MARGIN * 6
	_picker.offset_bottom = -MARGIN * 6
	add_child(_picker)
	_log_panel = PanelContainer.new()
	_log_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_panel.offset_left = MARGIN
	_log_panel.offset_right = -MARGIN
	_log_panel.offset_top = MARGIN
	_log_panel.offset_bottom = -MARGIN
	_log_panel.visible = false
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if TapInput.is_press(ev):
			_log_panel.visible = false)
	add_child(_log_panel)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log_panel.add_child(_log_label)
	_apply_speed()

func _layout_field() -> void:
	if _multi and not _slot_sprites[BattleModel.Side.FOE].is_empty():
		_layout_formation()
		return
	var w: float = _field.size.x
	var h: float = _field.size.y
	var sprite: float = float(EraManager.battle_sprite_size())
	# Chimora's own arrangement: foe on the upper left, the player's Spirling on the lower right,
	# info strips on the opposite sides (docs/legal/IP_PATENT_AUDIT.md, item 4).
	_foe_strip.size = Vector2(w * 0.55, STRIP_HEIGHT)
	_foe_strip.position = Vector2(w - _foe_strip.size.x - MARGIN, MARGIN)
	_ff_button.position = Vector2(MARGIN, MARGIN)
	_ff_button.size = Vector2(26, 12)
	_auto_button.position = Vector2(MARGIN, MARGIN + 14)
	_auto_button.size = Vector2(26, 12)
	_log_button.position = Vector2(MARGIN, MARGIN + 28)
	_log_button.size = Vector2(26, 12)
	_goal_label.position = Vector2(MARGIN, MARGIN + 42)
	_foe_sprite.position = Vector2(MARGIN * 2 + 28, MARGIN + STRIP_HEIGHT - 6)
	_foe_sprite.size = Vector2(sprite, sprite)
	_foe_sprite.mirrored = true
	_player_strip.size = Vector2(w - sprite - MARGIN * 5, STRIP_HEIGHT + 8)
	_player_strip.position = Vector2(MARGIN, h - _player_strip.size.y - MARGIN)
	_player_sprite.position = Vector2(w - sprite - MARGIN * 2, h - sprite - MARGIN * 2)
	_player_sprite.size = Vector2(sprite, sprite)
	_player_sprite.mirrored = true
	_backdrop.set_scene(backdrop, Rect2(_foe_sprite.position, _foe_sprite.size), Rect2(_player_sprite.position, _player_sprite.size))
	_backdrop.modulate = Color.WHITE.darkened(backdrop_shade)

## Creates the compact sprites and tags for every field slot (formation layout only).
func _build_formation() -> void:
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		for slot: int in model.slot_count(side):
			var sp := SpirlingSprite.new()
			sp.visible = false
			_shake_root.add_child(sp)
			_slot_sprites[side].append(sp)
			var tag := MiniStrip.new()
			tag.show_numbers = side == BattleModel.Side.PLAYER
			tag.ally = model.is_partner_slot(side, slot)
			tag.visible = false
			_field.add_child(tag)
			_slot_strips[side].append(tag)
	for n: Control in [_foe_sprite, _player_sprite, _player_strip]:
		n.visible = false
	_foe_strip.show_numbers = true
	_field.move_child(_pin, -1)
	_shake_root.move_child(_fx, -1)
	_layout_field()
	_apply_speed()

## Two ranks: foes right-aligned under the ledger strip, the player's side left-aligned above
## the text box. Four 28 px sprites with 6 px gaps fill 130 of the 144 px.
func _layout_formation() -> void:
	var w: float = _field.size.x
	var h: float = _field.size.y
	_foe_strip.position = Vector2(MARGIN, MARGIN)
	_foe_strip.size = Vector2(w - 26 - MARGIN * 3, STRIP_HEIGHT + 8)
	_ff_button.position = Vector2(w - 26 - MARGIN, MARGIN)
	_ff_button.size = Vector2(26, 12)
	_auto_button.position = Vector2(w - 26 - MARGIN, MARGIN + 14)
	_auto_button.size = Vector2(26, 12)
	_log_button.position = Vector2(w - 26 - MARGIN, MARGIN + 28)
	_log_button.size = Vector2(26, 12)
	_goal_label.position = Vector2(w - 26 - MARGIN, MARGIN + 42)
	_back_button.position = Vector2(MARGIN, MARGIN + STRIP_HEIGHT + 10)
	_back_button.size = Vector2(26, 12)
	var rects: Array[Rect2] = [Rect2(), Rect2()]
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		var n: int = _slot_sprites[side].size()
		var total: float = n * SLOT_SPRITE + (n - 1) * SLOT_GAP
		var x0: float = w - MARGIN - total if side == BattleModel.Side.FOE else MARGIN + 4
		var tag_h: float = (_slot_strips[side][0] as MiniStrip).needed_height() if n > 0 else 0.0
		var y: float = MARGIN + 44 if side == BattleModel.Side.FOE else h - MARGIN - tag_h - 2 - SLOT_SPRITE
		for slot: int in n:
			var sp: SpirlingSprite = _slot_sprites[side][slot]
			sp.position = Vector2(x0 + slot * (SLOT_SPRITE + SLOT_GAP), y)
			sp.size = Vector2(SLOT_SPRITE, SLOT_SPRITE)
			var tag: MiniStrip = _slot_strips[side][slot]
			tag.position = sp.position + Vector2(-1, SLOT_SPRITE + 2)
			tag.size = Vector2(MiniStrip.WIDTH, tag_h)
		rects[side] = Rect2(x0, y, total, SLOT_SPRITE)
	_backdrop.set_scene(backdrop, rects[BattleModel.Side.FOE], rects[BattleModel.Side.PLAYER])

## Shows [param side]/[param slot]'s details in the ledger strip (formation layout).
func _focus(side: int, slot: int) -> void:
	if not _multi:
		return
	var s: Spirling = model.active_spirling(side, slot)
	if s == null:
		return
	_foe_strip.show_numbers = side == BattleModel.Side.PLAYER
	_foe_strip.set_spirling(s)
	_foe_strip.visible = true

## Points the map pin at a slot (hollow = choosing, filled = aimed at).
func _point_pin(side: int, slot: int, filled: bool) -> void:
	if not _multi or slot < 0 or slot >= _slot_sprites[side].size():
		_pin.visible = false
		return
	var sp: SpirlingSprite = _slot_sprites[side][slot]
	_pin.filled = filled
	_pin.point_at(Rect2(sp.position, sp.size))

func _auto_active() -> bool:
	return GameState.auto_battle and model != null and model.is_wild

## Applies the 1x / 2x / 4x battle speed (and auto-advance while fast or on Auto).
func _apply_speed() -> void:
	var speed: float = GameState.battle_speed_scale()
	_ff_button.text = "%dx" % int(speed)
	_text.auto_advance = speed > 1.0 or _auto_active()
	_text.chars_per_second = GameState.text_cps() * speed
	for n: Variant in [_foe_sprite, _player_sprite, _foe_strip, _player_strip]:
		n.speed_scale = speed
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		for n: Variant in _slot_sprites[side] + _slot_strips[side]:
			n.speed_scale = speed

# --- Flow -------------------------------------------------------------------------

func _run() -> void:
	_menu.set_enabled(false)
	_foe_strip.visible = false
	_player_strip.visible = false
	_auto_button.visible = model.is_wild
	_apply_speed()
	Sound.music(music_track)
	var intro: Array[BattleEvent] = model.start()
	if _multi:
		_build_formation()
	await _play(intro)
	if model.has_meta("bonus_goal"):
		await _text.show_text(str(model.get_meta("bonus_goal")))
	_refresh_goal()
	for id: String in (["battle", "bond"] if model.is_wild else ["battle"]):
		for line: String in Tips.take(id):
			await _text.show_text(line)
	_replaying = not replay_inputs.is_empty()
	while not model.is_finished():
		if _replaying:
			if replay_inputs.is_empty():
				break
			var rec: Dictionary = replay_inputs.pop_front()
			await get_tree().create_timer(AUTO_DELAY / GameState.battle_speed_scale()).timeout
			if str(rec.get("t", "")) == "switch":
				await _play(model.submit_switch(int(rec.get("i", 0))))
			elif str(rec.get("t", "")) == "turns":
				await _play(model.submit_actions(BattleReplay.actions_from_dict(rec)))
			else:
				await _play(model.submit_turn(BattleReplay.action_from_dict(rec)))
			continue
		if model.needs_player_switch():
			_point_pin(BattleModel.Side.PLAYER, model.switch_slot(), false)
			var idx: int = await _pick_party("Who steps out?", false, model.switch_slot())
			_pin.visible = false
			inputs.append(BattleReplay.switch_to_dict(idx))
			await _play(model.submit_switch(idx))
			continue
		if _multi:
			var actions: Array[BattleAction] = await _choose_actions()
			inputs.append(BattleReplay.actions_to_dict(actions))
			await _play(model.submit_actions(actions))
			_refresh_goal()
			continue
		var action: BattleAction = await _choose_action()
		if action == null:
			continue
		inputs.append(BattleReplay.action_to_dict(action))
		await _play(model.submit_turn(action))
		_refresh_goal()
	_refresh_goal()
	battle_finished.emit(model.outcome, model)
	if quit_on_finish:
		get_tree().quit()

## Formation layout: one action per player slot, left to right. Run ends the choosing early.
func _choose_actions() -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	var taken: Array[int] = []
	for slot: int in model.player_slots():
		var a: BattleAction = null
		while a == null:
			a = await _choose_action(slot, taken)
		out.append(a)
		if a.kind == BattleAction.Kind.SWAP:
			taken.append(a.swap_index)
		if a.kind == BattleAction.Kind.RUN:
			break
	_pin.visible = false
	return out

func _choose_action(slot: int = 0, taken: Array[int] = []) -> BattleAction:
	var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER, slot)
	_focus(BattleModel.Side.PLAYER, slot)
	_point_pin(BattleModel.Side.PLAYER, slot, false)
	if _auto_active():
		_text.show_prompt("Auto: %s picks an art." % me.display_name())
		await get_tree().create_timer(AUTO_DELAY / GameState.battle_speed_scale()).timeout
		if _auto_active():
			return _auto_ai.choose(model, BattleModel.Side.PLAYER, slot)
	_text.show_prompt("Orders for %s? (%d Energy)" % [me.display_name(), me.energy])
	_menu.refresh(model, slot)
	_menu.set_enabled(true)
	var choice: Array = await _menu.chosen
	_menu.set_enabled(false)
	var kind: BattleAction.Kind = choice[0]
	var index: int = choice[1]
	match kind:
		BattleAction.Kind.MOVE:
			if index < me.moves.size() and me.can_afford(me.moves[index]):
				var aim: int = -1
				if not me.moves[index].is_area():
					aim = await _pick_target("Aim %s at?" % me.moves[index].move_name)
					if aim == -2:
						return null
				return BattleAction.make_move(BattleModel.Side.PLAYER, index, slot, aim)
			return BattleAction.make_rest(BattleModel.Side.PLAYER, slot)
		BattleAction.Kind.SWAP:
			var idx: int = await _pick_party("Swap to?", true, slot, taken)
			return null if idx < 0 else BattleAction.make_swap(BattleModel.Side.PLAYER, idx, slot)
		BattleAction.Kind.ITEM:
			return await _pick_item(slot)
		BattleAction.Kind.BOND:
			return await _bond(slot)
		BattleAction.Kind.RUN:
			return BattleAction.make_run(BattleModel.Side.PLAYER, slot)
	return null

## Lets the player tap the foe to aim at. Returns the foe slot, -1 when there is no choice
## (1v1 or a single foe left), or -2 when the player backs out.
func _pick_target(title: String) -> int:
	var foes: Array[int] = model.standing_slots(BattleModel.Side.FOE)
	if not _multi or foes.size() <= 1:
		return -1 if foes.is_empty() else foes[0]
	_text.show_prompt(title)
	for slot: int in foes:
		var sp: SpirlingSprite = _slot_sprites[BattleModel.Side.FOE][slot]
		var b := Button.new()
		b.flat = true
		b.position = sp.position - Vector2(2, 2)
		b.size = sp.size + Vector2(4, 14)
		b.accessibility_name = model.active_spirling(BattleModel.Side.FOE, slot).display_name()
		var picked: int = slot
		b.pressed.connect(func() -> void:
			Sound.sfx("confirm")
			_target_picked.emit(picked))
		b.focus_entered.connect(func() -> void:
			_focus(BattleModel.Side.FOE, picked)
			_point_pin(BattleModel.Side.FOE, picked, true))
		b.mouse_entered.connect(b.grab_focus)
		_field.add_child(b)
		_target_buttons.append(b)
	for i: int in _target_buttons.size():
		var b: Button = _target_buttons[i]
		b.focus_neighbor_left = _target_buttons[i - 1].get_path() if i > 0 else b.get_path()
		b.focus_neighbor_right = _target_buttons[i + 1].get_path() if i < _target_buttons.size() - 1 else b.get_path()
	_target_buttons[0].grab_focus()
	_back_button.visible = true
	var picked_slot: int = await _target_picked
	for b: Button in _target_buttons:
		b.queue_free()
	_target_buttons.clear()
	_back_button.visible = false
	_pin.visible = false
	return picked_slot if picked_slot >= 0 else -2

func _pick_party(title: String, cancellable: bool, slot: int = 0, taken: Array[int] = []) -> int:
	var entries: Array[Dictionary] = []
	var party: Array = model.party(BattleModel.Side.PLAYER)
	var candidates: Array[int] = []
	for i: int in model.swap_candidates(BattleModel.Side.PLAYER, slot):
		if not i in taken:
			candidates.append(i)
	for i: int in party.size():
		if model.is_partner_index(BattleModel.Side.PLAYER, i):
			continue
		var s: Spirling = party[i]
		entries.append({"text": "%s R%d %d/%d" % [s.display_name(), s.level, s.hp, s.max_hp()], "disabled": not i in candidates})
	while true:
		var idx: int = await _picker.pick(title, entries, cancellable)
		if idx < 0 or idx in candidates:
			return idx
	return -1

func _pick_item(slot: int = 0) -> BattleAction:
	var ids: Array[String] = []
	var entries: Array[Dictionary] = []
	for id: String in model.bag_ids(BattleModel.Side.PLAYER):
		var it: Dictionary = Database.item(id)
		if bool(it.get("battle", false)) and model.item_left_this_battle(BattleModel.Side.PLAYER, id):
			ids.append(id)
			entries.append({"text": "%s x%d" % [it.get("name", id), model.bag_count(BattleModel.Side.PLAYER, id)]})
	if ids.is_empty():
		await _text.show_text("No usable items.")
		return null
	var idx: int = await _picker.pick("Use which item?", entries)
	if idx < 0:
		return null
	if BattleModel.is_revive_item(ids[idx]):
		var down: int = await _pick_defeated()
		if down < 0:
			return null
		var r := BattleAction.make_item(BattleModel.Side.PLAYER, ids[idx], down, slot)
		return r if model.is_legal(r) else null
	var own: int = model.active_index(BattleModel.Side.PLAYER, slot)
	var target: int = await _pick_party("Use on?", true, slot) if model.party(BattleModel.Side.PLAYER).size() > 1 else own
	if target < 0:
		# Party picker disables the active Spirling; offer it directly.
		target = own
	var a := BattleAction.make_item(BattleModel.Side.PLAYER, ids[idx], target, slot)
	return a if model.is_legal(a) else null

## Picks a defeated Spirling of the player's team for a Rift Breath, or -1.
func _pick_defeated() -> int:
	var party: Array = model.party(BattleModel.Side.PLAYER)
	var idx: Array[int] = []
	var entries: Array[Dictionary] = []
	for i: int in party.size():
		var s: Spirling = party[i]
		if s.is_fainted() and not model.is_partner_index(BattleModel.Side.PLAYER, i):
			idx.append(i)
			entries.append({"text": "%s R%d" % [s.display_name(), s.level]})
	if idx.is_empty():
		await _text.show_text("Nobody in your team is defeated.")
		return -1
	var k: int = await _picker.pick("Bring back whom?", entries)
	return idx[k] if k >= 0 else -1

## Items in [param bag] that help a bond (a "bond_bonus" in items.json), Kin Charm first.
static func bond_charms(bag: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in bag:
		var it: Dictionary = Database.item(str(id))
		if int(bag[id]) > 0 and (float(it.get("bond_bonus", 0.0)) > 0.0 or bool(it.get("bond_sure", false))):
			out.append(str(id))
	out.sort_custom(func(a: String, b: String) -> bool: return a == "kin_charm" or (b != "kin_charm" and a < b))
	return out

func _bond(slot: int = 0) -> BattleAction:
	var charm: String = ""
	var charms: Array[String] = bond_charms(model.inventory)
	if charms.size() == 1 and charms[0] == "kin_charm":
		var use: int = await _picker.pick("Hold out a Kin Charm?", [{"text": "Yes (x%d)" % model.inventory.kin_charm}, {"text": "No"}] as Array[Dictionary])
		if use < 0:
			return null
		if use == 0:
			charm = "kin_charm"
	elif not charms.is_empty():
		# Shop charms (Echo Scent, Bond Seal) next to the Kin Charm: pick one or none.
		var opts: Array[Dictionary] = []
		for id: String in charms:
			opts.append({"text": "%s x%d" % [Database.item(id).get("name", id), model.inventory[id]]})
		opts.append({"text": "No"})
		var use: int = await _picker.pick("Hold out a charm?", opts)
		if use < 0:
			return null
		if use < charms.size():
			charm = charms[use]
	var aim: int = await _pick_target("Reach out to which one?")
	if aim == -2:
		return null
	var target_slot: int = maxi(aim, 0)
	await _text.show_text("Reach out to %s... Listen, then echo its call!" % model.active_spirling(BattleModel.Side.FOE, target_slot).display_name())
	_bond_game.target = _sprite(BattleModel.Side.FOE, target_slot).texture()
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, target_slot)
	var key: String = foe.uid if not foe.uid.is_empty() else str(foe.get_instance_id())
	if not _bond_plans.has(key):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var state: String = BondEcho.rift_state(GameState.current_map, GameState.rifts_sealed)
		_bond_plans[key] = BondEcho.make_plan(rng, foe.data, state)
	var score: float = await _bond_game.run(_bond_plans[key])
	GameState.note_echo(score)
	if score >= DailyTasks.MELODY_GOOD:
		DailyTasks.record("melody", {"map": GameState.current_map})
	if score >= 1.0:
		GameState.records["melody_perfect"] = 1
	return BattleAction.make_bond(BattleModel.Side.PLAYER, score, charm, slot, aim)

# --- Event playback -----------------------------------------------------------------

func _play(events: Array[BattleEvent]) -> void:
	_playing = events
	for i: int in events.size():
		_play_index = i
		await _play_event(events[i])
	_playing = []

## The event list being played and the current position, so an art can look ahead at how
## its first hit turns out (items 2375, 2376).
var _playing: Array[BattleEvent] = []
var _play_index: int = -1

## How the art at [param at] in [param events] lands on its first target: "miss" when the
## first result is a MISSED event, and "eff" (effectiveness) of the first damage. Looks only
## until the next art.
static func art_outcome(events: Array[BattleEvent], at: int) -> Dictionary:
	for i: int in range(at + 1, events.size()):
		var e: BattleEvent = events[i]
		match e.type:
			BattleEvent.Type.MOVE_USED:
				break
			BattleEvent.Type.MISSED:
				return {"miss": true, "eff": 1.0}
			BattleEvent.Type.DAMAGE:
				if not bool(e.data.get("status_tick", false)):
					return {"miss": false, "eff": float(e.data.get("eff", 1.0))}
	return {"miss": false, "eff": 1.0}

func _sprite(side: int, slot: int = 0) -> SpirlingSprite:
	if _multi and slot >= 0 and slot < _slot_sprites[side].size():
		return _slot_sprites[side][slot]
	return _player_sprite if side == BattleModel.Side.PLAYER else _foe_sprite

## The status strip for a slot: an InfoStrip in 1v1, a MiniStrip in the formation layout.
func _strip(side: int, slot: int = 0) -> Variant:
	if _multi and slot >= 0 and slot < _slot_strips[side].size():
		return _slot_strips[side][slot]
	return _player_strip if side == BattleModel.Side.PLAYER else _foe_strip

## Keeps the ledger strip in step with a slot whose numbers just changed.
func _refresh_focus(side: int, slot: int) -> void:
	if _multi and _foe_strip.spirling_name == _name_at(side, slot):
		_focus(side, slot)

func _name_at(side: int, slot: int) -> String:
	var s: Spirling = model.active_spirling(side, slot)
	return s.display_name() if s != null else ""

## Remembers an event for the log. Damage gets its amount (the text box only shows the bar).
func record(e: BattleEvent) -> void:
	var line: String = e.describe()
	if line.is_empty():
		return
	log_lines.append(line)
	while log_lines.size() > LOG_KEEP:
		log_lines.pop_front()

func _toggle_log() -> void:
	Sound.sfx("confirm")
	_log_label.text = "Battle log\n\n" + ("\n".join(log_lines) if not log_lines.is_empty() else "Nothing yet.") + "\n\n(tap to close)"
	_log_panel.visible = not _log_panel.visible

func _play_event(e: BattleEvent) -> void:
	var side: int = int(e.data.get("side", 0))
	var slot: int = int(e.data.get("slot", 0))
	record(e)
	match e.type:
		BattleEvent.Type.BATTLE_START:
			var foe: Spirling = model.active_spirling(BattleModel.Side.FOE)
			if _multi:
				for fs: int in model.slot_count(BattleModel.Side.FOE):
					var f: Spirling = model.active_spirling(BattleModel.Side.FOE, fs)
					_sprite(BattleModel.Side.FOE, fs).setup(f, "front")
					_strip(BattleModel.Side.FOE, fs).set_spirling(f)
				_focus(BattleModel.Side.FOE, 0)
				if model.is_wild:
					for fs: int in model.slot_count(BattleModel.Side.FOE):
						_strip(BattleModel.Side.FOE, fs).visible = true
						Sound.cry(model.active_spirling(BattleModel.Side.FOE, fs).data)
						await _sprite(BattleModel.Side.FOE, fs).step_out(false)
				await _text.show_text(e.describe())
				return
			_foe_sprite.setup(foe, "front")
			_foe_strip.set_spirling(foe)
			if music_track == "warden":
				# A Rift Warden shakes the field as it appears (item 2256).
				Juice.add_trauma(Juice.TRAUMA_WARDEN)
				Haptics.play("heavy")
			if model.is_wild:
				_foe_strip.visible = true
				Sound.cry(foe.data)
				await _foe_sprite.step_out(true)
			await _text.show_text(e.describe())
		BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
			var s: Spirling = model.party(side)[int(e.data.get("index", 0))]
			_sprite(side, slot).setup(s, "back" if side == BattleModel.Side.PLAYER else "front")
			_strip(side, slot).set_spirling(s)
			_strip(side, slot).visible = true
			_focus(side, slot)
			Sound.cry(s.data)
			await _sprite(side, slot).step_out(side != BattleModel.Side.PLAYER)
			_update_pinch()
			await _text.show_text(e.describe())
		BattleEvent.Type.SWAP_OUT:
			await _text.show_text(e.describe())
			await _sprite(side, slot).step_back(side != BattleModel.Side.PLAYER)
		BattleEvent.Type.BOSS, BattleEvent.Type.BOSS_PHASE:
			_focus(side, slot)
			_point_pin(side, slot, true)
			Sound.sfx("status")
			await _text.show_text(e.describe())
			_pin.visible = false
		BattleEvent.Type.MOVE_USED:
			_last_player_element = int(e.data.get("element", -1)) if side == BattleModel.Side.PLAYER else -1
			if side == BattleModel.Side.PLAYER:
				Collection.note_art(str(e.data.get("move", "")))
			_last_element[side] = int(e.data.get("element", -1))
			_focus(side, slot)
			_point_pin(side, slot, false)
			await _text.show_text(e.describe())
			var dir: Vector2 = Vector2(-8, -4) if side == BattleModel.Side.PLAYER else Vector2(8, 4)
			if _multi:
				dir = Vector2(0, -6) if side == BattleModel.Side.PLAYER else Vector2(0, 6)
			await _play_art(e, side, slot, dir)
			_pin.visible = false
		BattleEvent.Type.DAMAGE:
			var hit: String = _hit_sound(e)
			if hit == "hit" or hit == "hit_strong":
				Sound.element_hit(_last_element[BattleModel.other(side)])
			if hit != "hit":
				Sound.sfx(hit)
			if side == BattleModel.Side.FOE and _last_player_element >= 0 and e.data.has("eff"):
				var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, slot)
				if foe != null:
					GameState.learn_matchup(_last_player_element, foe.data.species_name, float(e.data.eff))
			if not bool(e.data.get("status_tick", false)):
				await _hit_feedback(e, side, slot, hit == "hit_strong")
			await _strip(side, slot).animate_hp(int(e.data.hp), int(e.data.max_hp))
			_refresh_focus(side, slot)
			_update_pinch()
			var line: String = _damage_line(e)
			if not line.is_empty():
				await _text.show_text(line)
		BattleEvent.Type.HEAL:
			Sound.sfx("heal")
			var heal_slot: int = model.slot_of(side, int(e.data.get("index", -1)))
			if heal_slot >= 0:
				await _strip(side, heal_slot).animate_hp(int(e.data.hp), int(e.data.max_hp))
				_refresh_focus(side, heal_slot)
			_update_pinch()
			await _text.show_text(e.describe())
		BattleEvent.Type.ENERGY_CHANGED:
			_strip(side, slot).set_energy(int(e.data.energy))
			_refresh_focus(side, slot)
		BattleEvent.Type.ENERGY_TAX:
			var ts: Variant = _strip(side, slot)
			if ts is InfoStrip:
				(ts as InfoStrip).set_tax(int(e.data.get("turns", 0)))
			var tax_text: String = e.describe()
			if not tax_text.is_empty():
				await _text.show_text(tax_text)
		BattleEvent.Type.STATUS_APPLIED:
			Sound.sfx("status")
			_strip(side, slot).set_status(str(e.data.status))
			_refresh_focus(side, slot)
			await _text.show_text(e.describe())
		BattleEvent.Type.STAT_CHANGED:
			var who: Spirling = model.active_spirling(side, slot)
			var st: Variant = _strip(side, slot)
			if st is InfoStrip and who != null:
				(st as InfoStrip).set_stages(who.stages)
			_refresh_focus(side, slot)
			if int(e.data.get("delta", 0)) != 0:
				Sound.sfx("level_up" if int(e.data.delta) > 0 else "status")
			await _text.show_text(e.describe())
		BattleEvent.Type.STATUS_CURED:
			_strip(side, slot).set_status("")
			_refresh_focus(side, slot)
			await _text.show_text(e.describe())
		BattleEvent.Type.FAINTED:
			Sound.sfx("faint")
			Juice.add_trauma(Juice.TRAUMA_FAINT)
			await _sprite(side, slot).faint()
			await _text.show_text(e.describe())
			_strip(side, slot).visible = false
		BattleEvent.Type.LEVEL_UP:
			Sound.sfx("level_up")
			var lv_slot: int = model.slot_of(BattleModel.Side.PLAYER, int(e.data.get("index", -1)))
			if lv_slot >= 0:
				var lst: Variant = _strip(BattleModel.Side.PLAYER, lv_slot)
				if lst is InfoStrip:
					(lst as InfoStrip).set_level(int(e.data.level))
				await lst.animate_hp(int(e.data.hp), int(e.data.max_hp))
			await _text.show_text(e.describe())
		BattleEvent.Type.BOND_RESULT:
			if bool(e.data.get("success", false)):
				await _sprite(BattleModel.Side.FOE, slot).step_back(false)
				_strip(BattleModel.Side.FOE, slot).visible = false
			await _text.show_text(e.describe())
		BattleEvent.Type.RULE:
			var turning: bool = bool(e.data.get("turning", false))
			_rule_banner.show_rule(Loc.t(str(e.data.get("label", ""))), turning, _field.size.x, _field.size.y * 0.42)
			if turning:
				Sound.sfx("status")
				Haptics.play("heavy")
			await _text.show_text(e.describe())
			_rule_banner.visible = false
		BattleEvent.Type.BATTLE_LINE:
			await _text.show_text(str(e.data.get("text", "")), str(e.data.get("name", "")))
		BattleEvent.Type.BATTLE_END:
			var outcome: int = int(e.data.get("outcome", 0))
			if outcome == BattleModel.Outcome.WIN or outcome == BattleModel.Outcome.BONDED:
				Sound.jingle("victory", "")
			elif outcome == BattleModel.Outcome.FLED:
				Sound.sfx("run")
			var money: int = int(e.data.get("money", 0))
			if money > 0:
				await _text.show_text("You received %d coins." % money)
			elif int(e.data.outcome) == BattleModel.Outcome.LOSS:
				await _text.show_text("Your team is worn out...")
		_:
			var text: String = e.describe()
			if not text.is_empty():
				await _text.show_text(text)

## Wind-up, charge and travel sounds and the element effect for an art (items 2329 to 2366, 2529, 2530).
func _play_art(e: BattleEvent, side: int, slot: int, dir: Vector2) -> void:
	var kind: int = int(e.data.get("kind", MoveData.Kind.PHYSICAL))
	var element: int = int(e.data.get("element", -1))
	var user: SpirlingSprite = _sprite(side, slot)
	Sound.sfx(charge_sound(kind))
	await user.windup(kind, dir)
	if element < 0:
		return
	var mv: MoveData = Database.move(str(e.data.get("move", "")))
	var sym: Dictionary = ElementFx.status_symbol(mv)
	var target: SpirlingSprite = user
	var targets: Array = e.data.get("targets", [])
	if (kind != MoveData.Kind.STATUS or bool(sym.on_foe)) and not targets.is_empty():
		target = _sprite(BattleModel.other(side), int(targets[0]))
	var me: Spirling = model.active_spirling(side, slot) if model != null else null
	var second: int = ElementFx.second_for(me.elements(), element) if me != null else -1
	_fx.user_sprite = user
	if kind != MoveData.Kind.PHYSICAL and target != user:
		_fx_travel_sound.call_deferred(element)
	var outcome: Dictionary = art_outcome(_playing, _play_index) if _play_index >= 0 else {}
	await _fx.play(element, kind, Rect2(user.position, user.size), Rect2(target.position, target.size),
		bool(outcome.get("miss", false)), ElementFx.impact_scale(float(outcome.get("eff", 1.0))), _art_amount(e),
		ElementFx.after_for(mv), str(sym.symbol), second)

## Particle factor from the art's power (item 2368).
static func _art_amount(e: BattleEvent) -> float:
	var mv: MoveData = Database.move(str(e.data.get("move", "")))
	return ElementFx.particles_for_power(mv.power) if mv != null else 1.0

## The charge sound for an art kind: a short rush, a rising pulse or two soft tones.
static func charge_sound(kind: int) -> String:
	match kind:
		MoveData.Kind.PHYSICAL: return "charge_physical"
		MoveData.Kind.FOCUS: return "charge_focus"
	return "charge_status"

## The travel sound starts with the travel phase, after the charge.
func _fx_travel_sound(element: int) -> void:
	await get_tree().create_timer(ElementFx.CHARGE_TIME / Juice.speed()).timeout
	Sound.sfx(travel_sound(element))

static func travel_sound(element: int) -> String:
	return "travel_" + String(Elements.E.keys()[element]).to_lower()

## Shake, vibration, hit-stop, knockback and flash for a landed hit (items 2256 to 2258, 2332, 2591).
func _hit_feedback(e: BattleEvent, side: int, slot: int, strong: bool) -> void:
	Juice.add_trauma(Juice.TRAUMA_HIT_STRONG if strong else Juice.TRAUMA_HIT, _last_element[BattleModel.other(side)])
	Haptics.play("heavy" if strong else "hit")
	var max_hp: int = maxi(int(e.data.get("max_hp", 1)), 1)
	await Juice.hitstop(float(e.data.get("amount", 0)) / max_hp)
	var sp: SpirlingSprite = _sprite(side, slot)
	sp.knockback(knockback_dir(side, _multi))
	await sp.hit_flash()

## Direction a Spirling on [param side] is pushed when hit: away from the other side.
static func knockback_dir(side: int, multi: bool) -> Vector2:
	if multi:
		return Vector2(0, 1) if side == BattleModel.Side.PLAYER else Vector2(0, -1)
	return Vector2(2, 1) if side == BattleModel.Side.PLAYER else Vector2(-2, -1)

## Switches to the pinch music while the player's active Spirling is low, and back once it recovers.
func _update_pinch() -> void:
	if model.is_finished():
		return
	var lowest: Spirling = model.active_spirling(BattleModel.Side.PLAYER)
	for slot: int in model.player_slots():
		var s: Spirling = model.active_spirling(BattleModel.Side.PLAYER, slot)
		if lowest == null or lowest.is_fainted() or s.hp_fraction() < lowest.hp_fraction():
			lowest = s
	var track: String = pinch_track(lowest, music_track)
	if Sound.current_track != track:
		Sound.music(track)

## "battle_pinch" when [param s] is at or below PINCH_RATIO of its HP (and still standing), else [param normal].
static func pinch_track(s: Spirling, normal: String) -> String:
	if s != null and s.hp > 0 and float(s.hp) / s.max_hp() <= PINCH_RATIO:
		return "battle_pinch"
	return normal

static func _hit_sound(e: BattleEvent) -> String:
	if bool(e.data.get("status_tick", false)) or not e.data.has("eff"):
		return "hit_weak"
	var eff: float = float(e.data.get("eff", 1.0))
	if eff > 1.0 or bool(e.data.get("crit", false)):
		return "hit_strong"
	return "hit_weak" if eff < 1.0 else "hit"

## Only the interesting part of a damage event (the bar already shows the amount).
func _damage_line(e: BattleEvent) -> String:
	var parts: PackedStringArray = []
	if bool(e.data.get("crit", false)):
		parts.append("A keen hit!")
	var eff: float = float(e.data.get("eff", 1.0))
	if eff > 1.0:
		parts.append("It's overwhelming!")
	elif eff < 1.0:
		parts.append("It barely landed...")
	if bool(e.data.get("recoil", false)):
		parts.append("%s is hurt by the recoil." % e.data.get("name", ""))
	return " ".join(parts)

# --- Demo -----------------------------------------------------------------------------

func _demo_model() -> BattleModel:
	Database.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = DEMO_SEED
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 9, rng), Spirling.new(Database.species("Puddlet"), 8, rng)]
	var theirs: Array[Spirling] = [Spirling.new(Database.species("Zippit"), 7, rng)]
	match demo:
		"boss":
			mine = _demo_team(rng, ["Kindlop", "Puddlet", "Zephlet", "Zippit"], 14)
			theirs = _demo_team(rng, ["Smoldrake"], 14)
		"duel3":
			mine = _demo_team(rng, ["Kindlop", "Puddlet", "Mossling"], 14)
			theirs = _demo_team(rng, ["Zippit", "Shalebat", "Mossling", "Kelpup"], 14)
		"tag":
			mine = _demo_team(rng, ["Kindlop", "Puddlet"], 13)
			theirs = _demo_team(rng, ["Shalebat", "Kelpup", "Mirkmole"], 13)
		"horde":
			mine = _demo_team(rng, ["Kindlop", "Puddlet", "Zephlet"], 12)
			theirs = _demo_team(rng, ["Mirkmole", "Shalebat", "Wickit", "Mirkmole", "Shalebat"], 11)
	var m := BattleModel.new(mine, theirs, demo == "" or demo == "horde", DEMO_SEED, 0 if demo == "" else 1)
	m.inventory = {"tonic": 3, "remedy": 1, "kin_charm": 2}
	match demo:
		"boss":
			m.front_size = [4, 1]
			m.foe_boss = "ashen_heart"
			m.trainer_name = "Ashen Heart"
		"duel3":
			m.front_size = [3, 3]
			m.trainer_name = "Rift Mystic Ilka"
		"tag":
			m.front_size = [1, 2]
			m.trainer_name = "Hauler Tobin"
			m.set_partner("Cartographer Kestra", _demo_team(rng, ["Zephlet", "Zippit"], 13), 1)
		"horde":
			m.front_size = [2, 4]
	return m

static func _demo_team(rng: RandomNumberGenerator, names: Array[String], level: int) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: String in names:
		out.append(Spirling.new(Database.species(n), level, rng))
	return out
