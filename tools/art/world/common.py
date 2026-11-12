"""Shared helpers for the world builders in tools/art/world/ (area 3 item 895).

Each module (veydal_core, veydal_wilds, veydal_caves, corvane) owns one group of maps and has a
`build(world)` function. Run them with `python3 tools/art/build_world.py [group ...]`.

The Act I maps were first made by a one-off script (kept for reference as act1_original.py.txt)
and have been edited by hand since, so `veydal_core` does not rebuild them: it only *patches*
them (for example adds hidden finds), and every patch is safe to run again. New maps from the
other groups are written whole, so their JSON is generated: edit the Python, not the JSON.
NPCs, finds, signs or warps added straight to a map's JSON belong in tools/art/world/hand/
(`build_world.py --absorb` writes them there); CI runs `build_world.py --check`, so a rebuild
can never drop them.
Map legend: see TilesetFactory.LEGEND and the header of scripts/overworld/MapData.gd.
"""
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MAPS = os.path.join(ROOT, "data", "maps")
DIA = os.path.join(ROOT, "data", "dialogue")
ORDER = ["name", "region", "biome", "backdrop", "outdoor", "field", "encounters", "heal_point",
         "rows", "warps", "npcs", "signs", "gear_spots", "blocks", "secrets", "floors", "passages", "spots", "sluices", "beam"]


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


# German texts for generated maps: tr("English", "Deutsch") records the pair and returns the
# English text (the key). World.write() puts them into tools/i18n/de_welt_maps.py.
GERMAN = {}


def tr(en, de):
    if en in GERMAN and GERMAN[en] != de:
        raise SystemExit("two German texts for %r" % en)
    GERMAN[en] = de
    return en


def lines(*pairs):
    """Dialogue lines from (English, German) pairs."""
    return [tr(en, de) for en, de in pairs]


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

    def render(self):
        """Every output file as {path: text}, with the hand-added overlays applied."""
        out = {}
        for mid, m in self.maps.items():
            m = apply_hand(m, load_hand(mid))
            out[os.path.join(MAPS, mid + ".json")] = json.dumps(_ordered(m), indent=1, ensure_ascii=False) + "\n"
        for fid, t in self.text.items():
            t = dict(t)
            t.update(load_hand("dialogue/" + fid))
            out[os.path.join(DIA, fid + ".json")] = json.dumps(t, indent=1, ensure_ascii=False) + "\n"
        if GERMAN:
            known = other_german()
            rows = ["# German texts for the generated area 3 maps. Written by tools/art/build_world.py:\n",
                    "# edit the tr()/lines() pairs in tools/art/world/*.py, not this file.\n", "T = {\n"]
            for en in sorted(GERMAN):
                if known.get(en) == GERMAN[en]:
                    continue
                rows.append("%s: %s,\n" % (json.dumps(en, ensure_ascii=False), json.dumps(GERMAN[en], ensure_ascii=False)))
            rows.append("}\n")
            out[os.path.join(ROOT, "tools", "i18n", "de_welt_maps.py")] = "".join(rows)
        return out

    def write(self):
        for path, text in self.render().items():
            with open(path, "w") as f:
                f.write(text)
        print("wrote %d maps, %d dialogue files, %d German texts" % (len(self.maps), len(self.text), len(GERMAN)))

    def check(self):
        """Paths whose file on disk differs from what the build would write."""
        stale = []
        for path, text in sorted(self.render().items()):
            on_disk = open(path).read() if os.path.exists(path) else None
            if on_disk != text:
                stale.append(os.path.relpath(path, ROOT))
        return stale

    def absorb(self, committed):
        """Writes hand/ overlays so the build reproduces the [param committed] map and dialogue
        JSON (read before the build ran); returns the overlay files written or removed."""
        touched = []
        for mid, m in self.maps.items():
            if mid in committed["maps"]:
                touched += _save_hand(mid, diff_hand(m, committed["maps"][mid]))
        for fid, t in self.text.items():
            com = committed["text"].get(fid, {})
            ov = {k: com[k] for k in t if k in com and com[k] != t[k]}
            touched += _save_hand("dialogue/" + fid, ov)
        return touched


