"""Era sound sets (docs/ERA_FEEL_AUDIO.md): the same menu, world and battle sounds played on
each era's handheld sound hardware, written for Chimora from note recipes, no samples.

  Era I    four chip channels: two pulses, a 4-bit wave, noise; dry and short
  Era II   the same chip, richer arrangement: vibrato, a second pulse in harmony, an echo voice
  Era III  low-rate sample voices (band-limited tones held at about 11 kHz), more voices at once
  Era IV   clean sample voices with bell overtones, a room reverb and stereo
  Era V    Era IV plus layered octaves, air noise, a long hall and longer tails

Era I reuses the older files in audio/sfx (select.wav, ...) and only adds the keys that did not
exist (bond, evolve, low_hp). Later eras write <key>_era<N>.wav. Each era has its own seeded
noise source so the older effects in sfx.py keep their bytes. data/era_audio.json maps the keys
to these files; Sound.gd resolves them for the active era."""
from __future__ import annotations

import numpy as np

from synth import RATE, env, freq, midi, noise, pulse, secs, sweep, triangle

ERAS = (1, 2, 3, 4, 5)
## Keys every era defines (data/era_audio.json "sfx_keys" must list the same).
KEYS = ["select", "confirm", "cancel", "blip", "bump", "door_open", "door_close", "stairs_up", "stairs_down",
        "heal", "level_up", "bond", "faint", "low_hp", "evolve"]
## Era I keys that already exist as older files (sfx.py); the rest are new for every era.
ERA1_EXISTING = {"select", "confirm", "cancel", "blip", "bump", "door_open", "door_close", "stairs_up",
                 "stairs_down", "heal", "level_up", "faint"}
GROUNDS = ["grass", "path", "wood", "sand", "stone", "shore"]

# Pitched recipes: (note or (from, to) glide, seconds). None is a rest.
TONES = {
    "select": [("E6", 0.035)],
    "confirm": [("A5", 0.045), ("E6", 0.045)],
    "cancel": [(("A5", "D5"), 0.09)],
    "blip": [("A5", 0.015)],
    "heal": [("C5", 0.07), ("E5", 0.07), ("G5", 0.07), ("C6", 0.07)],
    "level_up": [("G4", 0.08), ("C5", 0.08), ("E5", 0.08), ("G5", 0.08), ("E5", 0.08), ("G5", 0.3)],
    # The bond jingle: a short own fanfare that settles on the octave.
    "bond": [("C5", 0.08), ("G4", 0.08), ("C5", 0.08), ("E5", 0.08), ("G5", 0.12), (None, 0.04), ("C6", 0.34)],
    # Unfolding: three rising arpeggios, each a step higher, then a held top note.
    "evolve": [("D5", 0.06), ("F#5", 0.06), ("A5", 0.06), ("D6", 0.06), ("E5", 0.06), ("G#5", 0.06), ("B5", 0.06),
               ("E6", 0.06), ("A5", 0.08), ("C#6", 0.08), ("E6", 0.08), ("A6", 0.45)],
    "faint": [(("G5", "C3"), 0.5)],
    # The low-health alarm: two short high tones; Sound repeats it while Vigor is low.
    "low_hp": [("F#6", 0.05), (None, 0.025), ("C#6", 0.05)],
}
# Jingles get a harmony voice from Era II on (the richer arrangement).
JINGLES = {"heal", "level_up", "bond", "evolve"}
# Sounds that repeat fast (cursor, text blip): no echo, only a small room.
SHORT = {"select", "blip"}


def _vib_phase(f0: float, f1: float, n: int, depth: float) -> np.ndarray:
    fs = np.geomspace(max(f0, 1), max(f1, 1), n)
    t = np.arange(n) / RATE
    amt = np.clip((t - 0.03) / 0.05, 0.0, 1.0) * depth
    return np.cumsum(fs * 2 ** (amt * np.sin(2 * np.pi * 6.0 * t) / 12.0) / RATE)


