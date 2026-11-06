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
## Shade over dark gear cells (thick without the gear, a faint dusk with it).
var _shade: Node2D
var _entities: Node2D
var _camera: Camera2D
var _photo: PhotoMode
## The last battle's model (the weekly challenge reads its turn count).
var last_model: BattleModel
var _daylight: CanvasModulate
var _npcs: Array[NPC] = []
var _ui: CanvasLayer
var _text: TextBox
var _picker: ListPicker
var _banner: Label
## Top-of-screen notes (badges, daily tasks).
var toast: Toast
var _fade: ColorRect
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
		"give_item": _action_give_item,
		"set_flag": _action_set_flag,
		"shop": _action_shop,
		"exchange": _action_exchange,
		"festival_shop": _action_festival_shop,
		"spark_read": _action_spark_read,
		"quest_show": _action_quest_show,
		"switch": _action_switch,
		"gauntlet": _action_gauntlet,
		"weekly": _action_weekly,
		"master": _action_master,
		"season": _action_season,
		"choose_starter": _action_choose_starter,
		"page": _action_page,
		"set_var": _action_set_var,
		"add_var": _action_add_var,
		"battle": _action_battle,
		"scene": _action_scene,
		"warp": _action_warp,
		"echo_song": _action_echo_song,
		"quest_stage": _action_quest_stage,
		"lever": _action_lever,
	}
	_world = WorldMechanics.new(self)
	_build()
	if GameState.party.is_empty() and not GameState.in_game:
		# Running this scene directly from the editor: start a quick test game.
		GameState.new_game(GameState.Difficulty.TAMER, "Juno", 0, "Kindlop")
	GameState.in_game = true
	player.body_color = GameState.TAMER_COLORS[GameState.tamer_color]
	player.sprite_style = GameState.tamer_sprite()
	load_map(GameState.current_map, GameState.player_cell, GameState.facing)
	VirtualPad.set_wanted(true)
	if not GameState.has_flag("got_starter"):
		busy = true
		player.frozen = true
		_fade.color.a = 1.0
		prologue.call_deferred()

func _build() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	add_child(_ground)
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
	player.interact.connect(_on_interact)
	_entities.add_child(player)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()

	_ui = CanvasLayer.new()
	_ui.layer = UI_LAYER
	add_child(_ui)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UITheme.get_theme()
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
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 4
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_stylebox_override("normal", UITheme.panel_style())
	_banner.visible = false
	ui_root.add_child(_banner)
	toast = Toast.new()
	add_child(toast)
	_text = TextBox.new()
	_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text.offset_top = -TEXT_BOX_HEIGHT
	# Long lines (and German text) grow the box upward instead of off the bottom of the screen.
	_text.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_text.visible = false
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

func _process(_delta: float) -> void:
	# Integer-rounded camera (no smoothing) keeps pixels on the grid.
	_camera.global_position = (player.global_position + Vector2(GridWalker.TILE / 2.0, GridWalker.TILE / 2.0)).round()
	if _photo != null:
		_camera.global_position += _photo.pan

# --- Maps --------------------------------------------------------------------------

func _tip_after_load(id: String) -> void:
	# Wait for the warp fade to finish so the tip doesn't cut into it.
	while busy:
		await get_tree().process_frame
	await show_tip(id)

func _era_line_after_load(line: String) -> void:
	while busy:
		await get_tree().process_frame
	await get_tree().create_timer(EraManager.TRANSITION_TIME).timeout
	await _locked_say([line] as Array[String])

## Shows a first-time tip (if any) while the player waits.
func show_tip(id: String) -> void:
	var lines: Array[String] = Tips.take(id)
	if not lines.is_empty():
		await _locked_say(lines)

