class_name BattleHud
extends Node
## Places and dresses the battle HUD in the look of the era on screen (EraBattleHud,
## docs/ERA_FEEL_HUD.md): where the plates, the small buttons and the team rows go, the frame
## of the battle text box, the ring-rise panel and the lean of the Era V plates after the
## camera. BattleScene keeps the battle flow; this node only reads it.

var scene: BattleScene
var era: int = 1
var player_team: TeamRow
var foe_team: TeamRow
var level_panel: LevelPanel

## Hooks the HUD onto [param p_scene] once its controls exist (end of BattleScene._build).
func attach(p_scene: BattleScene) -> void:
	scene = p_scene
	era = EraManager.active_era()
	scene.add_child(self)
	scene._text.custom_minimum_size = Vector2(0, EraBattleHud.text_box_height(era))
	scene._text.draw.connect(_draw_text_frame)
	for panel: Control in [scene._picker, scene._log_panel]:
		if not EraBattleHud.skin_api():
			panel.add_theme_stylebox_override("panel", EraBattleHud.frame_style(era))
	player_team = TeamRow.new()
	foe_team = TeamRow.new()
	foe_team.title = "Foe's team"
	for row: TeamRow in [player_team, foe_team]:
		row.era = era
		row.visible = false
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene._field.add_child(row)
	level_panel = LevelPanel.new()
	level_panel.visible = false
	level_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(level_panel)
	for b: Button in [scene._ff_button, scene._auto_button, scene._log_button, scene._back_button]:
		b.clip_text = true
		# Thin side margins, so "Auto" fits a small button.
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBox = UITheme.get_theme().get_stylebox(state, "Button").duplicate()
			sb.content_margin_left = 1
			sb.content_margin_right = 1
			b.add_theme_stylebox_override(state, sb)
	# While aiming, Back stands where Log stood (one place fewer on a small screen).
	scene._back_button.text = "<"
	scene._back_button.accessibility_name = Loc.t("Back")
	scene._back_button.visibility_changed.connect(func() -> void:
		scene._log_button.visible = not scene._back_button.visible)
	scene._goal_label.clip_text = true

func _place(n: Control, r: Rect2) -> void:
	n.position = r.position
	n.size = r.size

## Team members that count for a side's row (the ally Wayfarer's Spirlings are not ours).
func _team(side: int) -> Array:
	var out: Array = []
	if scene.model == null:
		return out
	var party: Array = scene.model.party(side)
	for i: int in party.size():
		if not scene.model.is_partner_index(side, i):
			out.append(party[i])
	return out

func _team_size() -> int:
	return maxi(maxi(_team(BattleModel.Side.PLAYER).size(), _team(BattleModel.Side.FOE).size()), 1)

## One-on-one layout: called by BattleScene._layout_field after the stage placed the sprites
## and before the backdrop reads them (Era I-III move the foe so no plate covers it).
func layout_single() -> void:
	var f: Vector2 = scene._field.size
	var l: Dictionary = EraBattleHud.single_layout(era, f, Rect2(scene._foe_sprite.position, scene._foe_sprite.size),
		Rect2(scene._player_sprite.position, scene._player_sprite.size), _team_size())
	scene._foe_sprite.position = (l.foe_sprite as Rect2).position
	scene._player_sprite.position = (l.player_sprite as Rect2).position
	scene._foe_strip.slant_left = bool(l.foe_slant_left)
	scene._player_strip.slant_left = bool(l.player_slant_left)
	scene._foe_strip.single = true
	scene._player_strip.single = true
	_place(scene._foe_strip, l.foe_plate)
	_place(scene._player_strip, l.player_plate)
	var buttons: Array = l.buttons
	_place(scene._ff_button, buttons[0])
	_place(scene._auto_button, buttons[1])
	_place(scene._log_button, buttons[2])
	_place(scene._goal_label, l.goal)
	for row: TeamRow in [player_team, foe_team]:
		row.compact = false
	_place(player_team, l.player_team)
	_place(foe_team, l.foe_team)

