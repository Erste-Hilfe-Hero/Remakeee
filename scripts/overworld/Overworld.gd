class_name Overworld
extends Node2D
## Runs the current map: builds TileMapLayer + NPCs from MapData, moves the player,
## handles warps, signs, NPC dialogue and tall-grass encounters, and hosts battles on top.

signal battle_ended(outcome: BattleModel.Outcome)

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/Battle.tscn")
const UI_LAYER: int = 20
const BATTLE_LAYER: int = 30
const TEXT_BOX_HEIGHT: int = 44
const BANNER_TIME: float = 1.2
## Map changes stay under 300 ms in total (item 61): two fades plus the load.
const FADE_TIME: float = 0.11
## Pause between a Wayfarer spotting the player and walking over.
const SPOT_TIME: float = 0.5
## Seconds for a grapple swing or cliff climb.
const GEAR_MOVE_TIME: float = 0.4
## Hand-over-hand pulls along a grapple rope.
const GRAPPLE_PULLS: int = 4

var map: MapData
var player: Player
var busy: bool = false

var _ground: TileMapLayer
## Terrain look of the map's era over the ground tiles (EraTerrainLook, docs/ERA_FEEL_TILES.md).
var _terrain_look: EraTerrainLook
## Shade over dark gear cells (thick without the gear, a faint dusk with it).
var _shade: Node2D
var _entities: Node2D
var _camera: Camera2D
var _photo: PhotoMode
## The last battle's model (the weekly challenge reads its turn count).
var last_model: BattleModel
var _daylight: CanvasModulate
## Lit windows at night, on a layer the night tint does not reach (buildings plan item 8).
var _glow_layer: CanvasLayer
var _glow: WindowGlow
## The place's landmark sprite (Landmarks, map design item 509), y-sorted with the people.
var _landmark: Sprite2D
var _npcs: Array[NPC] = []
var _ui: CanvasLayer
var _text: TextBox
var _picker: ListPicker
## True while a boat or coach trip loads its stop: arriving that way does not open the stop.
var _on_trip: bool = false
var _banner: Label
## Time-of-day symbol beside the place banner (area 3 item 1169).
var _phase_icon: PhaseIcon
## Plain weather dots and veil (area 3 item 1144).
var weather_layer: WeatherLayer
var minimap: Minimap
## Top-of-screen notes (badges, daily tasks).
var toast: Toast
var _fade: ColorRect
## Light, weather look and transitions of the map's era (EraLightLayer, data/era_light.json).
var _era_light: EraLightLayer
## Dark rectangle that grows from a door over the screen on door warps (item 2277).
var _door_wipe: ColorRect
const DOOR_WIPE_TIME: float = 0.14
## Edge warps slide the view this far in the walking direction while it darkens (item 2278).
const EDGE_SLIDE: int = 16
var _particles: PixelParticles
## Era extras on the map (water shimmer, footprints, reflection, tilt, camera lead; EraFeelLayer).
var _era_feel: EraFeelLayer
var _walk_steps: int = 0
var _run_steps: int = 0
var _battle_layer: CanvasLayer
var _actions: Dictionary[String, Callable] = {}
var _ui_root: Control
## True while a cut-scene runs (steps of the player do not trigger warps or encounters).
var scene_running: bool = false
## Set by a step that cannot go on (a warp to a map that is not built yet); the scene stops.
var scene_abort: bool = false
## True while the running scene (and any scene inside it) is being skipped.
var scene_skipping: bool = false
## Area 3 puzzles and gear on the map (boulders, plates, cracked floor, planks, ladders).
var _world: WorldMechanics
## Cell the player arrived on in this map ("Reset room" puts them back here).
var _entry_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	Database.load_all()
	_actions = {
		"storage": _action_storage,
		"heal": _action_heal,
		"camp": _action_camp,
		"bench": _action_bench,
		"lake_bench": _action_lake_bench,
		"tide_stone": _action_tide_stone,
		"rubbing": _action_rubbing,
		"fish_trap": _action_fish_trap,
		"wake": _action_wake,
		"bounty": _action_bounty,
		"fine_training": _action_fine_training,
		"matchmaker": _action_matchmaker,
		"reserve": _action_reserve,
		"informant": _action_informant,
		"burrow": _action_burrow,
		"marker_stone": _action_marker_stone,
		"give_item": _action_give_item,
		"take_item": _action_take_item,
		"gift_spirling": _action_gift_spirling,
		"tip": _action_tip,
		"set_flag": _action_set_flag,
		"shop": _action_shop,
		"showcase": _action_showcase,
		"dig": _action_dig,
		"exchange": _action_exchange,
		"festival_shop": _action_festival_shop,
		"spark_read": _action_spark_read,
		"quest_show": _action_quest_show,
		"switch": _action_switch,
		"gauntlet": _action_gauntlet,
		"postgame_board": _action_postgame_board,
		"rift_tower": _action_rift_tower,
		"weekly": _action_weekly,
		"master": _action_master,
		"merchant": _action_merchant,
		"echo_room": _action_echo_room, "echo_chest": _action_echo_chest, "echo_info": _action_echo_info,
		"expedition": _action_expedition,
		"season": _action_season,
		"choose_starter": _action_choose_starter,
		"page": _action_page,
		"set_var": _action_set_var,
		"add_var": _action_add_var,
		"battle": _action_battle,
		"favor": _action_favor,
		"betrayal": _action_betrayal,
		"trust": _action_trust,
		"ledger": _action_ledger,
		"scene": _action_scene,
		"warp": _action_warp,
		"transit": _action_transit,
		"echo_song": _action_echo_song,
		"quest_stage": _action_quest_stage,
		"lever": _action_lever,
		"bell": _action_bell,
		"toggle": _action_toggle,
		"mirror": _action_mirror,
		"first_voice": _action_first_voice,
		"legend": _action_legend,
	}
	_world = WorldMechanics.new(self)
	_build()
	if GameState.party.is_empty() and not GameState.in_game:
		# Running this scene directly from the editor: start a quick test game.
		GameState.new_game(GameState.Difficulty.TAMER, "Juno", 0, "Kindlop")
	GameState.in_game = true
	player.body_color = GameState.body_color()
	player.material = GameState.tamer_material()
	player.hat = GameState.worn_hat()
	player.sprite_style = GameState.tamer_sprite()
	load_map(GameState.current_map, GameState.player_cell, GameState.facing)
	VirtualPad.set_wanted(true)
	DeepLink.poll()
	if not GameState.has_flag("got_starter"):
		busy = true
		player.frozen = true
		_fade.color.a = 1.0
		prologue.call_deferred()
	else:
		# Coming from the title screen: the world brightens in underneath it (item 2280).
		_fade.color.a = 1.0
		_fade_to.call_deferred(0.0)
		var hint: String = Festival.start_hint()
		if hint != "":
			GameState.notices.append(hint)
			show_notices.call_deferred()

