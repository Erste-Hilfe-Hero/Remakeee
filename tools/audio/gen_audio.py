"""Chimora's original chiptune audio, synthesized from note data written in this file.

    python3 tools/audio/gen_audio.py

Writes audio/sfx/*.wav (16-bit mono 22.05 kHz) and audio/music/*.ogg (Vorbis, via ffmpeg).
No samples, no third-party melodies: every sound is built from pulse/triangle/noise waves,
and every tune comes from the chord charts and motifs below (plus a seeded random walk over
chord tones for the variations). Re-run to rebuild; output is deterministic.
"""
from __future__ import annotations

import os
import random
import subprocess
import tempfile
import wave

import numpy as np

RATE = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name: str) -> int:
    """'C4' -> 60."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def freq(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12.0)


# --- Oscillators ----------------------------------------------------------------------

def pulse(f: float, n: int, duty: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    t = (np.arange(n) * f / RATE + phase0) % 1.0
    return np.where(t < duty, 1.0, -1.0)


def triangle(f: float, n: int) -> np.ndarray:
    t = (np.arange(n) * f / RATE) % 1.0
    return 4.0 * np.abs(t - 0.5) - 1.0


_noise_rng = np.random.default_rng(7)


def noise(n: int, step: int = 1) -> np.ndarray:
    raw = _noise_rng.uniform(-1.0, 1.0, n // step + 1)
    return np.repeat(raw, step)[:n]


def env(n: int, attack: float = 0.005, decay: float = 0.08, sustain: float = 0.6, release: float = 0.04) -> np.ndarray:
    a = max(1, int(attack * RATE))
    d = max(1, int(decay * RATE))
    r = max(1, int(release * RATE))
    e = np.full(n, sustain)
    e[:min(a, n)] = np.linspace(0, 1, a)[:n]
    if a < n:
        seg = min(d, n - a)
        e[a:a + seg] = np.linspace(1, sustain, d)[:seg]
    if n > r:
        e[n - r:] *= np.linspace(1, 0, r)
    return e


def sweep(f0: float, f1: float, n: int, wave_fn: str = "pulse", duty: float = 0.5) -> np.ndarray:
    fs = np.geomspace(max(f0, 1), max(f1, 1), n)
    ph = np.cumsum(fs / RATE) % 1.0
    if wave_fn == "tri":
        return 4.0 * np.abs(ph - 0.5) - 1.0
    return np.where(ph < duty, 1.0, -1.0)


def secs(s: float) -> int:
    return int(s * RATE)


# --- Sound effects ----------------------------------------------------------------------

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


# --- Music ----------------------------------------------------------------------------------

CHORD_SHAPES = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
                "sus4": [0, 5, 7], "sus2": [0, 2, 7], "dim": [0, 3, 6], "add9": [0, 4, 7, 14]}


def chord_tones(sym: str) -> tuple[int, list[int]]:
    root = sym[0]
    rest = sym[1:]
    if rest[:1] in ("#", "b"):
        root += rest[0]
        rest = rest[1:]
    return NOTE_INDEX[root], CHORD_SHAPES[rest]


class Song:
    """Four channels on a 16th-note grid: lead (pulse 25%), harmony (pulse 12.5%), bass (triangle), drums (noise)."""

    def __init__(self, bpm: int, bars: int):
        self.bpm = bpm
        self.bars = bars
        self.step = 60.0 / bpm / 4.0
        self.total = secs(self.step * 16 * bars)
        self.mix = np.zeros(self.total)

    def at(self, step_index: int) -> int:
        return secs(self.step * step_index)

    def note(self, ch: str, m: float, start: int, length: int, vol: float) -> None:
        s = self.at(start)
        n = min(self.at(start + length) - s, self.total - s)
        if n <= 0:
            return
        f = freq(m)
        if ch == "lead":
            w = pulse(f, n, 0.25) * env(n, decay=0.06, sustain=0.55, release=0.03)
            # Gentle vibrato on long notes.
            if length >= 6:
                w *= 1.0
        elif ch == "harm":
            w = pulse(f, n, 0.125) * env(n, decay=0.04, sustain=0.35, release=0.02)
        else:
            w = triangle(f, n) * env(n, attack=0.002, decay=0.02, sustain=0.9, release=0.02)
        self.mix[s:s + n] += w * vol

    def drum(self, kind: str, start: int, vol: float) -> None:
        s = self.at(start)
        if kind == "k":
            n = min(secs(0.09), self.total - s)
            w = sweep(160, 45, n, "tri") * env(n, decay=0.06, sustain=0.0, release=0.01)
        elif kind == "s":
            n = min(secs(0.1), self.total - s)
            w = noise(n, 1) * env(n, decay=0.07, sustain=0.0, release=0.01)
        else:
            n = min(secs(0.03), self.total - s)
            w = noise(n, 1) * env(n, decay=0.02, sustain=0.0, release=0.005) * 0.5
        self.mix[s:s + n] += w * vol

    def render(self) -> np.ndarray:
        peak = np.max(np.abs(self.mix)) or 1.0
        return self.mix / peak * 0.85


def parse_line(text: str) -> list[tuple[int | None, int]]:
    """'E5:4 G5:2 -:2' -> [(midi, steps), ...]; '-' is a rest."""
    out = []
    for tok in text.split():
        name, dur = tok.split(":")
        out.append((None if name == "-" else midi(name), int(dur)))
    return out


def write_line(song: Song, ch: str, line: str, start_bar: int, vol: float) -> None:
    pos = start_bar * 16
    for m, d in parse_line(line):
        if m is not None:
            song.note(ch, m, pos, d, vol)
        pos += d


def compose(name: str, bpm: int, chords: list[str], motifs: list[str], bass_style: str, arp_style: str,
            drums: str, seed: int, lead_vol: float = 0.32, octave: int = 4, variation: bool = True) -> np.ndarray:
    """Chords: one symbol per bar. Motifs: hand-written lead lines (one bar each, 16 steps) placed
    over the first bars; the remaining bars get a seeded walk over the bar's chord tones."""
    rng = random.Random(seed)
    song = Song(bpm, len(chords))
    for bar, sym in enumerate(chords):
        root, shape = chord_tones(sym)
        base = 12 * (octave + 1) + root
        # Bass
        broot = 12 * 3 + root if root >= 5 else 12 * 4 + root - 12
        if bass_style == "pulse8":
            for i in range(0, 16, 2):
                song.note("bass", broot + (12 if i % 4 == 2 else 0), bar * 16 + i, 2, 0.5)
        elif bass_style == "walk":
            for i, deg in enumerate([0, shape[1], shape[2], shape[1]]):
                song.note("bass", broot + deg, bar * 16 + i * 4, 4, 0.5)
        elif bass_style == "drone":
            song.note("bass", broot, bar * 16, 16, 0.45)
        else:  # root-fifth
            song.note("bass", broot, bar * 16, 8, 0.5)
            song.note("bass", broot + 7, bar * 16 + 8, 8, 0.5)
        # Harmony arpeggio
        tones = [base + s for s in shape]
        if arp_style == "up":
            seq = [tones[i % len(tones)] for i in range(8)]
            for i, m in enumerate(seq):
                song.note("harm", m, bar * 16 + i * 2, 2, 0.16)
        elif arp_style == "pad":
            for m in tones[:3]:
                song.note("harm", m, bar * 16, 16, 0.08)
        elif arp_style == "stab":
            for i in (2, 6, 10, 14):
                for m in tones[:3]:
                    song.note("harm", m, bar * 16 + i, 1, 0.07)
        elif arp_style == "rolling":
            order = [0, 1, 2, 1] if len(tones) < 4 else [0, 1, 2, 3]
            for i in range(16):
                song.note("harm", tones[order[i % 4]] + (12 if i >= 8 else 0), bar * 16 + i, 1, 0.12)
        # Drums
        pattern = DRUM_PATTERNS[drums]
        for i, ch in enumerate(pattern):
            if ch != ".":
                song.drum(ch, bar * 16 + i, 0.35 if ch != "h" else 0.25)
    # Lead: motifs first, then a walk over chord tones in the rest of the bars.
    for bar, line in enumerate(motifs):
        write_line(song, "lead", line, bar, lead_vol)
    if variation:
        rhythms = [[4, 2, 2, 4, 4], [2, 2, 4, 2, 2, 4], [6, 2, 4, 4], [4, 4, 4, 4], [3, 3, 2, 4, 4]]
        prev = None
        for bar in range(len(motifs), len(chords)):
            root, shape = chord_tones(chords[bar])
            pool = sorted({12 * (octave + 2) + root + s + o for s in shape for o in (-12, 0)})
            pos = bar * 16
            for d in rng.choice(rhythms):
                if rng.random() < 0.12 and prev is not None:
                    pos += d
                    continue
                if prev is None:
                    m = rng.choice(pool)
                else:
                    near = sorted(pool, key=lambda p: abs(p - prev))[:3]
                    m = rng.choice(near)
                song.note("lead", m, pos, d, lead_vol)
                prev = m
                pos += d
    return song.render()


