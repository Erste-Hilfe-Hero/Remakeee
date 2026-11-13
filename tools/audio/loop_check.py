#!/usr/bin/env python3
"""Checks that the battle loops in audio/music/ meet themselves at the loop point
(docs/KAMPF_PLAN_1000.md, item 712): decodes each battle*/warden* song with ffmpeg and fails
when the step from the last sample back to the first is bigger than MAX_SEAM of the song's own
99th-percentile sample step (the small files carry codec noise of that order everywhere, so
only a jump that stands out of the music is a click).
Usage: python3 tools/audio/loop_check.py [name ...]"""
import glob
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAX_SEAM = 0.5


def seam(path: str) -> float:
    """Loop-point step as a share of the song's 99th-percentile sample step."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, "<i2").astype(float) / 32768.0
    if len(x) < 2:
        return 0.0
    return abs(float(x[-1]) - float(x[0])) / (float(np.percentile(np.abs(np.diff(x)), 99)) or 1.0)


def main() -> None:
    names = sys.argv[1:]
    paths = [os.path.join(ROOT, "audio/music", n + ".ogg") for n in names] if names else \
        sorted(glob.glob(os.path.join(ROOT, "audio/music/battle*.ogg")) + glob.glob(os.path.join(ROOT, "audio/music/warden*.ogg")))
    bad = []
    for p in paths:
        s = seam(p)
        if s > MAX_SEAM:
            bad.append("%s (%.2f)" % (os.path.basename(p), s))
    if bad:
        sys.exit("loop seams over %.2f of the usual step: %s" % (MAX_SEAM, ", ".join(bad)))
    print("%d battle loops meet themselves" % len(paths))


if __name__ == "__main__":
    main()