func load_map(map_id: String, cell: Vector2i, face: String) -> void:
	map = MapData.load_map(map_id)
	if map == null:
		return
	_entry_cell = cell
	_world.prepare(map, cell)
	map.paint(_ground)
	refresh_shade()
	for n: NPC in _npcs:
		n.queue_free()
	_npcs.clear()
	for def: Dictionary in map.npcs:
		if def.has("hide_flag") and GameState.has_flag(str(def.hide_flag)):
			continue
		if def.has("show_flag") and not GameState.has_flag(str(def.show_flag)):
			continue
		var n := NPC.new()
		n.setup(def)
		_entities.add_child(n)
		_npcs.append(n)
	player.place(cell, face)
	GameState.current_map = map_id
	DailyTasks.note_map(map_id)
	DailyTasks.record("visit", {"map": map_id})
	GameState.player_cell = cell
	GameState.facing = face
	var era_before: int = EraManager.unlocked_era
	EraManager.unlock_region(map.region)
	if EraManager.unlocked_era > era_before and EraManager.ERA_LINES.has(EraManager.unlocked_era):
		_era_line_after_load.call_deferred(EraManager.ERA_LINES[EraManager.unlocked_era])
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map.width * GridWalker.TILE
	_camera.limit_bottom = map.height * GridWalker.TILE
	_show_banner(map.display_name)
	var arrive: String = StoryPlacements.enter_scene(map_id, GameState.flags)
	if not arrive.is_empty():
		_arrival_scene.call_deferred(arrive)
	refresh_daylight()
	Sound.music(Sound.track_for_map(map_id))
	if not map.encounter_table.is_empty():
		_tip_after_load.call_deferred("wild_area")

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
	_daylight.color = DayCycle.tint(map.outdoor, DayCycle.current(), GameState.day_night)

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
	var tw: Tween = create_tween()
	if rope != null:
		for i: int in GRAPPLE_PULLS:
			var a: Vector2 = from_pos.lerp(to_pos, float(i) / GRAPPLE_PULLS).round()
			var b: Vector2 = from_pos.lerp(to_pos, float(i + 1) / GRAPPLE_PULLS).round()
			tw.tween_property(player, "position", b, GEAR_MOVE_TIME / GRAPPLE_PULLS).from(a).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(func(k: float) -> void:
			var arc: float = -10.0 * sin(k * PI)
			player.position = from_pos.lerp(to_pos, k).round() + Vector2(0, round(arc)), 0.0, 1.0, GEAR_MOVE_TIME)
	await tw.finished
	if rope != null:
		rope.queue_free()
	player.place(dest, player.facing)
	GameState.player_cell = dest
	player.frozen = false
	busy = false
	return true

func _show_banner(text: String) -> void:
	_banner.text = " %s " % text
	_banner.visible = true
	await get_tree().create_timer(BANNER_TIME).timeout
	_banner.visible = false

