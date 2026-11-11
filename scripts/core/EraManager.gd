extends Node
## Each region = a visual jump in the art style (Era I Ink -> IV Panorama), like an old map
## being redrawn: ink sketch, watercolour wash, fine etching, then a wide painted panorama.
## Owns the active era: internal resolution, palette filter, sprite set and the Retro filter choice.

signal era_changed(era: int)
## Emitted when a new region unlocks a newer era (item 48); the overworld shows a line for it.
signal era_unlocked(era: int)

enum Era { INK = 1, WASH = 2, ETCHED = 3, PANORAMA = 4 }
## The whole story (all four regions) stays Era I. Era II opens after the finale and is the
## look of the post-game region; later eras arrive with their own new regions.
const REGION_ERA: Dictionary[String, int] = {"veydal": Era.INK, "corvane": Era.INK, "ashmere": Era.INK, "solenne": Era.INK}
const STORY_COMPLETE_FLAG: String = "story_complete"
const RESOLUTION: Dictionary[int, Vector2i] = {Era.INK: Vector2i(144, 256), Era.WASH: Vector2i(144, 256), Era.ETCHED: Vector2i(180, 320), Era.PANORAMA: Vector2i(270, 480)}
const BATTLE_SPRITE_SIZE: Dictionary[int, int] = {Era.INK: 56, Era.WASH: 56, Era.ETCHED: 64, Era.PANORAMA: 96}
## Era I: four cartographer's inks on parchment (original values, darkest to lightest). Deliberately
## not the green four-shade look of old handheld screens.
const INK_PALETTE: Array[Color] = [Color("2a1e2c"), Color("6a4256"), Color("c48a5e"), Color("f2e3c2")]
const FILTER_LAYER: int = 100
const PALETTE_SHADER: Shader = preload("res://shaders/palette_filter.gdshader")

var unlocked_era: int = Era.INK
var retro_filter: int = 0   # 0 = use newest unlocked era

var _filter_layer: CanvasLayer
var _filter_rect: ColorRect

func _ready() -> void:
	_filter_layer = CanvasLayer.new()
	_filter_layer.layer = FILTER_LAYER
	add_child(_filter_layer)
	_filter_rect = ColorRect.new()
	_filter_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	for i: int in INK_PALETTE.size():
		mat.set_shader_parameter("c%d" % i, INK_PALETTE[i])
	_filter_rect.material = mat
	_filter_layer.add_child(_filter_rect)
	_apply()

func active_era() -> int:
	return retro_filter if retro_filter > 0 else unlocked_era

## Lines shown when an era opens up for the first time.
const ERA_LINES: Dictionary[int, String] = {
	Era.WASH: "The last line of the map is drawn. The ink runs and spreads, and the world fills with colour!",
	Era.ETCHED: "The air grows sharper. Every leaf and stone shows more detail!",
	Era.PANORAMA: "The map unrolls wider than ever. The whole horizon opens before you!",
}
const TRANSITION_TIME: float = 0.9
var _wipe: ColorRect

func unlock_region(region: String) -> void:
	unlock_era(REGION_ERA.get(region, Era.INK))

## Era II opens once the story finale is done.
func unlock_story_end(story_complete: bool) -> void:
	if story_complete:
		unlock_era(Era.WASH)

const ERAS_PATH: String = "res://data/eras.json"

