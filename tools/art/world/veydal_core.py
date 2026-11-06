"""Veydal core: the hand-edited Act I maps (Brindlewick, Fernstair, Crowcrest, Thornridge,
Saltmarsh, the houses and the two Rift hollows). Only patches; see common.py. Every patch can
run again without changing anything a second time."""
from common import secret

GROUP = ["lighthouse", "brindlewick", "map_house", "rest_spring", "fernstair", "crowcrest",
         "thornridge", "saltmarsh", "cinder_rift", "tide_rift"]

# Area 3 item 898: one biome per map (steers encounters, weather and sounds).
BIOMES = {"lighthouse": "town", "brindlewick": "town", "map_house": "town", "rest_spring": "town",
          "fernstair": "fern", "crowcrest": "scree", "thornridge": "town", "saltmarsh": "marsh",
          "cinder_rift": "rift", "tide_rift": "rift"}

# Item 1081: the old find "signs" become hidden finds. Flags and texts stay, so old saves keep
# what they already took. (map, sign dialogue key, item, count)
OLD_FINDS = [("brindlewick", "islet", "revival_leaf", 1), ("fernstair", "rock_find", "kin_charm", 2),
             ("thornridge", "rock_find", "dash_brew", 2), ("saltmarsh", "reed_find", "power_brew", 1)]

# Item 1078: 3 to 5 hidden finds on every outdoor map, next to a path, glinting now and then.
NEW_FINDS = {
    "brindlewick": [secret(11, 1, "tonic", "find_brindle_tree", 2), secret(1, 10, "remedy", "find_brindle_rock"),
                    secret(11, 8, "wake_bell", "find_brindle_fern")],
    "fernstair": [secret(0, 13, "tonic", "find_fern_west", 2), secret(11, 22, "remedy", "find_fern_south"),
                  secret(2, 24, "cooling_gel", "find_fern_gate")],
    "crowcrest": [secret(0, 13, "tonic", "find_crow_tarn", 2), secret(11, 4, "dry_towel", "find_crow_top"),
                  secret(1, 18, "spark_drop", "find_crow_scree"), secret(11, 13, "wake_bell", "find_crow_door")],
    "thornridge": [secret(0, 4, "tonic", "find_thorn_terrace", 2), secret(9, 14, "remedy", "find_thorn_fence"),
                   secret(0, 16, "kin_charm", "find_thorn_scree")],
    "saltmarsh": [secret(11, 11, "tonic", "find_marsh_east"), secret(2, 3, "spark_drop", "find_marsh_reeds"),
                  secret(11, 9, "remedy", "find_marsh_post")],
}


def build(world):
    for mid, biome in BIOMES.items():
        world.load_map(mid)["biome"] = biome
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
            _add_secret(m, find)
    for mid, finds in NEW_FINDS.items():
        m = world.load_map(mid)
        for f in finds:
            _add_secret(m, f)


def _add_secret(m, find):
    secrets = m.setdefault("secrets", [])
    if not any(s["flag"] == find["flag"] for s in secrets):
        secrets.append(find)
