"""Finds spread over all of Veydal, patched onto maps of the other groups (built last).

Cartographer's stones (area 3 items 1084, 1085): one old stone with a compass rose on each of
the twelve outdoor maps of Veydal. Looking at one counts it (MarkerStones.gd); the 4th, 8th
and 12th give a keepsake.
"""
from common import lines

GROUP = []

STONES = [("brindlewick", 1, 5), ("thornridge", 10, 2), ("copperfold", 8, 1), ("wrenhollow", 8, 13),
          ("reedhaven", 10, 6), ("fernstair", 1, 4), ("crowcrest", 1, 7), ("lantern_steps", 1, 2),
          ("quillbrook", 8, 9), ("gloamwood", 1, 25), ("brackwater_fen", 4, 2), ("saltmarsh", 6, 11)]


def set_char(m, x, y, ch):
    r = m["rows"][y]
    m["rows"][y] = r[:x] + ch + r[x + 1:]


def build(world):
    for n, (mid, x, y) in enumerate(STONES, 1):
        m = world.load_map(mid)
        m["signs"] = [s for s in m.get("signs", []) if (s["x"], s["y"]) != (x, y)]
        m["signs"].append({"x": x, "y": y, "dialogue": "%s/marker_stone" % mid})
        set_char(m, x, y, "S")
        world.add_text(mid, {"marker_stone": {
            "lines": lines(("An old cartographer's stone. A compass rose is cut into it, worn almost smooth.",
                            "Ein alter Kartografenstein. Eine Windrose ist hineingemeißelt, fast glatt geschliffen.")),
            "action": "marker_stone %d" % n}})
