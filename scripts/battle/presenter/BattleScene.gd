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
## The battle started on an outdoor map: the backdrop takes the day/night tint (BattleShow).
var outdoor: bool = false
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
## Rain, fog or a storm over the field when the region's sky laid the field (Era III on).
var _weather: BattleWeather
var _backdrop: BattleBackdrop
## Era IV 2.5D stage; null before Panorama.
var _stage: Era4Stage
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
## Log entries with their filter kind and side (BattleInfo, item 565), the filter in use, the
## arts each foe showed (item 567), the end report (item 581) and the remembered art per slot
## and target (items 603, 615).
var log_entries: Array = []
var _log_filter: String = "all"
var _log_filter_button: Button
var _seen_arts: Dictionary = {}
var report: Dictionary = BattleInfo.new_report()
var _last_art_name: String = ""
## Name of the player's Spirling that used that art (the report's star, plan item 20).
var _last_user_name: String = ""
var _last_art: Dictionary = {}
var _last_aim: int = -1
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
	theme = EraBattleHud.theme(EraManager.active_era())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if model == null:
		model = _demo_model()
		quit_on_finish = false
	_multi = model.is_multi()
	_text.chars_per_second *= MultiRules.text_speed(model)
	_run.call_deferred()

## In a Trial "Leave" restarts it (item 708): the screen ends and the Rift starts it again.
func _puzzle_restart(a: BattleAction) -> bool:
	if a == null or a.kind != BattleAction.Kind.RUN or not model.has_meta("puzzle_max"):
		return false
	model.set_meta("puzzle_restart", true)
	return true

## Call before adding to the tree.
## Shows "T3 ✓", "T3 ✗" or "T3" for the bonus goal of this battle (item 762).
func _refresh_goal() -> void:
	if _goal_label != null and model.has_meta("puzzle_max"):
		# Trials (item 711): the goal as a sentence and the turns left, top left.
		_goal_label.text = str(model.get_meta("puzzle_goal", "")) + "\n" + Loc.t("Turns left: %d") % BattlePuzzle.turns_left(model)
		_goal_label.visible = true
		return
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
	_text.duck_music = true
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
	_backdrop.hat = GameState.worn_hat()
	_shake_root.add_child(_backdrop)
	if EraManager.uses_stage_25d():
		_stage = Era4Stage.new()
		_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shake_root.add_child(_stage)
		_stage.set_terrain(backdrop)
		_backdrop.visible = false

	# Rift field badge and backdrop tint (KAMPF_PLAN_1000 items 322, 331).
	_field_badge = FieldBadge.new()
	_field_badge.era = EraManager.active_era()
	_shake_root.add_child(_field_badge.tint_rect)
	_foe_sprite = SpirlingSprite.new()
	_player_sprite = SpirlingSprite.new()
	_foe_strip = InfoStrip.new()
	_player_strip = InfoStrip.new()
	_player_strip.show_numbers = true
	_player_strip.show_xp = true
	for n: Control in [_foe_sprite, _player_sprite]:
		_shake_root.add_child(n)
	_fx = ElementFx.new()
	_fx.name = "element_fx"
	_shake_root.add_child(_fx)
	_weather = BattleWeather.new()
	_weather.name = "battle_weather"
	_weather.visible = false
	_shake_root.add_child(_weather)
	if _stage != null and _stage.light_layer() != null:
		_shake_root.add_child(_stage.light_layer())
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
	_field.add_child(_field_badge)
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
	var log_box := VBoxContainer.new()
	_log_panel.add_child(log_box)
	_log_filter_button = Button.new()
	_log_filter_button.clip_text = true
	_log_filter_button.pressed.connect(func() -> void:
		_log_filter = BattleInfo.next_filter(_log_filter)
		_fill_log())
	log_box.add_child(_log_filter_button)
	# Photo mode in battle (KAMPF_PLAN_1000 662), the overworld's own: the log closes first.
	_photo_button = Button.new()
	_photo_button.name = "photo_button"
	_photo_button.text = "Take a photo"
	_photo_button.pressed.connect(open_photo)
	log_box.add_child(_photo_button)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.clip_text = true
	log_box.add_child(_log_label)
	_apply_speed()
	_hud = BattleHud.new()
	_hud.attach(self)
	_show = BattleShow.new()
	_show.attach(self)

## Era look of the HUD: plates, small buttons, team rows, text frame, ring-rise panel.
var _hud: BattleHud
## Banners, status motes, stage aura and battle sounds of every era (data/battle_show.json).
var _show: BattleShow
var _field_badge: FieldBadge
## Each Spirling's share and the Rift fields for the end report (items 335, 393).
var battle_report: BattleReport = BattleReport.new()

## Damage preview for one target with the team guard and back row factored in (items 362, 367).
func _aim_line(me: Spirling, mv: MoveData, foe_slot: int, from_slot: int = 0) -> String:
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, foe_slot)
	var mult: float = GameState.known_multiplier(mv.element, foe)
	var pct: int = CommandMenu.damage_pct(model, me, foe, mv) if GameState.damage_preview and ShopEffects.owns_setting("damage_preview") and mult >= 0.0 else -1
	if pct > 0:
		pct = maxi(1, roundi(pct * MultiRules.guard_mult(model, BattleModel.Side.FOE) * MultiRules.row_mult(model, BattleModel.Side.PLAYER, from_slot, BattleModel.Side.FOE, foe_slot, mv)))
	return MultiRules.aim_line(foe.display_name(), pct, mult if mv.power > 0 else -1.0)

