class_name KeepsakeIcons
extends RefCounted
## Own 7x7 pixel icons for keepsakes (KAMPF_PLAN_1000 304): one shape per kind of keepsake
## (prism, charm, stone, fruit, ...) from data/keepsake_kit.json "forms", coloured per keepsake.
## Drawn at runtime like ElementIcons, so there are no image files; docs/ASSET_LOG.md names them.

const SIZE: int = 7

static var _cache: Dictionary[String, ImageTexture] = {}

## The shape name of [param item_id] ("" when it has none).
static func form(item_id: String) -> String:
	return str((KeepsakeKit.data().get("icons", {}) as Dictionary).get(item_id, {}).get("form", ""))

## The pixel rows of [param form_name].
static func rows(form_name: String) -> Array:
	var r: Variant = (KeepsakeKit.data().get("forms", {}) as Dictionary).get(form_name, [])
	return r if r is Array else []

## Colour of the icon in [param era]: ink in Era I, else the element of an element keepsake or
## the keepsake's own colour.
static func colour(item_id: String, era: int) -> Color:
	if not BattleUiStyle.colour_on(era):
		return UITheme.INK
	var elem: String = str(BattleRules.held_info(item_id).get("elem", ""))
	if not elem.is_empty() and Elements.E.has(elem):
		return Elements.color(int(Elements.E[elem]))
	var hex: String = str((KeepsakeKit.data().get("icons", {}) as Dictionary).get(item_id, {}).get("colour", ""))
	return Color(hex) if not hex.is_empty() else UITheme.INK

## The icon of [param item_id] in [param color], or null for an item without one.
static func texture(item_id: String, color: Color = UITheme.INK) -> ImageTexture:
	var r: Array = rows(form(item_id))
	if r.is_empty():
		return null
	var key: String = "%s:%s" % [form(item_id), color.to_html()]
	if not _cache.has(key):
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		for y: int in mini(r.size(), SIZE):
			var row: String = r[y]
			for x: int in mini(row.length(), SIZE):
				if row[x] == "#":
					img.set_pixel(x, y, color)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

## The icon in the colour of the era on screen (menus and battle).
static func for_era(item_id: String) -> ImageTexture:
	var era: int = EraManager.active_era()
	return texture(item_id, colour(item_id, era))
