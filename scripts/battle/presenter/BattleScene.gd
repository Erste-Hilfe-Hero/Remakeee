class_name BattleScene
extends Control
## Battle presenter. Owns a BattleModel, asks the player for actions, and plays the model's
## events back in order (sprites, HP bars, Energy pips, text box). Holds no battle rules.
##
## Layout (original): foe strip along the top edge, foe sprite top-right, player sprite
## bottom-left, player strip just above the text box, commands at the bottom.

signal battle_finished(outcome: BattleModel.Outcome, model: BattleModel)

const TEXT_BOX_HEIGHT: int = 44
const STRIP_HEIGHT: int = 22
const MARGIN: int = 4
const FAST_SPEED: float = 3.0
const DEMO_SEED: int = 2024

var model: BattleModel
## Backdrop for where the battle started (field, lake, ridge, ember). Set before adding.
var backdrop: String = "field"
## Set to true to quit the app when the battle ends (standalone demo).
var quit_on_finish: bool = false

var _field: Control
var _backdrop: BattleBackdrop
var _foe_sprite: SpirlingSprite
var _player_sprite: SpirlingSprite
var _foe_strip: InfoStrip
var _player_strip: InfoStrip
var _text: TextBox
var _menu: CommandMenu
var _picker: ListPicker
var _bond_game: BondMinigame
var _ff_button: Button

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if model == null:
		model = _demo_model()
		quit_on_finish = false
	_run.call_deferred()

## Call before adding to the tree.
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

	_backdrop = BattleBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.add_child(_backdrop)

	_foe_sprite = SpirlingSprite.new()
	_player_sprite = SpirlingSprite.new()
	_foe_strip = InfoStrip.new()
	_player_strip = InfoStrip.new()
	_player_strip.show_numbers = true
	for n: Control in [_foe_sprite, _player_sprite, _foe_strip, _player_strip]:
		_field.add_child(n)
	_foe_sprite.visible = false
	_player_sprite.visible = false

	_ff_button = Button.new()
	_ff_button.text = ">>"
	_ff_button.toggle_mode = true
	_ff_button.focus_mode = Control.FOCUS_NONE
	_ff_button.button_pressed = GameState.fast_forward
	_ff_button.toggled.connect(_set_fast_forward)
	_field.add_child(_ff_button)

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
	_set_fast_forward(GameState.fast_forward)

func _layout_field() -> void:
	var w: float = _field.size.x
	var h: float = _field.size.y
	var sprite: float = float(EraManager.battle_sprite_size())
	# Chimora's own arrangement: foe on the upper left, the player's Spirling on the lower right,
	# info strips on the opposite sides (docs/legal/IP_PATENT_AUDIT.md, item 4).
	_foe_strip.size = Vector2(w * 0.55, STRIP_HEIGHT)
	_foe_strip.position = Vector2(w - _foe_strip.size.x - MARGIN, MARGIN)
	_ff_button.position = Vector2(MARGIN, MARGIN)
	_ff_button.size = Vector2(18, 12)
	_foe_sprite.position = Vector2(MARGIN * 2, MARGIN + STRIP_HEIGHT - 6)
	_foe_sprite.size = Vector2(sprite, sprite)
	_foe_sprite.mirrored = true
	_player_strip.size = Vector2(w - sprite - MARGIN * 5, STRIP_HEIGHT + 8)
	_player_strip.position = Vector2(MARGIN, h - _player_strip.size.y - MARGIN)
	_player_sprite.position = Vector2(w - sprite - MARGIN * 2, h - sprite - MARGIN * 2)
	_player_sprite.size = Vector2(sprite, sprite)
	_player_sprite.mirrored = true
	_backdrop.set_scene(backdrop, Rect2(_foe_sprite.position, _foe_sprite.size), Rect2(_player_sprite.position, _player_sprite.size))

func _set_fast_forward(on: bool) -> void:
	GameState.fast_forward = on
	var speed: float = FAST_SPEED if on else 1.0
	_text.auto_advance = on
	_text.chars_per_second = GameState.text_cps() * speed
	for n: Variant in [_foe_sprite, _player_sprite, _foe_strip, _player_strip]:
		n.speed_scale = speed