## The field badge: in 1v1 just above the player's plate (and team row), at the plate's left
## edge; in a formation under the ledger and the team rows at the left edge, folded when it
## would run into the foe rank.
func _place_field_badge() -> void:
	if _field_badge == null or _player_strip == null:
		return
	if not _multi or _slot_sprites[BattleModel.Side.FOE].is_empty():
		var plate: Rect2 = _player_strip.plate_rect()
		var top: float = plate.position.y
		if _hud != null and _hud.player_team != null and _hud.player_team.visible:
			top = minf(top, _hud.player_team.position.y)
		_field_badge.place(Vector2(maxf(plate.position.x, MARGIN), top - FieldBadge.HEIGHT - 2))
		return
	var below: float = _foe_strip.plate_rect().end.y
	var room: float = _field.size.x
	for row: Control in ([_hud.player_team, _hud.foe_team] if _hud != null else []):
		if row != null and row.visible and row.position.x < _field.size.x / 2.0:
			below = maxf(below, row.position.y + row.size.y)
	for sp: SpirlingSprite in _slot_sprites[BattleModel.Side.FOE]:
		if sp.position.y + sp.size.y > below:
			room = minf(room, sp.position.x - MARGIN - 2)
	_field_badge.place(Vector2(MARGIN, below + 2), room)

func _layout_field() -> void:
	if _multi and not _slot_sprites[BattleModel.Side.FOE].is_empty():
		_layout_formation()
		if _hud != null:
			_hud.layout_formation()
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
	if _stage != null:
		var fr: Rect2 = _stage.fit_sprite("foe", Vector2(w, h), _art_px(_foe_sprite, sprite))
		var pr: Rect2 = _stage.fit_sprite("player", Vector2(w, h), _art_px(_player_sprite, sprite))
		_foe_sprite.position = fr.position
		_foe_sprite.size = fr.size
		_player_sprite.position = pr.position
		_player_sprite.size = pr.size
	if _hud != null:
		_hud.layout_single()
	_backdrop.set_scene(backdrop, Rect2(_foe_sprite.position, _foe_sprite.size), Rect2(_player_sprite.position, _player_sprite.size))
	_backdrop.modulate = Color.WHITE.darkened(backdrop_shade) * BattleShow.night_tint(DayCycle.current(), GameState.day_night, outdoor, backdrop)

## Width of the art [param sp] draws (Era IV/V size it in whole multiples), [param fallback] before setup.
static func _art_px(sp: SpirlingSprite, fallback: float) -> float:
	return float(sp.texture().get_width()) if sp.texture() != null else fallback

## Era IV/V single battles: a Spirling just set up may bring art of another size, so it stands
## anew on its slab before it steps out.
func _restage() -> void:
	if _stage != null and not _multi:
		_layout_field()

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
	var tag_hs: Array[float] = [0.0, 0.0]
	for side: int in 2:
		if not _slot_strips[side].is_empty():
			tag_hs[side] = (_slot_strips[side][0] as MiniStrip).needed_height()
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		var n: int = _slot_sprites[side].size()
		var other: int = BattleModel.other(side)
		var tag_h: float = tag_hs[side]
		var slots: Array[Rect2] = formation_slots(EraManager.active_era(), side, n, Vector2(w, h), tag_h, _slot_sprites[other].size(), tag_hs[other])
		if _stage != null and side == BattleModel.Side.FOE and n > 0:
			var feet: float = Era4Stage.sprite_rect(EraManager.stage_config(), "foe", Vector2(w, h), slots[0].size.x).end.y
			slots = drop_to_floor(slots, feet, rects[BattleModel.Side.PLAYER].position.y - tag_h - 6)
		# A lone Rift boss stands bigger (KAMPF_PLAN_1000 655), clear of the player's rank.
		if side == BattleModel.Side.FOE and n == 1 and model != null and BattleRules.BOSSES.has(model.foe_boss):
			slots[0] = BattleShow.boss_rect(slots[0], EraManager.active_era(), rects[BattleModel.Side.PLAYER].position.y - tag_h - 6)
		for slot: int in n:
			var sp: SpirlingSprite = _slot_sprites[side][slot]
			sp.position = slots[slot].position
			sp.size = slots[slot].size
			var tag: MiniStrip = _slot_strips[side][slot]
			tag.position = sp.position + Vector2(-1, sp.size.y + 2)
			tag.size = Vector2(MiniStrip.WIDTH, tag_h)
		var r: Rect2 = Rect2()
		for q: Rect2 in slots:
			r = q if r.size == Vector2.ZERO else r.merge(q)
		rects[side] = r
	_backdrop.set_scene(backdrop, rects[BattleModel.Side.FOE], rects[BattleModel.Side.PLAYER])
	if _stage != null:
		_stage.fit_formation(rects[BattleModel.Side.FOE], rects[BattleModel.Side.PLAYER])

## Formation slots for [param n] Spirlings of [param side] in [param era] (data/era_battle_feel.json
## "formation_*"): Era I/II keep 28 px sprites in a flat rank, Era III 32 px, Era IV/V bigger
## sprites with every second one a step further back so the rank has depth (Era V triple battles
## stand in a shallow arc). Sprites shrink when the rank would not fit the field. With
## [param other_n] Spirlings on the other side (tags [param other_tag_h] high) the two ranks also
## never run into each other on a short field (formation_fit).
static func formation_slots(era: int, side: int, n: int, field: Vector2, tag_h: float, other_n: int = 0, other_tag_h: float = 0.0) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if n <= 0:
		return out
	var foe: bool = side == BattleModel.Side.FOE
	var gap: float = EraBattleFeel.num(era, "formation_gap", SLOT_GAP)
	var stagger: float = EraBattleFeel.num(era, "formation_stagger", 0.0)
	var fit: Dictionary = formation_fit(era, n if foe else other_n, other_n if foe else n, field, tag_h if foe else other_tag_h, other_tag_h if foe else tag_h)
	var px: float = float(fit.px) if other_n > 0 else floorf(minf(EraBattleFeel.num(era, "formation_slot", SLOT_SPRITE), (field.x - MARGIN * 2 - 4 - (n - 1) * gap) / n))
	var top: float = float(fit.foe_top) if other_n > 0 else float(MARGIN + FOE_RANK_TOP)
	var step: float = formation_step(px, gap)
	# A shrunken rank ends with its last tag, which is wider than its sprite.
	var total: float = formation_width(n, px, gap)
	var x0: float = field.x - MARGIN - total if foe else MARGIN + 4
	var y: float = top if foe else field.y - MARGIN - tag_h - 2 - px
	for slot: int in n:
		var back: float = 0.0
		if stagger > 0.0:
			# Odd slots step back; a rank of three bows its middle back (Era V triples).
			back = stagger if (slot % 2 == 1) else 0.0
		out.append(Rect2(Vector2(x0 + slot * step, y - back).round(), Vector2(px, px)))
	return out