func _build() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	add_child(_ground)
	_terrain_look = EraTerrainLook.new()
	add_child(_terrain_look)
	_particles = PixelParticles.new()
	_particles.name = "particles"
	add_child(_particles)
	_era_feel = EraFeelLayer.new()
	add_child(_era_feel)
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)
	_shade = Node2D.new()
	_shade.name = "Shade"
	add_child(_shade)
	player = Player.new()
	player.name = "Player"
	player.body_color = Color("3a5a9a")
	player.sprite_style = "tamer"
	player.can_move = _can_enter
	player.stepped.connect(_on_player_stepped)
	player.step_started.connect(_on_player_step_started)
	player.bob = true
	player.interact.connect(_on_interact)
	player.path_blocked.connect(_on_path_blocked)
	_entities.add_child(player)
	_era_feel.player = player
	_inkshadow = Sprite2D.new()
	_inkshadow.name = "Inkshadow"
	_inkshadow.centered = false
	_inkshadow.modulate = Color(UITheme.INK, 0.85)
	_entities.add_child(_inkshadow)
	# Era look of the figures: poses, bubbles, head turns, the Spirling behind (EraActors).
	var actors := EraActors.new()
	actors.name = "era_actors"
	actors.entities = _entities
	actors.player = player
	actors.follower = _inkshadow
	actors.is_night = func() -> bool: return map != null and map.outdoor and DayCycle.current() == DayCycle.Phase.NIGHT
	actors.is_rain = func() -> bool: return map != null and map.outdoor and WeatherCycle.current(map) in ["rain", "storm"]
	add_child(actors)
	var hint := InteractHint.new()
	hint.ow = self
	add_child(hint)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()
	_era_light = EraLightLayer.new()
	_era_light.setup(player, _camera)
	add_child(_era_light)

	_ui = CanvasLayer.new()
	_ui.layer = UI_LAYER
	add_child(_ui)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UITheme.get_theme()
	# Text box, hints and the HUD follow high contrast and large text at once.
	ui_root.add_to_group(MenuHost.THEME_GROUP)
	_ui.add_child(ui_root)
	_ui_root = ui_root
	SafeArea.apply(ui_root)
	_fade = ColorRect.new()
	_fade.color = Color(UITheme.INK, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The fade covers the whole screen, cut-outs included, under the (safe-area) UI.
	_ui.add_child(_fade)
	_ui.move_child(_fade, 0)
	weather_layer = WeatherLayer.new()
	_ui.add_child(weather_layer)
	_ui.move_child(weather_layer, 0)
	DayCycle.events.phase_changed.connect(_on_phase_changed)
	minimap = Minimap.new()
	_ui_root.add_child(minimap)
	_door_wipe = ColorRect.new()
	_door_wipe.color = UITheme.INK
	_door_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_wipe.visible = false
	_ui.add_child(_door_wipe)
	_ui.move_child(_door_wipe, 2)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 4
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_stylebox_override("normal", UITheme.panel_style())
	_banner.visible = false
	ui_root.add_child(_banner)
	_phase_icon = PhaseIcon.new()
	_banner.add_child(_phase_icon)
	toast = Toast.new()
	add_child(toast)
	Billing.pass_paid.connect(_on_pass_paid)
	_text = TextBox.new()
	_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text.offset_top = -TEXT_BOX_HEIGHT
	# Long lines (and German text) grow the box upward instead of off the bottom of the screen.
	_text.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_text.visible = false
	_text.allow_fast_forward = true
	ui_root.add_child(_text)
	_picker = ListPicker.new()
	_picker.set_anchors_preset(Control.PRESET_CENTER)
	_picker.custom_minimum_size = Vector2(110, 80)
	_picker.offset_left = -55
	_picker.offset_right = 55
	_picker.offset_top = -40
	_picker.offset_bottom = 40
	ui_root.add_child(_picker)

	_battle_layer = CanvasLayer.new()
	_battle_layer.layer = BATTLE_LAYER
	add_child(_battle_layer)

func _process(delta: float) -> void:
	# Integer-rounded camera (no smoothing) keeps pixels on the grid.
	_camera.global_position = (player.global_position + Vector2(GridWalker.TILE / 2.0, GridWalker.TILE / 2.0)).round()
	if _photo != null:
		_camera.global_position += _photo.pan
	_camera.global_position += _era_feel.camera_offset()
	# Music layers follow walking, running and open text boxes (items 2477, 2478).
	MusicDirector.update_world(player.moving, player.running, delta)
	MusicDirector.dialogue = _text.visible
	var rest_note: String = PlayReminder.tick(delta)
	if not rest_note.is_empty():
		toast.show_note(rest_note)
	# A chimora://event link opens the Goals screen once the player is free (DeepLink.gd).
	if DeepLink.route in ["event", "friend"] and GameState.has_flag("got_starter") and not busy and not scene_running and _photo == null and not player.moving:
		open_menu("Goals" if DeepLink.take() == "event" else "Invite")
	_walk_clock += delta
	if _walk_clock >= WALK_PAUSE:
		_walk_clock = 0.0
		walk_npcs()

## Seconds between two steps of a walking villager (item 1213): slower than the player.
const WALK_PAUSE: float = 1.4
var _walk_clock: float = 0.0

## One step for every villager on a walk, unless a talk or scene runs. Nobody steps onto the
## player, another person or a blocked cell; they wait instead.
func walk_npcs() -> void:
	if busy or scene_running or map == null:
		return
	var free: Callable = func(c: Vector2i) -> bool:
		return map.is_walkable(c) and npc_at(c) == null and player.cell != c
	for n: NPC in _npcs:
		n.walk_tick(free)

# --- Maps --------------------------------------------------------------------------

func _tip_after_load(id: String) -> void:
	# Wait for the warp fade to finish so the tip doesn't cut into it.
	while busy:
		await get_tree().process_frame
	await show_tip(id)

## Flag set once the goal line of room [param map_id] was shown.
static func goal_flag(map_id: String) -> String:
	return "goal_seen_" + map_id.replace(MapData.FLOOR_SEP, "_")

func _era_line_after_load(line: String, era_before: int = EraManager.unlocked_era) -> void:
	while busy:
		await get_tree().process_frame
	await get_tree().create_timer(EraManager.transition_wait()).timeout
	# After the EraUpgrade sweep: the finale card of the era that ended, then the staged change
	# scene (EraChangeScene, docs/ERA_LOOK_TITLE.md).
	await EraChangeScene.play_after_finale(self, era_before, EraManager.unlocked_era)
	var lines: Array[String] = [line]
	# What the new era brings (EraFeatures, data/era_functions.json).
	for e: int in range(era_before + 1, EraManager.unlocked_era + 1):
		lines.append_array(EraFeatures.new_in_lines(e))
	await _locked_say(lines)

## The first free walk after the prologue (item 1982): a note with an arrow to the D-pad that
## goes away after three steps; then the menu tip.
func show_walk_hint() -> void:
	var lines: Array[String] = Tips.take("walk")
	if lines.is_empty():
		return
	var hint := WalkHint.new()
	hint.text = lines[0]
	_ui.add_child(hint)
	for i: int in WalkHint.STEPS:
		await player.stepped
	hint.queue_free()
	while busy:
		await get_tree().process_frame
	await show_tip("menu")

## Shows a first-time tip (if any) while the player waits.
func show_tip(id: String) -> void:
	var lines: Array[String] = Tips.take(id)
	if not lines.is_empty():
		await _locked_say(lines)

func load_map(map_id: String, cell: Vector2i, face: String) -> void:
	map = MapData.load_map(map_id)
	if map == null:
		return
	if minimap != null:
		minimap.spotted.clear()
	_entry_cell = cell
	if map.outdoor:
		GameState.enter_map(map_id, cell)
	_world.prepare(map, cell)
	map.paint(_ground)
	_terrain_look.show_map(map, _ground, _camera, _entities)
	refresh_shade()
	_spawn_npcs()
	_place_landmark()
	_place_rustle()
	player.place(cell, face)
	_place_inkshadow(cell, cell)
	GameState.current_map = map_id
	# Boat and coach stops open once the player has walked there (area 3 item 1190).
	if not _on_trip and Transit.is_stop(map_id):
		GameState.set_flag(Transit.stop_flag(map_id))
	DailyTasks.note_map(map_id)
	DailyTasks.record("visit", {"map": map_id})
	EchoPath.note_visit(map_id)
	# Today's world event gives its find on the first visit (plan 3422).
	GameState.notices.append_array(WorldEvents.on_visit(map_id))
	# A released Spirling may show up where it came from (plan 1137).
	GameState.notices.append_array(Released.sightings(map_id, DailyFind.today_key(), GameState.rng))
	# Spirling Radar (shop, pay-to-win step 6): the rarer kinds of this place and their ground.
	var radar: String = ShopEffects.radar_line(map.encounter_table)
	if not radar.is_empty():
		GameState.notices.append(radar)
	GameState.player_cell = cell
	GameState.facing = face
	var era_before: int = EraManager.unlocked_era
	EraManager.unlock_region(map.region)
	EraManager.set_region(map.region)
	var look_line: String = RegionLook.arrive_line(map.region)
	if not look_line.is_empty() and not GameState.has_flag("look_seen_" + map.region):
		GameState.set_flag("look_seen_" + map.region)
		GameState.notices.append(Loc.t(look_line))
	EraManager.unlock_story_end(GameState.has_flag(EraManager.STORY_COMPLETE_FLAG))
	EraManager.mark_finales(GameState.flags)
	# The last era has no change after its finale; its finale card shows once (EraFinaleCard).
	EraFinaleCard.play_if_owed.call_deferred(self)
	EraManager.unlock_from_flags(GameState.has_flag)
	if EraManager.unlocked_era > era_before and EraManager.ERA_LINES.has(EraManager.unlocked_era):
		_era_line_after_load.call_deferred(EraManager.ERA_LINES[EraManager.unlocked_era], era_before)
	else:
		# An era opened before the era-change sequence existed plays it on the first visit.
		EraManager.upgrade_for_region(map.region)
	_era_feel.map = map
	_era_feel.footprints.clear()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map.width * GridWalker.TILE
	_camera.limit_bottom = map.height * GridWalker.TILE
	Survey.reveal(map, cell)
	_show_banner(banner_text())
	# A puzzle room says its goal once, on the first visit (area 3 item 1031).
	if not map.goal.is_empty() and not GameState.has_flag(goal_flag(map.id)):
		GameState.set_flag(goal_flag(map.id))
		_era_line_after_load.call_deferred(map.goal)
	refresh_minimap()
	var arrive: String = StoryPlacements.enter_scene(map_id, GameState.flags)
	if not arrive.is_empty():
		_arrival_scene.call_deferred(arrive)
	refresh_daylight()
	Sound.enter_map(map_id)
	if not map.encounter_table.is_empty():
		_tip_after_load.call_deferred("wild_area")

var _rustle: Node2D

## Shows today's rustling spot of the map (Era V), or hides it once it is used.
func _place_rustle() -> void:
	var day: String = DailyFind.today_key()
	if not RustleSpots.active(map, day, GameState.records):
		if _rustle != null:
			_rustle.visible = false
		return
	if _rustle == null:
		_rustle = RustleSpots.Mark.new()
		_rustle.name = "rustle_spot"
		_entities.add_child(_rustle)
	_rustle.position = Vector2(RustleSpots.spot(map, day)) * TilesetFactory.TILE
	_rustle.visible = true

## Tints the world for the time of day (UI layers are not affected). Checked once a minute.
func refresh_daylight() -> void:
	if _daylight == null:
		_daylight = CanvasModulate.new()
		add_child(_daylight)
		var t := Timer.new()
		t.wait_time = 60.0
		t.autostart = true
		t.timeout.connect(refresh_daylight)
		add_child(t)
	var w: String = WeatherCycle.current(map)
	_daylight.color = DayCycle.tint(map.outdoor, DayCycle.current(), GameState.day_night) * WeatherCycle.tint(w)
	# Era V shows the season on outdoor maps (data/era_feel.json "season_tint").
	if map.outdoor and bool(EraManager.feel("season_tint")):
		_daylight.color *= EraFeel.season_tint(int(Online.date_now().month))
	if _glow == null:
		_glow_layer = CanvasLayer.new()
		_glow_layer.layer = 1
		_glow_layer.follow_viewport_enabled = true
		add_child(_glow_layer)
		_glow = WindowGlow.new()
		_glow_layer.add_child(_glow)
	_glow.show_for(map, WindowGlow.lit(map.outdoor, DayCycle.current(), GameState.day_night))
	if weather_layer != null:
		weather_layer.show_kind(w)
	DayCycle.poll()
	_era_light.refresh(map, w, _daylight, _glow, weather_layer)

const SHADE_DARK: float = 0.9
const SHADE_LIT: float = 0.3

## Redraws the shade over dark cells; the needed gear thins it to dusk.
func refresh_shade() -> void:
	for c: Node in _shade.get_children():
		c.queue_free()
	for g: Dictionary in map.gear_spots:
		if g.has("to"):
			continue
		var r := ColorRect.new()
		r.color = Color(UITheme.INK, SHADE_LIT if GameState.has_gear(str(g.gear)) else SHADE_DARK)
		r.position = Vector2(int(g.x), int(g.y)) * TilesetFactory.TILE
		r.size = Vector2.ONE * TilesetFactory.TILE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shade.add_child(r)

func npc_at(cell: Vector2i) -> NPC:
	for n: NPC in _npcs:
		if n.cell == cell:
			return n
	return null

func _can_enter(cell: Vector2i) -> bool:
	if busy or npc_at(cell) != null:
		return false
	var world_rule: int = _world.can_enter(cell)
	if world_rule >= 0:
		return world_rule == 1
	if not map.is_walkable(cell):
		return false
	var gear: String = map.gear_needed_at(cell)
	if not gear.is_empty() and not GameState.has_gear(gear):
		_gear_hint.call_deferred(gear)
		return false
	return true

var _hinted_cell: Vector2i = Vector2i(-1, -1)

## Says once per approach what a dark spot needs (holding a direction would repeat it).
func _gear_hint(gear: String) -> void:
	var facing: Vector2i = player.facing_cell()
	if busy or facing == _hinted_cell:
		return
	_hinted_cell = facing
	Sound.sfx("bump")
	await _locked_say([str(Database.item(gear).get("hint", "You can't go that way yet."))] as Array[String])

func _locked_say(lines: Array[String]) -> void:
	busy = true
	player.frozen = true
	await say(lines)
	player.frozen = false
	busy = false

## Grapple across water or climb a low cliff. Returns true if a gear spot handled the interaction.
func _try_gear(target: Vector2i) -> bool:
	var spot: Dictionary = map.gear_spot(player.cell, target)
	if spot.is_empty():
		return false
	var gear: String = str(spot.gear)
	if not GameState.has_gear(gear):
		await _locked_say([str(Database.item(gear).get("hint", "You can't cross here yet."))] as Array[String])
		return true
	var to: Array = spot.to
	busy = true
	player.frozen = true
	var dest := Vector2i(int(to[0]), int(to[1]))
	Sound.sfx("confirm")
	var from_pos: Vector2 = player.position
	var to_pos: Vector2 = GridWalker.cell_to_pos(dest)
	var rope: Line2D = null
	if gear == "grapple_line":
		# Area 3 item 1049: the rope is stretched first, then the Wayfarer pulls along it hand
		# over hand, feet on the rope; no arc, never free in the air.
		rope = Line2D.new()
		rope.width = 1.0
		rope.default_color = UITheme.INK
		var half := Vector2(GridWalker.TILE / 2.0, GridWalker.TILE / 2.0 + 2.0)
		rope.points = PackedVector2Array([from_pos + half, to_pos + half])
		_entities.add_child(rope)
	# From Era III the Wayfarer wades across on foot, knee-deep, without the hop (data/era_actor_look.json).
	if EraActorLook.wades(gear):
		player.era_anim["wade"] = true
	var tw: Tween = create_tween()
	if rope != null:
		for i: int in GRAPPLE_PULLS:
			var a: Vector2 = from_pos.lerp(to_pos, float(i) / GRAPPLE_PULLS).round()
			var b: Vector2 = from_pos.lerp(to_pos, float(i + 1) / GRAPPLE_PULLS).round()
			tw.tween_property(player, "position", b, GEAR_MOVE_TIME / GRAPPLE_PULLS).from(a).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(func(k: float) -> void:
			var arc: float = (0.0 if player.era_anim.has("wade") else -10.0) * sin(k * PI)
			player.position = from_pos.lerp(to_pos, k).round() + Vector2(0, round(arc)), 0.0, 1.0, GEAR_MOVE_TIME)
	await tw.finished
	if rope != null:
		rope.queue_free()
	player.era_anim.erase("wade")
	player.place(dest, player.facing)
	GameState.player_cell = dest
	player.frozen = false
	busy = false
	return true

## NPCs of the map that are there now: flags, "phase_only" (area 3 item 1168) and "weekdays".
## Puts the map's landmark on its cell: the 16x32 sprite stands on the cell and covers the one above.
func _place_landmark() -> void:
	if _landmark != null:
		_landmark.queue_free()
		_landmark = null
	var lm: Dictionary = Landmarks.for_map(map.id)
	if lm.is_empty():
		return
	var path: String = Landmarks.art_path(str(lm.kind))
	if path.is_empty():
		return
	_landmark = Sprite2D.new()
	_landmark.name = "landmark"
	_landmark.texture = load(path)
	_landmark.centered = false
	_landmark.offset = Vector2(0, -TilesetFactory.TILE)
	_landmark.position = GridWalker.cell_to_pos(Landmarks.cell(lm))
	_entities.add_child(_landmark)

func _spawn_npcs() -> void:
	for n: NPC in _npcs:
		n.queue_free()
	_npcs.clear()
	var phase: int = DayCycle.current() if _world.phase_override < 0 else _world.phase_override
	# Day plans (area 3 item 1212): people move with the time of day, some visit other maps.
	for def: Dictionary in NpcSchedule.defs_for(map, phase):
		if def.has("hide_flag") and GameState.has_flag(str(def.hide_flag)):
			continue
		if def.has("show_flag") and not GameState.has_flag(str(def.show_flag)):
			continue
		if not DayCycle.shows_at(def, phase):
			continue
		# Market stalls (item 959) stand only on their weekdays.
		if not DayCycle.on_weekday(def, DayCycle.weekday()):
			continue
		var n := NPC.new()
		n.setup(def)
		_entities.add_child(n)
		_npcs.append(n)

## The time of day moved on: light, people, doors and the banner symbol follow (item 1167).
func _on_phase_changed(_phase: int) -> void:
	if map == null or busy:
		return
	refresh_daylight()
	_spawn_npcs()
	_world.refresh(player.cell)

## Map name with its survey share (item 1246): "Brindlewick  42%".
func banner_text() -> String:
	return WorldAtlas.banner(map, GameState.flags)

## Every step maps the cells around the player (item 1245) and moves the minimap.
func survey_step(cell: Vector2i) -> void:
	if map == null:
		return
	Survey.reveal(map, cell)
	refresh_minimap()

func refresh_minimap() -> void:
	if minimap == null or map == null:
		return
	var trainers: Array[Vector2i] = []
	for n: NPC in _npcs:
		if _is_active_trainer(n):
			trainers.append(n.cell)
	minimap.refresh(map, player.cell if player != null else GameState.player_cell, trainers)

func _show_banner(text: String) -> void:
	_banner.text = "    %s " % text
	_phase_icon.phase = DayCycle.current()
	_phase_icon.queue_redraw()
	# The banner takes the era's place-name style (TownPopup, data/era_feel.json "town_popup").
	var style: String = str(EraManager.feel("town_popup"))
	TownPopup.dress(_banner, style)
	_banner.visible = true
	await TownPopup.slide(_banner, style, true)
	await get_tree().create_timer(BANNER_TIME).timeout
	await TownPopup.slide(_banner, style, false)
	_banner.visible = false

## Darkens with the "close" curve and brightens without overshoot ("fade" curve).
func _fade_to(alpha: float) -> void:
	await Juice.tween(_fade, "color:a", alpha, "close" if alpha > _fade.color.a else "fade", FADE_TIME).finished

## True when [param cell] lies on the map border (a path to the next map, not a door).
func is_edge_cell(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.y <= 0 or cell.y >= map.height - 1 or cell.x >= map.rows[cell.y].length() - 1

## Darkening for a warp: doors grow a dark rectangle from the door, map edges slide the view
## on in the walking direction. Plain fade under reduced motion.
func _warp_out(edge: bool) -> void:
	if await _era_light.warp_out(map.kind_at(player.cell), edge, player.facing, _fade):
		return
	if Juice.reduced():
		await _fade_to(1.0)
		return
	if edge:
		var d: Vector2 = Vector2(GridWalker.DIRS[player.facing]) * EDGE_SLIDE
		Juice.tween(_camera, "offset", d, "close", FADE_TIME)
		await _fade_to(1.0)
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var door: Vector2 = (player.get_global_transform_with_canvas().origin + Vector2(8, 8)).round()
	# Era III winds a spiral of ink in around the Wayfarer (data/era_text.json).
	if EraText.warp(EraManager.active_era(), str(EraManager.feel("warp"))) == "spiral":
		await EraWarp.spiral_close(_ui, door, UITheme.INK, DOOR_WIPE_TIME)
		_fade.color.a = 1.0
		return
	# Eras IV and V close an iris on the Wayfarer instead of the door rectangle.
	if str(EraManager.feel("warp")) == "iris":
		await EraFeelLayer.iris_close(_ui, door, UITheme.INK, DOOR_WIPE_TIME * 1.5)
		_fade.color.a = 1.0
		return
	var start := Rect2(door - Vector2(8, 8), Vector2(16, 16))
	var full := Rect2(Vector2.ZERO, vp)
	_door_wipe.visible = true
	var grow := func(k: float) -> void:
		var p: Vector2 = start.position.lerp(full.position, k).round()
		var e: Vector2 = start.end.lerp(full.end, k).round()
		_door_wipe.position = p
		_door_wipe.size = e - p
	grow.call(0.0)
	var tw: Tween = create_tween()
	tw.tween_method(grow, 0.0, 1.0, DOOR_WIPE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_fade.color.a = 1.0
	_door_wipe.visible = false

# --- Player events -------------------------------------------------------------------

func _on_player_stepped(cell: Vector2i) -> void:
	_hinted_cell = Vector2i(-1, -1)
	_place_inkshadow(GameState.player_cell, cell)
	_era_feel.stepped(cell, GameState.player_cell)
	GameState.player_cell = cell
	GameState.facing = player.facing
	survey_step(cell)
	if scene_running:
		return
	_grass_rustle(map.kind_at(cell))
	DailyTasks.record("step", {"map": map.id})
	Kinship.on_step(GameState.party, GameState.records)
	_inkshadow_remark()
	show_notices()
	if await _world.stepped(cell):
		return
	var warp: Dictionary = map.warp_at(cell)
	if not warp.is_empty():
		await _warp(warp)
		return
	var spotter: NPC = _spotting_trainer()
	if spotter != null:
		await challenge(spotter, true)
		return
	# Rustling spot (Era V): today's shaking patch hides the map's rarest kind.
	if GameState.first_healthy_index() >= 0 and RustleSpots.due(map, cell, DailyFind.today_key(), GameState.records):
		RustleSpots.mark_done(GameState.records, map.id, DailyFind.today_key())
		_place_rustle()
		var rare: Spirling = RustleSpots.make_wild(map.encounter_table, GameState.rng, GameState.gleam_chain)
		if rare != null:
			Sound.sfx("sparkle")
			await _locked_say([RustleSpots.LINE] as Array[String])
			await start_battle([rare] as Array[Spirling], true)
			return
	# Encounter Call (item 4838): twice the encounter rate for its steps, then a short note.
	var call_mult: float = ShopEffects.encounter_mult()
	for ended: String in ShopEffects.step_kinds_done():
		toast.show_note(Loc.t(str(ShopEffects.STEP_END_NOTES[ended])))
	var guard_over: bool = EncounterTable.tick_guard()
	# Wild Ward (shop, pay-to-win step 6): switched on, no wild Spirling steps out.
	if map.kind_at(cell) in TilesetFactory.ENCOUNTER_KINDS and not map.encounter_table.is_empty() and guard_over and not ShopEffects.wild_ward_on():
		if GameState.first_healthy_index() >= 0 and GameState.rng.randf() < minf(1.0, EncounterTable.rate(map.encounter_table) * call_mult):
			var wild: Spirling = DailyFind.maybe_spawn(map.encounter_table, GameState.flags, GameState.rng)
			if wild != null:
				# The day's rare visitor glitters in with five very high notes (item 2517).
				Sound.sfx("sparkle")
				await _locked_say(["The grass rustles strangely... A rare visitor!"] as Array[String])
			else:
				# The pass holder's rare Spirling of the day (pay-to-win step 6, plan point 38).
				wild = ShopEffects.pass_rare(map.encounter_table, GameState.flags, GameState.rng)
			if wild == null:
				var boost: Array[int] = DayCycle.encounter_boost(Season.boosted(Season.current()), map.outdoor, DayCycle.current(), GameState.day_night)
				wild = EncounterTable.roll(map.encounter_table, GameState.rng, boost, EncounterTable.ground_at(map, cell), GameState.gleam_chain)
				if wild != null:
					GameState.gleam_chain = GleamRules.next_chain(GameState.gleam_chain, wild)
			if wild != null:
				await start_battle([wild] as Array[Spirling], true)

func _warp(warp: Dictionary) -> void:
	busy = true
	player.frozen = true
	var sounds: Array[String] = warp_sounds(map.kind_at(player.cell), player.facing)
	Sound.sfx(sounds[0])
	await _warp_out(is_edge_cell(player.cell))
	load_map(str(warp.to), Vector2i(int(warp.tx), int(warp.ty)), str(warp.get("facing", player.facing)))
	_camera.offset = Vector2.ZERO
	SaveManager.save_game()
	if not sounds[1].is_empty():
		Sound.sfx(sounds[1])
	await _fade_to(0.0)
	player.frozen = false
	busy = false

## Sounds for leaving through a warp on tile [param kind] and for arriving: a wooden door
## opens and shuts behind (item 2507), stairs climb or descend by the way the Wayfarer faces
## (item 2508), anything else is the warp sweep.
static func warp_sounds(kind: int, facing: String) -> Array[String]:
	if kind == TilesetFactory.Kind.DOOR:
		return ["door_open", "door_close"] as Array[String]
	if kind == TilesetFactory.Kind.STAIRS:
		return ["stairs_down" if facing == "down" else "stairs_up", ""] as Array[String]
	return ["warp", ""] as Array[String]

func _on_interact(cell: Vector2i) -> void:
	if busy:
		return
	if await _try_gear(cell):
		return
	if await _world.interact(cell):
		return
	var n: NPC = npc_at(cell)
	if n != null:
		await n.turn_toward(player.cell)
		if _is_active_trainer(n):
			await challenge(n, false)
		elif not await offer_warden_rematch(n) and not await offer_second_trial(n) and not await offer_rematch(n) and not await offer_trials(n):
			await run_dialogue(n.dialogue_ref, n)
		return
	var s: Dictionary = map.sign_at(cell, GameState.flags)
	if not s.is_empty():
		var icons: Control = _gear_icons(s.get("gear", []))
		await run_dialogue(str(s.dialogue))
		if icons != null:
			icons.queue_free()
		return
	var landmark: Array[String] = Landmarks.lines_at(map.id, cell)
	if not landmark.is_empty():
		await _locked_say(landmark)
		return
	# Talk across counters.
	if map.kind_at(cell) == TilesetFactory.Kind.COUNTER:
		var beyond: NPC = npc_at(cell + (cell - player.cell))
		if beyond != null:
			await beyond.turn_toward(player.cell)
			await run_dialogue(beyond.dialogue_ref, beyond)
			return
	survey_look(cell - player.cell)

## Survey Glass (area 3 items 1052, 1053): A on open ground looks ahead; finds up to 6 steps
## away show on the minimap. Says so in the ticker, so it never stops the walk.
func survey_look(dir: Vector2i) -> void:
	if map == null or not GameState.has_gear(SurveyGlass.ITEM) or dir == Vector2i.ZERO:
		return
	if not SurveyGlass.ready():
		Ticker.show_text(Loc.t("The glass is still misted. %d s.") % SurveyGlass.wait_left())
		return
	SurveyGlass.mark_used()
	var seen: Array[Vector2i] = SurveyGlass.scan(map, player.cell, dir, GameState.flags)
	if minimap != null:
		for c: Vector2i in seen:
			if not c in minimap.spotted:
				minimap.spotted.append(c)
		minimap.queue_redraw()
	Sound.sfx("confirm" if not seen.is_empty() else "tick")
	Ticker.show_text(Loc.t("Through the glass: %d glints ahead.") % seen.size() if not seen.is_empty() else Loc.t("Through the glass: nothing glints ahead."))

## Cave entrance signs show the gear needed inside as pictures above the text (item 982).
func _gear_icons(gear: Array) -> Control:
	if gear.is_empty():
		return null
	var row := HBoxContainer.new()
	row.name = "gear_icons"
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 4
	row.offset_top = -TEXT_BOX_HEIGHT - TilesetFactory.TILE * 2 - 4
	row.grow_vertical = Control.GROW_DIRECTION_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for g: Variant in gear:
		var tex: Texture2D = PauseMenu.gear_picture(str(g))
		if tex == null:
			continue
		var r := TextureRect.new()
		r.texture = tex
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	_text.get_parent().add_child(row)
	return row

## Shows a dialogue entry, then runs its action and flag. Freezes the player meanwhile.
## Follows "if"/"else", "choices" and "next" inside the same file (plan items 1335-1338).
func run_dialogue(ref: String, speaker: NPC = null) -> void:
	var goal_before: int = QuestLog.current_index(GameState.flags)
	busy = true
	player.frozen = true
	VirtualPad.set_talk(true)
	if speaker != null:
		DailyTasks.record("talk", {"map": map.id, "key": ref})
	_text.voice = Sound.voice_for(speaker.npc_id if speaker != null else "")
	await play_entry(ref, speaker)
	_text.voice = "player"
	refresh_shade()
	await announce_achievements()
	await announce_goal_if_changed(goal_before)
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false

## Plays [param ref] and whatever it leads to via "else", choices and "next".
func play_entry(ref: String, speaker: NPC = null) -> void:
	var hops: int = 0
	while not ref.is_empty() and hops < Dialogue.MAX_HOPS:
		hops += 1
		ref = await _play_one(ref, speaker)
	_text.visible = false

## Plays one entry and returns the next reference ("" when the talk is over).
func _play_one(ref: String, speaker: NPC) -> String:
	var entry: Dictionary = Dialogue.get_entry(ref)
	if entry.has("if") and not Dialogue.check(entry.get("if"), GameState.flags):
		return Dialogue.resolve_ref(ref, str(entry.else)) if entry.has("else") else ""
	var lines: Array[String] = Dialogue.lines_for(entry, GameState.flags)
	var who: String = Dialogue.speaker_for(entry)
	if who.is_empty():
		# Villagers whose lines carry no name show their role or Wayfarer name (item 2011).
		who = Speakers.name_for(speaker)
	var choices: Array[Dictionary] = Dialogue.choices_for(entry, GameState.flags)
	var next: String = str(entry.get("next", ""))
	_text.visible = true
	for i: int in lines.size():
		if i == lines.size() - 1 and not choices.is_empty():
			_text.show_prompt(lines[i], who)
		else:
			await _text.show_text(lines[i], who)
	if not choices.is_empty():
		var pick: Dictionary = await _ask_choice(choices)
		if entry.has("choice_id"):
			GameState.record_choice(str(entry.choice_id), str(pick.get("id", choices.find(pick))))
		if pick.has("flag"):
			GameState.set_flag(str(pick.flag))
		if pick.has("action"):
			_text.visible = false
			await _run_action(str(pick.action), speaker)
		if pick.has("next"):
			next = str(pick.next)
	await _text.close()
	var already: bool = entry.has("flag") and GameState.has_flag(str(entry.flag))
	if entry.has("action") and not (already and bool(entry.get("once", false))):
		await _run_action(str(entry.action), speaker)
	if entry.has("flag"):
		GameState.set_flag(str(entry.flag))
	return Dialogue.resolve_ref(ref, next) if not next.is_empty() else ""

## Shows the answers as a list under the last line and waits for a tap (plan item 1335).
func _ask_choice(choices: Array[Dictionary]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for c: Dictionary in choices:
		entries.append({"text": str(c.get("text", "..."))})
	var idx: int = await _picker.pick("", entries, false)
	return choices[clampi(idx, 0, choices.size() - 1)]

## Shows newly earned achievements (item 90).
func announce_achievements() -> void:
	show_notices()
	var lines: Array[String] = Collection.claim()
	lines.append_array(SeasonPath.note_play())
	# Ribbons of a festival that ended while the game was closed turn into Waymarks on the
	# first open, not only on the next battle (plan 3546).
	lines.append_array(Festival.settle())
	# Vows settle and the run is chronicled first, so "Three Ways" is checked right after (plan 3403).
	lines.append_array(Vows.settle())
	lines.append_array(RunChronicle.note())
	var badges: Array[String] = Achievements.check()
	lines.append_array(Completion.claim())
	for t: String in badges:
		# Unlocked badges show at the top of the screen without stopping the game (plan 3315).
		var a: Dictionary = Achievements.by_title(t)
		toast.show_note(Loc.t("Badge: %s") % Loc.t(t) + "  " + Waymarks.gain_text(int(a.get("reward", 0))), Badges.texture(a, true), "")
		Sound.sfx("level_up")
	if lines.is_empty():
		return
	Sound.sfx("level_up")
	await say(lines)
	_text.visible = false

## Shows queued reward notes (daily tasks, Waymarks) as toasts that do not stop the game.
func show_notices() -> void:
	for line: String in take_notices():
		toast.show_note(line, null, notice_sound(line))

## A finished daily task gets a stroke and a bell (item 2516), other notes the toast chime.
static func notice_sound(line: String) -> String:
	var done: String = Loc.t("Daily task done: %s").get_slice("%s", 0)
	return "task_done" if not done.is_empty() and line.begins_with(done) else "toast"

## Reward notes queued by DailyTasks / Waymarks, emptied.
func take_notices() -> Array[String]:
	var lines: Array[String] = GameState.notices.duplicate()
	GameState.notices.clear()
	return lines

## Shows "New goal: ..." when the story goal moved on since [param before]. A new chapter
## first gets its chapter card (plan item 1413), with the act name when the act changes.
func announce_goal_if_changed(before: int) -> void:
	var now: int = QuestLog.current_index(GameState.flags)
	if now == before:
		return
	var card: Array[String] = QuestLog.card_for(before, now, GameState.flags)
	if not card.is_empty():
		GameState.set_flag(QuestLog.card_flag(QuestLog.current(GameState.flags)))
		var sp := ScenePlayer.new()
		sp.overworld = self
		add_child(sp)
		await sp.play("chapter_card", {"skippable": false, "steps": [{"card": card[0], "title": card[1] if card.size() > 1 else ""}]})
		sp.queue_free()
		busy = true
		player.frozen = true
	await say(["New goal: " + QuestLog.goal_text(QuestLog.current(GameState.flags), GameState.flags)] as Array[String])
	var tip: Array[String] = Tips.take("goals")
	if not tip.is_empty():
		await say(tip)

func say(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_text.visible = true
	for line: String in lines:
		await _text.show_text(line)
	_text.visible = false

# --- Access for the ScenePlayer -----------------------------------------------------------

func ui_root() -> Control:
	return _ui_root

func text_box() -> TextBox:
	return _text

func fade_rect() -> ColorRect:
	return _fade

func entities() -> Node2D:
	return _entities

## The NPC on this map with [param id], or null.
func npc_by_id(id: String) -> NPC:
	for n: NPC in _npcs:
		if n.npc_id == id:
			return n
	return null

## Trauma for stepping into a Rift (item 2262).
const RIFT_TRAUMA: float = 0.35

## The world shakes with trauma 0.35 and a deep rumble as a Rift opens (item 2262). The
## camera offset shakes, never the menus.
func rift_opens() -> void:
	Sound.sfx("rumble")
	Juice.set_shake_root(_camera, "offset")
	Juice.add_trauma(RIFT_TRAUMA)

## Shakes the camera for [param seconds] (thunder, the Rift opening).
func shake_camera(seconds: float) -> void:
	if Juice.reduced():
		return
	var t: float = 0.0
	while t < seconds:
		_camera.offset = Vector2(GameState.rng.randi_range(-2, 2), GameState.rng.randi_range(-2, 2))
		await get_tree().process_frame
		t += get_process_delta_time()
	_camera.offset = Vector2.ZERO

## Runs dialogue actions from outside (scenes).
func run_action(action: String, speaker: NPC = null) -> void:
	await _run_action(action, speaker)

## Runs one action, or several separated by ";" (e.g. "page 1; give_item tonic 2").
func _run_action(action: String, speaker: NPC) -> void:
	for one: String in action.split(";", false):
		var parts: PackedStringArray = one.strip_edges().split(" ", false)
		if parts.is_empty() or not _actions.has(parts[0]):
			push_warning("Overworld: unknown dialogue action '%s'" % one)
			continue
		await _actions[parts[0]].call(parts.slice(1), speaker)

## "first_voice <species> <ring>": a fixed, one-time meeting with a First Voice (plan area 1,
## items 153-155). It is wild, so it can be bonded with the Echo call. If it is not bonded
## (beaten, fled or lost), it rests and comes back to the same place after the next rest.
func _action_first_voice(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty() or GameState.first_healthy_index() < 0:
		return
	var sd: SpirlingData = Database.species(args[0])
	if sd == null:
		return
	await _fixed_meeting(sd, int(args[1]) if args.size() > 1 else 40, "The light sinks back under the water. It will rise again after you rest.")

## "legend <species> <ring>": a one-time meeting with a legendary Spirling (FirstVoices.LEGENDS),
## with the same rest-and-return rule as a First Voice.
func _action_legend(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty() or GameState.first_healthy_index() < 0:
		return
	var sd: SpirlingData = Database.species(args[0])
	if sd == null:
		return
	var ring: int = int(args[1]) if args.size() > 1 else int(FirstVoices.entry(sd.species_name).get("ring", 50))
	await _fixed_meeting(sd, ring, "It slips away. It will be back here after you rest.")

func _fixed_meeting(sd: SpirlingData, ring: int, gone_line: String) -> void:
	var wild := Spirling.new(sd, ring, GameState.rng)
	_text.visible = false
	SaveManager.save_game()
	var outcome: BattleModel.Outcome = await start_battle([wild] as Array[Spirling], true, {"backdrop": "voice", "name": sd.species_name})
	GameState.set_flag(FirstVoices.away_flag(sd.species_name))
	# Only a bond in this meeting counts; a shop copy in storage is not the one met here.
	if outcome == BattleModel.Outcome.BONDED:
		GameState.set_flag(FirstVoices.bonded_flag(sd.species_name))
	else:
		await say([gone_line] as Array[String])

## Echo Cores that are ready wake into a Hallkind (item 185).
func _wake_cores() -> void:
	for kid: Spirling in GameState.awaken_cores():
		var lines: Array[String] = ["The song in the Echo Core you carry grows dense and clear.", "A young %s wakes, still humming the song of %s." % [kid.data.species_name, " and ".join(kid.lineage)]]
		var inh: Dictionary = kid.get_meta("inheritance", {})
		if not str(inh.get("line", "")).is_empty():
			lines.append(str(inh.line))
		for art: Variant in inh.get("arts", []):
			lines.append(Loc.t("It already knows %s, an heirloom art of the family.") % str(art))
		if not (inh.get("stats", []) as Array).is_empty():
			lines.append(Loc.t("It carries the family's best Spark in %d values.") % (inh.stats as Array).size())
		await say(lines)
		SaveManager.save_game()

## "marker_stone <n> [region]": a cartographer's stone (area 3 items 1084, 1085, 1312): counted
## once per region, a keepsake at 4, 8 and 12.
func _action_marker_stone(args: PackedStringArray, _speaker: NPC) -> void:
	var res: Dictionary = MarkerStones.visit(int(args[0]) if args.size() > 0 else 0, args[1] if args.size() > 1 else "veydal")
	if not bool(res.new):
		return
	Sound.sfx("confirm")
	var out: Array[String] = ["You trace the mark with your finger. Cartographer's stones found: %d/%d" % [int(res.found), MarkerStones.TOTAL]]
	if not str(res.reward).is_empty():
		out.append("Tucked behind the stone lies a keepsake: %s." % str(Database.item(str(res.reward)).get("name", res.reward)))
	await say(out)

## A cave campfire (area 3 item 992): the journey is saved, the team is not healed.
func _action_camp(_args: PackedStringArray, _speaker: NPC) -> void:
	Sound.sfx("confirm")
	var ok: bool = SaveManager.save_game()
	await say([("You sit by the fire for a while. Your journey is saved." if ok else "The fire smokes. Saving did not work this time."),
		"The warmth is welcome, but it does not rest your team."] as Array[String])

## Lines after sitting on a bench (area 3 item 935), one per phase that has just begun.
const BENCH_LINES: Dictionary[int, String] = {
	DayCycle.Phase.DAWN: "Dawn breaks over the water.",
	DayCycle.Phase.DAY: "The sun climbs high. It is broad day now.",
	DayCycle.Phase.DUSK: "The light turns golden. Dusk settles in.",
	DayCycle.Phase.NIGHT: "Stars come out over the brook. Night has fallen.",
}

## A bench by the water: sitting a while moves the clock on to the next time of day (item 935).
func _action_bench(_args: PackedStringArray, _speaker: NPC) -> void:
	var p: DayCycle.Phase = DayCycle.skip_to_next()
	Sound.sfx("confirm")
	await say(["You sit on the bench and watch the line drift. Time slips by...", BENCH_LINES[p]] as Array[String])
	refresh_daylight()
	_spawn_npcs()
	_world.refresh(player.cell)

## The tide stone at Sablecove (area 3 item 985): tides turn every six hours by the device
## clock; the stone tells the current tide and the next low tide.
func _action_tide_stone(_args: PackedStringArray, _speaker: NPC) -> void:
	await say(TideChart.stone_lines())

## Gear that reads weathered stones (area 3 item 1051).
const RUBBING_ITEM := "rubbing_charcoal"

## "rubbing <file/key>": a weathered stone on a burial mound (item 1088). With the Rubbing
## Charcoal the worn inscription comes back and points to a hidden find nearby.
func _action_rubbing(args: PackedStringArray, _speaker: NPC) -> void:
	if GameState.has_gear(RUBBING_ITEM):
		Sound.sfx("confirm")
	await say(rubbing_lines(args[0] if args.size() > 0 else ""))

## What a weathered stone shows: the inscription with the charcoal, else a hint at it.
static func rubbing_lines(key: String) -> Array[String]:
	if not GameState.has_gear(RUBBING_ITEM):
		return ["The letters are too worn to read. A charcoal rubbing might bring them back."] as Array[String]
	var out: Array[String] = ["You lay paper on the stone and rub the charcoal over it. Letters appear:"]
	if Dialogue.exists(key):
		out.append_array(Dialogue.lines_for(Dialogue.get_entry(key), GameState.flags))
	return out

## "fish_trap <id>": a trap on the Reedhaven jetty, emptied once a day (area 3 item 964).
func _action_fish_trap(args: PackedStringArray, _speaker: NPC) -> void:
	var id: String = args[0] if args.size() > 0 else "trap"
	var day: String = DailyFind.today_key()
	var got: Dictionary = FishTrap.catch(id, day)
	if got.is_empty():
		await say(["The trap is empty. Check it again tomorrow."] as Array[String])
		return
	FishTrap.empty(id, day)
	await say(["You haul up the trap. Something is caught in the reeds..."] as Array[String])
	if got.has("item"):
		await _action_give_item([str(got.item), "1"] as PackedStringArray, null)
	else:
		GameState.money += int(got.money)
		Sound.sfx("pickup")
		await say([Loc.plural(int(got.money), "You found %d coin!", "You found %d coins!")] as Array[String])

## "wake": the daily funeral show in Gravers' Hall (data/wake.json, scripts/core/Wake.gd).
func _action_wake(_args: PackedStringArray, _speaker: NPC) -> void:
	var day: String = DailyFind.today_key()
	if Wake.held_today(day):
		await say(["The Undertaker: One funeral a day. The dead are patient. Come back tomorrow."] as Array[String])
		return
	await say([Loc.t("The Undertaker: Today we mourn %s. Who will perform?") % Wake.deceased(day)] as Array[String])
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var names: Array[String] = []
	for p: Spirling in GameState.party:
		names.append(p.display_name())
	var who: int = await menu.pick_strings(Loc.t("Who performs?"), names)
	if who < 0:
		menu.queue_free()
		return
	var s: Spirling = GameState.party[who]
	var arts: Array[String] = []
	for m: MoveData in s.moves:
		arts.append(m.move_name)
	var pick: int = await menu.pick_strings(Loc.t("Which art?"), arts)
	if pick < 0:
		menu.queue_free()
		return
	var cost: int = int(Wake.data().get("bribe_cost", 0))
	var bribe: bool = false
	if GameState.money >= cost:
		bribe = await menu.confirm(Loc.t("Slip the Heir %d coins?") % cost, "Pay", "No")
	menu.queue_free()
	if bribe:
		GameState.money -= cost
	var result: Dictionary = Wake.perform(s, s.moves[pick], bribe, GameState.rng)
	var lines: Array[String] = [Loc.t("%s performs %s by the coffin.") % [s.display_name(), s.moves[pick].move_name]]
	lines.append_array(result.lines)
	lines.append(Loc.t("The mourners give %d points.") % int(result.score))
	for r: Dictionary in Wake.data().get("rivals", []):
		lines.append(Loc.t("%s scores %d.") % [Loc.t(str(r.name)), int(r.score)])
	if bool(result.won):
		lines.append(Loc.t("The hall weeps for you. You win %d coins.") % int(result.prize))
	else:
		lines.append("The Undertaker: Not today. The dead were not impressed.")
	Wake.finish(result, day)
	await say(lines)

## "bounty": the Fixer's daily bounty board and the 100 percent certificate (scripts/core/Bounties.gd).
func _action_bounty(_args: PackedStringArray, _speaker: NPC) -> void:
	var cert: Array[String] = Bounties.certificate(Completion.percent(), GameState.tamer_name)
	if not cert.is_empty():
		await say(cert)
	var day: String = DailyFind.today_key()
	var cap: int = GameState.progress_cap()
	var open: Array[Dictionary] = []
	for m: Dictionary in Bounties.board(day, cap):
		if not str(m.id) in Bounties.claimed(day):
			open.append(m)
	if open.is_empty():
		await say(["The Fixer: Board's clean. Come back tomorrow, somebody always owes somebody."] as Array[String])
		return
	var names: Array[String] = []
	for m: Dictionary in open:
		names.append(Bounties.line(m))
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var pick: int = await menu.pick_strings(Loc.t("Which mark?"), names)
	menu.queue_free()
	if pick < 0:
		return
	var m: Dictionary = open[pick]
	await say([Loc.t(str(m.crime))] as Array[String])
	var foes: Array[Spirling] = []
	for sp: Variant in m.team:
		if Database.spirlings.has(str(sp)):
			foes.append(Spirling.new(Database.spirlings[str(sp)], int(m.ring), GameState.rng))
	SaveManager.save_game()
	var outcome: BattleModel.Outcome = await start_battle(foes, false, {"name": Loc.t(str(m.name)), "money": 0, "ai": GameState.ai_level()})
	busy = true
	player.frozen = true
	if outcome == BattleModel.Outcome.WIN:
		var paid: int = Bounties.claim(day, cap, str(m.id))
		await say([Loc.t("The Fixer counts out %d coins. The rest is his cut. Always is.") % paid] as Array[String])

## "fine_training": Coach Varro raises one spark for coins, sometimes he just keeps them (FineTraining.gd).
func _action_fine_training(_args: PackedStringArray, _speaker: NPC) -> void:
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var names: Array[String] = []
	for p: Spirling in GameState.party:
		names.append(p.display_name())
	var who: int = await menu.pick_strings(Loc.t("Who trains?"), names)
	if who < 0:
		menu.queue_free()
		return
	var s: Spirling = GameState.party[who]
	var stats: Array[String] = []
	for k: String in Spirling.STAT_KEYS:
		stats.append(Loc.t("%s: %d coins") % [k.to_upper(), FineTraining.cost(s, k)])
	var pick: int = await menu.pick_strings(Loc.t("Which value?"), stats)
	menu.queue_free()
	if pick < 0:
		return
	var stat: String = Spirling.STAT_KEYS[pick]
	if not FineTraining.can_train(s, stat):
		await say(["Coach Varro: Either you're broke or it's maxed. Either way, no."] as Array[String])
		return
	var r: Dictionary = FineTraining.train(s, stat, GameState.rng)
	await say([str(r.line)] as Array[String])

## "burrow": the claimable hollow in Murk Hollow with a wall of trophies (scripts/core/Burrow.gd).
func _action_burrow(_args: PackedStringArray, _speaker: NPC) -> void:
	var menu := MenuHost.new()
	_ui.add_child(menu)
	if not Burrow.claimed():
		if not await menu.confirm(Loc.t("A dry hollow in the rock. Nobody seems to live here. Claim it as your Burrow?"), "Claim", "Leave"):
			menu.queue_free()
			return
		Burrow.claim()
		Sound.sfx("pickup")
	var pawned: String = Burrow.visit(DailyFind.today_key())
	if not pawned.is_empty():
		menu.visible = false
		await say([Loc.t(str(Burrow.data().squatter)) % Loc.t(str(Burrow.trophy(pawned).name))] as Array[String])
		menu.visible = true
	while true:
		var ids: Array[String] = Burrow.earned_ids()
		if ids.is_empty():
			menu.queue_free()
			await say(["Your Burrow. The walls are bare. Earn something worth hanging."] as Array[String])
			return
		var rows: Array[String] = []
		for id: String in ids:
			var shown: String = Loc.t(str(Burrow.trophy(id).name))
			rows.append(("* " + shown) if id in Burrow.wall() else shown)
		var pick: int = await menu.pick_strings(Loc.t("Your Burrow (%d/%d on the wall)") % [Burrow.wall().size(), int(Burrow.data().wall_slots)], rows)
		if pick < 0:
			break
		var id: String = ids[pick]
		menu.visible = false
		if id in Burrow.wall():
			Burrow.take_down(id)
			await say([Loc.t(str(Burrow.trophy(id).text)), "You take it down."] as Array[String])
		elif Burrow.hang(id):
			await say([Loc.t(str(Burrow.trophy(id).text)), "You hang it on the wall."] as Array[String])
		else:
			await say(["The wall is full. Take something down first."] as Array[String])
		menu.visible = true
	menu.queue_free()

## "matchmaker": Auntie Grisela seals a match contract on a carried Echo Core (data/breeding.json).
func _action_matchmaker(_args: PackedStringArray, _speaker: NPC) -> void:
	var core: Dictionary = Breeding.open_core()
	if core.is_empty():
		await say(["Auntie Grisela: No Echo Core, no wedding. Sing at a spring first, then we talk business."] as Array[String])
		return
	var fee: int = int(Breeding.data().get("contract_fee", 0))
	var lines: Array[String] = []
	for l: Variant in Breeding.data().get("contract_lines", []):
		lines.append(str(l))
	await say(lines)
	if GameState.money < fee:
		await say([Loc.t("Auntie Grisela: A contract costs %d coins. Love is free, paperwork is not.") % fee] as Array[String])
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var yes: bool = await menu.confirm(Loc.t("Seal a match contract for the core of %s for %d coins?") % [" and ".join(core.get("parents", [])), fee], "Seal", "No")
	menu.queue_free()
	if yes and Breeding.seal_contract(core):
		Sound.sfx("confirm")
		await say(["Auntie Grisela: Signed, sealed, and nobody else will hear of it. Probably."] as Array[String])
		SaveManager.save_game()

## "reserve": a run through Hollowgate Reserve (data/reserve.json, scripts/core/Reserve.gd).
func _action_reserve(_args: PackedStringArray, _speaker: NPC) -> void:
	var d: Dictionary = Reserve.data()
	var welcome: Array[String] = []
	for l: Variant in d.get("welcome", []):
		welcome.append(str(l))
	await say(welcome)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var fee: int = int(d.get("entry_fee", 0))
	var pay: bool = await menu.confirm(Loc.t("Pay %d coins to slip into the reserve?") % fee, "Pay", "No")
	if not pay:
		menu.queue_free()
		return
	var run: Dictionary = Reserve.enter()
	if run.is_empty():
		menu.queue_free()
		await say(["Velvet Dorran: No coins? Then you were never here."] as Array[String])
		return
	var game := BondMinigame.new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.visible = false
	_ui.add_child(game)
	while not Reserve.over(run):
		var s: Dictionary = Reserve.sighting(run, GameState.rng)
		var sname: String = str(s.species)
		GameState.mark_seen(sname)
		if bool(s.snitched):
			await say([Loc.t(str(d.snitch_line)) % sname] as Array[String])
			continue
		var done: bool = false
		while not done:
			var opts: Array[String] = [Loc.t("Echo call (%d left)") % int(run.calls), Loc.t("Set bait"), Loc.t("Rattle the fence"), Loc.t("Move on")]
			var c: int = await menu.pick_strings(Loc.t("A wild %s, Ring %d. Sightings left: %d") % [sname, int(s.level), int(run.sightings)], opts, false)
			if c == 3:
				break
			var action: String = ["call", "bait", "rattle"][c]
			var score: float = 0.0
			if action == "call":
				var plan: Dictionary = BondEcho.make_plan(GameState.rng, Database.species(sname))
				score = await game.run(plan)
				GameState.note_echo(score)
			elif action == "bait":
				await say([Loc.t(str(d.bait_line)) % sname] as Array[String])
			else:
				await say([Loc.t(str(d.rattle_line)) % sname] as Array[String])
			var res: Dictionary = Reserve.act(run, s, action, GameState.rng, score)
			if bool(res.bonded):
				Sound.sfx("confirm")
				GameState.receive_spirling(Reserve.spirling_of(s, GameState.rng))
				await say([Loc.t(str(d.bonded_line)) % sname] as Array[String])
				done = true
			elif bool(res.fled):
				await say([Loc.t(str(d.fled_line)) % sname] as Array[String])
				done = true
			elif action == "call":
				await say([Loc.t(str(d.missed_line)) % sname] as Array[String])
			if int(run.calls) <= 0:
				done = true
	game.queue_free()
	menu.queue_free()
	await say([str(d.done_line)] as Array[String])
	SaveManager.save_game()

## "informant": Whisper Moll sells tips on hidden gifts and wakes them (data/hidden_gifts.json).
func _action_informant(_args: PackedStringArray, _speaker: NPC) -> void:
	var d: Dictionary = HiddenGifts.data()
	var intro: Array[String] = []
	for l: Variant in d.get("tip_lines", []):
		intro.append(str(l))
	await say(intro)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var choice: int = await menu.pick_strings(Loc.t("Whisper Moll"), [Loc.t("Buy a tip (%d coins)") % int(d.get("tip_cost", 0)), Loc.t("Wake a hidden gift"), Loc.t("Leave")] as Array[String])
	if choice == 0:
		var names: Array[String] = []
		for p: Spirling in GameState.party:
			names.append(p.display_name())
		var who: int = await menu.pick_strings(Loc.t("Whose line?"), names)
		menu.queue_free()
		if who < 0:
			return
		var s: Spirling = GameState.party[who]
		if HiddenGifts.revealed(s.data.line_id):
			await say(["Whisper Moll: You already know that one. I don't sell the same secret twice. Not to you."] as Array[String])
			return
		var res: Dictionary = HiddenGifts.buy_tip(s.data, GameState.rng)
		if not bool(res.ok):
			await say(["Whisper Moll: No coins, no whispers."] as Array[String])
			return
		await say([str(res.line)] as Array[String])
		SaveManager.save_game()
	elif choice == 1:
		var names: Array[String] = []
		var picks: Array[Spirling] = []
		for p: Spirling in GameState.party:
			if p.hidden_gift or HiddenGifts.can_wake(p):
				names.append(Loc.t("%s (awake)") % p.display_name() if p.hidden_gift else p.display_name())
				picks.append(p)
		if picks.is_empty():
			menu.queue_free()
			await say([Loc.t("Whisper Moll: Nobody here is ready. Learn the secret first, and come back at Ring %d.") % int(d.get("unlock_ring", 20))] as Array[String])
			return
		var who: int = await menu.pick_strings(Loc.t("Whose gift?"), names)
		menu.queue_free()
		if who < 0:
			return
		var awake: bool = HiddenGifts.toggle(picks[who])
		var label: String = Loc.t(str(HiddenGifts.gift(HiddenGifts.gift_id(picks[who].data)).get("label", "")))
		await say([(Loc.t("%s wakes its hidden gift: %s.") if awake else Loc.t("%s lets %s sleep again. It can wake any time.")) % [picks[who].display_name(), label]] as Array[String])
		SaveManager.save_game()
	else:
		menu.queue_free()

## Seconds of quiet on a lake bench before a Spirling calls (area 3 item 1093); tests shorten it.
var lake_bench_wait: float = 10.0

## "lake_bench <species> <file/key>": sit, wait, hear a Spirling from the water, then a hint.
func _action_lake_bench(args: PackedStringArray, _speaker: NPC) -> void:
	await say(["You sit down and look out over the lake. Everything goes quiet..."] as Array[String])
	if lake_bench_wait > 0.0:
		await get_tree().create_timer(lake_bench_wait).timeout
	var sd: SpirlingData = Database.species(args[0]) if args.size() > 0 else null
	Sound.cry(sd)
	var out: Array[String] = ["Somewhere out on the water, a Spirling calls."]
	if args.size() > 1 and Dialogue.exists(args[1]):
		out.append_array(Dialogue.lines_for(Dialogue.get_entry(args[1]), GameState.flags))
	await say(out)

func _action_heal(_args: PackedStringArray, _speaker: NPC) -> void:
	FirstVoices.after_rest()
	for s: Spirling in GameState.party:
		Inkshadow.soothe(s)
	GameState.heal_party()
	Sound.sfx("heal")
	if map.heal_point.x >= 0:
		GameState.heal_map = map.id
		GameState.heal_cell = map.heal_point
		GameState.visit_rest(map.id, map.heal_point)
	Online.contribute("rests")
	DailyTasks.record("rest", {"map": map.id})
	await say(["Your team is fully rested."] as Array[String])
	await say(Tips.take("rest_spot"))
	if FirstSteps.tick(FirstSteps.REST):
		show_notices()
	GameState.note_core_rest()
	await _wake_cores()
	# Every spring can swap the team with storage, even before storage opens from the menu,
	# and load a saved team with one tap (plan area 1, items 378 and 381).
	# After the second mended Rift every spring is an Echo spring (items 183-184).
	var opts: Array[String] = []
	if not GameState.storage.is_empty() or not GameState.team_presets.is_empty():
		opts.append("Storage")
	if GameState.echo_spring_open():
		opts.append("Sing together")
	if not opts.is_empty():
		opts.append("Go on")
		var entries: Array[Dictionary] = []
		for o: String in opts:
			entries.append({"text": o})
		var c: int = await _picker.pick("Swap Spirlings here?" if not GameState.echo_spring_open() else "The spring hums softly.", entries)
		if c >= 0 and opts[c] == "Storage":
			await _action_storage(PackedStringArray(), null)
		elif c >= 0 and opts[c] == "Sing together":
			var menu := PauseMenu.new()
			_ui.add_child(menu)
			await menu.run_sing_together()
			menu.queue_free()

func _action_storage(_args: PackedStringArray, _speaker: NPC) -> void:
	var menu := PauseMenu.new()
	_ui.add_child(menu)
	await menu.run_storage()
	menu.queue_free()

## Opens the pause menu (Team, Spirlog, Satchel, Save, Settings); [param start] opens one entry
## first ("Goals" for a chimora://event link, "Invite" for chimora://friend, DeepLink.gd).
func open_menu(start: String = "") -> void:
	if busy:
		return
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	FirstSteps.tick(VirtualPad.MENU_SEEN_FLAG)
	var menu := PauseMenu.new()
	menu.encounter_table = map.encounter_table
	menu.current_map = map.id
	menu.room_puzzle = _world.has_puzzle()
	menu.can_undo = _world.can_undo()
	menu.open_on = start
	_ui.add_child(menu)
	# A page turned open, and folded shut when it closes (item 2509).
	Sound.sfx("page_open")
	# Slides in from the right edge with "open" (item 2281).
	if not Juice.reduced():
		menu.position.x = MENU_SLIDE
		Juice.tween(menu, "position", Vector2.ZERO, "open")
	await menu.run()
	Sound.sfx("page_close")
	await _close_menu(menu)
	match menu.room_action:
		"undo": _world.undo()
		"reset":
			_world.reset_room(_entry_cell)
			await _note_room_fail(map.id)
	var target: String = menu.travel_to
	var photo: bool = menu.photo
	var watch: bool = menu.watch_replay
	var watch_snap: Dictionary = menu.watch_snap
	var duel: Dictionary = menu.echo_duel
	var league: Dictionary = menu.league_match
	var raid: Dictionary = menu.raid_attempt
	var live: Dictionary = menu.live_stage
	var quit: bool = menu.to_title
	menu.queue_free()
	if quit:
		GameState.in_game = false
		get_tree().change_scene_to_file(TITLE_SCENE)
		return
	if not duel.is_empty():
		await echo_duel(duel)
	if not league.is_empty():
		await league_battle(league)
	if not raid.is_empty():
		await raid_battle(raid)
	if not live.is_empty():
		await live_duel(live)
	if photo:
		await photo_mode()
	if watch:
		await watch_replay(watch_snap if not watch_snap.is_empty() else GameState.records.get("last_battle", {}))
	var c: Array = GameState.travel_cell(target) if not target.is_empty() else []
	if c.size() == 2:
		Sound.sfx("warp")
		await _fade_to(1.0)
		load_map(target, Vector2i(int(c[0]), int(c[1])), "down")
		Sound.enter_map(target)
		await _fade_to(0.0)
	player.body_color = GameState.body_color()
	player.material = GameState.tamer_material()
	player.hat = GameState.worn_hat()
	refresh_daylight()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	show_notices()

## Plays a recorded battle (item 14). The replay uses copies, so nothing in the save changes.
const MENU_SLIDE: float = 40.0
const TITLE_SCENE: String = "res://scenes/ui/Title.tscn"

## Slides the pause menu's last list back out to the right with "close" in 0.12 s.
func _close_menu(menu: PauseMenu) -> void:
	if Juice.reduced():
		return
	menu.picker.visible = true
	menu.picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Juice.tween(menu, "modulate:a", 0.0, "close")
	await Juice.tween(menu, "position", Vector2(MENU_SLIDE, 0), "close").finished

# --- Inkshadow (the lead Spirling one step behind) ------------------------------------

var _inkshadow: Sprite2D

func _place_inkshadow(prev_cell: Vector2i, cell: Vector2i) -> void:
	if _inkshadow == null:
		return
	var lead: Spirling = Inkshadow.lead()
	_inkshadow.visible = lead != null and map != null and map.outdoor
	if not _inkshadow.visible:
		return
	_inkshadow.texture = MiniSprite.of(lead.data.species_name, GridWalker.TILE)
	_inkshadow.position = GridWalker.cell_to_pos(Inkshadow.trail_cell(prev_cell, cell, player.facing))

func _inkshadow_remark() -> void:
	if not map.outdoor:
		return
	var said: Dictionary = Inkshadow.step(GameState.rng)
	if said.is_empty():
		return
	GameState.money += int(said.get("money", 0))
	toast.show_note(str(said.text))

## Dust behind the feet on every second running step (items 2304, 2395).
func _on_player_step_started(dir: String, run: bool) -> void:
	_footstep(run)
	if not run:
		_run_steps = 0
		return
	_run_steps += 1
	if _run_steps % 2 == 0:
		_particles.dust(player.position + Vector2(8, 15), -Vector2(GridWalker.DIRS[dir]))

## Footsteps by ground (items 2501, 2502): every second step walking, every step running.
## Every third step into encounter grass rustles softly (item 2519).
const RUSTLE_EVERY: int = 3
var _grass_steps: int = 0

func _grass_rustle(kind: int) -> void:
	if not kind in TilesetFactory.ENCOUNTER_KINDS or map.encounter_table.is_empty():
		return
	_grass_steps += 1
	if rustle_due(_grass_steps):
		Sound.sfx("rustle", -6.0)

## True on the 1st, 4th, 7th ... grass step.
static func rustle_due(grass_steps: int) -> bool:
	return grass_steps > 0 and (grass_steps - 1) % RUSTLE_EVERY == 0

func _footstep(run: bool) -> void:
	_walk_steps += 1
	if not run and _walk_steps % 2 == 1:
		return
	var cell: Vector2i = player.cell
	var wet: bool = false
	for d: Vector2i in TilesetFactory.MASK_DIRS:
		if map.kind_at(cell + d) == TilesetFactory.Kind.WATER:
			wet = true
	Sound.footstep(map.kind_at(cell), wet)

func watch_replay(snap: Dictionary) -> void:
	var model: BattleModel = BattleReplay.build_model(snap)
	if model == null:
		var why: String = BattleReplay.problem(snap)
		await say([why if not why.is_empty() else "That replay can't be shown any more."] as Array[String])
		return
	await _fade_to(1.0)
	var scene: BattleScene = BATTLE_SCENE.instantiate()
	scene.setup(model)
	scene.backdrop = str(snap.get("backdrop", map.backdrop))
	scene.music_track = str(snap.get("music", "battle"))
	scene.replay_inputs = (snap.get("inputs", []) as Array).duplicate(true)
	_battle_layer.add_child(scene)
	_fade.color.a = 0.0
	await scene.battle_finished
	await _fade_to(1.0)
	scene.queue_free()
	Sound.enter_map(map.id)
	await _fade_to(0.0)

## A live duel, played or watched in the battle screen (Online 100, points 1 and 73).
func live_duel(info: Dictionary) -> void:
	await _fade_to(1.0)
	var stage := LiveDuelStage.new()
	stage.setup(info)
	_battle_layer.add_child(stage)
	_fade.color.a = 0.0
	await stage.finished
	if stage.ended and not stage.watch:
		LiveDuelMenu.last_id = stage.duel_id
	await _fade_to(1.0)
	stage.queue_free()
	Sound.enter_map(map.id)
	await _fade_to(0.0)

## Photo mode (item 94): pan, frame and save pictures until the player backs out.
func photo_mode() -> void:
	_photo = PhotoMode.new()
	_photo.place = map.display_name if not map.display_name.is_empty() else map.id.capitalize()
	add_child(_photo)
	VirtualPad.set_wanted(true)
	await _photo.finished
	if _photo.taken > 0:
		DailyTasks.record("photo", {"map": map.id, "night": DayCycle.current() == DayCycle.Phase.NIGHT})
	_photo.queue_free()
	_photo = null

## Android back: opens the pause menu in the world, works like B everywhere else (item 1787).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		DeepLink.poll()
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_inside_tree():
		return
	if not busy and _photo == null and player != null and not player.moving:
		open_menu()
	else:
		BackButton.press_cancel()

func _unhandled_input(event: InputEvent) -> void:
	if _photo != null:
		return
	if event.is_action_pressed(GameState.MENU_ACTION) and not busy and not player.moving:
		get_viewport().set_input_as_handled()
		open_menu()
		return
	# Tap-to-move: exactly once per tap, with or without mouse emulation (item 1780).
	if TapInput.is_press(event) and GameState.tap_to_move:
		var at: Vector2 = TapInput.position(event)
		if busy or player.frozen or VirtualPad.covers(at):
			return
		get_viewport().set_input_as_handled()
		var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * at
		tap_cell(Vector2i(floori(world.x / GridWalker.TILE), floori(world.y / GridWalker.TILE)))

## True if a tap on [param cell] should walk next to it and use it, like pressing A in front
## of it: signs, counters, hidden finds, smooth rock passages, ladders and plank gaps
## (item 2109, so all of the world works with taps alone). NPCs are checked by the caller.
static func used_on_arrival(m: MapData, cell: Vector2i, flags: Dictionary) -> bool:
	if not m.sign_at(cell, flags).is_empty() or not m.secret_at(cell, flags).is_empty():
		return true
	if not m.ladder_at(cell).is_empty():
		return true
	var p: Dictionary = m.passage_at(cell)
	if not p.is_empty() and not bool(flags.get(str(p.get("flag", "")), false)):
		return true
	var k: int = m.kind_at(cell)
	return k == TilesetFactory.Kind.COUNTER or k == TilesetFactory.Kind.PLANK

## Walks toward [param cell]; NPCs, signs, counters and finds get walked up to and used.
func tap_cell(cell: Vector2i, marker: bool = true) -> void:
	if map.in_bounds(cell) and cell == player.cell and not busy:
		# Tapping yourself looks through the Survey Glass, like A on open ground (item 1052).
		survey_look(player.facing_cell() - player.cell)
		return
	if not map.in_bounds(cell) or cell == player.cell:
		return
	_tap_goal = cell
	_tap_steps = player.manual_steps
	if marker:
		_tap_retries = 0
	var gear: Array = GameState.owned_gear()
	var passable: Callable = func(c: Vector2i) -> bool: return PuzzleRoom.passable(map, c, gear) and npc_at(c) == null
	# Tapping across water or a ledge: walk to the gear spot and use it.
	for g: Dictionary in map.gear_spots:
		if g.has("to") and int(g.x) == cell.x and int(g.y) == cell.y:
			var f := Vector2i(int(g.from[0]), int(g.from[1]))
			var route: Array[Vector2i] = PathFinder.find(player.cell, f, passable)
			if f == player.cell or not route.is_empty():
				player.follow(route, cell)
				return
	# Boulders: a tap next to one pushes it, a tap further away walks up to it (item 2109).
	if map.char_at(cell) == "B":
		if PathFinder.is_adjacent(cell, player.cell):
			player.follow([cell] as Array[Vector2i])
		else:
			player.follow(PathFinder.find_adjacent(player.cell, cell, passable))
		return
	var route: Array[Vector2i] = []
	var reached: bool = false
	# Tap walks keep off pressure plates unless the plate is the goal (plan item 901).
	var on_plate: Callable = func(c: Vector2i) -> bool: return map.kind_at(c) == TilesetFactory.Kind.PLATE
	if npc_at(cell) != null or used_on_arrival(map, cell, _world.flags_now(map, player.cell)):
		route = PathFinder.find_avoiding(player.cell, cell, passable, on_plate, true)
		reached = not route.is_empty() or PathFinder.is_adjacent(cell, player.cell)
		player.follow(route, cell if reached else Player.NO_TARGET)
	else:
		route = PathFinder.find_avoiding(player.cell, cell, passable, on_plate)
		reached = not route.is_empty()
		player.follow(route)
	if marker:
		show_tap_marker(cell, reached)

## The final cell of the last tap and how often a blocked walk was planned again (item 1822).
var _tap_goal: Vector2i = Player.NO_TARGET
var _tap_retries: int = 0
## Player.manual_steps when the tap walk was planned: walking by hand since then drops the retry.
var _tap_steps: int = 0
const TAP_RETRY_DELAY: float = 0.3
const TAP_RETRY_MAX: int = 5
const TAP_MARKER_TIME: float = 0.4

## A walking villager stepped into the tapped path: plan the way again after 0.3 s instead of
## standing still (item 1822). Boulders and closed gear spots are not retried.
func _on_path_blocked(next: Vector2i) -> void:
	if npc_at(next) == null or _tap_retries >= TAP_RETRY_MAX or _tap_goal == Player.NO_TARGET:
		return
	_tap_retries += 1
	var goal: Vector2i = _tap_goal
	await get_tree().create_timer(TAP_RETRY_DELAY).timeout
	if busy or player.moving or not player.path.is_empty() or _tap_goal != goal:
		return
	# The player took over with the pad meanwhile: never walk back to the old tap by itself.
	if player.manual_steps != _tap_steps or not player._held_direction().is_empty():
		_tap_goal = Player.NO_TARGET
		return
	tap_cell(goal, false)

## Shows where a tap leads: a blinking frame on the target for 0.4 s (item 1812), or a small X
## and the "cancel" sound when no way leads there (item 1813).
func show_tap_marker(cell: Vector2i, reachable: bool) -> TapMarker:
	var old: Node = _entities.get_node_or_null("tap_marker")
	if old != null:
		old.name = "tap_marker_old"
		old.queue_free()
	var mk := TapMarker.new()
	mk.name = "tap_marker"
	mk.cross = not reachable
	mk.life = TAP_MARKER_TIME
	mk.position = GridWalker.cell_to_pos(cell)
	_entities.add_child(mk)
	if not reachable:
		Sound.sfx("cancel")
	return mk

## "tip <coins> <who>": a teased townsfolk pays to make it stop (Ali, 7 Nov), once a day each.
func _action_tip(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 2:
		return
	var coins: int = GameState.pay_tip(args[1], int(args[0]))
	if coins <= 0:
		await say(["Nobody pays twice a day. Come back tomorrow."] as Array[String])
		return
	Sound.sfx("pickup")
	await say(["You got %d coins!" % coins] as Array[String])

func _action_give_item(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var count: int = int(args[1]) if args.size() > 1 else 1
	GameState.add_item(args[0], count)
	Sound.sfx("pickup")
	var item_name: String = str(Database.item(args[0]).get("name", args[0]))
	await say(["You got %s x%d!" % [item_name, count]] as Array[String])
	if PauseMenu.bag_tab(Database.item(args[0])) == 1:
		await say(Tips.take("keepsake"))
	if bool(Database.item(args[0]).get("gear", false)):
		var tip: Array[String] = Tips.take("gear")
		if not tip.is_empty():
			await say(tip)

## "take_item <id> [count]": the player hands items over in a talk (Lipka's moss, Mirza's charm).
func _action_take_item(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var count: int = 0
	for i: int in (int(args[1]) if args.size() > 1 else 1):
		if GameState.take_item(args[0]):
			count += 1
	if count > 0:
		var item_name: String = str(Database.item(args[0]).get("name", args[0]))
		await say(["You handed over %s x%d." % [item_name, count]] as Array[String])

## "gift_spirling <Species> [ring]": a Spirling handed over in a talk (the strangers' gift from
## the other map, plan 2 item 173). It joins the team, or storage when the team is full.
func _action_gift_spirling(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var sd: SpirlingData = Database.species(args[0])
	if sd == null:
		return
	var s := Spirling.new(sd, int(args[1]) if args.size() > 1 else 5, GameState.rng)
	var joined: bool = GameState.receive_spirling(s)
	Sound.sfx("pickup")
	await say(["You received %s!" % sd.species_name] as Array[String])
	if not joined:
		await say(["%s was sent to storage." % sd.species_name] as Array[String])

# --- Story: prologue and Mirela's map book ---------------------------------------------------

## The opening of a new journey (Ali, 2026-11-04): a short narration over black, then the
## morning after the storm in the lighthouse, where the partner Spirling is picked in the story.
func prologue() -> void:
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	_fade.color.a = 1.0
	# The storm night is a real scene with lightning and thunder (plan item 1410).
	await play_scene("prologue")
	busy = true
	player.frozen = true
	_fade.color.a = 1.0
	Sound.enter_map(map.id)
	var tw: Tween = create_tween()
	Juice.shaped(tw.tween_property(_fade, "color:a", 0.0, 0.6), "fade")
	await tw.finished
	busy = false
	# The prologue dialogue picks the partner ("choose_starter"); Aldo then hands over the map book.
	while not GameState.has_flag("got_starter"):
		await run_dialogue("lighthouse/morning")
	await run_dialogue("lighthouse/aldo")
	# Saved right after the prologue, and the tip says saving also works in the menu (1988).
	SaveManager.save_game()
	await _locked_say(Tips.take("save"))
	show_walk_hint()

## One line per starter under the partner list, so the choice is not made blind (onboarding).
const STARTER_HINTS: Dictionary[String, String] = {
	"Kindlop": "Warm and loyal. Sets things on fire when nervous. Mostly your things.",
	"Zippit": "Quick and twitchy. Every hug comes with a small shock. You get used to it.",
	"Wickit": "Its light never goes out. Handy when someone cuts the lamps on purpose.",
}
const STARTER_TITLE: String = "Pick your partner"

## The partner list: name and element per row, a short description as the row's hint.
static func starter_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sp: String in Database.STARTERS:
		out.append({"text": "%s (%s)" % [sp, Elements.element_name(Database.species(sp).elements[0])],
			"hint": Loc.t(str(STARTER_HINTS.get(sp, "")))})
	return out

## "choose_starter": the three Spirlings that sheltered from the storm; one stays.
func _action_choose_starter(_args: PackedStringArray, _speaker: NPC) -> void:
	if GameState.has_flag("got_starter"):
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	while true:
		var pick: int = await menu.pick(STARTER_TITLE, starter_rows(), false)
		var sd: SpirlingData = Database.species(Database.STARTERS[pick])
		if await menu.confirm("%s, the %s Spirling, curls up at your feet. Let it stay?" % [sd.species_name, Elements.element_name(sd.elements[0])]):
			GameState.choose_starter(sd.species_name)
			break
	menu.queue_free()
	Sound.sfx("level_up")
	await say(["%s decided to stay with you!" % GameState.starter,
		"The other two slip out into the morning, toward the lake."] as Array[String])

## Mirela's map book has 14 pages: 1-6 in Veydal (Act I), 7-10 in Corvane, 11-14 in Ashmere.
const PAGE_COUNT: int = 14
const VEYDAL_PAGES: int = 6
## Echo melody score that counts as a good answer outside battle.
const ECHO_SONG_PASS: float = 0.6

## How many of Mirela's map-book pages the player has found (of [param upto]).
static func pages_found(flags: Dictionary, upto: int = PAGE_COUNT) -> int:
	var n: int = 0
	for i: int in range(1, upto + 1):
		n += 1 if bool(flags.get("page_%d" % i, false)) else 0
	return n

## How many pages the player knows of: six until Act II shows there are more.
static func page_total(flags: Dictionary) -> int:
	return PAGE_COUNT if bool(flags.get("ferry_corvane_open", false)) else VEYDAL_PAGES

## "page <n>": one of Mirela's map-book pages. Shows the page and counts it. The six Veydal
## pages set "pages_all" (lamp room), all fourteen set "pages_complete".
func _action_page(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var flag: String = "page_%s" % args[0]
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	Sound.sfx("level_up")
	var n: int = pages_found(GameState.flags)
	await say(["A page from Mirela's map book! (%d/%d)" % [n, page_total(GameState.flags)]] as Array[String])
	await say(Dialogue.lines_for(Dialogue.get_entry("story/page_%s" % args[0]), GameState.flags))
	GameState.set_flag("page_%s_read" % args[0])
	if pages_found(GameState.flags, VEYDAL_PAGES) >= VEYDAL_PAGES and not GameState.has_flag("pages_all"):
		GameState.set_flag("pages_all")
		await say(["That's all six pages. Aldo should see them."] as Array[String])
	else:
		await say(Tips.take("map_page"))
	if n >= PAGE_COUNT:
		GameState.set_flag("pages_complete")
		await say(["All fourteen pages. Mirela's whole map book, together again."] as Array[String])

## "set_var <name> <value>": a story number such as kestra_trust (plan item 1339).
func _action_set_var(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() >= 2:
		GameState.set_story_var(args[0], int(args[1]))

## "add_var <name> <amount>"
func _action_add_var(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() >= 1:
		GameState.add_story_var(args[0], int(args[1]) if args.size() > 1 else 1)

## "favor <id>": the player lends a Spirling, lends coins or believes a tip (data/clans.json).
## The hidden trust and use values decide whether the figure betrays, rewards or simply keeps
## its word (Trust.resolve); the effects are applied in order. Each favor runs once.
func _action_favor(args: PackedStringArray, speaker: NPC) -> void:
	if args.is_empty():
		return
	var def: Dictionary = Trust.favor(args[0])
	if def.is_empty() or GameState.has_flag("favor_" + args[0]):
		return
	var amount: int = int(def.get("amount", 0))
	if str(def.kind) == "lend_coins":
		if GameState.money < amount:
			await say(["You don't have that many coins."] as Array[String])
			return
		GameState.money -= amount
	GameState.set_flag("favor_" + args[0])
	var npc: String = str(def.npc)
	var result: String = Trust.resolve(def, Trust.trust(npc), Trust.use(npc), GameState.rng.randf())
	await _apply_clan_effects(Trust.effects(def, result), speaker)

## "betrayal <id>": a scripted betrayal from data/clans.json. It always happens; a warning
## the player picked up (or enough trust) turns it from "struck" into "caught". Runs once.
func _action_betrayal(args: PackedStringArray, speaker: NPC) -> void:
	if args.is_empty():
		return
	var def: Dictionary = Trust.betrayal(args[0])
	if def.is_empty() or GameState.has_flag("betrayal_" + args[0]):
		return
	GameState.set_flag("betrayal_" + args[0])
	var result: String = Trust.betrayal_result(def, GameState.flags, GameState.story_vars)
	await _apply_clan_effects(Trust.effects(def, result), speaker)

## "trust <figure> <change> [use change]": moves the hidden values (nothing is shown).
func _action_trust(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 2:
		return
	var eff: Dictionary = {"trust": {args[0]: int(args[1])}}
	if args.size() > 2:
		eff["use"] = {args[0]: int(args[2])}
	Trust.apply_values(eff, GameState.story_vars)

## "ledger <id>": a new entry in the Ledger (pause menu).
func _action_ledger(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty() or GameState.has_flag(Trust.ledger_flag(args[0])):
		return
	GameState.set_flag(Trust.ledger_flag(args[0]))
	Sound.sfx("confirm")
	await say(["A new entry in your Ledger."] as Array[String])

func _apply_clan_effects(eff: Dictionary, speaker: NPC) -> void:
	Trust.apply_values(eff, GameState.story_vars)
	for f: Variant in eff.get("flags", []):
		GameState.set_flag(str(f))
	if eff.has("say"):
		await play_entry(str(eff.say), speaker)
	var coins: int = int(eff.get("coins", 0))
	if coins > 0:
		GameState.money += coins
		Sound.sfx("pickup")
		await say(["You got %d coins!" % coins] as Array[String])
	elif coins < 0 and GameState.money > 0:
		var lost: int = GameState.money - Trust.money_after(GameState.money, coins)
		GameState.money -= lost
		await say(["You lost %d coins." % lost] as Array[String])
	if bool(eff.get("take_keepsake", false)) and not GameState.party.is_empty() and not GameState.party[0].held.is_empty():
		var lost: String = str(Database.item(GameState.party[0].held).get("name", GameState.party[0].held))
		GameState.party[0].held = ""
		await say(["%s came back without its keepsake (%s)." % [GameState.party[0].display_name(), lost]] as Array[String])
	if eff.has("item"):
		await _action_give_item(PackedStringArray([str(eff.item)]), speaker)
	if eff.has("ledger"):
		await _action_ledger(PackedStringArray([str(eff.ledger)]), speaker)
	if eff.has("battle"):
		await _action_battle(PackedStringArray([str(eff.battle)]), speaker)

## "battle <id>": a story duel from data/story_battles.json, straight out of a talk or scene
## (plan item 1340). Wins set the beaten flag "beat_story_<id>" and the entry's win_flags.
func _action_battle(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var def: Dictionary = StoryBattles.get_def(args[0])
	if def.is_empty() or GameState.first_healthy_index() < 0:
		return
	var team: Array[Spirling] = TrainerData.build_team(def, GameState.starter, GameState.rng)
	if team.is_empty():
		return
	_text.visible = false
	SaveManager.save_game()
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level())
	var outcome: BattleModel.Outcome = await start_battle(team, bool(info.wild), info)
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	if outcome == BattleModel.Outcome.WIN:
		GameState.set_flag(StoryBattles.beaten_flag(args[0]))
		for f: Variant in def.get("win_flags", []):
			GameState.set_flag(str(f))
		if def.has("defeat"):
			await play_entry(str(def.defeat))
	elif def.has("lose"):
		await play_entry(str(def.lose))
	# A lost story duel sends the player to the last rest spot, so the scene around it stops
	# there (it has not been "seen" and starts again, e.g. the finale chain).
	if outcome == BattleModel.Outcome.LOSS:
		scene_abort = scene_running

## "scene <id>": plays data/scenes/<id>.json (plan item 1341).
func _action_scene(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	await play_scene(args[0])

## "warp <map> <x> <y> [facing]": moves the player to another map (ferry, coach). Used by
## story scenes and by area 3's ferry signs. A map that does not exist yet stops the scene.
func _action_warp(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 3:
		return
	if not MapData.exists(args[0]):
		scene_abort = scene_running
		await say(["The far landing is still being rebuilt after the storm. Not yet."] as Array[String])
		return
	var was_black: bool = _fade.color.a >= 0.99
	Sound.sfx("warp")
	if not was_black:
		await _fade_to(1.0)
	load_map(args[0], Vector2i(int(args[1]), int(args[2])), args[3] if args.size() > 3 else player.facing)
	Sound.music(Sound.track_for_map(args[0]))
	SaveManager.save_game()
	if not was_black and not scene_running:
		await _fade_to(0.0)

## "transit <line>": the boatman or the coach driver offers the open stops of the line
## (area 3 items 1187-1191). The trip is a short scene, then the player stands at the stop.
func _action_transit(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty() or Transit.line(args[0]).is_empty():
		return
	var id: String = args[0]
	var kind: String = str(Transit.line(id).get("kind", "boat"))
	var open: Array[String] = Transit.open_stops(id, map.id, GameState.flags, GameState.visited_rests)
	if open.is_empty():
		await say([Transit.no_stops_line(kind)] as Array[String])
		return
	var entries: Array[Dictionary] = []
	for s: String in open:
		entries.append({"text": MapData.load_map(s).display_name if MapData.exists(s) else s})
	var idx: int = await _picker.pick(str(Transit.line(id).get("name", "")), entries, true)
	if idx < 0 or idx >= open.size():
		return
	await take_trip(id, open[idx])

## Plays the trip scene for [param line_id] and puts the player at the stop on [param to].
func take_trip(line_id: String, to: String) -> void:
	var at: Dictionary = Transit.arrival(line_id, to)
	if at.is_empty() or not MapData.exists(to):
		return
	var kind: String = str(Transit.line(line_id).get("kind", "boat"))
	Sound.sfx("warp")
	await _fade_to(1.0)
	var scene := TripScene.new(kind, Transit.trip_line(kind, MapData.load_map(to).display_name))
	_ui_root.add_child(scene)
	await scene.run()
	scene.queue_free()
	_on_trip = true
	load_map(to, at.cell, at.facing)
	_on_trip = false
	Sound.music(Sound.track_for_map(to))
	SaveManager.save_game()
	await _fade_to(0.0)

## "echo_song <flag>": the player answers a hushed Spirling's call with the Echo melody
## outside battle (the bond minigame). A good echo sets the flag; a weak one can be retried
## by talking again. Nothing is bonded or caught.
func _action_echo_song(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty() or GameState.has_flag(args[0]):
		return
	_text.visible = false
	var game := BondMinigame.new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.BG, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(dim)
	_ui_root.add_child(game)
	var score: float = await game.run()
	game.queue_free()
	dim.queue_free()
	if score >= ECHO_SONG_PASS:
		Sound.sfx("level_up")
		GameState.set_flag(args[0])
		DailyTasks.record("melody", {"map": map.id})
	if score >= 1.0:
		GameState.records["melody_perfect"] = 1
	else:
		Sound.sfx("cancel")

## "quest_stage <id> <n>": moves a side goal with stages to step n (plan item 1631).
func _action_quest_stage(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() >= 2:
		GameState.set_story_var("q_%s_stage" % args[0], int(args[1]))

## A map's arrival scene (story_npcs.json "on_enter"), once the map change has finished.
func _arrival_scene(id: String) -> void:
	while _fade.color.a > 0.0 and not scene_running:
		await get_tree().process_frame
	if scene_running:
		# Arrived during a scene (a ferry crossing): play right after it.
		while scene_running:
			await get_tree().process_frame
	var goal_before: int = QuestLog.current_index(GameState.flags)
	busy = true
	player.frozen = true
	await play_scene(id)
	await announce_goal_if_changed(goal_before)
	player.frozen = false
	busy = false
	VirtualPad.set_wanted(true)

## Plays a cut-scene and returns to the talk or the world afterwards.
func play_scene(id: String) -> void:
	var sp := ScenePlayer.new()
	sp.overworld = self
	add_child(sp)
	await sp.play(id)
	sp.queue_free()

func _action_set_flag(args: PackedStringArray, _speaker: NPC) -> void:
	for f: String in args:
		GameState.set_flag(f)

## "quest_show <id> <Species> <item> [count]": show the NPC a Spirling of that species in your team.
## Flags: q_<id>_asked once asked, q_<id>_done once rewarded.
func _action_quest_show(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 3:
		return
	var id: String = args[0]
	if GameState.has_flag("q_%s_done" % id):
		return
	GameState.set_flag("q_%s_asked" % id)
	for s: Spirling in GameState.party:
		if s.data.species_name == args[1]:
			await say(["Oh! Is that a %s? Wonderful. Here, take this!" % args[1]] as Array[String])
			GameState.set_flag("q_%s_done" % id)
			await _action_give_item([args[2], args[3] if args.size() > 3 else "1"] as PackedStringArray, null)
			return

## "lever <flag> <gear>": a sluice wheel, mine cart or grate that needs Wayfarer Gear (the Pry
## Bar). With the gear the flag is set and blocks with that open_flag open (area 3 item 1045).
## "lever <flag> [gear]": without gear it is a plain lever (shortcuts that open from inside,
## area 3 item 983).
func _action_lever(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	if GameState.has_flag(args[0]):
		await say(["It has already been moved."] as Array[String])
		return
	if args.size() < 2:
		GameState.set_flag(args[0])
		Sound.sfx("warp")
		_world.refresh(player.cell)
		await say(["You pull the lever. Somewhere a rope ladder rattles down."] as Array[String])
		return
	if not GameState.has_gear(args[1]):
		Sound.sfx("bump")
		await say([str(Database.item(args[1]).get("hint", "It won't budge."))] as Array[String])
		return
	GameState.set_flag(args[0])
	Sound.sfx("warp")
	_world.refresh(player.cell)
	await say(["You set the %s and lean on it. Something gives with a groan!" % Database.item(args[1]).get("name", args[1])] as Array[String])

# --- Hooks for WorldMechanics ------------------------------------------------------------

func ground_layer() -> TileMapLayer:
	return _ground

func npcs() -> Array[NPC]:
	return _npcs

func gear_hint_deferred(gear: String) -> void:
	_gear_hint.call_deferred(gear)

func say_locked(lines: Array[String]) -> void:
	await _locked_say(lines)

## A hidden find: its own dialogue if it has one, else a short line and the item.
func take_find(find: Dictionary) -> void:
	busy = true
	player.frozen = true
	Sound.sfx("confirm")
	if find.has("dialogue"):
		await run_dialogue(str(find.dialogue))
	else:
		# Item 1089: loose soil is dug up by hand, no Spirling needed.
		var soil: bool = bool(find.get("soil", false))
		await say([("The soil here is loose. You dig with your hands and find something..." if soil else "Something glints here...")] as Array[String])
		await _action_give_item([str(find.item), str(find.get("count", 1))] as PackedStringArray, null)
	GameState.set_flag(str(find.flag))
	player.frozen = false
	busy = false

## Cracked floor gave way: the player lands on the same cell of the floor below.
func drop_to(map_id: String, cell: Vector2i) -> void:
	var fell_from: String = map.id
	busy = true
	player.frozen = true
	Sound.sfx("bump")
	await _fade_to(1.0)
	load_map(map_id, cell, player.facing)
	SaveManager.save_game()
	await _fade_to(0.0)
	player.frozen = false
	busy = false
	await _locked_say(["The floor gave way! You land on the level below, unhurt."] as Array[String])
	await _note_room_fail(fell_from)

## A failed try in a puzzle room (area 3 item 1027): the third one pins a tip at the entrance.
func _note_room_fail(room_id: String) -> void:
	if DungeonHints.note_fail(room_id):
		await _locked_say(["Somewhere near the entrance, someone has pinned a new note to the board."] as Array[String])

## Climbing down a rope ladder, rung by rung.
func climb_to(map_id: String, cell: Vector2i) -> void:
	busy = true
	player.frozen = true
	Sound.sfx("warp")
	await _fade_to(1.0)
	load_map(map_id, cell, "down")
	SaveManager.save_game()
	await _fade_to(0.0)
	player.frozen = false
	busy = false

## "switch <puzzle> <n> <total>": lamps/levers that must be used in order 1..total.
## Wrong order resets the puzzle; finishing sets the flag <puzzle> and opens its blocks.
func _action_switch(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 3:
		return
	var puzzle: String = args[0]
	if GameState.has_flag(puzzle):
		await say(["The lamp still burns."] as Array[String])
		return
	var result: int = GameState.press_switch(puzzle, int(args[1]), int(args[2]))
	match result:
		GameState.SwitchResult.WRONG:
			Sound.sfx("cancel")
			await say(["The lamp flares... and every lamp gutters out. Wrong order."] as Array[String])
		GameState.SwitchResult.STEP:
			Sound.sfx("confirm")
			await say(["The lamp flickers to life."] as Array[String])
		GameState.SwitchResult.SOLVED:
			Sound.sfx("warp")
			_world.refresh(player.cell)
			await say(["The last lamp catches. Somewhere, rock grinds against rock!"] as Array[String])

## "bell <puzzle> <n> <total>": Bellstone Ruins (area 3 item 1008). Same rules as switches:
## ring the bells in the order drawn on the wall; a wrong bell silences them all.
## Lines of an ordered switch puzzle per kind ("bell <flag> <n> <total> [kind]"): done, wrong,
## step, solved. Bells in the Bellstone Ruins, wind vanes in the Mist Rift, roots in the Root Rift.
const SWITCH_LINES: Dictionary[String, Array] = {
	"bell": ["The bell hums softly. This room is done.", "Clang! The note jars, and every bell falls silent. Start again.",
		"Dong. The note hangs in the air.", "The last note joins the others. A door swings open!"],
	"vane": ["The vanes turn on their own now. The path stays clear.", "The wind swings round and the fog rolls back in. Start again.",
		"The vane creaks round. A thin wind starts to blow.", "All three vanes catch the wind. The fog tears open!"],
	"root": ["The roots glow softly. The way stays open.", "The colour drains away again. Start with the first root.",
		"The root takes the colour and glows.", "The last root glows, and the tangle pulls aside!"],
	"shutter": ["The shutters hum in the wind. The stair stays open.", "The shutter bangs, and the wind drops dead. Every shutter swings shut again.",
		"The shutter swings open. Sand hisses through the slats.", "The last shutter opens, the tower breathes, and the stair is clear!"],
	"feather": ["The feathers lie still. This room is done.", "A feather twitches the wrong way, and every feather drops flat. Start again.",
		"The feather lifts and points at the ceiling.", "The last feather rises. Stone scrapes, and the stair opens!"],
	"valve": ["The pipes gurgle along happily. The stair stays dry.", "The valve screams, and every pipe slams shut again. Start over.",
		"The valve squeals round. Somewhere, water changes owner.", "The last valve turns, the cistern drains, and the stair is clear!"],
	"lens": ["The lenses send the light up the stair. It stays lit.", "The lens cracks the light into rainbows, and every lens swings back. Start over.",
		"The lens turns. A spot of sun crawls up the wall.", "The last lens turns, the light hits the stair, and the glass door melts aside!"],
	"bellows": ["The bellows breathe on their own now. The stair stays clear.", "The bellows wheeze, cough, and every one sags flat again. Start over.",
		"The bellows heave. Somewhere below, a fire wakes up grumpy.", "The last bellows heaves, the smoke clears off the stair, and the way down is open!"],
}

func _action_bell(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 3:
		return
	var texts: Array = SWITCH_LINES.get(args[3] if args.size() > 3 else "bell", SWITCH_LINES["bell"])
	if GameState.has_flag(args[0]):
		await say([str(texts[0])] as Array[String])
		return
	match GameState.press_switch(args[0], int(args[1]), int(args[2])):
		GameState.SwitchResult.WRONG:
			Sound.sfx("cancel")
			await say([str(texts[1])] as Array[String])
			await _note_room_fail(map.id)
		GameState.SwitchResult.STEP:
			Sound.sfx("confirm")
			await say([str(texts[2])] as Array[String])
		GameState.SwitchResult.SOLVED:
			Sound.sfx("warp")
			_world.refresh(player.cell)
			await say([str(texts[3])] as Array[String])

## "toggle <flag>": a sluice wheel that can be turned both ways (Brackwater Sluice, item 1009).
func _action_toggle(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var on: bool = not GameState.has_flag(args[0])
	GameState.set_flag(args[0], on)
	Sound.sfx("warp")
	_world.refresh(player.cell)
	var level: int = _world.water_level(map)
	var line: String = "You turn the wheel open. The water is now at mark %d." if on else "You turn the wheel shut. The water is now at mark %d."
	await say([line % level] as Array[String])

## "mirror <x> <y>": turns a mirror in Lanternwell (item 1010) and follows the light again.
func _action_mirror(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 2:
		return
	var hit: bool = _world.turn_mirror(Vector2i(int(args[0]), int(args[1])))
	Sound.sfx("warp" if hit else "confirm")
	await say(["The light strikes the crystal, and it rings out bright!" if hit else "You turn the mirror. The beam swings to a new wall."] as Array[String])

## Post-game gauntlet: five echo Wayfarers in a row, scaled to your strongest Spirling, no rest.
func _action_gauntlet(_args: PackedStringArray, _speaker: NPC) -> void:
	if not GameState.has_flag("tower_intro"):
		GameState.set_flag("tower_intro")
		await say(["The stair has %d floors. There is no healing on the way, only at a rest point after every tenth floor, where your climb is saved." % Gauntlet.FLOORS] as Array[String])
	var menu := MenuHost.new()
	_ui.add_child(menu)
	if Gauntlet.endless_open() or Masters.round_open():
		var ways: Array[String] = [Loc.t("Climb the stair")]
		var kinds: Array[String] = ["stair"]
		if Gauntlet.endless_open():
			ways.append(Loc.t("Endless stretch (best %d)") % Gauntlet.endless_best())
			kinds.append("endless")
		if Masters.round_open():
			ways.append(Loc.t("Master round (best %d of %d)") % [Masters.round_best(), Masters.list().size()])
			kinds.append("masters")
		var way: int = await menu.pick_strings(Loc.t("The lighthouse stair"), ways)
		if way < 0:
			menu.queue_free()
			return
		if kinds[way] != "stair":
			menu.queue_free()
			if kinds[way] == "masters":
				await _run_master_round()
			else:
				await _run_endless()
			return
	var best: int = Gauntlet.best()
	var start: int = 0
	var saved: int = Gauntlet.checkpoint()
	if saved > 0:
		var pick: int = await menu.pick_strings("Best so far: floor %d of %d." % [best, Gauntlet.FLOORS],
			["Continue from floor %d" % (saved + 1), "Start from floor 1"] as Array[String])
		if pick < 0:
			menu.queue_free()
			return
		start = saved if pick == 0 else 0
	elif not await menu.confirm("Climb the lighthouse stair? Best so far: floor %d of %d." % [best, Gauntlet.FLOORS]):
		menu.queue_free()
		return
	menu.queue_free()
	var run_seed: int = Gauntlet.checkpoint_seed() if start > 0 and Gauntlet.checkpoint_seed() != 0 else GameState.rng.randi()
	var run: Gauntlet = Gauntlet.new(run_seed, GameState.progress_cap())
	if start > 0:
		# Continuing at a rest point: the team starts rested, as it was when the climb was saved.
		GameState.heal_party()
	var floors: int = start
	var helper: Dictionary = await pick_echo_partner("Climb with a friend's echo beside you?")
	while floors < Gauntlet.FLOORS:
		await say(["Floor %d of %d: an echo steps out of the light..." % [floors + 1, Gauntlet.FLOORS]] as Array[String])
		var info: Dictionary = {"name": run.echo_name(floors), "ai": Gauntlet.ai_for(floors), "money": run.prize(floors)}
		var foes: Array[Spirling] = run.team(floors)
		# Every tenth floor a Warden echo stands in the light (plan 1102).
		if EchoTower.is_warden_floor(floors + 1):
			foes = EchoTower.warden_team(floors + 1, run.level_for(floors), run.rng)
			info["name"] = EchoTower.warden_name(floors + 1)
			info["warden"] = true
			await say([EchoTower.warden_line(floors + 1)] as Array[String])
		if not helper.is_empty():
			for s: Spirling in helper.partner.echo:
				s.restore()
			info["partner"] = helper.partner
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(foes, false, info)
		busy = true
		player.frozen = true
		if outcome != BattleModel.Outcome.WIN:
			break
		floors += 1
		var lines: Array[String] = Gauntlet.pay_floor(floors)
		if floors % Gauntlet.SECTION == 0 and GameState.party.all(func(s: Spirling) -> bool: return not s.is_fainted()):
			GameState.records["tower_flawless"] = 1
		if Gauntlet.is_rest_point(floors):
			Gauntlet.save_checkpoint(floors, run_seed)
			GameState.heal_party()
			lines.append("A rest point. Your team is rested and your climb is saved.")
		if not lines.is_empty():
			await say(lines)
		if Gauntlet.is_rest_point(floors):
			var m := MenuHost.new()
			_ui.add_child(m)
			var climb_on: bool = await m.confirm("Keep climbing?")
			m.queue_free()
			if not climb_on:
				break
	GameState.records["gauntlet_best"] = maxi(best, floors)
	if GameState.iron_oath:
		# Under the Iron Oath the stair keeps its own best as well (plan 3400).
		GameState.records["gauntlet_best_oath"] = maxi(int(GameState.records.get("gauntlet_best_oath", 0)), floors)
	if not helper.is_empty():
		await thank_echo(helper, floors >= Gauntlet.FLOORS)
	if floors >= Gauntlet.FLOORS:
		Gauntlet.clear_checkpoint()
		GameState.set_flag("gauntlet_clear")
		await _action_give_item([run.reward_item(), "1"] as PackedStringArray, null)
		await say(["The echoes bow and fade. You reached the lamp room!"] as Array[String])
	elif floors > best:
		await say(["New best: floor %d of %d!" % [floors, Gauntlet.FLOORS]] as Array[String])

## "postgame_board": Examiner Hollis's board in the map house (own ideas 200, batch 3): Master
## Rifts (1104), the master tour (1105), the Random Rift with rentals (1107, 1108), the weekly
## giant (1118), best times (1109) and the Cartographer's exam (1110).
func _action_postgame_board(_args: PackedStringArray, _speaker: NPC) -> void:
	var ways: Array[String] = []
	var kinds: Array[String] = []
	if not MasterRifts.open_entries().is_empty():
		ways.append(Loc.t("Master Rifts %d/%d") % [MasterRifts.won_count(), WardenRematch.entries().size()])
		kinds.append("rifts")
	if MasterTour.is_open():
		ways.append(Loc.t("Master tour (best %d of %d)") % [MasterTour.best(), MasterTour.steps()])
		kinds.append("tour")
	ways.append(Loc.t("Random Rift"))
	kinds.append("random")
	ways.append(Loc.t("Weekly giant"))
	kinds.append("giant")
	ways.append(Loc.t("Best times"))
	kinds.append("times")
	ways.append(Loc.t("Cartographer's exam"))
	kinds.append("exam")
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var way: int = await menu.pick_strings(Loc.t("The board"), ways)
	menu.queue_free()
	if way < 0:
		return
	match kinds[way]:
		"rifts":
			await _run_master_rift()
		"tour":
			await _run_master_tour()
		"random":
			await _run_random_rift()
		"giant":
			await _run_weekly_giant()
		"times":
			await _show_hall_times()
		"exam":
			await _run_final_exam()

## One timed battle for a hall; books the time on a win and says a new best.
func _timed_battle(hall: String, foes: Array[Spirling], info: Dictionary) -> BattleModel.Outcome:
	var t0: int = Time.get_ticks_msec()
	busy = false
	var outcome: BattleModel.Outcome = await start_battle(foes, false, info)
	busy = true
	player.frozen = true
	if outcome == BattleModel.Outcome.WIN and HallTimes.submit(hall, maxi(1, (Time.get_ticks_msec() - t0) / 1000)):
		await say([Loc.t("New best time: %s") % HallTimes.fmt(HallTimes.best(hall))] as Array[String])
	return outcome

func _run_master_rift() -> void:
	var open: Array[Dictionary] = MasterRifts.open_entries()
	var names: Array[String] = []
	for e: Dictionary in open:
		names.append(("[x] " if GameState.has_flag(MasterRifts.won_flag(e)) else "[ ] ") + MasterRifts.title(e))
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var pick: int = await menu.pick_strings(Loc.t("Which Rift?"), names)
	menu.queue_free()
	if pick < 0:
		return
	var e: Dictionary = open[pick]
	await say([Loc.t(str(MasterRifts.data().get("intro", "")))] as Array[String])
	GameState.heal_party()
	var info: Dictionary = {"name": Loc.t(str(e.get("name", ""))), "ai": 3, "money": int(e.get("money", 0)),
		"profile": str(e.get("profile", "")), "rule": MasterRifts.rule(e), "warden": true}
	var outcome: BattleModel.Outcome = await _timed_battle("rift_" + str(e.get("warden", "")), MasterRifts.team(e, GameState.rng), info)
	if outcome == BattleModel.Outcome.WIN:
		await say(MasterRifts.win(e))

func _run_master_tour() -> void:
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var go: bool = await menu.confirm(Loc.t(str(MasterTour.data().get("intro", ""))))
	menu.queue_free()
	if not go:
		return
	GameState.heal_party()
	var beaten: int = 0
	var t0: int = Time.get_ticks_msec()
	while beaten < MasterTour.steps():
		var e: Dictionary = MasterTour.entry(beaten)
		if beaten > 0:
			await say([Loc.t(str(MasterTour.data().get("step_line", ""))) % [beaten + 1, MasterTour.steps()]] as Array[String])
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(MasterTour.team(beaten, GameState.rng), false,
			{"name": Loc.t(str(e.get("name", ""))), "ai": 3, "money": 0, "profile": str(e.get("profile", "")), "warden": true})
		busy = true
		player.frozen = true
		if outcome != BattleModel.Outcome.WIN:
			break
		beaten += 1
	var lines: Array[String] = [Loc.t("Master tour: %d of %d Wardens.") % [beaten, MasterTour.steps()]]
	if beaten >= MasterTour.steps() and HallTimes.submit("tour", maxi(1, (Time.get_ticks_msec() - t0) / 1000)):
		lines.append(Loc.t("New best time: %s") % HallTimes.fmt(HallTimes.best("tour")))
	lines.append_array(MasterTour.finish(beaten))
	await say(lines)

func _run_random_rift() -> void:
	var rift := RandomRift.new(DailyFind.today_key())
	var menu := MenuHost.new()
	_ui.add_child(menu)
	await menu.info(rift.intro())
	var pick: int = await menu.pick_strings(Loc.t(str(RandomRift.data().get("rental_ask", ""))),
		[Loc.t("Own team"), Loc.t("Rentals")] as Array[String])
	menu.queue_free()
	if pick < 0:
		return
	if pick == 1:
		GameState.party_on_loan = GameState.party
		GameState.party = rift.rentals()
	GameState.heal_party()
	var won: int = 0
	var t0: int = Time.get_ticks_msec()
	while won < rift.rounds():
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(rift.team(won), false,
			{"name": Loc.t("Rift echo %d") % (won + 1), "ai": 3, "money": 0, "field": rift.field, "rule": rift.rule})
		busy = true
		player.frozen = true
		if outcome != BattleModel.Outcome.WIN:
			break
		won += 1
	if not GameState.party_on_loan.is_empty():
		GameState.party = GameState.party_on_loan
		GameState.party_on_loan = []
		GameState.heal_party()
	var lines: Array[String] = [Loc.t("Random Rift: %d of %d rounds.") % [won, rift.rounds()]]
	if won >= rift.rounds():
		if HallTimes.submit("random", maxi(1, (Time.get_ticks_msec() - t0) / 1000)):
			lines.append(Loc.t("New best time: %s") % HallTimes.fmt(HallTimes.best("random")))
		lines.append_array(rift.clear())
	await say(lines)

func _run_weekly_giant() -> void:
	var week: String = WeeklyChallenge.this_week()
	var g: Dictionary = WeeklyGiant.giant(week)
	var foes: Array[Spirling] = WeeklyGiant.foe(week, GameState.rng)
	if foes.is_empty():
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var go: bool = await menu.confirm(Loc.t(str(WeeklyGiant.data().get("intro", ""))) % [foes[0].display_name(), int(WeeklyGiant.record(week).best)])
	menu.queue_free()
	if not go:
		return
	GameState.heal_party()
	busy = false
	await start_battle(foes, false, {"name": foes[0].display_name(), "ai": 3, "money": 0, "boss": str(g.get("boss", "")), "warden": true})
	busy = true
	player.frozen = true
	var pct: int = WeeklyGiant.share_pct(foes[0].max_hp(), foes[0].hp)
	var lines: Array[String] = [Loc.t(str(WeeklyGiant.data().get("result", ""))) % pct]
	lines.append_array(WeeklyGiant.submit(week, pct))
	await say(lines)

func _show_hall_times() -> void:
	var names: Dictionary = {"tour": Loc.t("Master tour"), "random": Loc.t("Random Rift"), "exam": Loc.t("Cartographer's exam")}
	for e: Variant in WardenRematch.entries():
		names["rift_" + str((e as Dictionary).get("warden", ""))] = MasterRifts.title(e)
	var lines: Array[String] = HallTimes.lines(names)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	await menu.info("\n".join(lines) if not lines.is_empty() else Loc.t("No times yet."))
	menu.queue_free()

func _run_final_exam() -> void:
	if FinalExam.passed():
		await say(FinalExam.lines("done_line"))
		return
	if not FinalExam.is_open():
		await say(FinalExam.lines("locked"))
		return
	await say(FinalExam.lines("intro"))
	GameState.heal_party()
	var info: Dictionary = {"name": Loc.t(str(FinalExam.data().get("name", ""))), "ai": 3, "money": 0, "profile": "tactician", "warden": true}
	var outcome: BattleModel.Outcome = await _timed_battle("exam", FinalExam.team(GameState.rng), info)
	if outcome == BattleModel.Outcome.WIN:
		await say(FinalExam.pass_exam())

## "rift_tower <id>": a Rift tower (plan 3266-3275). Up to three Spirlings at ring 30 or more
## climb fifteen floors; the team rests every five floors.
func _action_rift_tower(args: PackedStringArray, _speaker: NPC) -> void:
	var t: Dictionary = RiftTower.find(args[0] if not args.is_empty() else "")
	if t.is_empty() or not RiftTower.is_open(t):
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var ok: Array[Spirling] = RiftTower.eligible(GameState.party)
	if ok.is_empty():
		await menu.info(RiftTower.entrance_text(t) + "\n" + Loc.t("None of your Spirlings is at ring %d yet.") % RiftTower.MIN_RING)
		menu.queue_free()
		return
	if not await menu.confirm(RiftTower.entrance_text(t) + "\n" + Loc.t("Enter?")):
		menu.queue_free()
		return
	var team: Array[Spirling] = []
	while team.size() < RiftTower.MAX_TEAM and team.size() < ok.size():
		var left: Array[Spirling] = ok.filter(func(s: Spirling) -> bool: return not s in team)
		if team.size() > 0 and left.is_empty():
			break
		var names: Array[String] = []
		for s: Spirling in left:
			names.append("%s (%s)" % [s.display_name(), Loc.t("Ring %d") % s.level])
		if team.size() > 0:
			names.append(Loc.t("Go with %d") % team.size())
		var i: int = await menu.pick_strings(Loc.t("Pick Spirling %d of up to %d") % [team.size() + 1, RiftTower.MAX_TEAM], names)
		if i < 0:
			menu.queue_free()
			return
		if i >= left.size():
			break
		team.append(left[i])
	menu.queue_free()
	rift_opens()
	var run := RiftTower.new(t, GameState.rng.randi())
	GameState.party_on_loan = GameState.party
	GameState.party = team
	GameState.heal_party()
	var cleared: int = 0
	while cleared < RiftTower.floors(t):
		await say([run.floor_card(cleared)] as Array[String])
		var info: Dictionary = {"name": Gauntlet.new(run.seed_value, 1).echo_name(cleared), "ai": RiftTower.ai_for(cleared),
			"money": run.prize(cleared), "shade": RiftTower.shade(t, cleared), "variants": run.variants_for(cleared)}
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(run.team(cleared), false, info)
		busy = true
		player.frozen = true
		if outcome != BattleModel.Outcome.WIN:
			break
		cleared += 1
		if cleared % RiftTower.SECTION == 0 and cleared < RiftTower.floors(t):
			GameState.heal_party()
			var m := MenuHost.new()
			_ui.add_child(m)
			var on: bool = await m.confirm(Loc.t("Your team rests. Go on?"))
			m.queue_free()
			if not on:
				break
	GameState.party = GameState.party_on_loan
	GameState.party_on_loan = []
	var lines: Array[String] = [Loc.t("%s: %d of %d floors.") % [Loc.t(str(t.name)), cleared, RiftTower.floors(t)]]
	lines.append_array(RiftTower.finish(t, cleared))
	await say(lines)
	await announce_achievements()

## Master round (plan 3292): all eight masters in a row, healed at the start and once halfway.
func _run_master_round() -> void:
	GameState.heal_party()
	var beaten: int = 0
	var all: Array[Dictionary] = Masters.list()
	for m: Dictionary in all:
		await say([Loc.t("Master %d of %d: %s, %s.") % [beaten + 1, all.size(), str(m.name), Loc.t(str(m.title))]] as Array[String])
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(Masters.team(str(m.id)), false,
			{"name": "%s, %s" % [str(m.name), Loc.t(str(m.title))], "ai": 3})
		busy = true
		player.frozen = true
		if outcome != BattleModel.Outcome.WIN:
			break
		beaten += 1
		if beaten == Masters.ROUND_REST_AFTER and beaten < all.size():
			GameState.heal_party()
			await say([Loc.t("Halfway. Your team is rested.")] as Array[String])
	var lines: Array[String] = [Loc.t("Master round: %d of %d beaten.") % [beaten, all.size()]]
	lines.append_array(Masters.finish_round(beaten))
	await say(lines)

## Endless stretch (plan 3264-3265): one fight after another, one ring stronger each floor,
## no healing; the run ends with the first loss or when the player stops.
func _run_endless() -> void:
	GameState.heal_party()
	var run: Gauntlet = Gauntlet.new(GameState.rng.randi(), GameState.progress_cap())
	var k: int = 0
	while true:
		await say([Loc.t("Endless floor %d: ring %d.") % [k + 1, run.endless_level(k)]] as Array[String])
		var info: Dictionary = {"name": run.echo_name(Gauntlet.FLOORS + k), "ai": 3, "money": run.prize(Gauntlet.FLOORS)}
		# The stair and the endless stretch are one tower of 100 floors (plan 1101, 1102).
		var tf: int = EchoTower.tower_floor(k)
		var foes: Array[Spirling] = run.endless_team(k)
		if EchoTower.is_warden_floor(tf):
			foes = EchoTower.warden_team(tf, run.endless_level(k), run.rng)
			info["name"] = EchoTower.warden_name(tf)
			info["warden"] = true
			await say([EchoTower.warden_line(tf)] as Array[String])
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(foes, false, info)
		busy = true
		player.frozen = true
		if outcome != BattleModel.Outcome.WIN:
			break
		k += 1
		var top: Array[String] = EchoTower.pay_top(tf)
		if not top.is_empty():
			await say(top)
			await _action_give_item([str(EchoTower.data().get("top_item", "max_tonic")), "1"] as PackedStringArray, null)
		if k % Gauntlet.SECTION == 0:
			var m := MenuHost.new()
			_ui.add_child(m)
			var on: bool = await m.confirm(Loc.t("Endless floor %d cleared. Keep going?") % k)
			m.queue_free()
			if not on:
				break
	var lines: Array[String] = [Loc.t("Endless stretch: %d floors (best %d).") % [k, maxi(k, Gauntlet.endless_best())]]
	lines.append_array(Gauntlet.pay_endless(k))
	await say(lines)

## Weekly challenge (item 88, plan area 8): five echo Wayfarers that are the same for everyone this week.
func _action_weekly(_args: PackedStringArray, _speaker: NPC) -> void:
	var week: String = WeeklyChallenge.this_week()
	var ch := WeeklyChallenge.new(week, GameState.progress_cap())
	var rec: Dictionary = WeeklyChallenge.record_for(week)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var go: bool = false
	while true:
		var ask: String = Loc.t("This week: %s, rule %s. Five echoes at ring %d. Best this week: %d of %d.") % [
			Loc.t(str(BattleRules.FIELDS[ch.field].label)), Loc.t(str(BattleRules.RULES[ch.rule].label)), ch.level, int(rec.best), WeeklyChallenge.ROUNDS]
		if not ch.variant.is_empty():
			ask += "\n" + ch.variant_line()
		ask += "\n" + Loc.t("Tries with prizes left: %d of %d.") % [WeeklyChallenge.prize_tries_left(rec), WeeklyChallenge.PRIZE_TRIES]
		var pick: int = await menu.pick_strings(ask, [Loc.t("Try"), Loc.t("Preview"), Loc.t("Archive")] as Array[String])
		if pick == 0:
			go = true
			break
		if pick == 1:
			await menu.info(ch.preview_text())
		elif pick == 2:
			await menu.info(WeeklyChallenge.archive_text())
		else:
			break
	menu.queue_free()
	if not go:
		return
	var prizes: bool = WeeklyChallenge.start_try(rec)
	GameState.records["weekly"] = rec
	if not ch.loan.is_empty():
		GameState.party_on_loan = GameState.party
		GameState.party = ch.loan_party()
		await say([ch.mode_line()] as Array[String])
	else:
		GameState.heal_party()
		await say(["Your team is fully rested."] as Array[String])
	var wins: int = 0
	var turns_total: int = 0
	while wins < WeeklyChallenge.ROUNDS:
		var info: Dictionary = {"name": "Weekly Echo %d" % (wins + 1), "ai": 3, "rule": ch.rule, "field": ch.field, "variants": ch.variant_ids()}
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(ch.team(wins), false, info)
		busy = true
		player.frozen = true
		var turns: int = last_model.turn if last_model != null else 0
		turns_total += turns
		if outcome != BattleModel.Outcome.WIN:
			break
		wins += 1
		var lines: Array[String] = [WeeklyChallenge.round_text(wins, turns, GameState.party)]
		var coins: int = WeeklyChallenge.claim_interim(rec, wins) if prizes else 0
		if coins > 0:
			lines.append("Interim prize: %d coins." % coins)
		await say(lines)
	var booked: Array[String] = ch.finish_run(rec, wins, turns_total, GameState.party, prizes)
	if not booked.is_empty():
		await say(booked)
	# Weekly board (item 125): rounds won and health left; the server keeps the best.
	Online.call_fn("weekly_submit", {"p_week": week, "p_score": EchoTeam.weekly_score(wins, GameState.party)})
	if wins >= WeeklyChallenge.ROUNDS and GameState.party.all(func(s: Spirling) -> bool: return not s.is_fainted()):
		GameState.records["weekly_flawless"] = 1
	if not GameState.party_on_loan.is_empty():
		GameState.party = GameState.party_on_loan
		GameState.party_on_loan = []
	if wins >= WeeklyChallenge.ROUNDS and prizes and not bool(rec.claimed):
		rec.claimed = true
		GameState.records["weekly_wins"] = int(GameState.records.get("weekly_wins", 0)) + 1
		GameState.money += WeeklyChallenge.PRIZE
		var won: Array[String] = ["You won this week's challenge! You received %d coins." % WeeklyChallenge.PRIZE]
		won.append_array(Waymarks.reward_lines(Waymarks.earn(WeeklyChallenge.full_waymarks(rec), "weekly")))
		won.append_array(SeasonPath.add("weekly"))
		await say(won)
		await _action_give_item([ch.reward_item(), "1"] as PackedStringArray, null)
	elif wins >= WeeklyChallenge.ROUNDS and not bool(rec.claimed):
		await say(["Cleared! The prize tries are used up this week, but the score counts."] as Array[String])
	elif wins >= WeeklyChallenge.ROUNDS:
		await say(["Cleared again! The prize comes back next week."] as Array[String])
	GameState.records["weekly"] = rec
	await announce_achievements()

## Master Wayfarer duel (plan 3288-3289): ring 45-55 team, Waymarks first time and weekly.
func _action_master(args: PackedStringArray, _speaker: NPC) -> void:
	var id: String = args[0] if not args.is_empty() else ""
	var m: Dictionary = Masters.find(id)
	if m.is_empty():
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var ask: String = Loc.t("Duel %s? Ring %d.") % [str(m.name), Masters.level(m)]
	if not Masters.pays_now(id):
		ask += " " + Loc.t("The Waymarks for this master come back next week.")
	var go: bool = await menu.confirm(ask)
	menu.queue_free()
	if not go:
		return
	var info: Dictionary = {"name": "%s, %s" % [str(m.name), Loc.t(str(m.title))], "ai": 3}
	busy = false
	var outcome: BattleModel.Outcome = await start_battle(Masters.team(id), false, info)
	busy = true
	player.frozen = true
	if outcome != BattleModel.Outcome.WIN:
		return
	var lines: Array[String] = []
	lines.append_array(Dialogue.get_entry("masters/" + id).get("win_lines", []))
	lines.append_array(Masters.win(id))
	await say(lines)
	await announce_achievements()

## Echo Path room marker (plan 3464): wild fight, Wanderer echo, treasure, rest or riddle.
func _action_echo_room(_args: PackedStringArray, _speaker: NPC) -> void:
	var slot: int = EchoPath.slot_of(map.id)
	if slot == 0:
		return
	if EchoPath.is_done(slot):
		await say(["This room is already clear this week."] as Array[String])
		return
	var lines: Array[String] = []
	match EchoPath.kind_of(slot):
		"wild", "echo":
			if GameState.first_healthy_index() < 0:
				return
			var wild: bool = EchoPath.kind_of(slot) == "wild"
			var foes: Array[Spirling] = []
			if wild:
				var s: Spirling = EchoPath.wild_for(slot)
				if s != null:
					foes.append(s)
			else:
				foes = EchoPath.echo_team(slot)
			if foes.is_empty():
				return
			SaveManager.save_game()
			busy = false
			var info: Dictionary = {} if wild else {"name": Loc.t("Wanderer echo"), "ai": 3}
			var outcome: BattleModel.Outcome = await start_battle(foes, wild, info)
			busy = true
			player.frozen = true
			if outcome != BattleModel.Outcome.WIN and outcome != BattleModel.Outcome.BONDED:
				return
			EchoPath.clear(slot)
		"treasure":
			lines.append_array(EchoPath.take_treasure(slot))
		"rest":
			# No rest point here: the rooms change every week.
			GameState.heal_party()
			Sound.sfx("heal")
			DailyTasks.record("rest", {"map": map.id})
			EchoPath.clear(slot)
			lines.append("Your team is fully rested.")
		"riddle":
			EchoPath.clear(slot)
			lines.append("The stone hums. The answer rings true.")
	lines.append(Loc.t("Rooms cleared this week: %d of %d.") % [EchoPath.done_count(), EchoPath.ROOMS])
	await say(lines)

## The chest at the end of the Echo Path (plan 3465), then the way back to the hall.
func _action_echo_chest(_args: PackedStringArray, _speaker: NPC) -> void:
	await say(EchoPath.open_chest())
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var back: bool = await menu.confirm(Loc.t("Return to the entrance hall?"))
	menu.queue_free()
	if back:
		Sound.sfx("warp")
		load_map(EchoPath.FILE, EchoPath.ARRIVE_DOWN, "down")

## The Echo Path guide: this week's wild kinds and progress.
func _action_echo_info(_args: PackedStringArray, _speaker: NPC) -> void:
	await say([EchoPath.spirlog_hint(), EchoPath.goal_line()] as Array[String])

## The wandering merchant (plan 3423): today's three goods for coins.
func _action_merchant(_args: PackedStringArray, speaker: NPC) -> void:
	var items: Array[String] = []
	items.assign(WorldEvents.merchant().get("items", []))
	await _action_shop(PackedStringArray(items), speaker)

## Aldo's roaming trips (plan 3446-3448): bring finished trips home, then send Spirlings from
## storage for 4, 8 or 12 hours with the reward shown before they go.
func _action_expedition(_args: PackedStringArray, _speaker: NPC) -> void:
	var back: Array[String] = Expeditions.collect()
	if not back.is_empty():
		await say(back)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var status: Array[String] = Expeditions.status_lines()
	if not status.is_empty():
		await menu.info("\n".join(status))
	while true:
		var title: String = Loc.t("Roaming trips %d/%d") % [Expeditions.trips().size(), Expeditions.max_trips()]
		var options: Array[String] = []
		if Expeditions.can_send():
			options.append("Send a Spirling")
		if not Expeditions.diary().is_empty():
			options.append("Trip diary")
		options.append("Done")
		var pick: int = await menu.pick_strings(title, options)
		if pick < 0 or options[pick] == "Done":
			break
		if options[pick] == "Trip diary":
			await menu.info("\n".join(Expeditions.diary()))
			continue
		var ready: Array[Spirling] = Expeditions.ready_to_go()
		var names: Array[String] = []
		for s: Spirling in ready:
			names.append("%s R%d" % [s.display_name(), s.level])
		var who: int = await menu.pick_strings("Who goes?", names)
		if who < 0:
			continue
		var plans: Array[String] = []
		for p: Variant in Expeditions.plans():
			plans.append(Expeditions.plan_text(p))
		var how: int = await menu.pick_strings("How long?", plans)
		if how < 0:
			continue
		var hours: int = int((Expeditions.plans()[how] as Dictionary).hours)
		# Plan 3449/3450: only maps this journey knows; a matching element brings more coins.
		var dests: Array[String] = Expeditions.destinations()
		var dest: String = ""
		if not dests.is_empty():
			var where: Array[String] = []
			for id: String in dests:
				where.append(Spirling.place_name(id) + ("  +%d%%" % Expeditions.match_bonus_pct() if Expeditions.element_match(ready[who], id) else ""))
			var w: int = await menu.pick_strings("Where to?", where)
			if w < 0:
				continue
			dest = dests[w]
		if Expeditions.send(ready[who], hours, dest):
			DailyTasks.record("trip", {"map": map.id})
			await menu.info(Loc.t("%s sets off. Back in %d hours.") % [ready[who].display_name(), hours])
	menu.queue_free()

## Seasonal festival (item 89): the crier names the festival and hands out its gift once a year.
func _action_season(_args: PackedStringArray, _speaker: NPC) -> void:
	var d: Dictionary = Online.date_now()
	var f: Dictionary = Season.for_month(int(d.month))
	if f.is_empty():
		await say([Season.next_line(int(d.month))] as Array[String])
		return
	await say([str(f.text)] as Array[String])
	var year: int = Season.festival_year(int(d.month), int(d.year))
	var flag: String = Season.gift_flag(f, year)
	if not GameState.has_flag(flag):
		GameState.set_flag(flag)
		await _action_give_item([Season.gift_for(f, year), "1"] as PackedStringArray, null)
	await _festival_task()

## The crier's festival task of the day (plan 3211): one a day, pays festival ribbons.
func _festival_task() -> void:
	var task: Dictionary = Festival.take_task()
	var t: Dictionary = Festival.task_def(str(task.get("id", "")))
	if t.is_empty():
		return
	if bool(task.get("done", false)):
		await say(["Crier: You've done today's festival task. Come back tomorrow for another!"] as Array[String])
		return
	await say([Loc.t("Crier: Today's festival task: %s (%d/%d). It pays %d ribbons.") % [Loc.t(str(t.text)), int(task.n), Festival.task_need(t), Festival.TASK_RIBBONS]] as Array[String])

## Tilda's festival stand (plan 3209): festival goods for ribbons, only while a festival runs.
func _action_festival_shop(_args: PackedStringArray, _speaker: NPC) -> void:
	var a: Dictionary = Festival.active()
	if a.is_empty():
		var nxt: Dictionary = Season.next_after(int(Online.date_now().month))
		await say([Loc.t("Tilda: My stand opens for the next festival, the %s.") % Loc.t(str(nxt.get("name", "")))] as Array[String])
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	while true:
		var goods: Array = Festival.shop()
		var labels: Array[String] = []
		for o: Variant in goods:
			labels.append("%s  %d" % [Loc.t(str(Database.item(str(o.item)).get("name", o.item))), int(o.price)])
		var idx: int = await menu.pick_strings(Loc.t("%s   Ribbons %d") % [Loc.t(str(a.fest.name)), Festival.ribbons()], labels)
		if idx < 0:
			break
		var o: Dictionary = goods[idx]
		var it: Dictionary = Database.item(str(o.item))
		if not await menu.confirm("%s\n%s\n\n%s" % [Loc.t(str(it.get("name", ""))), Loc.t(str(it.get("description", ""))), Loc.t("Trade for %d ribbons?") % int(o.price)]):
			continue
		var err: String = Festival.buy(str(o.item))
		Sound.sfx("cancel" if err != "" else "coin")
		await menu.info(err if err != "" else Loc.t("Traded for %s. You have %d.") % [Loc.t(str(it.get("name", ""))), GameState.item_count(str(o.item))])
	menu.queue_free()

## The Sparkseer reads each party member's hidden Spark values in words.
func _action_spark_read(_args: PackedStringArray, _speaker: NPC) -> void:
	var lines: Array[String] = []
	for s: Spirling in GameState.party:
		lines.append(GameState.spark_reading(s))
	await say(lines)

## Shop: "shop item_a item_b ..." sells those items for their JSON price. The bag has no limit.
## The Showcase (Era III, Showcase.gd): pick a Spirling, show three arts, get a place.
func _action_showcase(_args: PackedStringArray, _speaker: NPC) -> void:
	if not EraFeatures.is_unlocked(Showcase.FEATURE):
		await say(["The stage is still being built. Come back in a later era."] as Array[String])
		return
	var theme: String = Showcase.theme_for(DailyFind.today_key())
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var names: Array[String] = []
	for s: Spirling in GameState.party:
		names.append(MenuHost.party_line(s))
	var pick: int = await menu.pick_strings(Loc.t("Today's theme: %s. Who goes on stage?") % Loc.t(Showcase.theme_label(theme)), names)
	if pick < 0 or GameState.party[pick].moves.is_empty():
		menu.queue_free()
		return
	var star: Spirling = GameState.party[pick]
	var total: int = 0
	var last: MoveData = null
	for r: int in Showcase.rounds():
		var arts: Array[String] = []
		for mv: MoveData in star.moves:
			arts.append(mv.move_name)
		var a: int = await menu.pick_strings(Loc.t("Round %d of %d: which art?") % [r + 1, Showcase.rounds()], arts, false)
		var mv: MoveData = star.moves[maxi(a, 0)]
		var got: int = Showcase.appeal(star, theme, mv, last)
		total += got
		await menu.info(Loc.t("%s shows %s. Appeal %d.") % [star.display_name(), mv.move_name, got] + ("\n" + Loc.t("The judges have seen that one already.") if mv == last else ""))
		last = mv
	var rivals: Array[int] = Showcase.rivals(star, theme)
	var place: int = Showcase.place(total, rivals)
	var prize: int = Showcase.prize(place)
	var lines: PackedStringArray = [Loc.t("Your total: %d") % total]
	var rival_names: Array = Showcase.data().get("rival_names", [])
	for i: int in rivals.size():
		lines.append("%s: %d" % [str(rival_names[i]) if i < rival_names.size() else "?", rivals[i]])
	lines.append(Loc.t("Place %d.") % place)
	if prize > 0:
		Ticker.coins(GameState.money, GameState.money + prize)
		GameState.money += prize
		lines.append(Loc.plural(prize, "%d coin", "%d coins"))
	Showcase.note(GameState.records, place)
	await menu.info("\n".join(lines))
	menu.queue_free()

## The Dig site (Era IV, DigSite.gd): once a day, swing the pick at buried cells.
func _action_dig(_args: PackedStringArray, _speaker: NPC) -> void:
	if not EraFeatures.is_unlocked(DigSite.FEATURE):
		await say(["The ground here is still too hard. Come back in a later era."] as Array[String])
		return
	var day: String = DailyFind.today_key()
	if not DigSite.open_today(GameState.records, day):
		await say(["You already dug here today. The ground needs a night to settle."] as Array[String])
		return
	DigSite.mark_done(GameState.records, day)
	var dig: Dictionary = DigSite.start(day)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var found: PackedStringArray = []
	while int(dig.picks) > 0:
		var cells: Array[int] = DigSite.open_cells(dig)
		var names: Array[String] = [Loc.t("Look at the field")]
		for c: int in cells:
			names.append(DigSite.cell_name(c))
		var i: int = await menu.pick_strings(Loc.t("Picks left: %d") % int(dig.picks), names)
		if i < 0:
			break
		if i == 0:
			await menu.info(DigSite.grid_text(dig) + "\n" + Loc.t("# untouched, . empty, o rock, * find"))
			continue
		var r: Dictionary = DigSite.swing(dig, cells[i - 1])
		if bool(r.rock):
			Sound.sfx("bump")
			await menu.info(Loc.t("Clang! Solid rock. That cost two swings."))
		elif not str(r.item).is_empty():
			GameState.add_item(str(r.item))
			Sound.sfx("sparkle")
			var item_name: String = str(Database.item(str(r.item)).get("name", r.item))
			found.append(Loc.t(item_name))
			await menu.info(Loc.t("You dig up %s!") % Loc.t(item_name))
	await menu.info(Loc.t("The dig is over. Found: %s") % (", ".join(found) if not found.is_empty() else Loc.t("nothing")))
	menu.queue_free()

func _action_shop(args: PackedStringArray, _speaker: NPC) -> void:
	var menu := MenuHost.new()
	_ui.add_child(menu)
	while true:
		var rows: Array[Dictionary] = []
		for id: String in args:
			var it: Dictionary = Database.item(id)
			rows.append({"text": "%s  %d" % [it.get("name", id), ShopEffects.merchant_price(int(it.get("price", 0)))],
				"hint": "1x %s: %s" % [ShopCatalog.item_name(id), Loc.t(str(it.get("description", "")))]})
		var idx: int = await menu.pick("Shop   %s" % Loc.plural(GameState.money, "%d coin", "%d coins"), rows)
		if idx < 0:
			break
		var item: Dictionary = Database.item(args[idx])
		var price: int = ShopEffects.merchant_price(int(item.get("price", 0)))
		# What the item is and does before any coin moves (shop clarity, Ali 12 Nov 2026).
		if not await menu.confirm(ShopCatalog.merchant_card(args[idx], price) + "\n\n" + Loc.t("Buy for %d coins?") % price):
			continue
		if GameState.money < price:
			await menu.info("Not enough coins.")
			continue
		Ticker.coins(GameState.money, GameState.money - price)
		GameState.money -= price
		GameState.add_item(args[idx])
		Vows.broke("no_shop")
		Sound.sfx("coin")
		await menu.info("Bought %s. You have %d." % [item.get("name", ""), GameState.item_count(args[idx])])
	menu.queue_free()

## Marla's exchange stand (plan area 8): items for Waymarks only, with a card and a yes/no
## question before every trade.
func _action_exchange(_args: PackedStringArray, _speaker: NPC) -> void:
	if not Exchange.is_open():
		await say(["Marla: My stand opens once the valley is a little quieter. Mend a Rift, then come back."] as Array[String])
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	while true:
		var offers: Array[Dictionary] = Exchange.offers()
		var labels: Array[String] = []
		for o: Dictionary in offers:
			labels.append(Exchange.label(o))
		var list_row: int = -1
		if Exchange.full_unlocked():
			list_row = labels.size()
			labels.append(Loc.t("Weekly crates..."))
		var goal_row: int = labels.size()
		labels.append(Loc.t("Savings goal..."))
		var idx: int = await menu.pick_strings(Loc.t("Exchange   %s") % Waymarks.label(), labels)
		if idx < 0:
			break
		if idx == list_row:
			await menu.info(Exchange.weekly_list_text())
			continue
		if idx == goal_row:
			var names: Array[String] = []
			for o: Dictionary in offers:
				names.append(Exchange.label(o))
			var g: int = await menu.pick_strings(Loc.t("Save up for which offer?"), names)
			if g >= 0:
				Exchange.set_goal(str(offers[g].item))
				await menu.info(Exchange.goal_line())
			continue
		var o: Dictionary = offers[idx]
		if not await menu.confirm(Exchange.describe(o) + "\n\n" + Loc.t("Trade?")):
			continue
		var err: String = Exchange.buy(str(o.item))
		if err != "":
			Sound.sfx("cancel")
			await menu.info(err)
			continue
		Sound.sfx("coin")
		await menu.info(Loc.t("Traded for %s. You have %d.") % [Loc.t(str(Database.item(str(o.item)).get("name", ""))), GameState.item_count(str(o.item))])
	menu.queue_free()
	if not Exchange.full_unlocked():
		await say(["Marla: Once the valley is fully quiet I'll bring out the good crates."] as Array[String])

# --- Wayfarers --------------------------------------------------------------------------

func _is_active_trainer(n: NPC) -> bool:
	return TrainerData.is_trainer(n.definition) and not TrainerData.is_beaten(n.definition, map.id, GameState.flags)

## The first unbeaten Wayfarer whose line of sight reaches the player, or null.
func _spotting_trainer() -> NPC:
	if GameState.first_healthy_index() < 0:
		return null
	for n: NPC in _npcs:
		if not _is_active_trainer(n):
			continue
		var blocked: Callable = func(c: Vector2i) -> bool: return not map.is_walkable(c) or npc_at(c) != null
		if TrainerData.sees(n.cell, GridWalker.DIRS[n.facing], int(n.definition.get("sight", 0)), player.cell, blocked):
			return n
	return null

## A Wayfarer challenge: optional spot + walk-over, intro lines, battle, then the win aftermath.
func challenge(n: NPC, spotted: bool) -> void:
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var def: Dictionary = n.definition
	if spotted:
		n.alert = true
		await get_tree().create_timer(SPOT_TIME).timeout
		n.alert = false
		while (player.cell - n.cell).length_squared() > 1:
			n.step(n.facing)
			await n.step_finished
	n.face_toward(player.cell)
	player.face(_dir_name(n.cell - player.cell))
	if def.has("intro"):
		await say(Dialogue.lines_for(Dialogue.get_entry(str(def.intro)), GameState.flags))
	if def.has("warden"):
		# Warden fights are long; never lose progress to a crash or the OS closing the app.
		SaveManager.save_game()
	var team: Array[Spirling] = TrainerData.build_team(def, GameState.starter, GameState.rng, GameState.difficulty, GameState.level_cap())
	if team.is_empty():
		push_warning("Overworld: Wayfarer '%s' has no valid team" % n.npc_id)
		busy = false
		player.frozen = false
		return
	if def.has("warden") and not await warden_card(def, team, "Face the Warden now?"):
		busy = false
		player.frozen = false
		VirtualPad.set_wanted(true)
		return
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level(), GameState.difficulty)
	info["goal_key"] = BattleGoals.key(map.id, n.npc_id)
	# Helper call (item 46): after losing to a Warden once, a friend's echo can fight beside you.
	var losses: Dictionary = GameState.records.get("warden_losses", {})
	var lost_key: String = TrainerData.beaten_flag(def, map.id)
	var helper: Dictionary = {}
	if def.has("warden") and int(losses.get(lost_key, 0)) >= 1 and not info.has("partner"):
		helper = await pick_echo_partner("This Warden is tough. Call a friend's echo to fight beside you?")
		if not helper.is_empty():
			info["partner"] = helper.partner
	# Tailwind (items 737-739): offered openly after a few losses, only with the player's yes.
	var tailwind: bool = false
	if not bool(info.wild) and Tailwind.offered(GameState.difficulty, Tailwind.losses(GameState.records, lost_key)):
		var menu := MenuHost.new()
		_ui.add_child(menu)
		tailwind = await menu.confirm(Tailwind.question(GameState.difficulty), "Take Tailwind", "No, thanks")
		menu.queue_free()
		if tailwind:
			GameState.heal_party()
			info["foe_energy_cut"] = Tailwind.energy_cut(GameState.difficulty)
	# Warden Weakener (items 4885-4888): only after one try without help, never in Rift-Born.
	if def.has("warden") and ShopEffects.can_weaken_warden(int(losses.get(lost_key, 0)), GameState.difficulty):
		var ask := MenuHost.new()
		_ui.add_child(ask)
		var weaken: bool = await ask.confirm(Loc.t("Use a Warden Weakener? The Warden's team starts with 15%% less Vigor (%d left).") % GameState.item_count(ShopEffects.WARDEN_WEAKEN_ITEM), "Use", "Not now")
		ask.queue_free()
		if weaken and GameState.take_item(ShopEffects.WARDEN_WEAKEN_ITEM):
			info["warden_weakened"] = true
	_warden_battle = def.has("warden")
	var outcome: BattleModel.Outcome = await start_battle(team, bool(info.wild), info)
	_warden_battle = false
	if not bool(info.wild) and outcome != BattleModel.Outcome.FLED:
		Tailwind.note_outcome(GameState.records, lost_key, outcome == BattleModel.Outcome.WIN)
	if tailwind:
		var used: int = Tailwind.note_use(GameState.records)
		await say([Loc.t("Tailwind helped in this battle. Used %d times so far.") % used] as Array[String])
	if def.has("warden") and outcome == BattleModel.Outcome.LOSS:
		losses[lost_key] = int(losses.get(lost_key, 0)) + 1
		GameState.records["warden_losses"] = losses
	if not helper.is_empty():
		await thank_echo(helper, outcome == BattleModel.Outcome.WIN)
	await _pay_bonus_goal(str(info.goal_key))
	# A wild horde also counts as cleared when its last Spirling bonded with you.
	if outcome == BattleModel.Outcome.WIN or (bool(info.wild) and outcome == BattleModel.Outcome.BONDED):
		await after_tamer_win(n)

## The Wayfarer Pass paid its daily Riftglass (item 4631).
func _on_pass_paid(added: int) -> void:
	if is_instance_valid(toast):
		toast.show_note(Loc.t("Wayfarer Pass: +%d Riftglass") % added)

## Bonus goal of the battle just fought (items 755-757): pays out once when it was met.
func _pay_bonus_goal(goal_key: String) -> void:
	if last_model == null or not last_model.has_meta("goal_tracker"):
		return
	var tracker: BattleGoals.Tracker = last_model.get_meta("goal_tracker")
	BattleGoals.note(GameState.records, goal_key, tracker)
	if not tracker.met():
		return
	var lines: Array[String] = BattleGoals.grant(goal_key, tracker.goal, GameState.records)
	if not lines.is_empty():
		await say(lines)

## Win aftermath: beaten flag, defeat lines, Rift seal for Wardens, win flags, autosave.
func after_tamer_win(n: NPC) -> void:
	var goal_before: int = QuestLog.current_index(GameState.flags)
	var def: Dictionary = n.definition
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	GameState.set_flag(TrainerData.beaten_flag(def, map.id))
	_mark_rematch(def)
	# Weekly Rift board (online step 1): the won Warden battle goes to the referee; its rounds
	# count once the referee replayed it.
	if def.has("warden") and Online.flag_on("rift_board"):
		Online.call_fn("battle_submit", {"p_kind": "rift", "p_ref": str(def.warden),
			"p_replay": GameState.records.get("last_battle", {}), "p_claim": last_claim})
	if def.has("defeat"):
		await say(Dialogue.lines_for(Dialogue.get_entry(str(def.defeat)), GameState.flags))
	if def.has("warden") and GameState.seal_rift(str(def.warden)):
		var lines: Array[String] = ["The Warden's bond wakes again.", "Together you mend the Rift. The Hush lifts!"]
		if GameState.has_flag("storage_remote"):
			lines.append("Your resting Spirlings can now be called from the menu, wherever you are.")
		if GameState.has_ring_limit():
			lines.append("Your Spirlings can now grow to ring %d." % GameState.level_cap())
		await say(lines)
		# The Warden's thanks for the mend (the Rifts of 2026-11): an Echo Crystal with its art.
		for it: Variant in def.get("mend_items", []):
			await _action_give_item(PackedStringArray([str(it)]), null)
	# A Warden explains its team's cover in the lexicon after the first win (item 680).
	if def.has("lexicon") and Lexicon.add(GameState.records, str(def.lexicon)):
		await say([Loc.t("A new lexicon entry is written down."), "%s: %s" % [Loc.t(Lexicon.title(str(def.lexicon))), Loc.t(Lexicon.text(str(def.lexicon)))]] as Array[String])
	for f: Variant in def.get("win_flags", []):
		GameState.set_flag(str(f))
	if bool(def.get("leaves", false)):
		_npcs.erase(n)
		n.queue_free()
	await announce_goal_if_changed(goal_before)
	SaveManager.save_game()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false

## Iron Oath messages for [param retired], refilling or ending the oath if the party is empty.
static func oath_lines(retired: Array[String]) -> Array[String]:
	var lines: Array[String] = []
	for n: String in retired:
		lines.append("%s retires to the Sanctuary to rest." % n)
	if retired.is_empty() or not GameState.party.is_empty():
		return lines
	if GameState.fill_party_from_storage() > 0:
		lines.append("Spirlings from your storage step up to travel with you.")
	else:
		GameState.break_oath()
		lines.append("No Spirling is left to travel with you. The Iron Oath is broken.")
		lines.append("Your friends come back from the Sanctuary.")
	return lines

static func _today() -> String:
	return DailyFind.today_key()

func _mark_rematch(def: Dictionary) -> void:
	var rec: Dictionary = (GameState.records.get("rematch", {}) as Dictionary).duplicate()
	rec[TrainerData.beaten_flag(def, map.id)] = _today()
	GameState.records["rematch"] = rec

## A beaten Warden offers its Trials at the Rift (plan area 2, item 697): fixed puzzle battles
## with borrowed Spirlings. They give no rings, no growth and leave the team as it is; results
## go to GameState.records["puzzles"] (item 712). Returns false if there are none or the player leaves.
func offer_trials(n: NPC) -> bool:
	var def: Dictionary = n.definition
	if not def.has("warden") or not TrainerData.is_beaten(def, map.id, GameState.flags):
		return false
	var trials: Array[Dictionary] = BattlePuzzle.for_warden(str(def.warden))
	if trials.is_empty():
		return false
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var entries: Array[Dictionary] = []
	for p: Dictionary in trials:
		var got: int = BattlePuzzle.best_lanterns(GameState.records, str(p.id))
		var mark: String = (" " + Loc.t("Lanterns %d/%d") % [got, BattlePuzzle.MAX_LANTERNS]) if got > 0 else ""
		entries.append({"text": Loc.t(str(p.get("name", p.id))) + mark, "hint": Loc.t(str(p.get("text", "")))})
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var idx: int = await menu.pick(Loc.t("Trials"), entries, true)
	menu.queue_free()
	if idx < 0 or idx >= trials.size():
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return idx < 0
	await _play_trial(trials[idx], str(def.warden))
	return true

## Plays one Trial until it is solved or the player stops (items 707, 708, 710, 712). "Restart"
## in the battle and "Try again" after a miss start it at once with the same seed and no text
## before the fight; every miss counts towards the hints.
func _play_trial(p: Dictionary, warden: String) -> void:
	var quick: bool = false
	while true:
		var at: BattlePuzzle.Attempt = BattlePuzzle.start_attempt(p, quick)
		await start_battle(at.model.party(BattleModel.Side.FOE), false,
			{"model": at.model, "friendly": true, "warden": true, "name": str(p.get("name", ""))})
		var entry: Dictionary = BattlePuzzle.note_result(GameState.records, p, at)
		quick = true
		if at.model.has_meta("puzzle_restart"):
			continue
		var ok: bool = BattlePuzzle.solved(p, at)
		var lit: int = BattlePuzzle.lanterns(p, at)
		var lines: Array[String] = [Loc.t("Trial solved!") if ok else Loc.t("Not this time. The Trial waits for you.")]
		if lit > 0:
			lines.append(Loc.t("Lanterns %d/%d") % [lit, BattlePuzzle.MAX_LANTERNS])
		var tip: String = "" if ok else BattlePuzzle.hint(p, int(entry.get("fails", 0)))
		if not tip.is_empty():
			lines.append(Loc.t("Hint: %s") % tip)
		var reward: String = BattlePuzzle.reward_due(GameState.records, warden)
		if not reward.is_empty():
			BattlePuzzle.mark_reward(GameState.records, warden)
			GameState.add_item(reward)
			lines.append(Loc.t("Every Trial shines with 3 lanterns! You received %s.") % Loc.t(str(Database.item(reward).get("name", reward))))
		await say(lines)
		if ok:
			return
		var menu := MenuHost.new()
		_ui.add_child(menu)
		var again: bool = await menu.confirm(Loc.t("Try again?"), "Try again", "Leave")
		menu.queue_free()
		if not again:
			return

## The card before a Warden battle (item 687): rule, team size and elements, then [param question].
## "Not yet" leaves the player free to change their team first. Returns true to fight.
## Rift Anchor (item 4884): after a lost Warden battle the player may stay right before the
## Warden with a rested team instead of going back to the spring. The screen is black on entry
## and stays black when the answer is no.
func _use_rift_anchor() -> bool:
	await _fade_to(0.0)
	var ask := MenuHost.new()
	_ui.add_child(ask)
	var stay: bool = await ask.confirm(Loc.t("Use a Rift Anchor? You stay right before the Warden and your team is rested (%d left).") % GameState.item_count(ShopEffects.RIFT_ANCHOR_ITEM), "Stay", "Go back")
	ask.queue_free()
	if not stay or not GameState.take_item(ShopEffects.RIFT_ANCHOR_ITEM):
		await _fade_to(1.0)
		return false
	await say(["The Rift Anchor holds you in place. Your team is rested again."] as Array[String])
	return true

## Lost tries against the Warden of [param def] (records "warden_losses").
func _warden_losses(def: Dictionary) -> int:
	return int((GameState.records.get("warden_losses", {}) as Dictionary).get(TrainerData.beaten_flag(def, map.id), 0))

func warden_card(def: Dictionary, team: Array[Spirling], question: String) -> bool:
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var card: String = WardenCard.text(def, team, GameState.difficulty, GameState.level_cap())
	if ShopEffects.has_warden_lore(_warden_losses(def), GameState.difficulty):
		card += "\n" + WardenCard.lore(def, team)
	await menu.info(card, WardenCard.picture(team))
	var go: bool = await menu.confirm(question, "Fight", "Not yet")
	menu.queue_free()
	return go

## A Warden's rematch after the finale (data/warden_rematch.json): own team, lines and reward, once.
## Returns false if there is none or the player declines.
func offer_warden_rematch(n: NPC) -> bool:
	var base: Dictionary = n.definition
	if GameState.first_healthy_index() < 0 or not WardenRematch.can_challenge(base, map.id, GameState.flags):
		return false
	var entry: Dictionary = WardenRematch.entry_for(map.id, str(base.get("id", "")))
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	await say(WardenRematch.lines(entry, "intro"))
	var def: Dictionary = WardenRematch.rematch_def(base, entry)
	var team: Array[Spirling] = TrainerData.build_team(def, GameState.starter, GameState.rng, GameState.difficulty, GameState.level_cap())
	var who: String = str(base.get("trainer", base.get("id", "")))
	var go: bool = await warden_card(def, team, Loc.t("%s wants the rematch. Battle?") % who)
	if not go:
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return true
	SaveManager.save_game()
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level(), GameState.difficulty)
	var outcome: BattleModel.Outcome = await start_battle(team, false, info)
	busy = true
	player.frozen = true
	if outcome == BattleModel.Outcome.WIN:
		GameState.set_flag(WardenRematch.won_flag(entry))
		var reward: Dictionary = entry.get("reward", {})
		if reward.has("item"):
			GameState.add_item(str(reward.item), int(reward.get("count", 1)))
		await say(WardenRematch.lines(entry, "win"))
		await announce_achievements()
		SaveManager.save_game()
	else:
		await say(WardenRematch.lines(entry, "lose"))
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	return true

## A Warden's Second Trial (items 682-684): offered once both Rifts are mended, until it is won.
## Returns false if there is none or the player declines.
func offer_second_trial(n: NPC) -> bool:
	var base: Dictionary = n.definition
	if GameState.first_healthy_index() < 0 or not TrainerData.can_second_trial(base, map.id, GameState.flags):
		return false
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var who: String = str(base.get("trainer", base.get("id", "")))
	var def: Dictionary = TrainerData.second_trial_def(base, map.id)
	var team: Array[Spirling] = TrainerData.build_team(def, GameState.starter, GameState.rng, GameState.difficulty, GameState.level_cap())
	var go: bool = await warden_card(def, team, Loc.t("%s offers the Second Trial: two rules at once, a full team. Battle?") % who)
	if not go:
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return true
	SaveManager.save_game()
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level(), GameState.difficulty)
	var outcome: BattleModel.Outcome = await start_battle(team, false, info)
	busy = true
	player.frozen = true
	if outcome == BattleModel.Outcome.WIN:
		GameState.set_flag(TrainerData.beaten_flag(def, map.id))
		await say([Loc.t("%s: You passed the Second Trial. The Rift remembers you.") % who] as Array[String])
		await announce_achievements()
		SaveManager.save_game()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	return true

## Offers a beaten Wayfarer's daily rematch. Returns false if there is none or the player declines.
func offer_rematch(n: NPC) -> bool:
	var def: Dictionary = n.definition
	if GameState.first_healthy_index() < 0:
		return false
	# Today's rematch is used: a Rematch Key from the shop opens one more (item 4841).
	var keyed: bool = not TrainerData.can_rematch(def, map.id, GameState.flags, GameState.records, _today())
	if keyed and (GameState.item_count(TrainerData.REMATCH_KEY) <= 0
			or not TrainerData.can_rematch_with_key(def, map.id, GameState.flags, GameState.records, _today())):
		return false
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var who: String = str(def.get("trainer", def.get("id", "Wayfarer")))
	var ask: String = Loc.t("%s wants a rematch. Battle?") % who
	if keyed:
		ask = Loc.t("%s already battled you today. Use a Rematch Key (%d left)?") % [who, GameState.item_count(TrainerData.REMATCH_KEY)]
	var go: bool = await menu.confirm(ask)
	menu.queue_free()
	if not go:
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return false
	if keyed:
		GameState.take_item(TrainerData.REMATCH_KEY)
	var top: int = 1
	for s: Spirling in GameState.party:
		top = maxi(top, s.level)
	var team: Array[Spirling] = TrainerData.rematch_team(def, GameState.starter, GameState.rng, top, GameState.level_cap(), GameState.difficulty)
	if team.is_empty():
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return false
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level(), GameState.difficulty)
	info["money"] = TrainerData.REMATCH_MONEY_PER_LEVEL * team.reduce(func(m: int, s: Spirling) -> int: return maxi(m, s.level), 0)
	var outcome: BattleModel.Outcome = await start_battle(team, false, info)
	if outcome == BattleModel.Outcome.WIN:
		_mark_rematch(def)
		GameState.records["rematch_wins"] = int(GameState.records.get("rematch_wins", 0)) + 1
		busy = true
		player.frozen = true
		await say(["Good battle! Come back tomorrow for another."] as Array[String])
		await announce_achievements()
		SaveManager.save_game()
		player.frozen = false
		busy = false
	return true

static func _dir_name(d: Vector2i) -> String:
	for k: String in GridWalker.DIRS:
		if GridWalker.DIRS[k] == d:
			return k
	return "down"

# --- Playing with friends (items 46-48, 61, 121-124) ------------------------------------

## Asks whether to bring a friend's echo, lets the player pick one and builds the team.
## Returns {"code", "name", "partner": {...}} or {} (no friends with teams, offline, or no).
func pick_echo_partner(question: String) -> Dictionary:
	if not Online.is_online() or not Online.social_on():
		return {}
	var r: Dictionary = await Online.call_fn("friends_list")
	if not r.ok or not r.data is Dictionary:
		return {}
	var with_team: Array = (r.data.get("friends", []) as Array).filter(func(f: Dictionary) -> bool: return bool(f.get("has_team", false)))
	if with_team.is_empty():
		return {}
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var out: Dictionary = {}
	if await menu.confirm(question):
		var names: Array[String] = []
		for f: Dictionary in with_team:
			names.append(FriendsMenu.friend_line(f))
		var idx: int = await menu.pick_strings("Whose echo?", names)
		if idx >= 0:
			var t: Dictionary = await Online.call_fn("friend_team", {"p_code": with_team[idx].code})
			if t.ok and t.data is Dictionary and bool(t.data.get("ok", false)):
				var team: Array[Spirling] = EchoTeam.build(t.data.team, GameState.level_cap())
				if not team.is_empty():
					var label: String = "%s's echo" % str(t.data.name)
					out = {"code": str(with_team[idx].code), "name": str(t.data.name),
						"partner": {"name": label, "echo": team, "front": 1, "ai": EchoTeam.PARTNER_AI}}
	menu.queue_free()
	return out

## Tells the friend their echo helped, and adds friendship points (once a day).
func thank_echo(helper: Dictionary, won: bool) -> void:
	var r: Dictionary = await Online.call_fn("echo_report", {"p_code": helper.code, "p_kind": "echo", "p_won": won})
	var pts: int = int(r.data.get("points", 0)) if r.ok and r.data is Dictionary else 0
	if pts > 0:
		await say(["%s's echo fades with a smile. Your friendship grew!" % str(helper.name)] as Array[String])

## What the last battle's result was (winner, Vigor left, rounds), for the server's referee.
var last_claim: Dictionary = {}
## True while a Rift Warden battle from [method challenge] runs (Rift Anchor, item 4884).
var _warden_battle: bool = false

## Echo duel (items 121-124): a friend's team, run by the AI, everyone on the same level.
## Nothing is lost and the real team does not change.
func echo_duel(d: Dictionary) -> void:
	var ring: int = EchoTeam.duel_ring({"duel_ring": d.get("ring", EchoTeam.DUEL_LEVEL)})
	var foes: Array[Spirling] = EchoTeam.build(d.get("team", []), Spirling.STORY_RING, ring)
	var mine: Array[Spirling] = EchoTeam.duel_copy(GameState.party, ring)
	if foes.is_empty() or mine.is_empty():
		await say(["The echo flickers and fades. Try again later."] as Array[String])
		return
	await say(["%s's echo steps out of the light. Everyone fights at Ring %d." % [str(d.name), ring]] as Array[String])
	busy = false
	var outcome: BattleModel.Outcome = await start_battle(foes, false,
		{"name": "%s's echo" % str(d.name), "ai": EchoTeam.DUEL_AI, "player_team": mine, "friendly": true})
	busy = true
	player.frozen = true
	var won: bool = outcome == BattleModel.Outcome.WIN
	Online.call_fn("echo_report", {"p_code": d.code, "p_kind": "duel", "p_won": won})
	# The server's referee plays the duel again (plan area 7, item 2689).
	Online.call_fn("battle_submit", {"p_kind": "echo_duel", "p_ref": str(d.code),
		"p_replay": GameState.records.get("last_battle", {}), "p_claim": last_claim})
	await say(["You won the echo duel against %s!" % str(d.name) if won else "%s's echo won this time. Your team is fine." % str(d.name)] as Array[String])
	busy = false
	player.frozen = false

## League battle (plan area 7, items 2730-2772): the server picked the seed and both teams, the
## rival's echo is run by the AI. The result only counts once the server's referee says ok (2691).
func league_battle(m: Dictionary) -> void:
	var snap: Dictionary = BattleReferee.from_expect(m)
	# Seals work in the Open League, never in the Fair League; the server's expect does the same.
	snap["seals"] = ShopEffects.seals_for("league_" + str(m.get("league", LeagueRules.FAIR)))
	snap["amulets"] = ShopEffects.amulets_for("league_" + str(m.get("league", LeagueRules.FAIR)))
	var model: BattleModel = BattleReplay.build_model(snap)
	if model == null:
		await say(["The league battle could not start. Try again later."] as Array[String])
		return
	model.trainer_name = "League rival"
	var foes: Array[Spirling] = []
	foes.assign(model.parties[1])
	await say(["A rival's echo steps into the league ring."] as Array[String])
	busy = false
	var outcome: BattleModel.Outcome = await start_battle(foes, false, {"name": "League rival", "model": model, "friendly": true})
	busy = true
	player.frozen = true
	var kind: String = "league_" + str(m.get("league", LeagueRules.FAIR))
	var r: Dictionary = await Online.call_fn("battle_submit", {"p_kind": kind, "p_ref": str(m.get("match_id", "")),
		"p_replay": GameState.records.get("last_battle", {}), "p_claim": last_claim})
	var lines: Array[String] = ["You won the league battle!" if outcome == BattleModel.Outcome.WIN else "The rival won this league battle."]
	if bool(m.get("pair_limit", false)):
		lines.append("You met this rival 3 times today, so this battle does not count.")
	elif not bool(m.get("rated", true)):
		lines.append("The season ends soon, so this battle does not count.")
	elif r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		lines.append("Your result is being checked. It counts once the check is done.")
	else:
		lines.append("The result could not be sent, so it does not count.")
	await say(lines)
	# Online 100 point 83: report the rival right after the battle.
	if int(m.get("match_id", 0)) > 0:
		var menu := MenuHost.new()
		_ui.add_child(menu)
		await SafetyMenu.after_battle(menu, "league", int(m.match_id))
		menu.queue_free()
	busy = false
	player.frozen = false

## Raid Rift attempt (plan area 7, items 2847-2851, 2871): the server set seed, teams and the
## round limit; the battle is friendly, so it costs nothing and the team is healed afterwards.
## The damage comes off the guardian once the referee checked the battle (2691).
func raid_battle(at: Dictionary) -> void:
	var kind: String = str(at.get("kind", "raid"))
	var war: bool = kind != "raid"
	var snap: Dictionary = BattleReferee.from_expect(at)
	var model: BattleModel = BattleReplay.build_model(snap)
	if model == null:
		await say(["The Raid Rift could not open. Try again later."] as Array[String])
		return
	var foe_name: String = str(at.get("guardian", "?"))
	model.trainer_name = foe_name if war else "Rift guardian"
	var foes: Array[Spirling] = []
	foes.assign(model.parties[1])
	if kind == "tourney":
		await say([Loc.t("Tournament: the team of %s waits. Win with as much damage and as few rounds as you can.") % foe_name] as Array[String])
	elif war:
		await say([Loc.t("Bund against bund: %s's team waits. This battle counts for your bund.") % foe_name] as Array[String])
	else:
		await say([Loc.t("%s waits in the Raid Rift. You have %d rounds.") % [foe_name, model.round_limit]] as Array[String])
	busy = false
	await start_battle(foes, false, {"name": model.trainer_name, "model": model, "friendly": true})
	busy = true
	player.frozen = true
	var dealt: int = 0
	for s: Spirling in model.parties[1]:
		dealt += maxi(0, s.max_hp() - s.hp)
	var r: Dictionary = await Online.call_fn("battle_submit", {"p_kind": kind,
		"p_ref": str(at.get("attempt_id", "")), "p_replay": GameState.records.get("last_battle", {}), "p_claim": last_claim})
	var lines: Array[String] = [Loc.t("You dealt %d damage to the guardian.") % dealt]
	if war:
		lines = ["The tournament battle is over." if kind == "tourney" else "The war battle is over."]
	if r.ok and r.data is Dictionary and bool(r.data.get("ok", false)):
		lines.append("It counts once the check is done.")
	else:
		lines.append("The result could not be sent, so it does not count.")
	await say(lines)
	busy = false
	player.frozen = false

# --- Battles --------------------------------------------------------------------------

## Cuts to the battle screen and waits for it to end. [param trainer] holds Wayfarer info (M5).
func start_battle(foes: Array[Spirling], wild: bool, trainer: Dictionary = {}) -> BattleModel.Outcome:
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	for f: Spirling in foes:
		DailyTasks.note_seen(f.data.species_name, map.id)
		GameState.mark_seen(f.data.species_name)
		GameState.note_spirlog(f, false)
	# Battle Skip (items 4839/4840): asked before the battle, fought by the AI in the background.
	if wild and trainer.is_empty() and ShopEffects.can_skip(foes):
		var ask := MenuHost.new()
		_ui.add_child(ask)
		var skip: bool = await ask.confirm(Loc.t("Use a Battle Skip on %s? Your team wins it at once (%d left).") % [foes[0].display_name(), GameState.item_count(ShopEffects.SKIP_ITEM)], "Skip", "Fight")
		ask.queue_free()
		if skip:
			return await _skipped_battle(foes)
	Sound.sfx("encounter")
	await _fade_to(1.0)
	# A league battle comes ready-made from the server's seed and teams (plan area 7).
	var preset: Variant = trainer.get("model")
	var model: BattleModel = preset if preset is BattleModel else _new_model(foes, wild, trainer)
	var scene: BattleScene = BATTLE_SCENE.instantiate()
	scene.setup(model)
	# A worn shop backdrop (item 4281) replaces the place's own, never a fixed one.
	var worn: String = GameState.battle_backdrop()
	scene.backdrop = str(trainer.get("backdrop", worn if not worn.is_empty() else map.backdrop))
	scene.backdrop_shade = float(trainer.get("shade", 0.0))
	scene.music_track = "warden" if bool(trainer.get("warden", false)) else "battle"
	var replay: Dictionary = BattleReplay.snapshot(model, scene.music_track, scene.backdrop)
	_battle_layer.add_child(scene)
	_fade.color.a = 0.0
	var result: Array = await scene.battle_finished
	var outcome: BattleModel.Outcome = result[0]
	replay["inputs"] = scene.inputs
	GameState.records["last_battle"] = replay
	GameState.note_battle_end()
	Inkshadow.note_battle(GameState.party)
	last_claim = BattleReferee.claim_of(model)
	await _fade_to(1.0)
	scene.queue_free()
	if bool(trainer.get("friendly", false)):
		player.greet()
		await _fade_to(0.0)
	else:
		await _after_battle(model, outcome)
	Sound.enter_map(map.id)
	EncounterTable.start_guard()
	if _fade.color.a > 0.0:
		player.greet()
	await _fade_to(0.0)
	await _wake_cores()
	await announce_achievements()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	battle_ended.emit(outcome)
	return outcome

## A wild battle settled by a Battle Skip: the same model and aftermath, no battle screen.
func _skipped_battle(foes: Array[Spirling]) -> BattleModel.Outcome:
	var model: BattleModel = _new_model(foes, true, {})
	model.items_allowed = false
	var replay: Dictionary = BattleReplay.snapshot(model, "battle", map.backdrop)
	replay["inputs"] = ShopEffects.skip_battle(model)
	var outcome: BattleModel.Outcome = model.outcome
	GameState.records["last_battle"] = replay
	GameState.note_battle_end()
	last_claim = BattleReferee.claim_of(model)
	if outcome == BattleModel.Outcome.WIN:
		toast.show_note(Loc.t("Battle skipped: %s is beaten.") % foes[0].display_name())
	await _after_battle(model, outcome)
	Sound.enter_map(map.id)
	EncounterTable.start_guard()
	if _fade.color.a > 0.0:
		player.greet()
	await _fade_to(0.0)
	await _wake_cores()
	await announce_achievements()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	battle_ended.emit(outcome)
	return outcome

## The battle for [method start_battle] from the overworld's state and [param trainer].
func _new_model(foes: Array[Spirling], wild: bool, trainer: Dictionary) -> BattleModel:
	var ai_level: int = 0 if wild else int(trainer.get("ai", GameState.ai_level()))
	# Echo duels fight with level-matched copies, so the real team never changes (item 123).
	var own: Variant = trainer.get("player_team")
	var mine: Array[Spirling] = GameState.party
	if own is Array and not (own as Array).is_empty():
		mine = []
		mine.assign(own)
	var model := BattleModel.new(mine, foes, wild, GameState.rng.randi(), ai_level)
	last_model = model
	model.inventory = GameState.inventory
	model.items_allowed = GameState.items_allowed_in_battle()
	model.level_cap = GameState.level_cap()
	model.bench_share = GameState.bench_share()
	model.trainer_name = str(trainer.get("name", ""))
	var tune: Variant = trainer.get("profile_tune", {})
	model.ai.set_profile(str(trainer.get("profile", "")), tune if tune is Dictionary else {})
	if not wild:
		model.ai.set_difficulty(GameState.difficulty)
	model.foe_damage_mult = GameState.foe_damage_mult()
	model.boss_hp_scale = GameState.BOSS_HP_SCALE[GameState.difficulty]
	model.boss_difficulty = GameState.difficulty
	model.field = str(trainer.get("field", map.field))
	model.foe_rule = str(trainer.get("rule", ""))
	# Rule variants of a tower floor or the weekly challenge (item 799).
	var vids: Variant = trainer.get("variants", [])
	if vids is Array:
		model.variants.assign(vids)
	model.rule_turn_full = GameState.difficulty >= GameState.Difficulty.VETERAN
	model.prize_money = int(int(trainer.get("money", 0)) * ShopEffects.coin_mult())
	model.xp_mult = ShopEffects.growth_mult()
	model.ring_scaled_growth = EraFeatures.is_unlocked("ring_scaled_growth")
	model.wheel = bool(trainer.get("wheel", false)) and EraFeatures.is_unlocked("wheel_battles")
	model.wheel_size = EraActivities.wheel_size()
	# Weather in battle (Era III on): the sky of an outdoor map lays its field when nothing else does.
	if model.field.is_empty() and not (own is Array and not (own as Array).is_empty()) and EraFeatures.is_unlocked("sky_battles"):
		var sky: Dictionary = WeatherCycle.battle_field(WeatherCycle.current(map))
		if not sky.is_empty():
			model.field = str(sky.field)
			model.field_intro = str(sky.intro)
	# A windy sky lays no field and changes no rule; the battle only shows the wind.
	if WeatherCycle.current(map) == "wind":
		model.set_meta(BattleWeather.SKY_META, "wind")
	# Echo duels fight a friend's echo, not the world: the pass adds no energy or Rift Breath there.
	var world: bool = not (own is Array and not (own as Array).is_empty())
	model.energy_bonus = [ShopEffects.energy_bonus(world), 0]
	model.seals = [ShopEffects.seals_for("story" if world else "echo"), [0, 0, 0]]
	model.amulets = [ShopEffects.amulets_for("story" if world else "echo"), [0, 0, 0]]
	# Story foes start with less Energy, Rift-Born foes gain more in turn 1 (item 749); echo duels stay even.
	var d: int = GameState.difficulty if world else -1
	model.start_energy_cut = [0, int(trainer.get("foe_energy_cut", 0)) + BattleRules.foe_start_cut(d)]
	model.foe_turn1_energy = BattleRules.foe_turn1_energy(d)
	model.warden_weakened = bool(trainer.get("warden_weakened", false))
	model.gift_items = ShopEffects.battle_gifts(bool(trainer.get("warden", false)), world)
	model.bond_grace = maxi(ShopEffects.bond_grace(), 1 if GameState.is_newcomer() else 0) if wild else 0
	model.bond_edge = ShopEffects.bond_edge() if wild else 0.0
	var items: Variant = trainer.get("items", {})
	model.foe_items = (items as Dictionary).duplicate() if items is Dictionary else {}
	var front: Array = trainer.get("front", [1, 1])
	model.front_size = [int(front[0]), int(front[1])]
	model.foe_boss = str(trainer.get("boss", ""))
	var goal_key: String = str(trainer.get("goal_key", ""))
	var goal: Dictionary = BattleGoals.all().get(goal_key, {}) if not goal_key.is_empty() and GameState.bonus_goals else {}
	if not goal.is_empty():
		# The start card shows the goal; the tracker only watches, it never changes the battle.
		model.set_meta("goal_tracker", BattleGoals.Tracker.new(model, goal))
		var done: bool = bool((GameState.records.get("goals_done", {}) as Dictionary).get(goal_key, false))
		model.set_meta("bonus_goal", BattleGoals.describe(goal) + (" ✓" if done else ""))
	var partner: Variant = trainer.get("partner", {})
	if partner is Dictionary and not (partner as Dictionary).is_empty():
		var ally: Array[Spirling] = []
		# A friend's echo comes as ready Spirlings; story partners as a team definition.
		if partner.get("echo") is Array:
			ally.assign(partner.echo)
		else:
			ally = TrainerData.build_team(partner, GameState.starter, GameState.rng)
		model.set_partner(str(partner.get("name", "")), ally, int(partner.get("front", 1)),
			int(partner.get("ai", TrainerData.PARTNER_AI)), str(partner.get("profile", "")))
	return model

func _after_battle(model: BattleModel, outcome: BattleModel.Outcome) -> void:
	Kinship.after_battle(GameState.party, model.participants, outcome == BattleModel.Outcome.WIN)
	var had_growth: bool = ShopEffects.boost_left("growth") > 0
	ShopEffects.battle_done()
	# What is left of the shop boosts, right after the battle (item 4342).
	var boosts: Array[String] = ShopEffects.boost_lines()
	if not boosts.is_empty():
		toast.show_note("  ".join(boosts))
	elif had_growth:
		toast.show_note(Loc.t("The growth boost is used up."))
	var coins_before: int = GameState.money
	GameState.money += int(model.prize_money) if outcome == BattleModel.Outcome.WIN and not model.is_wild else 0
	if GameState.money != coins_before:
		Ticker.coins(coins_before, GameState.money)
	# The world goal of the week (item 85): wins and bonds count when that is this week's kind.
	if outcome == BattleModel.Outcome.WIN:
		Online.contribute("battles")
		GameState.note_core_win()
		var foe_elements: Array[String] = []
		for f: Spirling in model.parties[1]:
			for e: int in f.elements():
				foe_elements.append(Elements.E.keys()[e])
		DailyTasks.record("win", {"map": map.id, "wild": model.is_wild, "elements": foe_elements, "night": DayCycle.current() == DayCycle.Phase.NIGHT, "one_element": Achievements.one_element_team(GameState.party)})
		var fields: Array = GameState.records.get("fields_won", [])
		if model.field != "" and not model.field in fields:
			fields.append(model.field)
			GameState.records["fields_won"] = fields
	if model.bonded != null and outcome != BattleModel.Outcome.LOSS:
		Online.contribute("bonds")
	# In a horde the bond can land before the rest of the swarm is beaten (outcome WIN or FLED).
	if model.bonded != null and outcome != BattleModel.Outcome.LOSS:
		GameState.receive_spirling(model.bonded)
		# Wild Spirlings keep their temperament to themselves until they bond (item 315).
		var tm: Dictionary = model.bonded.temperament()
		await say(["%s seems %s." % [model.bonded.display_name(), Loc.t(str(tm.label)).to_lower()]] as Array[String])
		var bond_elements: Array[String] = []
		for e: int in model.bonded.elements():
			bond_elements.append(Elements.E.keys()[e])
		DailyTasks.record("bond", {"map": map.id, "elements": bond_elements})
		SaveManager.save_game()
	var oath: Array[String] = oath_lines(GameState.retire_fainted())
	if outcome == BattleModel.Outcome.LOSS:
		# No coin penalty: a spring keeper simply brings the player back.
		GameState.heal_party()
		if _warden_battle and ShopEffects.can_anchor(GameState.difficulty) and await _use_rift_anchor():
			if not oath.is_empty():
				await say(oath)
			return
		load_map(GameState.heal_map, GameState.heal_cell, "down")
		await _fade_to(0.0)
		await say(["Everything goes quiet... A spring keeper finds you and helps you back.", "Your team is rested again."] as Array[String])
		if not oath.is_empty():
			await say(oath)
		return
	if not oath.is_empty():
		await _fade_to(0.0)
		await say(oath)
	# Unfurling is never automatic: the first time a Spirling could unfurl, say so once.
	for s: Spirling in GameState.party:
		var hint: String = "unfurl_hint_%s_%s" % [s.uid, s.data.species_name]
		if s.can_unfurl(map.id) and not s.is_fainted() and not GameState.has_flag(hint):
			GameState.set_flag(hint)
			await _fade_to(0.0)
			await say(["%s feels ready to unfurl. You can choose it in the Team menu, now or later." % s.display_name()] as Array[String])
