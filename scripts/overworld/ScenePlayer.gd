class_name ScenePlayer
extends Node
## Cut-scenes from data/scenes/<id>.json (plan items 1370-1377). A scene is
## {"steps": [...], "skippable": true}. Steps run in order and block the controls:
##   {"say": [lines], "speaker": "Aldo"}        lines in the text box (same {name} rule)
##   {"dialogue": "file/key"}                   a normal dialogue entry (choices, if, next)
##   {"letter": [lines], "speaker": "Mirela"}   slow text, for letters and pages
##   {"move": "player" | npc id, "path": ["up", "left"]} or "to": [x, y] (PathFinder)
##   {"face": who, "dir": "left"}               turn a figure
##   {"emote": who, "icon": "!" | "?" | "..." | "heart" | "note"}
##   {"fade": "out" | "in", "color": "1b1b2a", "time": 0.4}
##   {"wait": 0.5}                              seconds
##   {"spawn": id, "x": 3, "y": 4, "sprite": "elder", "facing": "down", "color": "b04a4a"}
##   {"despawn": id}                            figures that only exist for the scene
##   {"card": "Chapter 1", "title": "The Map House"}   a chapter card over ink
##   {"flash": 0.2}, {"shake": 0.3}, {"sfx": "warp"}, {"music": "title"}
##   {"flag": "x"}, {"give_item": "tonic", "count": 2}, {"battle": "id"}, {"action": "..."}
## "Skip" (top right) jumps to the end but still runs every flag, item, battle and action step.
## Every scene sets "scene_<id>_seen" at the end.

signal _skip_pressed

const DIR: String = "res://data/scenes/"
## Steps that change the save and so also run when the scene is skipped.
const EFFECT_STEPS: Array[String] = ["flag", "give_item", "battle", "action", "set_var", "add_var"]
const EMOTE_TIME: float = 0.6
const LETTER_SPEED: float = 20.0
const MOVE_TIMEOUT: float = 3.0

var overworld: Overworld
var skipping: bool = false
var _spawned: Dictionary[String, NPC] = {}
var _skip_button: Button
var _emote: Label

static func load_scene(id: String) -> Dictionary:
	var path: String = DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw if raw is Dictionary else {}

static func exists(id: String) -> bool:
	return FileAccess.file_exists(DIR + id + ".json")

static func seen_flag(id: String) -> String:
	return "scene_%s_seen" % id

const KINDS: Array[String] = ["say", "dialogue", "letter", "move", "face", "emote", "fade", "wait",
	"spawn", "despawn", "card", "flash", "shake", "sfx", "music", "flag", "give_item", "battle",
	"action", "set_var", "add_var"]

## The kind of a step: the first known key it has ("" if none).
static func step_kind(step: Dictionary) -> String:
	for k: String in KINDS:
		if step.has(k):
			return k
	return ""

## True if the step must also run when the scene is skipped (a talk with choices counts).
static func runs_when_skipped(kind: String, step: Dictionary) -> bool:
	if kind in EFFECT_STEPS:
		return true
	return kind == "dialogue" and Dialogue.get_entry(str(step.dialogue)).has("choices")

## Plays the scene. Missing scenes do nothing (the validator reports them).
## [param data] replaces the file (tests).
func play(id: String, data: Dictionary = {}) -> void:
	var scene: Dictionary = data if not data.is_empty() else load_scene(id)
	var steps: Array = scene.get("steps", [])
	var was_busy: bool = overworld.busy
	var outer: bool = not overworld.scene_running
	# A scene started inside a skipped scene is skipped too.
	if overworld.scene_skipping:
		skipping = true
	elif skipping:
		overworld.scene_skipping = true
	overworld.busy = true
	overworld.scene_running = true
	overworld.player.frozen = true
	VirtualPad.set_wanted(false)
	if bool(scene.get("skippable", true)):
		_add_skip_button()
	for s: Variant in steps:
		if not s is Dictionary:
			continue
		var step: Dictionary = s
		var kind: String = step_kind(step)
		if skipping and not runs_when_skipped(kind, step):
			continue
		await _run(kind, step)
		if overworld.scene_abort:
			break
	var aborted: bool = overworld.scene_abort
	if outer:
		overworld.scene_abort = false
	_cleanup()
	if aborted:
		overworld.fade_rect().color.a = 0.0
	else:
		GameState.set_flag(seen_flag(id))
	if outer:
		overworld.scene_running = false
		overworld.scene_skipping = false
	overworld.busy = was_busy
	if not was_busy:
		overworld.player.frozen = false
		VirtualPad.set_wanted(true)