## Width of a rank of [param n] with its tags: a shrunken sprite is narrower than its tag.
static func formation_width(n: int, px: float, gap: float) -> float:
	return (n - 1) * formation_step(px, gap) + (maxf(px, MiniStrip.WIDTH) if px < SLOT_SPRITE else px)

## Foe rank top under the ledger strip: the usual one leaves a line for the Back button, the
## tight one sits right under the strip.
const FOE_RANK_TOP: int = 44
const FOE_RANK_TOP_TIGHT: int = 36
## Smallest formation sprite; below this the ranks would be unreadable.
const SLOT_MIN: int = 12

## Distance from one slot to the next: sprite plus gap, but never less than a tag is wide, so
## the tags of shrunken sprites do not run into each other.
static func formation_step(px: float, gap: float) -> float:
	return maxf(px + gap, MiniStrip.WIDTH + 1.0) if px < SLOT_SPRITE else px + gap

## Sprite size and foe rank top that keep [param n_foe] foes and [param n_player] own Spirlings
## apart on [param field]: {"px", "foe_top"}. The era's size stays when both ranks fit under
## each other or stand clear side by side. On a short field (the command menu is open on the
## small Era I/II screen) the foe rank moves up under the strip and both ranks shrink just
## enough: to stand under each other, or beside each other, whichever keeps them bigger.
static func formation_fit(era: int, n_foe: int, n_player: int, field: Vector2, foe_tag_h: float, player_tag_h: float) -> Dictionary:
	var gap: float = EraBattleFeel.num(era, "formation_gap", SLOT_GAP)
	var stagger: float = EraBattleFeel.num(era, "formation_stagger", 0.0)
	var room: float = field.x - MARGIN * 2 - 4
	var px: float = EraBattleFeel.num(era, "formation_slot", SLOT_SPRITE)
	for n: int in [n_foe, n_player]:
		if n > 0:
			px = floorf(minf(px, (room - (n - 1) * gap) / n))
	var top: float = MARGIN + FOE_RANK_TOP
	if n_foe <= 0 or n_player <= 0:
		return {"px": px, "foe_top": top}
	# Height both ranks need besides the two sprites: tags, the 2 px above each tag, a 2 px
	# lane between the ranks, the bottom margin and the step back of the staggered eras.
	var extra: float = foe_tag_h + player_tag_h + 2 + 2 + 2 + MARGIN + stagger
	var beside: float = px
	while beside > SLOT_MIN and formation_width(n_foe, beside, gap) + gap + formation_width(n_player, beside, gap) > room:
		beside -= 1.0
	if top + px * 2.0 + extra <= field.y or px <= beside:
		return {"px": px, "foe_top": top}
	var tight: float = MARGIN + FOE_RANK_TOP_TIGHT + stagger
	var under: float = floorf((field.y - tight - extra) / 2.0)
	if under >= beside:
		return {"px": maxf(minf(px, under), SLOT_MIN), "foe_top": tight}
	return {"px": maxf(minf(px, beside), SLOT_MIN), "foe_top": top}

## Era IV/V stage: the foe rank stands on the floor, not in the sky. Moves [param foes] down so
## the lowest feet reach [param feet_y] (the foe slab), but never into [param limit_y] (the top
## of the player's rank, less the room the foe tags need).
static func drop_to_floor(foes: Array[Rect2], feet_y: float, limit_y: float) -> Array[Rect2]:
	var low: float = 0.0
	for r: Rect2 in foes:
		low = maxf(low, r.end.y)
	var by: float = roundf(maxf(minf(feet_y, limit_y) - low, 0.0))
	var out: Array[Rect2] = []
	for r: Rect2 in foes:
		out.append(Rect2(r.position + Vector2(0, by), r.size))
	return out

## Shows [param side]/[param slot]'s details in the ledger strip (formation layout).
func _focus(side: int, slot: int) -> void:
	if not _multi:
		return
	var s: Spirling = model.active_spirling(side, slot)
	if s == null:
		return
	_foe_strip.show_numbers = side == BattleModel.Side.PLAYER
	_foe_strip.show_xp = side == BattleModel.Side.PLAYER
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
	_weather.setup(BattleWeather.weather_of(model), EraManager.active_era())
	_apply_speed()
	Sound.music(Sound.battle_music(music_track))
	# A Trial comes started (its Energy is set after the start); a restart skips its lines.
	var intro: Array[BattleEvent] = BattlePuzzle.intro_events(model) if model.has_meta("intro") else model.start()
	if _multi:
		_build_formation()
	if not model.has_meta("quick") and not model.has_meta("intro"):
		await _play_intro()
	await _play(intro)
	if model.has_meta("bonus_goal") and not model.has_meta("quick"):
		await _text.show_text(str(model.get_meta("bonus_goal")))
	# Difficulty and challenge rules of a Warden battle or a run with rules (KAMPF plan 495).
	if model.has_meta("challenge_line") and not model.has_meta("quick"):
		await _text.show_text(str(model.get_meta("challenge_line")))
	if model.is_wild and not model.bond_block.is_empty() and not model.has_meta("quick"):
		await _text.show_text(Loc.t(model.bond_block))
	_refresh_goal()
	var tip_ids: Array[String] = ["battle"]
	if model.is_wild:
		tip_ids.append("bond")
	if _multi:
		tip_ids.append("multi")
	for id: String in tip_ids:
		for line: String in Tips.take(id):
			await _text.show_text(line)
	_replaying = not replay_inputs.is_empty()
	while not model.is_finished() and not BattlePuzzle.out_of_turns(model):
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
			if _puzzle_restart(actions.back() if not actions.is_empty() else null):
				break
			inputs.append(BattleReplay.actions_to_dict(actions))
			await _play(model.submit_actions(actions))
			_refresh_goal()
			continue
		var action: BattleAction = await _choose_action()
		if action == null:
			continue
		if _puzzle_restart(action):
			break
		inputs.append(BattleReplay.action_to_dict(action))
		await _play(model.submit_turn(action))
		_refresh_goal()
	_refresh_goal()
	# The report card (KAMPF_PLAN_1000 661); a quick battle goes straight on.
	if model.is_finished() and not model.has_meta("quick"):
		await _show.play_outro(BattleShow.outro_lines(report, model.turn))
	# Comfort tips after the first battle that was really played (item 631).
	if not _replaying and not model.has_meta("quick") and not inputs.is_empty():
		for line: String in Tips.take("battle_comfort"):
			await _text.show_text(line)
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
	_menu.prefer_row = int(_last_art.get(slot, -1))
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
					aim = await _pick_target("Aim %s at?" % me.moves[index].move_name, me, me.moves[index], slot)
					if aim == -2:
						return null
					_last_aim = aim
				_last_art[slot] = index
				return BattleAction.make_move(BattleModel.Side.PLAYER, index, slot, aim)
			return BattleAction.make_rest(BattleModel.Side.PLAYER, slot)
		BattleAction.Kind.SWAP:
			var idx: int = await _pick_party("Swap to?", true, slot, taken)
			return null if idx < 0 else BattleAction.make_swap(BattleModel.Side.PLAYER, idx, slot)
		BattleAction.Kind.ITEM:
			return await _pick_item(slot, EraBattleHud.last_item if index >= 0 else "")
		BattleAction.Kind.BOND:
			if not model.is_wild:
				return BattleAction.make_oath(BattleModel.Side.PLAYER, slot)
			return await _bond(slot)
		BattleAction.Kind.RUN:
			return BattleAction.make_run(BattleModel.Side.PLAYER, slot)
	return null