func _fade_to(alpha: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tw.finished

# --- Player events -------------------------------------------------------------------

func _on_player_stepped(cell: Vector2i) -> void:
	_hinted_cell = Vector2i(-1, -1)
	GameState.player_cell = cell
	GameState.facing = player.facing
	if scene_running:
		return
	DailyTasks.record("step", {"map": map.id})
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
	if map.kind_at(cell) in TilesetFactory.ENCOUNTER_KINDS and not map.encounter_table.is_empty():
		if GameState.first_healthy_index() >= 0 and GameState.rng.randf() < EncounterTable.rate(map.encounter_table):
			var wild: Spirling = DailyFind.maybe_spawn(map.encounter_table, GameState.flags, GameState.rng)
			if wild != null:
				await _locked_say(["The grass rustles strangely... A rare visitor!"] as Array[String])
			else:
				var boost: Array[int] = DayCycle.encounter_boost(Season.boosted(Season.current()), map.outdoor, DayCycle.current(), GameState.day_night)
				wild = EncounterTable.roll(map.encounter_table, GameState.rng, boost)
			if wild != null:
				await start_battle([wild] as Array[Spirling], true)

func _warp(warp: Dictionary) -> void:
	busy = true
	player.frozen = true
	Sound.sfx("warp")
	await _fade_to(1.0)
	load_map(str(warp.to), Vector2i(int(warp.tx), int(warp.ty)), str(warp.get("facing", player.facing)))
	SaveManager.save_game()
	await _fade_to(0.0)
	player.frozen = false
	busy = false

func _on_interact(cell: Vector2i) -> void:
	if busy:
		return
	if await _try_gear(cell):
		return
	if await _world.interact(cell):
		return
	var n: NPC = npc_at(cell)
	if n != null:
		n.face_toward(player.cell)
		if _is_active_trainer(n):
			await challenge(n, false)
		elif not await offer_rematch(n):
			await run_dialogue(n.dialogue_ref, n)
		return
	var s: Dictionary = map.sign_at(cell, GameState.flags)
	if not s.is_empty():
		await run_dialogue(str(s.dialogue))
		return
	# Talk across counters.
	if map.kind_at(cell) == TilesetFactory.Kind.COUNTER:
		var beyond: NPC = npc_at(cell + (cell - player.cell))
		if beyond != null:
			beyond.face_toward(player.cell)
			await run_dialogue(beyond.dialogue_ref, beyond)

## Shows a dialogue entry, then runs its action and flag. Freezes the player meanwhile.
## Follows "if"/"else", "choices" and "next" inside the same file (plan items 1335-1338).
func run_dialogue(ref: String, speaker: NPC = null) -> void:
	var goal_before: int = QuestLog.current_index(GameState.flags)
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	if speaker != null:
		DailyTasks.record("talk", {"map": map.id, "key": ref})
	await play_entry(ref, speaker)
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
	_text.visible = false
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
	for t: String in Achievements.check():
		# Unlocked badges show at the top of the screen without stopping the game (plan 3315).
		var a: Dictionary = Achievements.by_title(t)
		toast.show_note(Loc.t("Badge: %s") % Loc.t(t) + "  " + Waymarks.gain_text(int(a.get("reward", 0))), Badges.texture(a, true))
		Sound.sfx("level_up")
	if lines.is_empty():
		return
	Sound.sfx("level_up")
	await say(lines)
	_text.visible = false

## Shows queued reward notes (daily tasks, Waymarks) as toasts that do not stop the game.
func show_notices() -> void:
	for line: String in take_notices():
		toast.show_note(line)

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

## Shakes the camera for [param seconds] (thunder, the Rift opening).
func shake_camera(seconds: float) -> void:
	if GameState.reduce_motion:
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

func _action_heal(_args: PackedStringArray, _speaker: NPC) -> void:
	GameState.heal_party()
	Sound.sfx("heal")
	if map.heal_point.x >= 0:
		GameState.heal_map = map.id
		GameState.heal_cell = map.heal_point
		GameState.visit_rest(map.id, map.heal_point)
	Online.contribute("rests")
	DailyTasks.record("rest", {"map": map.id})
	await say(["Your team is fully rested."] as Array[String])

func _action_storage(_args: PackedStringArray, _speaker: NPC) -> void:
	var menu := PauseMenu.new()
	_ui.add_child(menu)
	await menu.run_storage()
	menu.queue_free()

## Opens the pause menu (Team, Spirlog, Satchel, Save, Settings).
func open_menu() -> void:
	if busy:
		return
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var menu := PauseMenu.new()
	menu.encounter_table = map.encounter_table
	menu.current_map = map.id
	menu.room_puzzle = _world.has_puzzle()
	menu.can_undo = _world.can_undo()
	_ui.add_child(menu)
	await menu.run()
	match menu.room_action:
		"undo": _world.undo()
		"reset": _world.reset_room(_entry_cell)
	var target: String = menu.travel_to
	var photo: bool = menu.photo
	var watch: bool = menu.watch_replay
	var duel: Dictionary = menu.echo_duel
	menu.queue_free()
	if not duel.is_empty():
		await echo_duel(duel)
	if photo:
		await photo_mode()
	if watch:
		await watch_replay(GameState.records.get("last_battle", {}))
	if not target.is_empty() and GameState.visited_rests.has(target):
		var c: Array = GameState.visited_rests[target]
		Sound.sfx("warp")
		await _fade_to(1.0)
		load_map(target, Vector2i(int(c[0]), int(c[1])), "down")
		Sound.music(Sound.track_for_map(target))
		await _fade_to(0.0)
	player.body_color = GameState.TAMER_COLORS[GameState.tamer_color]
	refresh_daylight()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false

## Plays a recorded battle (item 14). The replay uses copies, so nothing in the save changes.
func watch_replay(snap: Dictionary) -> void:
	var model: BattleModel = BattleReplay.build_model(snap)
	if model == null:
		await say(["That replay can't be shown any more."] as Array[String])
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
	Sound.music(Sound.track_for_map(map.id))
	await _fade_to(0.0)

## Photo mode (item 94): pan, frame and save pictures until the player backs out.
func photo_mode() -> void:
	_photo = PhotoMode.new()
	_photo.place = map.display_name if not map.display_name.is_empty() else map.id.capitalize()
	add_child(_photo)
	VirtualPad.set_wanted(true)
	await _photo.finished
	if _photo.taken > 0:
		DailyTasks.record("photo", {"map": map.id})
	_photo.queue_free()
	_photo = null

## Android back: opens the pause menu in the world, works like B everywhere else (item 1787).
func _notification(what: int) -> void:
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

## Walks toward [param cell]; NPCs, signs and counters get walked up to and talked to.
func tap_cell(cell: Vector2i) -> void:
	if not map.in_bounds(cell) or cell == player.cell:
		return
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
	var talk: bool = npc_at(cell) != null or not map.sign_at(cell, GameState.flags).is_empty() or map.kind_at(cell) == TilesetFactory.Kind.COUNTER
	if talk:
		player.follow(PathFinder.find_adjacent(player.cell, cell, passable), cell)
	else:
		player.follow(PathFinder.find(player.cell, cell, passable))

func _action_give_item(args: PackedStringArray, _speaker: NPC) -> void:
	if args.is_empty():
		return
	var count: int = int(args[1]) if args.size() > 1 else 1
	GameState.add_item(args[0], count)
	var item_name: String = str(Database.item(args[0]).get("name", args[0]))
	await say(["You got %s x%d!" % [item_name, count]] as Array[String])
	if bool(Database.item(args[0]).get("gear", false)):
		var tip: Array[String] = Tips.take("gear")
		if not tip.is_empty():
			await say(tip)

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
	Sound.music(Sound.track_for_map(map.id))
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	await tw.finished
	busy = false
	# The prologue dialogue picks the partner ("choose_starter"); Aldo then hands over the map book.
	while not GameState.has_flag("got_starter"):
		await run_dialogue("lighthouse/morning")
	await run_dialogue("lighthouse/aldo")
	SaveManager.save_game()

## "choose_starter": the three Spirlings that sheltered from the storm; one stays.
func _action_choose_starter(_args: PackedStringArray, _speaker: NPC) -> void:
	if GameState.has_flag("got_starter"):
		return
	var menu := MenuHost.new()
	_ui.add_child(menu)
	while true:
		var entries: Array[String] = []
		for sp: String in Database.STARTERS:
			entries.append("%s (%s)" % [sp, Elements.element_name(Database.species(sp).elements[0])])
		var pick: int = await menu.pick_strings("Which one do you kneel down to?", entries, false)
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
func _action_lever(args: PackedStringArray, _speaker: NPC) -> void:
	if args.size() < 2:
		return
	if GameState.has_flag(args[0]):
		await say(["It has already been moved."] as Array[String])
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

## Cracked floor gave way: the player lands on the same cell of the floor below.
func drop_to(map_id: String, cell: Vector2i) -> void:
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

## Post-game gauntlet: five echo Wayfarers in a row, scaled to your strongest Spirling, no rest.
func _action_gauntlet(_args: PackedStringArray, _speaker: NPC) -> void:
	if not GameState.has_flag("tower_intro"):
		GameState.set_flag("tower_intro")
		await say(["The stair has %d floors. There is no healing on the way, only at a rest point after every tenth floor, where your climb is saved." % Gauntlet.FLOORS] as Array[String])
	var menu := MenuHost.new()
	_ui.add_child(menu)
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
		var info: Dictionary = {"name": "Echo Wayfarer %d" % (floors + 1), "ai": Gauntlet.ai_for(floors), "money": run.prize(floors)}
		if not helper.is_empty():
			for s: Spirling in helper.partner.echo:
				s.restore()
			info["partner"] = helper.partner
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(run.team(floors), false, info)
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
	if not helper.is_empty():
		await thank_echo(helper, floors >= Gauntlet.FLOORS)
	if floors >= Gauntlet.FLOORS:
		Gauntlet.clear_checkpoint()
		GameState.set_flag("gauntlet_clear")
		await _action_give_item([run.reward_item(), "1"] as PackedStringArray, null)
		await say(["The echoes bow and fade. You reached the lamp room!"] as Array[String])
	elif floors > best:
		await say(["New best: floor %d of %d!" % [floors, Gauntlet.FLOORS]] as Array[String])

## Weekly challenge (item 88, plan area 8): five echo Wayfarers that are the same for everyone this week.
func _action_weekly(_args: PackedStringArray, _speaker: NPC) -> void:
	var week: String = WeeklyChallenge.this_week()
	var ch := WeeklyChallenge.new(week, GameState.progress_cap())
	var rec: Dictionary = GameState.records.get("weekly", {})
	if str(rec.get("week", "")) != week:
		rec = {"week": week, "best": 0, "claimed": false}
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var go: bool = await menu.confirm("This week: %s, rule %s. Five echoes at ring %d. Best this week: %d of %d. Try?" % [
		BattleRules.FIELDS[ch.field].label, BattleRules.RULES[ch.rule].label, ch.level, int(rec.best), WeeklyChallenge.ROUNDS])
	menu.queue_free()
	if not go:
		return
	GameState.heal_party()
	await say(["Your team is fully rested."] as Array[String])
	var wins: int = 0
	while wins < WeeklyChallenge.ROUNDS:
		var info: Dictionary = {"name": "Weekly Echo %d" % (wins + 1), "ai": 3, "rule": ch.rule, "field": ch.field}
		busy = false
		var outcome: BattleModel.Outcome = await start_battle(ch.team(wins), false, info)
		busy = true
		player.frozen = true
		var turns: int = last_model.turn if last_model != null else 0
		if outcome != BattleModel.Outcome.WIN:
			break
		wins += 1
		var lines: Array[String] = [WeeklyChallenge.round_text(wins, turns, GameState.party)]
		var coins: int = WeeklyChallenge.claim_interim(rec, wins)
		if coins > 0:
			lines.append("Interim prize: %d coins." % coins)
		await say(lines)
	rec.best = maxi(int(rec.best), wins)
	# Weekly board (item 125): rounds won and health left; the server keeps the best.
	Online.call_fn("weekly_submit", {"p_week": week, "p_score": EchoTeam.weekly_score(wins, GameState.party)})
	if wins >= WeeklyChallenge.ROUNDS and GameState.party.all(func(s: Spirling) -> bool: return not s.is_fainted()):
		GameState.records["weekly_flawless"] = 1
	if wins >= WeeklyChallenge.ROUNDS and not bool(rec.claimed):
		rec.claimed = true
		GameState.records["weekly_wins"] = int(GameState.records.get("weekly_wins", 0)) + 1
		GameState.money += WeeklyChallenge.PRIZE
		var won: Array[String] = ["You won this week's challenge! You received %d coins." % WeeklyChallenge.PRIZE]
		won.append_array(Waymarks.reward_lines(Waymarks.earn(WeeklyChallenge.WAYMARKS, "weekly")))
		won.append_array(SeasonPath.add("weekly"))
		await say(won)
		await _action_give_item([ch.reward_item(), "1"] as PackedStringArray, null)
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

## Seasonal festival (item 89): the crier names the festival and hands out its gift once a year.
func _action_season(_args: PackedStringArray, _speaker: NPC) -> void:
	var d: Dictionary = Online.date_now()
	var f: Dictionary = Season.for_month(int(d.month))
	if f.is_empty():
		var nxt: Dictionary = Season.next_after(int(d.month))
		await say(["No festival right now. Next up: the %s." % str(nxt.get("name", ""))] as Array[String])
		return
	await say([str(f.text)] as Array[String])
	var flag: String = Season.gift_flag(f, Season.festival_year(int(d.month), int(d.year)))
	if not GameState.has_flag(flag):
		GameState.set_flag(flag)
		await _action_give_item([str(f.gift), "1"] as PackedStringArray, null)
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
	await say([Loc.t("Crier: Today's festival task: %s (%d/%d). It pays %d ribbons.") % [Loc.t(str(t.text)), int(task.n), int(t.n), Festival.TASK_RIBBONS]] as Array[String])

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
func _action_shop(args: PackedStringArray, _speaker: NPC) -> void:
	var menu := MenuHost.new()
	_ui.add_child(menu)
	while true:
		var labels: Array[String] = []
		for id: String in args:
			var it: Dictionary = Database.item(id)
			labels.append("%s  %d" % [it.get("name", id), int(it.get("price", 0))])
		var idx: int = await menu.pick_strings("Shop   %d coins" % GameState.money, labels)
		if idx < 0:
			break
		var item: Dictionary = Database.item(args[idx])
		var price: int = int(item.get("price", 0))
		if GameState.money < price:
			await menu.info("Not enough coins.")
			continue
		GameState.money -= price
		GameState.add_item(args[idx])
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
		var idx: int = await menu.pick_strings(Loc.t("Exchange   %s") % Waymarks.label(), labels)
		if idx < 0:
			break
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
	var team: Array[Spirling] = TrainerData.build_team(def, GameState.starter, GameState.rng)
	if team.is_empty():
		push_warning("Overworld: Wayfarer '%s' has no valid team" % n.npc_id)
		busy = false
		player.frozen = false
		return
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level())
	# Helper call (item 46): after losing to a Warden once, a friend's echo can fight beside you.
	var losses: Dictionary = GameState.records.get("warden_losses", {})
	var lost_key: String = TrainerData.beaten_flag(def, map.id)
	var helper: Dictionary = {}
	if def.has("warden") and int(losses.get(lost_key, 0)) >= 1 and not info.has("partner"):
		helper = await pick_echo_partner("This Warden is tough. Call a friend's echo to fight beside you?")
		if not helper.is_empty():
			info["partner"] = helper.partner
	var outcome: BattleModel.Outcome = await start_battle(team, bool(info.wild), info)
	if def.has("warden") and outcome == BattleModel.Outcome.LOSS:
		losses[lost_key] = int(losses.get(lost_key, 0)) + 1
		GameState.records["warden_losses"] = losses
	if not helper.is_empty():
		await thank_echo(helper, outcome == BattleModel.Outcome.WIN)
	# A wild horde also counts as cleared when its last Spirling bonded with you.
	if outcome == BattleModel.Outcome.WIN or (bool(info.wild) and outcome == BattleModel.Outcome.BONDED):
		await after_tamer_win(n)

