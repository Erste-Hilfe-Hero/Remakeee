class_name ShopZoom
extends RefCounted
## Finger and reading sizes for the shop, the pass track and the Riftglass questions (Apple review,
## 27.11.2026): every button at least 44 pt tall and every text at least 13 pt.
## The view of an era is scaled by a whole number (ScreenFit), so one pixel of the era is
## pt_per_px() points: on a phone the real value (iOS points, Android dp), elsewhere (tests, tools)
## the smallest supported phone, the iPhone SE (iOS 16: 750 x 1334 pixels, 2 pixels per point):
## 2.5 in Eras I and II, 2 in Era III, but only 1 in Eras IV and V, whose 12 px text would be
## 12 pt. Where text would be smaller than 13 pt the shop's screens are drawn into a view of half
## the size and shown twice as large (factor()), crisp like the rest of the pixel art. In every era
## buttons and list rows of these screens are at least touch_px() pixels tall.
## Only these screens change; the game's own display settings stay as they are.

## The smallest supported phone in pixels and its pixels per point.
const PHONE_PX: Vector2 = Vector2(750, 1334)
const PHONE_PX_PER_PT: float = 2.0
## Apple's smallest touch target and the smallest text size these screens allow, in points.
const MIN_TOUCH_PT: float = 44.0
const MIN_TEXT_PT: float = 13.0
## Meta of a host that already shows shop screens: how many of them are open on it.
const DEPTH: StringName = &"shop_zoom_depth"
const OLD_MIN: StringName = &"shop_zoom_old_min"
## Meta of a zoomed view: its factor.
const FACTOR: StringName = &"shop_zoom"

## Points per pixel of era [param era]: the phone's own value for the active era, else the
## iPhone SE's (model_pt_per_px).
static func pt_per_px(era: int = -1) -> float:
	if era <= 0 or era == EraManager.active_era():
		var d: float = device_pt_per_px()
		if d > 0.0:
			return d
	return model_pt_per_px(era)

## Points per pixel of era [param era] on the iPhone SE.
static func model_pt_per_px(era: int = -1) -> float:
	var base: Vector2i = EraManager.RESOLUTION[_era(era)]
	return floorf(minf(PHONE_PX.x / base.x, PHONE_PX.y / base.y)) / PHONE_PX_PER_PT

## The view size of era [param era] on the iPhone SE: the era's base size, grown to the
## phone's shape (stretch mode "viewport", aspect "expand"; the whole-number scale adds borders).
static func phone_view(era: int) -> Vector2i:
	var base: Vector2i = EraManager.RESOLUTION[era]
	var aspect: float = PHONE_PX.x / PHONE_PX.y
	if aspect < float(base.x) / base.y:
		return Vector2i(base.x, floori(base.x / aspect))
	return Vector2i(floori(base.y * aspect), base.y)

## Points (iOS) or dp (Android) per pixel of the game's view on this phone; 0 elsewhere.
static func device_pt_per_px() -> float:
	if not (OS.has_feature("ios") or OS.has_feature("android")):
		return 0.0
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0.0
	# Screen pixels per view pixel: the whole-number stretch scale (rounded down, so a finer
	# scale only ever makes these screens larger).
	var view: Vector2 = tree.root.get_visible_rect().size
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if view.x <= 0.0 or view.y <= 0.0:
		return 0.0
	var px_per_view: float = floorf(minf(win.x / view.x, win.y / view.y))
	var px_per_pt: float = DisplayServer.screen_get_scale() if OS.has_feature("ios") else DisplayServer.screen_get_dpi() / 160.0
	if px_per_view <= 0.0 or px_per_pt <= 0.0:
		return 0.0
	return px_per_view / px_per_pt

static func _era(era: int) -> int:
	return era if era > 0 else EraManager.active_era()

## Height of one text line in pixels of the era (the font every screen uses now).
static func line_px() -> float:
	return UITheme.font().get_height(UITheme.FONT_SIZE)

## How many times larger the shop screens are drawn in era [param era]: 1, or 2 where the
## era's text would be smaller than MIN_TEXT_PT.
static func factor(era: int = -1) -> int:
	var k: int = 1
	while k * line_px() * pt_per_px(era) < MIN_TEXT_PT - 0.01 and k < 4:
		k += 1
	return k

## The smallest button height in pixels of the (zoomed) shop view.
static func touch_px(era: int = -1) -> int:
	return ceili(MIN_TOUCH_PT / (factor(era) * pt_per_px(era)) - 0.01)