## Lets the player tap the foe to aim at. Returns the foe slot, -1 when there is no choice
## (1v1 or a single foe left), or -2 when the player backs out.
func _pick_target(title: String, me: Spirling = null, mv: MoveData = null, from_slot: int = 0) -> int:
	var foes: Array[int] = model.standing_slots(BattleModel.Side.FOE)
	if not _multi or foes.size() <= 1:
		return -1 if foes.is_empty() else foes[0]
	_text.show_prompt(title)
	for slot: int in foes:
		var sp: SpirlingSprite = _slot_sprites[BattleModel.Side.FOE][slot]
		var b := Button.new()
		b.flat = true
		# The map pin marks the target; the theme's dark focus box would hide the Spirling.
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.position = sp.position - Vector2(2, 2)
		b.size = sp.size + Vector2(4, 14)
		b.accessibility_name = MultiRules.slot_spoken(model, BattleModel.Side.FOE, slot)
		var picked: int = slot
		b.pressed.connect(func() -> void:
			Sound.sfx("confirm")
			_target_picked.emit(picked))
		b.focus_entered.connect(func() -> void:
			_text.show_prompt(Loc.t(title) + BattleInfo.target_preview(model, me, model.active_spirling(BattleModel.Side.FOE, picked), mv))
			_focus(BattleModel.Side.FOE, picked)
			_point_pin(BattleModel.Side.FOE, picked, true)
			# Under a team guard or against the back row the line adds the guard and row factor.
			var extra: float = MultiRules.guard_mult(model, BattleModel.Side.FOE) * MultiRules.row_mult(model, BattleModel.Side.PLAYER, from_slot, BattleModel.Side.FOE, picked, mv) if mv != null else 1.0
			if me != null and extra < 0.999:
				_text.show_prompt(title + "\n" + _aim_line(me, mv, picked, from_slot)))
		b.mouse_entered.connect(b.grab_focus)
		_field.add_child(b)
		_target_buttons.append(b)
	for i: int in _target_buttons.size():
		var b: Button = _target_buttons[i]
		b.focus_neighbor_left = _target_buttons[i - 1].get_path() if i > 0 else b.get_path()
		b.focus_neighbor_right = _target_buttons[i + 1].get_path() if i < _target_buttons.size() - 1 else b.get_path()
	_target_buttons[BattleInfo.aim_start(foes, _last_aim)].grab_focus()
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
	var foes: Array[int] = model.standing_slots(BattleModel.Side.FOE)
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, foes[0]) if foes.size() == 1 else null
	var candidates: Array[int] = []
	for i: int in model.swap_candidates(BattleModel.Side.PLAYER, slot):
		if not i in taken:
			candidates.append(i)
	# Outside a forced switch an ally in another slot can trade places (item 366).
	if cancellable:
		for i: int in MultiRules.shift_targets(model, BattleModel.Side.PLAYER, slot):
			if not i in taken:
				candidates.append(i)
	for i: int in party.size():
		if model.is_partner_index(BattleModel.Side.PLAYER, i):
			continue
		var s: Spirling = party[i]
		entries.append({"text": "%s R%d %d/%d%s" % [s.display_name(), s.level, s.hp, s.max_hp(), BattleInfo.switch_tag(s, foe)], "disabled": not i in candidates,
			"hint": BattleGuide.compare_line(s, model.active_spirling(BattleModel.Side.PLAYER, slot))})
	while true:
		var idx: int = await _picker.pick(title, entries, cancellable)
		if idx < 0 or idx in candidates:
			return idx
	return -1

## [param preset] (the item shortcut, Era IV on) uses that item on the active Spirling at once.
func _pick_item(slot: int = 0, preset: String = "") -> BattleAction:
	var ids: Array[String] = []
	var entries: Array[Dictionary] = []
	for id: String in model.bag_ids(BattleModel.Side.PLAYER):
		var it: Dictionary = Database.item(id)
		if bool(it.get("battle", false)) and model.item_left_this_battle(BattleModel.Side.PLAYER, id):
			ids.append(id)
			entries.append({"text": "%s x%d" % [it.get("name", id), model.bag_count(BattleModel.Side.PLAYER, id)], "hint": str(it.get("description", ""))})
	if ids.is_empty():
		await _text.show_text("No usable items.")
		return null
	var idx: int = ids.find(preset) if not preset.is_empty() else await _picker.pick("Use which item?", entries)
	if idx < 0:
		return null
	if BattleModel.is_revive_item(ids[idx]):
		var down: int = await _pick_defeated()
		if down < 0:
			return null
		var r := BattleAction.make_item(BattleModel.Side.PLAYER, ids[idx], down, slot)
		return r if model.is_legal(r) else null
	var own: int = model.active_index(BattleModel.Side.PLAYER, slot)
	var target: int = await _pick_party("Use on?", true, slot) if model.party(BattleModel.Side.PLAYER).size() > 1 and preset.is_empty() else own
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
		if int(bag[id]) > 0 and (float(it.get("bond_bonus", 0.0)) > 0.0 or bool(it.get("bond_sure", false)) or bool(it.get("bond_retry", false))
				or bool(it.get("bond_wish", false))):
			out.append(str(id))
	out.sort_custom(func(a: String, b: String) -> bool: return a == "kin_charm" or (b != "kin_charm" and a < b))
	return out

