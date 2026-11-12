"""Map and building audit: looks for things that make a map look unclean or broken.

Usage: python3 tools/maps/audit_maps.py                    list every finding, grouped by map
       python3 tools/maps/audit_maps.py --check            exit 1 on a finding that is not in the
                                                          baseline (tools/maps/audit_baseline.json)
       python3 tools/maps/audit_maps.py --write-baseline   accept the current findings as known
       python3 tools/maps/audit_maps.py --json             findings as JSON
The baseline lists the findings still open (or accepted on purpose, with a "why"). A fix removes
its line from the baseline (--write-baseline keeps the "why" of lines that stay); a new map must
not add findings. CI runs --check, and also fails when a baseline line is already fixed so the
list never goes stale.

Reads data/maps/*.json (and their floors) with the same tile rules as TilesetFactory and
tools/art/preview_map.py. Kinds of finding:
  unknown_tile    a row character that is not in the legend (drawn as plain grass at runtime)
  blank_tile      an atlas cell used by the map is empty in the map's atlas (Era I region atlas
                  or the shared Era II atlas)
  ragged_row      rows of different length (the short row ends in void)
  dead_door       a door with no warp: the player walks into it and nothing happens
  warp_off_door   a warp inside the map that is not on a door, stairs, Rift, ladder or the edge
  warp_no_return  a door warp whose destination has no warp back to this map
  warp_bad_land   a warp that lands on a blocked cell or on a missing map
  door_no_wall    a door with no wall, roof or tower above it (a door standing in the open)
  door_blocked    a door with no walkable cell below it
  wall_no_roof    a building wall with no roof or wall above it (a cut-off house)
  roof_no_wall    a roof row with nothing under it (a roof floating on the ground)
  wall_on_roof    a wall drawn above a roof (building stacked the wrong way round)
  building_edge   a building that touches the map edge (cut off by the border)
  building_touch  two buildings sharing an edge without a gap, or a tree/rock grown into one
  on_water        a sign, lamp, tower, landmark, NPC or find standing in water
  npc_in_wall     an NPC or sign cell on a wall, roof, door, tree, rock or cliff
  npc_on_warp     an NPC standing on a warp or right in front of a door
  small_interior  an interior narrower than the building that leads into it
  region_mismatch a door that leads into a room of another region (other atlas, other inks)
  unreachable     walkable cells (or finds, NPCs) no entry of the map can reach
  no_door         an outdoor building with no door at all
  building_cut    a building only one tile wide (a sliver of a house)
  tower_no_lamp   a lighthouse shaft with no lamp on top and no door below (a stray tower piece)
  open_edge       a walkable border cell of an outdoor map with no warp (the path runs into void)
"""
import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
from preview_map import JOINS, LEGEND, MASKED, SCATTERED, door_roles, lighthouse_door  # noqa: E402
from gen_tiles import K  # noqa: E402

SOLID = {"WATER", "TREE", "WALL", "ROOF", "FENCE", "SIGN", "COUNTER", "INNER_WALL", "SPRING", "CLIFF",
         "TOWER", "LAMP", "ROCK", "WADE", "BOULDER", "VINES", "PLANK"}
# For reachability: gear and puzzle cells count as passable (the player gets through later).
PASSABLE_LATER = {"WADE", "VINES", "PLANK", "BOULDER"}
BUILDING = {"WALL", "ROOF", "DOOR"}
HARD = {"WALL", "ROOF", "DOOR", "TREE", "ROCK", "CLIFF", "INNER_WALL", "TOWER", "WATER", "FENCE", "COUNTER", "SPRING"}
BASELINE = os.path.join(ROOT, "tools", "maps", "audit_baseline.json")


def map_ids() -> list:
    out = []
    for f in sorted(os.listdir(os.path.join(ROOT, "data", "maps"))):
        if not f.endswith(".json"):
            continue
        mid = f[:-5]
        d = json.load(open(os.path.join(ROOT, "data", "maps", f)))
        out.append(mid)
        out += ["%s@%d" % (mid, i + 1) for i, fl in enumerate(d.get("floors", [])) if "rows" in fl]
    return out


def load(mid: str) -> dict:
    file, _, level = mid.partition("@")
    d = json.load(open(os.path.join(ROOT, "data", "maps", file + ".json")))
    if level:
        fl = dict(d["floors"][int(level) - 1])
        for k in ("name", "region", "outdoor", "biome"):
            fl.setdefault(k, d.get(k))
        d = fl
    d = dict(d)
    d["id"] = mid
    return d


