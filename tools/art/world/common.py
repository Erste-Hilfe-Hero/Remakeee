"""Shared helpers for the world builders in tools/art/world/ (area 3 item 895).

Each module (veydal_core, veydal_wilds, veydal_caves, corvane) owns one group of maps and has a
`build(world)` function. Run them with `python3 tools/art/build_world.py [group ...]`.

The Act I maps were first made by a one-off script (kept for reference as act1_original.py.txt)
and have been edited by hand since, so `veydal_core` does not rebuild them: it only *patches*
them (for example adds hidden finds), and every patch is safe to run again. New maps from the
other groups are written whole, so their JSON is generated: edit the Python, not the JSON.
Map legend: see TilesetFactory.LEGEND and the header of scripts/overworld/MapData.gd.
"""
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MAPS = os.path.join(ROOT, "data", "maps")
DIA = os.path.join(ROOT, "data", "dialogue")
ORDER = ["name", "region", "biome", "backdrop", "outdoor", "field", "encounters", "heal_point",
         "rows", "warps", "npcs", "signs", "gear_spots", "blocks", "secrets", "floors"]


def warp(x, y, to, tx, ty, facing):
    return {"x": x, "y": y, "to": to, "tx": tx, "ty": ty, "facing": facing}


def npc(id_, x, y, facing, dialogue, sprite, **kw):
    d = {"id": id_, "x": x, "y": y, "facing": facing, "dialogue": dialogue, "sprite": sprite}
    d.update(kw)
    return d


def team(*pairs):
    return [{"species": s, "level": l} for s, l in pairs]


def secret(x, y, item, flag, count=1):
    return {"x": x, "y": y, "item": item, "count": count, "flag": flag}


def _ordered(m):
    out = {k: m[k] for k in ORDER if k in m}
    out.update({k: v for k, v in m.items() if k not in out})
    return out


class World:
    """Collects maps and dialogue, then writes only what changed."""

    def __init__(self):
        self.maps = {}
        self.text = {}

    def add_map(self, map_id, data):
        if map_id in self.maps:
            raise SystemExit("map %s is built twice" % map_id)
        data.setdefault("signs", [])
        self.maps[map_id] = data

    def load_map(self, map_id):
        """The current JSON of an existing map (for patches)."""
        if map_id not in self.maps:
            with open(os.path.join(MAPS, map_id + ".json")) as f:
                self.maps[map_id] = json.load(f)
        return self.maps[map_id]

    def dialogue(self, file_id):
        """Current dialogue entries of data/dialogue/<file_id>.json (read only)."""
        if file_id in self.text:
            return self.text[file_id]
        path = os.path.join(DIA, file_id + ".json")
        return json.load(open(path)) if os.path.exists(path) else {}

    def add_text(self, file_id, entries):
        """Sets dialogue keys in data/dialogue/<file_id>.json (other keys stay)."""
        if file_id not in self.text:
            path = os.path.join(DIA, file_id + ".json")
            self.text[file_id] = json.load(open(path)) if os.path.exists(path) else {}
        self.text[file_id].update(entries)

    def write(self):
        for mid, m in self.maps.items():
            with open(os.path.join(MAPS, mid + ".json"), "w") as f:
                json.dump(_ordered(m), f, indent=1, ensure_ascii=False)
                f.write("\n")
        for fid, t in self.text.items():
            with open(os.path.join(DIA, fid + ".json"), "w") as f:
                json.dump(t, f, indent=1, ensure_ascii=False)
                f.write("\n")
        print("wrote %d maps, %d dialogue files" % (len(self.maps), len(self.text)))


def check_rows(map_id, rows):
    """All rows the same width, only known tile characters."""
    legend = set(".,_~THRDf#S*CWoX^=%:+|L@wBPkvY")
    for i, r in enumerate(rows):
        if len(r) != len(rows[0]):
            raise SystemExit("%s row %d is %d wide, expected %d" % (map_id, i, len(r), len(rows[0])))
        bad = set(r) - legend
        if bad:
            raise SystemExit("%s row %d has unknown tiles %s" % (map_id, i, "".join(sorted(bad))))
