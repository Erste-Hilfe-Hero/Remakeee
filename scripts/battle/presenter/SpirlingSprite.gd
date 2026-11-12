class_name SpirlingSprite
extends Control
## Battle sprite. Uses the era sprite if one exists, otherwise a coloured placeholder
## rectangle (element colours, initial letter) as AGENTS.md asks until real art exists.

const STEP_OUT_DISTANCE: float = 40.0
const STEP_TIME: float = 0.3
const HIT_FLASHES: int = 3
const KNOCKBACK_PX: float = 3.0
const HOPS: float = 2.0
const HOP_HEIGHT: float = 4.0
const MOTION_PATH: String = "res://data/spirling_motion.json"
const MOTIONS: Array[String] = ["hop", "creep", "sway", "stomp", "slide"]
static var _motion: Dictionary = {}
## Prism variants are drawn with a warm tint over the era palette.
const PRISM_TINT: Color = Color(1.0, 0.78, 0.5)
## Gleam form: drawn through GleamRules.material() (the species' own palette). This tint is only
## for the placeholder rectangle when no sprite exists.
const GLEAM_TINT: Color = Color(0.72, 0.92, 1.0)
## Idle bob: 1 px up for half of each period (item 2335).
const BOB_PERIOD: float = 1.0
## Under a quarter of its strength a Spirling sits 1 px lower and bobs at half the pace.
const LOW_HP_SHARE: float = 0.25
const LOW_BOB_PERIOD: float = 2.0
const LOW_SAG_PX: float = 1.0
## Sidestep on a missed art: 4 px aside and back in 0.2 s (item 2337).
const DODGE_PX: float = 4.0
const DODGE_TIME: float = 0.2

var spirling: Spirling
var facing: String = "front"
## Draws the sprite flipped horizontally (art faces left; the battle layout needs it facing right).
var mirrored: bool = false
var speed_scale: float = 1.0
var _texture: Texture2D
var _home: Vector2
var _bob_time: float = 0.0
## Drawn offset of the idle bob and the low-strength sag; never moves the node itself.
var draw_offset: Vector2 = Vector2.ZERO
## Era V: the strip playing ("idle", "attack" or "hit") and its clock; strips are empty below Era V.
var anim_kind: String = "idle"
var _anim_time: float = 0.0
var _strips: Dictionary = {}
## Era IV: the "_b" breath frame (tools/art/gen_era4.py), swapped in for the second half of each
## bob instead of the 1 px lift; null when the sprite has none.
var _breath: Texture2D
## Era feel (data/era_battle_feel.json): drawn scale around the feet (pop-in growth, landing
## squash, Era IV breathing, collapse) and the white silhouette share drawn over the sprite
## (Era III/IV hit flash, Era III entrance). Neither moves the node.
var draw_scale: Vector2 = Vector2.ONE
var flash_amount: float = 0.0
## Dust puffs at the feet (Era IV/V landings and faints): 0 = none, rises to 1 and clears.
var dust: float = -1.0
var _silhouette: Texture2D
static var _sil_cache: Dictionary = {}
const DUST_TIME: float = 0.3
## Squash on landing (Era IV/V) and the pop-in steps (Era I).
const LAND_SQUASH: float = 0.86
const POP_STEPS: Array[float] = [0.34, 0.67, 1.0]
const POP_STEP_TIME: float = 0.07

func setup(s: Spirling, p_facing: String) -> void:
	spirling = s
	facing = p_facing
	accessibility_name = s.display_name()
	_texture = null
	var path: String = EraManager.sprite_path(s.data.species_name, facing)
	if not path.is_empty():
		_texture = load(path)
	# Looked up per setup, so an unfurled Gleam takes its new species' palette.
	material = GleamRules.material(s.data.species_name) if s.gleam and _texture != null else null
	_strips.clear()
	_breath = null
	var bp: String = breath_path(path)
	if _texture != null and ResourceLoader.exists(bp):
		_breath = load(bp)
	if _texture != null and BattleAnim.enabled():
		for k: String in BattleAnim.KINDS:
			var st: Texture2D = BattleAnim.strip_texture(path, k)
			if st != null:
				_strips[k] = st
	anim_kind = "idle"
	_anim_time = 0.0
	modulate.a = 1.0
	draw_scale = Vector2.ONE
	flash_amount = 0.0
	dust = -1.0
	_silhouette = silhouette_texture(path) if _texture != null else null
	queue_redraw()

