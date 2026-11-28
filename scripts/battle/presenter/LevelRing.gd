class_name LevelRing
extends Node2D
## Ring rise (item 2333): a ring of single pixels grows from 8 to 40 px across around a
## Spirling in 0.4 s and fades out, then frees itself. Under reduced motion it is not shown.

const FROM_SIZE: float = 8.0
const TO_SIZE: float = 40.0
const TIME: float = 0.4

## Current diameter in pixels.
var diameter: float = FROM_SIZE
## The running grow-and-fade tween.
var tween: Tween

## Pixel offsets of a ring with [param d] pixels across, one per whole pixel of its rim.
static func ring_pixels(d: float) -> Array[Vector2i]:
	var r: float = d / 2.0
	var out: Array[Vector2i] = []
	var steps: int = maxi(8, int(ceil(PI * d)))
	for i: int in steps:
		var a: float = TAU * i / steps
		var p := Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
		if not out.has(p):
			out.append(p)
	return out

## Starts the ring at [param center] under [param parent]. Returns null under reduced motion.
static func spawn(parent: Node, center: Vector2) -> LevelRing:
	if Juice.reduced() or parent == null:
		return null
	var ring := LevelRing.new()
	ring.position = center.round()
	parent.add_child(ring)
	ring._run()
	return ring

func _run() -> void:
	tween = create_tween().set_parallel(true)
	Juice.shaped(tween.tween_method(_set_diameter, FROM_SIZE, TO_SIZE, TIME / Juice.speed()), "move")
	Juice.shaped(tween.tween_property(self, "modulate:a", 0.0, TIME / Juice.speed()), "fade")
	await tween.finished
	queue_free()

func _set_diameter(d: float) -> void:
	diameter = d
	queue_redraw()

func _draw() -> void:
	for p: Vector2i in ring_pixels(roundf(diameter)):
		draw_rect(Rect2(Vector2(p), Vector2.ONE), UITheme.ACCENT)
