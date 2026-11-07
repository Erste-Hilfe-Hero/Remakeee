"""Finds spread over all of Veydal, patched onto maps of the other groups (built last).

Cartographer's stones (area 3 items 1084, 1085): one old stone with a compass rose on each of
the twelve outdoor maps of Veydal. Looking at one counts it (MarkerStones.gd); the 4th, 8th
and 12th give a keepsake.

Lake benches (area 3 item 1093): three benches looking out over the lake. Sitting for ten
seconds brings a Spirling call from the water and a true hint about a hidden place.
"""
from common import lines, npc, secret, tr

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

# Items 1051, 1088: weathered stones on old burial mounds. Only a rubbing with the Rubbing
# Charcoal makes the worn inscription readable; it points to a hidden find close by.
# (map, mound x, y, find x, y, item, inscription)
MOUNDS = [
    ("stillwater", 11, 8, 9, 6, "tonic",
     ("\"Stand at my foot, take one step west, then two toward the north. The walker's gift lies there.\"",
      "\"Stell dich an meinen Fuß, geh einen Schritt nach Westen, dann zwei nach Norden. Dort liegt die Gabe des Wanderers.\"")),
    ("quillbrook", 3, 15, 1, 15, "remedy",
     ("\"Two steps toward the setting sun, the brook keeps my gift.\"",
      "\"Zwei Schritte zur untergehenden Sonne hütet der Bach meine Gabe.\"")),
    ("fernstair", 1, 20, 2, 22, "spark_drop",
     ("\"One step toward morning, two toward the valley. Dig there.\"",
      "\"Einen Schritt zum Morgen, zwei zum Tal hin. Dort grab.\"")),
    ("crowcrest", 11, 12, 10, 10, "strong_tonic",
     ("\"Stand before me, then walk two steps toward the peaks.\"",
      "\"Stell dich vor mich, dann geh zwei Schritte zu den Gipfeln hin.\"")),
    ("greyreach", 0, 22, 3, 24, "max_tonic",
     ("\"Three steps from me toward morning, two toward the rails' end.\"",
      "\"Drei Schritte von mir zum Morgen hin, zwei zum Ende der Gleise.\"")),
]

# Item 959: on market days (device clock Wednesday and Saturday) three extra stalls stand in
# Brindlewick. (id, x, y, facing, sprite, line, shop items)
MARKET_DAYS = [3, 6]
MARKET = [
    ("stall_fish", 9, 8, "left", "villager",
     ("Fishwife Marit: Market day! Dried kelp towels and cool gel, straight off the boats.",
      "Fischhändlerin Marit: Markttag! Getrocknete Tangtücher und kühles Gel, frisch von den Booten."),
     "dry_towel cooling_gel wake_bell tonic"),
    ("stall_herbs", 8, 10, "up", "elder",
     ("Herbwoman Agnes: Brews from the fen, only on market days. Smell that.",
      "Kräuterfrau Agnes: Gebräu aus dem Fenn, nur an Markttagen. Riech mal."),
     "power_brew guard_brew focus_brew dash_brew"),
    ("stall_tinker", 2, 9, "right", "villager",
     ("Tinker Rasmus: Wednesday and Saturday, rain or shine. Charms and leaves, fair prices.",
      "Kesselflicker Rasmus: Mittwoch und Samstag, bei Regen und Sonne. Amulette und Blätter, faire Preise."),
     "kin_charm revival_leaf strong_tonic"),
]

# Item 1089: buried finds under loose soil. The soil shows on the ground; press A on it to dig
# the find up with your own hands, no Spirling needed. (map, x, y, item, flag)
LOOSE_SOIL = [("saltmarsh", 10, 9, "remedy", "dig_saltmarsh"), ("woadfen", 3, 21, "strong_tonic", "dig_woadfen"),
              ("saltglass", 9, 13, "revival_leaf", "dig_saltglass"), ("lantern_steps", 10, 11, "spark_drop", "dig_lantern_steps")]


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
    for n, (mid, x, y, fx, fy, item, words) in enumerate(MOUNDS, 1):
        m = world.load_map(mid)
        m["signs"] = [s for s in m.get("signs", []) if (s["x"], s["y"]) != (x, y)]
        m["signs"].append({"x": x, "y": y, "dialogue": "%s/mound_stone" % mid})
        set_char(m, x, y, "S")
        m["secrets"] = [s for s in m.get("secrets", []) if s["flag"] != "find_mound_%d" % n]
        m["secrets"].append(secret(fx, fy, item, "find_mound_%d" % n))
        world.add_text(mid, {
            "mound_stone": {"lines": lines(("An old burial mound. A weathered stone stands on it, its letters worn almost away.",
                                            "Ein alter Grabhügel. Darauf steht ein verwitterter Stein, die Buchstaben fast verschwunden.")),
                            "action": "rubbing %s/mound_words" % mid},
            "mound_words": lines(words)})
    # The charcoal burner in Gloamwood hands out the Rubbing Charcoal.
    m = world.load_map("gloamwood")
    m["npcs"] = [p for p in m["npcs"] if p["id"] != "charcoaler"]
    m["npcs"].append(npc("charcoaler", 8, 1, "down", "gloamwood/charcoaler", "villager"))
    world.add_text("gloamwood", {"charcoaler": {
        "lines": lines(("Charcoal burner Wido: The old mounds out here have words on them, if you know how to look.",
                        "Köhler Wido: Die alten Hügel hier draußen tragen Worte, wenn man weiß, wie man hinsieht."),
                       ("Charcoal burner Wido: Lay paper on the stone and rub this over it. The letters come back.",
                        "Köhler Wido: Leg Papier auf den Stein und reib das hier drüber. Die Buchstaben kommen zurück.")),
        "action": "give_item rubbing_charcoal 1", "flag": "got_rubbing_charcoal", "once": True,
        "after_flag": {"flag": "got_rubbing_charcoal", "lines": lines(
            ("Charcoal burner Wido: Five mounds I know of, from the forest to the rails. Mind the dead, they don't mind you.",
             "Köhler Wido: Fünf Hügel kenne ich, vom Wald bis zu den Gleisen. Achte die Toten, sie haben nichts gegen dich."))}}})
    m = world.load_map("brindlewick")
    ids = [st[0] for st in MARKET]
    m["npcs"] = [p for p in m["npcs"] if p["id"] not in ids]
    for sid, x, y, facing, sprite, line, shop in MARKET:
        m["npcs"].append(npc(sid, x, y, facing, "brindlewick/" + sid, sprite, weekdays=MARKET_DAYS))
        world.add_text("brindlewick", {sid: {"lines": lines(line), "action": "shop " + shop}})
    for mid, x, y, item, flag in LOOSE_SOIL:
        m = world.load_map(mid)
        m["secrets"] = [s for s in m.get("secrets", []) if s["flag"] != flag]
        m["secrets"].append(dict(secret(x, y, item, flag), soil=True))
