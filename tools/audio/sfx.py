"""Chimora's sound effects (plan area 6, item 2609): every effect is built from the
oscillators in synth.py, no samples. They share one seeded noise source, so effects are always
synthesized in this order; add new ones at the end to keep the older files byte-identical."""
from __future__ import annotations

import numpy as np

from synth import RATE, env, freq, midi, noise, pulse, secs, sweep, triangle

def sfx_defs() -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    n = secs(0.035)
    out["select"] = pulse(freq(midi("E6")), n, 0.25) * env(n, decay=0.02, sustain=0.3, release=0.01) * 0.5
    n = secs(0.09)
    a = pulse(freq(midi("A5")), n // 2, 0.25)
    b = pulse(freq(midi("E6")), n - n // 2, 0.25)
    out["confirm"] = np.concatenate([a, b]) * env(n, sustain=0.5) * 0.5
    n = secs(0.09)
    out["cancel"] = sweep(freq(midi("A5")), freq(midi("D5")), n, "pulse", 0.5) * env(n, sustain=0.5) * 0.45
    n = secs(0.06)
    out["bump"] = triangle(freq(midi("C3")), n) * env(n, sustain=0.4) * 0.8
    n = secs(0.12)
    out["hit"] = (noise(n, 3) * 0.7 + sweep(300, 80, n, "pulse", 0.5) * 0.3) * env(n, decay=0.05, sustain=0.25) * 0.8
    n = secs(0.22)
    out["hit_strong"] = (noise(n, 2) * 0.6 + sweep(600, 60, n, "pulse", 0.25) * 0.4) * env(n, decay=0.1, sustain=0.4) * 0.9
    n = secs(0.1)
    out["hit_weak"] = noise(n, 6) * env(n, decay=0.04, sustain=0.15) * 0.5
    n = secs(0.5)
    out["faint"] = sweep(freq(midi("G5")), freq(midi("C3")), n, "pulse", 0.5) * env(n, decay=0.2, sustain=0.5, release=0.1) * 0.45
    n = secs(0.3)
    out["status"] = (pulse(freq(midi("B4")), n, 0.125) * 0.5 + pulse(freq(midi("F5")), n, 0.125, 0.3) * 0.5) * \
        (0.6 + 0.4 * np.sin(np.arange(n) / RATE * 2 * np.pi * 18)) * env(n, sustain=0.6) * 0.4
    notes = ["C5", "E5", "G5", "C6"]
    parts = []
    for nm in notes:
        k = secs(0.07)
        parts.append(pulse(freq(midi(nm)), k, 0.25) * env(k, sustain=0.6, release=0.02))
    out["heal"] = np.concatenate(parts) * 0.45
    parts = []
    for nm, d in [("G4", 0.08), ("C5", 0.08), ("E5", 0.08), ("G5", 0.08), ("E5", 0.08), ("G5", 0.3)]:
        k = secs(d)
        parts.append(pulse(freq(midi(nm)), k, 0.5) * env(k, sustain=0.7, release=0.02))
    out["level_up"] = np.concatenate(parts) * 0.4
    n = secs(0.16)
    out["coin"] = np.concatenate([pulse(freq(midi("B5")), secs(0.05), 0.5), pulse(freq(midi("E6")), n - secs(0.05), 0.5)]) * env(n, sustain=0.6) * 0.4
    n = secs(0.35)
    out["warp"] = sweep(200, 900, n, "tri") * env(n, attack=0.05, sustain=0.6, release=0.1) * 0.7
    parts = []
    for nm in ["E5", "B5"]:
        k = secs(0.08)
        parts.append(triangle(freq(midi(nm)), k) * env(k, sustain=0.7))
    out["save"] = np.concatenate(parts) * 0.7
    n = secs(0.6)
    rise = sweep(120, 1400, n, "pulse", 0.25) * env(n, attack=0.01, sustain=0.7, release=0.05)
    out["encounter"] = (rise * 0.4 + noise(n, 4) * np.linspace(0, 0.35, n)) * 0.9
    n = secs(0.25)
    out["run"] = noise(n, 1) * np.linspace(0.4, 0, n) * 0.6
    out.update(element_hits())
    out.update(feel_sfx())
    out.update(world_sfx())
    out.update(rift_sfx())
    return out


def feel_sfx() -> dict[str, np.ndarray]:
    """Plan area 6: counter tick, Wayfarer spots you, item picked up (items 2236, 2505, 2506).
    Built after the older effects so their noise stays byte-identical."""
    out: dict[str, np.ndarray] = {}
    n = secs(0.015)
    out["tick"] = pulse(freq(midi("A6")), n, 0.125) * env(n, attack=0.001, decay=0.008, sustain=0.2, release=0.004) * 0.25
    parts = []
    for nm in ["E5", "B5"]:
        k = secs(0.075)
        parts.append(pulse(freq(midi(nm)), k, 0.25) * env(k, attack=0.002, sustain=0.7, release=0.01))
    out["spot"] = np.concatenate(parts) * 0.45
    parts = []
    for nm in ["D5", "F#5", "A5", "D6"]:
        k = secs(0.055)
        parts.append(triangle(freq(midi(nm)), k) * env(k, attack=0.002, sustain=0.7, release=0.01))
    out["pickup"] = np.concatenate(parts) * 0.7
    out.update(art_sfx())
    return out


def art_sfx() -> dict[str, np.ndarray]:
    """Charge sound per art kind and travel sound per element (items 2529, 2530)."""
    out: dict[str, np.ndarray] = {}
    n = secs(0.1)
    out["charge_physical"] = noise(n, 2) * np.linspace(0.2, 0.6, n) * env(n, attack=0.01, sustain=0.8, release=0.02) * 0.5
    n = secs(0.15)
    out["charge_focus"] = sweep(freq(midi("C5")), freq(midi("C6")), n, "pulse", 0.25) * \
        (0.6 + 0.4 * np.sin(np.arange(n) / RATE * 2 * np.pi * 30)) * env(n, attack=0.01, sustain=0.7) * 0.35
    parts = []
    for nm in ["A4", "E5"]:
        k = secs(0.07)
        parts.append(triangle(freq(midi(nm)), k) * env(k, attack=0.01, sustain=0.6, release=0.02))
    out["charge_status"] = np.concatenate(parts) * 0.5
    n = secs(0.2)
    t = np.arange(n) / RATE
    fade = env(n, attack=0.01, decay=0.05, sustain=0.7, release=0.05)
    out["travel_ember"] = (noise(n, 5) * 0.5 + pulse(freq(midi("E4")), n, 0.125) * 0.2) * \
        (0.5 + 0.5 * (np.sin(t * 2 * np.pi * 23) > 0)) * fade * 0.5
    out["travel_tide"] = triangle(freq(midi("G3")), n) * (0.5 + 0.5 * np.sin(t * 2 * np.pi * 9)) * fade * 0.6
    out["travel_bloom"] = (noise(n, 8) * 0.4 + triangle(freq(midi("D5")), n) * 0.3) * fade * 0.5
    out["travel_volt"] = noise(n, 1) * (np.sin(t * 2 * np.pi * 37) > 0.3) * fade * 0.5
    out["travel_stone"] = sweep(220, 90, n, "tri") * fade * 0.7
    out["travel_gale"] = noise(n, 1) * np.linspace(0.2, 0.6, n) * fade * 0.45
    out["travel_lumen"] = (pulse(freq(midi("A5")), n, 0.5) * 0.3 + pulse(freq(midi("E6")), n, 0.5) * 0.2) * fade * 0.4
    out["travel_umbra"] = sweep(160, 120, n, "pulse", 0.5) * (0.6 + 0.4 * np.sin(t * 2 * np.pi * 6)) * fade * 0.35
    return out


def element_hits() -> dict[str, np.ndarray]:
    """One hit sound per element (item 67), each with its own timbre."""
    out: dict[str, np.ndarray] = {}
    t = lambda n: np.arange(n) / RATE
    n = secs(0.2)  # Ember: crackling burst over a rising buzz
    crackle = noise(n, 2) * (np.random.default_rng(5).random(n) > 0.55)
    out["hit_ember"] = (crackle * 0.6 + sweep(220, 520, n, "pulse", 0.25) * 0.35) * env(n, decay=0.08, sustain=0.3) * 0.8
    n = secs(0.24)  # Tide: falling splash with a wobble
    wob = 1 + 0.5 * np.sin(t(n) * 2 * np.pi * 22)
    out["hit_tide"] = (noise(n, 5) * 0.45 * np.linspace(1, 0.2, n) + sweep(420, 140, n, "tri") * 0.5 * wob / 1.5) * env(n, decay=0.1, sustain=0.35) * 0.85
    n = secs(0.18)  # Bloom: soft leafy rustle and chirp
    out["hit_bloom"] = (noise(n, 9) * 0.35 + sweep(700, 950, n, "pulse", 0.125) * 0.3 * (0.6 + 0.4 * np.sin(t(n) * 2 * np.pi * 30))) * env(n, decay=0.06, sustain=0.3) * 0.75
    n = secs(0.2)  # Volt: buzzing zap that flips between two pitches
    flip = (np.floor(t(n) * 60) % 2).astype(float)
    zap = pulse(880, n, 0.5) * flip + pulse(1320, n, 0.5) * (1 - flip)
    out["hit_volt"] = (zap * 0.45 + noise(n, 1) * 0.2) * env(n, decay=0.05, sustain=0.4) * 0.7
    n = secs(0.2)  # Stone: heavy thud with grit
    out["hit_stone"] = (sweep(160, 50, n, "tri") * 0.8 + noise(n, 10) * 0.35) * env(n, decay=0.09, sustain=0.25) * 0.95
    n = secs(0.26)  # Gale: whoosh that swells and fades
    swell = np.sin(np.linspace(0, np.pi, n))
    out["hit_gale"] = (noise(n, 1) * 0.55 + sweep(300, 600, n, "tri") * 0.15) * swell * 0.8
    parts = []
    for nm in ["E6", "B6", "E7"]:  # Lumen: bright sparkle
        k = secs(0.05)
        parts.append(pulse(freq(midi(nm)), k, 0.125) * env(k, sustain=0.5, release=0.01))
    sp = np.concatenate(parts)
    out["hit_lumen"] = (sp * 0.4 + noise(len(sp), 1) * 0.1) * 0.8
    n = secs(0.24)  # Umbra: low, detuned and falling
    out["hit_umbra"] = (sweep(260, 90, n, "pulse", 0.5) * 0.35 + sweep(266, 92, n, "pulse", 0.25) * 0.35 + noise(n, 12) * 0.15) * env(n, decay=0.1, sustain=0.4) * 0.85
    return out


GROUNDS = ["grass", "path", "wood", "sand", "stone", "shore"]


def world_sfx() -> dict[str, np.ndarray]:
    """Footsteps per ground, two takes each, under 60 ms (items 2501, 2502), and the 15 ms
    text blip (item 2503; Sound shifts its pitch per speaker). Own generator, so the older
    effects keep their noise."""
    rng = np.random.default_rng(2501)
    out: dict[str, np.ndarray] = {}
    t = lambda n: np.arange(n) / RATE
    for take in (1, 2):
        n = secs(0.045 if take == 1 else 0.05)
        thump = lambda f0, f1: sweep(f0, f1, n, "tri") * env(n, attack=0.001, decay=0.02, sustain=0.2, release=0.01)
        hiss = lambda step: noise(n, step, rng) * env(n, attack=0.001, decay=0.015, sustain=0.15, release=0.01)
        out["step_grass_%d" % take] = hiss(1) * 0.5 * (rng.random(n) > 0.35) + thump(140, 90) * 0.2
        out["step_path_%d" % take] = hiss(3 + take) * 0.45 + thump(120, 70) * 0.35
        out["step_wood_%d" % take] = (triangle(260 + 30 * take, n) * 0.5 + hiss(6) * 0.2) * \
            env(n, attack=0.001, decay=0.012, sustain=0.1, release=0.008)
        out["step_sand_%d" % take] = noise(n, 2, rng) * np.sin(np.linspace(0, np.pi, n)) * 0.4
        out["step_stone_%d" % take] = (pulse(520 + 60 * take, n, 0.125) * 0.25 + hiss(8) * 0.4) * \
            env(n, attack=0.001, decay=0.008, sustain=0.08, release=0.006)
        out["step_shore_%d" % take] = (noise(n, 4, rng) * 0.35 * np.sin(np.linspace(0, np.pi, n)) +
                                       triangle(180, n) * 0.2 * (0.5 + 0.5 * np.sin(t(n) * 2 * np.pi * 70))) * \
            env(n, attack=0.004, decay=0.02, sustain=0.4, release=0.012)
    n = secs(0.015)
    out["blip"] = pulse(freq(midi("A5")), n, 0.25) * env(n, attack=0.001, decay=0.005, sustain=0.6, release=0.004) * 0.5
    return out


def rift_sfx() -> dict[str, np.ndarray]:
    """The deep rumble when a Rift opens around the Wayfarer (item 2262). Own generator, so
    the older effects keep their noise."""
    rng = np.random.default_rng(2262)
    out: dict[str, np.ndarray] = {}
    n = secs(0.7)
    body = sweep(72, 44, n, "tri") * 0.6 + noise(n, 48, rng) * 0.45
    wobble = 0.75 + 0.25 * np.sin(np.arange(n) / RATE * 2 * np.pi * 9)
    out["rumble"] = body * wobble * env(n, attack=0.04, decay=0.25, sustain=0.5, release=0.2) * 0.9
    return out
