class_name GleamRules
extends RefCounted
## Gleam form rules: the wild roll with its chain bonus, the per-species palette and the star mark.
## Tuning lives in data/gleam.json, palettes in data/gleam_palettes.json
## (tools/art/gen_gleam_palettes.py). A wild Gleam is a colour form only; the +10 % of the shop's
## Gleam Prism is Spirling.gleam_boost.
## Gleam kinds (1.3.2): "classic" is the first Gleam (same odds, palette and star); the rarer kinds
## of data/gleam.json "kinds" have their own odds, palette, glyph, colour and sparkle. One draw
## picks the kind, so replays stay in step. The shop never sells a kind: the shop's Shimmer Scent
## ([param paid] below) only scales the classic kind, and the Gleam Prism gives the classic kind.

const CONFIG_PATH: String = "res://data/gleam.json"
const PALETTE_PATH: String = "res://data/gleam_palettes.json"
const SHADER: Shader = preload("res://shaders/gleam_palette.gdshader")
## Gleam star in PixelFont (U+E006).
const STAR: String = ""
## The first Gleam kind; old saves and every Gleam without a known kind are this one.
const CLASSIC: String = "classic"
## Least contrast of a kind's label against its background (text_color).
const TEXT_CONTRAST: float = 3.0

static var _config: Dictionary = {}
static var _palettes: Dictionary = {}
static var _materials: Dictionary = {}
static var _kinds: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		_config = _read(CONFIG_PATH)
	return _config

static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

static func one_in() -> int:
	return maxi(1, int(config().get("wild_one_in", 1024)))

static func chain_max() -> int:
	return maxi(0, int(config().get("chain_max", 0)))

## Chance that a wild Spirling gleams after [param chain] earlier encounters of its kind in a row.
## [param mult] is the shop's Shimmer Scent (ShopEffects.gleam_mult).
static func chance(chain: int, mult: float = 1.0) -> float:
	var steps: int = clampi(chain, 0, chain_max())
	return minf(1.0, (1.0 + steps * float(config().get("chain_step", 0.0))) * maxf(mult, 1.0) / one_in())

## Rolls once on [param rng] (always one draw, so replays stay in step): true when the draw lands
## on the classic kind. roll_kind() picks among every kind with the same draw.
static func roll(rng: RandomNumberGenerator, chain: int, mult: float = 1.0) -> bool:
	return rng.randf() < chance(chain, mult)

## Every Gleam kind of data/gleam.json "kinds" in roll order (classic first), each {"id", "name",
## "glyph", "color", ...}. A data file without kinds still has the classic one.
static func kinds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = config().get("kinds", [])
	for k: Variant in (raw if raw is Array else []):
		if k is Dictionary and str((k as Dictionary).get("id", "")) != "":
			out.append(k)
	if out.is_empty() or str(out[0].id) != CLASSIC:
		out.push_front({"id": CLASSIC, "name": "Gleam", "glyph": "e006", "color": "f2d03b"})
	return out

static func kind_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Dictionary in kinds():
		out.append(str(k.id))
	return out

## The kind [param id] ({} when unknown).
static func kind(id: String) -> Dictionary:
	if _kinds.is_empty():
		for k: Dictionary in kinds():
			_kinds[str(k.id)] = k
	return _kinds.get(id, {})

static func is_kind(id: String) -> bool:
	return not kind(id).is_empty()

## One in how many wild Spirlings is of kind [param id] without chain or scent (0 when unknown).
static func kind_one_in(id: String) -> int:
	if id == CLASSIC:
		return one_in()
	return maxi(1, int(kind(id).get("one_in", 0))) if is_kind(id) else 0

## Chance of kind [param id] after [param chain] encounters in a row. [param mult] is a free boost
## (Rustle Spots); [param paid] is the shop's Shimmer Scent and only counts for the classic kind.
static func kind_chance(id: String, chain: int, mult: float = 1.0, paid: float = 1.0) -> float:
	if id == CLASSIC:
		return chance(chain, maxf(mult, 1.0) * maxf(paid, 1.0))
	var n: int = kind_one_in(id)
	if n <= 0:
		return 0.0
	var steps: int = clampi(chain, 0, chain_max())
	return minf(1.0, (1.0 + steps * float(config().get("chain_step", 0.0))) * maxf(mult, 1.0) / n)

## Chance that a wild Spirling gleams in any kind.
static func total_chance(chain: int, mult: float = 1.0, paid: float = 1.0) -> float:
	var sum: float = 0.0
	for id: String in kind_ids():
		sum += kind_chance(id, chain, mult, paid)
	return minf(1.0, sum)

