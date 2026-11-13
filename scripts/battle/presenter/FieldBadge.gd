class_name FieldBadge
extends Control
## The Rift field badge (docs/KAMPF_PLAN_1000.md, items 322, 334, 350): a small paper tag with the
## boosted element's symbol, the field's name and the turns it has left, plus the soft field tint
## over the backdrop (items 331, 353) and the battle song's pitch (item 332). It follows the field
## events as they play and syncs with the model after each turn. Where the room is too narrow
## (Era I/II formations) it folds to the symbol and the turns; a screen reader always gets the
## whole line. Under reduced motion the tag never flashes.

const HEIGHT: float = 11.0
const PAD: float = 2.0
const FLASH_TIME: float = 0.4

var field: String = ""
var turns: int = 0
## True while only the symbol and the turns fit.
var compact: bool = false
## The ColorRect over the backdrop (BattleScene puts it under the sprites).
var tint_rect: ColorRect
var era: int = 1
var _label: Label
var _flash: float = 0.0
var _max_width: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", UITheme.INK)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	tint_rect = ColorRect.new()
	tint_rect.name = "field_tint"
	tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint_rect.color = Color(0, 0, 0, 0)

## Shows [param id] with [param left] turns (0 = for the whole battle); "" hides the badge.
func show_field(id: String, left: int) -> void:
	var fresh: bool = id != field
	field = id if BattleRules.FIELDS.has(id) else ""
	turns = maxi(left, 0)
	accessibility_name = RiftFields.spoken(field, turns)
	tooltip_text = accessibility_name
	visible = not field.is_empty()
	_fit()
	if tint_rect != null:
		tint_rect.color = RiftFields.tint(field, era)
	if fresh:
		Sound.music_pitch(RiftFields.music_pitch(field))
		if not field.is_empty():
			RiftFields.note_seen(GameState.records, field)
			_flash = 0.0 if Juice.reduced() else FLASH_TIME

## The element the field boosts (its symbol on the badge), -1 without a field.
func element() -> int:
	return int(Elements.E.get(str(BattleRules.FIELDS.get(field, {}).get("boost", "")), -1))

## Sizes the badge: the full name when it fits in the room given by place(), else compact.
func _fit() -> void:
	var icon: float = float(ElementIcons.SIZE) + 2.0
	_label.text = RiftFields.badge_text(field, turns)
	var w: float = ceilf(_label.get_minimum_size().x) + PAD * 2.0 + icon
	compact = _max_width > 0.0 and w > _max_width
	if compact:
		_label.text = str(turns) if turns > 0 else ""
		w = ceilf(_label.get_minimum_size().x) + PAD * 2.0 + icon
	size = Vector2(w, HEIGHT)
	_label.position = Vector2(PAD + icon, 0)
	_label.size = Vector2(maxf(w - PAD * 2.0 - icon, 0.0), HEIGHT)
	queue_redraw()

## Follows one played battle event (FIELD, FIELD_END, FIELD_EXTENDED).
func on_event(e: BattleEvent) -> void:
	match e.type:
		BattleEvent.Type.FIELD:
			show_field(str(e.data.get("field", "")), int(e.data.get("turns", 0)))
		BattleEvent.Type.FIELD_END:
			if not e.data.has("by") and str(e.data.get("field", "")) == field:
				show_field("", 0)
		BattleEvent.Type.FIELD_EXTENDED:
			if not bool(e.data.get("failed", false)):
				show_field(field, turns + int(e.data.get("turns", 0)))

## Takes the field state of [param m] once a turn has played out.
func sync(m: BattleModel) -> void:
	if m != null:
		show_field(m.field, m.field_turns)

## Puts the badge at [param at]; [param max_width] > 0 folds it when the full tag is wider.
func place(at: Vector2, max_width: float = 0.0) -> void:
	_max_width = max_width
	_fit()
	position = at.round()

## Back to the place's normal song pitch when the battle screen goes away.
func _exit_tree() -> void:
	if not field.is_empty():
		Sound.music_pitch(1.0)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	var bg: Color = UITheme.ACCENT if _flash > 0.0 and int(_flash * 10.0) % 2 == 0 else UITheme.BG
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.INK, false, 1.0)
	if element() >= 0:
		draw_texture(ElementIcons.texture(element()), Vector2(PAD, floorf((HEIGHT - ElementIcons.SIZE) / 2.0)))