class Map:
    def __init__(self, mid: str):
        self.id = mid
        self.d = load(mid)
        self.rows = self.d["rows"]
        self.h = len(self.rows)
        self.w = max(len(r) for r in self.rows)
        self.region = self.d.get("region", "veydal")
        self.outdoor = bool(self.d.get("outdoor"))
        self.warps = self.d.get("warps", [])
        self.warp_cells = {(int(w["x"]), int(w["y"])): w for w in self.warps}

    def ch(self, x: int, y: int) -> str:
        if 0 <= y < self.h and 0 <= x < len(self.rows[y]):
            return self.rows[y][x]
        return ""

    def kind(self, x: int, y: int) -> str:
        c = self.ch(x, y)
        return LEGEND.get(c, "GRASS") if c else ""

    def inb(self, x: int, y: int) -> bool:
        return 0 <= y < self.h and 0 <= x < len(self.rows[y])

    def cells(self):
        for y in range(self.h):
            for x in range(len(self.rows[y])):
                yield x, y


_atlases = {}


def atlas(path: str) -> Image.Image:
    if path not in _atlases:
        _atlases[path] = Image.open(path).convert("RGBA")
    return _atlases[path]


def atlas_paths(region: str) -> list:
    tiles = os.path.join(ROOT, "art", "era1", "tiles")
    own = os.path.join(tiles, "overworld_%s.png" % region)
    out = [own if os.path.exists(own) else os.path.join(tiles, "overworld.png")]
    era2 = os.path.join(ROOT, "art", "era2", "tiles", "overworld.png")
    if os.path.exists(era2):
        out.append(era2)
    return out


def coords(m: Map, x: int, y: int, roles: dict) -> tuple:
    """Same as TilesetFactory.atlas_coords."""
    k = m.kind(x, y)
    if k == "DOOR" and lighthouse_door(m.rows, x, y):
        return K["TOWER"], 2
    if k == "TOWER" and m.kind(x, y + 1) == "DOOR" and lighthouse_door(m.rows, x, y + 1):
        return K["TOWER"], 1
    if k in MASKED:
        v = 0
        for bit, (dx, dy) in zip((1, 2, 4, 8), ((0, -1), (1, 0), (0, 1), (-1, 0))):
            o = m.kind(x + dx, y + dy) or k
            if o == k or o in JOINS.get(k, set()):
                v |= bit
        return K[k], v
    if k in SCATTERED:
        v = abs(x * 7 + y * 13 + (x * y) % 5) % 4
        left = m.kind(x - 1, y)
        if k == "GRASS" and left in {"WALL", "ROOF", "DOOR"} and not (left == "DOOR" and lighthouse_door(m.rows, x - 1, y)):
            v += 4
        return K[k], v
    if k == "DOOR":
        return K[k], roles.get((x, y), 0)
    return K[k], 0


def walkable(m: Map, x: int, y: int, later: bool = True) -> bool:
    k = m.kind(x, y)
    if not k:
        return False
    if k in SOLID:
        return later and k in PASSABLE_LATER
    return True


def components(m: Map, kinds: set) -> list:
    seen, out = set(), []
    for x, y in m.cells():
        if (x, y) in seen or m.kind(x, y) not in kinds:
            continue
        comp, q = [], deque([(x, y)])
        seen.add((x, y))
        while q:
            c = q.popleft()
            comp.append(c)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if n not in seen and m.kind(*n) in kinds:
                    seen.add(n)
                    q.append(n)
        out.append(comp)
    return out