func _bond(slot: int = 0) -> BattleAction:
	# Steps 3 and 4 of the bonding tutorial come when they are needed, not at battle start.
	for line: String in Tips.take(Tips.bond_how_id()):
		await _text.show_text(line)
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
	var mine: bool = GameState.bond_style == "mine"
	var reach: String = "Reach out to %s... Tap Mine! fast!" if mine else "Reach out to %s... Listen, then echo its call!"
	await _text.show_text(reach % model.active_spirling(BattleModel.Side.FOE, target_slot).display_name())
	_bond_game.target = _sprite(BattleModel.Side.FOE, target_slot).texture()
	_bond_game.target_name = model.active_spirling(BattleModel.Side.FOE, target_slot).display_name()
	var foe: Spirling = model.active_spirling(BattleModel.Side.FOE, target_slot)
	var key: String = foe.uid if not foe.uid.is_empty() else str(foe.get_instance_id())
	if not _bond_plans.has(key):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var state: String = BondEcho.rift_state(GameState.current_map, GameState.rifts_sealed)
		_bond_plans[key] = BondEcho.make_plan(rng, foe.data, state)
	var score: float = 0.0
	_bond_game.calm = GameState.bond_style == "calm"
	if mine:
		score = await _bond_game.run_mine(_bond_plans[key])
	else:
		score = await _bond_game.run(_bond_plans[key])
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
		# Resonance fields and boss phases explain themselves the first time (item 585).
		var tip: String = BattleInfo.tip_for(events[i])
		if not tip.is_empty() and not _replaying:
			for line: String in Tips.take(tip):
				await _text.show_text(line)
	_playing = []
	_field_badge.sync(model)
	_place_field_badge()

## The event list being played and the current position, so an art can look ahead at how
## its first hit turns out (items 2375, 2376).
var _playing: Array[BattleEvent] = []
var _play_index: int = -1

## How the art at [param at] in [param events] lands on its first target: "miss" when the
## first result is a MISSED event, and "eff" (effectiveness) of the first damage. Looks only
## until the next art.
## Hit-stop for the battle's last hit (item 2265).
const FINAL_HITSTOP: float = 0.12

## Hit-stop for the hit at [param at]: "final" for the hit that ends the battle (nothing but
## faints and the end follow), "" for a middle hit of an art that strikes several times this
## turn (only the first and last stop, item 2266), otherwise "normal".
static func hitstop_kind(events: Array[BattleEvent], at: int) -> String:
	if at < 0 or at >= events.size():
		return "normal"
	var e: BattleEvent = events[at]
	var hits: Array[int] = []
	var start: int = 0
	for i: int in range(at, -1, -1):
		if events[i].type == BattleEvent.Type.MOVE_USED:
			start = i
			break
	for i: int in range(start, events.size()):
		var x: BattleEvent = events[i]
		if i > start and x.type == BattleEvent.Type.MOVE_USED:
			break
		if x.type == BattleEvent.Type.DAMAGE and not bool(x.data.get("status_tick", false)):
			hits.append(i)
	if int(e.data.get("hp", 1)) <= 0:
		for i: int in range(at + 1, events.size()):
			var t: int = events[i].type
			if t == BattleEvent.Type.BATTLE_END:
				return "final"
			if t == BattleEvent.Type.DAMAGE or t == BattleEvent.Type.MOVE_USED:
				break
	if hits.size() > 2 and at != hits[0] and at != hits[-1]:
		return ""
	return "normal"

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
	BattleInfo.note(_seen_arts, e)
	if e.type == BattleEvent.Type.MOVE_USED and int(e.data.get("side", -1)) == BattleModel.Side.PLAYER:
		_last_art_name = str(e.data.get("move", ""))
		_last_user_name = str(e.data.get("name", ""))
	BattleInfo.count(report, e, _last_art_name, _last_user_name)
	log_entries.append(BattleInfo.entry(e))
	if e.type == BattleEvent.Type.BATTLE_END and model != null:
		for l: String in BattleInfo.report_lines(report, model.turn):
			log_entries.append({"text": l, "kind": "other", "side": -1})
	while log_entries.size() > BattleInfo.ENTRY_KEEP:
		log_entries.pop_front()
	var line: String = e.describe()
	if line.is_empty():
		return
	log_lines.append(line)
	while log_lines.size() > LOG_KEEP:
		log_lines.pop_front()

## The rule variants in play as a list for the top of the log panel (item 796), "" without any.
static func variant_list(m: BattleModel) -> String:
	if m == null or m.variants.is_empty():
		return ""
	var all: Dictionary = BattleRules.variants()
	var lines: Array[String] = [Loc.t("Rule variants")]
	for id: String in m.variants:
		var v: Dictionary = all.get(id, {})
		lines.append("- %s: %s" % [Loc.t(str(v.get("label", id))), Loc.t(str(v.get("text", "")))])
	return "\n".join(lines) + "\n\n"

var _photo_button: Button
## The open photo mode, null otherwise.
var photo: PhotoMode

## Opens the photo mode over the battle (662); B closes it and the battle goes on.
func open_photo() -> void:
	if photo != null:
		return
	_log_panel.visible = false
	photo = PhotoMode.new()
	photo.capture_gui = true
	photo.place = Loc.t("Battle")
	add_child(photo)
	await photo.finished
	if is_instance_valid(photo):
		photo.queue_free()
	photo = null

