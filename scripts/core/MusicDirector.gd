extends Node
## Autoload "MusicDirector": place songs as four stems played in sync, each with its own volume
## (items 2475 to 2479). Sound.music() stays the public way to start music; when a track has
## stems in audio/music/stems/, Sound plays the synchronized stream built here and this node
## fades the layers:
##   world:    standing = bass + chords, walking adds the melody, running adds the drums
##   dialogue: melody and drums drop to -12 dB while a text box is open
##   battle:   (Era V battle songs, data/era_audio.json "battle_layers") intensity 0 = bass +
##             chords, 1 adds the melody, 2 adds the drums (Sound.battle_state)
## Every layer change fades over FADE_TIME.

const STEM_DIR: String = "res://audio/music/stems/%s_%s.ogg"
const STEMS: Array[String] = ["bass", "chords", "melody", "drums"]
const FADE_TIME: float = 0.8
const DIALOGUE_DB: float = -12.0
const SILENT_DB: float = -80.0
## Standing still this long counts as idle (single steps do not drop the melody).
const IDLE_AFTER: float = 0.4

enum Motion { IDLE, WALK, RUN, FULL }

var motion: Motion = Motion.FULL
const FULL_INTENSITY: int = 2
## True while the active track is a battle song; its layers follow [member intensity].
var battle: bool = false
var intensity: int = FULL_INTENSITY
var dialogue: bool = false
## Current linear gain per stem (0..1), eased toward target_gains().
var gains: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1])
var _active: AudioStreamSynchronized
var _still: float = 0.0
var _cache: Dictionary[String, AudioStreamSynchronized] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func has_stems(track: String) -> bool:
	return not track.is_empty() and ResourceLoader.exists(STEM_DIR % [track, STEMS[0]])

## A synchronized stream of [param track]'s four stems (looping), or null without stems.
func stream_for(track: String) -> AudioStreamSynchronized:
	if not has_stems(track):
		return null
	if not _cache.has(track):
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = STEMS.size()
		for i: int in STEMS.size():
			var path: String = STEM_DIR % [track, STEMS[i]]
			var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
			if st is AudioStreamOggVorbis:
				st = st.duplicate()
				(st as AudioStreamOggVorbis).loop = true
			sync.set_sync_stream(i, st)
		_cache[track] = sync
	return _cache[track]

## Battle songs: "battle..." and "warden..." in any era.
static func is_battle_track(track: String) -> bool:
	return track.begins_with("battle") or track.begins_with("warden")

## Called by Sound when [param track] starts ([param stream] null for a plain track). A new fight
## opens at intensity 0; the pinch switch inside a fight keeps the intensity.
func set_active(stream: AudioStream, track: String = "") -> void:
	var was_battle: bool = battle
	battle = is_battle_track(track)
	if battle and not was_battle:
		intensity = 0
	_active = stream as AudioStreamSynchronized
	gains = target_gains()
	_apply()

func active() -> AudioStreamSynchronized:
	return _active

## Overworld feed: whether the Wayfarer is moving and running this frame.
func update_world(moving: bool, running: bool, delta: float) -> void:
	_still = 0.0 if moving else _still + delta
	if moving:
		motion = Motion.RUN if running else Motion.WALK
	elif _still >= IDLE_AFTER:
		motion = Motion.IDLE

func set_intensity(level: int) -> void:
	intensity = clampi(level, 0, FULL_INTENSITY)

## Target gain per stem for the current motion and dialogue state (battle: the intensity).
func target_gains() -> PackedFloat32Array:
	var g := PackedFloat32Array([1, 1, 1, 1])
	if battle:
		g[2] = 1.0 if intensity >= 1 else 0.0
		g[3] = 1.0 if intensity >= 2 else 0.0
		return g
	match motion:
		Motion.IDLE:
			g[2] = 0.0
			g[3] = 0.0
		Motion.WALK:
			g[3] = 0.0
	if dialogue:
		var dip: float = db_to_linear(DIALOGUE_DB)
		g[2] = minf(g[2], dip)
		g[3] = minf(g[3], dip)
	return g

func _process(delta: float) -> void:
	step(delta)

## Eases every stem toward its target (full swing in FADE_TIME) and applies the volumes.
func step(delta: float) -> void:
	var target: PackedFloat32Array = target_gains()
	var k: float = delta / FADE_TIME
	for i: int in gains.size():
		gains[i] = move_toward(gains[i], target[i], k)
	_apply()

func _apply() -> void:
	if _active == null:
		return
	for i: int in mini(gains.size(), _active.stream_count):
		_active.set_sync_stream_volume(i, linear_to_db(gains[i]) if gains[i] > 0.0001 else SILENT_DB)

## Volume in dB of stem [param i] in the active stream (tests).
func stem_db(i: int) -> float:
	return _active.get_sync_stream_volume(i) if _active != null else SILENT_DB