## Win aftermath: beaten flag, defeat lines, Rift seal for Wardens, win flags, autosave.
func after_tamer_win(n: NPC) -> void:
	var goal_before: int = QuestLog.current_index(GameState.flags)
	var def: Dictionary = n.definition
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	GameState.set_flag(TrainerData.beaten_flag(def, map.id))
	_mark_rematch(def)
	if def.has("defeat"):
		await say(Dialogue.lines_for(Dialogue.get_entry(str(def.defeat)), GameState.flags))
	if def.has("warden") and GameState.seal_rift(str(def.warden)):
		var lines: Array[String] = ["The Warden's bond wakes again.", "Together you mend the Rift. The Hush lifts!"]
		if GameState.has_flag("storage_remote"):
			lines.append("Your resting Spirlings can now be called from the menu, wherever you are.")
		if GameState.level_cap() < Spirling.MAX_LEVEL:
			lines.append("Your Spirlings can now grow to ring %d." % GameState.level_cap())
		await say(lines)
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
	return Time.get_date_string_from_system()

func _mark_rematch(def: Dictionary) -> void:
	var rec: Dictionary = (GameState.records.get("rematch", {}) as Dictionary).duplicate()
	rec[TrainerData.beaten_flag(def, map.id)] = _today()
	GameState.records["rematch"] = rec