def _additive(ph: np.ndarray, f: float, harmonics: int, odd: bool = False) -> np.ndarray:
    out = np.zeros(len(ph))
    for k in range(1, harmonics + 1):
        if odd and k % 2 == 0:
            continue
        if f * k > RATE / 2.4:
            break
        out += np.sin(2 * np.pi * k * ph) / k
    return out * 0.7


def _hold(x: np.ndarray, step: int) -> np.ndarray:
    """Sample-and-hold: plays [x] at RATE / [step], like a low-rate sample."""
    return np.repeat(x[::step], step)[:len(x)] if step > 1 else x


def _lowpass(x: np.ndarray, k: int) -> np.ndarray:
    if k <= 1:
        return x
    c = np.cumsum(np.concatenate([np.zeros(k), x]))
    return (c[k:] - c[:-k]) / k


def _comb(x: np.ndarray, d: int, g: float) -> np.ndarray:
    y = x.copy()
    for i in range(d, len(y), d):
        j = min(i + d, len(y))
        y[i:j] += g * y[i - d:j - d]
    return y


def _room(x: np.ndarray, base: float, tail: float, gain: float) -> np.ndarray:
    """Dry signal with a small Schroeder room ([base] s comb delay), padded by [tail] s."""
    x = np.concatenate([x, np.zeros(secs(tail))])
    wet = np.zeros_like(x)
    for k, g in zip((1.0, 1.13, 1.27, 1.41), (0.7, 0.68, 0.66, 0.64)):
        wet += _comb(x, max(1, int(base * k * RATE)), g) - x
    return x + _lowpass(wet, 3) * 0.25 * gain