# --- Hand-added content -----------------------------------------------------------------------
# Story and side-content work often adds NPCs, finds, signs or warps straight into a map's JSON.
# Those live in tools/art/world/hand/<map>.json (and hand/dialogue/<file>.json for dialogue
# entries edited by hand) and are applied on top of the generated map, so a rebuild keeps them.
# `build_world.py --absorb` writes these files from the JSON as it is now; `--check` (CI) fails
# when a rebuild would change data/, so the JSON and the generator cannot drift apart again.
# Overlay format: {"set": {key: value}, "unset": [key], "add": {list: [entry]},
#                  "replace": {list: [entry]}, "drop": {list: [entry key]}}
# List entries are matched by "id", else by their cell "x,y" (see entry_key()).
HAND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hand")


def entry_key(e):
    if isinstance(e, dict):
        if "id" in e:
            return "id:%s" % e["id"]
        if "x" in e and "y" in e:
            return "at:%s,%s" % (e["x"], e["y"])
    return None


def _keyed(lst):
    """{key: entry} when every entry of [param lst] has its own key, else None."""
    if not isinstance(lst, list):
        return None
    keys = [entry_key(e) for e in lst]
    if None in keys or len(set(keys)) != len(keys):
        return None
    return dict(zip(keys, lst))


def load_hand(name):
    path = os.path.join(HAND, name + ".json")
    return json.load(open(path)) if os.path.exists(path) else {}


def _save_hand(name, ov):
    path = os.path.join(HAND, name + ".json")
    if not ov:
        if os.path.exists(path):
            os.remove(path)
            return [path]
        return []
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = json.dumps(ov, indent=1, ensure_ascii=False) + "\n"
    if not os.path.exists(path) or open(path).read() != text:
        with open(path, "w") as f:
            f.write(text)
        return [path]
    return []


def apply_hand(m, ov):
    if not ov:
        return m
    m = dict(m)
    for k, v in ov.get("set", {}).items():
        m[k] = v
    for k in ov.get("unset", []):
        m.pop(k, None)
    for k in set(ov.get("add", {})) | set(ov.get("replace", {})) | set(ov.get("drop", {})):
        rep = {entry_key(e): e for e in ov.get("replace", {}).get(k, [])}
        drop = set(ov.get("drop", {}).get(k, []))
        lst = [rep.get(entry_key(e), e) for e in m.get(k, []) if entry_key(e) not in drop]
        m[k] = lst + ov.get("add", {}).get(k, [])
    return m


def diff_hand(gen, com):
    """Overlay that turns the generated map [param gen] into the committed map [param com]."""
    ov = {}
    for k in set(gen) | set(com):
        if k not in com:
            ov.setdefault("unset", []).append(k)
            continue
        if gen.get(k) == com[k]:
            continue
        g, c = _keyed(gen.get(k, [])), _keyed(com[k])
        if g is None or c is None:
            ov.setdefault("set", {})[k] = com[k]
            continue
        add = [e for kk, e in c.items() if kk not in g]
        rep = [e for kk, e in c.items() if kk in g and g[kk] != e]
        drop = [kk for kk in g if kk not in c]
        for name, val in (("add", add), ("replace", rep), ("drop", drop)):
            if val:
                ov.setdefault(name, {})[k] = val
    if "unset" in ov:
        ov["unset"].sort()
    return {k: (dict(sorted(v.items())) if isinstance(v, dict) else v) for k, v in sorted(ov.items())}


def other_german():
    """German texts of the other tools/i18n/de_*.py tables (a text kept there is not repeated
    in de_welt_maps.py)."""
    out = {}
    folder = os.path.join(ROOT, "tools", "i18n")
    for f in sorted(os.listdir(folder)):
        if not (f.startswith("de_") and f.endswith(".py")) or f == "de_welt_maps.py":
            continue
        ns = {}
        try:
            exec(compile(open(os.path.join(folder, f)).read(), f, "exec"), ns)
        except Exception:  # noqa: BLE001 - a table that needs imports is skipped
            continue
        if isinstance(ns.get("T"), dict):
            out.update(ns["T"])
    return out


def check_rows(map_id, rows):
    """All rows the same width, only known tile characters."""
    legend = set(".,_~THRDf#S*CWoX^=%:+|L@wBPkvY")
    for i, r in enumerate(rows):
        if len(r) != len(rows[0]):
            raise SystemExit("%s row %d is %d wide, expected %d" % (map_id, i, len(r), len(rows[0])))
        bad = set(r) - legend
        if bad:
            raise SystemExit("%s row %d has unknown tiles %s" % (map_id, i, "".join(sorted(bad))))