## The era whose battle feel applies (the battle's own era, not the species' art era).
static func feel_era() -> int:
	return EraManager.active_era()

## White silhouette of the sprite at [param path] (cached), for hit flashes.
static func silhouette_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _sil_cache.has(path):
		return _sil_cache[path]
	var tex: Texture2D = load(path)
	var img: Image = tex.get_image() if tex != null else null
	var out: Texture2D = null
	if img != null:
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var col: Color = Color(str(BattleAnim.config().get("flash_color", "f8f4ec")))
		for y: int in img.get_height():
			for x: int in img.get_width():
				var a: float = img.get_pixel(x, y).a
				if a > 0.0:
					img.set_pixel(x, y, Color(col, a))
		out = ImageTexture.create_from_image(img)
	_sil_cache[path] = out
	return out

## Breath frame path next to an era sprite path ("x_front.png" -> "x_front_b.png").
static func breath_path(path: String) -> String:
	return path.get_basename() + "_b.png" if path.begins_with("res://art/era4/") else ""

## True while the breath frame is shown: the lifted half of the idle bob.
func breathing() -> bool:
	return _breath != null and draw_offset.y < (LOW_SAG_PX if is_weak(spirling) else 0.0)

## The era sprite in use, or null while the placeholder rectangle is drawn.
func texture() -> Texture2D:
	return _texture

func _ready() -> void:
	_home = position

func _process(delta: float) -> void:
	if spirling == null or not visible:
		return
	_bob_time += delta
	if not _strips.is_empty():
		var before: int = BattleAnim.frame_at(anim_kind, _anim_time)
		_anim_time += delta * Juice.speed() if not Juice.reduced() else 0.0
		if BattleAnim.frame_at(anim_kind, _anim_time) != before:
			queue_redraw()
		return
	# Era I-III Spirlings stand still between moves (only the low-strength sag shows); the bob
	# and breath start with Era IV, the constant loop is Era V's strip above.
	var era: int = feel_era()
	var o: Vector2 = idle_offset(spirling, _bob_time, Juice.reduced() or not EraBattleFeel.idles(era))
	if o != draw_offset:
		draw_offset = o
		queue_redraw()
	if _breath == null and EraBattleFeel.idles(era) and not Juice.reduced() and dust < 0.0 and flash_amount <= 0.0:
		var b: Vector2 = breath_scale(_bob_time, EraBattleFeel.num(era, "breath_period", 1.6), EraBattleFeel.num(era, "breath_squash", 0.0))
		if b != draw_scale:
			draw_scale = b
			queue_redraw()

## Era IV breathing without a breath frame: the sprite widens a little and settles, in two
## whole steps per period, so pixels stay crisp.
static func breath_scale(t: float, period: float, squash: float) -> Vector2:
	if squash <= 0.0 or period <= 0.0:
		return Vector2.ONE
	return Vector2(1.0 + squash, 1.0 - squash) if fmod(t, period) >= period * 0.5 else Vector2.ONE

## True under a quarter of the Spirling's strength (but not fainted).
static func is_weak(s: Spirling) -> bool:
	return s != null and s.hp > 0 and s.hp < s.max_hp() * LOW_HP_SHARE

## Idle drawing offset at time t: weak Spirlings sag 1 px and bob at half the pace; under
## reduced motion only the sag stays.
static func idle_offset(s: Spirling, t: float, reduced: bool) -> Vector2:
	var weak: bool = is_weak(s)
	var y: float = LOW_SAG_PX if weak else 0.0
	if not reduced and s != null and s.hp > 0:
		var period: float = LOW_BOB_PERIOD if weak else BOB_PERIOD
		if fmod(t, period) >= period * 0.5:
			y -= 1.0
	return Vector2(0, y)

