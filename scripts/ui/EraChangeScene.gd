class_name EraChangeScene
extends EraMomentLayer
## The era change, staged in front of the player (data/era_moments.json "changes",
## docs/ERA_LOOK_TITLE.md). After an era finale the lake scene of the new era stands on screen
## the way the old hardware would draw it, and then upgrades step by step:
##   1 palette  the new colours come in (ink bleeding out, a scan line, the picture unrolling,
##              light sweeping across: every change has its own front)
##   2 detail   resolution and colour depth step up; from Era V the scene starts to move
##   3 frames   the menu frame below is redrawn in the new era's style
##   4 music    the old era's sound gives way to the new one (Sound bus effects and the era song)
##   5 list     "New in this era": EraFeatures.new_in(era)
## A press jumps to the list, the next one closes. With reduced motion: a plain fade, then the list.
## The era line and the long texts still come from the overworld text box afterwards.

const SHADER: Shader = preload("res://shaders/era_moment.gdshader")
const STYLE_OF: Dictionary[int, int] = {2: 1, 3: 2, 4: 3, 5: 4}
## Colour levels per channel an era shows (0 = the four inks) and voices its sound chip plays.
const LEVELS: Array[float] = [0.0, 0.0, 3.0, 6.0, 12.0, 32.0]
const VOICES: Array[int] = [0, 4, 5, 8, 12, 16]

var from_era: int = 1
var to_era: int = 2
var state: Dictionary = {}
var _view: SubViewport
var _art: EraTitleArt
var _pic: TextureRect
var _caption: Label
var _list: Label
var _hint: Label
var _music_done: bool = false
var _started: bool = false

## Plays the change from [param from] into [param to] over [param parent]; returns when it closed.
static func play(parent: Node, from: int, to: int) -> void:
	var s := EraChangeScene.new()
	s.from_era = clampi(from, 1, 4)
	s.to_era = clampi(to, 2, 5)
	parent.add_child(s)
	await s.finished

## After an era finale: the finale card of the era that ended, then one change scene per era
## that opened. Sets the seen flags. [param host] is the overworld (its "busy" is held).
static func play_after_finale(host: Node, era_before: int, era_now: int) -> void:
	var was_busy: Variant = host.get("busy")
	host.set("busy", true)
	if EraMoments.card_owed(era_before, GameState.has_flag):
		GameState.set_flag(EraMoments.CARD_FLAG % era_before)
		await EraFinaleCard.play(host, era_before)
	for e: int in range(era_before + 1, era_now + 1):
		if GameState.has_flag(EraMoments.CHANGE_FLAG % e):
			continue
		GameState.set_flag(EraMoments.CHANGE_FLAG % e)
		await play(host, e - 1, e)
	host.set("busy", was_busy)

## Shader settings of the change [param from] -> [param to] for a vignette [param art_h] px high.
static func params(from: int, to: int) -> Dictionary:
	var old_w: float = EraManager.RESOLUTION[clampi(from, 1, 5)].x
	var new_w: float = EraManager.RESOLUTION[clampi(to, 1, 5)].x
	return {
		"style": STYLE_OF.get(to, 1),
		"old_res": Vector2(old_w, EraTitleArt.art_height(old_w)),
		"new_res": Vector2(new_w, EraTitleArt.art_height(new_w)),
		"old_levels": LEVELS[clampi(from, 1, 5)],
		"mid_levels": maxf(LEVELS[clampi(from, 1, 5)], 4.0),
	}

