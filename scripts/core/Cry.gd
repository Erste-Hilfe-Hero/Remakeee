class_name Cry
extends RefCounted
## Spirling cries (item 70), synthesized at runtime so each species gets its own call with no
## audio files. The shape comes from a hash of the species name; size and element nudge it:
## big Spirlings call lower and longer, Volt buzzes, Tide warbles, Umbra growls, and so on.

const RATE: int = 22050
## Element index (Elements.E order) -> [pulse duty, vibrato depth, noise mix].
const ELEMENT_VOICE: Array = [
	[0.5, 0.02, 0.15],   # EMBER: bright with a little crackle
	[0.5, 0.06, 0.0],    # TIDE: warbling
	[0.25, 0.01, 0.05],  # BLOOM: soft
	[0.125, 0.0, 0.25],  # VOLT: thin and buzzy
	[0.5, 0.0, 0.2],     # STONE: blunt
	[0.25, 0.03, 0.1],   # GALE: airy
	[0.125, 0.015, 0.0], # LUMEN: clear and high
	[0.5, 0.04, 0.1],    # UMBRA: rough
]

static var _cache: Dictionary[String, AudioStreamWAV] = {}

## The cry of [param sd], built once and cached.
static func stream_for(sd: SpirlingData) -> AudioStreamWAV:
	if not _cache.has(sd.species_name):
		_cache[sd.species_name] = make(sd)
	return _cache[sd.species_name]

## Pitch, length and timbre for [param sd]: {"base": midi note, "segments": [[from, to, seconds]], ...}.
static func shape(sd: SpirlingData) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cry:" + sd.species_name)
	var st: int = BalanceSim.stage(sd)
	var base: float = rng.randf_range(66.0, 80.0) - (st - 1) * 5
	var segs: Array = []
	var n: int = rng.randi_range(2, 3)
	var note: float = base
	for i: int in n:
		var to: float = note + rng.randf_range(-7.0, 9.0)
		segs.append([note, to, rng.randf_range(0.07, 0.16) * (1.0 + 0.25 * (st - 1))])
		note = to + rng.randf_range(-3.0, 3.0)
	var el: int = sd.elements[0] if not sd.elements.is_empty() else 0
	var voice: Array = ELEMENT_VOICE[clampi(el, 0, ELEMENT_VOICE.size() - 1)]
	return {"base": base, "segments": segs, "duty": voice[0], "vibrato": voice[1], "noise": voice[2], "seed": rng.seed}

static func make(sd: SpirlingData) -> AudioStreamWAV:
	var sh: Dictionary = shape(sd)
	var data := PackedByteArray()
	var phase: float = 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = int(sh.seed)
	var t_total: float = 0.0
	for seg: Array in sh.segments:
		t_total += float(seg[2])
	var total: int = int(t_total * RATE)
	data.resize(total * 2)
	var idx: int = 0
	var noise_v: float = 0.0
	for seg: Array in sh.segments:
		var n: int = int(float(seg[2]) * RATE)
		for i: int in n:
			var k: float = float(i) / maxf(n - 1, 1)
			var t: float = float(idx) / RATE
			var m: float = lerpf(float(seg[0]), float(seg[1]), k) + float(sh.vibrato) * 12.0 * sin(t * TAU * 11.0)
			var f: float = 440.0 * pow(2.0, (m - 69.0) / 12.0)
			phase = fmod(phase + f / RATE, 1.0)
			var v: float = 1.0 if phase < float(sh.duty) else -1.0
			if idx % 4 == 0:
				noise_v = noise_rng.randf_range(-1.0, 1.0)
			v = v * (1.0 - float(sh.noise)) + noise_v * float(sh.noise)
			# Short fade at the start and end of the whole cry, slight dip between segments.
			var g: float = minf(1.0, idx / (RATE * 0.01)) * minf(1.0, (total - idx) / (RATE * 0.04))
			g *= 0.75 + 0.25 * sin(k * PI)
			var s: int = clampi(int(v * g * 0.35 * 32767.0), -32768, 32767)
			if idx < total:
				data.encode_s16(idx * 2, s)
			idx += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

static var _tones: Dictionary[String, AudioStreamWAV] = {}

## A short square-wave note (Echo call marks, item 279), cached per pitch, timbre and gain.
static func tone(midi: int, duty: float = 0.5, gain: float = 0.3, seconds: float = 0.22) -> AudioStreamWAV:
	var key: String = "%d:%.3f:%.2f:%.2f" % [midi, duty, gain, seconds]
	if _tones.has(key):
		return _tones[key]
	var total: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var f: float = 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	var phase: float = 0.0
	for i: int in total:
		phase = fmod(phase + f / RATE, 1.0)
		var v: float = 1.0 if phase < duty else -1.0
		var g: float = minf(1.0, i / (RATE * 0.005)) * minf(1.0, (total - i) / (RATE * 0.06))
		data.encode_s16(i * 2, clampi(int(v * g * gain * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_tones[key] = w
	return w