## Rolls the Gleam kind of a wild Spirling with one draw on [param rng]: the classic kind when
## the draw is below its chance (exactly when roll() would be true), then each rarer kind on the
## next slice. Returns "" when it does not gleam.
static func roll_kind(rng: RandomNumberGenerator, chain: int, mult: float = 1.0, paid: float = 1.0) -> String:
	var r: float = rng.randf()
	var edge: float = 0.0
	for id: String in kind_ids():
		edge += kind_chance(id, chain, mult, paid)
		if r < edge:
			return id
	return ""

## The kind of [param s]: "" when it does not gleam, CLASSIC for a Gleam without a known kind
## (saves from before the kinds, the Gleam Prism).
static func kind_of(s: Spirling) -> String:
	if s == null or not s.gleam:
		return ""
	return s.gleam_kind if is_kind(s.gleam_kind) else CLASSIC

## Same for a saved or traded Spirling dictionary.
static func kind_of_dict(m: Dictionary) -> String:
	if not (m.get("gleam") is bool and m.get("gleam")):
		return ""
	var k: String = str(m.get("gleam_kind", ""))
	return k if is_kind(k) else CLASSIC

## Makes [param s] a Gleam of kind [param id], or no Gleam for "".
static func apply(s: Spirling, id: String) -> void:
	s.gleam = id != ""
	s.gleam_kind = (id if is_kind(id) else CLASSIC) if s.gleam else ""

## The glyph of kind [param id] (PixelFont private-use character), STAR when unknown.
static func glyph(id: String) -> String:
	var hex: String = str(kind(id).get("glyph", "e006"))
	return char(hex.hex_to_int()) if hex.is_valid_hex_number() else STAR

## The colour of kind [param id] (labels, the battle glint).
static func color(id: String) -> Color:
	return Color(str(kind(id).get("color", "f2d03b")))

## The kind's colour darkened until it reads on [param bg] (contrast 3:1 or more), for text.
static func text_color(id: String, bg: Color) -> Color:
	var c: Color = color(id)
	for i: int in 10:
		if UITheme.contrast(c, bg) >= TEXT_CONTRAST:
			break
		c = c.darkened(0.12)
	return c

## English name of kind [param id] ("Rime Gleam"); callers translate it with Loc.t.
static func kind_name(id: String) -> String:
	return str(kind(id).get("name", "Gleam"))

## Sparkle and sound settings of kind [param id]: the top-level values of data/gleam.json with the
## kind's own "sparkles", "sparkle_time", "sfx", "sfx_pitch" and "sparkle_color" on top.
static func sparkle(id: String) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ["sfx", "sfx_pitch", "sparkles", "sparkle_time"]:
		if config().has(key):
			out[key] = config()[key]
	var k: Dictionary = kind(id)
	for key: String in ["sfx", "sfx_pitch", "sparkles", "sparkle_time", "sparkle_color", "cycle"]:
		if k.has(key):
			out[key] = k[key]
	return out

