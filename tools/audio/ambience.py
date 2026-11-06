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


def loops() -> dict[str, np.ndarray]:
    return {name: build(name, s, seed) for name, (s, seed) in LOOPS.items()}
