class_name ScreenFit
extends RefCounted
## Fits the pixel-art view to any screen shape, also when the screen changes while the game
## runs (a foldable opening or closing, a phone turned, an iPad or Chromebook window dragged
## to a new size). Update 1.3.2 (Google Play adaptive quality, tier 3): the view always fills
## the whole window, with no bars on any side.
##
## How: the pixel scale is the largest whole number at which the era's base size (144 x 256
## for Era I) still fits the window, the same scale the old integer stretch picked. The view
## is then the window divided by that scale, so it is never smaller than the base size and
## shows more of the world on a taller, wider or larger screen instead of bars. Because the
## window is rarely an exact multiple of the scale, the stretch is "fractional": the view is
## at most one pixel wider or taller than an exact multiple and is drawn at the scale to
## within a fraction of a percent, so the pixels stay crisp. A window smaller than the base
## size (a tiny split-screen strip) keeps the old integer stretch at scale 1.

## Width of the UI column on wide views, as a share of the view height (3:4). Lists, the shop,
## the battle panels and the talk box stay in a column of at most this width in the middle;
## the world, the battle backdrop and the touch buttons use the full width.
const COLUMN_ASPECT: float = 0.75

## The whole-number pixel scale for a window of [param window] pixels and an era base of
## [param base]: the largest at which the base fits, 0 when even 1 does not.
static func pixel_scale(window: Vector2, base: Vector2i) -> int:
	if window.x <= 0.0 or window.y <= 0.0 or base.x <= 0 or base.y <= 0:
		return 0
	return int(floorf(minf(window.x / base.x, window.y / base.y)))

## Always "expand": the view takes the window's shape, so no side shows a bar.
static func aspect_mode(_window: Vector2) -> Window.ContentScaleAspect:
	return Window.CONTENT_SCALE_ASPECT_EXPAND

## The content size for a window of [param window] pixels and an era base of [param base].
static func content_size(window: Vector2, base: Vector2i) -> Vector2i:
	var k: int = pixel_scale(window, base)
	if k < 1:
		return base
	return Vector2i(maxi(base.x, roundi(window.x / k)), maxi(base.y, roundi(window.y / k)))

## Sets [param w]'s content size, aspect and stretch for its current size. True when anything
## changed.
static func apply(w: Window, base: Vector2i) -> bool:
	var size := Vector2(w.size)
	var mode: Window.ContentScaleAspect = aspect_mode(size)
	var content: Vector2i = content_size(size, base)
	# Below the base size (k = 0: a tiny split-screen strip, the 64 x 64 px headless window) the
	# integer stretch keeps drawing at scale 1, as before 1.3.2, so touch and mouse positions
	# stay in view pixels there.
	var stretch := Window.CONTENT_SCALE_STRETCH_FRACTIONAL if pixel_scale(size, base) >= 1 else Window.CONTENT_SCALE_STRETCH_INTEGER
	var changed: bool = w.content_scale_aspect != mode or w.content_scale_size != content or w.content_scale_stretch != stretch
	if w.content_scale_stretch != stretch:
		w.content_scale_stretch = stretch
	if w.content_scale_aspect != mode:
		w.content_scale_aspect = mode
	if w.content_scale_size != content:
		w.content_scale_size = content
	return changed

## The UI column inside [param safe] for a view of [param vp]: the safe area itself on a
## portrait screen, a centred band COLUMN_ASPECT times the view height wide on a wide one.
static func column(vp: Vector2, safe: Rect2) -> Rect2:
	var w: float = floorf(vp.y * COLUMN_ASPECT)
	if safe.size.x <= w:
		return safe
	var x: float = roundf(safe.position.x + (safe.size.x - w) / 2.0)
	return Rect2(x, safe.position.y, w, safe.size.y)

## Shortest screen side, in dp / pt, from which the game also turns to landscape: Android's
## large-screen line (sw600dp: tablets, unfolded foldables, Chromebooks) and every iPad.
const LARGE_SCREEN_DP: float = 600.0

## Phones stay upright (turning a phone only shrinks the world strip); large screens follow
## the sensor in all four directions. The exported apps allow every direction (project
## orientation "sensor"), so Android 16+ large-screen rules and iPad multitasking never meet a
## locked app; this only narrows it on a phone, and again on every fold or unfold.
static func orientation_for(screen_px: Vector2, density: float) -> DisplayServer.ScreenOrientation:
	var short_dp: float = minf(screen_px.x, screen_px.y) / maxf(density, 0.1)
	if short_dp > 0.0 and short_dp < LARGE_SCREEN_DP:
		return DisplayServer.SCREEN_SENSOR_PORTRAIT
	return DisplayServer.SCREEN_SENSOR

## Pixels per dp (Android) or per point (iOS) of the screen the game is on; 1 elsewhere.
static func density() -> float:
	if OS.has_feature("ios"):
		return maxf(DisplayServer.screen_get_scale(), 1.0)
	if OS.has_feature("android"):
		var dpi: int = DisplayServer.screen_get_dpi()
		return dpi / 160.0 if dpi > 0 else 1.0
	return 1.0

## Applies orientation_for on a phone or tablet (no effect on desktop or in tests).
static func apply_orientation() -> void:
	if not OS.has_feature("mobile"):
		return
	var want: DisplayServer.ScreenOrientation = orientation_for(Vector2(DisplayServer.screen_get_size()), density())
	if DisplayServer.screen_get_orientation() != want:
		DisplayServer.screen_set_orientation(want)

## Smallest touch target, in points (Apple) / dp (Android 48 dp is about 44 pt).
const TOUCH_PT: float = 44.0

## Screen pixels per view pixel of [param w] (the pixel scale it is drawn at), 1 without a window.
static func px_scale(w: Window) -> float:
	if w == null:
		return 1.0
	var vis: Vector2 = w.get_visible_rect().size
	return float(w.size.x) / vis.x if vis.x > 0.0 and w.size.x > 0 else 1.0

## The smallest touch target in view pixels for [param w] (update 1.3.2): TOUCH_PT on this
## screen at the scale the view is drawn at. A low scale (a small or low-density screen)
## asks for larger buttons and rows; never more than an eighth of the view height. 0 (no
## floor) when the view is drawn smaller than its own size (a window below the base size, or the
## 64 x 64 px headless window of the test runs), where a pixel measure means nothing.
static func touch_px(w: Window) -> int:
	if w == null or px_scale(w) < 1.0:
		return 0
	var px: int = ceili(TOUCH_PT * density() / px_scale(w) - 0.01)
	return mini(px, int(w.get_visible_rect().size.y / 8.0))
