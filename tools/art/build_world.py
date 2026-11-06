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
        # Every group is built so the German table stays complete; only wanted groups are written.
        mod.build(world)
    # Maps of other areas (story maps and the like) that no group owns are left as they are.
    for mid in list(world.maps):
        if mid not in owner:
            raise SystemExit("map %s was built but is in no GROUP" % mid)
        if owner[mid] not in wanted:
            del world.maps[mid]
            world.text.pop(mid, None)
    world.write()


if __name__ == "__main__":
    main(sys.argv[1:])
