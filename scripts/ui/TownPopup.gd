class_name TownPopup
extends RefCounted
## Place-name banner per era (data/era_feel.json "town_popup", docs/ERA_FEEL_UI.md):
## Era I a plain ink panel that just appears, Era II a framed sign that drops in, Era III a
## wooden board that drops in, Era IV a full-width ribbon that slides in from the left, Era V
## the ribbon with a light sweep. Reduced motion shows and hides it without movement.

const SLIDE_TIME: float = 0.18
const TOP: int = 4
const WOOD: Color = Color("6b4426")
const WOOD_EDGE: Color = Color("3a2412")
const WOOD_TEXT: Color = Color("f6e7c8")

## The banner's look for [param style].
static func dress(banner: Label, style: String) -> void:
	banner.remove_theme_color_override("font_color")
	match style:
		"board":
			var sb := UITheme.flat_style(WOOD, WOOD_EDGE)
			sb.border_width_bottom = 2
			sb.set_content_margin_all(3)
			banner.add_theme_stylebox_override("normal", sb)
			banner.add_theme_color_override("font_color", WOOD_TEXT)
		"ribbon", "ribbon_shine":
			var sb := StyleBoxFlat.new()
			sb.bg_color = UITheme.ACCENT
			sb.border_color = UITheme.INK
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			sb.set_content_margin_all(3)
			banner.add_theme_stylebox_override("normal", sb)
			banner.add_theme_color_override("font_color", UITheme.INK)
		_:
			banner.add_theme_stylebox_override("normal", UITheme.panel_style())

## Moves the banner in ([param show_it]) or out the way of [param style]. Awaitable.
static func slide(banner: Label, style: String, show_it: bool) -> void:
	if banner.has_meta("popup_tween"):
		var prev: Variant = banner.get_meta("popup_tween")
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()
	banner.offset_top = TOP
	banner.position.x = 0.0
	banner.modulate = Color.WHITE
	if style == "plain" or Juice.reduced() or not banner.is_inside_tree():
		return
	var tw: Tween = banner.create_tween()
	banner.set_meta("popup_tween", tw)
	var h: float = maxf(banner.size.y, 12.0) + TOP
	match style:
		"sign", "board":
			var start: float = -h if show_it else TOP
			var end: float = TOP if show_it else -h
			banner.offset_top = start
			tw.tween_property(banner, "offset_top", end, SLIDE_TIME).set_trans(Tween.TRANS_BACK if show_it else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if show_it else Tween.EASE_IN)
		_:
			var w: float = banner.get_viewport_rect().size.x
			banner.position.x = -w if show_it else 0.0
			banner.modulate.a = 0.0 if show_it else 1.0
			tw.tween_property(banner, "position:x", 0.0 if show_it else w, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if show_it else Tween.EASE_IN)
			tw.parallel().tween_property(banner, "modulate:a", 1.0 if show_it else 0.0, SLIDE_TIME)
			if show_it and style == "ribbon_shine":
				tw.tween_property(banner, "modulate", Color(1.5, 1.5, 1.4, 1.0), 0.12)
				tw.tween_property(banner, "modulate", Color.WHITE, 0.25)
	await tw.finished
