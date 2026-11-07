class_name ShopPreview
extends RefCounted
## Shows a look before it is bought (plan item 4291): a small picture for jackets, hats, text
## frames and battle backdrops, a sample line for profile frames and gift cards. Drawn from the
## same code the game uses, so the preview is what you get.

const SCALE: int = 3

## The kind part of a look offer's unlock key ("hat_tricorn" -> ["hat", "tricorn"]), or [].
static func look_parts(o: Dictionary) -> Array[String]:
	if str(o.get("slot", "")) == "gift_card":
		return ["gift_card", ""]
	var key: String = ShopMenu.look_key(o)
	for prefix: String in ["jacket_", "backdrop_", "frame_", "hat_", "card_frame_"]:
		if key.begins_with(prefix):
			return [prefix.trim_suffix("_"), key.trim_prefix(prefix)]
	return []

## A sample line for looks that are text (profile frames, gift cards); "" for the others.
static func preview_text(o: Dictionary) -> String:
	var parts: Array[String] = look_parts(o)
	if parts.is_empty():
		return ""
	match parts[0]:
		"card_frame":
			var shown: String = FriendsMenu.framed_name({"name": GameState.tamer_name, "card": {"frame": parts[1]}})
			return "\n\n" + Loc.t("Preview: %s") % shown
		"gift_card":
			var lines: Array[String] = []
			for k: String in FriendsMenu.GIFT_CARDS:
				lines.append(FriendsMenu.GIFT_CARDS[k])
			return "\n\n" + Loc.t("Preview:") + "\n" + "\n".join(lines)
	return ""

## The picture for a look offer, or null (other offers, or no renderer for backdrops).
## [param host] is a node in the tree, used to render a backdrop off screen. Awaitable.
static func picture(o: Dictionary, host: Node = null) -> Texture2D:
	var parts: Array[String] = look_parts(o)
	if parts.is_empty():
		return null
	var img: Image
	match parts[0]:
		"jacket":
			img = _jacket(Color(str(o.get("color", "#3a5a9a"))))
		"hat":
			img = _hat(parts[1])
		"frame":
			img = _text_frame(parts[1])
		"backdrop":
			img = await _backdrop(parts[1], host)
	return ImageTexture.create_from_image(img) if img != null else null

## The Wayfarer's shoulders in the jacket colour, from behind, like the battle picture.
static func _jacket(c: Color) -> Image:
	var img := _canvas(16, 14)
	img.fill_rect(Rect2i(1, 7, 14, 7), UITheme.INK)
	img.fill_rect(Rect2i(2, 8, 12, 6), c)
	img.fill_rect(Rect2i(5, 1, 6, 6), UITheme.INK)
	img.fill_rect(Rect2i(6, 2, 4, 4), UITheme.MID)
	return _scaled(img)

static func _hat(kind: String) -> Image:
	var img := _canvas(16, 16)
	img.fill_rect(Rect2i(5, 8, 6, 6), UITheme.INK)
	img.fill_rect(Rect2i(6, 9, 4, 4), UITheme.MID)
	HatArt.paint(img, Vector2i(8, 9), kind)
	return _scaled(img)

## The 9 px frame texture stretched to a small text box, edges tiled like the real box.
static func _text_frame(kind: String) -> Image:
	var sb: StyleBox = UITheme.text_frame_style(kind)
	if not sb is StyleBoxTexture:
		return null
	var src: Image = (sb as StyleBoxTexture).texture.get_image()
	var n: int = src.get_width()
	var m: int = UITheme.FRAME_MARGIN
	var w: int = 30
	var h: int = 15
	var img := _canvas(w, h)
	for y: int in h:
		for x: int in w:
			var sx: int = x if x < m else (n - (w - x) if x >= w - m else m + (x - m) % (n - 2 * m))
			var sy: int = y if y < m else (n - (h - y) if y >= h - m else m + (y - m) % (n - 2 * m))
			img.set_pixel(x, y, src.get_pixel(sx, sy))
	return _scaled(img)

## Renders the backdrop once off screen. Needs a renderer: headless runs get null.
static func _backdrop(kind: String, host: Node) -> Image:
	if host == null or not host.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 54)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bd := BattleBackdrop.new()
	bd.size = Vector2(vp.size)
	vp.add_child(bd)
	host.add_child(vp)
	bd.set_scene(kind, Rect2(60, 8, 24, 24), Rect2(14, 22, 24, 24))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.resize(vp.size.x * 2, vp.size.y * 2, Image.INTERPOLATE_NEAREST)
	return img

static func _canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(UITheme.BG)
	return img

static func _scaled(img: Image) -> Image:
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	return img