func _toggle_log() -> void:
	Sound.sfx("confirm")
	_log_filter = "all"
	_fill_log()
	_log_panel.visible = not _log_panel.visible

## Log text for the filter in use: rule variants, the battle facts, then the matching lines.
func _fill_log() -> void:
	_log_filter_button.text = BattleInfo.filter_row(_log_filter)
	var lines: Array[String] = BattleInfo.filter_lines(log_entries, _log_filter, LOG_KEEP)
	_log_label.text = variant_list(model) + BattleInfo.facts(model, _seen_arts) + "\n\n" + Loc.t("Battle log") + "\n\n" \
		+ ("\n".join(lines) if not lines.is_empty() else Loc.t("Nothing yet.")) + "\n\n" + Loc.t("(tap to close)")

## A Gleam steps out: the sound cue and the sparkle (data/gleam.json).
func _gleam_entrance(sprite: SpirlingSprite) -> void:
	var cfg: Dictionary = GleamRules.config()
	Sound.sfx(str(cfg.get("sfx", "sparkle")), 0.0, float(cfg.get("sfx_pitch", 1.0)))
	await sprite.gleam_sparkle()

func _play_event(e: BattleEvent) -> void:
	var side: int = int(e.data.get("side", 0))
	var slot: int = int(e.data.get("slot", 0))
	record(e)
	_hud.on_event(e)
	_show.on_event(e)
	_field_badge.on_event(e)
	_place_field_badge()
	if e.type == BattleEvent.Type.BATTLE_START:
		battle_report.begin(model.field)
	battle_report.add(e)
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
						if model.active_spirling(BattleModel.Side.FOE, fs).gleam:
							await _gleam_entrance(_sprite(BattleModel.Side.FOE, fs))
				await _text.show_text(e.describe())
				return
			_foe_sprite.setup(foe, "front")
			_restage()
			_foe_strip.set_spirling(foe)
			if music_track == "warden":
				# A Rift Warden shakes the field as it appears (item 2256).
				Juice.add_trauma(era_trauma(Juice.TRAUMA_WARDEN))
				Haptics.play("heavy")
			if model.is_wild:
				_foe_strip.visible = true
				Sound.cry(foe.data)
				await _foe_sprite.step_out(true)
				if foe.gleam:
					await _gleam_entrance(_foe_sprite)
			await _text.show_text(e.describe())
		BattleEvent.Type.SEND_OUT, BattleEvent.Type.SWAP_IN:
			var s: Spirling = model.party(side)[int(e.data.get("index", 0))]
			_sprite(side, slot).setup(s, "back" if side == BattleModel.Side.PLAYER else "front")
			_restage()
			_strip(side, slot).set_spirling(s)
			_strip(side, slot).visible = true
			_focus(side, slot)
			# The player's own Spirling keeps the cry of the era it was met in.
			Sound.cry(s.data, Sound.cry_era_for(s.origin_era, side == BattleModel.Side.PLAYER, EraManager.active_era()))
			_era_fx("sendout", side, slot)
			BattleCamera.sendout(_shake_root, Rect2(_sprite(side, slot).position, _sprite(side, slot).size))
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
			await _float(side, slot, e.describe())
			var dir: Vector2 = Vector2(-8, -4) if side == BattleModel.Side.PLAYER else Vector2(8, 4)
			if _multi:
				dir = Vector2(0, -6) if side == BattleModel.Side.PLAYER else Vector2(0, 6)
			await _play_art(e, side, slot, dir)
			_pin.visible = false
		BattleEvent.Type.DAMAGE:
			var hit: String = _hit_sound(e)
			# Louder the more strength the hit took (item 2532).
			var lost: float = float(e.data.get("amount", 0)) / maxf(float(e.data.get("max_hp", 1)), 1.0)
			if hit == "hit" or hit == "hit_strong":
				Sound.element_hit(_last_element[BattleModel.other(side)], lost)
			if hit != "hit":
				Sound.sfx(hit, Sound.hit_volume_db(lost))
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
				await _float(side, slot, line)
		BattleEvent.Type.HEAL:
			Sound.sfx("heal")
			var heal_slot: int = model.slot_of(side, int(e.data.get("index", -1)))
			if heal_slot >= 0:
				await _strip(side, heal_slot).animate_hp(int(e.data.hp), int(e.data.max_hp))
				_refresh_focus(side, heal_slot)
			_update_pinch()
			await _float(side, maxi(heal_slot, 0), e.describe())
		BattleEvent.Type.ENERGY_CHANGED:
			var es: Variant = _strip(side, slot)
			if side == BattleModel.Side.PLAYER and es is InfoStrip:
				var ticks: int = Sound.energy_ticks(int(e.data.energy) - (es as InfoStrip).energy)
				if ticks > 0:
					Sound.energy_tick(ticks)
			_strip(side, slot).set_energy(int(e.data.energy))
			_refresh_focus(side, slot)
		BattleEvent.Type.ENERGY_TAX:
			var ts: Variant = _strip(side, slot)
			if ts is InfoStrip:
				(ts as InfoStrip).set_tax(int(e.data.get("turns", 0)))
			var tax_text: String = e.describe()
			if not tax_text.is_empty():
				await _float(side, slot, tax_text)
		BattleEvent.Type.STATUS_APPLIED:
			BattleAudio.play(BattleAudio.status_sound(str(e.data.status)))
			_strip(side, slot).set_status(str(e.data.status))
			_refresh_focus(side, slot)
			await _float(side, slot, e.describe())
			if side == BattleModel.Side.PLAYER and not _replaying:
				var tip: String = BattleGuide.first_status_tip(str(e.data.status), GameState.flags)
				await _float(side, slot, tip)
		BattleEvent.Type.STAT_CHANGED:
			var who: Spirling = model.active_spirling(side, slot)
			var st: Variant = _strip(side, slot)
			if st is InfoStrip and who != null:
				(st as InfoStrip).set_stages(who.stages)
			_refresh_focus(side, slot)
			if int(e.data.get("delta", 0)) != 0:
				BattleAudio.play(BattleAudio.stage_sound(int(e.data.delta)), 0.0, BattleAudio.stage_pitch(int(e.data.get("stage", 0))))
				_era_fx("stat_up" if int(e.data.delta) > 0 else "stat_down", side, slot)
			await _float(side, slot, e.describe())
		BattleEvent.Type.STATUS_CURED:
			_strip(side, slot).set_status("")
			_refresh_focus(side, slot)
			await _float(side, slot, e.describe())
		BattleEvent.Type.FAINTED:
			Sound.sfx("faint")
			Juice.add_trauma(era_trauma(Juice.TRAUMA_FAINT))
			_era_fx("faint_motes", side, slot)
			await _sprite(side, slot).faint()
			await _text.show_text(e.describe())
			_strip(side, slot).visible = false
		BattleEvent.Type.LEVEL_UP:
			Sound.sfx("level_up")
			var lv_slot: int = model.slot_of(BattleModel.Side.PLAYER, int(e.data.get("index", -1)))
			if lv_slot >= 0:
				var lv_sprite: SpirlingSprite = _sprite(BattleModel.Side.PLAYER, lv_slot)
				var lv_era: int = EraManager.active_era()
				if lv_sprite != null and lv_sprite.visible and EraBattleFeel.text(lv_era, "level_up", "ring") != "text":
					LevelRing.spawn(_shake_root, lv_sprite.position + lv_sprite.size / 2.0)
					lv_sprite.glints(int(EraBattleFeel.num(lv_era, "level_glints", 0)))
				var lst: Variant = _strip(BattleModel.Side.PLAYER, lv_slot)
				if lst is InfoStrip:
					(lst as InfoStrip).set_level(int(e.data.level))
					_refresh_xp(lv_slot, int(e.data.get("index", -1)))
				await lst.animate_hp(int(e.data.hp), int(e.data.max_hp))
			_hud.show_level(e)
			await _text.show_text(e.describe())
			_hud.hide_level()
		BattleEvent.Type.BOND_RESULT:
			if bool(e.data.get("success", false)):
				Sound.sfx("bond")
				var bonded: SpirlingSprite = _sprite(BattleModel.Side.FOE, slot)
				var bond_era: int = EraManager.active_era()
				await bonded.bond_rings()
				if EraBattleFeel.text(bond_era, "bond", "hop") == "blink_out":
					await bonded.blink_out()
				else:
					bonded.glints(int(EraBattleFeel.num(bond_era, "bond_glints", 0)))
					await bonded.greet_hop()
				await bonded.step_back(false)
				_strip(BattleModel.Side.FOE, slot).visible = false
			await _text.show_text(e.describe())
		BattleEvent.Type.RULE:
			var turning: bool = bool(e.data.get("turning", false))
			_rule_banner.show_rule(Loc.t(str(e.data.get("label", ""))), turning, _field.size.x, _field.size.y * 0.42,
				str(e.data.get("symbol", "")))
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
			# Each Spirling's share and the fields go under the battle report of the log.
			for line: String in battle_report.lines().slice(1):
				log_entries.append({"text": line, "kind": "other", "side": -1})
			if _multi and outcome == BattleModel.Outcome.WIN and battle_report.best() >= 0:
				await _text.show_text(battle_report.best_line())
		BattleEvent.Type.MISSED:
			# The target sidesteps while the line shows (item 2337).
			var t_side: int = BattleModel.other(side)
			var t_slot: int = int(e.data.get("target_slot", 0))
			var target: SpirlingSprite = _sprite(t_side, t_slot)
			# A soft rush of air past the target and a quick swish as it steps aside (items
			# 2531, 2536).
			Sound.sfx("miss")
			if target != null and target.visible:
				BattleAudio.play("dodge")
				target.dodge(dodge_dir(t_side))
			var miss_text: String = e.describe()
			if not miss_text.is_empty():
				await _float(t_side, t_slot, miss_text)
		BattleEvent.Type.XP_GAINED:
			var xp_slot: int = model.slot_of(BattleModel.Side.PLAYER, int(e.data.get("index", -1)))
			if xp_slot >= 0:
				_refresh_xp(xp_slot, int(e.data.get("index", -1)))
			await _float(BattleModel.Side.PLAYER, maxi(xp_slot, 0), e.describe())
		BattleEvent.Type.SUPPORT when str(e.data.get("kind", "")) == "shift":
			# Two of your Spirlings trade places (item 366): both slots show their new Spirling.
			for at: int in [slot, int(e.data.get("other", slot))]:
				var sp: Spirling = model.active_spirling(side, at)
				if sp != null:
					_sprite(side, at).setup(sp, "back" if side == BattleModel.Side.PLAYER else "front")
					_strip(side, at).set_spirling(sp)
			_restage()
			Sound.sfx("run")
			await _text.show_text(e.describe())
		_:
			var text: String = e.describe()
			if not text.is_empty():
				await _text.show_text(text)