func _add_skip_button() -> void:
	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.offset_left = -34
	_skip_button.offset_top = 2
	_skip_button.offset_right = -2
	_skip_button.offset_bottom = 16
	_skip_button.theme = UITheme.get_theme()
	_skip_button.pressed.connect(skip)
	overworld.ui_root().add_child(_skip_button)

## Jumps to the end of the scene (effect steps still run).
func skip() -> void:
	skipping = true
	overworld.scene_skipping = true
	overworld.text_box().auto_advance = true
	overworld.text_box().advance_now()
	if _skip_button != null:
		_skip_button.visible = false
	_skip_pressed.emit()

func _cleanup() -> void:
	overworld.text_box().auto_advance = false
	overworld.text_box().visible = false
	for n: NPC in _spawned.values():
		n.queue_free()
	_spawned.clear()
	if _skip_button != null:
		_skip_button.queue_free()
	if _emote != null:
		_emote.queue_free()
	# A skipped scene never leaves the screen faded out.
	if skipping:
		overworld.fade_rect().color.a = 0.0

## Figure for "player" or an NPC id (spawned scene figures first).
func figure(who: String) -> GridWalker:
	if who == "player":
		return overworld.player
	if _spawned.has(who):
		return _spawned[who]
	return overworld.npc_by_id(who)

func _lines(v: Variant) -> Array[String]:
	var out: Array[String] = []
	for l: Variant in (v if v is Array else [v]):
		out.append(str(l))
	return out

func _run(kind: String, step: Dictionary) -> void:
	var box: TextBox = overworld.text_box()
	match kind:
		"say", "letter":
			var speed: float = box.chars_per_second
			if kind == "letter":
				box.chars_per_second = LETTER_SPEED
			box.visible = true
			for line: String in _lines(step.get(kind)):
				await box.show_text(line, str(step.get("speaker", "")))
				if skipping:
					break
			box.visible = false
			box.chars_per_second = speed
		"dialogue":
			await overworld.play_entry(str(step.dialogue))
		"move":
			await _move(figure(str(step.move)), step)
		"face":
			var f: GridWalker = figure(str(step.face))
			if f != null:
				f.face(str(step.get("dir", "down")))
		"emote":
			await _show_emote(figure(str(step.emote)), str(step.get("icon", "!")))
		"fade":
			var target: float = 1.0 if str(step.fade) == "out" else 0.0
			var rect: ColorRect = overworld.fade_rect()
			if step.has("color"):
				rect.color = Color(Color(str(step.color)), rect.color.a)
			var tw: Tween = overworld.create_tween()
			tw.tween_property(rect, "color:a", target, float(step.get("time", 0.4)))
			await tw.finished
		"wait":
			await _wait(float(step.wait))
		"spawn":
			var n := NPC.new()
			n.setup({"id": str(step.spawn), "x": int(step.get("x", 0)), "y": int(step.get("y", 0)),
				"facing": str(step.get("facing", "down")), "sprite": str(step.get("sprite", "villager")),
				"color": str(step.get("color", "b04a4a"))})
			overworld.entities().add_child(n)
			_spawned[str(step.spawn)] = n
		"despawn":
			var id: String = str(step.despawn)
			if _spawned.has(id):
				_spawned[id].queue_free()
				_spawned.erase(id)
			else:
				var n: NPC = overworld.npc_by_id(id)
				if n != null:
					n.visible = false
		"card":
			await _card(str(step.card), str(step.get("title", "")))
		"flash":
			var rect: ColorRect = overworld.fade_rect()
			var keep: Color = rect.color
			rect.color = Color(UITheme.BG, 0.9)
			await _wait(float(step.flash))
			rect.color = keep
		"shake":
			await overworld.shake_camera(float(step.shake))
		"sfx":
			Sound.sfx(str(step.sfx))
		"music":
			Sound.music(str(step.music))
		"flag":
			for f: Variant in (step.flag if step.flag is Array else [step.flag]):
				GameState.set_flag(str(f))
		"give_item":
			var count: int = int(step.get("count", 1))
			if skipping:
				GameState.add_item(str(step.give_item), count)
			else:
				await overworld.run_action(" ".join(["give_item", str(step.give_item), str(count)]))
		"set_var":
			for k: Variant in (step.set_var as Dictionary):
				GameState.set_story_var(str(k), int(step.set_var[k]))
		"add_var":
			for k: Variant in (step.add_var as Dictionary):
				GameState.add_story_var(str(k), int(step.add_var[k]))
		"battle":
			await overworld.run_action(" ".join(["battle", str(step.battle)]))
			overworld.busy = true
			overworld.player.frozen = true
		"action":
			await overworld.run_action(str(step.action))

