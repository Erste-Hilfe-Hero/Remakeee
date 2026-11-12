class_name ResultCard
extends RefCounted
## A result picture of a battle (Online 100, point 76): who fought, who won, in how many rounds and
## which Spirlings still stood, drawn in the game with its own Spirling art and saved next to the
## photos. Made from a replay (Records > Online replays) or from a finished live duel.

const SIZE := Vector2i(176, 112)
const ICON: int = 20
const FILE: String = "chimora_result.png"

## What the card shows for [param model] after its battle: {title, names, winner (0, 1 or -1),
## rounds, teams: [[{species, name, left, full}]]}. [param names] are the two sides, lower side first.
static func facts_of_model(model: BattleModel, title: String, names: Array) -> Dictionary:
	var teams: Array = []
	for side: int in 2:
		var rows: Array = []
		for s: Spirling in model.party(side):
			rows.append({"species": s.data.species_name, "name": s.display_name(), "left": maxi(0, s.hp), "full": s.max_hp()})
		teams.append(rows)
	var a: int = model.alive_count(0)
	var b: int = model.alive_count(1)
	var won: int = -1
	if model.is_finished():
		won = 0 if a > 0 and b == 0 else (1 if b > 0 and a == 0 else -1)
		if model.outcome == BattleModel.Outcome.WIN:
			won = 0
		elif model.outcome == BattleModel.Outcome.LOSS:
			won = 1
	return {"title": title, "names": [str(names[0]), str(names[1])], "winner": won, "rounds": model.turn, "teams": teams}

## The facts of a kept replay: the battle is played again from its seed, teams and inputs.
## {} when it cannot be played in this version.
static func facts_of_replay(snap: Dictionary, title: String) -> Dictionary:
	var m: BattleModel = BattleReplay.build_model(snap)
	if m == null:
		return {}
	m.start()
	for v: Variant in snap.get("inputs", []):
		if m.is_finished() or not v is Dictionary:
			break
		var d: Dictionary = v
		if str(d.get("t", "")) == "switch":
			if not m.needs_player_switch() or not int(d.get("i", -1)) in m.swap_candidates(BattleModel.Side.PLAYER, m.switch_slot()):
				break
			m.submit_switch(int(d.get("i", 0)))
		elif m.needs_player_switch():
			break
		elif str(d.get("t", "")) == "turns":
			m.submit_actions(BattleReplay.actions_from_dict(d))
		else:
			m.submit_turn(BattleReplay.action_from_dict(d))
	var foe: String = str(snap.get("trainer", ""))
	if foe.is_empty():
		foe = (m.party(BattleModel.Side.FOE)[0] as Spirling).display_name()
	return facts_of_model(m, title, [Loc.t("You"), foe])

## The facts of a live duel from its state (live_state or live_watch) and both names.
static func facts_of_duel(d: Dictionary, names: Array) -> Dictionary:
	var sim: LiveDuelSim = LiveDuelSim.of(d)
	if sim == null:
		return {}
	var f: Dictionary = facts_of_model(sim.model, Loc.t("Live duel"), names)
	f["rounds"] = sim.played
	# Given up or out of time: the server's winner counts, not the Spirlings left.
	if str(d.get("state", "")) == "done":
		f["winner"] = int(d.get("winner", -1))
	return f

## "Mira beats Tom" / "No winner".
static func headline(f: Dictionary) -> String:
	var w: int = int(f.get("winner", -1))
	if w < 0:
		return Loc.t("No winner")
	return Loc.t("%s beats %s") % [str(f.names[w]), str(f.names[1 - w])]

## The card as a node tree of [constant SIZE].
static func build(f: Dictionary) -> Control:
	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.custom_minimum_size = Vector2(SIZE)
	root.size = Vector2(SIZE)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = Vector2(SIZE)
	root.add_child(bg)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style())
	frame.size = Vector2(SIZE)
	root.add_child(frame)
	var col := VBoxContainer.new()
	col.position = Vector2(5, 4)
	col.size = Vector2(SIZE) - Vector2(10, 8)
	col.add_theme_constant_override("separation", 1)
	root.add_child(col)
	col.add_child(_line("%s - %s" % [ProjectSettings.get_setting("application/config/name", ""), str(f.get("title", ""))], "title"))
	col.add_child(_line(headline(f), "headline"))
	col.add_child(_line(Loc.t("Rounds: %d") % int(f.get("rounds", 0)), "rounds"))
	for side: int in [1, 0]:
		col.add_child(_line(str(f.names[side]) + ("  *" if int(f.get("winner", -1)) == side else ""), "name%d" % side))
		var row := HBoxContainer.new()
		row.name = "team%d" % side
		row.add_theme_constant_override("separation", 1)
		for s: Dictionary in f.teams[side]:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(ICON, ICON)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var path: String = EraManager.sprite_path(str(s.species), "front")
			if not path.is_empty() and ResourceLoader.exists(path):
				icon.texture = load(path)
			# A Spirling that dropped is shown dark.
			if int(s.left) <= 0:
				icon.modulate = Color(0.25, 0.25, 0.3, 0.8)
			icon.tooltip_text = str(s.name)
			row.add_child(icon)
		col.add_child(row)
	return root

static func _line(text: String, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.FONT_SIZE)
	l.clip_text = true
	return l

## Draws the card off screen and gives the picture; null when the device cannot draw it.
static func render(host: Node, f: Dictionary) -> Image:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(build(f))
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	return img

## Draws and saves the card. Returns the line to tell the player.
static func save(host: Node, f: Dictionary) -> String:
	if f.is_empty():
		return Loc.t("This battle cannot be shown any more.")
	var img: Image = await render(host, f)
	if img == null or img.is_empty():
		return Loc.t("Could not save the picture.")
	if OS.has_feature("web"):
		var big: Image = img.duplicate()
		big.resize(img.get_width() * PhotoMode.SCALE, img.get_height() * PhotoMode.SCALE, Image.INTERPOLATE_NEAREST)
		JavaScriptBridge.download_buffer(big.save_png_to_buffer(), FILE, "image/png")
		return Loc.t("The result picture is in your downloads.")
	var path: String = PhotoMode.save_photo(img)
	if path.is_empty():
		return Loc.t("Could not save the picture.")
	return Loc.t("Result picture saved with your photos.")
