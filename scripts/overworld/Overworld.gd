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
const FADE_TIME: float = 0.18
## Pause between a Tamer spotting the player and walking over.
const SPOT_TIME: float = 0.5
## Seconds for a grapple or glide hop.
const GEAR_MOVE_TIME: float = 0.4

var map: MapData
var player: Player
var busy: bool = false

var _ground: TileMapLayer
var _entities: Node2D
var _camera: Camera2D
var _npcs: Array[NPC] = []
var _ui: CanvasLayer
var _text: TextBox
var _picker: ListPicker
var _banner: Label
var _fade: ColorRect
var _battle_layer: CanvasLayer
var _actions: Dictionary[String, Callable] = {}

func _ready() -> void:
	Database.load_all()
	_actions = {
		"storage": _action_storage,
		"heal": _action_heal,
		"give_item": _action_give_item,
		"set_flag": _action_set_flag,
		"shop": _action_shop,
	}
	_build()
	if GameState.party.is_empty():
		# Running this scene directly from the editor: start a quick test game.
		GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	GameState.in_game = true
	player.body_color = GameState.TAMER_COLORS[GameState.tamer_color]
	load_map(GameState.current_map, GameState.player_cell, GameState.facing)
	VirtualPad.set_wanted(true)

func _build() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	add_child(_ground)
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)
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
	_fade = ColorRect.new()
	_fade.color = Color(UITheme.INK, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_fade)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 4
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_stylebox_override("normal", UITheme.panel_style())
	_banner.visible = false
	ui_root.add_child(_banner)
	_text = TextBox.new()
	_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text.offset_top = -TEXT_BOX_HEIGHT
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

# --- Maps --------------------------------------------------------------------------

func load_map(map_id: String, cell: Vector2i, face: String) -> void:
	map = MapData.load_map(map_id)
	if map == null:
		return
	map.paint(_ground)
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
	GameState.player_cell = cell
	GameState.facing = face
	EraManager.unlock_region(map.region)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map.width * GridWalker.TILE
	_camera.limit_bottom = map.height * GridWalker.TILE
	_show_banner(map.display_name)
	Sound.music(Sound.track_for_map(map_id))

func npc_at(cell: Vector2i) -> NPC:
	for n: NPC in _npcs:
		if n.cell == cell:
			return n
	return null

func _can_enter(cell: Vector2i) -> bool:
	if busy or not map.is_walkable(cell) or npc_at(cell) != null:
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

## Grapple across water or glide down a ledge. Returns true if a gear spot handled the interaction.
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
	Sound.sfx("warp" if gear == "glide_cloak" else "confirm")
	var from_pos: Vector2 = player.position
	var to_pos: Vector2 = GridWalker.cell_to_pos(dest)
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		var arc: float = -10.0 * sin(k * PI)
		player.position = from_pos.lerp(to_pos, k).round() + Vector2(0, round(arc)), 0.0, 1.0, GEAR_MOVE_TIME)
	await tw.finished
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
			var wild: Spirling = EncounterTable.roll(map.encounter_table, GameState.rng)
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
	var n: NPC = npc_at(cell)
	if n != null:
		n.face_toward(player.cell)
		if _is_active_trainer(n):
			await challenge(n, false)
		else:
			await run_dialogue(n.dialogue_ref, n)
		return
	var s: Dictionary = map.sign_at(cell)
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
func run_dialogue(ref: String, speaker: NPC = null) -> void:
	var goal_before: int = QuestLog.current_index(GameState.flags)
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var entry: Dictionary = Dialogue.get_entry(ref)
	_text.visible = true
	for line: String in Dialogue.lines_for(entry, GameState.flags):
		await _text.show_text(line)
	_text.visible = false
	var already: bool = entry.has("flag") and GameState.has_flag(str(entry.flag))
	if entry.has("action") and not (already and bool(entry.get("once", false))):
		await _run_action(str(entry.action), speaker)
	if entry.has("flag"):
		GameState.set_flag(str(entry.flag))
	await announce_goal_if_changed(goal_before)
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false

