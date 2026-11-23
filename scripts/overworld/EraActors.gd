class_name EraActors
extends Node2D
## The live part of the era look of overworld figures (EraActorLook, data/era_actor_look.json).
## One node in the overworld, after the figures in the tree, so it runs after them each frame:
##   - redraws a figure when its pose changes, steps it in the era's pixel jumps
##   - draws the emote bubbles over the figures (Era II on; Era I keeps its ink box)
##   - turns villagers' heads to the Wayfarer (Era IV on) and lets them react (Era V)
## Reduced motion: no pop, no bounce, no hop, no breathing; bubbles and head turns still show.

## The node of the overworld on screen; null outside it.
static var current: EraActors

## Parent of the figures (the overworld's y-sorted node).
var entities: Node2D
var player: GridWalker
## Returns true when it is night / raining on this map (set by the overworld; tests set their own).
var is_night: Callable = func() -> bool: return false
var is_rain: Callable = func() -> bool: return false

## Bubbles on screen: {"node": Node2D, "kind": String, "age": float, "time": float, "hold": bool}.
var bubbles: Array[Dictionary] = []
var _near_after: int = 0

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

func _ready() -> void:
	EraManager.era_changed.connect(_on_era_changed)

func _on_era_changed(_era: int) -> void:
	bubbles.clear()
	if entities != null:
		for c: Node in entities.get_children():
			if c is GridWalker:
				c.era_anim.erase("key")
				c.queue_redraw()
	queue_redraw()

# --- Bubbles ------------------------------------------------------------------------------

## Shows bubble [param kind] (a kind or a scene icon) over [param node] for [param time] seconds.
## False when the era draws its emotes the old way (Era I) or has not got the kind.
func show_bubble(node: Node2D, kind: String, time: float = -1.0, hold: bool = false) -> bool:
	var k: String = EraActorLook.emote_kind(kind)
	if node == null or EraActorLook.plain_emotes() or not k in (EraActorLook.value("emotes") as Array):
		return false
	for b: Dictionary in bubbles:
		if b.node == node:
			bubbles.erase(b)
			break
	bubbles.append({"node": node, "kind": k, "age": 0.0, "hold": hold,
		"time": time if time > 0.0 else EraActorLook.num("emote_time", 0.7)})
	queue_redraw()
	return true

## Shows the bubble the era gives for [param trigger] (talk, near ...) over [param node].
func react(node: Node2D, trigger: String, time: float = -1.0) -> bool:
	var kind: String = EraActorLook.emote_for(trigger)
	return not kind.is_empty() and show_bubble(node, kind, time)

## For callers that only have the class: the same on the overworld's node, false without one.
static func react_on(node: Node2D, trigger: String) -> bool:
	return current != null and current.react(node, trigger)

static func bubble_on(node: Node2D, icon: String, time: float) -> bool:
	return current != null and current.show_bubble(node, icon, time)

func bubble_of(node: Node2D) -> String:
	for b: Dictionary in bubbles:
		if b.node == node:
			return str(b.kind)
	return ""

func _tick_bubbles(delta: float) -> void:
	if bubbles.is_empty():
		return
	for i: int in range(bubbles.size() - 1, -1, -1):
		var b: Dictionary = bubbles[i]
		b.age = float(b.age) + delta
		var gone: bool = not is_instance_valid(b.node)
		if not gone and bool(b.hold):
			gone = not (b.node is NPC and (b.node as NPC).alert)
		elif not gone:
			gone = float(b.age) >= float(b.time)
		if gone:
			bubbles.remove_at(i)
	queue_redraw()

## Where a bubble is drawn and which frame, for [param b] in era row [param r].
func bubble_place(b: Dictionary, r: Dictionary, reduced: bool) -> Dictionary:
	var lift: int = int((r.get("frame", [16, 16]) as Array)[1]) - GridWalker.TILE
	var at: Vector2 = (b.node as Node2D).position + Vector2(0, -lift - 13)
	var frame: int = 0
	if not reduced:
		if bool(r.get("emote_pop", false)) and float(b.age) < EraActorLook.num("emote_pop_time", 0.08):
			at.y += 2
		var frames: int = int(r.get("emote_frames", 1))
		if frames > 1:
			frame = int(float(b.age) * EraActorLook.num("emote_fps", 4.0)) % frames
			at.y -= frame
	return {"at": at, "frame": frame}