# --- Flow -------------------------------------------------------------------------

func _run() -> void:
	_menu.set_enabled(false)
	_foe_strip.visible = false
	_player_strip.visible = false
	await _play(model.start())
	while not model.is_finished():
		if model.needs_player_switch():
			var idx: int = await _pick_party("Who steps out?", false)
			await _play(model.submit_switch(idx))
			continue
		var action: BattleAction = await _choose_action()
		if action == null:
			continue
		await _play(model.submit_turn(action))
	battle_finished.emit(model.outcome, model)
	if quit_on_finish:
		get_tree().quit()

func _choose_action() -> BattleAction:
	var me: Spirling = model.active_spirling(BattleModel.Side.PLAYER)
	_text.show_prompt("Orders for %s?" % me.display_name())
	_menu.refresh(model)
	_menu.set_enabled(true)
	var choice: Array = await _menu.chosen
	_menu.set_enabled(false)
	var kind: BattleAction.Kind = choice[0]
	var index: int = choice[1]
	match kind:
		BattleAction.Kind.MOVE:
			if index < me.moves.size() and me.can_afford(me.moves[index]):
				return BattleAction.make_move(BattleModel.Side.PLAYER, index)
			return BattleAction.make_rest(BattleModel.Side.PLAYER)
		BattleAction.Kind.SWAP:
			var idx: int = await _pick_party("Swap to?", true)
			return null if idx < 0 else BattleAction.make_swap(BattleModel.Side.PLAYER, idx)
		BattleAction.Kind.ITEM:
			return await _pick_item()
		BattleAction.Kind.BOND:
			return await _bond()
		BattleAction.Kind.RUN:
			return BattleAction.make_run(BattleModel.Side.PLAYER)
	return null

func _pick_party(title: String, cancellable: bool) -> int:
	var entries: Array[Dictionary] = []
	var party: Array = model.party(BattleModel.Side.PLAYER)
	var candidates: Array[int] = model.swap_candidates(BattleModel.Side.PLAYER)
	for i: int in party.size():
		var s: Spirling = party[i]
		entries.append({"text": "%s Lv%d %d/%d" % [s.display_name(), s.level, s.hp, s.max_hp()], "disabled": not i in candidates})
	while true:
		var idx: int = await _picker.pick(title, entries, cancellable)
		if idx < 0 or idx in candidates:
			return idx
	return -1

func _pick_item() -> BattleAction:
	var ids: Array[String] = []
	var entries: Array[Dictionary] = []
	for id: Variant in model.inventory:
		var it: Dictionary = Database.item(str(id))
		if int(model.inventory[id]) > 0 and bool(it.get("battle", false)):
			ids.append(str(id))
			entries.append({"text": "%s x%d" % [it.get("name", id), model.inventory[id]]})
	if ids.is_empty():
		await _text.show_text("No usable items.")
		return null
	var idx: int = await _picker.pick("Use which item?", entries)
	if idx < 0:
		return null
	var target: int = await _pick_party("Use on?", true) if model.party(BattleModel.Side.PLAYER).size() > 1 else model.active[BattleModel.Side.PLAYER]
	if target < 0:
		# Party picker disables the active Spirling; offer it directly.
		target = model.active[BattleModel.Side.PLAYER]
	var a := BattleAction.make_item(BattleModel.Side.PLAYER, ids[idx], target)
	return a if model.is_legal(a) else null

func _bond() -> BattleAction:
	var charm: String = ""
	if int(model.inventory.get("kin_charm", 0)) > 0:
		var use: int = await _picker.pick("Hold out a Kin Charm?", [{"text": "Yes (x%d)" % model.inventory.kin_charm}, {"text": "No"}] as Array[Dictionary])
		if use < 0:
			return null
		if use == 0:
			charm = "kin_charm"
	await _text.show_text("Reach out to %s... Listen, then echo its call!" % model.active_spirling(BattleModel.Side.FOE).display_name())
	_bond_game.target = _foe_sprite.texture()
	var score: float = await _bond_game.run()
	return BattleAction.make_bond(BattleModel.Side.PLAYER, score, charm)