## A newly bonded Spirling hops 4 px once before its name shows (item 2344). Skipped
## under reduced motion. Awaitable.
const GREET_HOP_PX: float = 4.0
const GREET_HOP_TIME: float = 0.2

func greet_hop() -> void:
	if Juice.reduced():
		return
	await Juice.tween(self, "position", _home + Vector2(0, -GREET_HOP_PX), "move", GREET_HOP_TIME * 0.45).finished
	await Juice.tween(self, "position", _home, "impact", GREET_HOP_TIME * 0.55).finished

## Where a sidestep in `dir` (sign of x; 0 counts as right) lands.
static func dodge_spot(home: Vector2, dir: float) -> Vector2:
	return home + Vector2(-DODGE_PX if dir < 0.0 else DODGE_PX, 0)

## Sidesteps a missed art: 4 px in `dir` (sign of x) and back in 0.2 s. Skipped under
## reduced motion. Awaitable.
func dodge(dir: float) -> void:
	if Juice.reduced():
		return
	await Juice.tween(self, "position", dodge_spot(_home, dir), "move", DODGE_TIME * 0.4).finished
	await Juice.tween(self, "position", _home, "move", DODGE_TIME * 0.6).finished

## Steps out beside the Wayfarer (slides in from the screen edge; never thrown). Awaitable.
## Durations come from Juice curves, so the 2x / 4x battle speed applies on its own.
## The way the Spirling moves follows its motion profile (item 2330).
func step_out(from_left: bool) -> void:
	var style: String = EraBattleFeel.text(feel_era(), "entrance", "bounce")
	if style == "pop" and not Juice.reduced():
		await _pop_in()
		return
	await _slide_in(from_left)
	if Juice.reduced():
		return
	match style:
		"bounce":
			await greet_hop()
		"burst":
			await _fade_flash(0.25)
		"land", "live":
			await land()

## Era I: appears where it stands in three growing steps, no slide.
func _pop_in() -> void:
	_home = position
	modulate.a = 1.0
	visible = true
	for k: float in POP_STEPS:
		draw_scale = Vector2(k, k)
		queue_redraw()
		await get_tree().create_timer(POP_STEP_TIME / Juice.speed()).timeout
	draw_scale = Vector2.ONE
	queue_redraw()

## Era III: the sprite shows as a white silhouette that fades into its colours.
func _fade_flash(time: float) -> void:
	flash_amount = 1.0
	queue_redraw()
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		flash_amount = v
		queue_redraw(), 1.0, 0.0, time / Juice.speed()).set_trans(Tween.TRANS_SINE)
	await tw.finished
	flash_amount = 0.0

## Era IV/V: squashes on landing and kicks up a puff of dust.
func land() -> void:
	if Juice.reduced():
		return
	draw_scale = Vector2(2.0 - LAND_SQUASH, LAND_SQUASH)
	queue_redraw()
	_puff()
	await get_tree().create_timer(0.08 / Juice.speed()).timeout
	draw_scale = Vector2.ONE
	queue_redraw()

func _puff() -> void:
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		dust = v
		queue_redraw(), 0.0, 1.0, DUST_TIME / Juice.speed()).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		dust = -1.0
		queue_redraw())

