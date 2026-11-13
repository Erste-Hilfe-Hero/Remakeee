extends Node
## Each region = a visual jump in the art style (Era I Ink -> IV Panorama), like an old map
## being redrawn: ink sketch, watercolour wash, fine etching, then a wide painted panorama.
## Owns the active era: internal resolution, palette filter, sprite set and the Retro filter choice.

signal era_changed(era: int)
## Emitted when a new region unlocks a newer era (item 48); the overworld shows a line for it.
signal era_unlocked(era: int)

enum Era { INK = 1, WASH = 2, ETCHED = 3, PANORAMA = 4, LIVING = 5 }
const NEWEST: int = Era.LIVING
## The whole story (all four regions) stays Era I. Era II opens after the finale and is the
## look of the post-game region Vellmarch (data/region2.json); Era III opens after Vellmarch's finale
## with Quillmarch (data/region3.json); later eras arrive with their own new regions.
const REGION_ERA: Dictionary[String, int] = {"veydal": Era.INK, "corvane": Era.INK, "ashmere": Era.INK, "solenne": Era.INK, "vellmarch": Era.WASH, "quillmarch": Era.ETCHED}
const STORY_COMPLETE_FLAG: String = "story_complete"
const RESOLUTION: Dictionary[int, Vector2i] = {Era.INK: Vector2i(144, 256), Era.WASH: Vector2i(144, 256), Era.ETCHED: Vector2i(180, 320), Era.PANORAMA: Vector2i(270, 480), Era.LIVING: Vector2i(270, 480)}
const BATTLE_SPRITE_SIZE: Dictionary[int, int] = {Era.INK: 56, Era.WASH: 56, Era.ETCHED: 64, Era.PANORAMA: 96, Era.LIVING: 96}
## Era I: four cartographer's inks on parchment (original values, darkest to lightest). Deliberately
## not the green four-shade look of old handheld screens.
const INK_PALETTE: Array[Color] = [Color("2a1e2c"), Color("6a4256"), Color("c48a5e"), Color("f2e3c2")]
const FILTER_LAYER: int = 100
const PALETTE_SHADER: Shader = preload("res://shaders/palette_filter.gdshader")

var unlocked_era: int = Era.INK
## Region of the map on screen; picks the Era I inks (RegionLook), e.g. Corvane's dye fens.
var current_region: String = ""
var retro_filter: int = 0   # 0 = use newest unlocked era

var _filter_layer: CanvasLayer
var _filter_rect: ColorRect
## Window size and safe area last fitted (ScreenFit); a change means a fold, unfold or turn.
var _screen_seen: Array = []

func _ready() -> void:
	_filter_layer = CanvasLayer.new()
	_filter_layer.layer = FILTER_LAYER
	add_child(_filter_layer)
	_filter_rect = ColorRect.new()
	_filter_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	_filter_rect.material = mat
	_apply_inks()
	_filter_layer.add_child(_filter_rect)
	_apply()

## Watches the window: a foldable opening or closing changes its size and safe area while
## the game runs. In "keep" mode the view's size may not change with it, so the UI is told
## through the root's size_changed all the same (SafeArea, VirtualPad, MenuHost listen).
func _process(_delta: float) -> void:
	var w: Window = get_window()
	var seen: Array = [w.size, DisplayServer.get_display_safe_area()]
	if seen == _screen_seen:
		return
	var first: bool = _screen_seen.is_empty()
	_screen_seen = seen
	if first:
		return
	var vp_before: Vector2 = w.get_visible_rect().size
	ScreenFit.apply(w, RESOLUTION[active_era()])
	if w.get_visible_rect().size == vp_before:
		w.size_changed.emit()

func active_era() -> int:
	return retro_filter if retro_filter > 0 else unlocked_era

## Lines shown when an era opens up for the first time.
const ERA_LINES: Dictionary[int, String] = {
	Era.WASH: "The last line of the map is drawn. The ink runs and spreads, and the world fills with colour!",
	Era.ETCHED: "The air grows sharper. Every leaf and stone shows more detail!",
	Era.PANORAMA: "The map unrolls wider than ever. The whole horizon opens before you!",
	Era.LIVING: BattleAnim.UNLOCK_LINE,
}
const TRANSITION_TIME: float = 0.9
var _wipe: ColorRect

## The four Era I inks on screen for [param region]: its own look or the base Ink palette.
func inks_for(region: String) -> Array[Color]:
	var own: Array[Color] = RegionLook.palette(region)
	return own if own.size() == INK_PALETTE.size() else INK_PALETTE

## Called when a map of [param region] is shown; swaps the screen inks to that region's look.
func set_region(region: String) -> void:
	current_region = region
	_apply_inks()

func _apply_inks() -> void:
	if _filter_rect == null:
		return
	var inks: Array[Color] = inks_for(current_region)
	for i: int in inks.size():
		_filter_rect.material.set_shader_parameter("c%d" % i, inks[i])

func unlock_region(region: String) -> void:
	unlock_era(region_era(region))

