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
    out.update(dodge_sfx())
    out.update(social_sfx())
    out.update(passage_sfx())
    out.update(grass_sfx())
    out.update(era2_element_sfx())
    out.update(later_element_sfx())
    out.update(era_feel_sfx())
    out.update(battle_show_sfx())
    out.update(late_status_sfx())
    out.update(keepsake_sfx())
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


def dodge_sfx() -> dict[str, np.ndarray]:
    """A missed art's soft rush of air past the target (item 2531) and the quick sideways
    swish of the dodge (item 2536). Own generator, so the older effects keep their noise."""
    rng = np.random.default_rng(2531)
    out: dict[str, np.ndarray] = {}
    n = secs(0.32)
    # Noise held longer and longer as it passes: the rush falls in pitch and fades.
    held = np.concatenate([noise(n // 4, step, rng) for step in (2, 3, 5, 8)])[:n]
    if len(held) < n:
        held = np.pad(held, (0, n - len(held)))
    swell = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    out["miss"] = held * swell * 0.5
    n = secs(0.12)
    out["dodge"] = (noise(n, 1, rng) * 0.5 + sweep(900, 400, n, "tri") * 0.15) * \
        env(n, attack=0.004, decay=0.05, sustain=0.3, release=0.03) * 0.7
    return out


def social_sfx() -> dict[str, np.ndarray]:
    """Small notes for menus and friends: a greyed-out row (item 2511), the toast (2512), a
    sent gift (2514), a new friend (2515), a finished daily task (2516) and the day's rare
    visitor (2517). Own generator, so the older effects keep their noise."""
    rng = np.random.default_rng(2511)
    out: dict[str, np.ndarray] = {}

    def tone(nm: str, d: float, kind: str = "pulse", duty: float = 0.25) -> np.ndarray:
        k = secs(d)
        osc = triangle(freq(midi(nm)), k) if kind == "tri" else pulse(freq(midi(nm)), k, duty)
        return osc * env(k, attack=0.002, sustain=0.6, release=0.015)

    # Dull and short, low triangle with a muffled thud: unlike the falling "cancel" sweep.
    n = secs(0.07)
    out["locked"] = (triangle(freq(midi("F#3")), n) * 0.7 + noise(n, 24, rng) * 0.2) * \
        env(n, attack=0.001, decay=0.03, sustain=0.2, release=0.02) * 0.6
    out["toast"] = np.concatenate([tone("G5", 0.045, "tri"), tone("D6", 0.06, "tri")]) * 0.35
    out["gift"] = np.concatenate([tone("G5", 0.07), tone("E5", 0.07), tone("C5", 0.14)]) * 0.42
    out["friend"] = np.concatenate([tone("C5", 0.09, "pulse", 0.5), tone("G5", 0.16, "pulse", 0.5)]) * 0.4
    n = secs(0.06)
    stroke = noise(n, 2, rng) * np.linspace(0.2, 0.6, n) * env(n, attack=0.002, sustain=0.6, release=0.01) * 0.35
    k = secs(0.35)
    bell = (triangle(freq(midi("E6")), k) * 0.6 + pulse(freq(midi("B6")), k, 0.125) * 0.15) * \
        env(k, attack=0.002, decay=0.2, sustain=0.2, release=0.1)
    out["task_done"] = np.concatenate([stroke, bell * 0.6])
    parts = []
    for nm in ["E7", "B6", "G#7", "D#7", "B7"]:
        parts.append(tone(nm, 0.04, "tri"))
    out["sparkle"] = np.concatenate(parts) * 0.3
    return out


def passage_sfx() -> dict[str, np.ndarray]:
    """Doors opening and closing in wood (item 2507), three quick steps up or down the stairs
    (2508), the pause menu as a page turned open and folded shut (2509), the faint Energy tick
    at round start (2537). Own generator, so the older effects keep their noise."""
    rng = np.random.default_rng(2507)
    out: dict[str, np.ndarray] = {}
    # Wood: band of noise held a few samples (darker) over a low pulse thump.
    n = secs(0.22)
    creak = sweep(180, 260, n, "pulse", 0.125) * 0.15 * np.sin(np.linspace(0, np.pi, n))
    out["door_open"] = (noise(n, 10, rng) * 0.35 + creak + sweep(110, 80, n, "tri") * 0.35) * \
        env(n, attack=0.01, decay=0.1, sustain=0.4, release=0.06) * 0.8
    n = secs(0.12)
    out["door_close"] = (noise(n, 14, rng) * 0.4 + sweep(95, 55, n, "tri") * 0.6) * \
        env(n, attack=0.001, decay=0.05, sustain=0.2, release=0.04) * 0.9
    for name, notes in [("stairs_up", ["C4", "E4", "G4"]), ("stairs_down", ["G4", "E4", "C4"])]:
        parts = []
        for nm in notes:
            k = secs(0.05)
            step = triangle(freq(midi(nm)), k) * 0.5 + noise(k, 4, rng) * 0.25
            parts.append(step * env(k, attack=0.001, decay=0.02, sustain=0.2, release=0.01))
            parts.append(np.zeros(secs(0.025)))
        out[name] = np.concatenate(parts) * 0.7
    # A page: a short rush of fine noise, rising when it opens, falling and soft when it shuts.
    n = secs(0.16)
    out["page_open"] = (noise(n, 1, rng) * np.linspace(0.2, 0.6, n) + sweep(600, 1200, n, "tri") * 0.08) * \
        env(n, attack=0.01, decay=0.06, sustain=0.5, release=0.04) * 0.6
    n = secs(0.13)
    out["page_close"] = (noise(n, 2, rng) * np.linspace(0.6, 0.15, n) + sweep(700, 300, n, "tri") * 0.1) * \
        env(n, attack=0.002, decay=0.05, sustain=0.4, release=0.04) * 0.6
    n = secs(0.012)
    out["energy_tick"] = pulse(freq(midi("E7")), n, 0.125) * env(n, attack=0.001, decay=0.006, sustain=0.2, release=0.003) * 0.2
    return out


def grass_sfx() -> dict[str, np.ndarray]:
    """A soft rustle when the Wayfarer walks into encounter grass (item 2519). Own generator,
    so the older effects keep their noise."""
    rng = np.random.default_rng(2519)
    out: dict[str, np.ndarray] = {}
    n = secs(0.14)
    blades = noise(n, 1, rng) * (rng.random(n) > 0.45)
    out["rustle"] = blades * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.35
    return out


def era2_element_sfx() -> dict[str, np.ndarray]:
    """Hit and travel sounds for the Era II elements Ink and Echo (legendary Spirlings). Own
    generator, so the older effects keep their noise."""
    rng = np.random.default_rng(1818)
    out: dict[str, np.ndarray] = {}
    tt = lambda n: np.arange(n) / RATE
    n = secs(0.22)  # Ink: a wet blot, low splat with a scratch of the nib
    out["hit_ink"] = (sweep(200, 70, n, "pulse", 0.25) * 0.5 + noise(n, 3, rng) * 0.3 * np.linspace(1, 0, n)) * \
        env(n, decay=0.1, sustain=0.3) * 0.85
    n = secs(0.3)  # Echo: a struck bell with its own echo
    bell = triangle(freq(midi("A5")), n) * 0.4 + triangle(freq(midi("E6")), n) * 0.2
    out["hit_echo"] = (bell * np.exp(-tt(n) * 9) + np.roll(bell * np.exp(-tt(n) * 9), secs(0.09)) * 0.35) * 0.8
    n = secs(0.25)
    fade = np.linspace(1, 0, n)
    out["travel_ink"] = (noise(n, 2, rng) * (np.sin(tt(n) * 2 * np.pi * 14) > 0.2) * 0.4 + sweep(140, 110, n, "tri") * 0.3) * fade * 0.5
    out["travel_echo"] = (triangle(freq(midi("E5")), n) * 0.3 * (0.5 + 0.5 * np.sin(tt(n) * 2 * np.pi * 7))) * fade * 0.5
    return out


def later_element_sfx() -> dict[str, np.ndarray]:
    """Hit and travel sounds for the elements of the post-game regions: Rust and Mask (Vellmarch),
    Acid and Frost (Quillmarch), Gilt and Zenith (Halcyra). Own generator and seed."""
    rng = np.random.default_rng(4242)
    out: dict[str, np.ndarray] = {}
    tt = lambda n: np.arange(n) / RATE
    n = secs(0.22)  # Rust: a grinding scrape on old iron
    out["hit_rust"] = (sweep(160, 60, n, "pulse", 0.3) * 0.45 + noise(n, 4, rng) * 0.35) * env(n, decay=0.12, sustain=0.3) * 0.8
    n = secs(0.2)  # Mask: a muffled knock behind a face
    out["hit_mask"] = (triangle(freq(midi("D3")), n) * 0.5 + noise(n, 6, rng) * 0.15) * np.exp(-tt(n) * 18) * 0.9
    n = secs(0.22)  # Acid: a hiss with bubbles
    bub = (np.sin(tt(n) * 2 * np.pi * 23) > 0.6) * 0.3
    out["hit_acid"] = (noise(n, 1, rng) * 0.35 + sweep(500, 300, n, "tri") * bub) * env(n, decay=0.1, sustain=0.4) * 0.75
    n = secs(0.24)  # Frost: brittle ice cracking
    crack = noise(n, 1, rng) * (rng.random(n) > 0.85)
    out["hit_frost"] = (crack * 0.6 + triangle(freq(midi("B6")), n) * 0.2 * np.exp(-tt(n) * 14)) * 0.8
    n = secs(0.3)  # Gilt: a coin ringing on stone
    coin = triangle(freq(midi("E6")), n) * 0.35 + triangle(freq(midi("G#6")), n) * 0.2
    out["hit_gilt"] = coin * np.exp(-tt(n) * 11) * 0.85
    n = secs(0.26)  # Zenith: a bright rising flash
    out["hit_zenith"] = sweep(500, 1400, n, "tri") * env(n, decay=0.14, sustain=0.3) * 0.6
    n = secs(0.25)
    fade = np.linspace(1, 0, n)
    out["travel_rust"] = (noise(n, 3, rng) * 0.3 + sweep(120, 90, n, "pulse", 0.3) * 0.25) * fade * 0.5
    out["travel_mask"] = (triangle(freq(midi("A3")), n) * 0.3 * (0.5 + 0.5 * np.sin(tt(n) * 2 * np.pi * 5))) * fade * 0.5
    out["travel_acid"] = (noise(n, 1, rng) * 0.25 * (np.sin(tt(n) * 2 * np.pi * 11) > 0)) * fade * 0.5
    out["travel_frost"] = (triangle(freq(midi("E6")), n) * 0.2 + noise(n, 1, rng) * 0.1) * fade * 0.5
    out["travel_gilt"] = (triangle(freq(midi("B5")), n) * 0.25 * (0.6 + 0.4 * np.sin(tt(n) * 2 * np.pi * 9))) * fade * 0.5
    out["travel_zenith"] = sweep(700, 1100, n, "tri") * 0.25 * fade * 0.5
    return out


def era_feel_sfx() -> dict[str, np.ndarray]:
    """Era feel (docs/ERA_FEEL_UI.md): one text blip per era from Era II on, each a step up in
    sound chip (II square, III square plus triangle, IV soft triangle, V near-sine with a glide),
    and the era-change jingle era_up_2 to era_up_5 with the same steps. Own oscillators only."""
    out: dict[str, np.ndarray] = {}
    tt = lambda n: np.arange(n) / RATE
    sine = lambda f, n: np.sin(tt(n) * 2 * np.pi * f)
    a5 = freq(midi("A5"))
    n = secs(0.015)
    out["blip_e2"] = pulse(a5, n, 0.5) * env(n, attack=0.001, decay=0.005, sustain=0.6, release=0.004) * 0.45
    out["blip_e3"] = (pulse(a5, n, 0.5) * 0.3 + triangle(a5, n) * 0.4) * env(n, attack=0.001, decay=0.005, sustain=0.6, release=0.004)
    n = secs(0.018)
    out["blip_e4"] = triangle(a5, n) * env(n, attack=0.002, decay=0.006, sustain=0.6, release=0.006) * 0.6
    glide = np.linspace(1.0, 1.04, n)
    ph = np.cumsum(a5 * glide / RATE) % 1.0
    out["blip_e5"] = np.sin(ph * 2 * np.pi) * env(n, attack=0.002, decay=0.006, sustain=0.6, release=0.006) * 0.55
    notes = ["C5", "E5", "G5", "C6", "E6", "G6"]

    def jingle(voice, step: float, tail: float) -> np.ndarray:
        parts = []
        for i, nm in enumerate(notes):
            k = secs(step if i < len(notes) - 1 else tail)
            parts.append(voice(freq(midi(nm)), k) * env(k, attack=0.003, decay=0.05, sustain=0.6, release=0.03))
        return np.concatenate(parts)

    out["era_up_2"] = jingle(lambda f, k: pulse(f, k, 0.25), 0.07, 0.35) * 0.4
    out["era_up_3"] = jingle(lambda f, k: pulse(f, k, 0.5) * 0.5 + triangle(f / 2, k) * 0.5, 0.075, 0.45) * 0.45
    out["era_up_4"] = jingle(lambda f, k: triangle(f, k) * 0.5 + triangle(f * 1.004, k) * 0.4, 0.08, 0.6) * 0.55
    dry = jingle(lambda f, k: sine(f, k) * 0.6 + sine(f * 2, k) * 0.15, 0.085, 0.7)
    echo = np.zeros(len(dry) + secs(0.18))
    echo[:len(dry)] += dry
    echo[secs(0.18):] += dry * 0.35
    out["era_up_5"] = echo * 0.5
    return out


def battle_show_sfx() -> dict[str, np.ndarray]:
    """Battle audio (docs/KAMPF_PLAN_1000.md, "Audio im Kampf"): one short sound per status
    (685), stage up/down notes the game pitches by stage (686), the Overcharge swell (687),
    Resonance field rise, fade and shift (688, 689, 720), the keen-hit accent (719), the
    matchup tones for players who cannot see the screen (696), the Warden rule seal (706), the
    partner's call (707), the calm-rule refusal (708), the boss's entrance and phase stinger
    (683, 705) and the defeat jingle (692). Own generator, so the older effects keep their noise."""
    rng = np.random.default_rng(681)
    out: dict[str, np.ndarray] = {}

    def notes(seq, voice, gap: float = 0.0) -> np.ndarray:
        parts = []
        for nm, d in seq:
            k = secs(d)
            parts.append(voice(freq(midi(nm)), k) * env(k, attack=0.003, decay=0.04, sustain=0.6, release=0.02))
            if gap > 0.0:
                parts.append(np.zeros(secs(gap)))
        return np.concatenate(parts)

    sq = lambda f, k: pulse(f, k, 0.25)
    tri = lambda f, k: triangle(f, k)
    # Statuses: a crackle that falls (scorch), a drip pair (soak), a low creak (root), a buzz
    # (jolt), a wobble (daze) and a slow sigh down (drowse).
    n = secs(0.28)
    out["status_scorch"] = (noise(n, 2, rng) * 0.45 + sweep(900, 300, n, "pulse", 0.125) * 0.35) * env(n, decay=0.08, sustain=0.4) * 0.7
    out["status_soak"] = notes([("E6", 0.05), ("B5", 0.07)], tri, 0.03) * 0.7
    n = secs(0.3)
    out["status_root"] = (sweep(110, 70, n, "tri") * 0.7 + noise(n, 24, rng) * 0.2) * env(n, attack=0.02, sustain=0.6) * 0.8
    n = secs(0.22)
    buzz = pulse(freq(midi("A4")), n, 0.5) * (0.5 + 0.5 * np.sign(np.sin(np.arange(n) / RATE * 2 * np.pi * 30)))
    out["status_jolt"] = buzz * env(n, decay=0.05, sustain=0.5) * 0.45
    n = secs(0.34)
    t = np.arange(n) / RATE
    wob = np.sin(np.cumsum(freq(midi("D5")) * (1 + 0.04 * np.sin(t * 2 * np.pi * 7)) / RATE) * 2 * np.pi)
    out["status_daze"] = np.sign(wob) * 0.4 * env(n, sustain=0.6, release=0.08)
    n = secs(0.45)
    out["status_drowse"] = sweep(freq(midi("A4")), freq(midi("D4")), n, "tri") * env(n, attack=0.05, sustain=0.6, release=0.15) * 0.7
    # Stage notes: one rising and one falling pair; the game raises the pitch per stage.
    out["stage_up"] = notes([("C5", 0.05), ("G5", 0.09)], sq) * 0.45
    out["stage_down"] = notes([("G4", 0.05), ("C4", 0.09)], sq) * 0.45
    # Overcharge: a held rising swell; the game pitches it by the Energy poured in.
    n = secs(0.32)
    out["overcharge"] = (sweep(220, 660, n, "pulse", 0.125) * 0.5 + noise(n, 3, rng) * np.linspace(0.0, 0.25, n)) * \
        env(n, attack=0.03, sustain=0.7, release=0.04) * 0.7
    # Resonance fields: a soft chord that blooms (rise), folds away (fade) or turns (shift).
    n = secs(0.35)
    chord = sum(triangle(freq(midi(nm)), n) for nm in ("C4", "G4", "D5")) / 3.0
    out["field_rise"] = chord * env(n, attack=0.25, decay=0.1, sustain=0.7, release=0.2) * 0.9
    n = secs(0.4)
    out["field_fade"] = (sweep(freq(midi("D5")), freq(midi("G3")), n, "tri") * 0.6 + triangle(freq(midi("C4")), n) * 0.3) * \
        np.linspace(1.0, 0.0, n) * 0.8
    out["field_shift"] = notes([("G4", 0.06), ("D5", 0.06), ("A5", 0.14)], tri) * 0.7
    # Keen hit: a bright click on top of the hit.
    n = secs(0.07)
    out["crit_accent"] = (pulse(freq(midi("E7")), n, 0.125) * 0.5 + noise(n, 1, rng) * 0.3) * env(n, attack=0.001, decay=0.02, sustain=0.2, release=0.02) * 0.7
    # Matchup tones (696): up for an overwhelming hit, down for a hit that barely landed.
    out["eff_up"] = notes([("E5", 0.05), ("A5", 0.07)], tri) * 0.55
    out["eff_down"] = notes([("A4", 0.05), ("E4", 0.07)], tri) * 0.55
    # Warden rule seal: two low strokes like a stamp.
    n = secs(0.12)
    stamp = (triangle(freq(midi("C3")), n) * 0.7 + noise(n, 12, rng) * 0.3) * env(n, attack=0.002, decay=0.04, sustain=0.3, release=0.03)
    out["rule_seal"] = np.concatenate([stamp * 0.6, np.zeros(secs(0.05)), stamp]) * 0.85
    out["partner_call"] = notes([("D5", 0.06), ("F#5", 0.06), ("A5", 0.06), ("D6", 0.12)], sq) * 0.4
    out["calm_fail"] = notes([("F4", 0.08), ("F4", 0.12)], tri, 0.04) * 0.6
    # Boss: a deep swell for the entrance and a sharp stinger when its phase turns.
    n = secs(0.45)
    out["boss_intro"] = (sweep(55, 110, n, "tri") * 0.6 + pulse(freq(midi("A2")), n, 0.5) * 0.25 + noise(n, 40, rng) * 0.2) * \
        env(n, attack=0.15, decay=0.2, sustain=0.6, release=0.25) * 0.9
    n = secs(0.4)
    out["boss_phase"] = (pulse(freq(midi("D5")), n, 0.5) * 0.3 + pulse(freq(midi("G#5")), n, 0.5) * 0.3 + noise(n, 2, rng) * 0.2) * \
        env(n, attack=0.002, decay=0.1, sustain=0.5, release=0.12) * 0.7
    # Defeat: a short falling line in minor, the last note held.
    out["defeat"] = notes([("A4", 0.11), ("F4", 0.11), ("D4", 0.11), ("C#4", 0.3)], lambda f, k: pulse(f, k, 0.5) * 0.5 + triangle(f / 2, k) * 0.5) * 0.45
    return out


def late_status_sfx() -> dict[str, np.ndarray]:
    """Sounds for the statuses added later: Spent (a short fizzle down, Energy runs dry) and
    Marked (a thin high ping, the target is singled out). Own generator, so the older effects
    keep their noise."""
    rng = np.random.default_rng(685)
    out: dict[str, np.ndarray] = {}
    n = secs(0.16)
    out["status_spent"] = (sweep(700, 180, n, "pulse", 0.25) * 0.5 + noise(n, 4, rng) * 0.2) * env(n, decay=0.05, sustain=0.4) * 0.6
    n = secs(0.14)
    out["status_marked"] = (pulse(freq(midi("B6")), n, 0.125) * 0.4 + triangle(freq(midi("B5")), n) * 0.4) * env(n, attack=0.002, decay=0.04, sustain=0.4, release=0.05) * 0.6
    # Muddle: two notes that wander off each other, the art may hit the wrong target.
    n = secs(0.16)
    out["status_muddle"] = (pulse(freq(midi("E5")), n, 0.25) * 0.35 + sweep(freq(midi("F5")), freq(midi("C5")), n, "tri") * 0.4) * env(n, sustain=0.5, release=0.04) * 0.6
    return out


def keepsake_sfx() -> dict[str, np.ndarray]:
    """Keepsake sound (KAMPF_PLAN_1000 319): a short glassy two-note glint when a held keepsake
    works. One file to keep audio/sfx under its size budget; the game pitches it per cue (a lower
    knock for a guard, a deep ring for the Hold Stone, a bright one for a fruit). Own generator,
    so the older effects keep their noise."""
    out: dict[str, np.ndarray] = {}
    parts = []
    for nm, d in [("B5", 0.04), ("F#6", 0.08)]:
        k = secs(d)
        parts.append((triangle(freq(midi(nm)), k) * 0.6 + pulse(freq(midi(nm)) * 2, k, 0.125) * 0.25) *
                     env(k, attack=0.002, decay=0.03, sustain=0.5, release=0.03))
    out["keepsake_stir"] = np.concatenate(parts) * 0.6
    return out
