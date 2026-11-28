extends Node
## The work of tools/c200_start_shots.gd, run as a node so the autoloads exist.

const Shots: GDScript = preload("res://tools/era_battle_shots_runner.gd")
const SCALE: int = 2

var out: String = "user://c200_start_shots"

func _ready() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)

func _run() -> void:
	Database.load_all()
	Loc.set_language("en")
	GameState.language = "en"
	GameState.reduce_motion = true
	var menu := MenuHost.new()
	get_tree().root.add_child(menu)
	await _frames(10)
	var rows: Array[Dictionary] = [{"text": "Continue  Brindlewick  1:05", "icon": EraSaveCard.continue_icon(1, "Kindlop")},
		{"text": "New Game"}, {"text": "What's new"}, {"text": "Settings"}]
	menu.pick("", rows, false)
	await _frames(10)
	await _shot("item02_continue_lead")
	menu.picker.picked.emit(-1)
	await _frames(4)
	var saves: Array = [{"saved_at": 1764000000, "summary": "Brindlewick  1:05"}, {"saved_at": 1763900000, "summary": "Fernstair  0:52"},
		{"saved_at": 1763800000, "summary": "Saltmarsh  0:40"}]
	menu.pick("Earlier saves (the server keeps the last 5)", SaveHistoryMenu.entry_rows(saves))
	await _frames(10)
	await _shot("item17_earlier_saves")
	menu.picker.picked.emit(-1)
	menu.queue_free()
	await _frames(4)
	GameState.spirlog = {}
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	inst.setup(Shots.formation_model([1, 1]))
	get_tree().root.add_child(inst)
	var left: int = 600
	while not inst._waiting_orders and left > 0:
		inst._text.advance_now()
		await get_tree().create_timer(0.1).timeout
		left -= 1
	print("menu open: ", Shots.settled(inst))
	await get_tree().create_timer(FirstArtArrow.IDLE_SECONDS + 0.5).timeout
	print("arrow visible: ", inst._first_arrow != null and inst._first_arrow.visible)
	await _shot("item11_first_battle_arrow")
	get_tree().quit()
