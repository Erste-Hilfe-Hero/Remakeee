class_name LiveDuelStage
extends Control
## A live duel in the animated battle screen (Online 100, points 1 and 73), for the two players and
## for friends who watch. The battle screen itself is used as it is, in its replay mode; this node
## asks the server for the rounds, hands them to the battle (LiveBattleModel), and lays the choices,
## the clock, emotes and the result over it.

signal finished

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/Battle.tscn")
## Seconds between two questions to the server.
const POLL: float = 1.5
const STEP: float = 0.2
## Seconds an emote stays on the bar.
const EMOTE_SECONDS: int = 6
const DOCK_HEIGHT: int = 70
const DOCK_MARGIN: int = 8

var duel_id: int = 0
var watch: bool = false
## The friend's name (players) or both names (watchers), lower side first once the duel is known.
var names: Array = ["", ""]
## The last answer of the server.
var state: Dictionary = {}
var model: LiveBattleModel
var scene: BattleScene
## Rounds handed to the battle so far.
var fed: int = 0
## Set when the duel ended while the player was here (LiveDuelMenu offers rematch and report).
var ended: bool = false

var _bar: Label
var _menu_button: Button
var _panel: PanelContainer
var _scene_done: bool = false
var _choosing: bool = false
var _busy: bool = false
var _menu_open: bool = false
var _finish_asked: int = 0
var _leave: bool = false
var _text_box: TextBox

func setup(info: Dictionary) -> void:
	duel_id = int(info.get("id", 0))
	watch = bool(info.get("watch", false))
	if info.get("names") is Array and (info.names as Array).size() == 2:
		names = [str(info.names[0]), str(info.names[1])]
	elif info.has("name"):
		names = [str(info.name), ""]

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run.call_deferred()

func _process(_delta: float) -> void:
	# Lines go on by themselves: the round clock runs for both players.
	if scene != null and _text_box == null:
		_text_box = _find_text_box(scene)
	if _text_box != null:
		_text_box.auto_advance = true

static func _find_text_box(n: Node) -> TextBox:
	for c: Node in n.get_children():
		if c is TextBox:
			return c
		var deeper: TextBox = _find_text_box(c)
		if deeper != null:
			return deeper
	return null

func _fetch() -> Dictionary:
	var r: Dictionary = await Online.call_fn("live_watch" if watch else "live_state", {"p_id": duel_id})
	if LiveDuelMenu._ok(r):
		return r.data
	return {"error": LiveDuelMenu.error_text(r), "net": not bool(r.get("ok", false))}

## How many rounds of [param d] have both choices.
static func complete_rounds(d: Dictionary) -> int:
	var moves: Dictionary = d.get("moves", {}) if d.get("moves") is Dictionary else {}
	var n: int = 0
	while moves.get(str(n + 1)) is Array and (moves[str(n + 1)] as Array).size() == 2 \
			and moves[str(n + 1)][0] is Dictionary and moves[str(n + 1)][1] is Dictionary:
		n += 1
	return n

## Hands every finished round the battle does not have yet to it.
func _feed() -> void:
	var full: int = complete_rounds(state)
	while fed < full:
		fed += 1
		model.rounds.append(state.moves[str(fed)])

## Has the player chosen for the open round?
static func moved(d: Dictionary) -> bool:
	var row: Variant = (d.get("moves", {}) as Dictionary).get(str(int(d.get("round", 0))))
	var side: int = int(d.get("side", -1))
	return side >= 0 and row is Array and (row as Array).size() == 2 and row[side] != null

## May the player choose now? Only when the battle on screen has caught up with the server.
func can_choose() -> bool:
	return not watch and str(state.get("state", "")) == "running" and not bool(state.get("judging", false)) and model.waiting \
		and model.rounds.is_empty() and not model.is_finished() and model.played == int(state.round) - 1 and not moved(state)