func _slide_in(from_left: bool) -> void:
	_home = position
	position = _home + Vector2(-STEP_OUT_DISTANCE if from_left else STEP_OUT_DISTANCE, 0)
	modulate.a = 0.0
	visible = true
	Juice.tween(self, "modulate:a", 1.0, "move", STEP_TIME)
	var m: String = motion_of(spirling.data.species_name, spirling.elements()) if spirling != null else "slide"
	if Juice.reduced():
		m = "slide"
	match m:
		"hop":
			# Two hops of 4 px each on the way in.
			var start: Vector2 = position
			var hop := func(k: float) -> void:
				var arc: float = absf(sin(k * PI * HOPS))
				position = (start.lerp(_home, k) + Vector2(0, -HOP_HEIGHT * arc)).round()
			var tw: Tween = create_tween()
			Juice.shaped(tw.tween_method(hop, 0.0, 1.0, STEP_TIME / Juice.speed()), "move")
			await tw.finished
			position = _home
		"stomp":
			await Juice.tween(self, "position", _home, "impact", STEP_TIME).finished
			Juice.add_trauma(0.1)
		"creep":
			await Juice.tween(self, "position", _home, "move", STEP_TIME * 1.3).finished
		"sway":
			var start2: Vector2 = position
			var sway := func(k: float) -> void:
				position = (start2.lerp(_home, k) + Vector2(0, -sin(k * PI * 3.0))).round()
			var tw2: Tween = create_tween()
			tw2.tween_method(sway, 0.0, 1.0, STEP_TIME / Juice.speed()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await tw2.finished
			position = _home
		_:
			await Juice.tween(self, "position", _home, "move", STEP_TIME).finished

## Motion profile for [param species]: data/spirling_motion.json, else by first element.
static func motion_of(species: String, elements: Array[int]) -> String:
	if _motion.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOTION_PATH)) if FileAccess.file_exists(MOTION_PATH) else null
		_motion = raw if raw is Dictionary else {"species": {}, "by_element": {}}
	var sp: Dictionary = _motion.get("species", {})
	if sp.has(species):
		return str(sp[species])
	if not elements.is_empty():
		return str((_motion.get("by_element", {}) as Dictionary).get(Elements.E.keys()[elements[0]], "slide"))
	return "slide"

## Wind-up before an art (item 2331): physical arts pull back 3 px and snap forward, focus arts
## rise 2 px and drop as they fire, status arts bob twice.
func windup(kind: int, toward: Vector2) -> void:
	if Juice.reduced():
		return
	match kind:
		MoveData.Kind.PHYSICAL:
			await Juice.tween(self, "position", _home - (toward.normalized() * 3.0).round(), "move", 0.08).finished
			await lunge(toward)
		MoveData.Kind.FOCUS:
			await Juice.tween(self, "position", _home + Vector2(0, -2), "move", 0.1).finished
			await Juice.tween(self, "position", _home, "impact", 0.06).finished
		_:
			for i: int in 2:
				await Juice.tween(self, "position", _home + Vector2(0, -1), "impact", 0.05).finished
				await Juice.tween(self, "position", _home, "move", 0.05).finished

func step_back(to_left: bool) -> void:
	Juice.tween(self, "modulate:a", 0.0, "move", STEP_TIME)
	await Juice.tween(self, "position", _home + Vector2(-STEP_OUT_DISTANCE if to_left else STEP_OUT_DISTANCE, 0), "move", STEP_TIME).finished
	position = _home

## Era V: plays a one-shot strip and returns to idle. Awaitable.
func play_strip(kind: String) -> void:
	anim_kind = kind
	_anim_time = 0.0
	queue_redraw()
	await get_tree().create_timer(BattleAnim.frame_count(kind) / BattleAnim.fps(kind) / Juice.speed()).timeout
	anim_kind = "idle"
	_anim_time = 0.0
	queue_redraw()

func lunge(toward: Vector2) -> void:
	if Juice.reduced():
		return
	if _strips.has("attack"):
		await play_strip("attack")
		return
	await Juice.tween(self, "position", _home + toward, "impact", 0.08).finished
	await Juice.tween(self, "position", _home, "move", 0.12).finished

## Pushed 3 px away from the attacker, springs back in 0.15 s (item 2332). Under reduced
## motion only a 1 px jolt (item 2258).
func knockback(away: Vector2) -> void:
	var d: Vector2 = away.normalized()
	if Juice.reduced():
		position = _home + d.round()
		await get_tree().create_timer(0.05).timeout
		position = _home
		return
	await Juice.tween(self, "position", _home + (d * KNOCKBACK_PX).round(), "impact").finished
	await Juice.tween(self, "position", _home, "move", 0.15).finished