## The rarer kinds a Spirlog entry lists: [param key] is "gleam_kinds_seen" or "gleam_kinds_bonded".
static func kinds_in(entry: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = entry.get(key, [])
	for id: String in kind_ids():
		if raw is Array and (raw as Array).has(id):
			out.append(id)
	return out

## Chain count that applies to [param species] from the saved chain {"species", "count"}.
static func chain_for(chain: Dictionary, species: String) -> int:
	return int(chain.get("count", 0)) if str(chain.get("species", "")) == species else 0

## The chain after a wild [param s] appeared: same kind counts up (to chain_max), another kind
## starts over at 1, and a Gleam ends the chain.
static func next_chain(chain: Dictionary, s: Spirling) -> Dictionary:
	var sp: String = s.data.species_name
	if s.gleam:
		return {"species": sp, "count": 0}
	return {"species": sp, "count": mini(chain_for(chain, sp) + 1, chain_max())}

## The four Gleam colours of [param species] in kind [param id] (ink 0..3), or [] when it has none.
static func palette(species: String, id: String = CLASSIC) -> Array[Color]:
	if _palettes.is_empty():
		_palettes = _read(PALETTE_PATH)
	var table: Variant = _palettes.get("palettes", {}) if id == CLASSIC else (_palettes.get("kinds", {}) as Dictionary).get(id, {})
	var out: Array[Color] = []
	for h: Variant in (table as Dictionary).get(species, []) if table is Dictionary else []:
		out.append(Color(str(h)))
	return out

## Shader material that recolours a sprite of [param species] in kind [param id], or null without
## a palette.
static func material(species: String, id: String = CLASSIC) -> ShaderMaterial:
	if id != CLASSIC:
		return _kind_material(species, id)
	if _materials.has(species):
		return _materials[species]
	var pal: Array[Color] = palette(species)
	var mat: ShaderMaterial = null
	var sprite: String = EraManager.sprite_path(species)
	if pal.size() == 4 and SpriteTiers.tier_of_path(sprite) > 1:
		# Art of tiers II to V is not in the four inks: turn its hues instead.
		mat = ShaderMaterial.new()
		mat.shader = load(SpriteTiers.HUE_SHADER_PATH)
		# Keyed by the line, so every stage of a line gleams in the same colours.
		var sd: SpirlingData = Database.species(species)
		var key: String = sd.line_id if sd != null and sd.line_id != "" else SpriteTiers.id_of_path(sprite)
		mat.set_shader_parameter("shift", SpriteTiers.gleam_shift(key))
	elif pal.size() == 4:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		for i: int in 4:
			mat.set_shader_parameter("src%d" % i, EraManager.INK_PALETTE[i])
			mat.set_shader_parameter("dst%d" % i, pal[i])
	_materials[species] = mat
	return mat

## A rarer kind: Era I ink art takes the kind's palette, later tiers are pulled toward the kind's
## dark-to-light ramp ("tier" in data/gleam.json); "cycle" turns the hues over time (Opaline).
## Under reduced motion a cycling kind stands still at its "still_phase" (turns) instead.
static func _kind_material(species: String, id: String) -> ShaderMaterial:
	var k: Dictionary = kind(id)
	var still: bool = k.has("cycle") and Juice.reduced()
	var key: String = species + "|" + id + ("|still" if still else "")
	if _materials.has(key):
		return _materials[key]
	var pal: Array[Color] = palette(species, id)
	var cycle: float = 0.0 if still else float(k.get("cycle", 0.0))
	var phase: float = float(k.get("still_phase", 0.5)) if still else 0.0
	var mat: ShaderMaterial = null
	var sprite: String = EraManager.sprite_path(species)
	if pal.size() == 4 and SpriteTiers.tier_of_path(sprite) > 1:
		mat = ShaderMaterial.new()
		mat.shader = load(SpriteTiers.HUE_SHADER_PATH)
		var t: Dictionary = k.get("tier", {})
		var sd: SpirlingData = Database.species(species)
		var line: String = sd.line_id if sd != null and sd.line_id != "" else SpriteTiers.id_of_path(sprite)
		mat.set_shader_parameter("shift", SpriteTiers.gleam_shift(line) if k.has("cycle") else 0.0)
		mat.set_shader_parameter("ramp_dark", Color(str(t.get("dark", "000000"))))
		mat.set_shader_parameter("ramp_light", Color(str(t.get("light", "ffffff"))))
		mat.set_shader_parameter("ramp_mid", Color(str(t.get("dark", "000000"))).lerp(Color(str(t.get("light", "ffffff"))), 0.5) if not t.has("mid") else Color(str(t.mid)))
		mat.set_shader_parameter("accent", Color(str(t.get("accent", "ffffff"))))
		mat.set_shader_parameter("accent_from", float(t.get("accent_from", 2.0)))
		mat.set_shader_parameter("true_colours", true)
		mat.set_shader_parameter("ramp_mix", float(t.get("mix", 0.0)))
		mat.set_shader_parameter("cycle", cycle)
		mat.set_shader_parameter("phase", phase)
	elif pal.size() == 4:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		for i: int in 4:
			mat.set_shader_parameter("src%d" % i, EraManager.INK_PALETTE[i])
			mat.set_shader_parameter("dst%d" % i, pal[i])
		mat.set_shader_parameter("cycle", cycle)
		mat.set_shader_parameter("phase", phase)
		mat.set_shader_parameter("true_colours", true)
	_materials[key] = mat
	return mat

## "<glyph> " before the name of a Gleam (party, storage): the star for the classic kind, the
## kind's own glyph for the rarer ones; "" otherwise.
static func mark(s: Spirling) -> String:
	var id: String = kind_of(s)
	return glyph(id) + " " if id != "" else ""

## Same for a traded Spirling dictionary.
static func mark_of_dict(m: Dictionary) -> String:
	var id: String = kind_of_dict(m)
	return glyph(id) + " " if id != "" else ""

## "<glyph> Rime Gleam" (translated) for summary and trade, "" for no Gleam.
static func label(id: String) -> String:
	return glyph(id) + " " + Loc.t(kind_name(id)) if id != "" else ""