func _run() -> void:
	state = await _fetch()
	if state.has("error") or not str(state.get("state", "")) in ["running", "done"]:
		await _ask(str(state.get("error", Loc.t("This duel is over."))), ["Close"])
		finished.emit()
		return
	model = LiveBattleModel.build(state)
	if model == null:
		await _ask(Loc.t("That replay can't be shown any more."), ["Close"])
		finished.emit()
		return
	var side: int = int(state.get("side", -1))
	if state.get("names") is Array and (state.names as Array).size() == 2:
		names = [str(state.names[0]), str(state.names[1])]
	elif side >= 0:
		var friend: String = str(names[0])
		names = [Loc.t("You"), friend] if side == 0 else [friend, Loc.t("You")]
	model.trainer_name = str(names[1])
	# Someone who comes in late starts at the round that was played last.
	if str(state.state) == "running":
		var skip: Array = []
		for r: int in range(1, complete_rounds(state)):
			skip.append(state.moves[str(r)])
		model.enter(skip)
		fed = skip.size()
	_feed()
	scene = BATTLE_SCENE.instantiate()
	scene.setup(model)
	scene.replay_inputs = model.feed
	scene.music_track = BattleAudio.theme("duel", false, false, false)
	scene.battle_finished.connect(func(_o: BattleModel.Outcome, _m: BattleModel) -> void: _scene_done = true)
	add_child(scene)
	_build_overlay()
	var since: float = 0.0
	while not _leave:
		_feed()
		_bar.text = bar_text(state, names, watch, int(Time.get_unix_time_from_system()))
		if str(state.state) == "done":
			# Played to the end: let the last round run out. Given up or out of time: stop now.
			if str(state.reason) != "played" or _scene_done or (model.waiting and model.rounds.is_empty()):
				break
		elif not watch and _scene_done and model.is_finished() and _finish_asked < fed and not bool(state.get("judging", false)):
			_finish_asked = fed
			var r: Dictionary = await Online.call_fn("live_finish", {"p_id": duel_id, "p_winner": model.winner()})
			if LiveDuelMenu._ok(r):
				state = r.data
			continue
		elif can_choose() and not _choosing and not _busy and not _menu_open:
			_choose()
		await get_tree().create_timer(STEP).timeout
		since += STEP
		if since >= POLL and not _busy:
			since = 0.0
			var d: Dictionary = await _fetch()
			if d.has("error") and bool(d.get("net", false)):
				# No answer this time: ask again.
				continue
			if d.has("error"):
				# The duel is gone (a block, the parent switch): nothing more to show.
				if not _scene_done:
					model.close()
				await _ask(str(d.error), ["Close"])
				finished.emit()
				return
			if not _busy:
				state = d
	_close_panel()
	_menu_button.visible = false
	model.close()
	if _leave:
		finished.emit()
		return
	ended = true
	await _result()
	finished.emit()

# --- The overlay -------------------------------------------------------------------------------

## The lines and the menu button sit in the lower part of the screen, where the battle screen
## shows its commands in a normal battle and nothing while it plays a replay.
func _build_overlay() -> void:
	_bar = Label.new()
	_bar.add_theme_font_size_override("font_size", UITheme.FONT_SIZE)
	_bar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_left = DOCK_MARGIN
	_bar.offset_right = -DOCK_MARGIN
	_bar.offset_top = -DOCK_HEIGHT
	_bar.offset_bottom = -DOCK_MARGIN - 14
	add_child(_bar)
	_menu_button = Button.new()
	_menu_button.text = Loc.t("Menu")
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_menu_button.offset_left = -44
	_menu_button.offset_right = -DOCK_MARGIN
	_menu_button.offset_top = -DOCK_MARGIN - 12
	_menu_button.offset_bottom = -DOCK_MARGIN
	_menu_button.pressed.connect(_open_menu)
	add_child(_menu_button)

## The lines over the battle: who stands where, the round and the clock, the last emote.
static func bar_text(d: Dictionary, p_names: Array, watching: bool, now: int) -> String:
	var lines: Array[String] = [Loc.t("Top: %s  Bottom: %s") % [str(p_names[1]), str(p_names[0])]]
	if str(d.get("state", "")) == "running":
		if watching:
			lines.append(Loc.t("Round %d (you see it one move later)") % maxi(1, int(d.round) - 1))
		elif bool(d.get("judging", false)):
			lines.append(Loc.t("The referee checks the duel."))
		else:
			lines.append(Loc.t("Round %d") % int(d.round) + "  " + Loc.t("Time left: %d s") % LiveDuel.seconds_left(int(d.deadline), now))
			if moved(d):
				lines.append(Loc.t("You chose. Waiting for your friend."))
	for e: Dictionary in (d.get("emotes", []) as Array).slice(-1):
		if now - int(e.get("at", 0)) <= EMOTE_SECONDS:
			lines.append("%s: %s" % [str(p_names[int(e.side)]), LiveDuel.emote_text(int(e.emote))])
	return "\n".join(lines)

