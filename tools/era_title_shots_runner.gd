extends Node
## The work of tools/era_title_shots.gd, run as a node so the autoloads exist. Every moment is
## driven by hand (its clock is set, then a frame is drawn), so the strips are the same each run.

const ROMAN: Array[String] = ["", "i", "ii", "iii", "iv", "v"]
var out: String = "user://era_title_shots"
var lang: String = "en"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	Loc.set_language(lang)
	GameState.language = lang
	EraBoot.shown = true
	GameState.reduce_motion = false
	# A phone screen (19.5:9) rather than the bare 9:16 minimum.
	get_window().size = Vector2i(432, 936)
	var em: Node = get_tree().root.get_node("/root/EraManager")
	for era: int in range(1, 6):
		em.call("from_dict", {"unlocked_era": era})
		await _frames(2)
		await _title(era)
		await _boot(era)
		await _finale(era)
		if era >= 2:
			await _change(era)
	em.call("from_dict", {"unlocked_era": 5})
	await _frames(2)
	await _cards()
	get_tree().quit()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _grab() -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _save(frames: Array[Image], name: String) -> void:
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var strip: Image = Image.create((w + 4) * frames.size() - 4, h, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.1, 0.1, 0.1))
	for i: int in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(i * (w + 4), 0))
	var scale: int = 2 if w <= 200 else 1
	strip.resize(strip.get_width() * scale, strip.get_height() * scale, Image.INTERPOLATE_NEAREST)
	strip.save_png("%s/%s_%s.png" % [out, name, lang])
	print("saved %s (%d frames)" % [name, frames.size()])

## The title as the player sees it: picture, save card and a stand-in for the menu rows.
func _title(era: int) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var host := Control.new()
	host.theme = UITheme.get_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var art := EraTitleArt.new()
	art.era = era
	art.manual = true
	art.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var art_h: int = EraTitleArt.art_height(size.x)
	art.offset_bottom = art_h
	host.add_child(art)
	var card := EraSaveCard.new()
	card.era = era
	card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 4
	card.offset_right = -4
	card.offset_top = art_h + 2
	card.offset_bottom = art_h + 2 + EraSaveCard.height_for(size.x)
	host.add_child(card)
	add_child(host)
	var menu := MenuHost.new()
	host.add_child(menu)
	menu.offset_top = card.offset_bottom + 2
	card.show_save(era, "%s  %d:%02d" % [str(EraMoments.era(era).region), 20 * era, 7 * era])
	var rows: Array[Dictionary] = [{"text": "Continue", "icon": EraSaveCard.badge(era)}, {"text": "New Game"}, {"text": "What's new"}, {"text": "Settings"}]
	menu.pick("", rows, false)
	var frames: Array[Image] = []
	for t: float in ([0.0, 0.7] if era == 1 else [0.5, 1.0, 2.2, 5.5]):
		art.clock = t
		frames.append(await _grab())
	_save(frames, "title_era_%s" % ROMAN[era])
	host.queue_free()
	await _frames(1)

func _boot(era: int) -> void:
	var b := EraBoot.new()
	b.era = era
	b.manual = true
	add_child(b)
	var total: float = b.total()
	var frames: Array[Image] = []
	for k: float in [0.12, 0.3, 0.45, 0.62, 0.8]:
		b.t = total * k
		b.stage.queue_redraw()
		frames.append(await _grab())
	_save(frames, "boot_era_%s" % ROMAN[era])
	b.queue_free()
	await _frames(1)

func _finale(era: int) -> void:
	var c := EraFinaleCard.new()
	c.era = era
	c.manual = true
	add_child(c)
	var full: float = EraFinaleCard.full_time(era)
	var frames: Array[Image] = []
	for k: float in [0.25, 0.6, 1.05]:
		c.t = full * k
		c._art.clock = c.t
		c.stage.queue_redraw()
		frames.append(await _grab())
	_save(frames, "finale_era_%s" % ROMAN[era])
	c.queue_free()
	await _frames(1)

## One frame in the middle of each step of the change into [param to], and the finished list.
func _change(to: int) -> void:
	var s := EraChangeScene.new()
	s.from_era = to - 1
	s.to_era = to
	s.manual = true
	add_child(s)
	await _frames(1)
	var frames: Array[Image] = []
	var tl: Array[Dictionary] = EraMoments.timeline(to)
	var times: Array[float] = [0.05]
	for st: Dictionary in tl:
		times.append((float(st.start) + float(st.end)) / 2.0)
	times.append(float(tl[-1].end) + 0.1)
	for t: float in times:
		s.t = t
		s.step()
		s.stage.queue_redraw()
		frames.append(await _grab())
	_save(frames, "change_era_%s_to_%s" % [ROMAN[to - 1], ROMAN[to]])
	# The reduced-motion version: a plain fade, then the list.
	s.queue_free()
	await _frames(1)
	var r := EraChangeScene.new()
	r.from_era = to - 1
	r.to_era = to
	r.manual = true
	r.reduced = true
	add_child(r)
	await _frames(1)
	frames = []
	for t: float in [0.2, EraMoments.total_time(to, true) + 0.1]:
		r.t = t
		r.step()
		r.stage.queue_redraw()
		frames.append(await _grab())
	_save(frames, "change_reduced_era_%s" % ROMAN[to])
	r.queue_free()
	await _frames(1)

## The five save cards under each other, as a slot list would show them.
func _cards() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("20222c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var h: int = EraSaveCard.height_for(size.x)
	for era: int in range(1, 6):
		var card := EraSaveCard.new()
		card.era = era
		card.position = Vector2(6, 8 + (era - 1) * (h + 8))
		card.size = Vector2(size.x - 12, h)
		bg.add_child(card)
		card.show_save(era, "%s  %d:%02d" % [str(EraMoments.era(era).region), 20 * era, 7 * era])
		var icon := TextureRect.new()
		icon.texture = EraSaveCard.badge(era)
		icon.position = Vector2(8 + (era - 1) * 24, 16 + 5 * (h + 8))
		icon.scale = Vector2(2, 2)
		bg.add_child(icon)
	_save([await _grab()], "save_cards")
	bg.queue_free()
