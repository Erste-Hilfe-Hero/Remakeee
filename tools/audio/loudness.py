#!/usr/bin/env python3
"""Loudness targets for Chimora's audio (plan area 6, items 2611, 2612).

Music aims at -16 LUFS integrated (+-1), sound effects at a -3 dBFS peak. gen_audio.py calls
normalize_music() / normalize_sfx() on every file it writes; run this file to check what is in
audio/ now:

    python3 tools/audio/loudness.py          # report, exit 1 when something is off target
Needs ffmpeg (ebur128 filter) for the LUFS measurement.
"""
from __future__ import annotations

import glob
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synth import RATE, ROOT, write_wav  # noqa: E402

MUSIC_LUFS = -16.0
MUSIC_TOLERANCE = 1.0
SFX_PEAK_DBFS = -3.0
# Music may not clip while being raised to the target.
MUSIC_PEAK_LIMIT = 0.98


def peak_dbfs(data: np.ndarray) -> float:
    p = float(np.max(np.abs(data))) if len(data) else 0.0
    return 20.0 * np.log10(p) if p > 0 else -120.0


def lufs_of_file(path: str) -> float:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True, check=True)
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1]) if m else float("nan")


def lufs(data: np.ndarray) -> float:
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "x.wav")
        write_wav(p, data)
        return lufs_of_file(p)


def music_gain(data: np.ndarray) -> float:
    """Gain that brings [data] to -16 LUFS without passing the peak limit."""
    now = lufs(data)
    if not np.isfinite(now):
        return 1.0
    g = 10 ** ((MUSIC_LUFS - now) / 20.0)
    peak = float(np.max(np.abs(data))) or 1.0
    return min(g, MUSIC_PEAK_LIMIT / peak)


def normalize_sfx(data: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(data))) or 1.0
    return data * (10 ** (SFX_PEAK_DBFS / 20.0) / peak)


def _read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return raw.astype(np.float64) / 32767.0


def check() -> list[str]:
    problems = []
    for p in sorted(glob.glob(os.path.join(ROOT, "audio", "sfx", "*.wav"))):
        pk = peak_dbfs(_read_wav(p))
        if abs(pk - SFX_PEAK_DBFS) > 0.5:
            problems.append("%s: peak %.1f dBFS (want %.0f)" % (os.path.relpath(p, ROOT), pk, SFX_PEAK_DBFS))
    for p in sorted(glob.glob(os.path.join(ROOT, "audio", "music", "*.ogg"))):
        v = lufs_of_file(p)
        if not np.isfinite(v) or abs(v - MUSIC_LUFS) > MUSIC_TOLERANCE:
            problems.append("%s: %.1f LUFS (want %.0f +-%.0f)" % (os.path.relpath(p, ROOT), v, MUSIC_LUFS, MUSIC_TOLERANCE))
    return problems


if __name__ == "__main__":
    bad = check()
    for b in bad:
        print(b)
    print("loudness: %s" % ("OK" if not bad else "%d off target" % len(bad)))
    sys.exit(1 if bad else 0)