func _draw() -> void:
	if bubbles.is_empty():
		return
	var era: int = EraManager.active_era()
	var tex: Texture2D = EraActorLook.emote_sheet(era)
	if tex == null:
		return
	var r: Dictionary = EraActorLook.row(era)
	var kinds: Array = EraActorLook.data().get("emote_kinds", [])
	for b: Dictionary in bubbles:
		if not is_instance_valid(b.node):
			continue
		var p: Dictionary = bubble_place(b, r, Juice.reduced())
		draw_texture_rect_region(tex, Rect2(p.at, Vector2(16, 16)), Rect2(kinds.find(b.kind) * 16, int(p.frame) * 16, 16, 16))

# --- Figures ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var r: Dictionary = EraActorLook.row()
	if entities != null:
		var own: bool = EraActorLook.own_sheets()
		var px: int = maxi(1, int(r.get("step_px", 1)))
		for c: Node in entities.get_children():
			if c is GridWalker:
				_tick_walker(c, r, own, px)
	_tick_bubbles(delta)

func _tick_walker(w: GridWalker, r: Dictionary, own: bool, px: int) -> void:
	if px > 1 and w.moving:
		w.position = snap(w.position, px)
	if w is NPC:
		_tick_npc(w, r)
	elif w is Player:
		_player_material(w, own)
	if not own:
		return
	if not w.era_anim.has("seed"):
		w.era_anim["seed"] = absi(hash(w.get_instance_id())) % 4000
	var last: String = str(w.era_anim.get("face", w.facing))
	if last != w.facing:
		if EraActorLook.OPPOSITE[last] != w.facing:
			w.era_anim["turn_from"] = last
			w.era_anim["turn_until"] = Time.get_ticks_msec() + int(EraActorLook.num("turn_blend_ms", 70.0))
	w.era_anim["face"] = w.facing
	var p: Dictionary = EraActorLook.pose_of(w, r)
	var key: String = "%s/%s" % [p.row, p.col]
	if key != str(w.era_anim.get("key", "")):
		w.era_anim["key"] = key
		w.queue_redraw()

## The Wayfarer's look shader repaints the four-ink sheet. The era's own sheets are repainted when
## they load (EraActorLook.player_sheet), so the shader rests while they are in use.
func _player_material(w: GridWalker, own: bool) -> void:
	if own and w.material != null:
		w.era_anim["material"] = w.material
		w.material = null
		w.queue_redraw()
	elif not own and w.material == null and w.era_anim.get("material") != null:
		w.material = w.era_anim["material"]
		w.queue_redraw()

## [param pos] moved down to the era's pixel jump (2 px in Eras I and II).
static func snap(pos: Vector2, px: int) -> Vector2:
	return (pos / float(px)).floor() * float(px)

func _tick_npc(n: NPC, r: Dictionary) -> void:
	if n.alert and bubble_of(n) != EraActorLook.emote_for("spot"):
		show_bubble(n, EraActorLook.emote_for("spot"), -1.0, true)
	if player == null or not bool(r.get("head_turn", false)) or not n.may_glance() or n.moving:
		return
	var d: Vector2i = player.cell - n.cell
	var near: bool = maxi(absi(d.x), absi(d.y)) <= int(r.get("head_turn_radius", 0)) and d != Vector2i.ZERO
	var was: bool = bool(n.era_anim.get("watching", false))
	if near:
		var dir: String = look_dir(d)
		var want: String = "" if dir == n.facing else dir
		if n.look != want:
			n.look = want
		if not was:
			_noticed(n)
	elif was:
		n.look = ""
	n.era_anim["watching"] = near

## Direction name from a figure toward an offset [param d] in cells.
static func look_dir(d: Vector2i) -> String:
	if absi(d.x) > absi(d.y):
		return "right" if d.x > 0 else "left"
	return "down" if d.y > 0 else "up"

## A villager has just noticed the Wayfarer (Era V): a bubble by the hour and the weather, at most
## once per cooldown.
func _noticed(n: NPC) -> void:
	var now: int = Time.get_ticks_msec()
	if now < int(n.era_anim.get("near_after", 0)) or now < _near_after or n.alert:
		return
	var kind: String = near_trigger(is_night.call(), is_rain.call())
	if react(n, kind, EraActorLook.num("near_emote_time", 1.4)):
		n.era_anim["near_after"] = now + int(EraActorLook.num("near_emote_cooldown", 40.0) * 1000.0)
		# One villager at a time: a full square does not answer all at once.
		_near_after = now + int(EraActorLook.num("near_emote_gap", 6.0) * 1000.0)

static func near_trigger(night: bool, rain: bool) -> String:
	return "near_rain" if rain else ("near_night" if night else "near")
