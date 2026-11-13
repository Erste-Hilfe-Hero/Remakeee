extends Node
## The work of tools/era_chars_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 3
## One outdoor town per era region.
const TOWNS: Dictionary[int, String] = {1: "brindlewick", 2: "cindergate_quay", 3: "burin_landing", 4: "brightledge", 5: "driftwick"}
const GROUND: Color = Color("86b46a")
var out: String = "user://era_chars"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	var em: Node = get_tree().root.get_node("/root/EraManager")
	for era: int in range(1, 6):
		# The look of a player who has just reached this era (no Retro filter involved).
		em.set("unlocked_era", era)
		em.call("set_retro_filter", 0)
		await _cast(era)
		await _town(era)
	get_tree().quit()

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

## A cell next to a villager with room for the Wayfarer and the Spirling behind.
func _spot(m: MapData) -> Vector2i:
	var taken: Dictionary = {}
	for n: Dictionary in m.npcs:
		taken[Vector2i(int(n.x), int(n.y))] = true
	for n: Dictionary in m.npcs:
		var c := Vector2i(int(n.x) + 1, int(n.y) + 1)
		var ok: bool = true
		for d: Vector2i in [Vector2i.ZERO, Vector2i.DOWN, Vector2i.RIGHT]:
			ok = ok and m.is_walkable(c + d) and not taken.has(c + d)
		if ok:
			return c
	return Vector2i(int(m.npcs[0].x), int(m.npcs[0].y) + 1)

func _town(era: int) -> void:
	var gs: Node = get_tree().root.get_node("/root/GameState")
	gs.call("new_game", 1, "Rowan", 1, "Kindlop", 0, 2, 3)
	gs.set("reduce_motion", false)
	var m: MapData = MapData.load_map(TOWNS[era])
	gs.set("current_map", TOWNS[era])
	gs.set("player_cell", _spot(m))
	gs.set("facing", "up")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	await _frames(40)
	var actors: EraActors = EraActors.current
	var near: Array[NPC] = []
	for n: NPC in ow._npcs:
		near.append(n)
	near.sort_custom(func(a: NPC, b: NPC) -> bool: return (a.cell - ow.player.cell).length_squared() < (b.cell - ow.player.cell).length_squared())
	if near.size() > 0:
		near[0].alert = true
	if near.size() > 1:
		actors.show_bubble(near[1], "heart", 99.0)
	if near.size() > 2:
		actors.show_bubble(near[2], "...", 99.0)
	await _frames(30)
	await _save("era%d_town" % era)
	# A running step to the right, held in the middle.
	if near.size() > 0:
		near[0].alert = false
	ow.player.step("right", true)
	ow.player._t = ow.player._duration * 0.5
	ow.player.set_process(false)
	ow.player.position = GridWalker.cell_to_pos(ow.player.cell) - Vector2(8, 0)
	await _frames(3)
	await _save("era%d_run" % era)
	ow.queue_free()
	await _frames(2)

func _cast(era: int) -> void:
	var size: Vector2 = Vector2(EraManager.RESOLUTION[era])
	var scene := Node2D.new()
	get_tree().root.add_child(scene)
	var bg := ColorRect.new()
	bg.color = GROUND
	bg.size = size
	scene.add_child(bg)
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	scene.add_child(holder)
	var actors := EraActors.new()
	actors.entities = holder
	scene.add_child(actors)
	var styles: Array = EraActorLook.data().styles
	var per_row: int = int((size.x - 8) / 18)
	var r: Dictionary = EraActorLook.row(era)
	var row_h: int = int(r.frame[1]) + 6
	var y: int = 14
	# Everyone facing down, then every direction of the Wayfarer.
	y = _line(holder, styles, per_row, y, func(_n: NPC, _i: int) -> void: pass, row_h)
	y = _line(holder, ["tamer", "tamer", "tamer", "tamer", "tamer_f", "tamer_f", "tamer_f", "tamer_f"], per_row, y,
		func(n: NPC, i: int) -> void: n.face(["down", "up", "left", "right"][i % 4]), row_h)
	# Walking: both feet, to the side and toward the camera; then running.
	y = _line(holder, ["villager", "villager", "ranger", "ranger", "elder", "elder", "stranger_kid", "stranger_kid"], per_row, y,
		func(n: NPC, i: int) -> void: _hold_step(n, ["right", "right", "down", "down"][i % 4], i % 2, false, 0.5), row_h)
	y = _line(holder, ["tamer", "tamer", "tamer_f", "tamer_f", "ranger", "ranger"], per_row, y,
		func(n: NPC, i: int) -> void: _hold_step(n, ["right", "down"][i % 2], i / 2, true, 0.5 if i % 4 < 2 else 0.1), row_h)
	# Head turns (Era IV on these are head-only), the wading pose, season outfits.
	y = _line(holder, ["villager", "villager", "elder", "elder", "tamer_f", "warden"], per_row, y,
		func(n: NPC, i: int) -> void: n.look = ["left", "right", "left", "right", "up", "left"][i], row_h)
	y = _line(holder, ["tamer", "tamer_f", "villager", "villager", "villager", "villager", "elder", "elder"], per_row, y,
		func(n: NPC, i: int) -> void:
			if i < 2:
				n.era_anim["wade"] = true
			elif i < 6:
				n.era_anim["outfit"] = (i - 2) if str(r.outfits) == "season" else 0
			else:
				n.era_anim["outfit"] = (i - 5) * 2 - 1 if str(r.outfits) == "season" else 0, row_h)
	# Every bubble of the era.
	var kinds: Array = r.emotes
	y += 8
	var shown: Array[NPC] = []
	y = _line(holder, kinds.map(func(_k: Variant) -> String: return "villager"), per_row, y, func(n: NPC, _i: int) -> void: shown.append(n), row_h + 4)
	# The Spirling behind.
	var f := Sprite2D.new()
	f.centered = false
	f.texture = MiniSprite.of("Kindlop", GridWalker.TILE)
	f.modulate = Color(UITheme.INK, 0.85)
	f.position = Vector2(8 + 18, y + 4)
	holder.add_child(f)
	actors.follower = f
	var lead := NPC.new()
	lead.setup({"id": "lead", "x": 0, "y": 0, "sprite": "tamer", "facing": "right", "still": true})
	holder.add_child(lead)
	lead.position = Vector2(8 + 36, y + 4)
	await _frames(4)
	for i: int in shown.size():
		if EraActorLook.plain_emotes(era):
			shown[i].alert = i == 0
		else:
			actors.show_bubble(shown[i], str(kinds[i]), 99.0)
	await _frames(20)
	await _save("era%d_cast" % era)
	scene.queue_free()
	await _frames(2)

## Adds one row of figures and returns the y of the next row.
func _line(holder: Node2D, styles: Array, per_row: int, y: int, each: Callable, row_h: int) -> int:
	for i: int in styles.size():
		if i > 0 and i % per_row == 0:
			y += row_h
		var n := NPC.new()
		n.setup({"id": "c%d_%d" % [y, i], "x": 0, "y": 0, "sprite": str(styles[i]), "facing": "down", "still": true})
		holder.add_child(n)
		n.position = Vector2(8 + (i % per_row) * 18, y)
		n.cell = Vector2i(i, 0)
		each.call(n, i)
	return y + row_h

## Freezes [param n] part-way through a step.
func _hold_step(n: NPC, dir: String, parity: int, run: bool, k: float) -> void:
	var at: Vector2 = n.position
	n.step(dir, run)
	n.cell = Vector2i(parity, 0)
	n._t = n._duration * k
	n.set_process(false)
	n.position = at