def voice(era: int, f0: float, f1: float, n: int, harm: bool = False) -> np.ndarray:
    """One note (or glide) of [n] samples in the voice of [era]."""
    if era == 1:
        return sweep(f0, f1, n, "pulse", 0.25) * env(n, decay=0.03, sustain=0.6, release=0.01)
    if era == 2:
        ph = _vib_phase(f0, f1, n, 0.25) % 1.0
        duty = 0.5 if harm else np.where(np.arange(n) < n // 3, 0.125, 0.25)
        return np.where(ph < duty, 1.0, -1.0) * env(n, attack=0.002, decay=0.04, sustain=0.55, release=0.015)
    ph = _vib_phase(f0, f1, n, 0.2 if era >= 4 else 0.15)
    w = _additive(ph, max(f0, f1), 6 if era == 3 else 9, odd=harm)
    if era >= 4:
        t = np.arange(n) / RATE
        w += 0.3 * np.sin(2 * np.pi * 2 * ph + 1.6 * np.sin(2 * np.pi * 3.5 * ph)) * np.exp(-t * 8)
    if era >= 5:
        w += 0.35 * np.sin(np.pi * ph)
    w = w * env(n, attack=0.004, decay=0.06, sustain=0.6, release=min(0.03, n / RATE / 3))
    return _hold(w, 2) if era == 3 else w


def tones(era: int, recipe: list, jingle: bool, rng: np.random.Generator, short: bool = False) -> np.ndarray:
    stretch = {1: 1.0, 2: 1.0, 3: 1.05, 4: 1.1, 5: 1.2}[era] if jingle else 1.0
    parts = []
    for note, d in recipe:
        n = secs(d * stretch)
        if note is None:
            parts.append(np.zeros(n))
            continue
        a, b = (note, note) if isinstance(note, str) else note
        f0, f1 = freq(midi(a)), freq(midi(b))
        w = voice(era, f0, f1, n)
        if jingle and era >= 2:
            # Harmony a sixth below (Era II: second pulse; later: a softer pad voice).
            w = w + voice(era, f0 * 0.5946, f1 * 0.5946, n, harm=True) * (0.35 if era == 2 else 0.45)
        if era >= 5 and n > secs(0.05):
            w = w + _lowpass(noise(n, 1, rng), 6) * env(n, attack=0.01, sustain=0.3) * 0.06
        parts.append(w)
    out = np.concatenate(parts)
    if era == 2 and not short:
        d = secs(0.06)
        out = np.concatenate([out, np.zeros(d)])
        out[d:] += out[:-d].copy() * 0.3
    return out


def thud(era: int, f0: float, f1: float, d: float, grit: float, rng: np.random.Generator) -> np.ndarray:
    """A blunt knock: falling body plus a little noise (bump, door, stair step)."""
    n = secs(d)
    if era == 1:
        body = sweep(f0, f1, n, "tri")
        nz = noise(n, 10, rng)
    elif era == 2:
        body = sweep(f0, f1, n, "tri")
        nz = noise(n, 6, rng)
    else:
        body = np.sin(2 * np.pi * np.cumsum(np.geomspace(f0, f1, n)) / RATE)
        body += 0.3 * np.sin(4 * np.pi * np.cumsum(np.geomspace(f0, f1, n)) / RATE)
        nz = _lowpass(noise(n, 1, rng), 8 if era == 3 else 4)
        if era == 3:
            nz = _hold(nz, 2)
    if era >= 5:
        body += 0.4 * np.sin(np.pi * np.cumsum(np.geomspace(f0, f1, n)) / RATE)
    return (body * 0.8 + nz * grit) * env(n, attack=0.001, decay=d * 0.4, sustain=0.25, release=d * 0.3)


def creak(era: int, d: float, rng: np.random.Generator) -> np.ndarray:
    """A door swinging open: wood hiss, a creak that rises, a low thump."""
    n = secs(d)
    swell = np.sin(np.linspace(0, np.pi, n))
    if era <= 2:
        cr = sweep(180, 260, n, "pulse", 0.125 if era == 1 else 0.25)
        if era == 2:
            cr = cr * (0.7 + 0.3 * np.sin(np.arange(n) / RATE * 2 * np.pi * 24))
        nz = noise(n, 10, rng)
    else:
        t = np.arange(n) / RATE
        ph = np.cumsum(np.geomspace(170, 280, n)) / RATE
        cr = _additive(ph, 280, 7) * (0.6 + 0.4 * (np.sin(t * 2 * np.pi * 31) > 0))
        nz = _lowpass(noise(n, 1, rng), 10)
        if era == 3:
            cr, nz = _hold(cr, 2), _hold(nz, 2)
    out = nz * 0.35 + cr * 0.18 * swell + thud(era, 110, 80, d, 0.0, rng) * 0.4
    if era >= 5:
        k = secs(0.012)  # the latch
        out[:k] += noise(k, 1, rng) * np.linspace(0.6, 0, k)
    return out * env(n, attack=0.01, decay=0.1, sustain=0.45, release=0.06)


def stairs(era: int, notes: list[str], rng: np.random.Generator) -> np.ndarray:
    parts = []
    for nm in notes:
        f = freq(midi(nm))
        step = thud(era, f, f * 0.9, 0.05, 0.3, rng) if era > 1 else \
            (triangle(f, secs(0.05)) * 0.5 + noise(secs(0.05), 4, rng) * 0.25) * env(secs(0.05), attack=0.001, decay=0.02, sustain=0.2, release=0.01)
        parts += [step, np.zeros(secs(0.025 if era < 5 else 0.04))]
    return np.concatenate(parts)


def heartbeat(rng: np.random.Generator) -> np.ndarray:
    """Era V low health: a soft double heartbeat instead of the beeping alarm."""
    a = thud(5, 70, 45, 0.11, 0.05, rng)
    return np.concatenate([a, np.zeros(secs(0.08)), a * 0.7, np.zeros(secs(0.05))])


def finish(era: int, x: np.ndarray, short: bool = False) -> np.ndarray:
    """Era IV room and Era V hall, both stereo (left dry-led, right a few ms later). [short]
    sounds (cursor, text blip) repeat fast, so they only get a small room."""
    if era < 4:
        return x
    base, tail, gain = (0.035, 0.12, 0.9) if era == 4 else (0.06, 0.22, 1.2)
    if short:
        base, tail, gain = 0.015, 0.04 if era == 4 else 0.06, 0.4
    left = _room(x, base, tail, gain)
    right = _room(x, base * 1.09, tail, gain)
    d = secs(0.009 if era == 4 else 0.014)
    right = np.concatenate([np.zeros(d), right])[:len(right)]
    return np.stack([left, right], axis=1)


def era_set(era: int) -> dict[str, np.ndarray]:
    rng = np.random.default_rng(9000 + era)
    out: dict[str, np.ndarray] = {}
    for key in KEYS:
        if era == 1 and key in ERA1_EXISTING:
            continue
        if key in TONES and not (key == "low_hp" and era == 5):
            x = tones(era, TONES[key], key in JINGLES, rng, key in SHORT)
        elif key == "low_hp":
            x = heartbeat(rng)
        elif key == "bump":
            x = thud(era, freq(midi("C3")), freq(midi("C3")) * 0.85, 0.06, 0.15 if era > 1 else 0.0, rng)
        elif key == "door_open":
            x = creak(era, 0.22 if era < 5 else 0.3, rng)
        elif key == "door_close":
            x = thud(era, 95, 55, 0.12 if era < 5 else 0.16, 0.45, rng)
        elif key == "stairs_up":
            x = stairs(era, ["C4", "E4", "G4"], rng)
        elif key == "stairs_down":
            x = stairs(era, ["G4", "E4", "C4"], rng)
        else:
            raise KeyError(key)
        out[key] = finish(era, x, key in SHORT)
    return out


def footsteps_era5() -> dict[str, np.ndarray]:
    """Era V steps per ground: fuller and a touch longer than the Era I to IV takes."""
    rng = np.random.default_rng(9505)
    out: dict[str, np.ndarray] = {}
    for take in (1, 2):
        n = secs(0.07 if take == 1 else 0.075)
        e = env(n, attack=0.001, decay=0.025, sustain=0.2, release=0.02)
        body = lambda f0, f1: np.sin(2 * np.pi * np.cumsum(np.geomspace(f0, f1, n)) / RATE)
        hiss = lambda k: _lowpass(noise(n, 1, rng), k)
        crunch = (rng.random(n) > 0.6)
        out["grass"] = (hiss(2) * crunch * 0.6 + body(150, 90) * 0.25) * e
        out["path"] = (hiss(4) * 0.5 + body(130, 70) * 0.45) * e
        knock = np.sin(2 * np.pi * (240 + 25 * take) * np.arange(n) / RATE) * np.exp(-np.arange(n) / RATE * 60)
        out["wood"] = (knock * 0.6 + hiss(6) * 0.2 + body(120, 80) * 0.3) * e
        out["sand"] = hiss(3) * crunch * np.sin(np.linspace(0, np.pi, n)) * 0.55
        click = np.sin(2 * np.pi * (1500 + 120 * take) * np.arange(n) / RATE) * np.exp(-np.arange(n) / RATE * 120)
        out["stone"] = (click * 0.35 + hiss(3) * 0.35 + body(160, 110) * 0.2) * e
        t = np.arange(n) / RATE
        out["shore"] = (hiss(5) * np.sin(np.linspace(0, np.pi, n)) * 0.45 +
                        np.sin(2 * np.pi * np.cumsum(np.geomspace(300, 700, n)) / RATE) * 0.12 * np.exp(-t * 40)) * \
            env(n, attack=0.004, decay=0.03, sustain=0.4, release=0.02)
        for g in GROUNDS:
            out["step_%s_%d_era5" % (g, take)] = _room(out.pop(g), 0.02, 0.03, 0.5)
    return out


def file_name(key: str, era: int) -> str:
    return key if era == 1 else "%s_era%d" % (key, era)


def sfx_defs() -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for era in ERAS:
        for key, data in era_set(era).items():
            out[file_name(key, era)] = data
    out.update(footsteps_era5())
    return out


def rate_of(name: str) -> int:
    """Sample rate a file is written at: Era III effects at half rate (low-rate samples)."""
    return RATE // 2 if name.endswith("_era3") else RATE


def downsample(name: str, data: np.ndarray) -> np.ndarray:
    return data[::RATE // rate_of(name)]