## Shows "New goal: ..." when the story goal moved on since [param before].
func announce_goal_if_changed(before: int) -> void:
	if QuestLog.current_index(GameState.flags) == before:
		return
	await say(["New goal: " + QuestLog.goal_text(QuestLog.current(GameState.flags), GameState.flags)] as Array[String])

func say(lines: Array[String]) -> void:
	_text.visible = true
	for line: String in lines:
		await _text.show_text(line)
	_text.visible = false

func _run_action(action: String, speaker: NPC) -> void:
	var parts: PackedStringArray = action.split(" ", false)
	if parts.is_empty() or not _actions.has(parts[0]):
		push_warning("Overworld: unknown dialogue action '%s'" % action)
		return
	await _actions[parts[0]].call(parts.slice(1), speaker)

func _action_heal(_args: PackedStringArray, _speaker: NPC) -> void:
	GameState.heal_party()
	Sound.sfx("heal")
	if map.heal_point.x >= 0:
		GameState.heal_map = map.id
		GameState.heal_cell = map.heal_point
	await say(["Your team is fully rested."] as Array[String])

func _action_storage(_args: PackedStringArray, _speaker: NPC) -> void:
	var menu := PauseMenu.new()
	_ui.add_child(menu)
	await menu.run_storage()
	menu.queue_free()

## Opens the pause menu (Team, Spirlog, Bag, Save, Settings).
func open_menu() -> void:
	if busy:
		return
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	var menu := PauseMenu.new()
	menu.encounter_table = map.encounter_table
	_ui.add_child(menu)
	await menu.run()
	menu.queue_free()
	player.body_color = GameState.TAMER_COLORS[GameState.tamer_color]
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GameState.MENU_ACTION) and not busy and not player.moving:
		get_viewport().set_input_as_handled()
		open_menu()
		return
	# Tap-to-move (touch arrives here as an emulated left click).
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and GameState.tap_to_move:
		if busy or player.frozen or VirtualPad.covers(mb.position):
			return
		get_viewport().set_input_as_handled()
		var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * mb.position
		tap_cell(Vector2i(floori(world.x / GridWalker.TILE), floori(world.y / GridWalker.TILE)))

## Walks toward [param cell]; NPCs, signs and counters get walked up to and talked to.
func tap_cell(cell: Vector2i) -> void:
	if not map.in_bounds(cell) or cell == player.cell:
		return
	var passable: Callable = func(c: Vector2i) -> bool: return map.is_walkable(c) and npc_at(c) == null
	# Tapping across water or a ledge: walk to the gear spot and use it.
	for g: Dictionary in map.gear_spots:
		if g.has("to") and int(g.x) == cell.x and int(g.y) == cell.y:
			var f := Vector2i(int(g.from[0]), int(g.from[1]))
			var route: Array[Vector2i] = PathFinder.find(player.cell, f, passable)
			if f == player.cell or not route.is_empty():
				player.follow(route, cell)
				return
	var talk: bool = npc_at(cell) != null or not map.sign_at(cell).is_empty() or map.kind_at(cell) == TilesetFactory.Kind.COUNTER
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

func _action_set_flag(args: PackedStringArray, _speaker: NPC) -> void:
	for f: String in args:
		GameState.set_flag(f)

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

# --- Tamers --------------------------------------------------------------------------

func _is_active_trainer(n: NPC) -> bool:
	return TrainerData.is_trainer(n.definition) and not TrainerData.is_beaten(n.definition, map.id, GameState.flags)

## The first unbeaten Tamer whose line of sight reaches the player, or null.
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

## A Tamer challenge: optional spot + walk-over, intro lines, battle, then the win aftermath.
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
		push_warning("Overworld: Tamer '%s' has no valid team" % n.npc_id)
		busy = false
		player.frozen = false
		return
	var outcome: BattleModel.Outcome = await start_battle(team, false, TrainerData.battle_info(def, team, GameState.ai_level()))
	if outcome == BattleModel.Outcome.WIN:
		await after_tamer_win(n)