func build() -> void:
	var w: int = EraManager.RESOLUTION[to_era].x
	var art_h: int = EraTitleArt.art_height(w)
	var k: int = ui_scale(w)
	_view = SubViewport.new()
	_view.size = Vector2i(w, art_h)
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_art = EraTitleArt.new()
	_art.theme = UITheme.get_theme()
	_art.era = to_era
	_art.show_logo = false
	_art.manual = true
	_art.still = reduced
	_art.size = Vector2(w, art_h)
	_view.add_child(_art)
	_pic = TextureRect.new()
	_pic.texture = _view.get_texture()
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var p: Dictionary = params(from_era, to_era)
	for key: String in p:
		mat.set_shader_parameter(key, p[key])
	var inks: Array[Color] = EraManager.INK_PALETTE
	for i: int in inks.size():
		mat.set_shader_parameter("c%d" % i, inks[i])
	_pic.material = mat
	stage.add_child(_pic)
	_caption = _label(k)
	_list = _label(k)
	_hint = _label(k)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage.resized.connect(_layout)
	_layout()
	state = EraMoments.state_at(to_era, 0.0, reduced)
	_refresh()

func _label(k: int) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", PixelFont.BASE_SIZE * k)
	l.add_theme_constant_override("line_spacing", 0)
	stage.add_child(l)
	return l

## Top of the vignette, and the panel below it.
func header_h() -> float:
	return 26.0 * ui_scale(stage.size.x)

func panel_rect() -> Rect2:
	var k: int = ui_scale(stage.size.x)
	var top: float = header_h() + _pic.size.y + 4.0 * k
	return Rect2(4.0 * k, top, stage.size.x - 8.0 * k, maxf(stage.size.y - top - 14.0 * k, 40.0 * k))

func _layout() -> void:
	var k: int = ui_scale(stage.size.x)
	var art_h: float = EraTitleArt.art_height(stage.size.x)
	# A short screen gives the picture less room so the panel keeps its lines.
	art_h = minf(art_h, stage.size.y - header_h() - 78.0 * k)
	_pic.position = Vector2(0, header_h())
	_pic.size = Vector2(stage.size.x, art_h)
	var pr: Rect2 = panel_rect()
	_caption.position = pr.position + Vector2(6, 5) * k
	_caption.size = Vector2(pr.size.x - 12.0 * k, 20.0 * k)
	_list.position = pr.position + Vector2(6.0 * k, 5.0 * k + 12.0 * k)
	_list.size = Vector2(pr.size.x - 12.0 * k, pr.size.y - 20.0 * k)
	_hint.position = Vector2(0, stage.size.y - 12.0 * k)
	_hint.size = Vector2(stage.size.x - 4.0 * k, 10.0 * k)

func step() -> void:
	if not _started:
		_started = true
		# The old era's sound first; the music step swaps it.
		Sound.apply_era_fx(int(EraMoments.music_plan(from_era, to_era).before_fx))
	state = EraMoments.state_at(to_era, t, reduced)
	if not _music_done and float(state.music) > 0.0:
		_swap_music()
	_refresh()

## The music step: the new era's bus effects and its song take over (Sound, MusicDirector).
func _swap_music() -> void:
	_music_done = true
	var plan: Dictionary = EraMoments.music_plan(from_era, to_era)
	Sound.apply_era_fx(int(plan.after_fx))
	Sound.sfx("level_up")
	Sound.music(str(plan.track))

func _refresh() -> void:
	var mat: ShaderMaterial = _pic.material
	mat.set_shader_parameter("palette_p", float(state.palette))
	mat.set_shader_parameter("detail_p", float(state.detail))
	# The new era's scene only starts to move once its detail is there.
	if not reduced and float(state.detail) > 0.0:
		_art.clock = maxf(t - float(EraMoments.timeline(to_era)[1].start), 0.0)
	# Eras I and II could only fade in steps; the plain fade of reduced motion is smooth.
	_pic.modulate.a = float(state.get("fade", 1.0)) if reduced else 1.0
	var era_text: int = to_era if float(state.frames) >= 1.0 else from_era
	var ink: Color = EraMoments.col(era_text, "ink")
	var on_list: bool = str(state.id) == "list"
	_caption.text = Loc.t(str(state.caption))
	_caption.add_theme_color_override("font_color", ink)
	_list.add_theme_color_override("font_color", ink)
	var rows: Array[String] = EraMoments.list_lines(to_era)
	var shown: int = EraMoments.list_rows_shown(to_era, float(state.list), reduced) if on_list else 0
	var text: String = ""
	for i: int in mini(shown, rows.size()):
		text += "+\u00a0%s\n" % rows[i]
	_list.text = text
	# The rows start under the caption, however many lines it wraps to (German is longer).
	_list.position.y = _caption.position.y + maxi(_caption.get_line_count(), 1) * _caption.get_line_height()
	_hint.text = EraMoments.text("continue") if bool(state.done) else EraMoments.text("skip")
	var k: int = ui_scale(stage.size.x)
	_hint.add_theme_font_size_override("font_size", PixelFont.BASE_SIZE * fit_scale(_hint.get_theme_font("font"), _hint.text, k, _hint.size.x))
	_hint.add_theme_color_override("font_color", EraMoments.col(to_era, "paper"))