func _wait(seconds: float) -> void:
	if seconds <= 0.0 or skipping:
		return
	var t: SceneTreeTimer = get_tree().create_timer(seconds)
	await t.timeout

## Walks a figure along "path" (directions) or to "to" ([x, y]) with PathFinder.
func _move(f: GridWalker, step: Dictionary) -> void:
	if f == null:
		return
	var dirs: Array[String] = []
	if step.has("path"):
		for d: Variant in step.path:
			if GridWalker.DIRS.has(str(d)):
				dirs.append(str(d))
	elif step.get("to") is Array and (step.to as Array).size() == 2:
		var goal := Vector2i(int(step.to[0]), int(step.to[1]))
		var passable: Callable = func(c: Vector2i) -> bool: return overworld.map.is_walkable(c)
		var cells: Array[Vector2i] = PathFinder.find(f.cell, goal, passable)
		var at: Vector2i = f.cell
		for c: Vector2i in cells:
			dirs.append(Overworld._dir_name(c - at))
			at = c
	for d: String in dirs:
		if skipping:
			f.place(f.cell + GridWalker.DIRS[d], d)
			continue
		f.step(d)
		var t: float = 0.0
		while f.moving and t < MOVE_TIMEOUT:
			await get_tree().process_frame
			t += get_process_delta_time()
	if f == overworld.player:
		GameState.player_cell = f.cell
		GameState.facing = f.facing

func _show_emote(f: GridWalker, icon: String) -> void:
	if f == null:
		return
	if _emote == null:
		_emote = Label.new()
		_emote.add_theme_stylebox_override("normal", UITheme.panel_style())
		_emote.theme = UITheme.get_theme()
		overworld.entities().add_child(_emote)
	var glyph: Dictionary = {"heart": "<3", "note": "~", "...": "...", "?": "?", "!": "!"}
	_emote.text = str(glyph.get(icon, icon))
	_emote.z_index = 10
	_emote.position = f.position + Vector2(2, -14)
	_emote.visible = true
	Sound.sfx("select")
	await _wait(EMOTE_TIME)
	_emote.visible = false

## A chapter card (plan item 1413): ink background, two centred lines.
func _card(top: String, title: String) -> void:
	var rect: ColorRect = overworld.fade_rect()
	var tw: Tween = overworld.create_tween()
	tw.tween_property(rect, "color:a", 1.0, 0.3)
	await tw.finished
	var label := Label.new()
	label.theme = UITheme.get_theme()
	label.text = Loc.t(top) + ("\n" + Loc.t(title) if not title.is_empty() else "")
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", UITheme.BG)
	overworld.ui_root().add_child(label)
	Sound.sfx("level_up")
	await _wait(1.6)
	label.queue_free()
	var back: Tween = overworld.create_tween()
	back.tween_property(rect, "color:a", 0.0, 0.3)
	await back.finished
