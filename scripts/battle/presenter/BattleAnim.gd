class_name BattleAnim
extends RefCounted
## Era V animated battle sprites: frame strips (idle bob, attack lunge, hit flash) built from a
## species' base sprite. Each strip is one horizontal Image of N frames, each the base size.
## Values live in data/era5_anim.json.

const PATH: String = "res://data/era5_anim.json"
const KINDS: Array[String] = ["idle", "attack", "hit"]
const UNLOCK_LINE: String = "The world comes alive. Every Spirling moves on its own now, and the battle follows every strike!"

static var _cfg: Dictionary = {}
static var _cache: Dictionary = {}

static func config() -> Dictionary:
	if _cfg.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = raw if raw is Dictionary else {"min_era": 5, "strips": {}}
	return _cfg

## True when [param era] shows animated battle sprites and the battle camera.
static func enabled_for(era: int) -> bool:
	return era >= int(config().get("min_era", 5))

static func enabled() -> bool:
	return enabled_for(EraManager.active_era())

static func strip_cfg(kind: String) -> Dictionary:
	return (config().get("strips", {}) as Dictionary).get(kind, {})

static func frame_count(kind: String) -> int:
	var c: Dictionary = strip_cfg(kind)
	return maxi((c.get("dx", c.get("dy", [0])) as Array).size(), 1)

static func fps(kind: String) -> float:
	return float(strip_cfg(kind).get("fps", 8))

static func loops(kind: String) -> bool:
	return bool(strip_cfg(kind).get("loop", false))

## Frame index at time [param t] (seconds); one-shot strips hold their last frame.
static func frame_at(kind: String, t: float) -> int:
	var n: int = frame_count(kind)
	var i: int = int(floor(maxf(t, 0.0) * fps(kind)))
	return posmod(i, n) if loops(kind) else mini(i, n - 1)

## Builds the strip for [param kind] from [param base]. Attack frames move toward -x (the art
## faces left); mirroring is applied at draw time. Hit frames marked "flash" are a solid silhouette.
static func build_strip(base: Image, kind: String) -> Image:
	var src: Image = base.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var c: Dictionary = strip_cfg(kind)
	var n: int = frame_count(kind)
	var dxs: Array = c.get("dx", [])
	var dys: Array = c.get("dy", [])
	var flashes: Array = c.get("flash", [])
	var flash_col: Color = Color(str(config().get("flash_color", "ffffff")))
	var out: Image = Image.create_empty(w * n, h, false, Image.FORMAT_RGBA8)
	for f: int in n:
		var dx: int = -int(dxs[f]) if f < dxs.size() else 0
		var dy: int = int(dys[f]) if f < dys.size() else 0
		var flash: bool = f < flashes.size() and bool(flashes[f])
		for y: int in h:
			var sy: int = y - dy
			if sy < 0 or sy >= h:
				continue
			for x: int in w:
				var sx: int = x - dx
				if sx < 0 or sx >= w:
					continue
				var p: Color = src.get_pixel(sx, sy)
				if p.a <= 0.0:
					continue
				out.set_pixel(f * w + x, y, Color(flash_col, p.a) if flash else p)
	return out

## Cached strip texture for [param path] and [param kind]; null when the sprite cannot load.
static func strip_texture(path: String, kind: String) -> Texture2D:
	var key: String = path + "|" + kind
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = load(path) if not path.is_empty() else null
	var img: Image = tex.get_image() if tex != null else null
	var out: Texture2D = ImageTexture.create_from_image(build_strip(img, kind)) if img != null else null
	_cache[key] = out
	return out

static func clear_cache() -> void:
	_cache.clear()
