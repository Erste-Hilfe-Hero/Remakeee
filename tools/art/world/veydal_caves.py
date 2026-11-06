"""Veydal caves and puzzle dungeons (Murk Hollow and the new grottoes, Bellstone Ruins,
Brackwater Sluice, Lanternwell, Shatterfloor Mine)."""
from common import secret  # noqa: F401

GROUP = ["murk_hollow"]

# Item 1081: Murk Hollow's two find signs become hidden finds (flags and texts kept).
OLD_FINDS = [("murk_hollow", "gallery_find", "spark_coil", 1), ("murk_hollow", "nook_find", "echo_umbra", 1)]


def build(world):
    world.load_map("murk_hollow")["biome"] = "cave"
    for mid, key, item, count in OLD_FINDS:
        m = world.load_map(mid)
        ref = "%s/%s" % (mid, key)
        old = [s for s in m.get("signs", []) if s.get("dialogue") == ref]
        if old:
            s = old[0]
            m["signs"].remove(s)
            entry = world.dialogue(mid)[key]
            find = secret(s["x"], s["y"], item, entry["flag"], count)
            find["dialogue"] = ref
            m.setdefault("secrets", []).append(find)
