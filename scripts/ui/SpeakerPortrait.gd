class_name SpeakerPortrait
extends Control
## Who speaks, shown with the dialogue box of the later eras (docs/ERA_FEEL_TEXT.md): Era IV
## puts a 12 px head on the name plate, Era V a 32 px portrait on the box that blinks and moves
## its mouth while the line types. Which speaker has art is data (data/era_text.json
## "speakers"); a speaker without art, and every speaker in Eras I to III, keeps the plain name
## tag. Reduced motion keeps the portrait still.

## The portrait sinks this far into the top edge of the box.
const BUST_OVERLAP: int = 2
const BUST_INSET: int = 2
const ICON_GAP: int = 2

var _box: TextBox
var _tag: Label
var _tex: Texture2D
var _mode: String = "none"
var _id: String = ""
var _time: float = 0.0
var _frame: int = 0
var _tag_pad: float = 0.0

## Adds the portrait to [param box]; it stays hidden until a speaker with art talks.
static func attach(box: TextBox) -> SpeakerPortrait:
	var p := SpeakerPortrait.new()
	p._box = box
	p.top_level = true
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(p)
	return p

## The way a box shows the speaker: the era's mode, but a box that sits inside a layout (the
## battle screen) has no room above it for a bust and shows the small head instead.
static func mode_for(era_mode: String, in_layout: bool) -> String:
	if era_mode == "bust" and in_layout:
		return "icon"
	return era_mode if era_mode in EraText.PORTRAITS else "none"

## Speaker id on show ("" when none).
func speaker_id() -> String:
	return _id if _mode != "none" else ""

func mode() -> String:
	return _mode

## Frame of the bust on show: 0 resting, 1 eyes shut, 2 speaking.
func frame() -> int:
	return _frame

## Called by the box when the speaker changes: [param who] is the name on [param tag].
func show_for(who: String, tag: Label) -> void:
	_tag = tag
	var was_icon: bool = _mode == "icon"
	var mode_now: String = mode_for(EraText.portrait_mode(EraManager.active_era()), _box.get_parent() is Container)
	var id: String = EraText.speaker_id(who) if mode_now != "none" else ""
	var path: String = EraText.art_path(id, mode_now)
	var tex: Texture2D = load(path) as Texture2D if not path.is_empty() else null
	if tex == null:
		mode_now = "none"
		id = ""
	var changed: bool = id != _id or mode_now != _mode
	_id = id
	_mode = mode_now
	_tex = tex
	if _mode == "icon":
		# The name moves right to leave room for the head on the plate.
		var sb: StyleBox = UITheme.panel_style()
		_tag_pad = sb.content_margin_left
		sb.content_margin_left += _icon_size() + ICON_GAP
		tag.add_theme_stylebox_override("normal", sb)
	elif was_icon:
		tag.add_theme_stylebox_override("normal", UITheme.panel_style())
	if _mode == "none":
		visible = false
		return
	accessibility_name = Loc.t(EraText.PORTRAIT_LABEL) % who
	if _mode == "bust":
		var m: float = UITheme.FRAME_MARGIN
		size = Vector2(_bust_size() + m * 2.0, _bust_size() + m * 2.0)
	else:
		size = Vector2(_icon_size(), _icon_size())
	if changed:
		_time = 0.0
		_frame = 0
		if _mode == "bust" and not Juice.reduced() and is_inside_tree():
			modulate.a = 0.0
			Juice.tween(self, "modulate:a", 1.0, "open")
		else:
			modulate.a = 1.0
	_place()
	queue_redraw()

func _bust_size() -> int:
	return int(EraText.portrait_value("size", 32.0))

func _icon_size() -> int:
	return int(EraText.portrait_value("icon_size", 12.0))

## Where the portrait sits for a box at [param box_rect] on a screen [param screen] high: on
## the right end of the top edge, or under the box when there is no room above.
static func bust_position(box_rect: Rect2, own: Vector2) -> Vector2:
	var x: float = box_rect.end.x - own.x - BUST_INSET
	var y: float = box_rect.position.y - own.y + BUST_OVERLAP
	if y < 0.0:
		y = box_rect.end.y - BUST_OVERLAP
	return Vector2(x, y).floor()

func _place() -> void:
	if _mode == "none" or _box == null or _tag == null:
		visible = false
		return
	var show_it: bool = _box.is_visible_in_tree() and not _tag.text.is_empty()
	if _mode == "icon":
		global_position = (_tag.global_position + Vector2(_tag_pad, (_tag.size.y - size.y) / 2.0)).floor()
		show_it = show_it and _tag.visible
	else:
		global_position = bust_position(Rect2(_box.global_position, _box.size), size)
	visible = show_it

func _process(delta: float) -> void:
	if _mode == "none":
		return
	_place()
	if _mode != "bust":
		return
	_time += delta
	var f: int = EraText.bust_frame(_time, _box.is_typing(), Juice.reduced())
	if f != _frame:
		_frame = f
		queue_redraw()

func _draw() -> void:
	if _tex == null:
		return
	if _mode == "icon":
		draw_texture(_tex, Vector2.ZERO)
		return
	draw_style_box(UITheme.panel_style(), Rect2(Vector2.ZERO, size))
	var s: int = _bust_size()
	var frames: int = maxi(1, _tex.get_width() / s)
	var m: float = UITheme.FRAME_MARGIN
	draw_texture_rect_region(_tex, Rect2(m, m, s, s), Rect2(mini(_frame, frames - 1) * s, 0, s, s))
