"""Chimora's original chiptune audio, synthesized from note data written for this game.

    python3 tools/audio/gen_audio.py                 everything
    python3 tools/audio/gen_audio.py --sfx           sound effects only
    python3 tools/audio/gen_audio.py --music         music (and stems) only
    python3 tools/audio/gen_audio.py --only lighthouse --only tick
    python3 tools/audio/gen_audio.py --music --no-stems

Writes audio/sfx/*.wav (16-bit mono 22.05 kHz), audio/music/*.ogg and, for every place song,
audio/music/stems/<name>_<bass|chords|melody|drums>.ogg and audio/ambience/*.ogg (Vorbis via
ffmpeg). No samples, no
third-party melodies: every sound is built from pulse/triangle/noise waves (synth.py), effects
live in sfx.py, songs in music.py, ambience loops in ambience.py. Every file is normalized on the way out (loudness.py):
music to -16 LUFS, effects to a -3 dBFS peak. Output is deterministic for one ffmpeg build.
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ambience  # noqa: E402
import era_sfx  # noqa: E402
import loudness  # noqa: E402
import music  # noqa: E402
import sfx  # noqa: E402
from synth import ROOT, write_ogg, write_wav  # noqa: E402

SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
STEM_DIR = os.path.join(MUSIC_DIR, "stems")
AMBIENCE_DIR = os.path.join(ROOT, "audio", "ambience")
AMBIENCE_QUALITY = 0
STEM_QUALITY = 0


def all_songs() -> dict[str, dict]:
    return {**music.SONGS, **music.MAP_SONGS, **music.EXTRA_SONGS}


def write_loud(path: str, data: np.ndarray, quality: int, small: bool = False) -> None:
    """Writes [data] at -16 LUFS; low Vorbis qualities shift the loudness of bright sounds, so
    the file is measured once and written again with the correction."""
    g = loudness.music_gain(data)
    write_ogg(path, data * g, quality, small)
    off = loudness.MUSIC_LUFS - loudness.lufs_of_file(path)
    if abs(off) > 0.5:
        g = min(g * 10 ** (off / 20.0), loudness.MUSIC_PEAK_LIMIT / (float(np.max(np.abs(data))) or 1.0))
        write_ogg(path, data * g, quality, small)


def loops_clean(name: str) -> bool:
    """Battle loops end on their first sample (music.close_loop, KAMPF_PLAN_1000 item 712)."""
    return name.startswith(("battle", "warden"))


def build_song(name: str, spec: dict, stems: bool) -> float:
    song = music.compose(name, **spec)
    parts = song.stems()
    mix = sum(parts.values())
    if loops_clean(name):
        mix = music.close_loop(mix)
    if name in music.EXTRA_SONGS:
        write_loud(os.path.join(MUSIC_DIR, name + ".ogg"), mix, 0, small=True)
        if stems and name in music.LAYERED_SONGS:
            g = loudness.music_gain(mix)
            os.makedirs(STEM_DIR, exist_ok=True)
            for stem, data in parts.items():
                write_ogg(os.path.join(STEM_DIR, "%s_%s.ogg" % (name, stem)), data * g, STEM_QUALITY, small=True)
        return len(mix) / 22050.0
    g = loudness.music_gain(mix)
    # A place song's full mix only plays where its stems cannot (sound test, era fallback), so
    # it is written small; the stems carry the in-game quality.
    write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), mix * g, small=name in music.MAP_SONGS)
    if stems and name in music.MAP_SONGS:
        os.makedirs(STEM_DIR, exist_ok=True)
        for stem, data in parts.items():
            # Stems play together, so 16 kHz / 16 kbit/s per stem keeps the download small
            # (APK size budget; the full mixes are not even exported, see export_presets.cfg).
            write_ogg(os.path.join(STEM_DIR, "%s_%s.ogg" % (name, stem)), data * g, STEM_QUALITY, small=True)
    return len(mix) / 22050.0


def main() -> None:
    ap = argparse.ArgumentParser(description="Build Chimora's sound effects and music.")
    ap.add_argument("--only", action="append", default=[], help="build only this sound or song (repeatable)")
    ap.add_argument("--sfx", action="store_true", help="build sound effects only")
    ap.add_argument("--music", action="store_true", help="build music only")
    ap.add_argument("--stems", dest="stems", action="store_true", default=True, help="also write stems (default)")
    ap.add_argument("--no-stems", dest="stems", action="store_false", help="skip the stems")
    args = ap.parse_args()
    do_sfx = args.sfx or not args.music
    do_music = args.music or not args.sfx
    wanted = set(args.only)
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    # Every effect is always synthesized (they share one seeded noise source, so skipping one
    # would change the next); --only just limits what is written.
    for name, data in sfx.sfx_defs().items():
        if not do_sfx or (wanted and name not in wanted):
            continue
        write_wav(os.path.join(SFX_DIR, name + ".wav"), loudness.normalize_sfx(data))
        print("sfx", name)
    # Era sound sets (era_sfx.py) have their own seeded noise, so they never shift the above.
    for name, data in era_sfx.sfx_defs().items():
        if not do_sfx or (wanted and name not in wanted):
            continue
        write_wav(os.path.join(SFX_DIR, name + ".wav"), loudness.normalize_sfx(era_sfx.downsample(name, data)), era_sfx.rate_of(name))
        print("sfx", name)
    for name, spec in all_songs().items():
        if not do_music or (wanted and name not in wanted):
            continue
        t = build_song(name, spec, args.stems)
        print("music", name, "%.1fs" % t)
    if do_music:
        os.makedirs(AMBIENCE_DIR, exist_ok=True)
        for name, data in ambience.loops().items():
            if wanted and name not in wanted:
                continue
            write_loud(os.path.join(AMBIENCE_DIR, name + ".ogg"), data, AMBIENCE_QUALITY)
            print("ambience", name, "%.1fs" % (len(data) / 22050.0))
        total = sum(os.path.getsize(os.path.join(AMBIENCE_DIR, f)) for f in os.listdir(AMBIENCE_DIR) if f.endswith(".ogg"))
        if total > ambience.MAX_BYTES:
            sys.exit("ambience is %.1f MB, the limit is %.1f MB" % (total / 1e6, ambience.MAX_BYTES / 1e6))


if __name__ == "__main__":
    main()