## Era of [param region]: the story regions from REGION_ERA, post-game regions from
## data/eras.json "regions" (Halcyra, data/region4.json = Era IV), so a new era region needs no
## code change.
static func region_era(region: String) -> int:
	if REGION_ERA.has(region):
		return REGION_ERA[region]
	var f: FileAccess = FileAccess.open(ERAS_PATH, FileAccess.READ)
	if f == null:
		return Era.INK
	var d: Variant = JSON.parse_string(f.get_as_text())
	var regions: Dictionary = d.get("regions", {}) if d is Dictionary else {}
	return clampi(int(regions.get(region, Era.INK)), Era.INK, NEWEST)

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

## data/eras.json "finale_flags": era flag -> the content flag whose finale sets it (Era II
## finale = Vellmarch chapter 5). Sets each era flag once its source flag is set.
static func mark_finales(flags: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(ERAS_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	var m: Dictionary = d.get("finale_flags", {})
	for era_flag: String in m:
		if bool(flags.get(str(m[era_flag]), false)):
			flags[era_flag] = true

## Unlocks every era whose flag is set. Eras open in order: a later flag does nothing while
## an earlier era is still locked.
func unlock_from_flags(has_flag: Callable) -> void:
	var flags: Dictionary = unlock_flags()
	for e: int in range(Era.WASH, NEWEST + 1):
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

## Era transition (item 48): the era-change sequence (EraUpgrade, docs/ERA_FEEL_UI.md). The
## screen switches to the new era at once and an overlay shows the old era's look on top that
## gives way the era's own way (colour spreading from the Wayfarer, lines sharpening, the map
## unrolling, the map breathing), with the era jingle and a caption. With reduced motion it is
## the plain light fade.
func play_transition(to_era: int = 0) -> void:
	var to: int = to_era if to_era > 0 else active_era()
	if not Juice.reduced() and to >= Era.WASH and get_tree() != null:
		GameState.set_flag(EraFeel.SEEN_FLAG % to)
		_apply()
		var seq := EraUpgrade.new()
		seq.setup(to - 1, to, inks_for(current_region), upgrade_center)
		get_tree().root.add_child(seq)
		return
	if to >= Era.WASH:
		GameState.set_flag(EraFeel.SEEN_FLAG % to)
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

## Where the era-change colour spreads from, in screen pixels (the overworld sets the
## Wayfarer's spot); the screen centre when unset.
var upgrade_center: Vector2 = Vector2(-1, -1)

## Seconds the overworld waits before it shows an era line after a transition.
func transition_wait() -> float:
	return EraUpgrade.TIME if not Juice.reduced() else TRANSITION_TIME

## Value of [param key] in data/era_feel.json for the active era (EraFeel).
func feel(key: String) -> Variant:
	return EraFeel.value(active_era(), key)

## Plays the era-change sequence of the era of [param region] when it is owed (an era opened
## by an older save, before the sequence existed). True when it starts.
func upgrade_for_region(region: String) -> bool:
	var e: int = region_era(region)
	if retro_filter != 0 or not EraFeel.upgrade_due(e, active_era(), unlocked_era, GameState.has_flag):
		return false
	play_transition(e)
	return true

## Settings: shows the change into the era on screen once more. False on Era I.
func replay_upgrade() -> bool:
	if active_era() < Era.WASH or not is_inside_tree():
		return false
	play_transition(active_era())
	return true

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
	return clampi(sd.era, Era.INK, NEWEST) if sd != null else Era.INK

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

## Stage colours for [param region]: data/era4_stage.json "colors" with the region's own
## "stage" colours from data/region_looks.json on top (Halcyra's golden hour).
## [param terrain] (the battle backdrop: lake, ridge, ember ...) tints the stage between the two
## (data/era_battle_feel.json "stage_terrain"), so a lake fight stands on water-blue ground.
func stage_colors(region: String, terrain: String = "") -> Dictionary:
	var out: Dictionary = (stage_config().get("colors", {}) as Dictionary).duplicate()
	if not terrain.is_empty():
		out.merge(EraBattleFeel.stage_terrain(terrain), true)
	out.merge(RegionLook.look(region).get("stage", {}), true)
	return out

## Battle presentation value [param key] of the active era (data/era_battle_feel.json):
## intro wipe, entrance, idle level, art tier, camera ... See EraBattleFeel.
func battle_feel(key: String, fallback: Variant = null) -> Variant:
	return EraBattleFeel.value(active_era(), key, fallback)

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
	unlocked_era = clampi(int(d.get("unlocked_era", Era.INK)), Era.INK, NEWEST)
	retro_filter = clampi(int(d.get("retro_filter", 0)), 0, unlocked_era)
	_apply()

func _apply() -> void:
	var era: int = active_era()
	if is_inside_tree():
		ScreenFit.apply(get_window(), RESOLUTION[era])
	if _filter_rect != null:
		_filter_rect.visible = era == Era.INK
	EraText.set_era(era)
	UITheme.set_era_skin(EraFeel.palette(era), str(EraFeel.value(era, "frame")), str(EraFeel.value(era, "font")) == "large")
	GridWalker.walk_frames = int(EraFeel.value(era, "walk_frames"))
	GridWalker.breathe = bool(EraFeel.value(era, "idle_breathe"))
	if is_inside_tree():
		MenuHost.refresh_all_themes(get_tree())
	_clear_art_caches()
	era_changed.emit(era)

func _clear_art_caches() -> void:
	TilesetFactory.clear_cache()
	GridWalker.clear_cache()
	ElementFx.clear_cache()
