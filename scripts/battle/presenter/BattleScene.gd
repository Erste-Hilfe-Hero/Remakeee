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
## Pause before an auto-battle move, so the player can still tap Auto off.
const AUTO_DELAY: float = 0.35
const DEMO_SEED: int = 2024
## Lines kept for the battle log (shown newest last).
const LOG_KEEP: int = 14

var model: BattleModel
## Backdrop for where the battle started (field, lake, ridge, ember). Set before adding.
var backdrop: String = "field"
## Music for this fight ("battle" or "warden"); the overworld sets it before adding the scene.
var music_track: String = "battle"
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
var _auto_button: Button
var _auto_ai := BattleAI.new(1)
var _log_button: Button
var _log_panel: PanelContainer
var _log_label: Label
## Plain-text lines of what happened so far (item 11: re-read the last turns).
var log_lines: Array[String] = []
## Element of the player's last move, so the hit that follows teaches the matchup.
var _last_player_element: int = -1
## Element of the last move each side used, for the hit sound.
var _last_element: Array[int] = [-1, -1]
## HP ratio at or below which the pinch music takes over (item 69).
const PINCH_RATIO: float = 0.25

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
	_log_button = Button.new()
	_log_button.text = "Log"
	_log_button.focus_mode = Control.FOCUS_NONE
	_log_button.pressed.connect(_toggle_log)
	_field.add_child(_log_button)

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
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_log_panel.visible = false)
	add_child(_log_panel)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log_panel.add_child(_log_label)
	_apply_speed()

func _layout_field() -> void:
	var w: float = _field.size.x
	var h: float = _field.size.y
	var sprite: float = float(EraManager.battle_sprite_size())
	_foe_strip.position = Vector2(MARGIN, MARGIN)
	_foe_strip.size = Vector2(w * 0.55, STRIP_HEIGHT)
	_ff_button.position = Vector2(w - 26 - MARGIN, MARGIN)
	_ff_button.size = Vector2(26, 12)
	_auto_button.position = Vector2(w - 26 - MARGIN, MARGIN + 14)
	_auto_button.size = Vector2(26, 12)
	_log_button.position = Vector2(w - 26 - MARGIN, MARGIN + 28)
	_log_button.size = Vector2(26, 12)
	_foe_sprite.position = Vector2(w - sprite - MARGIN * 2, MARGIN + STRIP_HEIGHT - 6)
	_foe_sprite.size = Vector2(sprite, sprite)
	_player_strip.size = Vector2(w - sprite - MARGIN * 5, STRIP_HEIGHT + 8)
	_player_strip.position = Vector2(w - _player_strip.size.x - MARGIN, h - _player_strip.size.y - MARGIN)
	_player_sprite.position = Vector2(MARGIN * 2, h - sprite - MARGIN * 2)
	_player_sprite.size = Vector2(sprite, sprite)
	_backdrop.set_scene(backdrop, Rect2(_foe_sprite.position, _foe_sprite.size), Rect2(_player_sprite.position, _player_sprite.size))

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

# --- Flow -------------------------------------------------------------------------