## How large one pixel of [param n]'s view shows on the main screen (the zoom factors of the
## views it sits in).
static func screen_scale(n: Node) -> float:
	var s: float = 1.0
	var vp: Viewport = n.get_viewport() if n.is_inside_tree() else null
	while vp != null and vp.has_meta(FACTOR):
		s *= float(vp.get_meta(FACTOR))
		var up: Node = vp.get_parent()
		vp = up.get_viewport() if up != null and up.is_inside_tree() else null
	return s

## The host to run shop screens and Riftglass questions on, instead of [param host]: in the
## zoomed eras a new MenuHost in a view of 1 / factor() size over [param host], else [param host]
## itself with rows of at least touch_px(). Pair every call with leave().
static func enter(host: MenuHost) -> MenuHost:
	if host.has_meta(DEPTH):
		host.set_meta(DEPTH, int(host.get_meta(DEPTH)) + 1)
		return host
	var k: int = factor()
	if k > 1:
		var inner: MenuHost = _zoomed(host, k)
		inner.set_meta(DEPTH, 1)
		return inner
	host.set_meta(DEPTH, 1)
	host.set_meta(OLD_MIN, host.min_row)
	host.min_row = maxi(host.min_row, touch_px())
	return host

## Ends what enter() started: the zoomed view closes, a plain host gets its rows back.
static func leave(h: MenuHost) -> void:
	if not is_instance_valid(h) or not h.has_meta(DEPTH):
		return
	var d: int = int(h.get_meta(DEPTH)) - 1
	if d > 0:
		h.set_meta(DEPTH, d)
		return
	h.remove_meta(DEPTH)
	if h.has_meta(OLD_MIN):
		h.min_row = int(h.get_meta(OLD_MIN))
		h.remove_meta(OLD_MIN)
		return
	var box: Node = h.get_viewport().get_parent() if h.is_inside_tree() else null
	if box is View:
		box.queue_free()
	else:
		h.queue_free()

## One question of a Riftglass sink outside the menus (the battle's continue and bond boost), on
## [param picker] of [param parent], or in the zoomed eras on a zoomed list over [param parent].
static func ask(parent: Control, picker: ListPicker, title: String, entries: Array[Dictionary], cancellable: bool = true) -> int:
	var k: int = factor()
	if k > 1:
		var h: MenuHost = _zoomed(parent, k)
		h.min_row = touch_px()
		h.set_meta(DEPTH, 1)
		var r: int = await h.pick(title, entries, cancellable)
		leave(h)
		return r
	var old: Dictionary = picker.layout
	picker.layout = raised(old, touch_px())
	var r2: int = await picker.pick(title, entries, cancellable)
	if is_instance_valid(picker):
		picker.layout = old
	return r2

## [param lay] (a ListPicker layout) with rows and the Back button of at least [param px].
static func raised(lay: Dictionary, px: int) -> Dictionary:
	var out: Dictionary = lay.duplicate()
	out["row_h"] = maxi(int(lay.get("row_h", ListPicker.ROW_HEIGHT)), px)
	out["back_size"] = maxi(int(lay.get("back_size", ListPicker.BACK_SIZE)), px)
	return out

## A MenuHost in a view of 1 / [param k] the size of [param parent]'s, shown [param k] times as
## large over it.
static func _zoomed(parent: Control, k: int) -> MenuHost:
	var box := View.new()
	box.outer = parent
	box.name = "shop_zoom"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = k
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.set_meta(FACTOR, k)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(vp)
	parent.add_child(box)
	var inner := MenuHost.new()
	inner.min_row = touch_px()
	vp.add_child(inner)
	inner.theme = zoom_theme()
	return inner

## The theme inside a zoomed view: the era's colours and frames with the narrow pixel font of
## Eras I and II (5 px letters, 18 pt when shown twice as large), so long German words still fit
## the half-size view.
static func zoom_theme() -> Theme:
	var th: Theme = UITheme.get_theme().duplicate()
	th.default_font = PixelFont.get_font()
	return th

## The zoomed view. Keys and pad buttons go only to the screens inside it (the world behind a
## shop screen never sees them); taps reach them through the container as usual.
class View extends SubViewportContainer:
	var outer: Control

	func _input(event: InputEvent) -> void:
		if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventGesture:
			return
		if not is_visible_in_tree() or get_child_count() == 0:
			return
		(get_child(0) as SubViewport).push_input(event)
		get_viewport().set_input_as_handled()

	func _process(_delta: float) -> void:
		if get_child_count() == 0:
			return
		for c: Node in get_child(0).get_children():
			var h: MenuHost = c as MenuHost
			if h == null:
				continue
			# "Close every menu" on the host behind closes the zoomed lists too.
			if outer is MenuHost and (outer as MenuHost).close_all:
				h.close_all = true
			# A new palette (MenuHost.refresh_theme) keeps the zoomed view's font.
			if h.theme == UITheme.get_theme():
				h.theme = ShopZoom.zoom_theme()