## Era number -> story flag that opens it (data/eras.json "unlock_flags"): Era II after the
## story finale, Era III after the Era II post-game finale.
static func unlock_flags() -> Dictionary:
	var f: FileAccess = FileAccess.open(ERAS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d.get("unlock_flags", {}) if d is Dictionary else {}

## Unlocks every era whose flag is set. Eras open in order: a later flag does nothing while
## an earlier era is still locked.
func unlock_from_flags(has_flag: Callable) -> void:
	var flags: Dictionary = unlock_flags()
	for e: int in range(Era.WASH, Era.PANORAMA + 1):
		var flag: String = str(flags.get(str(e), ""))
		if flag.is_empty() or not has_flag.call(flag) or unlocked_era < e - 1:
			return
		unlock_era(e)

## Raises unlocked_era to [param e]; never lowers it (older saves keep their era).
func unlock_era(e: int) -> void:
	if e > unlocked_era:
		unlocked_era = e
		if retro_filter == 0 and is_inside_tree():
			play_transition()
		else:
			_apply()
		era_unlocked.emit(e)

## Era transition (item 48): a light sweep down the screen, the era switches while the
## screen is covered, then the light fades. With reduced motion it is a plain fade.
func play_transition() -> void:
	if _wipe == null:
		_wipe = ColorRect.new()
		_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wipe.color = Color(1, 1, 0.92)
		_filter_layer.add_child(_wipe)
	var size: Vector2 = get_viewport().get_visible_rect().size
	_wipe.position = Vector2.ZERO
	_wipe.size = Vector2(size.x, 0.0 if not Juice.reduced() else size.y)
	_wipe.modulate.a = 1.0 if not Juice.reduced() else 0.0
	_wipe.visible = true
	Sound.sfx("warp")
	var tw: Tween = create_tween()
	var half: float = TRANSITION_TIME / 2.0
	if Juice.reduced():
		Juice.shaped(tw.tween_property(_wipe, "modulate:a", 1.0, half), "close")
	else:
		Juice.shaped(tw.tween_property(_wipe, "size:y", size.y, half), "close")
	tw.tween_callback(_apply)
	Juice.shaped(tw.tween_property(_wipe, "modulate:a", 0.0, half), "fade")
	tw.tween_callback(func() -> void: _wipe.visible = false)

func set_retro_filter(e: int) -> void:
	retro_filter = clampi(e, 0, unlocked_era)
	_apply()

## Battle sprite size of the active era, or of [param species]' own era when given.
func battle_sprite_size(species: String = "") -> int:
	return BATTLE_SPRITE_SIZE[active_era() if species.is_empty() else species_era(species)]

## The era a species comes from (1 when unknown).
func species_era(species: String) -> int:
	var sd: SpirlingData = Database.species(species)
	if sd == null:
		sd = Database.species(species.capitalize())
	return clampi(sd.era, Era.INK, Era.PANORAMA) if sd != null else Era.INK

## Sprite for [param species] in the species' own era (not the world era), falling back to
## older eras when a file is missing.
func sprite_path(species: String, facing: String = "front") -> String:
	return art_path_from("spirlings/%s_%s.png" % [species.to_lower(), facing], species_era(species))

## res:// path of [param rel] (relative to art/eraN/) in the active era, walking back to
## older eras when the file is missing. Empty when no era has it.
func art_path(rel: String) -> String:
	return art_path_from(rel, active_era())

## Like art_path() but starting from era [param start].
func art_path_from(rel: String, start: int) -> String:
	for era: int in range(start, 0, -1):
		var path: String = "res://art/era%d/%s" % [era, rel]
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""

## Era IV render path (design plan 331-333): from Panorama on, battles stand on the 2.5D stage.
const STAGE_25D_FROM: int = Era.PANORAMA
const STAGE_PATH: String = "res://data/era4_stage.json"
var _stage_cfg: Dictionary = {}

func uses_stage_25d() -> bool:
	return active_era() >= STAGE_25D_FROM

## data/era4_stage.json, loaded once.
func stage_config() -> Dictionary:
	if _stage_cfg.is_empty():
		var f: FileAccess = FileAccess.open(STAGE_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_stage_cfg = d
	return _stage_cfg

func to_dict() -> Dictionary:
	return {"unlocked_era": unlocked_era, "retro_filter": retro_filter}

func from_dict(d: Dictionary) -> void:
	unlocked_era = clampi(int(d.get("unlocked_era", Era.INK)), Era.INK, Era.PANORAMA)
	retro_filter = clampi(int(d.get("retro_filter", 0)), 0, unlocked_era)
	_apply()

func _apply() -> void:
	var era: int = active_era()
	if is_inside_tree():
		get_window().content_scale_size = RESOLUTION[era]
	if _filter_rect != null:
		_filter_rect.visible = era == Era.INK
	_clear_art_caches()
	era_changed.emit(era)

func _clear_art_caches() -> void:
	TilesetFactory.clear_cache()
	GridWalker.clear_cache()
	ElementFx.clear_cache()