# --- Event playback -----------------------------------------------------------------

func _play(events: Array[BattleEvent]) -> void:
	for e: BattleEvent in events:
		await _play_event(e)

func _sprite(side: int) -> SpirlingSprite:
	return _player_sprite if side == BattleModel.Side.PLAYER else _foe_sprite

func _strip(side: int) -> InfoStrip:
	return _player_strip if side == BattleModel.Side.PLAYER else _foe_strip

func _play_event(e: BattleEvent) -> void:
	var side: int = int(e.data.get("side", 0))
	match e.type:
		BattleEvent.Type.BATTLE_START:
			var foe: Spirling = model.active_spirling(BattleModel.Side.FOE)
			_foe_sprite.setup(foe, "front")
			_foe_strip.set_spirling(foe)
			if model.is_wild:
				_foe_strip.visible = true
				await _foe_sprite.step_out(true)
			await _text.show_text(e.describe())
		BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
			var s: Spirling = model.party(side)[int(e.data.get("index", 0))]
			_sprite(side).setup(s, "back" if side == BattleModel.Side.PLAYER else "front")
			_strip(side).set_spirling(s)
			_strip(side).visible = true
			await _sprite(side).step_out(side != BattleModel.Side.PLAYER)
			await _text.show_text(e.describe())
		BattleEvent.Type.SWAP_OUT:
			await _text.show_text(e.describe())
			await _sprite(side).step_back(side != BattleModel.Side.PLAYER)
		BattleEvent.Type.MOVE_USED:
			await _text.show_text(e.describe())
			var dir: Vector2 = Vector2(-8, -4) if side == BattleModel.Side.PLAYER else Vector2(8, 4)
			await _sprite(side).lunge(dir)
		BattleEvent.Type.DAMAGE:
			if not bool(e.data.get("status_tick", false)):
				await _sprite(side).hit_flash()
			await _strip(side).animate_hp(int(e.data.hp), int(e.data.max_hp))
			var line: String = _damage_line(e)
			if not line.is_empty():
				await _text.show_text(line)
		BattleEvent.Type.HEAL:
			if int(e.data.get("index", -1)) == model.active[side]:
				await _strip(side).animate_hp(int(e.data.hp), int(e.data.max_hp))
			await _text.show_text(e.describe())
		BattleEvent.Type.ENERGY_CHANGED:
			_strip(side).set_energy(int(e.data.energy))
		BattleEvent.Type.STATUS_APPLIED:
			_strip(side).set_status(str(e.data.status))
			await _text.show_text(e.describe())
		BattleEvent.Type.STATUS_CURED:
			_strip(side).set_status("")
			await _text.show_text(e.describe())
		BattleEvent.Type.FAINTED:
			await _sprite(side).faint()
			await _text.show_text(e.describe())
			_strip(side).visible = false
		BattleEvent.Type.LEVEL_UP:
			if int(e.data.get("index", -1)) == model.active[BattleModel.Side.PLAYER]:
				_player_strip.set_level(int(e.data.level))
				await _player_strip.animate_hp(int(e.data.hp), int(e.data.max_hp))
			await _text.show_text(e.describe())
		BattleEvent.Type.BOND_RESULT:
			if bool(e.data.get("success", false)):
				await _foe_sprite.step_back(false)
			await _text.show_text(e.describe())
		BattleEvent.Type.BATTLE_END:
			var money: int = int(e.data.get("money", 0))
			if money > 0:
				await _text.show_text("You received %d coins." % money)
			elif int(e.data.outcome) == BattleModel.Outcome.LOSS:
				await _text.show_text("Your team is worn out...")
		_:
			var text: String = e.describe()
			if not text.is_empty():
				await _text.show_text(text)

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
	var m := BattleModel.new(mine, theirs, true, DEMO_SEED, 0)
	m.inventory = {"tonic": 3, "remedy": 1, "kin_charm": 2}
	return m