DRUM_PATTERNS = {
    "none": "................",
    "soft": "k.......h.......",
    "walk": "k...h...k...h...",
    "drive": "k.h.s.h.k.hkS.h.".replace("S", "s"),
    "battle": "k.hks.hkk.hks.hs",
    "march": "k...s...k.k.s...",
}

SONGS = {
    "title": dict(bpm=92, chords=["Dm", "Bbmaj7", "F", "C", "Dm", "Bbmaj7", "Gm", "A7"], arp_style="up", bass_style="root-fifth",
                  drums="soft", seed=11, motifs=["D5:6 F5:2 A5:4 G5:4", "F5:6 E5:2 D5:4 C5:4", "C5:4 F5:4 A5:6 G5:2", "E5:8 -:4 G5:4"]),
    "town": dict(bpm=104, chords=["G", "Em", "C", "D", "G", "Em", "Am7", "D7", "C", "D", "Bm", "Em", "C", "D", "G", "G"], arp_style="rolling",
                 bass_style="walk", drums="walk", seed=23, motifs=["B4:4 D5:4 G5:6 F#5:2", "E5:4 G5:2 E5:2 B4:8", "C5:4 E5:4 G5:4 E5:4", "F#5:6 E5:2 D5:8"]),
    "route": dict(bpm=132, chords=["A", "F#m", "D", "E", "A", "F#m", "Bm", "E7", "D", "E", "C#m", "F#m", "D", "E", "A", "E"], arp_style="up",
                  bass_style="pulse8", drums="drive", seed=37, motifs=["A4:2 C#5:2 E5:4 A5:4 G#5:2 F#5:2", "F#5:4 E5:2 C#5:2 A4:8", "D5:2 F#5:2 A5:4 F#5:4 D5:4", "E5:6 G#5:2 B5:8"]),
    "rift": dict(bpm=78, chords=["Em", "Fmaj7", "Em", "Ebmaj7", "Em", "Fmaj7", "Dm", "Edim"], arp_style="pad", bass_style="drone",
                 drums="soft", seed=41, motifs=["E5:8 B4:4 C5:4", "A4:12 -:4"], lead_vol=0.26),
    "battle": dict(bpm=152, chords=["Em", "Em", "C", "D", "Em", "Em", "Am", "B7", "C", "D", "Bm", "Em", "C", "D", "B7", "B7"], arp_style="rolling",
                   bass_style="pulse8", drums="battle", seed=53, motifs=["E5:2 E5:2 G5:2 E5:2 B5:4 A5:4", "G5:2 F#5:2 E5:4 B4:8", "C5:2 E5:2 G5:4 C6:4 B5:4", "A5:4 F#5:4 D5:8"]),
    "warden": dict(bpm=164, chords=["Cm", "Ab", "Bb", "G7", "Cm", "Ab", "Fm", "G7", "Ab", "Bb", "Gm", "Cm", "Ab", "Bb", "G7", "G7"], arp_style="rolling",
                   bass_style="pulse8", drums="battle", seed=67, motifs=["C5:2 Eb5:2 G5:4 C6:4 Bb5:4", "Ab5:4 G5:2 Eb5:2 C5:8", "D5:2 F5:2 Bb5:4 Ab5:4 G5:4", "G5:4 B5:4 D6:8"]),
    # Battle music once your Spirling is low on HP (item 69): faster, tenser, same key as "battle".
    "battle_pinch": dict(bpm=176, chords=["Em", "F", "Em", "F", "C", "B7", "Em", "B7"], arp_style="rolling",
                         bass_style="pulse8", drums="battle", seed=59, motifs=["B5:2 C6:2 B5:2 G5:2 E5:4 F5:4", "E5:2 G5:2 B5:4 D#5:8", "C6:2 B5:2 A5:2 G5:2 E5:8", "D#5:4 F#5:4 B5:8"]),
    "victory": dict(bpm=140, chords=["C", "F", "G", "C"], arp_style="stab", bass_style="root-fifth", drums="march", seed=71, variation=False,
                    motifs=["C5:2 E5:2 G5:2 C6:6 -:4", "A5:2 C6:2 A5:2 F5:6 -:4", "G5:2 B5:2 D6:2 B5:2 G5:4 F5:4", "E5:8 C5:8"]),
}
# Tracks that play once (jingles) instead of looping.
ONE_SHOT = {"victory"}


def write_wav(path: str, data: np.ndarray) -> None:
    pcm = (np.clip(data, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def write_ogg(path: str, data: np.ndarray) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        write_wav(wav, data)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", path], check=True)


def main() -> None:
    import argparse
    ap = argparse.ArgumentParser(description="Build Chimora's sound effects and music.")
    ap.add_argument("--only", action="append", default=[], help="build only this sound or song (repeatable)")
    ap.add_argument("--sfx", action="store_true", help="build sound effects only")
    ap.add_argument("--music", action="store_true", help="build music only")
    args = ap.parse_args()
    do_sfx = args.sfx or not args.music
    do_music = args.music or not args.sfx
    wanted = set(args.only)
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    # Every effect is always synthesized (they share one seeded noise source, so skipping one
    # would change the next); --only just limits what is written.
    for name, data in sfx_defs().items():
        if not do_sfx or (wanted and name not in wanted):
            continue
        write_wav(os.path.join(SFX_DIR, name + ".wav"), data)
        print("sfx", name)
    for name, spec in SONGS.items():
        if not do_music or (wanted and name not in wanted):
            continue
        data = compose(name, **spec)
        write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), data)
        print("music", name, "%.1fs" % (len(data) / RATE))


if __name__ == "__main__":
    main()