## Win aftermath: beaten flag, defeat lines, Rift seal for Wardens, win flags, autosave.
func after_tamer_win(n: NPC) -> void:
	var goal_before: int = QuestLog.current_index(GameState.flags)
	var def: Dictionary = n.definition
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	GameState.set_flag(TrainerData.beaten_flag(def, map.id))
	if def.has("defeat"):
		await say(Dialogue.lines_for(Dialogue.get_entry(str(def.defeat)), GameState.flags))
	if def.has("warden") and GameState.seal_rift(str(def.warden)):
		var lines: Array[String] = ["The Warden's bond wakes again.", "Together you mend the Rift. The Hush lifts!"]
		if GameState.has_flag("pc_unlocked"):
			lines.append("Your storage box now opens from the menu, wherever you are.")
		if GameState.level_cap() < Spirling.MAX_LEVEL:
			lines.append("Your Spirlings can now grow to Lv%d." % GameState.level_cap())
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

static func _dir_name(d: Vector2i) -> String:
	for k: String in GridWalker.DIRS:
		if GridWalker.DIRS[k] == d:
			return k
	return "down"

# --- Battles --------------------------------------------------------------------------

## Cuts to the battle screen and waits for it to end. [param trainer] holds Tamer info (M5).
func start_battle(foes: Array[Spirling], wild: bool, trainer: Dictionary = {}) -> BattleModel.Outcome:
	busy = true
	player.frozen = true
	VirtualPad.set_wanted(false)
	for f: Spirling in foes:
		GameState.mark_seen(f.data.species_name)
	Sound.sfx("encounter")
	await _fade_to(1.0)
	var ai_level: int = 0 if wild else int(trainer.get("ai", GameState.ai_level()))
	var model := BattleModel.new(GameState.party, foes, wild, GameState.rng.randi(), ai_level)
	model.inventory = GameState.inventory
	model.items_allowed = GameState.items_allowed_in_battle()
	model.level_cap = GameState.level_cap()
	model.trainer_name = str(trainer.get("name", ""))
	model.prize_money = int(trainer.get("money", 0))
	var items: Variant = trainer.get("items", {})
	model.foe_items = (items as Dictionary).duplicate() if items is Dictionary else {}
	var scene: BattleScene = BATTLE_SCENE.instantiate()
	scene.setup(model)
	scene.backdrop = map.backdrop
	scene.music_track = "warden" if bool(trainer.get("warden", false)) else "battle"
	_battle_layer.add_child(scene)
	_fade.color.a = 0.0
	var result: Array = await scene.battle_finished
	var outcome: BattleModel.Outcome = result[0]
	await _fade_to(1.0)
	scene.queue_free()
	await _after_battle(model, outcome)
	Sound.music(Sound.track_for_map(map.id))
	await _fade_to(0.0)
	VirtualPad.set_wanted(true)
	player.frozen = false
	busy = false
	battle_ended.emit(outcome)
	return outcome

func _after_battle(model: BattleModel, outcome: BattleModel.Outcome) -> void:
	GameState.money += int(model.prize_money) if outcome == BattleModel.Outcome.WIN and not model.is_wild else 0
	if outcome == BattleModel.Outcome.BONDED and model.bonded != null:
		GameState.receive_spirling(model.bonded)
		SaveManager.save_game()
	if outcome == BattleModel.Outcome.LOSS:
		GameState.heal_party()
		GameState.money = GameState.money / 2
		load_map(GameState.heal_map, GameState.heal_cell, "down")
		await _fade_to(0.0)
		await say(["You hurried back to rest...", "Your team is rested again."] as Array[String])
		return
	for s: Spirling in GameState.party:
		if s.can_evolve() and not s.is_fainted():
			var old_name: String = s.display_name()
			await _fade_to(0.0)
			s.evolve()
			await say(["%s glows with Rift light..." % old_name, "%s grew into %s!" % [old_name, s.data.species_name]] as Array[String])
			GameState.mark_seen(s.data.species_name, true)
