"""Overworld sheet for a First Voice resting place (plan area 1, item 154): a soft light that
floats over the water and bobs between two frames. Same layout as the NPC sheets: 4 columns
(down, up, left, right) x 2 step frames of 16 px, in the four Era I shades.
Writes art/era1/chars/first_voice.png. Run: python3 tools/art/gen_first_voice.py"""
import os

from PIL import Image

INK, DARK, MID, LIGHT = (42, 30, 44, 255), (106, 66, 86, 255), (196, 138, 94, 255), (242, 227, 194, 255)


def frame(img, ox, oy, lift):
    def put(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            img.putpixel((ox + x, oy + y), c)
    # ripple ring on the water
    for x in range(3, 13):
        put(x, 14, DARK)
    put(2, 13, DARK); put(13, 13, DARK)
    # the light: an outlined orb with a bright core and four short rays
    cy = 7 - lift
    for y in range(cy - 3, cy + 4):
        for x in range(5, 11):
            d = (x - 7.5) ** 2 + (y - cy) ** 2
            if d <= 10:
                put(x, y, MID)
            if d <= 4:
                put(x, y, LIGHT)
    for x, y in [(4, cy), (11, cy), (7, cy - 4), (8, cy - 4), (7, cy + 4), (8, cy + 4)]:
        put(x, y, INK)
    for x, y in [(2, cy), (13, cy), (7, cy - 6), (8, cy + 6)]:
        put(x, y, LIGHT)


def main():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for col in range(4):
        for row in range(2):
            frame(img, col * 16, row * 16, row)
    out = os.path.join(os.path.dirname(__file__), "..", "..", "art", "era1", "chars", "first_voice.png")
    img.save(out)


if __name__ == "__main__":
    main()
