"""Chimora's original chiptune audio, synthesized from note data written for this game.

    python3 tools/audio/gen_audio.py                 everything
    python3 tools/audio/gen_audio.py --sfx           sound effects only
    python3 tools/audio/gen_audio.py --music         music (and stems) only
    python3 tools/audio/gen_audio.py --only lighthouse --only tick
    python3 tools/audio/gen_audio.py --music --no-stems

Writes audio/sfx/*.wav (16-bit mono 22.05 kHz), audio/music/*.ogg and, for every place song,
audio/music/stems/<name>_<bass|chords|melody|drums>.ogg (Vorbis via ffmpeg). No samples, no
third-party melodies: every sound is built from pulse/triangle/noise waves (synth.py), effects
live in sfx.py, songs in music.py. Every file is normalized on the way out (loudness.py):
music to -16 LUFS, effects to a -3 dBFS peak. Output is deterministic for one ffmpeg build.
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import loudness  # noqa: E402
import music  # noqa: E402
import sfx  # noqa: E402
from synth import ROOT, write_ogg, write_wav  # noqa: E402

SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
STEM_DIR = os.path.join(MUSIC_DIR, "stems")
STEM_QUALITY = 0


def all_songs() -> dict[str, dict]:
    return {**music.SONGS, **music.MAP_SONGS}


def build_song(name: str, spec: dict, stems: bool) -> float:
    song = music.compose(name, **spec)
    parts = song.stems()
    mix = sum(parts.values())
    g = loudness.music_gain(mix)
    write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), mix * g)
    if stems and name in music.MAP_SONGS:
        os.makedirs(STEM_DIR, exist_ok=True)
        for stem, data in parts.items():
            # Stems play together, so a lower Vorbis quality per stem keeps the download small.
            write_ogg(os.path.join(STEM_DIR, "%s_%s.ogg" % (name, stem)), data * g, STEM_QUALITY)
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
    for name, spec in all_songs().items():
        if not do_music or (wanted and name not in wanted):
            continue
        t = build_song(name, spec, args.stems)
        print("music", name, "%.1fs" % t)


if __name__ == "__main__":
    main()
