class_name ScreenFit
extends RefCounted
## Fits the pixel-art view to any screen shape, also when the screen changes while the game
## runs: a foldable like iPhone Duo goes from its outer display (1398 x 2034 px) to its
## inner one (1878 x 2670 px) and back, and the inner display does not keep the app in
## portrait. Up to MAX_ASPECT (width / height) the view grows sideways ("expand", more of
## the world shows); a wider screen keeps a 3:4 view in the middle with bars at the sides, so
## menus and the battle made for a portrait phone never stretch across a landscape screen.
## The scale stays a whole number (project setting), so the pixels stay crisp.

## Widest view, width / height. 3:4 is the shape of a portrait tablet, which the game
## already fills; iPhone Duo's inner display (about 0.70) fits under it.
const MAX_ASPECT: float = 0.75

## Expand up to MAX_ASPECT, keep (bars at the sides) beyond it.
static func aspect_mode(window: Vector2) -> Window.ContentScaleAspect:
	if window.x <= 0.0 or window.y <= 0.0 or window.x / window.y <= MAX_ASPECT:
		return Window.CONTENT_SCALE_ASPECT_EXPAND
	return Window.CONTENT_SCALE_ASPECT_KEEP

## The content size for a window of [param window] pixels and an era base of [param base].
static func content_size(window: Vector2, base: Vector2i) -> Vector2i:
	if aspect_mode(window) == Window.CONTENT_SCALE_ASPECT_EXPAND:
		return base
	return Vector2i(roundi(base.y * MAX_ASPECT), base.y)

## Sets [param w]'s content size and aspect for its current size. True when anything changed.
static func apply(w: Window, base: Vector2i) -> bool:
	var size := Vector2(w.size)
	var mode: Window.ContentScaleAspect = aspect_mode(size)
	var content: Vector2i = content_size(size, base)
	var changed: bool = w.content_scale_aspect != mode or w.content_scale_size != content
	if w.content_scale_aspect != mode:
		w.content_scale_aspect = mode
	if w.content_scale_size != content:
		w.content_scale_size = content
	return changed