## The era's battle opening (BattleIntro): the cover clears in the era's pattern; Era V also
## swoops the field back from the foe.
func _play_intro() -> void:
	var era: int = EraManager.active_era()
	var cover := BattleIntro.new()
	add_child(cover)
	if EraBattleFeel.text(era, "intro") == "swoop":
		BattleCamera.swoop_in(_shake_root, Rect2(_foe_sprite.position, _foe_sprite.size))
	# A rematch keeps only a short opening (BattleShow, plan 660).
	await cover.play(era, BattleShow.intro_share_for(model))
	BattleShow.note_intro(model)
	intro_style_played = cover.style

## The intro style the last opening played (tests).
var intro_style_played: String = ""

## Shake for [param amount] scaled by the era: small in Era I, strongest in Era V.
static func era_trauma(amount: float) -> float:
	return amount * EraBattleFeel.shake(EraManager.active_era())

## Shows a short line floating over the Spirling at [param side]/[param slot] instead of a text
## box (owner, 9 Nov: fewer text windows, show it in the fight). Lines without a visible
## Spirling fall back to the text box. The battle log keeps every line.
func _float(side: int, slot: int, text: String) -> void:
	if text.is_empty():
		return
	var sp: SpirlingSprite = _sprite(side, slot)
	if sp == null or not sp.visible or not is_inside_tree():
		await _text.show_text(text)
		return
	var stack: int = 0
	for n: Node in _shake_root.get_children():
		if n is FloatText and not n.is_queued_for_deletion() and int(n.get_meta("side", -1)) == side:
			stack += 1
	var f: FloatText = FloatText.spawn(_shake_root, text, sp.position + Vector2(sp.size.x / 2.0, 0), stack)
	if f != null:
		f.set_meta("side", side)
	floats_shown += 1
	await get_tree().create_timer(FloatText.GAP / Juice.speed()).timeout