## Offers a beaten Wayfarer's daily rematch. Returns false if there is none or the player declines.
func offer_rematch(n: NPC) -> bool:
	var def: Dictionary = n.definition
	if GameState.first_healthy_index() < 0 or not TrainerData.can_rematch(def, map.id, GameState.flags, GameState.records, _today()):
		return false
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var menu := MenuHost.new()
	_ui.add_child(menu)
	var who: String = str(def.get("trainer", def.get("id", "Wayfarer")))
	var go: bool = await menu.confirm("%s wants a rematch. Battle?" % who)
	menu.queue_free()
	if not go:
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return false
	var top: int = 1
	for s: Spirling in GameState.party:
		top = maxi(top, s.level)
	var team: Array[Spirling] = TrainerData.rematch_team(def, GameState.starter, GameState.rng, top, GameState.level_cap())
	if team.is_empty():
		VirtualPad.set_wanted(true)
		player.frozen = false
		busy = false
		return false
	var info: Dictionary = TrainerData.battle_info(def, team, GameState.ai_level())
	info["money"] = TrainerData.MONEY_PER_LEVEL * team.reduce(func(m: int, s: Spirling) -> int: return maxi(m, s.level), 0)
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

## Echo duel (items 121-124): a friend's team, run by the AI, everyone on the same level.
## Nothing is lost and the real team does not change.
func echo_duel(d: Dictionary) -> void:
	var ring: int = EchoTeam.duel_ring({"duel_ring": d.get("ring", EchoTeam.DUEL_LEVEL)})
	var foes: Array[Spirling] = EchoTeam.build(d.get("team", []), Spirling.MAX_LEVEL, ring)
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