func hit_flash() -> void:
	if _strips.has("hit") and not Juice.reduced():
		await play_strip("hit")
		return
	if Juice.reduced():
		# One soft dim instead of blinking (no flashes).
		modulate.a = 0.6
		await get_tree().create_timer(0.12 / Juice.speed()).timeout
		modulate.a = 1.0
		return
	# Era III/IV: a white silhouette pulses instead of the old blink.
	var sil: bool = EraBattleFeel.silhouette_hit(feel_era())
	for i: int in HIT_FLASHES:
		if sil:
			flash_amount = 1.0
			queue_redraw()
		else:
			visible = false
		await get_tree().create_timer(0.05 / Juice.speed()).timeout
		flash_amount = 0.0
		queue_redraw()
		visible = true
		await get_tree().create_timer(0.05 / Juice.speed()).timeout

## Gleam entrance: glints burst from the sprite and fade (count and time in data/gleam.json).
func gleam_sparkle() -> void:
	var cfg: Dictionary = GleamRules.config()
	var n: int = int(cfg.get("sparkles", 6))
	var t: float = float(cfg.get("sparkle_time", 0.6))
	var tex: Texture2D = ElementFx.shape("glint", 0)
	if tex == null or n <= 0:
		return
	var last: Tween = null
	for i: int in n:
		var g := TextureRect.new()
		g.texture = tex
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.use_parent_material = false
		var c: Vector2 = size / 2.0 - tex.get_size() / 2.0
		g.position = c
		add_child(g)
		var a: float = TAU * i / n
		last = Juice.tween(g, "position", c + Vector2(cos(a), sin(a)) * size.x * 0.45, "move", t)
		Juice.tween(g, "modulate:a", 0.0, "move", t)
	if last != null:
		await last.finished
	for ch: Node in get_children():
		if ch is TextureRect:
			ch.queue_free()

## Faints in the era's way: Era I/II drop out of sight in four hard steps, Era III sinks and
## fades, Era IV adds a puff of dust, Era V folds flat as it fades.
func faint() -> void:
	var style: String = EraBattleFeel.text(feel_era(), "faint", "sink")
	if Juice.reduced():
		style = "sink"
	match style:
		"drop":
			for i: int in range(1, 5):
				position = _home + Vector2(0, roundf(size.y * 0.15 * i))
				modulate.a = 1.0 - i * 0.25
				await get_tree().create_timer(0.07 / Juice.speed()).timeout
		"collapse":
			_puff()
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_method(func(v: float) -> void:
				draw_scale = Vector2(1.0 + (1.0 - v) * 0.2, v)
				queue_redraw(), 1.0, 0.15, 0.4 / Juice.speed()).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "modulate:a", 0.0, 0.4 / Juice.speed()).set_trans(Tween.TRANS_SINE)
			await tw.finished
		_:
			if style == "sink_dust":
				_puff()
			Juice.tween(self, "modulate:a", 0.0, "move", 0.4)
			await Juice.tween(self, "position", _home + Vector2(0, 12), "move", 0.4).finished
	visible = false
	position = _home
	draw_scale = Vector2.ONE
	dust = -1.0

## Era I: a bonded Spirling blinks three times and is gone.
func blink_out() -> void:
	if Juice.reduced():
		return
	for i: int in 3:
		visible = false
		await get_tree().create_timer(0.08 / Juice.speed()).timeout
		visible = true
		await get_tree().create_timer(0.08 / Juice.speed()).timeout

