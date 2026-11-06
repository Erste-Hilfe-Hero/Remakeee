class_name MiniSprite
extends RefCounted
## Small copies of Spirling sprites for menu rows (14x14, plan item 1889) and the Spirlog page
## (48x48, item 1936), scaled with nearest pixels and cached.

static var _cache: Dictionary[String, Texture2D] = {}

static func of(species: String, size: int) -> Texture2D:
	var key: String = "%s:%d:%s" % [species, size, EraManager.sprite_path(species)]
	if _cache.has(key):
		return _cache[key]
	var path: String = EraManager.sprite_path(species)
	if path.is_empty():
		return null
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(size, size, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(img)
	_cache[key] = out
	return out
