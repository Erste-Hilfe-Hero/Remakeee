class_name PixelParticles
extends Node2D
## A small particle pool drawn with draw calls (items 2393 to 2395): single pixels or 8x8
## shapes, at most MAX_PARTICLES per node, positions rounded to whole pixels when drawn.
##   var p := PixelParticles.new(); add_child(p)
##   p.emit(pos, 3, {"vel": Vector2(0, -10), "spread": 6.0, "life": 0.3, "color": UITheme.MID})
##   p.dust(feet, back_dir)

const MAX_PARTICLES: int = 64

## Live particles: {pos, vel, life, max_life, gravity, friction, color, tex}.
var particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 0x5eed
	set_process(false)

## Spawns [param count] particles at [param pos]. Options: vel (Vector2), spread (random extra
## speed per axis), life (s), gravity (px/s^2), friction (share of speed lost per second),
## color, tex (an 8x8 Texture2D drawn instead of a pixel). Extra particles over the cap are dropped.
func emit(pos: Vector2, count: int, opts: Dictionary = {}) -> void:
	var vel: Vector2 = opts.get("vel", Vector2.ZERO)
	var spread: float = float(opts.get("spread", 0.0))
	var life: float = float(opts.get("life", 0.4))
	for i: int in count:
		if particles.size() >= MAX_PARTICLES:
			break
		particles.append({
			"pos": pos,
			"vel": vel + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread)),
			"life": life, "max_life": life,
			"gravity": float(opts.get("gravity", 0.0)),
			"friction": float(opts.get("friction", 0.0)),
			"color": opts.get("color", UITheme.MID),
			"tex": opts.get("tex", null),
		})
	set_process(true)
	queue_redraw()

## Running dust: 3 grey pixels kicked back from the feet, 0.3 s (item 2395).
func dust(feet: Vector2, back: Vector2) -> void:
	emit(feet + back * 3.0, 3, {"vel": back * 14.0 + Vector2(0, -6), "spread": 5.0, "life": 0.3,
		"friction": 3.0, "color": UITheme.MID})

func clear() -> void:
	particles.clear()
	queue_redraw()

func _process(delta: float) -> void:
	step(delta)

## Advances every particle by [param delta] seconds and drops the dead ones.
func step(delta: float) -> void:
	for i: int in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life = float(p.life) - delta
		if float(p.life) <= 0.0:
			particles.remove_at(i)
			continue
		var v: Vector2 = p.vel
		v.y += float(p.gravity) * delta
		v *= maxf(0.0, 1.0 - float(p.friction) * delta)
		p.vel = v
		p.pos = (p.pos as Vector2) + v * delta
	if particles.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for p: Dictionary in particles:
		var at: Vector2 = (p.pos as Vector2).round()
		var tex: Variant = p.tex
		if tex is Texture2D:
			draw_texture(tex, at - Vector2(4, 4), p.color)
		else:
			draw_rect(Rect2(at, Vector2.ONE), p.color)
