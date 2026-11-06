"""Shared synthesis helpers for Chimora's generated audio: notes, oscillators, envelopes, files.
Part of tools/audio/ (plan area 6, item 2609); gen_audio.py is the entry point."""
from __future__ import annotations

import os
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


def noise(n: int, step: int = 1, rng: np.random.Generator | None = None) -> np.ndarray:
    """White noise held for [step] samples. Sound effects share one seeded source (their order
    matters); music passes its own per-song generator so each track rebuilds on its own."""
    raw = (rng or _noise_rng).uniform(-1.0, 1.0, n // step + 1)
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


def write_wav(path: str, data: np.ndarray) -> None:
    pcm = (np.clip(data, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def write_ogg(path: str, data: np.ndarray, quality: int = 3) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        write_wav(wav, data)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality),
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", path], check=True)
