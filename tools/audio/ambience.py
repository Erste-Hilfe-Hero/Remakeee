"""Ambience loops for the outdoor maps (plan area 6, items 2569 to 2573): one 30 to 45 s mono
loop per map, built from filtered noise and short tone figures written for Chimora. No
recordings. Each loop has its own seeded generator and starts and ends on the same swell
phase, so the seam does not click. gen_audio.py writes them to audio/ambience/<name>.ogg."""
from __future__ import annotations

import numpy as np

from synth import RATE, env, freq, midi, noise, pulse, secs, sweep, triangle


def lowpass(x: np.ndarray, k: int) -> np.ndarray:
    """Moving average over [k] samples (a soft low-pass), same length, wraps at the seam."""
    if k <= 1:
        return x
    pad = np.concatenate([x[-k:], x])
    c = np.cumsum(pad)
    return (c[k:] - c[:-k]) / k


def highpass(x: np.ndarray, k: int) -> np.ndarray:
    return x - lowpass(x, k)


def _place(out: np.ndarray, sound: np.ndarray, at: int) -> None:
    end = min(len(out), at + len(sound))
    out[at:end] += sound[:end - at]


def _swell(n: int, period: float, depth: float = 0.7) -> np.ndarray:
    """Slow rise and fall with a whole number of periods in [n], so the loop meets itself."""
    cycles = max(1, round(n / RATE / period))
    ph = np.arange(n) / n * cycles * 2 * np.pi
    return (1 - depth) + depth * (0.5 - 0.5 * np.cos(ph))


def _events(rng: np.random.Generator, n: int, every: float, margin: float = 1.0) -> list[int]:
    """Start samples for rare sounds, about one per [every] seconds, kept off the seam."""
    out, t = [], margin + rng.uniform(0, every)
    while t < n / RATE - margin - 1.0:
        out.append(int(t * RATE))
        t += every * rng.uniform(0.6, 1.4)
    return out


def gull(rng: np.random.Generator) -> np.ndarray:
    """A two-part falling whistle (not a recording of a real bird)."""
    parts = []
    for f0, f1, d in [(1500, 1100, 0.12), (1350, 900, 0.18)]:
        k = secs(d * rng.uniform(0.9, 1.1))
        parts.append(sweep(f0, f1, k, "tri") * env(k, attack=0.01, decay=0.05, sustain=0.6, release=0.04))
        parts.append(np.zeros(secs(0.05)))
    return np.concatenate(parts)


def chirp(rng: np.random.Generator) -> np.ndarray:
    notes = rng.choice(["E6", "G6", "A6", "C7", "D7"], size=int(rng.integers(2, 5)))
    parts = []
    for nm in notes:
        k = secs(0.04)
        parts.append(pulse(freq(midi(str(nm))), k, 0.25) * env(k, attack=0.002, decay=0.02, sustain=0.3, release=0.01))
        parts.append(np.zeros(secs(0.03)))
    return np.concatenate(parts)


def bell(rng: np.random.Generator) -> np.ndarray:
    k = secs(1.2)
    f = freq(midi(str(rng.choice(["G5", "B5", "D6"]))))
    return (triangle(f, k) * 0.6 + triangle(f * 2.01, k) * 0.25) * np.exp(-np.arange(k) / RATE * 3.0)


def frog(rng: np.random.Generator) -> np.ndarray:
    parts = []
    for _ in range(int(rng.integers(2, 4))):
        k = secs(0.07)
        parts.append(sweep(220, 150, k, "pulse", 0.5) * env(k, attack=0.005, decay=0.03, sustain=0.4, release=0.02))
        parts.append(np.zeros(secs(0.08)))
    return np.concatenate(parts)


def cricket(n: int) -> np.ndarray:
    t = np.arange(n) / RATE
    gate = (np.sin(t * 2 * np.pi * 28) > 0.6) * (np.sin(t * 2 * np.pi * 0.8) > -0.2)
    return pulse(4200, n, 0.5) * gate