## A list to pick from, over the battle. Returns the index, or -1 when another list took its place.
func _ask(title: String, labels: Array) -> int:
	_close_panel()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.add_user_signal("picked", [{"name": "index", "type": TYPE_INT}])
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	panel.add_child(col)
	var head := Label.new()
	head.text = title
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", UITheme.FONT_SIZE)
	col.add_child(head)
	for i: int in labels.size():
		var b := Button.new()
		b.text = Loc.t(str(labels[i]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			Sound.sfx("confirm")
			panel.emit_signal("picked", i))
		col.add_child(b)
	add_child(panel)
	_panel = panel
	if col.get_child_count() > 1:
		(col.get_child(1) as Button).grab_focus.call_deferred()
	var idx: int = await Signal(panel, "picked")
	if _panel == panel:
		_panel = null
	panel.queue_free()
	return idx

func _close_panel() -> void:
	if _panel != null:
		var old: PanelContainer = _panel
		_panel = null
		old.emit_signal("picked", -1)

func _choose() -> void:
	_choosing = true
	var side: int = int(state.side)
	var round_no: int = int(state.round)
	var options: Array = LiveDuelSim.choices_of(model, side)
	var labels: Array = []
	for o: Dictionary in options:
		labels.append(str(o.label))
	var me: Spirling = model.active_spirling(side)
	var idx: int = await _ask(Loc.t("Round %d: choose for %s") % [round_no, me.display_name() if me != null else "-"], labels)
	if idx >= 0 and str(state.get("state", "")) == "running" and int(state.round) == round_no:
		_busy = true
		var r: Dictionary = await Online.call_fn("live_move", {"p_id": duel_id, "p_round": round_no, "p_input": options[idx].input})
		_busy = false
		if LiveDuelMenu._ok(r):
			state = r.data
	_choosing = false

func _open_menu() -> void:
	if _busy or _menu_open:
		return
	_menu_open = true
	await _menu()
	_menu_open = false

func _menu() -> void:
	var entries: Array = ["Stop watching", "Back"] if watch else ["Send an emote", "Give up", "Leave (the duel goes on)", "Back"]
	var idx: int = await _ask(Loc.t("Live duel"), entries)
	if idx < 0:
		return
	match str(entries[idx]):
		"Stop watching", "Leave (the duel goes on)":
			_leave = true
		"Send an emote":
			var e: int = await _ask(Loc.t("Send an emote"), LiveDuel.EMOTES)
			if e >= 0:
				await Online.call_fn("live_emote", {"p_id": duel_id, "p_emote": e})
		"Give up":
			if await _ask(Loc.t("Really give up this duel?"), ["Yes", "No"]) == 0:
				_busy = true
				var r: Dictionary = await Online.call_fn("live_forfeit", {"p_id": duel_id})
				_busy = false
				if LiveDuelMenu._ok(r):
					state = r.data

## The result with the damage per Spirling (point 10) and the result picture (point 76).
func _result() -> void:
	var lines: Array[String] = result_lines(state, names, watch)
	var sim: LiveDuelSim = LiveDuelSim.of(state)
	if sim != null:
		for side: int in 2:
			lines.append(str(names[side]) + ":")
			lines.append_array(sim.summary(side))
	while true:
		var idx: int = await _ask("\n".join(lines), ["Save a result picture", "Close"])
		if idx != 0:
			return
		lines = [await ResultCard.save(self, ResultCard.facts_of_duel(state, names))]

static func result_lines(d: Dictionary, p_names: Array, watching: bool) -> Array[String]:
	if not watching:
		return [LiveDuel.result_text(int(d.side), int(d.winner), str(d.reason))]
	var out: Array[String] = [Loc.t("The duel is over.")]
	if int(d.get("winner", -1)) >= 0:
		out.append(Loc.t("%s wins!") % str(p_names[int(d.winner)]))
	elif str(d.get("reason", "")) == "played":
		out.append(Loc.t("Draw"))
	return out
