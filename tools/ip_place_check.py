#!/usr/bin/env python3
"""Place and map names against a block list of the inspiration's towns and regions (plan area 3,
item 1319). Checks map file ids, every map and floor "name", the region and line names of
data/world_layout.json and the German map names. The list is base64-encoded so this file does
not spell the names out. Run by tools/ip_check.sh."""
import base64
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
BLOCKED = base64.b64decode(
    "cGFsbGV0fHZpcmlkaWFufHBld3RlcnxjZXJ1bGVhbnx2ZXJtaWxpb258Y2VsYWRvbnxrYW50b3xqb2h0b3xob2VubnxzaW5ub2h8dW5vdmF8a2Fsb3N8YWxvbGF8Z2FsYXJ8cGFsZGVhfGxpdHRsZXJvb3R8dHdpbmxlYWZ8Z29sZGVucm9kfGVjcnV0ZWFrfGxhdmFyaWRnZXxuaW1iYXNhfGx1bWlvc2V8aGF1Lj9vbGl8aHVsYnVyeXxtZXNhZ296YQ=="
).decode()
PATTERN = re.compile(r"(?<![a-z])(%s)(?![a-z])" % BLOCKED, re.I)


def names():
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "maps", "*.json"))):
        mid = os.path.splitext(os.path.basename(path))[0]
        yield path, mid
        m = json.load(open(path))
        for level in [m] + list(m.get("floors", [])):
            if "name" in level:
                yield path, str(level["name"])
    layout = json.load(open(os.path.join(ROOT, "data", "world_layout.json")))
    for key in ("regions", "lines"):
        for k, v in layout.get(key, {}).items():
            yield "data/world_layout.json", k
            yield "data/world_layout.json", str(v.get("name", ""))
    maps_de = os.path.join(ROOT, "data", "i18n", "de", "welt_maps.json")
    if os.path.exists(maps_de):
        for en, de in json.load(open(maps_de)).get("strings", {}).items():
            if len(en) < 40:
                yield maps_de, de


def main():
    bad = [(p, n) for p, n in names() if PATTERN.search(n.replace("_", " "))]
    for p, n in bad:
        print("%s: place name '%s' is on the block list" % (os.path.relpath(p, ROOT), n))
    if bad:
        print("::error::A place or map name matches the inspiration's towns or regions (lines above). Pick our own name.")
        return 1
    print("Place names OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
