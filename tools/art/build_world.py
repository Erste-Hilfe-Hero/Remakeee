#!/usr/bin/env python3
"""Builds the world maps, one group per file in tools/art/world/ (area 3 item 895), so several
people can work on different map groups at once.

Usage: python3 tools/art/build_world.py            (all groups)
       python3 tools/art/build_world.py corvane    (only these groups)
       python3 tools/art/build_world.py --check    (CI: exit 1 when a rebuild would change data/)
       python3 tools/art/build_world.py --absorb   (keep hand edits of data/maps and data/dialogue:
                                                    writes them to tools/art/world/hand/, then builds)
Hand-added NPCs, finds, signs and warps live in tools/art/world/hand/ (see common.py), so a
rebuild never throws them away.
Groups: veydal_core, veydal_wilds, veydal_caves, veydal_dungeons, corvane, veydal_finds, rifts12, solenne, solenne_side, solenne_more, halcyra, quivermoor. See tools/art/world/common.py.
"""
import importlib
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "world"))
from common import DIA, MAPS, World  # noqa: E402

GROUPS = ["veydal_core", "veydal_wilds", "veydal_caves", "veydal_dungeons", "corvane", "veydal_finds", "rifts12", "solenne", "solenne_side", "solenne_more", "halcyra", "quivermoor"]


def snapshot():
    out = {"maps": {}, "text": {}}
    for key, folder in (("maps", MAPS), ("text", DIA)):
        for f in os.listdir(folder):
            if f.endswith(".json"):
                out[key][f[:-5]] = json.load(open(os.path.join(folder, f)))
    return out


def main(argv):
    flags = {a for a in argv if a.startswith("--")}
    argv = [a for a in argv if not a.startswith("--")]
    committed = snapshot() if "--absorb" in flags else None
    wanted = argv or GROUPS
    world = World()
    owner = {}
    for g in GROUPS:
        mod = importlib.import_module(g)
        for mid in mod.GROUP:
            if mid in owner:
                raise SystemExit("map %s is in both %s and %s" % (mid, owner[mid], g))
            owner[mid] = g
        # Every group is built so the German table stays complete; only wanted groups are written.
        mod.build(world)
    # Maps of other areas (story maps and the like) that no group owns are left as they are.
    for mid in list(world.maps):
        if mid not in owner:
            raise SystemExit("map %s was built but is in no GROUP" % mid)
        if owner[mid] not in wanted:
            del world.maps[mid]
            world.text.pop(mid, None)
    if "--check" in flags:
        stale = world.check()
        if stale:
            print("build_world.py would change %d files:" % len(stale))
            for p in stale:
                print("  " + p)
            print("Edit tools/art/world/*.py (or run python3 tools/art/build_world.py --absorb to keep a hand edit"
                  " of data/maps or data/dialogue in tools/art/world/hand/), then rebuild.")
            raise SystemExit(1)
        print("world maps match tools/art/world (%d maps)" % len(world.maps))
        return
    if committed is not None:
        for p in world.absorb(committed):
            print("hand overlay", os.path.relpath(p, os.path.dirname(os.path.abspath(__file__))))
    world.write()


if __name__ == "__main__":
    main(sys.argv[1:])