## Battle lines shown as floats so far (tests).
var floats_shown: int = 0

## Redraws the EXP bar of the player strip at [param slot] from party member [param index].
func _refresh_xp(slot: int, index: int) -> void:
	var st: Variant = _strip(BattleModel.Side.PLAYER, slot)
	var party: Array = model.parties[BattleModel.Side.PLAYER]
	if st is InfoStrip and index >= 0 and index < party.size():
		(st as InfoStrip).set_xp(party[index] as Spirling)

## Wind-up, charge and travel sounds and the element effect for an art (items 2329 to 2366, 2529, 2530).
func _play_art(e: BattleEvent, side: int, slot: int, dir: Vector2) -> void:
	var kind: int = int(e.data.get("kind", MoveData.Kind.PHYSICAL))
	var element: int = int(e.data.get("element", -1))
	var user: SpirlingSprite = _sprite(side, slot)
	BattleAudio.play(charge_sound(kind))
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
	_fx.feel = EraBattleFeel.move_anim(mv, EraManager.active_era()) if mv != null else {}
	if str(_fx.feel.get("style", "")) == "quake" and int(_fx.feel.get("tier", 1)) >= 4 and kind != MoveData.Kind.STATUS:
		Juice.add_trauma(era_trauma(0.1), element)
	if kind != MoveData.Kind.PHYSICAL and target != user:
		_fx_travel_sound.call_deferred(element)
	var outcome: Dictionary = art_outcome(_playing, _play_index) if _play_index >= 0 else {}
	# In the formation layout the user turns toward a target on the other half (item 2336).
	var was_mirrored: bool = user.mirrored
	if _multi and target != user:
		var turn: int = turn_toward(user.position.x + user.size.x / 2.0, target.position.x + target.size.x / 2.0, _field.size.x / 2.0)
		if turn != 0:
			user.mirrored = turn > 0
			user.queue_redraw()
	if target != user:
		BattleCamera.push(_shake_root, Rect2(user.position, user.size), Rect2(target.position, target.size))
	await _fx.play(element, kind, Rect2(user.position, user.size), Rect2(target.position, target.size),
		bool(outcome.get("miss", false)), ElementFx.impact_scale(float(outcome.get("eff", 1.0))), _art_amount(e),
		ElementFx.after_for(mv), str(sym.symbol), second)
	BattleCamera.release(_shake_root)
	if user.mirrored != was_mirrored:
		user.mirrored = was_mirrored
		user.queue_redraw()

## Which way an attacker at x [param from_x] turns for a target at [param to_x]: 1 to face
## right, -1 to face left, 0 to stay when both stand on the same half split at [param mid].
static func turn_toward(from_x: float, to_x: float, mid: float) -> int:
	if (from_x < mid) == (to_x < mid):
		return 0
	return 1 if to_x > from_x else -1

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
	BattleAudio.play(travel_sound(element))

static func travel_sound(element: int) -> String:
	return "travel_" + String(Elements.E.keys()[element]).to_lower()

## Shake, vibration, hit-stop, knockback and flash for a landed hit (items 2256 to 2258, 2332, 2591).
func _hit_feedback(e: BattleEvent, side: int, slot: int, strong: bool) -> void:
	Juice.add_trauma(era_trauma(Juice.TRAUMA_HIT_STRONG if strong else Juice.TRAUMA_HIT), _last_element[BattleModel.other(side)])
	Haptics.play("heavy" if strong else "hit")
	var max_hp: int = maxi(int(e.data.get("max_hp", 1)), 1)
	match hitstop_kind(_playing, _play_index) if _play_index >= 0 else "normal":
		"final":
			await Juice.hitstop(1.0, FINAL_HITSTOP)
		"normal":
			# A keen hit holds a little longer (plan 644).
			await Juice.hitstop(float(e.data.get("amount", 0)) / max_hp, BattleShow.crit_hitstop() if bool(e.data.get("crit", false)) else -1.0)
	var sp: SpirlingSprite = _sprite(side, slot)
	_era_fx("hitmark", side, slot)
	sp.knockback(knockback_dir(side, _multi))
	await sp.hit_flash()

## The era's small effect of [param kind] over the Spirling at [param side]/[param slot]
## (EraMoveFx: send-out burst, hit mark, stat arrows, faint motes). Never waited for.
func _era_fx(kind: String, side: int, slot: int) -> void:
	var sp: SpirlingSprite = _sprite(side, slot)
	if sp != null:
		EraMoveFx.spawn(_shake_root, kind, EraManager.active_era(), Rect2(sp.position, sp.size))

## A dodging Spirling steps toward the outer screen edge: the foe right, the player left.
static func dodge_dir(target_side: int) -> float:
	return 1.0 if target_side == BattleModel.Side.FOE else -1.0

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
	var track: String = Sound.battle_music(pinch_track(lowest, music_track))
	if Sound.current_track != track:
		Sound.music(track)
	var foe_low: float = 1.0
	for fs: int in model.slot_count(BattleModel.Side.FOE):
		var f: Spirling = model.active_spirling(BattleModel.Side.FOE, fs)
		if f != null and not f.is_fainted():
			foe_low = minf(foe_low, f.hp_fraction())
	# Low-health alarm and the Era V battle layers (docs/ERA_FEEL_AUDIO.md).
	Sound.battle_state(lowest.hp_fraction() if lowest != null and not lowest.is_fainted() else 1.0, foe_low)

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