func _run() -> void:
	_menu.set_enabled(false)
	_foe_strip.visible = false
	_player_strip.visible = false
	_auto_button.visible = model.is_wild
	_apply_speed()
	Sound.music(music_track)
	await _play(model.start())
	for id: String in (["battle", "bond"] if model.is_wild else ["battle"]):
		for line: String in Tips.take(id):
			await _text.show_text(line)
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
	if _auto_active():
		_text.show_prompt("Auto: %s picks a move." % me.display_name())
		await get_tree().create_timer(AUTO_DELAY / GameState.battle_speed_scale()).timeout
		if _auto_active():
			return _auto_ai.choose(model, BattleModel.Side.PLAYER)
	_text.show_prompt("What will %s do? (%d Energy)" % [me.display_name(), me.energy])
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
	await _text.show_text("Reach out to %s... Tap with the pulse!" % model.active_spirling(BattleModel.Side.FOE).display_name())
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
	record(e)
	match e.type:
		BattleEvent.Type.BATTLE_START:
			var foe: Spirling = model.active_spirling(BattleModel.Side.FOE)
			_foe_sprite.setup(foe, "front")
			_foe_strip.set_spirling(foe)
			if model.is_wild:
				_foe_strip.visible = true
				Sound.cry(foe.data)
				await _foe_sprite.step_out(false)
			await _text.show_text(e.describe())
		BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
			var s: Spirling = model.party(side)[int(e.data.get("index", 0))]
			_sprite(side).setup(s, "back" if side == BattleModel.Side.PLAYER else "front")
			_strip(side).set_spirling(s)
			_strip(side).visible = true
			Sound.cry(s.data)
			await _sprite(side).step_out(side == BattleModel.Side.PLAYER)
			_update_pinch()
			await _text.show_text(e.describe())
		BattleEvent.Type.SWAP_OUT:
			await _text.show_text(e.describe())
			await _sprite(side).step_back(side == BattleModel.Side.PLAYER)
		BattleEvent.Type.MOVE_USED:
			_last_player_element = int(e.data.get("element", -1)) if side == BattleModel.Side.PLAYER else -1
			_last_element[side] = int(e.data.get("element", -1))
			await _text.show_text(e.describe())
			var dir: Vector2 = Vector2(8, -4) if side == BattleModel.Side.PLAYER else Vector2(-8, 4)
			await _sprite(side).lunge(dir)
		BattleEvent.Type.DAMAGE:
			var hit: String = _hit_sound(e)
			if hit == "hit" or hit == "hit_strong":
				Sound.element_hit(_last_element[BattleModel.other(side)])
			if hit != "hit":
				Sound.sfx(hit)
			if side == BattleModel.Side.FOE and _last_player_element >= 0 and e.data.has("eff"):
				var foe: Spirling = model.active_spirling(BattleModel.Side.FOE)
				GameState.learn_matchup(_last_player_element, foe.data.species_name, float(e.data.eff))
			if not bool(e.data.get("status_tick", false)):
				await _sprite(side).hit_flash()
			await _strip(side).animate_hp(int(e.data.hp), int(e.data.max_hp))
			_update_pinch()
			var line: String = _damage_line(e)
			if not line.is_empty():
				await _text.show_text(line)
		BattleEvent.Type.HEAL:
			Sound.sfx("heal")
			if int(e.data.get("index", -1)) == model.active[side]:
				await _strip(side).animate_hp(int(e.data.hp), int(e.data.max_hp))
			_update_pinch()
			await _text.show_text(e.describe())
		BattleEvent.Type.ENERGY_CHANGED:
			_strip(side).set_energy(int(e.data.energy))
		BattleEvent.Type.STATUS_APPLIED:
			Sound.sfx("status")
			_strip(side).set_status(str(e.data.status))
			await _text.show_text(e.describe())
		BattleEvent.Type.STAT_CHANGED:
			var who: Spirling = model.active_spirling(side)
			_strip(side).set_stages(who.stages)
			if int(e.data.get("delta", 0)) != 0:
				Sound.sfx("level_up" if int(e.data.delta) > 0 else "status")
			await _text.show_text(e.describe())
		BattleEvent.Type.STATUS_CURED:
			_strip(side).set_status("")
			await _text.show_text(e.describe())
		BattleEvent.Type.FAINTED:
			Sound.sfx("faint")
			await _sprite(side).faint()
			await _text.show_text(e.describe())
			_strip(side).visible = false
		BattleEvent.Type.LEVEL_UP:
			Sound.sfx("level_up")
			if int(e.data.get("index", -1)) == model.active[BattleModel.Side.PLAYER]:
				_player_strip.set_level(int(e.data.level))
				await _player_strip.animate_hp(int(e.data.hp), int(e.data.max_hp))
			await _text.show_text(e.describe())
		BattleEvent.Type.BOND_RESULT:
			if bool(e.data.get("success", false)):
				await _foe_sprite.step_back(false)
			await _text.show_text(e.describe())
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

## Switches to the pinch music while the player's active Spirling is low, and back once it recovers.
func _update_pinch() -> void:
	if model.is_finished():
		return
	var track: String = pinch_track(model.active_spirling(BattleModel.Side.PLAYER), music_track)
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
	var m := BattleModel.new(mine, theirs, true, DEMO_SEED, 0)
	m.inventory = {"tonic": 3, "remedy": 1, "kin_charm": 2}
	return m
