"""App Store preview video from the frames of tools/store_video.gd (plan Chimora 100, item 89).

  xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/store_video.gd -- /tmp/video
  python3 tools/store/make_store_video.py /tmp/video out.mp4      (needs Pillow and ffmpeg)

Blank frames (one colour: the moment one scene is freed and the next not drawn yet) are left out.
Every frame is scaled to 1080 x 1920 (whole-number upscale, then one smooth step, as the store
pictures) and encoded as App Store previews want it: portrait 1080 x 1920, 30 fps, H.264 High,
yuv420p, at most 30 s, with a silent stereo AAC track (uploads without audio are refused at times).
Nothing is uploaded.
"""
from __future__ import annotations

import glob
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image

W, H, FPS = 1080, 1920, 30
MAX_SECONDS = 29.5


def cover(img: Image.Image) -> Image.Image:
    s = max(W / img.width, H / img.height)
    cw, ch = W / s, H / s
    x0, y0 = (img.width - cw) / 2, (img.height - ch) / 2
    img = img.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch)))
    k = max(1, math.ceil(max(W / img.width, H / img.height)))
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    return big if big.size == (W, H) else big.resize((W, H), Image.LANCZOS)


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    frames = [f for f in sorted(glob.glob(os.path.join(src, "f*.png"))) if len(Image.open(f).getcolors(4) or [0] * 4) > 2]
    frames = frames[: int(MAX_SECONDS * FPS)]
    if not frames:
        raise SystemExit("no frames in " + src)
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(frames):
            cover(Image.open(f).convert("RGB")).save(os.path.join(tmp, "%05d.png" % i), compress_level=1)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "%05d.png"),
                        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
                        "-shortest", "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
                        "-r", str(FPS), "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
                        "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", dst], check=True)
    print("%s: %d frames, %.1f s" % (dst, len(frames), len(frames) / FPS))


if __name__ == "__main__":
    main()