# --- Battles --------------------------------------------------------------------------

## Cuts to the battle screen and waits for it to end. [param trainer] holds Wayfarer info (M5).
func start_battle(foes: Array[Spirling], wild: bool, trainer: Dictionary = {}) -> BattleModel.Outcome:
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	for f: Spirling in foes:
		GameState.mark_seen(f.data.species_name)
		GameState.note_spirlog(f, false)
	Sound.sfx("encounter")
	await _fade_to(1.0)
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
	model.field = str(trainer.get("field", map.field))
	model.foe_rule = str(trainer.get("rule", ""))
	model.prize_money = int(trainer.get("money", 0))
	var items: Variant = trainer.get("items", {})
	model.foe_items = (items as Dictionary).duplicate() if items is Dictionary else {}
	var front: Array = trainer.get("front", [1, 1])
	model.front_size = [int(front[0]), int(front[1])]
	model.foe_boss = str(trainer.get("boss", ""))
	var partner: Variant = trainer.get("partner", {})
	if partner is Dictionary and not (partner as Dictionary).is_empty():
		var ally: Array[Spirling] = []
		# A friend's echo comes as ready Spirlings; story partners as a team definition.
		if partner.get("echo") is Array:
			ally.assign(partner.echo)
		else:
			ally = TrainerData.build_team(partner, GameState.starter, GameState.rng)
		model.set_partner(str(partner.get("name", "")), ally, int(partner.get("front", 1)),
			int(partner.get("ai", TrainerData.PARTNER_AI)))
	var scene: BattleScene = BATTLE_SCENE.instantiate()
	scene.setup(model)
	scene.backdrop = map.backdrop
	scene.music_track = "warden" if bool(trainer.get("warden", false)) else "battle"
	var replay: Dictionary = BattleReplay.snapshot(model, scene.music_track, scene.backdrop)
	_battle_layer.add_child(scene)
	_fade.color.a = 0.0
	var result: Array = await scene.battle_finished
	var outcome: BattleModel.Outcome = result[0]
	replay["inputs"] = scene.inputs
	GameState.records["last_battle"] = replay
	last_claim = BattleReferee.claim_of(model)
	await _fade_to(1.0)
	scene.queue_free()
	if bool(trainer.get("friendly", false)):
		await _fade_to(0.0)
	else:
		await _after_battle(model, outcome)
	Sound.music(Sound.track_for_map(map.id))
	await _fade_to(0.0)
	await announce_achievements()
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	battle_ended.emit(outcome)
	return outcome

