"""Finds spread over all of Veydal, patched onto maps of the other groups (built last).

Cartographer's stones (area 3 items 1084, 1085): one old stone with a compass rose on each of
the twelve outdoor maps of Veydal. Looking at one counts it (MarkerStones.gd); the 4th, 8th
and 12th give a keepsake.

Lake benches (area 3 item 1093): three benches looking out over the lake. Sitting for ten
seconds brings a Spirling call from the water and a true hint about a hidden place.
"""
from common import lines, tr

GROUP = []

STONES = [("brindlewick", 1, 5), ("thornridge", 10, 2), ("copperfold", 8, 1), ("wrenhollow", 8, 13),
          ("reedhaven", 10, 6), ("fernstair", 1, 4), ("crowcrest", 1, 7), ("lantern_steps", 1, 2),
          ("quillbrook", 8, 9), ("gloamwood", 1, 25), ("brackwater_fen", 4, 2), ("saltmarsh", 6, 11)]

# (map, x, y, species heard, hint)
LAKE_BENCHES = [
    ("reedhaven", 1, 5, "Kelpup",
     ("An old fen-cutter rows past: \"That smooth boulder in Brackwater Fen? Hands put it there, to hide a way.\"",
      "Ein alter Torfstecher rudert vorbei: \"Der glatte Felsbrocken im Brackfenn? Den haben Hände dorthin gelegt, um einen Weg zu verstecken.\"")),
    ("brackwater_fen", 8, 4, "Puddlet",
     ("You remember a saying: \"In Quillbrook, the stone too smooth to be natural is a door.\"",
      "Dir fällt ein Spruch ein: \"In Federbach ist der Stein, der zu glatt ist, eine Tür.\"")),
    ("corvane_quay", 4, 19, "Kelpup",
     ("A dockhand mutters as he passes: \"Someone dropped a tonic among the trees on the west side. Never found it.\"",
      "Ein Hafenarbeiter murmelt im Vorbeigehen: \"Jemand hat bei den Bäumen auf der Westseite ein Tonikum verloren. Nie wiedergefunden.\"")),
]


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
    for mid, x, y, species, hint in LAKE_BENCHES:
        m = world.load_map(mid)
        m["signs"] = [s for s in m.get("signs", []) if (s["x"], s["y"]) != (x, y)]
        m["signs"].append({"x": x, "y": y, "dialogue": "%s/lake_bench" % mid})
        set_char(m, x, y, "S")
        world.add_text(mid, {
            "lake_bench": {"lines": lines(("A bench with a view over the lake. Sit and listen for a while?",
                                           "Eine Bank mit Blick über den See. Eine Weile sitzen und lauschen?")),
                           "choices": [{"text": tr("Sit and listen", "Sitzen und lauschen"),
                                        "action": "lake_bench %s %s/lake_hint" % (species, mid)},
                                       {"text": tr("Not now", "Jetzt nicht")}]},
            "lake_hint": lines(hint)})