## Formation layout (several Spirlings per side): called after BattleScene._layout_formation.
func layout_formation() -> void:
	var f: Vector2 = scene._field.size
	var l: Dictionary = EraBattleHud.formation_layout(era, f.x, _team_size())
	scene._foe_strip.slant_left = false
	scene._foe_strip.single = false
	_place(scene._foe_strip, l.ledger)
	var buttons: Array = l.buttons
	_place(scene._ff_button, buttons[0])
	_place(scene._auto_button, buttons[1])
	_place(scene._log_button, buttons[2])
	_place(scene._back_button, buttons[2])
	_place(scene._goal_label, l.goal)
	for row: TeamRow in [player_team, foe_team]:
		row.compact = true
	_place(player_team, l.player_team)
	_place(foe_team, l.foe_team)
	# The small tags stand centred under their sprite; in Era V they are as wide as it.
	var fit: bool = EraBattleHud.text(era, "mini") == "fit"
	for side: int in [BattleModel.Side.PLAYER, BattleModel.Side.FOE]:
		for slot: int in scene._slot_strips[side].size():
			var tag: MiniStrip = scene._slot_strips[side][slot]
			var sp: SpirlingSprite = scene._slot_sprites[side][slot]
			if fit:
				tag.size.x = maxf(sp.size.x, MiniStrip.WIDTH)
			tag.position.x = roundf(sp.position.x + (sp.size.x - tag.size.x) / 2.0)

## Keeps the team rows and the item shortcut in step with the battle (every played event).
func on_event(e: BattleEvent) -> void:
	if e.type == BattleEvent.Type.ITEM_USED and int(e.data.get("side", -1)) == BattleModel.Side.PLAYER:
		note_item(str(e.data.get("item", "")))
	refresh_teams()

## Remembers [param id] for the item shortcut: only an item the player picks in battle and
## that needs no defeated target.
static func note_item(id: String) -> void:
	var it: Dictionary = Database.item(id)
	if bool(it.get("battle", false)) and not BattleModel.is_revive_item(id):
		EraBattleHud.last_item = id

## Does a side show its team row? Ours from two Spirlings on; the foe's only for a Wayfarer's
## team, never for wild Spirlings.
static func shows_team(wild: bool, side: int, members: int) -> bool:
	return members > 1 and (side == BattleModel.Side.PLAYER or not wild)

## Party indices of [param side] standing on the field now (the rest of the row is the bench).
static func fielded(m: BattleModel, side: int) -> Array:
	var out: Array = []
	for slot: int in m.slot_count(side):
		var i: int = m.active_index(side, slot)
		if i >= 0 and m.is_standing(m.active_spirling(side, slot)):
			out.append(i)
	return out

func refresh_teams() -> void:
	if scene == null or scene.model == null:
		return
	for pair: Array in [[player_team, BattleModel.Side.PLAYER], [foe_team, BattleModel.Side.FOE]]:
		var row: TeamRow = pair[0]
		var team: Array = _team(int(pair[1]))
		row.set_party(team, fielded(scene.model, int(pair[1])))
		row.visible = shows_team(scene.model.is_wild, int(pair[1]), team.size())

## Shows the ring-rise panel for the LEVEL_UP event [param e]; hide_level() takes it away.
func show_level(e: BattleEvent) -> void:
	var party: Array = scene.model.party(BattleModel.Side.PLAYER)
	var index: int = int(e.data.get("index", -1))
	if index < 0 or index >= party.size():
		return
	var to: int = int(e.data.get("level", 1))
	# The panel stands in the command panel, which is empty while the turn plays, so it covers
	# neither a plate nor a Spirling.
	var room: Rect2 = scene._menu.get_global_rect().grow(-3)
	level_panel.max_width = room.size.x
	level_panel.show_rise(party[index] as Spirling, to - 1, to)
	level_panel.global_position = level_spot(room, level_panel.size)

## Where the ring-rise panel goes inside [param room]: at its right edge, centred in height.
static func level_spot(room: Rect2, panel: Vector2) -> Vector2:
	return Vector2(room.end.x - panel.x, room.position.y + floorf((room.size.y - panel.y) / 2.0)).round()

func hide_level() -> void:
	level_panel.visible = false

## The battle text box in the era's frame, drawn over the box's own panel (the text is a child
## and stays on top). A worn shop frame keeps its look.
func _draw_text_frame() -> void:
	if EraBattleHud.frames_text_box(GameState.dialogue_frame()):
		scene._text.draw_style_box(EraBattleHud.frame_style(era), Rect2(Vector2.ZERO, scene._text.size))

## Era V: the plates lean a share of the way the battle camera moved the field.
func _process(_delta: float) -> void:
	if scene == null:
		return
	var share: float = 0.0 if Juice.reduced() else EraBattleHud.num(era, "camera_follow")
	var root: Control = scene._shake_root
	for strip: InfoStrip in [scene._foe_strip, scene._player_strip]:
		strip.cam_shift = EraBattleHud.camera_shift(root.pivot_offset, root.scale, strip.position + strip.size / 2.0, share)
