class_name GleamRules
extends RefCounted
## Gleam form rules: the wild roll with its chain bonus, the per-species palette and the star mark.
## Tuning lives in data/gleam.json, palettes in data/gleam_palettes.json
## (tools/art/gen_gleam_palettes.py). A wild Gleam is a colour form only; the +10 % of the shop's
## Gleam Prism is Spirling.gleam_boost.

const CONFIG_PATH: String = "res://data/gleam.json"
const PALETTE_PATH: String = "res://data/gleam_palettes.json"
const SHADER: Shader = preload("res://shaders/gleam_palette.gdshader")
## Gleam star in PixelFont (U+E006).
const STAR: String = ""

static var _config: Dictionary = {}
static var _palettes: Dictionary = {}
static var _materials: Dictionary = {}

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
static func chance(chain: int) -> float:
	var steps: int = clampi(chain, 0, chain_max())
	return minf(1.0, (1.0 + steps * float(config().get("chain_step", 0.0))) / one_in())

## Rolls once on [param rng] (always one draw, so replays stay in step).
static func roll(rng: RandomNumberGenerator, chain: int) -> bool:
	return rng.randf() < chance(chain)

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

## The four Gleam colours of [param species] (ink 0..3), or [] when it has none.
static func palette(species: String) -> Array[Color]:
	if _palettes.is_empty():
		_palettes = _read(PALETTE_PATH)
	var out: Array[Color] = []
	for h: Variant in (_palettes.get("palettes", {}) as Dictionary).get(species, []):
		out.append(Color(str(h)))
	return out

## Shader material that recolours a sprite of [param species], or null without a palette.
static func material(species: String) -> ShaderMaterial:
	if _materials.has(species):
		return _materials[species]
	var pal: Array[Color] = palette(species)
	var mat: ShaderMaterial = null
	if pal.size() == 4:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		for i: int in 4:
			mat.set_shader_parameter("src%d" % i, EraManager.INK_PALETTE[i])
			mat.set_shader_parameter("dst%d" % i, pal[i])
	_materials[species] = mat
	return mat

## "<star> " before the name of a Gleam (party, storage), "" otherwise.
static func mark(s: Spirling) -> String:
	return STAR + " " if s.gleam else ""