def build(name: str, seconds: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    loop = secs(seconds)
    seam = secs(0.25)
    # Built a little longer than the loop; the extra tail is crossfaded into the start below.
    n = loop + seam
    out = np.zeros(n)
    sw = lambda period, depth: np.resize(_swell(loop, period, depth), n)
    if name == "sea":  # lighthouse (2571): swell every 6 s plus rare gull-like whistles
        out += lowpass(noise(n, 1, rng), 12) * sw(6.0, 0.85) * 0.9
        for at in _events(rng, loop, 9.0):
            _place(out, gull(rng) * 0.25, at)
    elif name == "market":  # brindlewick (2572): murmur from band-limited noise, now and then a bell
        murmur = highpass(lowpass(noise(n, 1, rng), 20), 120)
        out += murmur * (0.7 + 0.3 * lowpass(rng.uniform(-1, 1, n), 4000) * 3) * 1.2
        for at in _events(rng, loop, 12.0):
            _place(out, bell(rng) * 0.2, at)
    elif name == "ferns":  # fernstair (2573): high wind through ferns plus short chirps
        out += highpass(noise(n, 1, rng), 6) * sw(8.0, 0.6) * 0.35
        for at in _events(rng, loop, 4.0):
            _place(out, chirp(rng) * 0.2, at)
    elif name == "cliffs":  # crowcrest (2574): steady wind, a strong gust every 8 to 15 s
        out += lowpass(noise(n, 1, rng), 40) * sw(5.0, 0.4) * 1.2
        t = 2.0
        while t < loop / RATE - 4.0:
            k = secs(rng.uniform(1.8, 3.0))
            _place(out, lowpass(noise(k, 1, rng), 18) * np.sin(np.linspace(0, np.pi, k)) ** 2 * 1.8, secs(t))
            t += rng.uniform(8.0, 15.0)
        for at in _events(rng, loop, 14.0):
            _place(out, gull(rng) * 0.15, at)
    elif name == "marsh":  # saltmarsh: lapping water and frogs
        out += lowpass(noise(n, 1, rng), 25) * sw(2.5, 0.5) * 0.9
        for at in _events(rng, loop, 5.0):
            _place(out, frog(rng) * 0.18, at)
        for at in _events(rng, loop, 2.5):  # still-water glugs (2575)
            k = secs(0.04)
            _place(out, sweep(260, 620, k, "tri") * env(k, attack=0.003, decay=0.02, sustain=0.3, release=0.01) * 0.12, at)
    elif name == "meadow":  # thornridge: leaves and crickets
        out += highpass(lowpass(noise(n, 1, rng), 8), 60) * sw(7.0, 0.5) * 0.6
        out += cricket(n) * 0.04
    else:
        raise KeyError(name)
    # The sample after the loop's last one is out[loop]; fading that tail into the start makes
    # the jump from the end back to sample 0 continuous (clean loop point).
    fade = np.linspace(0, 1, seam)
    # Gentle soft clip so rare peaks do not hold the loudness target down.
    out = np.tanh(out / (np.percentile(np.abs(out), 99.5) or 1.0)) * 0.5
    head = out[:loop].copy()
    head[:seam] = out[:seam] * fade + out[loop:] * (1 - fade)
    return head


## name: (seconds, seed); every loop is 30 to 45 s (item 2569).
LOOPS: dict[str, tuple[float, int]] = {
    "sea": (36.0, 11),
    "market": (40.0, 12),
    "ferns": (32.0, 13),
    "cliffs": (35.0, 14),
    "marsh": (42.0, 15),
    "meadow": (30.0, 16),
}


## All ambience together stays under this size (item 2586); gen_audio.py checks it.
MAX_BYTES = 2_500_000


def _room(x: np.ndarray, base: float, gain: float) -> np.ndarray:
    """Small Schroeder room on a loop buffer (four combs), added to the dry signal."""
    wet = np.zeros_like(x)
    for k, g in zip((1.0, 1.13, 1.27, 1.41), (0.7, 0.68, 0.66, 0.64)):
        d = max(1, int(base * k * RATE))
        y = x.copy()
        for i in range(d, len(y), d):
            j = min(i + d, len(y))
            y[i:j] += g * y[i - d:j - d]
        wet += y - x
    return x + lowpass(wet, 3) * 0.25 * gain


def footfalls(rng: np.random.Generator) -> np.ndarray:
    """A few passers-by on cobbles: soft knocks two to the second."""
    parts = []
    for _ in range(int(rng.integers(4, 8))):
        k = secs(0.04)
        parts.append(sweep(160, 90, k, "tri") * env(k, attack=0.001, decay=0.015, sustain=0.1, release=0.01))
        parts.append(np.zeros(secs(rng.uniform(0.22, 0.3))))
    return np.concatenate(parts)


def far_call(rng: np.random.Generator) -> np.ndarray:
    """A distant Spirling-like call: a slow two-part glide with vibrato (no real animal)."""
    k = secs(rng.uniform(0.5, 0.8))
    t = np.arange(k) / RATE
    f0 = rng.uniform(380, 620)
    fs = np.geomspace(f0, f0 * rng.uniform(0.7, 1.4), k) * 2 ** (0.3 * np.sin(2 * np.pi * 5 * t) / 12)
    ph = np.cumsum(fs / RATE)
    w = np.sin(2 * np.pi * ph) + 0.3 * np.sin(4 * np.pi * ph)
    return w * np.sin(np.linspace(0, np.pi, k)) ** 2


def buzz(n: int, rng: np.random.Generator) -> np.ndarray:
    """Marsh insects: a thin whine that drifts in pitch and comes and goes."""
    t = np.arange(n) / RATE
    ph = np.cumsum((520 + 40 * np.sin(2 * np.pi * 0.13 * t)) / RATE)
    gate = np.clip(np.sin(2 * np.pi * 0.07 * t + rng.uniform(0, 6)) * 2 - 0.5, 0, 1)
    return np.sin(2 * np.pi * ph) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t)) * gate