func paint(ci: Control) -> void:
	var size: Vector2 = ci.size
	var k: int = ui_scale(size.x)
	ci.draw_rect(Rect2(Vector2.ZERO, size), EraMoments.col(to_era, "ink"))
	var font: Font = ci.get_theme_default_font()
	var fs: int = PixelFont.BASE_SIZE * k
	var paper: Color = EraMoments.col(to_era, "paper")
	# Header: the era that is arriving, and the line of this change.
	var head: String = EraMoments.era_label(to_era if float(state.palette) > 0.5 or reduced else from_era)
	var headline: String = Loc.t(str(EraMoments.change(to_era).get("headline", "")))
	ci.draw_string(font, Vector2(0, 3 * k + PixelFont.ASCENT * k), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, PixelFont.BASE_SIZE * fit_scale(font, head, k, size.x - 4), EraMoments.col(to_era, "sun"))
	ci.draw_string(font, Vector2(0, 14 * k + PixelFont.ASCENT * k), headline, HORIZONTAL_ALIGNMENT_CENTER, size.x, PixelFont.BASE_SIZE * fit_scale(font, headline, k, size.x - 4), paper)
	# The frame: the old era's, then the new one drawn over it from the left.
	var pr: Rect2 = panel_rect()
	EraBackdrop.draw_frame(ci, pr, from_era)
	var fp: float = float(state.frames)
	EraBackdrop.draw_frame(ci, pr, to_era, fp)
	if fp > 0.0 and fp < 1.0:
		ci.draw_rect(Rect2(pr.position.x + pr.size.x * fp, pr.position.y - 1, 2, pr.size.y + 2), Color(1, 1, 0.94))
	if str(state.id) == "music":
		_paint_voices(ci, pr, k)

## The sound step as a row of voice bars: the old chip's voices, then the new era's join.
func _paint_voices(ci: Control, pr: Rect2, k: int) -> void:
	var p: float = float(state.music)
	var n_old: int = VOICES[from_era]
	var n_new: int = VOICES[to_era]
	var n: int = n_old + int(round((n_new - n_old) * clampf(p * 1.5, 0.0, 1.0)))
	var bar_w: float = floorf((pr.size.x - 16.0 * k) / n_new)
	var base_y: float = pr.end.y - 6.0 * k
	for i: int in n:
		var h: float = (4.0 + 9.0 * absf(sin(t * (5.0 + i % 4) + i * 1.7))) * k
		if reduced:
			h = (6.0 + (i * 5) % 7) * k
		var c: Color = EraMoments.col(to_era, "accent") if i >= n_old else EraMoments.col(to_era, "ink")
		ci.draw_rect(Rect2(pr.position.x + 8.0 * k + i * bar_w, base_y - h, maxf(bar_w - 1.0, 1.0), h), c)

func press() -> void:
	var skip_to: float = EraMoments.total_time(to_era, reduced)
	if t < skip_to:
		# A skipped scene does not start the era song for a moment.
		_music_done = true
		t = skip_to
		step()
		stage.queue_redraw()
		return
	close()

func close() -> void:
	if is_closed():
		return
	# Whatever step the scene stood on, the game goes on with the active era's sound.
	Sound.apply_era_fx(EraManager.active_era())
	if GameState.in_game and not GameState.current_map.is_empty():
		Sound.enter_map(GameState.current_map)
	super.close()
