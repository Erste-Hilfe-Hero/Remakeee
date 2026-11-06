#!/usr/bin/env python3
"""Builds the world maps, one group per file in tools/art/world/ (area 3 item 895), so several
people can work on different map groups at once.

Usage: python3 tools/art/build_world.py            (all groups)
       python3 tools/art/build_world.py corvane    (only these groups)
Groups: veydal_core, veydal_wilds, veydal_caves, corvane. See tools/art/world/common.py.
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "world"))
from common import World  # noqa: E402

GROUPS = ["veydal_core", "veydal_wilds", "veydal_caves", "corvane"]


def main(argv):
    wanted = argv or GROUPS
    world = World()
    owner = {}
    for g in GROUPS:
        mod = importlib.import_module(g)
        for mid in mod.GROUP:
            if mid in owner:
                raise SystemExit("map %s is in both %s and %s" % (mid, owner[mid], g))
            owner[mid] = g
        if g in wanted:
            mod.build(world)
    from common import MAPS
    for f in sorted(os.listdir(MAPS)):
        if f.endswith(".json") and f[:-5] not in owner:
            raise SystemExit("map %s belongs to no group: add it to GROUP in one module" % f[:-5])
    for mid in world.maps:
        if owner.get(mid) not in wanted:
            raise SystemExit("map %s was built but belongs to group %s" % (mid, owner.get(mid)))
    world.write()


if __name__ == "__main__":
    main(sys.argv[1:])