def build_era(name: str, seconds: float, seed: int) -> np.ndarray:
    """Era IV and V biome loops (town, route, marsh) for the outdoor maps of Halcyra and
    Quivermoor (data/era_audio.json "ambience"). Era IV: the place in a room reverb. Era V: more
    layers and events (birds, far calls, wind chimes, insects) and a wider hall."""
    rng = np.random.default_rng(seed)
    biome, era = name.rsplit("_era", 1)
    era = int(era)
    loop = secs(seconds)
    seam = secs(0.25)
    n = loop + seam
    out = np.zeros(n)
    sw = lambda period, depth: np.resize(_swell(loop, period, depth), n)
    if biome == "town":
        murmur = highpass(lowpass(noise(n, 1, rng), 18), 140)
        out += murmur * sw(9.0, 0.4) * 1.1
        for at in _events(rng, loop, 7.0):
            _place(out, footfalls(rng) * 0.2, at)
        for at in _events(rng, loop, 15.0):
            _place(out, bell(rng) * 0.15, at)
        if era >= 5:
            for at in _events(rng, loop, 5.0):
                _place(out, chirp(rng) * 0.12, at)
            for at in _events(rng, loop, 11.0):  # wind chimes
                for i, nm in enumerate(rng.choice(["E6", "G6", "B6", "D7"], size=3)):
                    k = secs(0.6)
                    _place(out, triangle(freq(midi(str(nm))), k) * np.exp(-np.arange(k) / RATE * 5) * 0.06, at + secs(0.15 * i))
    elif biome == "route":
        out += lowpass(noise(n, 1, rng), 30) * sw(6.0, 0.6) * 0.9
        out += highpass(noise(n, 1, rng), 5) * sw(11.0, 0.5) * 0.12
        for at in _events(rng, loop, 3.5 if era == 4 else 2.2):
            _place(out, chirp(rng) * 0.18, at)
        if era >= 5:
            out += cricket(n) * 0.03
            for at in _events(rng, loop, 9.0):
                _place(out, far_call(rng) * 0.07, at)
            t = 3.0
            while t < loop / RATE - 4.0:  # gusts through leaves
                k = secs(rng.uniform(1.5, 2.5))
                _place(out, highpass(noise(k, 1, rng), 4) * np.sin(np.linspace(0, np.pi, k)) ** 2 * 0.5, secs(t))
                t += rng.uniform(7.0, 12.0)
    elif biome == "marsh":
        out += lowpass(noise(n, 1, rng), 25) * sw(3.0, 0.5) * 0.8
        for at in _events(rng, loop, 4.5 if era == 4 else 3.0):
            _place(out, frog(rng) * 0.16, at)
        for at in _events(rng, loop, 2.0):
            k = secs(0.05)
            _place(out, sweep(240, 640, k, "tri") * env(k, attack=0.003, decay=0.02, sustain=0.3, release=0.01) * 0.1, at)
        if era >= 5:
            out += buzz(n, rng) * 0.02
            for at in _events(rng, loop, 6.0):
                _place(out, highpass(noise(secs(0.3), 1, rng), 3) * np.sin(np.linspace(0, np.pi, secs(0.3))) * 0.18, at)
    else:
        raise KeyError(name)
    out = _room(out, 0.04 if era == 4 else 0.07, 0.8 if era == 4 else 1.2)
    fade = np.linspace(0, 1, seam)
    out = np.tanh(out / (np.percentile(np.abs(out), 99.5) or 1.0)) * 0.5
    head = out[:loop].copy()
    head[:seam] = out[:seam] * fade + out[loop:] * (1 - fade)
    return head


## Era IV and V biome loops: name: (seconds, seed).
ERA_LOOPS: dict[str, tuple[float, int]] = {
    "town_era4": (30.0, 41), "route_era4": (32.0, 42), "marsh_era4": (34.0, 43),
    "town_era5": (30.0, 51), "route_era5": (32.0, 52), "marsh_era5": (34.0, 53),
}


def loops() -> dict[str, np.ndarray]:
    out = {name: build(name, s, seed) for name, (s, seed) in LOOPS.items()}
    out.update({name: build_era(name, s, seed) for name, (s, seed) in ERA_LOOPS.items()})
    return out