def check_map(m: Map, maps: dict, entries_into: dict) -> list:
    f = []

    def add(kind: str, x, y, msg: str) -> None:
        f.append({"map": m.id, "kind": kind, "x": x, "y": y, "msg": msg})

    widths = {len(r) for r in m.rows}
    if len(widths) > 1:
        add("ragged_row", -1, -1, "row lengths %s" % sorted(widths))
    for x, y in m.cells():
        if m.ch(x, y) not in LEGEND:
            add("unknown_tile", x, y, "character %r" % m.ch(x, y))
    roles = door_roles(m.d)
    used = {coords(m, x, y, roles) for x, y in m.cells() if m.ch(x, y) in LEGEND}
    for p in atlas_paths(m.region):
        a = atlas(p)
        for col, row in sorted(used):
            box = a.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))
            if box.getbbox() is None or box.getextrema()[3][1] == 0:
                add("blank_tile", -1, -1, "%s column %d row %d is empty in %s" % (
                    [k for k, v in K.items() if v == col][0], col, row, os.path.relpath(p, ROOT)))

    # Doors and warps.
    for x, y in m.cells():
        k = m.kind(x, y)
        if k != "DOOR":
            continue
        if (x, y) not in m.warp_cells:
            add("dead_door", x, y, "door leads nowhere")
        above = m.kind(x, y - 1)
        if above not in {"WALL", "ROOF", "TOWER", "INNER_WALL", "CLIFF"} and m.outdoor:
            add("door_no_wall", x, y, "nothing above the door (%s)" % (above or "edge"))
        if m.outdoor and not (walkable(m, x, y + 1) or not m.inb(x, y + 1)):
            add("door_blocked", x, y, "no ground in front of the door")
    for (x, y), w in m.warp_cells.items():
        k = m.kind(x, y)
        edge = x in (0, m.w - 1) or y in (0, m.h - 1)
        if k not in {"DOOR", "STAIRS", "RIFT"} and not edge and not str(w["to"]).startswith(m.id.split("@")[0]):
            add("warp_off_door", x, y, "warp to %s sits on %s" % (w["to"], k))
        to = str(w["to"])
        if to not in maps:
            add("warp_bad_land", x, y, "warp to unknown map %s" % to)
            continue
        dest = maps[to]
        tx, ty = int(w.get("tx", -1)), int(w.get("ty", -1))
        if not walkable(dest, tx, ty, later=False):
            add("warp_bad_land", x, y, "lands on %s at %d,%d in %s" % (dest.kind(tx, ty) or "void", tx, ty, to))
        if k == "DOOR" and not any(str(b["to"]) == m.id for b in dest.warps):
            add("warp_no_return", x, y, "%s has no warp back here" % to)

    # Buildings: roof above wall above door.
    for x, y in m.cells():
        k = m.kind(x, y)
        if k == "WALL" and m.outdoor:
            above = m.kind(x, y - 1)
            if above not in {"ROOF", "WALL", "TOWER", "LAMP", ""}:
                add("wall_no_roof", x, y, "wall with %s above" % above)
        if k == "ROOF" and m.outdoor:
            below = m.kind(x, y + 1)
            if below not in {"ROOF", "WALL", "DOOR", ""}:
                add("roof_no_wall", x, y, "roof with %s below" % below)
            if m.kind(x, y - 1) == "WALL":
                add("wall_on_roof", x, y, "wall above a roof")
    if m.outdoor:
        for comp in components(m, BUILDING):
            xs = [c[0] for c in comp]
            ys = [c[1] for c in comp]
            if min(xs) == 0 or max(xs) == m.w - 1 or min(ys) == 0 or max(ys) == m.h - 1:
                add("building_edge", min(xs), min(ys), "building %d,%d-%d,%d touches the map edge" % (
                    min(xs), min(ys), max(xs), max(ys)))
            doors = [c for c in comp if m.kind(*c) == "DOOR"]
            if len(doors) > 1:
                rowsets = {c[1] for c in doors}
                add("building_touch", min(xs), min(ys), "one block %d,%d-%d,%d holds %d doors (houses grown together)" % (
                    min(xs), min(ys), max(xs), max(ys), len(doors)))
            if not doors and not any(m.kind(*c) == "TOWER" for c in comp):
                add("no_door", min(xs), min(ys), "building %d,%d-%d,%d has no door" % (min(xs), min(ys), max(xs), max(ys)))
            if max(xs) - min(xs) < 1 and len(comp) > 1:
                add("building_cut", min(xs), min(ys), "building %d,%d-%d,%d is one tile wide (cut off)" % (
                    min(xs), min(ys), max(xs), max(ys)))
            for c in comp:
                for dx, dy in ((1, 0), (-1, 0)):
                    n = (c[0] + dx, c[1] + dy)
                    # The tree, rock or cliff frame of a map may touch a house; anything inside it may not.
                    if n[0] in (0, m.w - 1):
                        continue
                    if m.kind(*n) in {"TREE", "ROCK", "CLIFF"} and m.kind(*c) != "DOOR":
                        add("building_touch", c[0], c[1], "%s grows into the building" % m.kind(*n))
                        break

    # Things standing in water or inside walls.
    def water(x, y):
        return m.kind(x, y) in {"WATER"}
    for x, y in m.cells():
        k = m.kind(x, y)
        if k in {"SIGN", "LAMP", "TOWER"} and m.outdoor:
            below = m.kind(x, y + 1)
            if k == "SIGN" and all(water(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if m.inb(x + dx, y + dy)):
                add("on_water", x, y, "sign in open water")
            if k == "LAMP" and below == "WATER":
                add("on_water", x, y, "lamp over water")
    hard = HARD | {"SIGN", "LAMP", "BOULDER"}
    for n in m.d.get("npcs", []):
        x, y = int(n["x"]), int(n["y"])
        k = m.kind(x, y)
        if k == "WATER":
            add("on_water", x, y, "npc %s in water" % n.get("id"))
        elif k in hard - {"COUNTER"}:
            add("npc_in_wall", x, y, "npc %s on %s" % (n.get("id"), k))
        if (x, y) in m.warp_cells:
            add("npc_on_warp", x, y, "npc %s on a warp" % n.get("id"))
        elif m.kind(x, y - 1) == "DOOR" and m.outdoor:
            add("npc_on_warp", x, y, "npc %s blocks a door" % n.get("id"))
    # Sign texts on other cells are fine: they read a wall, a rock or a fish trap.
    lm = LANDMARKS.get(m.id)
    # Tide posts stand in the water on purpose.
    if lm and m.kind(lm["x"], lm["y"]) == "WATER" and "tide_post" not in lm["kind"]:
        add("on_water", lm["x"], lm["y"], "landmark %s in water" % lm["kind"])

    # Lighthouse tower tiles: a shaft needs its lamp on top, or it reads as a stray lighthouse
    # piece (tower over a door without a lamp is the dark Saltglass lighthouse, see ashmere.py).
    # Rifts use the tower as stone pillars, so only outdoor maps are checked.
    for x, y in m.cells():
        if not m.outdoor or m.kind(x, y) != "TOWER" or m.kind(x, y - 1) == "TOWER":
            continue
        yy = y
        while m.kind(x, yy) == "TOWER":
            yy += 1
        if m.kind(x, y - 1) != "LAMP" and m.kind(x, yy) != "DOOR":
            add("tower_no_lamp", x, y, "lighthouse shaft %d,%d-%d,%d with no lamp and no door" % (x, y, x, yy - 1))

    # Interiors: no narrower than the building that leads in, same region.
    for (x, y), w in m.warp_cells.items():
        if m.kind(x, y) != "DOOR" or not m.outdoor:
            continue
        dest = maps.get(str(w["to"]))
        if dest is None or dest.outdoor:
            continue
        comp = next((c for c in components(m, BUILDING) if (x, y) in c), [])
        bw = len({c[0] for c in comp if c[1] == y})
        if dest.w < bw:
            add("small_interior", x, y, "%s is %d wide, the building %d" % (dest.id, dest.w, bw))
        if dest.region != m.region:
            add("region_mismatch", x, y, "%s (%s) behind a %s door" % (dest.id, dest.region, m.region))

    # Reachability from every entry (warp landings into this map, its own warps, NPCs on stairs).
    starts = set(entries_into.get(m.id, set())) | set(m.warp_cells)
    seen, q = set(), deque(c for c in starts if walkable(m, *c) or c in m.warp_cells)
    seen |= set(q)
    while q:
        c = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if n not in seen and walkable(m, *n):
                seen.add(n)
                q.append(n)
    # A block opened by a puzzle flag, a ladder, a gear jump or a drop counts as a way through.
    extra = [(int(b["x"]), int(b["y"])) for b in m.d.get("blocks", [])]
    extra += [(int(p["x"]), int(p["y"])) for p in m.d.get("passages", [])]
    for g in m.d.get("gear_spots", []):
        extra += [tuple(g.get("to", [])), tuple(g.get("from", []))]
    if seen and (extra or m.d.get("ladders")):
        q = deque(c for c in extra if len(c) == 2)
        for c in q:
            seen.add(c)
        while q:
            c = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if n not in seen and walkable(m, *n):
                    seen.add(n)
                    q.append(n)
    if starts:
        lost = [c for c in m.cells() if walkable(m, *c) and c not in seen]
        if lost:
            for comp in _groups(lost):
                if len(comp) >= 2 or any(_has_thing(m, c) for c in comp):
                    xs = [c[0] for c in comp]
                    ys = [c[1] for c in comp]
                    add("unreachable", min(xs), min(ys), "%d cells %d,%d-%d,%d cannot be reached" % (
                        len(comp), min(xs), min(ys), max(xs), max(ys)))

    # Paths that run into the border without a warp.
    if m.outdoor:
        for x, y in m.cells():
            if not (x in (0, m.w - 1) or y in (0, m.h - 1)):
                continue
            if m.kind(x, y) in {"PATH", "PIER", "STAIRS"} and (x, y) not in m.warp_cells:
                add("open_edge", x, y, "%s runs off the map with no warp" % m.kind(x, y))
    return f


def _groups(cells: list) -> list:
    left, out = set(cells), []
    while left:
        c = left.pop()
        comp, q = [c], deque([c])
        while q:
            a = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (a[0] + dx, a[1] + dy)
                if n in left:
                    left.remove(n)
                    comp.append(n)
                    q.append(n)
        out.append(comp)
    return out


def _has_thing(m: Map, c: tuple) -> bool:
    things = [(int(n["x"]), int(n["y"])) for n in m.d.get("npcs", [])]
    things += [(int(s["x"]), int(s["y"])) for s in m.d.get("secrets", [])]
    return c in things


LANDMARKS = json.load(open(os.path.join(ROOT, "data", "landmarks.json")))["maps"]


def audit() -> list:
    maps = {mid: Map(mid) for mid in map_ids()}
    # echo_path floors are built at runtime; warps into them still count as known maps.
    for mid in list(maps):
        base = mid.split("@")[0]
        d = json.load(open(os.path.join(ROOT, "data", "maps", base + ".json")))
        for i, fl in enumerate(d.get("floors", [])):
            if "rows" not in fl:
                maps.setdefault("%s@%d" % (base, i + 1), maps[base])
    entries = {}
    for m in maps.values():
        for w in m.warps:
            entries.setdefault(str(w["to"]), set()).add((int(w.get("tx", -1)), int(w.get("ty", -1))))
    for lad in [lad for m in maps.values() for lad in m.d.get("ladders", [])]:
        entries.setdefault(str(lad.get("to")), set()).add((int(lad.get("tx", -1)), int(lad.get("ty", -1))))
    for m in maps.values():
        if m.d.get("drop_to"):
            for x, y in m.cells():
                if m.kind(x, y) == "CRACKED":
                    entries.setdefault(m.d["drop_to"], set()).add((x, y))
    out = []
    done = set()
    for mid, m in maps.items():
        if m.id in done:
            continue
        done.add(m.id)
        out += check_map(m, maps, entries)
    return out


def main() -> None:
    findings = audit()
    if "--json" in sys.argv:
        print(json.dumps(findings, indent=1))
    else:
        by_map = {}
        for x in findings:
            by_map.setdefault(x["map"], []).append(x)
        for mid in sorted(by_map):
            print(mid)
            for x in by_map[mid]:
                print("  %-15s %3s,%-3s %s" % (x["kind"], x["x"], x["y"], x["msg"]))
        kinds = {}
        for x in findings:
            kinds[x["kind"]] = kinds.get(x["kind"], 0) + 1
        print("maps:", len({m.split("@")[0] for m in map_ids()}), "files,", len(map_ids()), "levels")
        print("findings:", len(findings), dict(sorted(kinds.items())))
    key = lambda x: "%s %s %s,%s" % (x["map"], x["kind"], x["x"], x["y"])  # noqa: E731
    old = json.load(open(BASELINE))["open"] if os.path.exists(BASELINE) else {}
    if "--write-baseline" in sys.argv:
        keep = {key(x): old.get(key(x), x["msg"]) for x in findings}
        json.dump({"_doc": "Known map audit findings (tools/maps/audit_maps.py). Key: map kind x,y. "
                   "Value: the finding, or why it stays on purpose. Remove a line by fixing the map.",
                   "open": dict(sorted(keep.items()))}, open(BASELINE, "w"), indent=1)
        open(BASELINE, "a").write("\n")
        print("wrote", os.path.relpath(BASELINE, ROOT), len(keep), "findings")
    if "--check" in sys.argv:
        now = {key(x) for x in findings}
        new = sorted(now - set(old))
        gone = sorted(set(old) - now)
        for k in new:
            print("NEW  ", k)
        for k in gone:
            print("FIXED", k, "(remove it from the baseline: --write-baseline)")
        if new or gone:
            sys.exit(1)
        print("OK: %d known findings, nothing new" % len(now))


if __name__ == "__main__":
    main()
