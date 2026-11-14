class_name KeepsakePop
extends TextureRect
## The keepsake's icon popping up over its holder when it works (KAMPF_PLAN_1000 318): it grows
## in, rises a little and fades (data/keepsake_kit.json "pop"). Under reduced motion it only
## shows for a moment and fades, without moving.

## Shows [param tex] centred above [param at] under [param parent].
static func spawn(parent: Node, tex: Texture2D, at: Vector2) -> KeepsakePop:
	if parent == null or tex == null:
		return null
	var m: Dictionary = KeepsakeKit.pop_motion(Juice.reduced())
	var p := KeepsakePop.new()
	p.texture = tex
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_SCALE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(tex.get_width(), tex.get_height()) * int(m.scale)
	p.position = (at - Vector2(p.size.x / 2.0, p.size.y + 2.0)).round()
	p.pivot_offset = p.size / 2.0
	parent.add_child(p)
	p._run(m)
	return p

func _run(m: Dictionary) -> void:
	var speed: float = Juice.speed()
	var time: float = float(m.time) / speed
	var hold: float = float(m.hold) / speed
	var t: Tween = create_tween().set_parallel(true)
	if float(m.grow) > 1.0:
		scale = Vector2.ONE * float(m.grow)
		Juice.shaped(t.tween_property(self, "scale", Vector2.ONE, time * 0.4), "open")
	if float(m.rise) > 0.0:
		Juice.shaped(t.tween_property(self, "position:y", position.y - float(m.rise), time), "fade")
	Juice.shaped(t.tween_property(self, "modulate:a", 0.0, maxf(time - hold, 0.05)), "fade").set_delay(hold)
	t.chain().tween_callback(queue_free)