## Glints burst from the sprite and fade ([param n] of them), for level-ups and bonds from Era III.
func glints(n: int, t: float = 0.5) -> void:
	var tex: Texture2D = ElementFx.shape("glint", 0)
	if tex == null or n <= 0 or Juice.reduced():
		return
	var last: Tween = null
	var made: Array[TextureRect] = []
	for i: int in n:
		var g := TextureRect.new()
		g.texture = tex
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.use_parent_material = false
		var c: Vector2 = size / 2.0 - tex.get_size() / 2.0
		g.position = c
		add_child(g)
		made.append(g)
		var a: float = TAU * i / n + 0.4
		last = Juice.tween(g, "position", c + Vector2(cos(a), sin(a)) * size.x * 0.55, "move", t)
		Juice.tween(g, "modulate:a", 0.0, "move", t)
	if last != null:
		await last.finished
	for g: TextureRect in made:
		if is_instance_valid(g):
			g.queue_free()

## Drawing transform: [param off] lift, [member draw_scale] around the feet, then the mirror.
func _xform(off: Vector2, mirror: bool = true) -> Transform2D:
	var foot := Vector2(size.x / 2.0, size.y)
	var xf := Transform2D(0.0, off + foot) * Transform2D(0.0, draw_scale, 0.0, Vector2.ZERO) * Transform2D(0.0, -foot)
	if mirror and mirrored:
		xf = xf * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(size.x, 0))
	return xf

## Era III+: a flat shadow under the feet, dithered so it stays in the pixel style.
func _draw_shadow() -> void:
	if not EraBattleFeel.flag(feel_era(), "shadow") or _texture == null or modulate.a < 0.5:
		return
	var w: int = int(size.x * 0.6 * draw_scale.x)
	var x0: int = int((size.x - w) / 2.0)
	var y0: int = int(size.y) - 2
	var c := Color(UITheme.INK, 0.35)
	for row: int in 3:
		var inset: int = [w / 6, 0, w / 6][row]
		draw_rect(Rect2(x0 + inset, y0 + row - 1, w - inset * 2, 1), c)

func _draw_dust() -> void:
	if dust < 0.0:
		return
	var c := Color(UITheme.ACCENT, 1.0 - dust)
	for side: int in [-1, 1]:
		for i: int in 3:
			var p := Vector2(size.x / 2.0 + side * (size.x * 0.3 + dust * 8.0 + i * 3.0), size.y - 2.0 - dust * (3.0 + i * 2.0))
			draw_rect(Rect2(p.round(), Vector2(2, 2)), c)

func _draw() -> void:
	if spirling == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	_draw_shadow()
	_draw_dust()
	var tint: Color = PRISM_TINT if spirling.prism and material == null else Color.WHITE
	if _strips.has(anim_kind):
		var st: Texture2D = _strips[anim_kind]
		var fw: float = st.get_width() / float(BattleAnim.frame_count(anim_kind))
		var src := Rect2(fw * BattleAnim.frame_at(anim_kind, _anim_time), 0, fw, st.get_height())
		draw_set_transform_matrix(_xform(Vector2.ZERO))
		draw_texture_rect_region(st, r, src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if _texture != null:
		var tex: Texture2D = _breath if breathing() else _texture
		# With a breath frame the frame swap replaces the lift; only the low-strength sag stays.
		var off: Vector2 = Vector2(0, LOW_SAG_PX if is_weak(spirling) else 0.0) if _breath != null else draw_offset
		draw_set_transform_matrix(_xform(off))
		draw_texture_rect(tex, r, false, tint)
		if flash_amount > 0.0 and _silhouette != null:
			draw_texture_rect(_silhouette, r, false, Color(1, 1, 1, flash_amount))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform_matrix(_xform(draw_offset, false))
	var els: Array[int] = spirling.elements()
	draw_rect(r, Elements.color(els[0]))
	if els.size() > 1:
		# Second element as a lower band.
		draw_rect(Rect2(0, size.y * 0.66, size.x, size.y * 0.34), Elements.color(els[1]))
	draw_rect(r, UITheme.INK, false, 1.0)
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size() * 2
	draw_string(font, Vector2(0, size.y / 2 + fs / 3.0), spirling.data.species_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, UITheme.INK)
	# Back sprites get a small notch so the two sides read differently.
	if facing == "back":
		draw_rect(Rect2(0 if mirrored else size.x - 8, 0, 8, 8), UITheme.BG)