func _after_battle(model: BattleModel, outcome: BattleModel.Outcome) -> void:
	GameState.money += int(model.prize_money) if outcome == BattleModel.Outcome.WIN and not model.is_wild else 0
	# The world goal of the week (item 85): wins and bonds count when that is this week's kind.
	if outcome == BattleModel.Outcome.WIN:
		Online.contribute("battles")
		var foe_elements: Array[String] = []
		for f: Spirling in model.parties[1]:
			for e: int in f.elements():
				foe_elements.append(Elements.E.keys()[e])
		DailyTasks.record("win", {"map": map.id, "wild": model.is_wild, "elements": foe_elements})
	if model.bonded != null and outcome != BattleModel.Outcome.LOSS:
		Online.contribute("bonds")
	# In a horde the bond can land before the rest of the swarm is beaten (outcome WIN or FLED).
	if model.bonded != null and outcome != BattleModel.Outcome.LOSS:
		GameState.receive_spirling(model.bonded)
		var bond_elements: Array[String] = []
		for e: int in model.bonded.elements():
			bond_elements.append(Elements.E.keys()[e])
		DailyTasks.record("bond", {"map": map.id, "elements": bond_elements})
		SaveManager.save_game()
	var oath: Array[String] = oath_lines(GameState.retire_fainted())
	if outcome == BattleModel.Outcome.LOSS:
		# No coin penalty: a spring keeper simply brings the player back.
		GameState.heal_party()
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
